#!/bin/bash
#==============================================================================
# Idle DPMS Off Wrapper
#
# PURPOSE: Turns off displays only if no media is playing
#==============================================================================

SCRIPTS_DIR="$HOME/.config/sway/scripts"

# Check if media is playing
if "$SCRIPTS_DIR/check-media-playing.sh"; then
    # Media is playing, don't turn off displays
    exit 0
fi

# No media playing, turn off displays
swaymsg "output * dpms off"
