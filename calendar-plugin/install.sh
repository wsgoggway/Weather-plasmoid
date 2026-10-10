#!/usr/bin/env bash
# Build and install the weatherevents Plasma calendar plugin.
#
# Usage:
#   ./calendar-plugin/install.sh            # build + install + plasmashell --replace
#   ./calendar-plugin/install.sh uninstall  # remove installed files + plasmashell --replace
#
# Requires sudo: the plugin goes into system Qt/KDE directories.
# WARNING: finishes with `plasmashell --replace`, which RESTARTS the user's
# desktop shell. Run manually; never executed by agents.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"

# Keep in sync with calendar-plugin/CMakeLists.txt install destinations.
PLUGIN_DIR="/usr/lib/qt6/plugins/plasmacalendarplugins"
PLUGIN_SO="${PLUGIN_DIR}/weatherevents.so"
CONFIG_PAGE="${PLUGIN_DIR}/weatherevents/configui.qml"
QML_MODULE_DIR="/usr/lib/qt6/qml/org/kde/plasma/private/weathereventsconfig"

restart_shell() {
    # This restarts the user's plasmashell; backgrounded so this script can exit.
    echo "Restarting plasmashell (this restarts your desktop shell)..."
    nohup plasmashell --replace >/dev/null 2>&1 &
    disown
}

if [[ "${1:-}" == "uninstall" ]]; then
    echo "Plan:"
    echo "  1. sudo rm -f ${PLUGIN_SO} ${CONFIG_PAGE}"
    echo "  2. sudo rm -rf ${QML_MODULE_DIR}"
    echo "  3. plasmashell --replace (restarts the user's shell)"
    sudo rm -f "${PLUGIN_SO}" "${CONFIG_PAGE}"
    sudo rm -rf "${QML_MODULE_DIR}"
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
echo "  3. sudo cmake --install ${BUILD_DIR}  (.so + configui.qml + config QML module)"
echo "  4. plasmashell --replace (restarts the user's shell)"

cmake -S "${SCRIPT_DIR}" -B "${BUILD_DIR}"
cmake --build "${BUILD_DIR}"

SO_ARTIFACT="$(find "${BUILD_DIR}" -name 'weatherevents.so' -type f -print -quit)"
if [[ -z "${SO_ARTIFACT}" ]]; then
    echo "ERROR: build produced no weatherevents.so under ${BUILD_DIR}" >&2
    exit 1
fi

sudo cmake --install "${BUILD_DIR}"
restart_shell
echo "Installed: ${PLUGIN_SO}"
echo "           ${CONFIG_PAGE}"
echo "           ${QML_MODULE_DIR}/"
