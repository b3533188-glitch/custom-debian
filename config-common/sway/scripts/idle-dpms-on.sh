#!/bin/bash
#==============================================================================
# Idle DPMS On (Resume)
#
# PURPOSE: Turns displays back on and restarts wallpaper
#==============================================================================

SCRIPTS_DIR="$HOME/.config/sway/scripts"

# Turn displays back on
swaymsg "output * dpms on"

# Restore brightness
bash -c "$SCRIPTS_DIR/restore-brightness.sh"

# Check if wallpaper is already running to prevent unnecessary restarts
WALLPAPER_LINK="$HOME/.config/wallpapers/wallpaper_current"
if [ -f "$WALLPAPER_LINK" ]; then
    # Check if swaybg is already running with the correct wallpaper
    if pgrep -f "swaybg.*$WALLPAPER_LINK" >/dev/null 2>&1; then
        # Wallpaper is already being displayed correctly
        exit 0
    fi
    
    # Only restart if wallpaper is not being displayed
    # Start new swaybg without killing existing ones to prevent conflicts
    swaybg -i "$WALLPAPER_LINK" -m fill &
    NEW_PID=$!
    
    # Give it time to start
    sleep 0.5
    
    # Only kill old swaybg processes if the new one started successfully
    if kill -0 "$NEW_PID" 2>/dev/null; then
        for pid in $(pgrep -x swaybg); do
            if [ "$pid" != "$NEW_PID" ]; then
                kill "$pid" 2>/dev/null || true
            fi
        done
    fi
fi
