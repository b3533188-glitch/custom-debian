#!/bin/bash

# Backup Manager for Debian System
# Supports encrypted (GPG) and unencrypted backups
# Supports automatic scheduling

STATE_DIR="$HOME/.local/state/backup-manager"
CONFIG_FILE="$HOME/.config/backup-manager/config"
LOG_FILE="$STATE_DIR/backup.log"

mkdir -p "$STATE_DIR"
mkdir -p "$(dirname "$CONFIG_FILE")"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Defaults
        BACKUP_SOURCE="$HOME"
        BACKUP_DEST="$HOME/Backups"
        ENCRYPT_BACKUP="false"
        AUTO_BACKUP_DAYS="7"
        GPG_RECIPIENT=""
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
BACKUP_SOURCE="$BACKUP_SOURCE"
BACKUP_DEST="$BACKUP_DEST"
ENCRYPT_BACKUP="$ENCRYPT_BACKUP"
AUTO_BACKUP_DAYS="$AUTO_BACKUP_DAYS"
GPG_RECIPIENT="$GPG_RECIPIENT"
EOF
}

# Create backup
create_backup() {
    local source="$1"
    local dest="$2"
    local encrypt="$3"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${timestamp}.tar.gz"

    mkdir -p "$dest"

    echo "Creating backup..."
    echo "Source: $source"
    echo "Destination: $dest/$backup_name"
    echo ""

    # Create tar archive
    if tar -czf "$dest/$backup_name" -C "$(dirname "$source")" "$(basename "$source")" 2>/dev/null; then
        echo "✓ Archive created successfully"

        if [ "$encrypt" = "true" ]; then
            echo "Encrypting backup..."
            if gpg --encrypt --recipient "$GPG_RECIPIENT" "$dest/$backup_name"; then
                rm "$dest/$backup_name"
                backup_name="${backup_name}.gpg"
                echo "✓ Backup encrypted"
            else
                echo "✗ Encryption failed"
                return 1
            fi
        fi

        echo ""
        echo "✓ Backup completed: $dest/$backup_name"
        echo "[$(date)] Backup created: $dest/$backup_name" >> "$LOG_FILE"
        return 0
    else
        echo "✗ Backup failed"
        return 1
    fi
}

# Restore backup
restore_backup() {
    local backup_file="$1"
    local restore_dest="$2"

    if [ ! -f "$backup_file" ]; then
        echo "✗ Backup file not found: $backup_file"
        return 1
    fi

    echo "Restoring backup..."
    echo "From: $backup_file"
    echo "To: $restore_dest"
    echo ""

    # Check if encrypted
    if [[ "$backup_file" == *.gpg ]]; then
        echo "Decrypting backup..."
        local decrypted="${backup_file%.gpg}"
        if gpg --decrypt --output "$decrypted" "$backup_file"; then
            echo "✓ Decrypted"
            backup_file="$decrypted"
        else
            echo "✗ Decryption failed"
            return 1
        fi
    fi

    # Extract
    mkdir -p "$restore_dest"
    if tar -xzf "$backup_file" -C "$restore_dest"; then
        echo ""
        echo "✓ Restore completed"
        echo "[$(date)] Restore completed from: $backup_file" >> "$LOG_FILE"

        # Cleanup decrypted file if it was encrypted
        if [[ "$1" == *.gpg ]]; then
            rm "$backup_file"
        fi
        return 0
    else
        echo "✗ Restore failed"
        return 1
    fi
}

# Interactive mode
interactive_mode() {
    load_config

    while true; do
        clear
        echo "╔════════════════════════════════════════╗"
        echo "║       BACKUP MANAGER                   ║"
        echo "╚════════════════════════════════════════╝"
        echo ""
        echo "1) Create Backup"
        echo "2) Restore Backup"
        echo "3) Configure Settings"
        echo "4) View Backup History"
        echo "5) Exit"
        echo ""
        read -p "Select option: " choice

        case $choice in
            1)
                echo ""
                echo "=== CREATE BACKUP ==="
                echo ""
                read -p "Source path [$BACKUP_SOURCE]: " input
                [ -n "$input" ] && BACKUP_SOURCE="$input"

                read -p "Destination path [$BACKUP_DEST]: " input
                [ -n "$input" ] && BACKUP_DEST="$input"

                read -p "Encrypt backup? (y/N): " encrypt
                if [[ "$encrypt" =~ ^[Yy]$ ]]; then
                    read -p "GPG recipient email: " GPG_RECIPIENT
                    ENCRYPT_BACKUP="true"
                else
                    ENCRYPT_BACKUP="false"
                fi

                echo ""
                create_backup "$BACKUP_SOURCE" "$BACKUP_DEST" "$ENCRYPT_BACKUP"

                save_config
                echo ""
                read -p "Press Enter to continue..."
                ;;
            2)
                echo ""
                echo "=== RESTORE BACKUP ==="
                echo ""
                read -p "Backup file path: " backup_file
                read -p "Restore to path [$HOME]: " restore_dest
                [ -z "$restore_dest" ] && restore_dest="$HOME"

                echo ""
                restore_backup "$backup_file" "$restore_dest"

                echo ""
                read -p "Press Enter to continue..."
                ;;
            3)
                echo ""
                echo "=== CONFIGURE SETTINGS ==="
                echo ""
                echo "Current settings:"
                echo "  Source: $BACKUP_SOURCE"
                echo "  Destination: $BACKUP_DEST"
                echo "  Encryption: $ENCRYPT_BACKUP"
                echo "  Auto-backup interval: $AUTO_BACKUP_DAYS days"
                echo ""
                read -p "Default source path [$BACKUP_SOURCE]: " input
                [ -n "$input" ] && BACKUP_SOURCE="$input"

                read -p "Default destination [$BACKUP_DEST]: " input
                [ -n "$input" ] && BACKUP_DEST="$input"

                read -p "Auto-backup interval (days) [$AUTO_BACKUP_DAYS]: " input
                [ -n "$input" ] && AUTO_BACKUP_DAYS="$input"

                save_config
                echo ""
                echo "✓ Settings saved"
                read -p "Press Enter to continue..."
                ;;
            4)
                echo ""
                echo "=== BACKUP HISTORY ==="
                echo ""
                if [ -f "$LOG_FILE" ]; then
                    tail -20 "$LOG_FILE"
                else
                    echo "No backup history found"
                fi
                echo ""
                read -p "Press Enter to continue..."
                ;;
            5)
                exit 0
                ;;
        esac
    done
}

# Auto backup check
auto_backup_check() {
    load_config

    local last_backup_file="$STATE_DIR/last_backup"
    local now=$(date +%s)

    if [ -f "$last_backup_file" ]; then
        local last_backup=$(cat "$last_backup_file")
        local days_diff=$(( (now - last_backup) / 86400 ))

        if [ "$days_diff" -lt "$AUTO_BACKUP_DAYS" ]; then
            echo "Next backup in $(($AUTO_BACKUP_DAYS - days_diff)) days"
            return 0
        fi
    fi

    echo "Auto-backup due, creating backup..."
    if create_backup "$BACKUP_SOURCE" "$BACKUP_DEST" "$ENCRYPT_BACKUP"; then
        echo "$now" > "$last_backup_file"
    fi
}

# Main
case "${1:-interactive}" in
    "interactive")
        interactive_mode
        ;;
    "create")
        load_config
        create_backup "${2:-$BACKUP_SOURCE}" "${3:-$BACKUP_DEST}" "${4:-$ENCRYPT_BACKUP}"
        ;;
    "restore")
        restore_backup "$2" "${3:-$HOME}"
        ;;
    "auto-check")
        auto_backup_check
        ;;
    *)
        echo "Usage: $0 {interactive|create [source] [dest] [encrypt]|restore [file] [dest]|auto-check}"
        exit 1
        ;;
esac
