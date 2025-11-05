#!/bin/bash
# Script para ativar timers do systemd user
# Deve ser executado APÓS a instalação, quando o usuário estiver logado

set -e

echo "🔄 Recarregando configuração do systemd user..."
systemctl --user daemon-reload

echo "✅ Habilitando timers do usuário..."
systemctl --user enable package-sync.timer
systemctl --user enable sway-theme-switcher.timer
systemctl --user enable sway-wallpaper.timer
systemctl --user enable system-updater.timer

echo "🚀 Iniciando timers..."
systemctl --user start package-sync.timer
systemctl --user start sway-theme-switcher.timer
systemctl --user start sway-wallpaper.timer
systemctl --user start system-updater.timer

echo "📋 Status dos timers:"
systemctl --user list-timers --all

echo ""
echo "🎉 Todos os timers foram ativados com sucesso!"
echo "💡 O filtro de luz azul agora funcionará automaticamente durante a noite."