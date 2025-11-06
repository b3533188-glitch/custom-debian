#!/bin/bash
#==============================================================================
# Script de Instalação Manual do Fix de Wallpaper
#
# Este script aplica as correções de wallpaper manualmente
#==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    error "Este script precisa ser executado como root."
    echo "Execute com: sudo $0"
    exit 1
fi

# Detect user
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    TARGET_USER="$SUDO_USER"
else
    warning "SUDO_USER não detectado. Qual usuário deve receber as configurações?"
    read -p "Digite o nome do usuário: " TARGET_USER

    if ! id "$TARGET_USER" &>/dev/null; then
        error "Usuário '$TARGET_USER' não existe!"
        exit 1
    fi
fi

USER_HOME="/home/$TARGET_USER"

if [ ! -d "$USER_HOME" ]; then
    error "Diretório home não encontrado: $USER_HOME"
    exit 1
fi

info "Instalando configurações para o usuário: $TARGET_USER"
info "Diretório home: $USER_HOME"

# Get script directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Detect profile
info "Detectando perfil do sistema..."
PROFILE=""

if [ -f "$USER_HOME/.config/sway/config" ]; then
    if grep -q "LVDS-1" "$USER_HOME/.config/sway/config" 2>/dev/null; then
        PROFILE="mac"
    elif grep -q "eDP-1" "$USER_HOME/.config/sway/config" 2>/dev/null; then
        PROFILE="notebook"
    elif grep -q "Virtual-1" "$USER_HOME/.config/sway/config" 2>/dev/null; then
        PROFILE="qemu"
    fi
fi

if [ -z "$PROFILE" ]; then
    warning "Não foi possível detectar o perfil automaticamente."
    echo "Escolha o perfil:"
    echo "1) mac (MacBook/Desktop com LVDS-1)"
    echo "2) notebook (Laptop com eDP-1)"
    echo "3) qemu (Máquina Virtual)"
    read -p "Opção [1-3]: " PROFILE_CHOICE

    case $PROFILE_CHOICE in
        1) PROFILE="mac" ;;
        2) PROFILE="notebook" ;;
        3) PROFILE="qemu" ;;
        *) error "Opção inválida!"; exit 1 ;;
    esac
fi

success "Perfil detectado/selecionado: $PROFILE"

CONFIG_DIR="$SCRIPT_DIR/config.$PROFILE"

if [ ! -d "$CONFIG_DIR" ]; then
    error "Diretório de configuração não encontrado: $CONFIG_DIR"
    exit 1
fi

# Create directories
info "Criando diretórios necessários..."
mkdir -p "$USER_HOME/.config"
mkdir -p "$USER_HOME/.local/bin"
mkdir -p "$USER_HOME/.local/state/sway"
mkdir -p "$USER_HOME/.config/systemd/user"

# Copy wallpapers
info "Copiando wallpapers..."
rm -rf "$USER_HOME/.config/wallpapers"
mkdir -p "$USER_HOME/.config/wallpapers"

if [ -d "$SCRIPT_DIR/assets/wallpapers" ]; then
    cp -a "$SCRIPT_DIR/assets/wallpapers"/. "$USER_HOME/.config/wallpapers"/

    if [ -d "$USER_HOME/.config/wallpapers/day" ] && [ -d "$USER_HOME/.config/wallpapers/night" ]; then
        success "Wallpapers copiados com sucesso"
        info "  - $(ls -1 "$USER_HOME/.config/wallpapers/day" | wc -l) wallpapers diurnos"
        info "  - $(ls -1 "$USER_HOME/.config/wallpapers/night" | wc -l) wallpapers noturnos"
    else
        error "Erro ao copiar wallpapers!"
        exit 1
    fi
else
    error "Diretório de wallpapers não encontrado: $SCRIPT_DIR/assets/wallpapers"
    exit 1
fi

# Copy Sway config
info "Copiando configuração do Sway..."
if [ -d "$CONFIG_DIR/sway" ]; then
    rm -rf "$USER_HOME/.config/sway"
    cp -a "$CONFIG_DIR/sway" "$USER_HOME/.config/sway"

    # Overlay common scripts
    if [ -d "$SCRIPT_DIR/config-common/sway/scripts" ]; then
        mkdir -p "$USER_HOME/.config/sway/scripts"
        cp -a "$SCRIPT_DIR/config-common/sway/scripts"/. "$USER_HOME/.config/sway/scripts"/
    fi

    chmod +x "$USER_HOME/.config/sway/scripts"/*.sh 2>/dev/null || true
    success "Configuração do Sway copiada"
else
    warning "Diretório sway não encontrado em $CONFIG_DIR"
fi

# Copy daemon script
info "Copiando daemon de wallpaper..."
if [ -f "$SCRIPT_DIR/scripts/sway-wallpaper-daemon.sh" ]; then
    cp "$SCRIPT_DIR/scripts/sway-wallpaper-daemon.sh" "$USER_HOME/.local/bin/"
    chmod +x "$USER_HOME/.local/bin/sway-wallpaper-daemon.sh"
    success "Daemon copiado para ~/.local/bin/"
else
    error "Script daemon não encontrado!"
    exit 1
fi

# Copy systemd service (but don't enable it - will be started by Sway)
info "Copiando serviço systemd..."
if [ -f "$CONFIG_DIR/systemd/sway-wallpaper.service" ]; then
    cp "$CONFIG_DIR/systemd/sway-wallpaper.service" "$USER_HOME/.config/systemd/user/"
    success "Serviço systemd copiado (será iniciado pelo Sway)"
else
    warning "Serviço systemd não encontrado"
fi

# Fix ownership
info "Ajustando permissões..."
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.config"
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_HOME/.local"
success "Permissões ajustadas"

# Stop any running wallpaper daemon via systemd
info "Parando daemon systemd se estiver rodando..."
USER_ID=$(id -u "$TARGET_USER")
export XDG_RUNTIME_DIR="/run/user/$USER_ID"
su - "$TARGET_USER" -c "systemctl --user stop sway-wallpaper.service 2>/dev/null || true"
su - "$TARGET_USER" -c "systemctl --user disable sway-wallpaper.service 2>/dev/null || true"
success "Daemon systemd desabilitado"

echo ""
success "✅ Instalação concluída com sucesso!"
echo ""
info "PRÓXIMOS PASSOS:"
echo "1. Reinicie o Sway (Mod+Shift+C para reload ou faça logout/login)"
echo "2. O wallpaper deve aparecer automaticamente"
echo "3. O daemon vai trocar wallpapers a cada 30 minutos"
echo ""
info "Para verificar se está funcionando:"
echo "  pgrep -a sway-wallpaper"
echo "  pgrep -a swaybg"
echo "  tail -f ~/.local/state/sway/wallpaper-daemon.log"
echo ""
