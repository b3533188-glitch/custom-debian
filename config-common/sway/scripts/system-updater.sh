#!/bin/bash
#==============================================================================
# Sistema Automático de Atualizações
#==============================================================================

# Configurações
CACHE_DIR="$HOME/.cache/system-updater"
UPDATE_AVAILABLE_FILE="$CACHE_DIR/updates_available"
WAYBAR_MODULE_FILE="$CACHE_DIR/waybar_updates"
LOG_FILE="$CACHE_DIR/updater.log"

# Criar diretórios necessários
mkdir -p "$CACHE_DIR"

# Função de log
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Verificar se Flatpak está instalado
FLATPAK_INSTALLED=false
if command -v flatpak >/dev/null 2>&1; then
    FLATPAK_INSTALLED=true
fi

# Função para verificar atualizações do sistema
check_system_updates() {
    log "Verificando atualizações do sistema..."

    # Atualizar cache de pacotes
    doas apt update >/dev/null 2>&1

    # Contar pacotes atualizáveis
    local apt_updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)

    echo "$apt_updates"
}

# Função para verificar atualizações Flatpak
check_flatpak_updates() {
    if [ "$FLATPAK_INSTALLED" = true ]; then
        log "Verificando atualizações Flatpak..."
        local flatpak_updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
        echo "$flatpak_updates"
    else
        echo "0"
    fi
}

# Função para verificar atualizações de AppImages (simplificado)
check_appimage_updates() {
    # Verificar se helium existe e se há updates (placeholder)
    if [ -f "$HOME/.local/bin/helium" ]; then
        # Placeholder para verificação de atualização do Helium
        # Por simplicidade, retorna 0 por enquanto
        echo "0"
    else
        echo "0"
    fi
}

# Função principal de verificação
check_updates() {
    local apt_count=$(check_system_updates)
    local flatpak_count=$(check_flatpak_updates)
    local appimage_count=$(check_appimage_updates)

    local total_updates=$((apt_count + flatpak_count + appimage_count))

    log "Atualizações encontradas - APT: $apt_count, Flatpak: $flatpak_count, AppImage: $appimage_count"

    # Criar arquivo de status para waybar
    if [ "$total_updates" -gt 0 ]; then
        cat > "$WAYBAR_MODULE_FILE" << EOF
{
    "text": " $total_updates",
    "tooltip": "Atualizações disponíveis:\n• APT: $apt_count\n• Flatpak: $flatpak_count\n• AppImage: $appimage_count\n\nClick to update",
    "class": "updates-available"
}
EOF

        # Criar flag de updates available
        echo "$total_updates" > "$UPDATE_AVAILABLE_FILE"

        # Enviar notificação
        notify-send "Atualizações Disponíveis" \
            "$total_updates atualizações encontradas.\nClique no ícone da waybar para atualizar." \
            --icon=software-update-available \
            --urgency=low

        log "Notificação enviada: $total_updates updates available"
    else
        # Remover arquivos se não há atualizações
        rm -f "$UPDATE_AVAILABLE_FILE" "$WAYBAR_MODULE_FILE"
        log "Nenhuma atualização disponível"
    fi
}

# Função para aplicar atualizações
apply_updates() {
    log "Iniciando aplicação de atualizações..."

    local apt_count=$(check_system_updates)
    local flatpak_count=$(check_flatpak_updates)

    if [ "$apt_count" -gt 0 ]; then
        echo "📦 Atualizando pacotes do sistema ($apt_count pacotes)..."
        doas apt upgrade -y
    fi

    if [ "$FLATPAK_INSTALLED" = true ] && [ "$flatpak_count" -gt 0 ]; then
        echo "📱 Atualizando aplicações Flatpak ($flatpak_count aplicações)..."
        flatpak update -y
    fi

    # Verificar novamente após atualizações
    echo "🔍 Verificando se restam atualizações..."
    check_updates

    echo "✅ Processo de atualização concluído!"
    log "Atualizações aplicadas com sucesso"
}

# Verificar argumentos
case "${1:-check}" in
    "check")
        check_updates
        ;;
    "update")
        apply_updates
        ;;
    "status")
        if [ -f "$UPDATE_AVAILABLE_FILE" ]; then
            cat "$UPDATE_AVAILABLE_FILE"
        else
            echo "0"
        fi
        ;;
    "waybar")
        if [ -f "$WAYBAR_MODULE_FILE" ]; then
            cat "$WAYBAR_MODULE_FILE"
        else
            echo '{"text": "", "tooltip": "System updated", "class": "updated"}'
        fi
        ;;
    *)
        echo "Uso: $0 {check|update|status|waybar}"
        exit 1
        ;;
esac