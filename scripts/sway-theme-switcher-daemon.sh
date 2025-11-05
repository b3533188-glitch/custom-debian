#!/bin/bash
#==============================================================================
# Sway Theme Switcher Daemon
#
# PURPOSE: Runs 24/7 and switches theme at 06:00 (day) and 18:00 (night)
#==============================================================================

LOG_FILE="$HOME/.local/state/sway/theme-daemon.log"
THEME_SCRIPT="$HOME/.config/sway/scripts/theme-switcher.sh"
CHECK_INTERVAL=60  # Check every minute

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Sway theme switcher daemon started (PID: $$)"

# Track last transition to avoid duplicate runs
LAST_TRANSITION=""

# Main loop
while true; do
    HOUR=$(date +%H)
    MINUTE=$(date +%M)
    CURRENT_TIME="${HOUR}:${MINUTE}"

    # Check if it's 06:00 or 18:00
    if [ "$HOUR" = "06" ] && [ "$MINUTE" = "00" ] && [ "$LAST_TRANSITION" != "06:00" ]; then
        log_message "Morning transition: switching to day theme"
        if [ -f "$THEME_SCRIPT" ]; then
            "$THEME_SCRIPT" >> "$LOG_FILE" 2>&1
            LAST_TRANSITION="06:00"
        else
            log_message "ERROR: Theme script not found at $THEME_SCRIPT"
        fi
    elif [ "$HOUR" = "18" ] && [ "$MINUTE" = "00" ] && [ "$LAST_TRANSITION" != "18:00" ]; then
        log_message "Evening transition: switching to night theme"
        if [ -f "$THEME_SCRIPT" ]; then
            "$THEME_SCRIPT" >> "$LOG_FILE" 2>&1
            LAST_TRANSITION="18:00"
        else
            log_message "ERROR: Theme script not found at $THEME_SCRIPT"
        fi
    fi

    # Reset transition tracker if we're past the minute
    if [ "$MINUTE" != "00" ]; then
        if [ "$LAST_TRANSITION" = "06:00" ] || [ "$LAST_TRANSITION" = "18:00" ]; then
            LAST_TRANSITION=""
        fi
    fi

    # Sleep for 1 minute
    sleep $CHECK_INTERVAL
done
