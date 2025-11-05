#!/bin/bash
#==============================================================================
# Sway Idle Start Script
#
# PURPOSE: Initializes the swayidle daemon with specific timeouts for screen
#          DPMS, system suspend, and screen locking.
#          Starts ENABLED by default (user can disable manually)
#==============================================================================

STATE_FILE="$HOME/.config/sway/.idle-state"

# Criar arquivo de estado se não existir (habilitado por padrão)
if [ ! -f "$STATE_FILE" ]; then
    echo "enabled" > "$STATE_FILE"
fi

# Ler estado salvo
IDLE_STATE=$(cat "$STATE_FILE")

# Se o estado é desabilitado, não iniciar o swayidle
if [ "$IDLE_STATE" = "disabled" ]; then
    echo "[$(date)] Sway idle is disabled by user preference" >> $HOME/sway-idle.log
    exit 0
fi

# Caso contrário, iniciar normalmente
echo "[$(date)] Sway idle script started" >> $HOME/sway-idle.log

swayidle -w \
    timeout 90 "$HOME/.config/sway/scripts/idle-dim-screen.sh" resume "$HOME/.config/sway/scripts/restore-brightness.sh" \
    timeout 180 "$HOME/.config/sway/scripts/idle-lock-screen.sh" \
    timeout 300 "$HOME/.config/sway/scripts/idle-dpms-off.sh" resume "$HOME/.config/sway/scripts/idle-dpms-on.sh" \
    timeout 600 "$HOME/.config/sway/scripts/idle-suspend.sh" \
    before-sleep "$HOME/.config/sway/scripts/lock-screen.sh -f"
