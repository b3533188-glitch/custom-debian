#!/bin/bash
#==============================================================================
# Wallpaper Debug Script
#
# PURPOSE: Diagnose wallpaper disappearing issues
#==============================================================================

echo "=== Wallpaper Debug Script ==="
echo "Timestamp: $(date)"
echo ""

echo "1. Checking swaybg processes:"
echo "   Running swaybg processes:"
pgrep -a swaybg | sed 's/^/     /'
echo ""

echo "2. Checking wallpaper symlink:"
WALLPAPER_LINK="$HOME/.config/wallpapers/wallpaper_current"
if [ -L "$WALLPAPER_LINK" ]; then
    echo "   Wallpaper symlink exists: $WALLPAPER_LINK"
    echo "   Points to: $(readlink -f "$WALLPAPER_LINK")"
    if [ -f "$(readlink -f "$WALLPAPER_LINK")" ]; then
        echo "   Target file exists: ✓"
    else
        echo "   Target file missing: ✗"
    fi
else
    echo "   Wallpaper symlink missing: ✗"
fi
echo ""

echo "3. Checking systemd timers:"
echo "   Active user timers:"
systemctl --user list-timers --all | grep -E "(sway-wallpaper|sway-theme-switcher)" | sed 's/^/     /' || echo "     No wallpaper timers found"
echo ""

echo "4. Checking swayidle status:"
if pgrep -x swayidle >/dev/null; then
    echo "   swayidle is running: ✓"
    echo "   swayidle command line:"
    ps -p $(pgrep -x swayidle) -o args= | sed 's/^/     /'
else
    echo "   swayidle is not running: ✗"
fi
echo ""

echo "5. Checking wallpaper scripts:"
SCRIPT_DIR="$HOME/.config/sway/scripts"
if [ -f "$SCRIPT_DIR/change-wallpaper.sh" ]; then
    echo "   change-wallpaper.sh exists: ✓"
else
    echo "   change-wallpaper.sh missing: ✗"
fi

if [ -f "$SCRIPT_DIR/idle-dpms-on.sh" ]; then
    echo "   idle-dpms-on.sh exists: ✓"
else
    echo "   idle-dpms-on.sh missing: ✗"
fi

if [ -f "$SCRIPT_DIR/idle-dpms-off.sh" ]; then
    echo "   idle-dpms-off.sh exists: ✓"
else
    echo "   idle-dpms-off.sh missing: ✗"
fi
echo ""

echo "6. Checking wallpaper log:"
LOG_FILE="$HOME/.local/state/sway/wallpaper.log"
if [ -f "$LOG_FILE" ]; then
    echo "   Last 10 wallpaper log entries:"
    tail -10 "$LOG_FILE" | sed 's/^/     /'
else
    echo "   No wallpaper log found"
fi
echo ""

echo "7. Checking sway-idle log:"
if [ -f "$HOME/sway-idle.log" ]; then
    echo "   Last 10 sway-idle log entries:"
    tail -10 "$HOME/sway-idle.log" | sed 's/^/     /'
else
    echo "   No sway-idle log found"
fi
echo ""

echo "8. Testing wallpaper script manually:"
if [ -f "$SCRIPT_DIR/change-wallpaper.sh" ]; then
    echo "   Running change-wallpaper.sh test..."
    timeout 10s "$SCRIPT_DIR/change-wallpaper.sh" 2>&1 | head -5 | sed 's/^/     /'
fi
echo ""

echo "=== Debug Complete ==="