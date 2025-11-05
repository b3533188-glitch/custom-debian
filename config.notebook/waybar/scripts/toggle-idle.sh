#!/bin/bash
#==============================================================================
# Waybar Idle Toggle Script (Corrected)
#
# PURPOSE: Toggles the swayidle daemon on and off.
#          - If called with --toggle, it kills/restarts the swayidle daemon.
#          - Otherwise, it outputs JSON for Waybar to display the current status.
#==============================================================================

IDLE_START_SCRIPT="$HOME/.config/sway/scripts/start-idle.sh"
STATE_FILE="$HOME/.config/sway/.idle-state"

# --toggle action: kill or restart the idle daemon
if [[ "$1" == "--toggle" ]]; then
    if pgrep -x "swayidle" > /dev/null; then
        # swayidle is running, so kill it to INHIBIT locking
        pkill -x "swayidle"
        echo "disabled" > "$STATE_FILE"
        notify-send -u low -t 2000 "Sway Idle Inhibited" "Automatic locking is now OFF" --icon=changes-prevent
    else
        # swayidle is not running, so start it to ACTIVATE locking
        echo "enabled" > "$STATE_FILE"
        "$IDLE_START_SCRIPT" &
        notify-send -u low -t 2000 "Sway Idle Activated" "Automatic locking is now ON" --icon=system-lock-screen
    fi
    exit 0
fi

# Default action: display status for Waybar
if pgrep -x "swayidle" > /dev/null; then
    # swayidle is running -> Lock is ACTIVE
    echo '{"text":"", "tooltip":"Idle lock is ACTIVE (click to disable)", "class":"active"}'
else
    # swayidle is not running -> Lock is INHIBITED
    echo '{"text":"", "tooltip":"Idle lock is INHIBITED (click to enable)", "class":"inhibited"}'
fi
