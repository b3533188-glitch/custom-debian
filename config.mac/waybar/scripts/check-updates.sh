#!/bin/bash

# Script compatível que redireciona para o novo sistema de atualizações
SYSTEM_UPDATER="$HOME/.local/bin/system-updater.sh"

# Função para verificar atualizações (compatibilidade)
check_updates() {
    if [ -f "$SYSTEM_UPDATER" ]; then
        "$SYSTEM_UPDATER" check >/dev/null 2>&1
    fi
}

# Função para mostrar status na waybar
show_waybar_status() {
    if [ -f "$SYSTEM_UPDATER" ]; then
        "$SYSTEM_UPDATER" waybar
    else
        # Fallback para o sistema antigo
        echo "{\"text\": \"?\", \"tooltip\": \"Update system not found: $SYSTEM_UPDATER\", \"class\": \"error\"}"
    fi
}

# Verificar argumentos
case "${1:-waybar}" in
    "check")
        check_updates
        ;;
    "waybar")
        show_waybar_status
        ;;
    "count")
        if [ -f "$CACHE_FILE" ]; then
            cat "$CACHE_FILE"
        else
            echo "0"
        fi
        ;;
    *)
        echo "Usage: $0 {check|waybar|count}"
        exit 1
        ;;
esac