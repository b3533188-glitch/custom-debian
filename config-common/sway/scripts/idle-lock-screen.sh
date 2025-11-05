#!/bin/bash
#==============================================================================
# Idle Lock Screen Wrapper
#
# PURPOSE: Locks screen only if no media is playing
#==============================================================================

SCRIPTS_DIR="$HOME/.config/sway/scripts"

# Check if media is playing
if "$SCRIPTS_DIR/check-media-playing.sh"; then
    # Media is playing, don't lock
    exit 0
fi

# No media playing, proceed with locking
exec "$SCRIPTS_DIR/lock-screen.sh" -f
