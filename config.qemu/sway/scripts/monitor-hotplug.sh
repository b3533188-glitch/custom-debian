#!/bin/bash

# Check dependencies
missing_deps=()
for dep in swaymsg; do
    if ! command -v "$dep" &> /dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
    exit 1
fi

# Monitor hotplug detection and auto-configuration
detect_monitors() {
    # Verificar se estamos em um ambiente Sway
    if ! pgrep -x sway > /dev/null; then
        echo "Sway não está rodando - script não aplicável"
        exit 0
    fi

    # Detectar monitor interno (pode ser eDP-1, LVDS-1, ou outros)
    LAPTOP_SCREEN=$(swaymsg -t get_outputs | jq -r '.[] | select(.name | test("eDP|LVDS|DSI")) | .name' | head -1)

    if [ -z "$LAPTOP_SCREEN" ]; then
        echo "Monitor interno não detectado - usando fallback"
        LAPTOP_SCREEN="eDP-1"
    fi

    # Detectar monitor externo ativo (excluindo o interno)
    EXTERNAL_MONITOR=$(swaymsg -t get_outputs | jq -r --arg laptop "$LAPTOP_SCREEN" '.[] | select(.name != $laptop and .active == true) | .name' | head -1)

    if [ -n "$EXTERNAL_MONITOR" ]; then
        # Verificar resolução suportada do monitor externo
        EXTERNAL_MODES=$(swaymsg -t get_outputs | jq -r --arg monitor "$EXTERNAL_MONITOR" '.[] | select(.name == $monitor) | .modes[] | "\(.width)x\(.height)@\(.refresh/1000)"')

        # Tentar usar 1920x1080 se disponível, senão usar a primeira resolução disponível
        if echo "$EXTERNAL_MODES" | grep -q "1920x1080"; then
            EXTERNAL_MODE="1920x1080@60Hz"
        else
            EXTERNAL_MODE=$(echo "$EXTERNAL_MODES" | head -1)
        fi

        # Configurar monitor externo
        swaymsg output "$EXTERNAL_MONITOR" mode "$EXTERNAL_MODE" pos 0 -190
        swaymsg output "$LAPTOP_SCREEN" pos 1920 0

        # Move workspaces to appropriate outputs (apenas se existirem)
        for workspace in 6 7 8 9 10; do
            if swaymsg -t get_workspaces | jq -e --arg ws "$workspace" '.[] | select(.name == $ws)' > /dev/null; then
                swaymsg workspace "$workspace" output "$EXTERNAL_MONITOR"
            fi
        done

        if command -v notify-send &> /dev/null; then
            notify-send "Monitor" "External monitor connected: $EXTERNAL_MONITOR ($EXTERNAL_MODE)"
        fi
    else
        # Apenas tela do laptop
        swaymsg output "$LAPTOP_SCREEN" pos 0 0

        if command -v notify-send &> /dev/null; then
            notify-send "Monitor" "Using laptop screen only: $LAPTOP_SCREEN"
        fi
    fi
}

detect_monitors