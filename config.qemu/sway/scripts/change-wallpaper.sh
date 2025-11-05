#!/bin/bash

WALLPAPER_DIR="$HOME/.config/wallpapers"
CURRENT_WALLPAPER_LINK="$WALLPAPER_DIR/wallpaper_current"
LOG_FILE="$HOME/.local/state/sway/wallpaper.log"

# Create log directory
mkdir -p "$HOME/.local/state/sway"

HOUR=$(date +%H)

if [ "$HOUR" -ge 6 ] && [ "$HOUR" -lt 18 ]; then
    TIME_OF_DAY="day"
else
    TIME_OF_DAY="night"
fi

SOURCE_DIR="$WALLPAPER_DIR/$TIME_OF_DAY"

# Get current wallpaper if it exists
CURRENT_WALLPAPER=""
if [ -L "$CURRENT_WALLPAPER_LINK" ]; then
    CURRENT_WALLPAPER=$(readlink -f "$CURRENT_WALLPAPER_LINK")
fi

# Verify wallpaper directory exists
if [ ! -d "$SOURCE_DIR" ] || ! find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
    FALLBACK_TIME_OF_DAY=$([ "$TIME_OF_DAY" == "day" ] && echo "night" || echo "day")
    SOURCE_DIR="$WALLPAPER_DIR/$FALLBACK_TIME_OF_DAY"
    if [ ! -d "$SOURCE_DIR" ] || ! find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) -print -quit | grep -q .; then
        echo "[$(date)] Error: No wallpapers found in $WALLPAPER_DIR" >> "$LOG_FILE"
        # Don't kill swaybg if we can't find a wallpaper
        exit 1
    fi
fi

# Get all wallpapers from the directory
WALLPAPERS=($(find "$SOURCE_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \)))

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    echo "[$(date)] Error: No wallpapers found in $SOURCE_DIR" >> "$LOG_FILE"
    exit 1
fi

# If we have multiple wallpapers, try to select a different one
if [ ${#WALLPAPERS[@]} -gt 1 ] && [ -n "$CURRENT_WALLPAPER" ]; then
    # Filter out current wallpaper
    AVAILABLE_WALLPAPERS=()
    for wp in "${WALLPAPERS[@]}"; do
        if [ "$wp" != "$CURRENT_WALLPAPER" ]; then
            AVAILABLE_WALLPAPERS+=("$wp")
        fi
    done

    # Select from filtered list if available
    if [ ${#AVAILABLE_WALLPAPERS[@]} -gt 0 ]; then
        SELECTED_WALLPAPER="${AVAILABLE_WALLPAPERS[$RANDOM % ${#AVAILABLE_WALLPAPERS[@]}]}"
    else
        SELECTED_WALLPAPER="${WALLPAPERS[$RANDOM % ${#WALLPAPERS[@]}]}"
    fi
else
    # Only one wallpaper or first run
    SELECTED_WALLPAPER="${WALLPAPERS[$RANDOM % ${#WALLPAPERS[@]}]}"
fi

if [ -z "$SELECTED_WALLPAPER" ] || [ ! -f "$SELECTED_WALLPAPER" ]; then
    echo "[$(date)] Error: Failed to select wallpaper" >> "$LOG_FILE"
    exit 1
fi

# Check if swaybg is running
SWAYBG_RUNNING=$(pgrep -x swaybg >/dev/null 2>&1 && echo 1 || echo 0)

# If the selected wallpaper is the same as current AND swaybg is running, no need to change
if [ "$SWAYBG_RUNNING" -eq 1 ] && [ -n "$CURRENT_WALLPAPER" ] && [ "$SELECTED_WALLPAPER" = "$CURRENT_WALLPAPER" ]; then
    # Verify wallpaper is actually displayed by checking if swaybg is still running with correct image
    if pgrep -f "swaybg.*$CURRENT_WALLPAPER_LINK" >/dev/null 2>&1; then
        echo "[$(date)] Wallpaper unchanged: $SELECTED_WALLPAPER already displayed" >> "$LOG_FILE"
        exit 0
    fi
fi

# Update symlink
if ! ln -sf "$SELECTED_WALLPAPER" "$CURRENT_WALLPAPER_LINK"; then
    echo "[$(date)] Error: Failed to create wallpaper symlink" >> "$LOG_FILE"
    exit 1
fi

# Verify symlink was created successfully and points to a valid file
if [ ! -L "$CURRENT_WALLPAPER_LINK" ] || [ ! -f "$CURRENT_WALLPAPER_LINK" ]; then
    echo "[$(date)] Error: Symlink validation failed: link=$([ -L "$CURRENT_WALLPAPER_LINK" ] && echo 'exists' || echo 'missing') file=$([ -f "$CURRENT_WALLPAPER_LINK" ] && echo 'valid' || echo 'invalid')" >> "$LOG_FILE"
    exit 1
fi

# Log whether this is a restart or a change
if [ "$SWAYBG_RUNNING" -eq 0 ]; then
    echo "[$(date)] swaybg was not running, starting it" >> "$LOG_FILE"
fi

# Start new swaybg BEFORE killing the old one to prevent wallpaper disappearing
# Use a temporary log file to capture any errors
SWAYBG_ERROR_LOG="$HOME/.local/state/sway/swaybg-error.log"
swaybg -i "$CURRENT_WALLPAPER_LINK" -m fill >>"$SWAYBG_ERROR_LOG" 2>&1 &
NEW_SWAYBG_PID=$!

echo "[$(date)] Started new swaybg process (PID: $NEW_SWAYBG_PID)" >> "$LOG_FILE"

# Give the new swaybg time to start and initialize
sleep 1

# Verify the new swaybg is still running before killing old ones
if ! kill -0 "$NEW_SWAYBG_PID" 2>/dev/null; then
    echo "[$(date)] Error: New swaybg process died immediately (PID: $NEW_SWAYBG_PID)" >> "$LOG_FILE"
    if [ -s "$SWAYBG_ERROR_LOG" ]; then
        echo "[$(date)] swaybg error output:" >> "$LOG_FILE"
        tail -10 "$SWAYBG_ERROR_LOG" >> "$LOG_FILE"
    fi
    # Don't kill old swaybg if new one failed
    exit 1
fi

# Kill old swaybg instances (except the one we just started)
for pid in $(pgrep -x swaybg); do
    if [ "$pid" != "$NEW_SWAYBG_PID" ]; then
        kill "$pid" 2>/dev/null || true
    fi
done

# Final verification that our swaybg is still running
sleep 0.5
if ! kill -0 "$NEW_SWAYBG_PID" 2>/dev/null; then
    echo "[$(date)] Error: New swaybg process died after killing old ones (PID: $NEW_SWAYBG_PID)" >> "$LOG_FILE"
    if [ -s "$SWAYBG_ERROR_LOG" ]; then
        echo "[$(date)] swaybg error output:" >> "$LOG_FILE"
        tail -10 "$SWAYBG_ERROR_LOG" >> "$LOG_FILE"
    fi
    exit 1
fi

echo "[$(date)] Wallpaper changed to: $SELECTED_WALLPAPER (PID: $NEW_SWAYBG_PID)" >> "$LOG_FILE"
exit 0
