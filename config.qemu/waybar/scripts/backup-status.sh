#!/bin/bash

STATE_DIR="$HOME/.local/state/backup-system"
CONFIG_FILE="$HOME/.config/backup-system/config"
LAST_BACKUP_FILE="$STATE_DIR/last_backup_time"

# Load config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    REMINDER_ENABLED="false"
    REMINDER_DAYS="14"
fi

# Get last backup time
if [ -f "$LAST_BACKUP_FILE" ]; then
    last_backup=$(cat "$LAST_BACKUP_FILE")
    now=$(date +%s)
    days_since=$(( (now - last_backup) / 86400 ))

    # Determine status
    if [ "$days_since" -lt 7 ]; then
        # Recent backup
        text="💾"
        tooltip="Last backup: $days_since day(s) ago\nStatus: Up to date"
        class="backup-ok"
    elif [ "$days_since" -lt "${REMINDER_DAYS:-14}" ]; then
        # Getting old
        text="💾"
        tooltip="Last backup: $days_since day(s) ago\nStatus: Consider backing up soon"
        class="backup-warning"
    else
        # Overdue
        text="💾 !"
        tooltip="Last backup: $days_since day(s) ago\nStatus: Backup recommended"
        class="backup-critical"
    fi
else
    # Never backed up
    text="💾 !"
    tooltip="No backup found\nStatus: Create your first backup"
    class="backup-critical"
fi

# Output JSON
echo "{\"text\": \"$text\", \"tooltip\": \"$tooltip\", \"class\": \"$class\"}"
