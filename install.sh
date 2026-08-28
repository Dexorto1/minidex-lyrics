#!/usr/bin/env bash
set -e

DEST_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.minidex-lyrics"
OLD_DIR="$HOME/.local/share/plasma/plasmoids/org.kde.plasma.inirmusicplayer"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Installing minidex-lyrics Plasmoid ==="
echo "Source: $SRC_DIR"
echo "Destination: $DEST_DIR"

# Clean up old installations
rm -rf "$OLD_DIR" "$DEST_DIR"
mkdir -p "$DEST_DIR"
cp -r "$SRC_DIR"/* "$DEST_DIR"/

# Rebuild KDE system configuration cache
if command -v kbuildsycoca6 &>/dev/null; then
    echo "Rebuilding Plasma 6 cache..."
    kbuildsycoca6 --noincremental || true
elif command -v kbuildsycoca5 &>/dev/null; then
    echo "Rebuilding Plasma 5 cache..."
    kbuildsycoca5 --noincremental || true
fi

# Reload Plasmashell if running
if pgrep -x "plasmashell" > /dev/null 2>&1; then
    echo "Restarting plasmashell to refresh widget..."
    if command -v kquitapp6 &>/dev/null; then
        kquitapp6 plasmashell && sleep 1 && kstart6 plasmashell &>/dev/null &
    elif command -v kquitapp5 &>/dev/null; then
        kquitapp5 plasmashell && sleep 1 && kstart5 plasmashell &>/dev/null &
    elif command -v pkill &>/dev/null; then
        pkill -f plasmashell && sleep 1 && (plasmashell &>/dev/null &)
    fi
fi

echo ""
echo "============================================="
echo " Installation of minidex-lyrics Complete!"
echo "============================================="
echo "1. Right-click on Desktop or Panel -> 'Add Widgets...'"
echo "2. Search for 'minidex-lyrics'"
echo "3. Drag it onto your desktop or panel."
echo "============================================="
