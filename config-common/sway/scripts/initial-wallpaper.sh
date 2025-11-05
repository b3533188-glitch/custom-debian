#!/bin/bash
#==============================================================================
# Initial Wallpaper Setup
#
# PURPOSE: Sets initial wallpaper on Sway startup without conflicting with timers
#          This script runs once during Sway initialization
#==============================================================================

WALLPAPER_DIR="$HOME/.config/wallpapers"
CURRENT_WALLPAPER_LINK="$WALLPAPER_DIR/wallpaper_current"
LOG_FILE="$HOME/.local/state/sway/wallpaper.log"

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] Starting initial wallpaper setup" >> "$LOG_FILE"

# Only run if no wallpaper is currently set
if pgrep -x swaybg >/dev/null 2>&1; then
    echo "[$(date)] swaybg already running, skipping initial setup" >> "$LOG_FILE"
    exit 0
fi

# Verify wallpaper directory exists
if [ ! -d "$WALLPAPER_DIR" ]; then
    echo "[$(date)] ERROR: Wallpaper directory not found: $WALLPAPER_DIR" >> "$LOG_FILE"
    echo "[$(date)] This indicates the installation may have failed to copy wallpapers" >> "$LOG_FILE"
    exit 1
fi

HOUR=$(date +%H)

if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
    TIME_OF_DAY="day"
else
    TIME_OF_DAY="night"
fi

SOURCE_DIR="$WALLPAPER_DIR/$TIME_OF_DAY"

# Verify wallpaper directory exists
if [ ! -d "$SOURCE_DIR" ] || ! find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
    FALLBACK_TIME_OF_DAY=$([ "$TIME_OF_DAY" == "day" ] && echo "night" || echo "day")
    SOURCE_DIR="$WALLPAPER_DIR/$FALLBACK_TIME_OF_DAY"
    if [ ! -d "$SOURCE_DIR" ] || ! find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
        echo "[$(date)] Error: No wallpapers found in $WALLPAPER_DIR" >> "$LOG_FILE"
        exit 1
    fi
fi

# Get first available wallpaper
SELECTED_WALLPAPER=$(find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) | head -1)

if [ -z "$SELECTED_WALLPAPER" ] || [ ! -f "$SELECTED_WALLPAPER" ]; then
    echo "[$(date)] Error: Failed to select initial wallpaper" >> "$LOG_FILE"
    exit 1
fi

# Update symlink
ln -sf "$SELECTED_WALLPAPER" "$CURRENT_WALLPAPER_LINK"

# Start swaybg
swaybg -i "$CURRENT_WALLPAPER_LINK" -m fill >/dev/null 2>&1 &
SWAYBG_PID=$!

# Verify it started
sleep 1
if kill -0 "$SWAYBG_PID" 2>/dev/null; then
    echo "[$(date)] Initial wallpaper set: $SELECTED_WALLPAPER (PID: $SWAYBG_PID)" >> "$LOG_FILE"
else
    echo "[$(date)] Error: Failed to start initial swaybg" >> "$LOG_FILE"
    exit 1
fi

exit 0