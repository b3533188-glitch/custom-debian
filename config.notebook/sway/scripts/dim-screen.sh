#!/bin/bash

# Create log directory and rotate if needed
LOG_DIR="$HOME/.local/state/sway"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/idle.log"

# Rotate log if it gets too large (>1MB)
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

echo "[$(date)] Dimming screens for idle" >> "$LOG_FILE"

# Dim internal display (always works with swayosd)
if command -v swayosd-client &>/dev/null; then
    swayosd-client --brightness 10 2>>"$LOG_FILE"
fi

# Dim external display if ddcutil is available
if command -v ddcutil &>/dev/null && command -v doas &>/dev/null; then
    # Try to dim external display, but don't fail if it doesn't work
    if ! doas ddcutil -d 1 setvcp 10 1 2>>"$LOG_FILE"; then
        echo "[$(date)] Warning: Could not dim external display" >> "$LOG_FILE"
    fi
fi

exit 0