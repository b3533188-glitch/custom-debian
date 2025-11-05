#!/bin/bash
#==============================================================================
# Manual Configuration Update Sync
#
# PURPOSE: Updates system-updater state after manual config update via main.sh
#          This prevents the system-updater from showing pending updates
#==============================================================================

REPO_DIR="$HOME/.local/share/custom-debian-repo"
COMMIT_FILE="$HOME/.local/state/system-updater/installed_commit"
LOG_FILE="$HOME/.local/state/system-updater/manual-update.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_message "Starting manual configuration update sync..."

# Ensure repository exists and is updated
if [ ! -d "$REPO_DIR/.git" ]; then
    log_message "ERROR: Repository not found at $REPO_DIR"
    exit 1
fi

cd "$REPO_DIR"

# Fetch latest changes
git fetch origin main >/dev/null 2>&1

# Get current commit
CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)
if [ -z "$CURRENT_COMMIT" ]; then
    log_message "ERROR: Could not get current commit"
    exit 1
fi

# Update commit file
mkdir -p "$(dirname "$COMMIT_FILE")"
echo "$CURRENT_COMMIT" > "$COMMIT_FILE"

log_message "Updated installed commit to: ${CURRENT_COMMIT:0:8}"
log_message "Manual configuration update sync completed"

# Send notification if possible
if command -v notify-send >/dev/null 2>&1; then
    notify-send "Configuration Updated" "System updater state synchronized" --icon=preferences-system
fi

exit 0