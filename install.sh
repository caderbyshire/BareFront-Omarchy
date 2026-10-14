#!/usr/bin/env bash
# Run in a terminal: the full installer handles package privileges and AUR builds.
set -Eeuo pipefail
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${BAREFRONT_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/barefront}"
[[ "$INSTALL_ROOT" == /* ]] || { echo 'BAREFRONT_INSTALL_DIR must be an absolute path.' >&2; exit 1; }
[[ "$EUID" -ne 0 ]] || { echo 'Run this installer as your normal desktop user.' >&2; exit 1; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'BareFront currently requires x86-64.' >&2; exit 1; }
command -v omarchy >/dev/null || { echo 'This installer requires Omarchy.' >&2; exit 1; }
# This entry point always runs the full interactive first-install workflow.
unset BAREFRONT_AGENT_INSTALL
command -v python3 >/dev/null || omarchy pkg add python
if [[ -e "$INSTALL_ROOT" && ! -f "$INSTALL_ROOT/.omarchy-managed" ]]; then
    echo "Refusing to overwrite an existing unmanaged directory: $INSTALL_ROOT" >&2
    exit 1
fi
mkdir -p "$INSTALL_ROOT"
exec 9>"$INSTALL_ROOT/.install.lock"
flock -n 9 || { echo 'A BareFront installation is already running.' >&2; exit 1; }
touch "$INSTALL_ROOT/.omarchy-managed"
# Seed a new installation once. Re-running preserves configuration and user data.
if [[ ! -f "$INSTALL_ROOT/.omarchy-source-ready" ]]; then
    cp -a "$PLUGIN_ROOT/application/." "$INSTALL_ROOT/"
    touch "$INSTALL_ROOT/.omarchy-source-ready"
fi
install -m755 "$PLUGIN_ROOT/installer/install-runtime.sh" "$INSTALL_ROOT/scripts/install-runtime.sh"
python3 "$PLUGIN_ROOT/installer/adapt.py" "$INSTALL_ROOT"
rm -f "$INSTALL_ROOT/.omarchy-install-complete"
bash "$INSTALL_ROOT/scripts/install_barefront_arch.sh"
[[ -x "$INSTALL_ROOT/barefront" && -f "$INSTALL_ROOT/barefront.ini" ]] || {
    echo 'BareFront installation did not produce an executable and configuration.' >&2
    exit 1
}
touch "$INSTALL_ROOT/.omarchy-install-complete"
echo "BareFront installed: $INSTALL_ROOT"
