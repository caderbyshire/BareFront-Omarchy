#!/usr/bin/env bash
# Build and install the matching recorder/helper pair without changing user data.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${BAREFRONT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/barefront}"
if [[ "$DEST" != /* || ! -f "$DEST/.omarchy-managed" ]]; then
    echo 'A managed BareFront installation was not found.' >&2
    exit 1
fi
for FILE in scripts/capture_gamescope_video.sh src/capture_helper.cpp capture_helper; do
    [[ -f "$DEST/$FILE" ]] || { echo "Capture component missing: $DEST/$FILE" >&2; exit 1; }
done
SOURCE="$ROOT/application"
bash -n "$SOURCE/scripts/capture_gamescope_video.sh"
if cmp -s "$SOURCE/scripts/capture_gamescope_video.sh" "$DEST/scripts/capture_gamescope_video.sh" &&
   cmp -s "$SOURCE/src/capture_helper.cpp" "$DEST/src/capture_helper.cpp" &&
   [[ "$DEST/capture_helper" -nt "$DEST/src/capture_helper.cpp" ]]; then
    echo 'Recorder and helper already up to date.'
    exit 0
fi
STAGE="$(mktemp -d -t barefront-capture-build.XXXXXX)"
trap 'rm -rf -- "$STAGE"' EXIT
# Build before touching the installed pair; missing dependencies leave it intact.
g++ -std=c++17 -Wall -Wextra "$SOURCE/src/capture_helper.cpp" \
    -o "$STAGE/capture_helper" $(sdl2-config --cflags --libs) -lX11 -lXi
BACKUP="$(mktemp -d "$DEST/.capture-backup.XXXXXX")"
mkdir -p "$BACKUP/scripts" "$BACKUP/src"
for FILE in scripts/capture_gamescope_video.sh src/capture_helper.cpp capture_helper; do
    cp -p -- "$DEST/$FILE" "$BACKUP/$FILE"
done
rollback() {
    for FILE in scripts/capture_gamescope_video.sh src/capture_helper.cpp capture_helper; do
        cp -p -- "$BACKUP/$FILE" "$DEST/$FILE"
    done
    echo "Capture update failed; restored previous components from $BACKUP" >&2
}
trap rollback ERR
install -m755 "$SOURCE/scripts/capture_gamescope_video.sh" "$DEST/scripts/capture_gamescope_video.sh"
install -m644 "$SOURCE/src/capture_helper.cpp" "$DEST/src/capture_helper.cpp"
install -m755 "$STAGE/capture_helper" "$DEST/capture_helper.new"
mv -f -- "$DEST/capture_helper.new" "$DEST/capture_helper"
trap - ERR
echo "Recorder and helper updated. Backup: $BACKUP"
echo 'New captures take effect on the next game launch. Existing green recordings must be recorded again.'
