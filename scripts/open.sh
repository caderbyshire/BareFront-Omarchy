#!/usr/bin/env bash
set -Eeuo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL_ROOT="${BAREFRONT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/barefront}"
if [[ ! -f "$INSTALL_ROOT/.omarchy-install-complete" ]]; then
    bash "$PLUGIN_ROOT/install.sh"
fi
exec bash "$INSTALL_ROOT/scripts/launch_barefront_gamescope.sh"
