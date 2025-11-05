#!/bin/bash
#==============================================================================
# Idle Dim Screen Wrapper
#
# PURPOSE: Dims screen only if no media is playing
#==============================================================================

SCRIPTS_DIR="$HOME/.config/sway/scripts"

# Check if media is playing
if "$SCRIPTS_DIR/check-media-playing.sh"; then
    # Media is playing, don't dim
    exit 0
fi

# No media playing, proceed with dimming
exec "$SCRIPTS_DIR/dim-screen.sh"
