#!/bin/bash

# Check dependencies
missing_deps=()
for dep in tar gzip notify-send; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
    exit 1
fi

# Backup configuration files
BACKUP_DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$HOME/.config-backup-$BACKUP_DATE"
BACKUP_FILE="$HOME/config-backup-$BACKUP_DATE.tar.gz"

echo "Creating backup of configuration files..."

# Create temporary backup directory
mkdir -p "$BACKUP_DIR"

# Copy configuration directories
if [ -d "$HOME/.config/sway" ]; then
    cp -r "$HOME/.config/sway" "$BACKUP_DIR/" 2>/dev/null || true
fi

if [ -d "$HOME/.config/waybar" ]; then
    cp -r "$HOME/.config/waybar" "$BACKUP_DIR/" 2>/dev/null || true
fi

if [ -d "$HOME/.config/kitty" ]; then
    cp -r "$HOME/.config/kitty" "$BACKUP_DIR/" 2>/dev/null || true
fi

if [ -d "$HOME/.config/wofi" ]; then
    cp -r "$HOME/.config/wofi" "$BACKUP_DIR/" 2>/dev/null || true
fi

if [ -d "$HOME/.config/gammastep" ]; then
    cp -r "$HOME/.config/gammastep" "$BACKUP_DIR/" 2>/dev/null || true
fi

# Copy dotfiles
for dotfile in .profile .bashrc .zshrc; do
    if [ -f "$HOME/$dotfile" ]; then
        cp "$HOME/$dotfile" "$BACKUP_DIR/" 2>/dev/null || true
    fi
done

# Create compressed archive
if tar -czf "$BACKUP_FILE" -C "$(dirname "$BACKUP_DIR")" "$(basename "$BACKUP_DIR")" 2>/dev/null; then
    # Clean up temporary directory
    rm -rf "$BACKUP_DIR"

    # Get file size
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

    echo "Backup created successfully: $BACKUP_FILE ($SIZE)"
    notify-send "Backup Complete" "Configuration backup saved: ~/config-backup-$BACKUP_DATE.tar.gz ($SIZE)"
else
    echo "Error: Failed to create backup archive" >&2
    rm -rf "$BACKUP_DIR"
    exit 1
fi