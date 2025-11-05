#!/bin/bash

# Create log directory and rotate if needed
LOG_DIR="$HOME/.local/state/sway"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/idle.log"

# Rotate log if it gets too large (>1MB)
if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]; then
    mv "$LOG_FILE" "$LOG_FILE.old"
fi

echo "[$(date)] Restoring screens from idle" >> "$LOG_FILE"

# Restore internal display brightness (always works with swayosd)
if command -v swayosd-client &>/dev/null; then
    swayosd-client --brightness 75 2>>"$LOG_FILE"
fi

# Restore external display brightness if ddcutil is available
if command -v ddcutil &>/dev/null && command -v doas &>/dev/null; then
    # Try to restore external display, but don't fail if it doesn't work
    if ! doas ddcutil -d 1 setvcp 10 30 2>>"$LOG_FILE"; then
        echo "[$(date)] Warning: Could not restore external display brightness" >> "$LOG_FILE"
    fi
fi

exit 0
