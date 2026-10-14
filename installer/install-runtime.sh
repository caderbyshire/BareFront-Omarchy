#!/usr/bin/env bash
# Retain the pinned patched runtime; isolate Debian ABI compatibility libraries.
set -Eeuo pipefail
ROOT="$(realpath "$1")"
DEST="$ROOT/runtime/presentation"
CACHE="$ROOT/runtime/downloads"
mkdir -p "$CACHE"
fetch() {
    local url="$1" file="$2" sha="$3"
    if [[ ! -f "$file" ]] || ! printf '%s  %s\n' "$sha" "$file" | sha256sum -c --status; then
        curl -fL --retry 3 --connect-timeout 20 "$url" -o "$file.part"
        printf '%s  %s\n' "$sha" "$file.part" | sha256sum -c -
        mv "$file.part" "$file"
    fi
}
ARCHIVE="$CACHE/presentation-v2.tar.xz"
fetch https://github.com/craigaderbyshire/BareFront-Presentation-Runtime/releases/download/v2/barefront-presentation-debian13-amd64-v2.tar.xz \
    "$ARCHIVE" 9aabed1d4813c943edd94c17dd962d2af90ce6bde421687de1929cf00c69ee48
STAGE="$(mktemp -d "$ROOT/runtime/.arch-presentation.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
tar -xJf "$ARCHIVE" -C "$STAGE" --no-same-owner
printf '%s  %s\n' a0951ce8f20d0f9fc893b64c3e9d1a82e8b16b0bf61bb915c39a3901970b1346 "$STAGE/runtime/gamescope/gamescope" | sha256sum -c -
printf '%s  %s\n' 6e4ef4faba44b7cd7625fac47b5960406a1a02539b72fd6aab2b308aa75d3dfd "$STAGE/runtime/vkbasalt/libvkbasalt.so" | sha256sum -c -
mkdir -p "$STAGE/new/gamescope" "$STAGE/new/vkbasalt" "$STAGE/new/vulkan/implicit_layer.d" "$STAGE/new/compat" "$STAGE/new/LICENSES"
install -m755 "$STAGE/runtime/gamescope/gamescope" "$STAGE/new/gamescope/gamescope.bin"
install -m755 "$STAGE/runtime/vkbasalt/libvkbasalt.so" "$STAGE/new/vkbasalt/libvkbasalt.so"
cp -a "$STAGE/LICENSES/." "$STAGE/new/LICENSES/"
cp "$STAGE/README.txt" "$STAGE/new/README.txt"
while read -r name url sha; do
    file="$CACHE/$name.deb"
    fetch "https://deb.debian.org/debian/$url" "$file" "$sha"
    mkdir -p "$STAGE/$name"
    (cd "$STAGE/$name"; ar x "$file"; tar -xf data.tar.*)
    cp -a "$STAGE/$name/usr/lib/x86_64-linux-gnu/." "$STAGE/new/compat/"
    cp "$STAGE/$name/usr/share/doc/$name/copyright" "$STAGE/new/LICENSES/$name-copyright"
done <<'PACKAGES'
libdisplay-info2 pool/main/libd/libdisplay-info/libdisplay-info2_0.2.0-2_amd64.deb 961924d484d4c14b6decb76cf0e860a1e7b6c89bfc85e527d873a89faf24b846
libwlroots-0.18 pool/main/w/wlroots/libwlroots-0.18_0.18.2-3_amd64.deb b271f6b007a0945284d36e5d5e4c84542e930c5bd6a46464ec333e5fddd88b7a
PACKAGES
cat > "$STAGE/new/gamescope/gamescope" <<'WRAPPER'
#!/usr/bin/env bash
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export LD_LIBRARY_PATH="$HERE/../compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export SDL_VIDEODRIVER=x11
export SDL_VIDEO_X11_WMCLASS=gamescope
exec "$HERE/gamescope.bin" --backend sdl "$@"
WRAPPER
chmod 755 "$STAGE/new/gamescope/gamescope"
python3 - "$DEST" "$STAGE/new/vulkan/implicit_layer.d/vkBasalt.json" <<'PY'
import json, sys
from pathlib import Path
data={'file_format_version':'1.0.0','layer':{
    'name':'VK_LAYER_VKBASALT_post_processing', 'type':'GLOBAL',
    'library_path':sys.argv[1]+'/vkbasalt/libvkbasalt.so',
    'api_version':'1.3.223','implementation_version':'1',
    'description':'BareFront patched vkBasalt',
    'functions':{'vkGetInstanceProcAddr':'vkBasalt_GetInstanceProcAddr',
                 'vkGetDeviceProcAddr':'vkBasalt_GetDeviceProcAddr'},
    'enable_environment':{'ENABLE_VKBASALT':'1'},
    'disable_environment':{'DISABLE_VKBASALT':'1'}}}
Path(sys.argv[2]).write_text(json.dumps(data,indent=2)+'\n')
PY
CHECK="$(LD_LIBRARY_PATH="$STAGE/new/compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" ldd "$STAGE/new/gamescope/gamescope.bin")"
if [[ "$CHECK" == *'not found'* ]]; then
    printf '%s\n' "$CHECK"
    echo 'Missing Arch runtime dependencies; refusing incomplete installation.' >&2
    exit 1
fi
"$STAGE/new/gamescope/gamescope" --version
if [[ -e "$DEST" ]]; then
    [[ -f "$DEST/ARCH-LOCAL" ]] || { echo 'Refusing to replace an unmanaged runtime.' >&2; exit 1; }
    [[ ! -e "$DEST.previous" ]] || { echo 'Runtime backup already exists.' >&2; exit 1; }
    mv "$DEST" "$DEST.previous"
fi
touch "$STAGE/new/ARCH-LOCAL"
if ! mv "$STAGE/new" "$DEST"; then
    [[ ! -d "$DEST.previous" ]] || mv "$DEST.previous" "$DEST"
    exit 1
fi
if [[ -d "$DEST.previous" ]]; then rm -rf "$DEST.previous"; fi
echo "Private Arch-compatible presentation runtime installed: $DEST"
