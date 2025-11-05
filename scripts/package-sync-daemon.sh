#!/bin/bash
#==============================================================================
# Package Sync Daemon
#
# PURPOSE: Runs 24/7 and checks for package updates every 30 minutes
#==============================================================================

LOG_FILE="$HOME/.local/state/system-updater/package-sync-daemon.log"
UPDATER_SCRIPT="$HOME/.local/bin/system-updater.sh"
CHECK_INTERVAL=1800  # 30 minutes in seconds

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Package sync daemon started (PID: $$)"

# Initial delay of 5 minutes after boot (simulating OnBootSec=5min)
log_message "Waiting 5 minutes before first check..."
sleep 300

# Main loop
while true; do
    log_message "Running package sync check..."

    if [ -f "$UPDATER_SCRIPT" ]; then
        "$UPDATER_SCRIPT" check >> "$LOG_FILE" 2>&1
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            log_message "Package sync completed successfully"
        else
            log_message "Package sync failed with exit code $EXIT_CODE"
        fi
    else
        log_message "ERROR: System updater script not found at $UPDATER_SCRIPT"
    fi

    # Sleep for 30 minutes
    log_message "Sleeping for 30 minutes until next check..."
    sleep $CHECK_INTERVAL
done
