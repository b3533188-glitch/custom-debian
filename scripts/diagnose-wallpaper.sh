#!/bin/bash

# Script de diagnóstico para problemas com wallpaper
# Execute este script na máquina com o problema

echo "=== Diagnóstico de Problemas com Wallpaper ==="
echo ""

# Verificar se swaybg está rodando
echo "1. Status do swaybg:"
if pgrep -x swaybg >/dev/null; then
    echo "   ✓ swaybg está rodando"
    echo "   Processos:"
    ps aux | grep swaybg | grep -v grep
else
    echo "   ✗ swaybg NÃO está rodando"
fi
echo ""

# Verificar wallpaper atual
echo "2. Wallpaper atual:"
WALLPAPER_LINK="$HOME/.config/wallpapers/wallpaper_current"
if [ -L "$WALLPAPER_LINK" ]; then
    CURRENT_WALLPAPER=$(readlink -f "$WALLPAPER_LINK")
    echo "   ✓ Link existe: $WALLPAPER_LINK"
    echo "   → Aponta para: $CURRENT_WALLPAPER"
    if [ -f "$CURRENT_WALLPAPER" ]; then
        echo "   ✓ Arquivo de imagem existe"
    else
        echo "   ✗ Arquivo de imagem NÃO existe!"
    fi
else
    echo "   ✗ Link wallpaper_current NÃO existe"
fi
echo ""

# Verificar timers ativos
echo "3. Systemd timers ativos:"
systemctl --user list-timers --all | grep -E "(sway-wallpaper|sway-theme-switcher)" || echo "   Nenhum timer encontrado"
echo ""

# Verificar logs recentes
echo "4. Logs recentes:"
if [ -f "$HOME/.local/state/sway/wallpaper.log" ]; then
    echo "   Últimas 5 linhas do wallpaper.log:"
    tail -5 "$HOME/.local/state/sway/wallpaper.log" | sed 's/^/   /'
else
    echo "   Nenhum log de wallpaper encontrado"
fi
echo ""

if [ -f "$HOME/sway-idle.log" ]; then
    echo "   Últimas 5 linhas do sway-idle.log:"
    tail -5 "$HOME/sway-idle.log" | sed 's/^/   /'
else
    echo "   Nenhum log de idle encontrado"
fi
echo ""

# Verificar scripts de idle
echo "5. Status do swayidle:"
if pgrep -x swayidle >/dev/null; then
    echo "   ✓ swayidle está rodando"
    echo "   Processos:"
    ps aux | grep swayidle | grep -v grep
else
    echo "   ✗ swayidle NÃO está rodando"
fi
echo ""

# Verificar eventos recentes
echo "6. Monitoramento em tempo real (10 segundos):"
echo "   Pressione Ctrl+C para parar"
echo ""

for i in {1..10}; do
    echo "   [$i/10] $(date '+%H:%M:%S') - swaybg rodando: $(pgrep -x swaybg >/dev/null && echo 'SIM' || echo 'NÃO')"
    sleep 1
done

echo ""
echo "=== Sugestões de correção ==="
echo ""
echo "Se o wallpaper está sumindo frequentemente:"
echo "1. Verifique se os timers estão configurados corretamente:"
echo "   systemctl --user list-timers"
echo ""
echo "2. Desative temporariamente os timers para testar:"
echo "   systemctl --user stop sway-wallpaper.timer sway-theme-switcher.timer"
echo ""
echo "3. Verifique logs completos:"
echo "   journalctl --user -u sway-wallpaper.service -f"
echo "   journalctl --user -u sway-theme-switcher.service -f"
echo ""
echo "4. Reinicie manualmente o wallpaper:"
echo "   ~/.config/sway/scripts/change-wallpaper.sh"