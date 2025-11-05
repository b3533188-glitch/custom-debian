#!/bin/bash

# Script to run backup system in floating terminal

BACKUP_SCRIPT="$HOME/.local/bin/backup-system.sh"

if [ ! -f "$BACKUP_SCRIPT" ]; then
    notify-send "Backup System" "Error: Backup script not found" -u critical
    exit 1
fi

# Open backup system in floating terminal
kitty --app-id floating-terminal --title "Backup System" -e "$BACKUP_SCRIPT" interactive &
