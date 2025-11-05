#!/bin/bash

# Wrapper script for gufw in Wayland environment
# Ensures proper GTK and display variables are set

export GDK_BACKEND=wayland
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway

# Launch gufw with proper privileges
pkexec env DISPLAY=$WAYLAND_DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY GDK_BACKEND=wayland /usr/bin/gufw "$@"