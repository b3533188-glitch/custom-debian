#!/bin/bash
#==============================================================================
# Sway Lock Screen Script
#
# PURPOSE: Locks the screen using swaylock with a pre-defined Nord theme.
#          It uses the currently set wallpaper as the background image.
#          Sends D-Bus signals for applications like KeePassXC to lock.
#==============================================================================

# Function to safely log with rotation
log_message() {
    local LOG_DIR="$HOME/.local/state/sway"
    mkdir -p "$LOG_DIR"
    local LOG_FILE="$LOG_DIR/idle.log"

    # Rotate log if it gets too large (>1MB)
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
    fi

    echo "[$(date)] $1" >> "$LOG_FILE"
}

log_message "Locking screen"

# Send lock signal to D-Bus (for KeePassXC and other apps)
dbus-send --session --type=signal /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver.ActiveChanged boolean:true 2>/dev/null &

# Ensure wallpaper_current exists, if not create it
if [ ! -f "$HOME/.config/wallpapers/wallpaper_current" ]; then
    # Try to run change-wallpaper script to create the link
    if [ -f "$HOME/.config/sway/scripts/change-wallpaper.sh" ]; then
        "$HOME/.config/sway/scripts/change-wallpaper.sh"
    fi
fi

# If still no wallpaper_current, find any available wallpaper
if [ ! -f "$HOME/.config/wallpapers/wallpaper_current" ]; then
    FALLBACK_WALLPAPER=$(find "$HOME/.config/wallpapers" -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" | head -1)
    if [ -n "$FALLBACK_WALLPAPER" ]; then
        ln -sf "$FALLBACK_WALLPAPER" "$HOME/.config/wallpapers/wallpaper_current"
    fi
fi

swaylock \
    --ignore-empty-password \
    --indicator-idle-visible \
    --indicator-caps-lock \
    --show-failed-attempts \
    --daemonize \
    --image "$HOME/.config/wallpapers/wallpaper_current" \
    --font "JetBrains Mono:size=20" \
    --indicator-radius 150 \
    --indicator-thickness 12 \
    --inside-color 2e3440FF \
    --ring-color 5E81AC \
    --line-color 00000000 \
    --separator-color 00000000 \
    --key-hl-color 4c566a \
    --bs-hl-color ebcb8b \
    --inside-ver-color 2e3440FF \
    --ring-ver-color 5E81AC \
    --text-ver-color d8dee9 \
    --inside-wrong-color 2e3440FF \
    --ring-wrong-color bf616a \
    --text-wrong-color d8dee9 \
    --inside-clear-color 2e3440FF \
    --ring-clear-color a3be8c \
    --text-clear-color d8dee9 \
    --text-color d8dee9 \
    --text-caps-lock-color d8dee9 \
    "$@"

# Send unlock signal to D-Bus after unlocking
dbus-send --session --type=signal /org/freedesktop/ScreenSaver org.freedesktop.ScreenSaver.ActiveChanged boolean:false 2>/dev/null &

log_message "Screen unlocked"
