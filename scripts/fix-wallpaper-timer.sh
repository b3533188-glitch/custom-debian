#!/bin/bash
#==============================================================================
# Fix Wallpaper Timer Script
#
# PURPOSE: Fix wallpaper timer to run only at specific times, not every minute
#==============================================================================

echo "Fixing wallpaper timer..."

# Detect hardware profile
if lspci | grep -i apple >/dev/null 2>&1 || sysctl hw.model 2>/dev/null | grep -i mac >/dev/null; then
    PROFILE="mac"
elif grep -q "QEMU" /proc/cpuinfo 2>/dev/null || grep -q "VMware" /proc/cpuinfo 2>/dev/null; then
    PROFILE="qemu"
else
    PROFILE="notebook"
fi

echo "Detected profile: $PROFILE"

# Stop current timer
echo "Stopping wallpaper timer..."
systemctl --user stop sway-wallpaper.timer 2>/dev/null || true

# Kill duplicate swaybg processes
echo "Cleaning up duplicate swaybg processes..."
pkill -x swaybg || true

# Copy correct timer
TIMER_FILE="$HOME/.config/systemd/user/sway-wallpaper.timer"
REPO_DIR="$HOME/.local/share/custom-debian-repo"

# Create correct timer content directly
echo "Creating correct wallpaper timer..."
cat > "$TIMER_FILE" << 'EOF'
[Unit]
Description=Sway Wallpaper Timer (changes every 30 minutes)

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min
OnCalendar=*-*-* 06:00:00
OnCalendar=*-*-* 18:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "Timer file updated successfully"

# Verify timer content has correct OnUnitActiveSec
if ! grep -q "OnUnitActiveSec=30min" "$TIMER_FILE"; then
    echo "ERROR: Timer doesn't have OnUnitActiveSec=30min!"
    echo "Content:"
    cat "$TIMER_FILE"
    exit 1
fi

# Reload systemd and restart timer
echo "Reloading systemd daemon..."
systemctl --user daemon-reload

echo "Enabling wallpaper timer..."
systemctl --user enable sway-wallpaper.timer

echo "Starting wallpaper timer..."
systemctl --user start sway-wallpaper.timer

# Show timer status
echo ""
echo "Timer status:"
systemctl --user list-timers | grep sway-wallpaper || echo "Timer not found"

# Show timer content for verification
echo ""
echo "Timer content verification:"
cat "$TIMER_FILE"

# Start wallpaper manually
echo ""
echo "Starting wallpaper manually..."
if [ -f "$HOME/.config/sway/scripts/change-wallpaper.sh" ]; then
    "$HOME/.config/sway/scripts/change-wallpaper.sh"
else
    echo "Warning: change-wallpaper.sh not found"
fi

echo ""
echo "Wallpaper timer fix complete!"
echo "The timer will now change wallpaper every 30 minutes."
echo "Day wallpapers (06:00-17:59) and night wallpapers (18:00-05:59)."