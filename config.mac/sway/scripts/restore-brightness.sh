#!/bin/bash

# Create log directory
LOG_DIR="$HOME/.local/state/sway"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/idle.log"

echo "[$(date)] Restoring screen from idle" >> "$LOG_FILE"

# Check if brightnessctl is available
if ! command -v brightnessctl &>/dev/null; then
    echo "[$(date)] Error: brightnessctl not found" >> "$LOG_FILE"
    exit 0  # Don't block idle even if brightness control fails
fi

# Restore brightness from the secure user-specific file if it exists
BRIGHTNESS_FILE="$HOME/.cache/sway_brightness_before_dim"
if [ -f "$BRIGHTNESS_FILE" ]; then
    # Validate that the file contains only a number (security)
    BRIGHTNESS_VALUE=$(cat "$BRIGHTNESS_FILE" 2>/dev/null)
    if [[ "$BRIGHTNESS_VALUE" =~ ^[0-9]+$ ]]; then
        if brightnessctl s "$BRIGHTNESS_VALUE" 2>>"$LOG_FILE"; then
            rm -f "$BRIGHTNESS_FILE"
        else
            echo "[$(date)] Warning: Could not restore brightness" >> "$LOG_FILE"
        fi
    else
        echo "[$(date)] Warning: Invalid brightness value in $BRIGHTNESS_FILE" >> "$LOG_FILE"
        rm -f "$BRIGHTNESS_FILE"
    fi
fi

exit 0