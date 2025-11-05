#!/bin/bash

# Backup System for Debian - Interactive backup management with GPG support

STATE_DIR="$HOME/.local/state/backup-system"
CONFIG_FILE="$HOME/.config/backup-system/config"
LOG_FILE="$STATE_DIR/backup.log"
BACKUP_LIST="$STATE_DIR/backup_sources"
LAST_BACKUP_FILE="$STATE_DIR/last_backup_time"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

# Create necessary directories
mkdir -p "$STATE_DIR" "$(dirname "$CONFIG_FILE")"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        # Defaults
        BACKUP_DEST="$HOME/Backups"
        ENCRYPT_BACKUP="false"
        GPG_RECIPIENT=""
        AUTO_BACKUP_ENABLED="false"
        AUTO_BACKUP_INTERVAL="7"  # days
        REMINDER_ENABLED="false"
        REMINDER_DAYS="14"
        REMOVE_OLD_BACKUP="false"
    fi
}

# Save configuration
save_config() {
    cat > "$CONFIG_FILE" << EOF
BACKUP_DEST="$BACKUP_DEST"
ENCRYPT_BACKUP="$ENCRYPT_BACKUP"
GPG_RECIPIENT="$GPG_RECIPIENT"
AUTO_BACKUP_ENABLED="$AUTO_BACKUP_ENABLED"
AUTO_BACKUP_INTERVAL="$AUTO_BACKUP_INTERVAL"
REMINDER_ENABLED="$REMINDER_ENABLED"
REMINDER_DAYS="$REMINDER_DAYS"
REMOVE_OLD_BACKUP="$REMOVE_OLD_BACKUP"
EOF
}

# Draw box
draw_box() {
    local text="$1"
    local color="${2:-$CYAN}"
    local length=$((${#text} + 2))
    echo -e "${color}┌$(printf '─%.0s' $(seq 1 $length))┐${NC}"
    echo -e "${color}│ ${BOLD}$text${NC}${color} │${NC}"
    echo -e "${color}└$(printf '─%.0s' $(seq 1 $length))┘${NC}"
}

# Progress bar function
show_progress() {
    local message="$1"
    local percent="$2"
    local width=40
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    printf "\r${CYAN}%s${NC} [" "$message"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] ${BOLD}%3d%%${NC}" "$percent"
}

# Load backup sources
load_sources() {
    if [ -f "$BACKUP_LIST" ]; then
        mapfile -t SOURCES < "$BACKUP_LIST"
    else
        SOURCES=()
    fi
}

# Save backup sources
save_sources() {
    printf "%s\n" "${SOURCES[@]}" > "$BACKUP_LIST"
}

# Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_name="backup_${timestamp}.tar.gz"
    local backup_path="$BACKUP_DEST/$backup_name"

    mkdir -p "$BACKUP_DEST"

    echo ""
    draw_box "CREATING BACKUP" "$CYAN"
    echo ""

    # Check if there are sources
    if [ ${#SOURCES[@]} -eq 0 ]; then
        echo -e "${RED}Error: No backup sources configured${NC}"
        echo ""
        echo -e "${GRAY}Press Enter to continue...${NC}"
        read
        return 1
    fi

    # Display sources
    echo -e "${CYAN}Backup sources:${NC}"
    for source in "${SOURCES[@]}"; do
        echo -e "  ${BOLD}•${NC} $source"
    done
    echo ""
    echo -e "${CYAN}Destination:${NC} $BACKUP_DEST"
    echo -e "${CYAN}Encryption:${NC} $ENCRYPT_BACKUP"
    echo ""

    # Remove old backup if configured
    if [ "$REMOVE_OLD_BACKUP" = "true" ]; then
        show_progress "Removing old backups..." 10
        find "$BACKUP_DEST" -name "backup_*.tar.gz*" -type f -delete 2>/dev/null
        show_progress "Removing old backups..." 100
        echo ""
        echo -e "${GREEN}✓${NC} Old backups removed"
        echo ""
    fi

    # Create temporary file list
    local temp_list=$(mktemp)
    printf "%s\n" "${SOURCES[@]}" > "$temp_list"

    # Calculate total size for progress estimation
    local total_size=0
    for source in "${SOURCES[@]}"; do
        if [ -e "$source" ]; then
            total_size=$((total_size + $(du -sb "$source" 2>/dev/null | cut -f1)))
        fi
    done

    # Create tar archive with progress
    show_progress "Creating archive..." 0
    (
        tar -czf "$backup_path" -T "$temp_list" 2>/dev/null &
        tar_pid=$!

        while kill -0 $tar_pid 2>/dev/null; do
            if [ -f "$backup_path" ]; then
                current_size=$(stat -f%z "$backup_path" 2>/dev/null || stat -c%s "$backup_path" 2>/dev/null || echo 0)
                if [ "$total_size" -gt 0 ]; then
                    percent=$((current_size * 70 / total_size))
                    [ $percent -gt 70 ] && percent=70
                else
                    percent=35
                fi
                show_progress "Creating archive..." $percent
            fi
            sleep 0.2
        done
        wait $tar_pid
        return $?
    )

    if [ $? -eq 0 ]; then
        show_progress "Creating archive..." 70
        echo ""
        echo -e "${GREEN}✓${NC} Archive created successfully"
        rm "$temp_list"
    else
        echo ""
        echo -e "${RED}✗${NC} Failed to create archive"
        rm "$temp_list"
        echo ""
        echo -e "${GRAY}Press Enter to continue...${NC}"
        read
        return 1
    fi

    # Encrypt if configured
    if [ "$ENCRYPT_BACKUP" = "true" ]; then
        echo ""
        show_progress "Encrypting with GPG..." 70

        if gpg --encrypt --recipient "$GPG_RECIPIENT" "$backup_path" 2>/dev/null & then
            gpg_pid=$!

            while kill -0 $gpg_pid 2>/dev/null; do
                show_progress "Encrypting with GPG..." 85
                sleep 0.2
            done
            wait $gpg_pid
            gpg_result=$?

            if [ $gpg_result -eq 0 ]; then
                show_progress "Encrypting with GPG..." 100
                echo ""
                rm "$backup_path"
                backup_name="${backup_name}.gpg"
                backup_path="${backup_path}.gpg"
                echo -e "${GREEN}✓${NC} Backup encrypted"
            else
                echo ""
                echo -e "${RED}✗${NC} Encryption failed"
                echo ""
                echo -e "${GRAY}Press Enter to continue...${NC}"
                read
                return 1
            fi
        fi
    else
        show_progress "Finalizing backup..." 100
        echo ""
    fi

    # Calculate size
    local size=$(du -h "$backup_path" | cut -f1)

    echo ""
    echo -e "${GREEN}✓ BACKUP COMPLETED${NC}"
    echo -e "${GRAY}File: $backup_name${NC}"
    echo -e "${GRAY}Size: $size${NC}"
    echo ""

    # Log
    echo "[$(date)] Backup created: $backup_path (Size: $size)" >> "$LOG_FILE"

    # Update last backup time
    date +%s > "$LAST_BACKUP_FILE"

    # Update waybar status
    pkill -RTMIN+12 waybar 2>/dev/null || true

    # Send notification
    notify-send "Backup System" "Backup completed successfully\nSize: $size" -u normal

    echo -e "${GRAY}Press Enter to continue...${NC}"
    read
    return 0
}

# Manage backup sources
manage_sources() {
    while true; do
        clear
        echo ""
        draw_box "BACKUP SOURCES" "$CYAN"
        echo ""

        if [ ${#SOURCES[@]} -eq 0 ]; then
            echo -e "${GRAY}No sources configured${NC}"
        else
            for i in "${!SOURCES[@]}"; do
                echo -e "${BOLD}$((i+1)).${NC} ${SOURCES[$i]}"
            done
        fi

        echo ""
        echo -e "${BOLD}Options:${NC}"
        echo "  a) Add source"
        echo "  r) Remove source"
        echo "  c) Clear all"
        echo "  b) Back"
        echo ""
        echo -n "Select option: "
        read -n 1 -s choice
        echo ""

        case $choice in
            a)
                echo ""
                read -p "Enter path to backup: " new_source
                if [ -z "$new_source" ]; then
                    continue
                fi
                # Expand tilde
                new_source="${new_source/#\~/$HOME}"
                if [ ! -e "$new_source" ]; then
                    echo -e "${RED}Path does not exist: $new_source${NC}"
                    sleep 2
                    continue
                fi
                SOURCES+=("$new_source")
                save_sources
                echo -e "${GREEN}✓${NC} Source added"
                sleep 1
                ;;
            r)
                if [ ${#SOURCES[@]} -eq 0 ]; then
                    continue
                fi
                echo ""
                read -p "Enter number to remove: " num
                if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#SOURCES[@]}" ]; then
                    unset 'SOURCES[$((num-1))]'
                    SOURCES=("${SOURCES[@]}")  # Re-index
                    save_sources
                    echo -e "${GREEN}✓${NC} Source removed"
                    sleep 1
                fi
                ;;
            c)
                SOURCES=()
                save_sources
                echo -e "${GREEN}✓${NC} All sources cleared"
                sleep 1
                ;;
            b)
                break
                ;;
        esac
    done
}

# Configure settings
configure_settings() {
    while true; do
        clear
        echo ""
        draw_box "BACKUP SETTINGS" "$CYAN"
        echo ""

        echo -e "${BOLD}Current settings:${NC}"
        echo -e "  Destination:       ${CYAN}$BACKUP_DEST${NC}"
        echo -e "  Encryption:        ${CYAN}$ENCRYPT_BACKUP${NC}"
        if [ "$ENCRYPT_BACKUP" = "true" ]; then
            echo -e "  GPG Recipient:     ${CYAN}$GPG_RECIPIENT${NC}"
        fi
        echo -e "  Auto Backup:       ${CYAN}$AUTO_BACKUP_ENABLED${NC}"
        if [ "$AUTO_BACKUP_ENABLED" = "true" ]; then
            echo -e "  Backup Interval:   ${CYAN}$AUTO_BACKUP_INTERVAL days${NC}"
        fi
        echo -e "  Reminder:          ${CYAN}$REMINDER_ENABLED${NC}"
        if [ "$REMINDER_ENABLED" = "true" ]; then
            echo -e "  Reminder After:    ${CYAN}$REMINDER_DAYS days${NC}"
        fi
        echo -e "  Remove Old:        ${CYAN}$REMOVE_OLD_BACKUP${NC}"
        echo ""

        echo -e "${BOLD}Options:${NC}"
        echo "  1) Change destination"
        echo "  2) Toggle encryption"
        echo "  3) Toggle auto backup"
        echo "  4) Toggle reminder"
        echo "  5) Toggle remove old backups"
        echo "  b) Back"
        echo ""
        echo -n "Select option: "
        read -n 1 -s choice
        echo ""

        case $choice in
            1)
                echo ""
                read -p "Enter backup destination [$BACKUP_DEST]: " input
                if [ -n "$input" ]; then
                    BACKUP_DEST="${input/#\~/$HOME}"
                    mkdir -p "$BACKUP_DEST"
                fi
                save_config
                ;;
            2)
                if [ "$ENCRYPT_BACKUP" = "true" ]; then
                    ENCRYPT_BACKUP="false"
                else
                    ENCRYPT_BACKUP="true"
                    echo ""
                    read -p "Enter GPG recipient email: " GPG_RECIPIENT
                fi
                save_config
                ;;
            3)
                if [ "$AUTO_BACKUP_ENABLED" = "true" ]; then
                    AUTO_BACKUP_ENABLED="false"
                else
                    AUTO_BACKUP_ENABLED="true"
                    echo ""
                    read -p "Backup interval (days) [$AUTO_BACKUP_INTERVAL]: " input
                    if [ -n "$input" ]; then
                        AUTO_BACKUP_INTERVAL="$input"
                    fi
                fi
                save_config
                ;;
            4)
                if [ "$REMINDER_ENABLED" = "true" ]; then
                    REMINDER_ENABLED="false"
                else
                    REMINDER_ENABLED="true"
                    echo ""
                    read -p "Remind after (days) [$REMINDER_DAYS]: " input
                    if [ -n "$input" ]; then
                        REMINDER_DAYS="$input"
                    fi
                fi
                save_config
                ;;
            5)
                if [ "$REMOVE_OLD_BACKUP" = "true" ]; then
                    REMOVE_OLD_BACKUP="false"
                else
                    REMOVE_OLD_BACKUP="true"
                fi
                save_config
                ;;
            b)
                break
                ;;
        esac
    done
}

# View backup history
view_history() {
    clear
    echo ""
    draw_box "BACKUP HISTORY" "$CYAN"
    echo ""

    if [ ! -f "$LOG_FILE" ]; then
        echo -e "${GRAY}No backup history${NC}"
    else
        tail -20 "$LOG_FILE"
    fi

    echo ""
    echo -e "${GRAY}Press Enter to continue...${NC}"
    read
}

# Restore backup
restore_backup() {
    clear
    echo ""
    draw_box "RESTORE BACKUP" "$CYAN"
    echo ""

    # List available backups
    echo -e "${CYAN}Available backups:${NC}"
    local backups=($(find "$BACKUP_DEST" -name "backup_*.tar.gz*" -type f 2>/dev/null | sort -r))

    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${GRAY}No backups found${NC}"
        echo ""
        echo -e "${GRAY}Press Enter to continue...${NC}"
        read
        return
    fi

    for i in "${!backups[@]}"; do
        local file=$(basename "${backups[$i]}")
        local size=$(du -h "${backups[$i]}" | cut -f1)
        echo -e "${BOLD}$((i+1)).${NC} $file ${GRAY}($size)${NC}"
    done

    echo ""
    read -p "Select backup to restore (or 'q' to cancel): " choice

    if [ "$choice" = "q" ]; then
        return
    fi

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#backups[@]}" ]; then
        echo -e "${RED}Invalid selection${NC}"
        sleep 2
        return
    fi

    local backup_file="${backups[$((choice-1))]}"

    echo ""
    read -p "Restore to path [$HOME]: " restore_dest
    [ -z "$restore_dest" ] && restore_dest="$HOME"

    echo ""

    # Check if encrypted
    local temp_file="$backup_file"
    if [[ "$backup_file" == *.gpg ]]; then
        show_progress "Decrypting backup..." 0

        gpg --decrypt --output "${backup_file%.gpg}" "$backup_file" 2>/dev/null &
        gpg_pid=$!

        while kill -0 $gpg_pid 2>/dev/null; do
            show_progress "Decrypting backup..." 30
            sleep 0.2
        done
        wait $gpg_pid
        gpg_result=$?

        if [ $gpg_result -eq 0 ]; then
            show_progress "Decrypting backup..." 50
            echo ""
            echo -e "${GREEN}✓${NC} Decrypted"
            temp_file="${backup_file%.gpg}"
        else
            echo ""
            echo -e "${RED}✗${NC} Decryption failed"
            echo ""
            echo -e "${GRAY}Press Enter to continue...${NC}"
            read
            return
        fi
    fi

    # Extract with progress
    show_progress "Extracting archive..." 50
    mkdir -p "$restore_dest"

    tar -xzf "$temp_file" -C "$restore_dest" 2>/dev/null &
    tar_pid=$!

    while kill -0 $tar_pid 2>/dev/null; do
        show_progress "Extracting archive..." 75
        sleep 0.2
    done
    wait $tar_pid
    tar_result=$?

    if [ $tar_result -eq 0 ]; then
        show_progress "Extracting archive..." 100
        echo ""
        echo -e "${GREEN}✓${NC} Restore completed"

        # Cleanup decrypted file if it was encrypted
        if [[ "$backup_file" == *.gpg ]] && [ "$temp_file" != "$backup_file" ]; then
            rm -f "$temp_file"
        fi
    else
        echo ""
        echo -e "${RED}✗${NC} Restore failed"
    fi

    echo ""
    echo -e "${GRAY}Press Enter to continue...${NC}"
    read
}

# Main menu
main_menu() {
    load_config
    load_sources

    while true; do
        clear
        echo ""
        draw_box "BACKUP SYSTEM" "$CYAN"
        echo ""

        # Show last backup time
        if [ -f "$LAST_BACKUP_FILE" ]; then
            local last_backup=$(cat "$LAST_BACKUP_FILE")
            local now=$(date +%s)
            local days_ago=$(( (now - last_backup) / 86400 ))
            echo -e "${GRAY}Last backup: $days_ago day(s) ago${NC}"
            echo ""
        fi

        echo -e "${BOLD}1)${NC} Create Backup"
        echo -e "${BOLD}2)${NC} Manage Sources"
        echo -e "${BOLD}3)${NC} Configure Settings"
        echo -e "${BOLD}4)${NC} View History"
        echo -e "${BOLD}5)${NC} Restore Backup"
        echo -e "${BOLD}6)${NC} Exit"
        echo ""
        echo -n "Select option: "
        read -n 1 -s choice
        echo ""

        case $choice in
            1) create_backup ;;
            2) manage_sources ;;
            3) configure_settings ;;
            4) view_history ;;
            5) restore_backup ;;
            6) exit 0 ;;
        esac
    done
}

# Check if auto backup is due
check_auto_backup() {
    load_config

    if [ "$AUTO_BACKUP_ENABLED" != "true" ]; then
        return
    fi

    local now=$(date +%s)
    local last_backup=0

    if [ -f "$LAST_BACKUP_FILE" ]; then
        last_backup=$(cat "$LAST_BACKUP_FILE")
    fi

    local days_since=$(( (now - last_backup) / 86400 ))

    if [ "$days_since" -ge "$AUTO_BACKUP_INTERVAL" ]; then
        # Send notification
        notify-send "Backup System" "Starting automatic backup..." -u normal

        # Load sources and create backup
        load_sources

        # Create backup silently
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_name="backup_${timestamp}.tar.gz"
        local backup_path="$BACKUP_DEST/$backup_name"

        mkdir -p "$BACKUP_DEST"

        if [ ${#SOURCES[@]} -eq 0 ]; then
            notify-send "Backup System" "Auto backup failed: No sources configured" -u critical
            return
        fi

        # Remove old if configured
        if [ "$REMOVE_OLD_BACKUP" = "true" ]; then
            find "$BACKUP_DEST" -name "backup_*.tar.gz*" -type f -delete 2>/dev/null
        fi

        # Create archive
        local temp_list=$(mktemp)
        printf "%s\n" "${SOURCES[@]}" > "$temp_list"

        if tar -czf "$backup_path" -T "$temp_list" 2>/dev/null; then
            rm "$temp_list"

            # Encrypt if needed
            if [ "$ENCRYPT_BACKUP" = "true" ]; then
                if gpg --encrypt --recipient "$GPG_RECIPIENT" "$backup_path" 2>/dev/null; then
                    rm "$backup_path"
                    backup_path="${backup_path}.gpg"
                fi
            fi

            local size=$(du -h "$backup_path" | cut -f1)
            echo "[$(date)] Auto backup created: $backup_path (Size: $size)" >> "$LOG_FILE"
            date +%s > "$LAST_BACKUP_FILE"

            notify-send "Backup System" "Auto backup completed\nSize: $size" -u normal
        else
            rm "$temp_list"
            notify-send "Backup System" "Auto backup failed" -u critical
        fi
    fi
}

# Check if reminder is due
check_reminder() {
    load_config

    if [ "$REMINDER_ENABLED" != "true" ]; then
        return
    fi

    local now=$(date +%s)
    local last_backup=0

    if [ -f "$LAST_BACKUP_FILE" ]; then
        last_backup=$(cat "$LAST_BACKUP_FILE")
    fi

    local days_since=$(( (now - last_backup) / 86400 ))

    if [ "$days_since" -ge "$REMINDER_DAYS" ]; then
        notify-send "Backup System" "It's been $days_since days since last backup\nConsider creating a new backup" -u normal
    fi
}

# Main
case "${1:-interactive}" in
    "interactive")
        main_menu
        ;;
    "auto-backup")
        check_auto_backup
        ;;
    "reminder")
        check_reminder
        ;;
    *)
        echo "Usage: $0 {interactive|auto-backup|reminder}"
        exit 1
        ;;
esac
