#!/bin/bash

# Create log directory
LOG_DIR="$HOME/.local/state/sway"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/idle.log"

echo "[$(date)] Dimming screen for idle" >> "$LOG_FILE"

# Check if brightnessctl is available
if ! command -v brightnessctl &>/dev/null; then
    echo "[$(date)] Error: brightnessctl not found" >> "$LOG_FILE"
    exit 0  # Don't block idle even if brightness control fails
fi

# Save current brightness to a secure user-specific file
BRIGHTNESS_FILE="$HOME/.cache/sway_brightness_before_dim"
mkdir -p "$HOME/.cache"

if brightnessctl g > "$BRIGHTNESS_FILE" 2>>"$LOG_FILE"; then
    # Set brightness to 5%
    brightnessctl s 5% 2>>"$LOG_FILE" || echo "[$(date)] Warning: Could not dim screen" >> "$LOG_FILE"
else
    echo "[$(date)] Warning: Could not save current brightness" >> "$LOG_FILE"
fi

exit 0