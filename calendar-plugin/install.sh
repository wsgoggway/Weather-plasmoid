#!/usr/bin/env bash
# Build and install the weatherevents Plasma calendar plugin.
#
# Usage:
#   ./calendar-plugin/install.sh            # build + install + plasmashell --replace
#   ./calendar-plugin/install.sh uninstall  # remove .so + plasmashell --replace
#
# Requires sudo: the plugin goes into /usr/lib/qt6/plugins/plasmacalendarplugins.
# WARNING: finishes with `plasmashell --replace`, which RESTARTS the user's
# desktop shell. Run manually; never executed by agents.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
INSTALL_PATH="/usr/lib/qt6/plugins/plasmacalendarplugins/weatherevents.so"

find_plugin_artifact() {
    find "${BUILD_DIR}" -name 'weatherevents.so' -type f -print -quit
}

restart_shell() {
    # This restarts the user's plasmashell; backgrounded so this script can exit.
    echo "Restarting plasmashell (this restarts your desktop shell)..."
    nohup plasmashell --replace >/dev/null 2>&1 &
    disown
}

if [[ "${1:-}" == "uninstall" ]]; then
    echo "Plan:"
    echo "  1. sudo rm -f ${INSTALL_PATH}"
    echo "  2. plasmashell --replace (restarts the user's shell)"
    sudo rm -f "${INSTALL_PATH}"
    restart_shell
    echo "Uninstalled."
    exit 0
fi

if [[ $# -gt 0 ]]; then
    echo "Unknown argument: $1" >&2
    echo "Usage: $0 [uninstall]" >&2
    exit 1
fi

echo "Plan:"
echo "  1. cmake -S ${SCRIPT_DIR} -B ${BUILD_DIR}"
echo "  2. cmake --build ${BUILD_DIR}"
echo "  3. sudo install -Dm755 <weatherevents.so> ${INSTALL_PATH}"
echo "  4. plasmashell --replace (restarts the user's shell)"

cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}"
cmake --build "${BUILD_DIR}"

ARTIFACT="$(find_plugin_artifact)"
if [[ -z "${ARTIFACT}" ]]; then
    echo "ERROR: build produced no weatherevents.so under ${BUILD_DIR}" >&2
    exit 1
fi

sudo install -Dm755 "${ARTIFACT}" "${INSTALL_PATH}"
restart_shell
echo "Installed ${INSTALL_PATH}"
