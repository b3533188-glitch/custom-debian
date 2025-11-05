#!/bin/bash

# Sistema de sincronização automática completa
# Monitora mudanças no repositório e sincroniza pacotes E configurações automaticamente

set -e

# Repositório local fixo para sincronização
REPO_DIR="$HOME/.local/share/custom-debian-repo"
CONFIG_FILE="$REPO_DIR/config.sh"
LAST_SYNC_FILE="$HOME/.cache/debian-config-sync"
LOG_FILE="$HOME/.local/state/config-sync.log"

# Detectar perfil (mac ou notebook)
PROFILE=""
if [ -f "$HOME/.config/sway/config" ]; then
    if grep -q "MacBook" "$HOME/.config/sway/config" 2>/dev/null; then
        PROFILE="mac"
    else
        PROFILE="notebook"
    fi
else
    # Detectar baseado no hardware se não há config ainda
    if lspci | grep -i apple >/dev/null 2>&1 || sysctl hw.model 2>/dev/null | grep -i mac >/dev/null; then
        PROFILE="mac"
    else
        PROFILE="notebook"
    fi
fi

CONFIG_DIR="$REPO_DIR/config.$PROFILE"

# Função para log com timestamp
log_message() {
    local LOG_DIR="$(dirname "$LOG_FILE")"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Função para garantir que o repositório existe localmente
ensure_repo_exists() {
    if [ ! -d "$REPO_DIR/.git" ]; then
        log_message "Repository not found. Performing initial clone..."
        mkdir -p "$(dirname "$REPO_DIR")"
        git clone "https://codeberg.org/Brussels9807/custom-debian.git" "$REPO_DIR" >/dev/null 2>&1
        log_message "Repository cloned to $REPO_DIR"
    fi
}

# Função para verificar se há mudanças no repositório
check_repo_changes() {
    ensure_repo_exists
    cd "$REPO_DIR" || return 1

    # Verificar se há atualizações remotas
    git fetch origin main >/dev/null 2>&1

    local current_commit=$(git rev-parse HEAD)
    local remote_commit=$(git rev-parse origin/main)

    if [ "$current_commit" != "$remote_commit" ]; then
        echo "changes_detected"
        return 0
    fi

    echo "no_changes"
    return 1
}

# Função para extrair lista de pacotes do config.sh
extract_packages() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERRO: Arquivo config.sh não encontrado"
        return 1
    fi

    # Extrair pacotes obrigatórios
    grep "MANDATORY_PACKAGES=" "$CONFIG_FILE" | sed 's/.*=(//' | sed 's/).*//' | tr ' ' '\n' | grep -v '^$'
}

# Função para sincronizar pacotes
sync_packages() {
    log_message "Verificando pacotes..."

    # Extrair lista de pacotes
    local packages=$(extract_packages)
    if [ $? -ne 0 ]; then
        log_message "ERRO: Falha ao extrair lista de pacotes"
        return 1
    fi

    # Verificar quais pacotes não estão instalados
    local missing_packages=""
    for package in $packages; do
        if ! dpkg -l | grep -q "^ii  $package "; then
            missing_packages="$missing_packages $package"
        fi
    done

    if [ -n "$missing_packages" ]; then
        log_message "Missing packages found:$missing_packages"

        # Atualizar cache de pacotes
        doas apt update >/dev/null 2>&1

        # Instalar pacotes em falta
        for package in $missing_packages; do
            log_message "Installing package: $package"
            if doas apt install -y "$package" >/dev/null 2>&1; then
                log_message "✓ Package .* installed successfully"
            else
                log_message "✗ Failed to install package: $package"
            fi
        done

        notify-send "Config Sync" "Installed missing packages:$missing_packages" --icon=package-install
    else
        log_message "All mandatory packages are already installed"
    fi
}

# Função para sincronizar configurações
sync_configurations() {
    log_message "Synchronizing configurations ($PROFILE profile)..."

    if [ ! -d "$CONFIG_DIR" ]; then
        log_message "ERRO: Diretório de configuração não encontrado: $CONFIG_DIR"
        return 1
    fi

    local changes_made=false

    # Sincronizar cada diretório de configuração
    for config_path in "$CONFIG_DIR"/*; do
        if [ -d "$config_path" ]; then
            local config_name=$(basename "$config_path")
            local target_path="$HOME/.config/$config_name"

            # Verificar se há diferenças
            if [ ! -d "$target_path" ] || ! diff -r "$config_path" "$target_path" >/dev/null 2>&1; then
                log_message "Updating configuration: $config_name"

                # Fazer backup se existir
                if [ -d "$target_path" ]; then
                    mv "$target_path" "$target_path.bak.$(date +%Y%m%d_%H%M%S)"
                fi

                # Copiar nova configuração
                mkdir -p "$(dirname "$target_path")"
                cp -r "$config_path" "$target_path"
                changes_made=true

                log_message "✓ Configuration .* updated"
            fi
        fi
    done

    # Sincronizar scripts
    if [ -d "$REPO_DIR/scripts" ]; then
        local bin_dir="$HOME/.local/bin"
        mkdir -p "$bin_dir"

        for script in "$REPO_DIR/scripts"/*.sh; do
            if [ -f "$script" ]; then
                local script_name=$(basename "$script")
                local target_script="$bin_dir/$script_name"

                if [ ! -f "$target_script" ] || ! diff "$script" "$target_script" >/dev/null 2>&1; then
                    cp "$script" "$target_script"
                    chmod +x "$target_script"
                    log_message "✓ Script $script_name atualizado"
                    changes_made=true
                fi
            fi
        done
    fi

    if [ "$changes_made" = true ]; then
        notify-send "Config Sync" "Configurations updated from repository" --icon=preferences-system
    else
        log_message "All configurations are already up to date"
    fi
}

# Função para sincronizar systemd services
sync_systemd_services() {
    log_message "Checking systemd services..."

    local systemd_source="$CONFIG_DIR/systemd"
    local systemd_target="$HOME/.config/systemd/user"

    if [ -d "$systemd_source" ]; then
        mkdir -p "$systemd_target"

        for service_file in "$systemd_source"/*.{service,timer}; do
            if [ -f "$service_file" ]; then
                local service_name=$(basename "$service_file")
                local target_file="$systemd_target/$service_name"

                if [ ! -f "$target_file" ] || ! diff "$service_file" "$target_file" >/dev/null 2>&1; then
                    cp "$service_file" "$target_file"
                    systemctl --user daemon-reload 2>/dev/null || true
                    log_message "✓ Systemd service .* updated"
                fi
            fi
        done
    fi
}

# Função principal de sincronização
sync_all() {
    log_message "Iniciando sincronização completa..."

    # Garantir que o repositório existe e está atualizado
    ensure_repo_exists
    cd "$REPO_DIR"
    git pull origin main >/dev/null 2>&1

    # Sincronizar componentes
    sync_packages
    sync_configurations
    sync_systemd_services

    # Atualizar timestamp do último sync
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_SYNC_FILE"
    log_message "Sincronização completa concluída"
}

# Função para mostrar status
show_status() {
    echo "=== Status do Sistema de Sincronização Completa ==="
    echo ""

    echo "Perfil detectado: $PROFILE"
    echo "Diretório do repositório: $REPO_DIR"
    echo "Diretório de configuração: $CONFIG_DIR"
    echo ""

    if [ -f "$LAST_SYNC_FILE" ]; then
        echo "Última sincronização: $(cat "$LAST_SYNC_FILE")"
    else
        echo "Nunca sincronizado"
    fi

    cd "$REPO_DIR"
    echo "Commit atual: $(git rev-parse --short HEAD)"
    echo "Branch: $(git branch --show-current)"

    echo ""
    echo "Pacotes obrigatórios:"
    extract_packages | while read package; do
        if dpkg -l | grep -q "^ii  $package "; then
            echo "  ✓ $package"
        else
            echo "  ✗ $package (não instalado)"
        fi
    done

    echo ""
    echo "Configurações principais:"
    for config_path in "$CONFIG_DIR"/*; do
        if [ -d "$config_path" ]; then
            local config_name=$(basename "$config_path")
            local target_path="$HOME/.config/$config_name"
            if [ -d "$target_path" ]; then
                echo "  ✓ $config_name"
            else
                echo "  ✗ $config_name (não instalado)"
            fi
        fi
    done
}

# Função principal
main() {
    case "${1:-check}" in
        "check")
            if check_repo_changes | grep -q "changes_detected"; then
                echo "Mudanças detectadas no repositório"
                sync_all
            else
                echo "Nenhuma mudança detectada"
            fi
            ;;
        "sync")
            sync_all
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Uso: $0 {check|sync|status}"
            echo ""
            echo "  check  - Verificar mudanças e sincronizar se necessário"
            echo "  sync   - Forçar sincronização completa"
            echo "  status - Mostrar status do sistema"
            exit 1
            ;;
    esac
}

main "$@"