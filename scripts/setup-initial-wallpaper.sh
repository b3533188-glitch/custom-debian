#!/bin/bash
#==============================================================================
# Initial Wallpaper Setup Script
#
# PURPOSE: Sets initial wallpaper and ensures wallpaper system is working
#==============================================================================

echo "Setting up initial wallpaper..."

# Create necessary directories
mkdir -p "$HOME/.local/state/sway"
mkdir -p "$HOME/.config/wallpapers"

# Check if wallpaper script exists
if [ ! -f "$HOME/.config/sway/scripts/change-wallpaper.sh" ]; then
    echo "Error: change-wallpaper.sh not found!"
    exit 1
fi

# Kill any existing swaybg processes
pkill -x swaybg 2>/dev/null || true

# Run wallpaper script to set initial wallpaper
echo "Running initial wallpaper setup..."
"$HOME/.config/sway/scripts/change-wallpaper.sh"

# Check if swaybg is running
if pgrep -x swaybg >/dev/null; then
    echo "✅ Wallpaper setup successful!"
    echo "Wallpaper will change every 30 minutes automatically."
else
    echo "❌ Wallpaper setup failed!"
    echo "Check wallpaper logs: $HOME/.local/state/sway/wallpaper.log"
    exit 1
fi