#!/bin/bash
#==============================================================================
# Idle Suspend Wrapper
#
# PURPOSE: Suspends system only if no media is playing
#==============================================================================

SCRIPTS_DIR="$HOME/.config/sway/scripts"

# Check if media is playing
if "$SCRIPTS_DIR/check-media-playing.sh"; then
    # Media is playing, don't suspend
    exit 0
fi

# No media playing, suspend system
systemctl suspend
