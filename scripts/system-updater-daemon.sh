#!/bin/bash
#==============================================================================
# System Updater Daemon
#
# PURPOSE: Runs 24/7 and checks for system updates every 6 hours
#==============================================================================

LOG_FILE="$HOME/.local/state/system-updater/daemon.log"
UPDATER_SCRIPT="$HOME/.local/bin/system-updater.sh"
CHECK_INTERVAL=21600  # 6 hours in seconds

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "System updater daemon started (PID: $$)"

# Initial delay of 30 minutes after boot (simulating OnBootSec=30min)
log_message "Waiting 30 minutes before first check..."
sleep 1800

# Main loop
while true; do
    log_message "Running system update check..."

    if [ -f "$UPDATER_SCRIPT" ]; then
        "$UPDATER_SCRIPT" check >> "$LOG_FILE" 2>&1
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            log_message "Update check completed successfully"
        else
            log_message "Update check failed with exit code $EXIT_CODE"
        fi
    else
        log_message "ERROR: System updater script not found at $UPDATER_SCRIPT"
    fi

    # Sleep for 6 hours
    log_message "Sleeping for 6 hours until next check..."
    sleep $CHECK_INTERVAL
done
