#!/bin/bash

# Sistema de sincronização automática de pacotes
# Monitora mudanças no repositório e sincroniza pacotes automaticamente

set -e

REPO_DIR="/home/me/Documents/backup-repositories/debian"
CONFIG_FILE="$REPO_DIR/config.sh"
LAST_SYNC_FILE="$HOME/.cache/debian-package-sync"
LOG_FILE="$HOME/.local/state/package-sync.log"

# Função para log com timestamp
log_message() {
    local LOG_DIR="$(dirname "$LOG_FILE")"
    mkdir -p "$LOG_DIR"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Função para verificar se há mudanças no repositório
check_repo_changes() {
    cd "$REPO_DIR"

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
    log_message "Iniciando sincronização de pacotes..."

    # Atualizar repositório local
    cd "$REPO_DIR"
    git pull origin main >/dev/null 2>&1

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

        notify-send "Package Sync" "Installed missing packages:$missing_packages" --icon=package-install
    else
        log_message "All mandatory packages are already installed"
    fi

    # Atualizar timestamp do último sync
    echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$LAST_SYNC_FILE"
    log_message "Sincronização concluída"
}

# Função para mostrar status
show_status() {
    echo "=== Status do Sistema de Sincronização ==="
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
}

# Função principal
main() {
    case "${1:-check}" in
        "check")
            if check_repo_changes | grep -q "changes_detected"; then
                echo "Mudanças detectadas no repositório"
                sync_packages
            else
                echo "Nenhuma mudança detectada"
            fi
            ;;
        "sync")
            sync_packages
            ;;
        "status")
            show_status
            ;;
        *)
            echo "Uso: $0 {check|sync|status}"
            echo ""
            echo "  check  - Verificar mudanças e sincronizar se necessário"
            echo "  sync   - Forçar sincronização de pacotes"
            echo "  status - Mostrar status do sistema"
            exit 1
            ;;
    esac
}

main "$@"