#!/bin/bash

LIGHT_THEME="Graphite-blue-Light"
DARK_THEME="Graphite-blue-Dark"

export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

CURRENT_HOUR=$(date +%H)

# Detectar estado atual
GAMMASTEP_RUNNING=$(pgrep -x "gammastep" >/dev/null 2>&1 && echo 1 || echo 0)
CURRENT_THEME=""
if command -v gsettings >/dev/null 2>&1; then
    CURRENT_THEME=$(gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | tr -d "'")
fi

# Determinar qual modo deveria estar ativo
if [[ "10#$CURRENT_HOUR" -ge 6 && "10#$CURRENT_HOUR" -lt 18 ]]; then
    SHOULD_BE_DAY=1
else
    SHOULD_BE_DAY=0
fi

if [[ $SHOULD_BE_DAY -eq 1 ]]; then
    # Day mode - verificar e corrigir se necessário

    # Corrigir tema se estiver errado
    if [[ "$CURRENT_THEME" != "$LIGHT_THEME" ]]; then
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.gnome.desktop.interface gtk-theme "$LIGHT_THEME"
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        fi
    fi

    # Corrigir gammastep se estiver rodando (não deveria estar)
    if [[ $GAMMASTEP_RUNNING -eq 1 ]]; then
        pkill -x gammastep
        sleep 0.5
        gammastep -x -P >/dev/null 2>&1 || true
    fi
else
    # Night mode - verificar e corrigir se necessário

    # Corrigir tema se estiver errado
    if [[ "$CURRENT_THEME" != "$DARK_THEME" ]]; then
        if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.gnome.desktop.interface gtk-theme "$DARK_THEME"
            gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        fi
    fi

    # Corrigir gammastep se não estiver rodando (deveria estar)
    if [[ $GAMMASTEP_RUNNING -eq 0 ]]; then
        gammastep -O 3000 -P >/dev/null 2>&1 &
        disown
    fi
fi

exit 0
