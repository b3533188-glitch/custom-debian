#!/bin/bash
#==============================================================================
# Check Media Playing Script
#
# PURPOSE: Detects if VIDEO is currently playing to prevent idle suspension
#          ONLY blocks for video playback, NOT for audio-only or fullscreen apps
#
# RETURNS: 0 if video is playing, 1 if not
#==============================================================================

# Check using playerctl for video playback detection
if command -v playerctl &>/dev/null; then
    # Get all active players
    players=$(playerctl -l 2>/dev/null)

    for player in $players; do
        # Check if player is playing
        status=$(playerctl -p "$player" status 2>/dev/null)
        if [ "$status" = "Playing" ]; then
            # Check if it's a video player (not just audio)
            # Common video players: firefox, chromium, mpv, vlc, celluloid, totem
            case "$player" in
                firefox*|chromium*|mpv*|vlc*|celluloid*|totem*)
                    # For browsers and video players, check metadata
                    # If it has video track information, it's playing video
                    metadata=$(playerctl -p "$player" metadata 2>/dev/null)

                    # Check for video-specific metadata or URL patterns
                    if echo "$metadata" | grep -qiE "youtube|vimeo|video|\.mp4|\.mkv|\.avi|\.webm"; then
                        exit 0  # Video is playing
                    fi
                    ;;
            esac
        fi
    done
fi

# No video detected
exit 1
