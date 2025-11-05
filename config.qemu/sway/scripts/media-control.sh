#!/bin/bash

# Script para controlar mídia com notificações visuais

ACTION="$1"

get_media_info() {
    TITLE=$(playerctl metadata title 2>/dev/null || echo "Nenhuma mídia")
    ARTIST=$(playerctl metadata artist 2>/dev/null || echo "")
    if [ -n "$ARTIST" ]; then
        echo "$TITLE - $ARTIST"
    else
        echo "$TITLE"
    fi
}

case "$ACTION" in
    play-pause)
        playerctl play-pause
        STATUS=$(playerctl status 2>/dev/null)
        MEDIA=$(get_media_info)
        if [ "$STATUS" = "Playing" ]; then
            notify-send -t 2000 -u low " Reproduzindo" "$MEDIA"
        else
            notify-send -t 2000 -u low " Pausado" "$MEDIA"
        fi
        ;;
    next)
        playerctl next
        sleep 0.2
        MEDIA=$(get_media_info)
        notify-send -t 2000 -u low " Próxima" "$MEDIA"
        ;;
    previous)
        playerctl previous
        sleep 0.2
        MEDIA=$(get_media_info)
        notify-send -t 2000 -u low " Anterior" "$MEDIA"
        ;;
esac
