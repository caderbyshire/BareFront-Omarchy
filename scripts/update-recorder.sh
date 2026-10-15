#!/usr/bin/env bash
# Apply the recording fix without touching ROMs, saves, configuration or emulators.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${BAREFRONT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/barefront}"
if [[ "$DEST" != /* || ! -f "$DEST/.omarchy-managed" ]]; then
    echo 'A managed BareFront installation was not found.' >&2
    exit 1
fi
SOURCE="$ROOT/application/scripts/capture_gamescope_video.sh"
TARGET="$DEST/scripts/capture_gamescope_video.sh"
[[ -f "$TARGET" ]] || { echo "Recorder missing: $TARGET" >&2; exit 1; }
bash -n "$SOURCE"
if cmp -s "$SOURCE" "$TARGET"; then
    echo 'Recorder already up to date.'
    exit 0
fi
BACKUP="$(mktemp "$TARGET.before-fix.XXXXXX")"
cp -p -- "$TARGET" "$BACKUP"
install -m755 "$SOURCE" "$TARGET"
echo "Recorder updated. Backup: $BACKUP"
