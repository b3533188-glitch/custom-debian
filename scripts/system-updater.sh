#!/bin/bash

# Sistema Completo de Atualizações Automáticas
# - Verifica APT, Flatpak e programs manuais a cada 30 minutos
# - Monitora repositório de configurações
# - Aplica mudanças respeitando preferências do usuário
# - Gerencia packages obrigatórios e opcionais

set -e

# Arquivos de estado e configuração
STATE_DIR="$HOME/.local/state/system-updater"
CONFIG_DIR="$HOME/.config/system-updater"
CACHE_DIR="$HOME/.cache/system-updater"
LOG_FILE="$STATE_DIR/updater.log"

# Repositório local fixo
REPO_DIR="$HOME/.local/share/custom-debian-repo"

# Arquivos específicos
LAST_CHECK_FILE="$CACHE_DIR/last_check"
INSTALLED_COMMIT_FILE="$STATE_DIR/installed_commit"
USER_PREFERENCES="$CONFIG_DIR/user_preferences.conf"
INSTALLED_MANUAL="$STATE_DIR/manual_packages.list"
NOTIFIED_OPTIONAL="$STATE_DIR/notified_optional.list"

# Configuração
CHECK_INTERVAL=1800  # 30 minutos
REPO_URL="https://codeberg.org/Brussels9807/custom-debian.git"

# Detectar perfil
detect_profile() {
    if [ -f "$HOME/.config/sway/config" ]; then
        if grep -q "MacBook\|Apple" "$HOME/.config/sway/config" 2>/dev/null; then
            echo "mac"
        else
            echo "notebook"
        fi
    else
        if lspci | grep -i apple >/dev/null 2>&1 || [ -f /sys/class/dmi/id/sys_vendor ] && grep -qi apple /sys/class/dmi/id/sys_vendor; then
            echo "mac"
        else
            echo "notebook"
        fi
    fi
}

PROFILE=$(detect_profile)
CONFIG_SOURCE="$REPO_DIR/config.$PROFILE"

# Função para log com timestamp
log_message() {
    mkdir -p "$STATE_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Função para carregar preferências do usuário
load_user_preferences() {
    if [ -f "$USER_PREFERENCES" ]; then
        source "$USER_PREFERENCES"
    else
        # Valores padrão - serão sobrescritos pelos dados reais de instalação
        MOUSE_ACCELERATION="default"
        CHOSEN_DEB_OPTIONS=()
        CHOSEN_FILE_MANAGERS=()
        FLATPAK_APPS=()
    fi
}

# Função para salvar preferências do usuário
save_user_preferences() {
    mkdir -p "$CONFIG_DIR"
    cat > "$USER_PREFERENCES" << EOF
# Preferências do usuário salvas automaticamente
MOUSE_ACCELERATION="$MOUSE_ACCELERATION"
CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]})
CHOSEN_FILE_MANAGERS=(${CHOSEN_FILE_MANAGERS[@]})
FLATPAK_APPS=(${FLATPAK_APPS[@]})
LAST_CONFIG_UPDATE="$(date)"
EOF
}

# Função para verificar se repositório existe localmente
ensure_repo_exists() {
    if [ ! -d "$REPO_DIR/.git" ]; then
        log_message "Repository not found. Performing initial clone..."
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "$REPO_URL" "$REPO_DIR" >/dev/null 2>&1
        log_message "Repository cloned to $REPO_DIR"

        # Salvar commit atual como instalado
        cd "$REPO_DIR"
        mkdir -p "$STATE_DIR"
        git rev-parse HEAD > "$INSTALLED_COMMIT_FILE"
        log_message "Saved installed commit: $(cat "$INSTALLED_COMMIT_FILE")"
    fi
}

# Função para verificar updates APT
check_apt_updates() {
    local force_refresh="${1:-false}"

    if [ "$force_refresh" = "true" ]; then
        log_message "Updating APT cache..."
        if doas apt update >/dev/null 2>&1; then
            log_message "APT cache updated"
        else
            log_message "APT cache could not be updated (no doas privileges)"
        fi
    fi

    local updates=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    echo "$updates"
}

# Função para verificar updates Flatpak
check_flatpak_updates() {
    local force_refresh="${1:-false}"

    if command -v flatpak >/dev/null 2>&1; then
        if [ "$force_refresh" = "true" ]; then
            log_message "Updating Flatpak metadata..."
            flatpak update --appstream >/dev/null 2>&1 || true
        fi

        local updates=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
        echo "$updates"
    else
        echo "0"
    fi
}

# Função para detectar programs manuais instalados
detect_manual_programs() {
    local manual_list=""

    # Verificar programs conhecidos
    # Helium Browser
    if [ -f "$HOME/Applications/Helium.AppImage" ] || [ -f "/opt/helium/helium" ]; then
        manual_list="$manual_list helium"
    fi

    # VeraCrypt
    if command -v veracrypt >/dev/null 2>&1; then
        manual_list="$manual_list veracrypt"
    fi

    # Outros programs podem ser adicionados aqui
    # Adicione verificações para outros programs manuais conforme necessário

    echo "$manual_list"
}

# Função para verificar updates de programs manuais
check_manual_updates() {
    local updates_available=0

    # Verificar cada programa manual
    # Helium - verificar no GitHub releases
    if echo "$(detect_manual_programs)" | grep -q "helium"; then
        # Implementar verificação de versão do Helium
        # Por enquanto, placeholder
        updates_available=$((updates_available + 0))
    fi

    # VeraCrypt - verificar site oficial
    if echo "$(detect_manual_programs)" | grep -q "veracrypt"; then
        # Implementar verificação de versão do VeraCrypt
        # Por enquanto, placeholder
        updates_available=$((updates_available + 0))
    fi

    echo "$updates_available"
}

# Função para verificar mudanças no repositório
check_repo_changes() {
    ensure_repo_exists
    cd "$REPO_DIR" || return 1

    git fetch origin main >/dev/null 2>&1 || return 1

    local installed_commit=""
    local remote_commit=$(git rev-parse origin/main 2>/dev/null)

    if [ -f "$INSTALLED_COMMIT_FILE" ]; then
        installed_commit=$(cat "$INSTALLED_COMMIT_FILE")
    else
        # Se não existe arquivo, criar com commit atual
        installed_commit=$(git rev-parse HEAD 2>/dev/null)
        mkdir -p "$STATE_DIR"
        echo "$installed_commit" > "$INSTALLED_COMMIT_FILE"
    fi

    if [ "$installed_commit" != "$remote_commit" ]; then
        echo "repo_changes_detected"
    else
        echo "no_repo_changes"
    fi
}

# Função para extrair listas de packages do repositório
extract_package_lists() {
    local config_file="$REPO_DIR/config.sh"

    if [ ! -f "$config_file" ]; then
        log_message "ERRO: config.sh não encontrado"
        return 1
    fi

    # Extrair packages obrigatórios
    MANDATORY_PACKAGES=($(grep "MANDATORY_PACKAGES=" "$config_file" | sed 's/.*=(//' | sed 's/).*//' | tr ' ' '\n' | grep -v '^$'))

    # Extrair packages opcionais (exemplo - adapte conforme sua estrutura)
    OPTIONAL_PACKAGES=($(grep "OPTIONAL_PACKAGES=" "$config_file" | sed 's/.*=(//' | sed 's/).*//' | tr ' ' '\n' | grep -v '^$' 2>/dev/null || echo ""))
}

# Função para verificar packages obrigatórios
check_mandatory_packages() {
    extract_package_lists

    local missing_packages=()
    local extra_packages=()

    # Verificar packages que deveriam estar instalados
    for package in "${MANDATORY_PACKAGES[@]}"; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages+=("$package")
        fi
    done

    # Verificar se há packages instalados que não deveriam estar (removidos da lista)
    if [ -f "$STATE_DIR/last_mandatory.list" ]; then
        while read -r old_package; do
            if [[ ! " ${MANDATORY_PACKAGES[@]} " =~ " $old_package " ]]; then
                if dpkg -l | grep -q "^ii  $old_package "; then
                    extra_packages+=("$old_package")
                fi
            fi
        done < "$STATE_DIR/last_mandatory.list"
    fi

    # Salvar lista atual
    mkdir -p "$STATE_DIR"
    printf '%s\n' "${MANDATORY_PACKAGES[@]}" > "$STATE_DIR/last_mandatory.list"

    if [ ${#missing_packages[@]} -gt 0 ] || [ ${#extra_packages[@]} -gt 0 ]; then
        echo "mandatory_changes_detected"
        printf '%s\n' "${missing_packages[@]}" > "$STATE_DIR/missing_mandatory.list"
        printf '%s\n' "${extra_packages[@]}" > "$STATE_DIR/extra_mandatory.list"
    else
        echo "no_mandatory_changes"
    fi
}

# Função para verificar packages opcionais
check_optional_packages() {
    if [ ${#OPTIONAL_PACKAGES[@]} -eq 0 ]; then
        echo "no_optional_changes"
        return
    fi

    local new_optional=()
    local removed_optional=()

    # Verificar novos packages opcionais
    if [ -f "$STATE_DIR/last_optional.list" ]; then
        for package in "${OPTIONAL_PACKAGES[@]}"; do
            if ! grep -q "^$package$" "$STATE_DIR/last_optional.list"; then
                new_optional+=("$package")
            fi
        done

        # Verificar packages opcionais removidos
        while read -r old_package; do
            if [[ ! " ${OPTIONAL_PACKAGES[@]} " =~ " $old_package " ]]; then
                removed_optional+=("$old_package")
            fi
        done < "$STATE_DIR/last_optional.list"
    else
        new_optional=("${OPTIONAL_PACKAGES[@]}")
    fi

    # Salvar lista atual
    printf '%s\n' "${OPTIONAL_PACKAGES[@]}" > "$STATE_DIR/last_optional.list"

    if [ ${#new_optional[@]} -gt 0 ] || [ ${#removed_optional[@]} -gt 0 ]; then
        echo "optional_changes_detected"
        printf '%s\n' "${new_optional[@]}" > "$STATE_DIR/new_optional.list"
        printf '%s\n' "${removed_optional[@]}" > "$STATE_DIR/removed_optional.list"
    else
        echo "no_optional_changes"
    fi
}

# Função para verificar mudanças em wallpapers
check_wallpaper_changes() {
    local wallpaper_dir="$REPO_DIR/assets/wallpapers"
    local local_wallpaper_dir="$HOME/.config/wallpapers"

    if [ ! -d "$wallpaper_dir" ]; then
        echo "no_wallpaper_changes"
        return
    fi

    if [ ! -d "$local_wallpaper_dir" ] || ! diff -r "$wallpaper_dir" "$local_wallpaper_dir" >/dev/null 2>&1; then
        echo "wallpaper_changes_detected"
    else
        echo "no_wallpaper_changes"
    fi
}

# Função para aplicar mudanças de configuração
apply_config_changes() {
    log_message "Using sync-configs.sh for configuration updates"
    
    # Usar o script sync-configs.sh do diretório de scripts
    local sync_script="$(dirname "${BASH_SOURCE[0]}")/sync-configs.sh"
    
    if [ -f "$sync_script" ]; then
        # Executar sync-configs.sh e capturar resultado
        if "$sync_script" sync >/dev/null 2>&1; then
            # Atualizar arquivo de commit para marcar como sincronizado
            ensure_repo_exists
            cd "$REPO_DIR"
            local current_commit=$(git rev-parse HEAD 2>/dev/null)
            if [ -n "$current_commit" ]; then
                echo "$current_commit" > "$INSTALLED_COMMIT_FILE"
                log_message "Updated installed commit to: $current_commit"
            fi
            
            log_message "Configuration update completed successfully via sync-configs.sh"
            return 0
        else
            log_message "ERROR: sync-configs.sh failed"
            return 1
        fi
    else
        log_message "ERROR: sync-configs.sh not found at: $sync_script"
        return 1
    fi
}

# Função para enviar notificação da waybar
update_waybar_status() {
    # Verificar se está em processo de checagem
    local checking_flag="$CACHE_DIR/checking"
    if [ -f "$checking_flag" ]; then
        echo "{\"text\": \"🔄\", \"tooltip\": \"Checking for updates...\", \"class\": \"checking\"}"
        return 0
    fi

    local apt_updates=$(check_apt_updates)
    local flatpak_updates=$(check_flatpak_updates)
    local manual_updates=$(check_manual_updates)
    local total_updates=$((apt_updates + flatpak_updates + manual_updates))

    # Verificar se há mudanças no repositório
    local repo_status=$(check_repo_changes)
    local config_updates=0
    if [ "$repo_status" = "repo_changes_detected" ]; then
        config_updates=1
    fi

    # Total inclui config updates
    local total_with_config=$((total_updates + config_updates))

    local mandatory_status=$(check_mandatory_packages)
    local optional_status=$(check_optional_packages)

    local status_text=""
    local tooltip_text=""
    local css_class=""

    # Arquivo para armazenar estado anterior
    local last_state_file="$STATE_DIR/last_update_state"
    local current_state="$apt_updates:$flatpak_updates:$manual_updates:$repo_status"
    local should_notify=false

    # Verificar se houve mudança no estado
    if [ -f "$last_state_file" ]; then
        local last_state=$(cat "$last_state_file")
        if [ "$current_state" != "$last_state" ]; then
            should_notify=true
        fi
    else
        # Primeira execução - notificar apenas se houver atualizações
        if [ "$total_with_config" -gt 0 ]; then
            should_notify=true
        fi
    fi

    # Salvar estado atual
    mkdir -p "$STATE_DIR"
    echo "$current_state" > "$last_state_file"

    if [ "$total_with_config" -gt 0 ] || [ "$mandatory_status" = "mandatory_changes_detected" ] ||
       [ "$optional_status" = "optional_changes_detected" ]; then

        status_text="↻ $total_with_config"
        tooltip_text="$total_with_config updates available"
        css_class="updates-available"

        if [ "$apt_updates" -gt 0 ]; then
            tooltip_text="$tooltip_text\\nAPT: $apt_updates packages"
        fi
        if [ "$flatpak_updates" -gt 0 ]; then
            tooltip_text="$tooltip_text\\nFlatpak: $flatpak_updates apps"
        fi
        if [ "$manual_updates" -gt 0 ]; then
            tooltip_text="$tooltip_text\\nManual: $manual_updates programs"
        fi
        if [ "$config_updates" -gt 0 ]; then
            tooltip_text="$tooltip_text\\nConfiguration: 1 update"
        fi

        tooltip_text="$tooltip_text\\nLast check: $(date '+%H:%M')\\nClick to update"

        # Enviar notificação apenas se houve mudança e não foi suprimida
        if [ "$should_notify" = true ] && [ "$1" != "--no-notify" ]; then
            notify-send "Updates Available" "$total_with_config updates found" --icon=software-update-available
        fi

    else
        status_text="✓"
        tooltip_text="System updated\\nLast check: $(date '+%H:%M')\\nClick to check again"
        css_class="up-to-date"
    fi

    echo "{\"text\": \"$status_text\", \"tooltip\": \"$tooltip_text\", \"class\": \"$css_class\"}"
}

# Função para busca completa forçada
force_full_check() {
    log_message "Starting forced full check..."

    load_user_preferences

    # Forçar atualização de todos os caches
    log_message "Updating all caches..."

    # Atualizar cache APT
    if doas apt update >/dev/null 2>&1; then
        log_message "APT cache updated"
    else
        log_message "APT cache could not be updated (no doas privileges)"
    fi

    # Atualizar metadados Flatpak se disponível
    if command -v flatpak >/dev/null 2>&1; then
        flatpak update --appstream >/dev/null 2>&1 || true
    fi

    # Verificar mudanças no repositório forçadamente
    ensure_repo_exists
    cd "$REPO_DIR"
    git fetch origin main >/dev/null 2>&1

    # Atualizar timestamp da última verificação
    mkdir -p "$CACHE_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_CHECK_FILE"

    # Gerar status atualizado
    update_waybar_status

    log_message "Forced full check completed"
}

# Função principal de verificação
main_check() {
    log_message "Starting complete verification..."

    load_user_preferences

    # Atualizar timestamp da última verificação
    mkdir -p "$CACHE_DIR"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_CHECK_FILE"

    # Verificar tudo
    update_waybar_status

    log_message "Complete verification finished"
}

# Função para mostrar status
show_status() {
    echo "=== Automatic Updates System ==="
    echo ""

    echo "Detected profile: $PROFILE"
    echo "Repository: $REPO_DIR"
    echo ""

    if [ -f "$LAST_CHECK_FILE" ]; then
        echo "Last check: $(cat "$LAST_CHECK_FILE")"
    else
        echo "Never checked"
    fi

    echo ""
    echo "Updates available:"
    echo "  APT: $(check_apt_updates) packages"
    echo "  Flatpak: $(check_flatpak_updates) applications"
    echo "  Manual: $(check_manual_updates) programs"

    echo ""
    echo "Repository status:"
    if [ "$(check_repo_changes)" = "repo_changes_detected" ]; then
        echo "  ⚠ Changes detected"
    else
        echo "  ✓ Updated"
    fi

    echo ""
    echo "Mandatory packages:"
    if [ "$(check_mandatory_packages)" = "mandatory_changes_detected" ]; then
        echo "  ⚠ Changes detected"
    else
        echo "  ✓ In compliance"
    fi
}

# Função para aplicar atualizações com limpeza
apply_updates_with_cleanup() {
    local quiet_mode=false
    if [ "$1" = "--no-notify" ]; then
        quiet_mode=true
        shift
    fi

    mkdir -p "$STATE_DIR" "$CACHE_DIR"

    log_message "Starting system update with cleanup"

    # Verificar quais tipos de updates existem
    local apt_updates=$(check_apt_updates)
    local flatpak_updates=$(check_flatpak_updates)
    local config_updates=0
    if [ "$(check_repo_changes)" = "repo_changes_detected" ]; then
        config_updates=1
    fi

    local apt_was_updated=0

    # Aplicar mudanças de configuração se houver
    if [ "$config_updates" -gt 0 ]; then
        if [ "$quiet_mode" = false ]; then
            echo "⚙️  Aplicando atualizações de configuração..."
        fi
        if apply_config_changes; then
            log_message "Configuration updates applied"
        else
            log_message "Failed to apply configuration updates"
        fi
    fi

    # Atualizar APT apenas se houver updates de pacotes APT
    if [ "$apt_updates" -gt 0 ]; then
        # Atualizar repositórios APT
        if [ "$quiet_mode" = false ]; then
            echo "🔄 Atualizando repositórios..."
        fi
        if doas apt update >/dev/null 2>&1; then
            log_message "APT repositories updated"
        else
            log_message "Failed to update APT repositories"
            return 1
        fi

        # Aplicar atualizações APT
        if [ "$quiet_mode" = false ]; then
            echo "📦 Aplicando atualizações de pacotes APT..."
        fi
        if doas apt upgrade -y >/dev/null 2>&1; then
            log_message "APT packages upgraded"
            apt_was_updated=1
        else
            log_message "Failed to upgrade APT packages"
            return 1
        fi
    fi

    # Atualizar Flatpak apenas se houver updates
    if [ "$flatpak_updates" -gt 0 ] && command -v flatpak >/dev/null 2>&1; then
        if [ "$quiet_mode" = false ]; then
            echo "📱 Atualizando aplicações Flatpak..."
        fi
        if flatpak update -y >/dev/null 2>&1; then
            log_message "Flatpak applications updated"
        else
            log_message "Failed to update Flatpak applications"
        fi
    fi

    # Limpeza pós-update APENAS se houve updates APT
    if [ "$apt_was_updated" -eq 1 ]; then
        if [ "$quiet_mode" = false ]; then
            echo "🧹 Executando limpeza pós-update..."
        fi

        # Limpeza APT
        doas apt autoremove -y >/dev/null 2>&1 || true
        doas apt autoclean >/dev/null 2>&1 || true

        # Limpeza de cache de pacotes
        doas apt clean >/dev/null 2>&1 || true

        # Limpeza de kernels antigos
        if command -v apt-mark >/dev/null 2>&1; then
            doas apt autoremove --purge -y >/dev/null 2>&1 || true
        fi

        # Limpar caches do sistema
        if [ -d "/var/cache/apt/archives" ]; then
            doas find /var/cache/apt/archives -name "*.deb" -type f -delete 2>/dev/null || true
        fi
    fi

    # Limpeza Flatpak (independente de APT)
    if [ "$flatpak_updates" -gt 0 ] && command -v flatpak >/dev/null 2>&1; then
        if [ "$quiet_mode" = false ]; then
            echo "🧹 Limpando pacotes Flatpak não utilizados..."
        fi
        flatpak uninstall --unused -y >/dev/null 2>&1 || true
    fi

    # Atualizar cache do updater
    rm -f "$CACHE_DIR/updates_available" 2>/dev/null || true
    echo "0" > "$CACHE_DIR/last_update_count"

    log_message "System update with cleanup completed successfully"

    if [ "$quiet_mode" = false ]; then
        echo ""
        echo "✅ Atualização concluída com sucesso!"
    fi

    return 0
}

# Função principal
case "${1:-check}" in
    "check")
        main_check
        ;;
    "waybar")
        update_waybar_status
        ;;
    "status")
        show_status
        ;;
    "update")
        apply_updates_with_cleanup "$@"
        ;;
    "force-sync")
        load_user_preferences
        apply_config_changes
        ;;
    "force-check")
        force_full_check
        ;;
    *)
        echo "Uso: $0 {check|waybar|status|update|force-sync|force-check}"
        echo ""
        echo "  check       - Verificação completa (padrão)"
        echo "  waybar      - Apenas status para waybar"
        echo "  status      - Mostrar status detalhado"
        echo "  update      - Aplicar atualizações com limpeza automática"
        echo "  force-sync  - Forçar sincronização de configurações"
        echo "  force-check - Busca completa forçada (atualiza caches)"
        exit 1
        ;;
esac