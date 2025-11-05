#!/bin/bash
#==============================================================================
# Start Gestures Script
# Starts lisgd daemon for touchpad gesture support
#==============================================================================

# Kill any existing lisgd processes
killall lisgd 2>/dev/null

# Find touchpad device
TOUCHPAD_DEVICE=$(ls -la /dev/input/by-path/ | grep -i "event-mouse" | awk '{print $NF}' | sed 's/\.\.\//\/dev\/input\//')

if [ -z "$TOUCHPAD_DEVICE" ]; then
    echo "Touchpad device not found. Gestures disabled."
    exit 1
fi

# Start lisgd with gestures configured via -g parameter
# Format: -g 'fingers,swipe_type,edge,distance_threshold,orientation,command'
# Swipe types: LR (left-right), RL (right-left), DU (down-up), UD (up-down)
lisgd -d "$TOUCHPAD_DEVICE" \
      -g "3,LR,*,*,*,swaymsg workspace prev" \
      -g "3,RL,*,*,*,swaymsg workspace next" \
      -g "4,LR,*,*,*,swaymsg move container to workspace prev" \
      -g "4,RL,*,*,*,swaymsg move container to workspace next" &
