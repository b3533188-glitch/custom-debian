#!/bin/bash
#==============================================================================
# Sway Wallpaper Daemon
#
# PURPOSE: Runs 24/7 and changes wallpaper every 30 minutes
#          Also checks at 06:00 and 18:00 for day/night transition
#==============================================================================

LOG_FILE="$HOME/.local/state/sway/wallpaper-daemon.log"
WALLPAPER_SCRIPT="$HOME/.config/sway/scripts/change-wallpaper.sh"
CHECK_INTERVAL=1800  # 30 minutes

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Sway wallpaper daemon started (PID: $$)"

# Function to check if it's time for day/night transition
check_transition_time() {
    local hour=$(date +%H)
    local minute=$(date +%M)

    # Check if it's 06:00 or 18:00 (±1 minute tolerance)
    if ([ "$hour" = "06" ] && [ "$minute" -le "01" ]) || \
       ([ "$hour" = "18" ] && [ "$minute" -le "01" ]); then
        return 0  # It's transition time
    fi
    return 1
}

# Main loop
while true; do
    # Run wallpaper change
    if [ -f "$WALLPAPER_SCRIPT" ]; then
        "$WALLPAPER_SCRIPT" >> "$LOG_FILE" 2>&1
    else
        log_message "ERROR: Wallpaper script not found at $WALLPAPER_SCRIPT"
    fi

    # Sleep for 30 minutes
    sleep $CHECK_INTERVAL

    # After waking up, check if we need immediate transition check
    if check_transition_time; then
        log_message "Transition time detected, running immediate wallpaper change"
        if [ -f "$WALLPAPER_SCRIPT" ]; then
            "$WALLPAPER_SCRIPT" >> "$LOG_FILE" 2>&1
        fi
    fi
done
