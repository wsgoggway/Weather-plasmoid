#!/bin/bash
# Install Open-Meteo Weather plasmoid for KDE Plasma 6
# Usage: ./install.sh [--user|--system]

set -e

PLASMOID_NAME="com.github.vladimirm.openmeteo-weather"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)/package"

echo "=============================================="
echo "  Open-Meteo Weather — Plasmoid Installer"
echo "=============================================="
echo ""

INSTALL_MODE="${1:---user}"

if [ "$INSTALL_MODE" == "--user" ]; then
    TARGET_DIR="$HOME/.local/share/plasma/plasmoids/$PLASMOID_NAME"
    echo "→ Installing for current user"
    echo "  $TARGET_DIR"
elif [ "$INSTALL_MODE" == "--system" ]; then
    TARGET_DIR="/usr/share/plasma/plasmoids/$PLASMOID_NAME"
    echo "→ Installing system-wide"
    echo "  $TARGET_DIR"
    SUDO="sudo"
else
    echo "✗ Unknown option: $INSTALL_MODE"
    echo "Usage: $0 [--user|--system]"
    exit 1
fi

# Remove old installation
if [ -d "$TARGET_DIR" ]; then
    echo "→ Removing previous installation..."
    $SUDO rm -rf "$TARGET_DIR"
fi

# Install files
echo "→ Copying plasmoid files..."
$SUDO mkdir -p "$TARGET_DIR"
$SUDO cp -r "$SOURCE_DIR"/* "$TARGET_DIR"

echo ""
echo "✓ Installation complete!"
echo ""
echo "To apply changes:"
echo "  plasmashell --replace &"
echo ""
echo "Then add the widget:"
echo "  Right-click panel → Add Widgets"
echo "  → Environment & Weather → Open-Meteo Weather"
echo ""
echo "The widget uses the free Open-Meteo API"
echo "— no API key needed!"
echo ""
echo "Attribution: Weather data by open-meteo.com (CC BY 4.0)"
echo "=============================================="
