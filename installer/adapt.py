#!/usr/bin/env python3
"""Generate the Omarchy/Arch installer from the pinned BareFront installer."""
from pathlib import Path
import re
import sys

ROOT = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / 'application'
LOCAL = ROOT / 'scripts'
text = (ROOT / 'scripts/install_barefront.sh').read_text()

def replace(old, new):
    global text
    assert old in text, f'Upstream installer changed: {old[:100]}'
    text = text.replace(old, new)

def section(start, end, replacement):
    global text
    a, b = text.index(start), text.index(end)
    text = text[:a] + replacement + '\n\n' + text[b:]

replace('BAREFRONT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"',
        'BAREFRONT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\nLOCAL_INSTALL_DIR="$BAREFRONT_DIR/scripts"')
replace('LOG_FILE="$LOG_DIR/install.log"', 'LOG_FILE="$LOG_DIR/install-arch.log"')
section('package_is_installed()\n{', 'install_debian_emulator()', '''package_is_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

arch_install() {
    local package
    local packages=()
    for package in "$@"; do
        case "$package" in
            g++) package=gcc ;;
            pkg-config) package=pkgconf ;;
            libsdl2-dev) package=sdl2-compat ;;
            libx11-dev) package=libx11 ;;
            libxtst-dev) package=libxtst ;;
            libgtk-3-dev) package=gtk3 ;;
            libgtksourceview-3.0-dev) package=gtksourceview3 ;;
            libxv-dev) package=libxv ;;
            libgl1-mesa-dev) package=libglvnd ;;
            libasound2-dev) package=alsa-lib ;;
            libopenal-dev) package=openal ;;
            libpulse-dev) package=libpulse ;;
            libao-dev) package=libao ;;
            libudev-dev) package=systemd-libs ;;
            libxrandr-dev) package=libxrandr ;;
            libxext-dev) package=libxext ;;
        esac
        if ! pacman -Q "$package" >/dev/null 2>&1; then
            packages+=("$package")
        fi
    done
    (( ${#packages[@]} )) || return 0
    if [[ -n "${BAREFRONT_AGENT_INSTALL:-}" ]]; then
        pkexec /usr/share/omarchy/bin/omarchy-pkg-add "${packages[@]}"
    else
        omarchy pkg add "${packages[@]}"
    fi
}
''')
section('if [[ "${ID:-}" != "debian" ]]; then', 'if [[ "$EUID" -eq 0 ]]; then', '''if [[ "${ID:-}" != omarchy && "${ID:-}" != arch && " ${ID_LIKE:-} " != *" arch "* ]]; then
    die "This installer requires Arch Linux or Omarchy."
fi
[[ "$(uname -m)" == x86_64 ]] || die "This installer requires x86-64."
''')
section('echo "Checking sudo access..."', '# An explicit local archive', '''if [[ -z "${BAREFRONT_AGENT_INSTALL:-}" ]]; then
    sudo -v || die "sudo authentication failed."
fi
''')
section('heading "STAGE 2 / DEBIAN DEPENDENCIES"', 'heading "STAGE 2B / BAREFRONT DIRECTORIES"', '''heading "STAGE 2 / ARCH DEPENDENCIES"
arch_install base-devel pkgconf git curl wget ca-certificates unzip zip 7zip xz file rsync jq python \
    udisks2 cifs-utils keyutils libpulse sdl2-compat sdl2_image sdl2_ttf sdl2_mixer ffmpeg \
    gstreamer gst-plugin-pipewire gst-plugins-base gst-plugins-good gst-plugins-ugly \
    libglvnd vulkan-icd-loader vulkan-tools xorg-xrandr fuse2 libx11 libxtst libxi \
    libxfixes libxrender libxres libliftoff gamescope mednafen mame stella dolphin-emu vice \
    gtk3 gtksourceview3 libxv alsa-lib openal libao libxrandr libxext
systemctl --user start pipewire.socket pipewire.service
pw-cli info 0 >/dev/null || die "PipeWire connection failed."
bash "$LOCAL_INSTALL_DIR/install-runtime.sh" "$BAREFRONT_DIR"
source "$BAREFRONT_DIR/scripts/barefront_presentation_runtime.sh"
barefront_resolve_presentation_runtime "$BAREFRONT_DIR"
GAMESCOPE_EXE="$BAREFRONT_GAMESCOPE"
''')
section('enable_barefront_contrib()\n{', 'heading "STAGE 3A SUMMARY"', '''if install_debian_emulator "Commodore 64 / VICE" vice /usr/bin/x64sc; then
    ((SUCCESS_COUNT+=1))
else
    ((FAILED_COUNT+=1))
fi
''')
section('if package_is_installed "amiberry" && [[ -x "$AMIBERRY_EXE" ]]; then',
        '# Verify installed package', '''if ! package_is_installed amiberry; then
    [[ -z "${BAREFRONT_AGENT_INSTALL:-}" ]] || die "Install Amiberry first in a terminal: omarchy pkg aur add amiberry"
    omarchy pkg aur add amiberry || die "Amiberry AUR build failed."
fi
''')
replace('sudo apt-get install -y', 'arch_install')
text = re.sub(r"dpkg-query -W -f='\$\{Version\}' ([a-z0-9-]+)", r"pacman -Q \1 | awk '{print $2}'", text)
replace('/usr/games/', '/usr/bin/')
replace('VKBASALT_LAYER="/usr/share/vulkan/implicit_layer.d/vkBasalt.json"',
        'VKBASALT_LAYER="$BAREFRONT_VKBASALT_LAYER_DIR/vkBasalt.json"')
replace('STAGE 3A / DEBIAN EMULATORS', 'STAGE 3A / ARCH EMULATORS')
replace('These emulators come directly from Debian 13 packages.', 'These emulators come from Arch repository packages.')
replace('Debian emulator packages:', 'Arch emulator packages:')
replace('whether its Debian package', 'whether its Arch package')
replace('Official Amiberry Debian package repository', 'Amiberry Arch User Repository package')
replace('Common Debian dependencies', 'Common Arch dependencies')
replace('Debian-managed emulator stage', 'Arch-managed emulator stage')
replace('Amiberry official Debian-package installation / integration', 'Amiberry AUR installation / integration')
replace('if [[ "$SUPPORTS_1080P50" == "yes" ]]; then',
        'if [[ -z "${WAYLAND_DISPLAY:-}" && "$SUPPORTS_1080P50" == "yes" ]]; then')
replace('-j"$(nproc)"', '-j"${BAREFRONT_BUILD_JOBS:-4}"')
replace('    read -r -p \\\n        "Configure a Network Share content source? [y/N] " \\\n        network_reply', '''    if [[ -n "${BAREFRONT_AGENT_INSTALL:-}" ]]; then
        network_reply=N
    else
        read -r -p "Configure a Network Share content source? [y/N] " network_reply
    fi''')
assert not re.search(r'^\s*(?:if ! |if )?(?:sudo )?(?:apt-get|apt-cache|dpkg)', text, re.M)
# Tracked launchers also contain Debian executable paths. Only local copies change.
for path in (ROOT / 'scripts').glob('launch_*.sh'):
    original = path.read_text()
    adapted = original.replace('/usr/games/', '/usr/bin/')
    adapted = adapted.replace('if [[ "$SUPPORTS_1080P50" == "yes" ]]; then',
                              'if [[ -z "${WAYLAND_DISPLAY:-}" && "$SUPPORTS_1080P50" == "yes" ]]; then')
    adapted = adapted.replace('if ! xrandr \\\n    --output "$DISPLAY_OUTPUT"',
                              'if [[ -z "${WAYLAND_DISPLAY:-}" ]] && ! xrandr \\\n    --output "$DISPLAY_OUTPUT"')
    if adapted != original:
        path.write_text(adapted)
output = LOCAL / 'install_barefront_arch.sh'
temporary = output.with_suffix('.tmp')
temporary.write_text('# OMARCHY/ARCH ADAPTATION: generated by installer/adapt.py.\n' + text)
temporary.chmod(0o755)
temporary.replace(output)
print(output)
