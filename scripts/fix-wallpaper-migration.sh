#!/bin/bash
#==============================================================================
# Fix Wallpaper Migration Script
#
# PURPOSE: Manually fix migration from timers to daemon services
#          Use this if you ran config update before git pull
#==============================================================================

set -e

echo "=== Corrigindo migração de timers para daemons ==="
echo ""

# Stop and disable all old timers
echo "1. Parando e desabilitando timers antigos..."
for timer in sway-wallpaper sway-theme-switcher system-updater package-sync; do
    systemctl --user stop ${timer}.timer 2>/dev/null || true
    systemctl --user disable ${timer}.timer 2>/dev/null || true
    echo "   ✓ ${timer}.timer desabilitado"
done

# Remove timer files
echo ""
echo "2. Removendo arquivos .timer..."
rm -f ~/.config/systemd/user/*.timer
echo "   ✓ Timers removidos"

# Copy new daemon service files from repository
echo ""
echo "3. Copiando novos arquivos de serviço daemon..."
REPO_DIR="$HOME/Documents/backup-repositories/debian"

if [ ! -d "$REPO_DIR" ]; then
    echo "   ✗ Repositório não encontrado em $REPO_DIR"
    echo "   Atualize o caminho no script ou rode git pull primeiro"
    exit 1
fi

# Detect profile
PROFILE="notebook"
if [ -f "$HOME/.config/sway/config" ]; then
    if grep -q "MacBook\|Apple" "$HOME/.config/sway/config" 2>/dev/null; then
        PROFILE="mac"
    fi
fi

echo "   Perfil detectado: $PROFILE"

# Copy service files
cp "$REPO_DIR/config.$PROFILE/systemd"/*.service ~/.config/systemd/user/
echo "   ✓ Arquivos de serviço copiados"

# Copy daemon scripts
echo ""
echo "4. Copiando scripts daemon..."
for daemon in sway-wallpaper-daemon.sh sway-theme-switcher-daemon.sh \
              system-updater-daemon.sh package-sync-daemon.sh; do
    if [ -f "$REPO_DIR/scripts/$daemon" ]; then
        cp "$REPO_DIR/scripts/$daemon" ~/.local/bin/
        chmod +x ~/.local/bin/$daemon
        echo "   ✓ $daemon copiado"
    else
        echo "   ✗ $daemon não encontrado no repositório"
    fi
done

# Reload systemd
echo ""
echo "5. Recarregando systemd..."
systemctl --user daemon-reload
echo "   ✓ Systemd recarregado"

# Enable and start daemon services
echo ""
echo "6. Habilitando e iniciando serviços daemon..."
for service in sway-wallpaper sway-theme-switcher system-updater package-sync; do
    systemctl --user enable ${service}.service
    systemctl --user start ${service}.service
    echo "   ✓ ${service}.service iniciado"
done

# Verify wallpaper daemon is running
echo ""
echo "7. Verificando serviços..."
sleep 2

if systemctl --user is-active --quiet sway-wallpaper.service; then
    echo "   ✓ sway-wallpaper.service está RODANDO"
else
    echo "   ✗ sway-wallpaper.service NÃO está rodando"
    echo "   Verificando log:"
    systemctl --user status sway-wallpaper.service --no-pager | head -20
fi

if pgrep -x swaybg >/dev/null; then
    echo "   ✓ swaybg está rodando"
else
    echo "   ✗ swaybg NÃO está rodando ainda (pode demorar até 30min para primeira execução)"
fi

echo ""
echo "=== Migração concluída! ==="
echo ""
echo "Logs disponíveis em:"
echo "  ~/.local/state/sway/wallpaper-daemon.log"
echo "  ~/.local/state/sway/theme-daemon.log"
echo "  ~/.local/state/system-updater/daemon.log"
echo ""
echo "Para verificar status:"
echo "  systemctl --user status sway-wallpaper.service"
echo "  journalctl --user -u sway-wallpaper.service -f"
