#!/bin/bash

# Script para executar atualizações em terminal flutuante

SYSTEM_UPDATER="$HOME/.local/bin/system-updater.sh"

if [ ! -f "$SYSTEM_UPDATER" ]; then
    notify-send "System Update" "Error: System updater not found" -u critical
    exit 1
fi

# Verificar status atual
status_json=$("$SYSTEM_UPDATER" waybar)
status_text=$(echo "$status_json" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)

# Se status é checkmark (sem updates), fazer busca em background
if [ "$status_text" = "✓" ]; then
    # Criar flag de checagem para alterar ícone da waybar
    CACHE_DIR="$HOME/.cache/system-updater"
    mkdir -p "$CACHE_DIR"
    touch "$CACHE_DIR/checking"

    # Enviar notificação de busca
    notify-send "System Update" "Checking for updates..." -u normal

    # Executar force-check em background
    (
        "$SYSTEM_UPDATER" force-check >/dev/null 2>&1

        # Remover flag de checagem
        rm -f "$CACHE_DIR/checking"

        # Verificar resultado detalhado
        STATE_DIR="$HOME/.local/state/system-updater"
        apt_count=0
        flatpak_count=0
        config_count=0

        # Ler contadores de cache
        if [ -f "$STATE_DIR/apt_updates" ]; then
            apt_count=$(cat "$STATE_DIR/apt_updates" 2>/dev/null || echo 0)
        fi
        if [ -f "$STATE_DIR/flatpak_updates" ]; then
            flatpak_count=$(cat "$STATE_DIR/flatpak_updates" 2>/dev/null || echo 0)
        fi

        # Verificar config updates
        REPO_DIR="$HOME/.local/share/custom-debian-repo"
        if [ -d "$REPO_DIR" ]; then
            cd "$REPO_DIR" 2>/dev/null
            INSTALLED_COMMIT=$(cat "$STATE_DIR/installed_commit" 2>/dev/null || echo "")
            if [ -n "$INSTALLED_COMMIT" ]; then
                git fetch origin main >/dev/null 2>&1
                REMOTE_COMMIT=$(git rev-parse origin/main 2>/dev/null || echo "")
                if [ -n "$REMOTE_COMMIT" ] && [ "$INSTALLED_COMMIT" != "$REMOTE_COMMIT" ]; then
                    config_count=1
                fi
            fi
        fi

        total=$((apt_count + flatpak_count + config_count))

        if [ "$total" -eq 0 ]; then
            notify-send "System Update" "System is already up to date" -u low
        else
            # Construir mensagem detalhada
            details=""
            if [ "$apt_count" -gt 0 ]; then
                details="${details}APT: $apt_count package(s)\n"
            fi
            if [ "$flatpak_count" -gt 0 ]; then
                details="${details}Flatpak: $flatpak_count app(s)\n"
            fi
            if [ "$config_count" -gt 0 ]; then
                details="${details}Configuration: 1 update\n"
            fi

            notify-send "System Update" "$total update(s) available\n\n$details\nClick to install" -u normal
        fi
    ) &

    exit 0
fi

# Se há updates, abrir terminal e executar atualização
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'EOF'
#!/bin/bash

# Cores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GRAY='\033[0;90m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

CHECKMARK="✓"

draw_box() {
    local text="$1"
    local color="${2:-$CYAN}"
    local length=$((${#text} + 2))
    echo -e "${color}┌$(printf '─%.0s' $(seq 1 $length))┐${NC}"
    echo -e "${color}│ ${BOLD}$text${NC}${color} │${NC}"
    echo -e "${color}└$(printf '─%.0s' $(seq 1 $length))┘${NC}"
}

clear
echo ""
draw_box "SYSTEM UPDATES" "$CYAN"
echo ""

SYSTEM_UPDATER="$HOME/.local/bin/system-updater.sh"

if [ ! -f "$SYSTEM_UPDATER" ]; then
    echo -e "${RED}Error: System updater not found${NC}"
    echo ""
    echo -e "${GRAY}Press Enter to close...${NC}"
    read
    exit 1
fi

echo -e "${YELLOW}Checking for updates...${NC}"
echo ""

# Verificar updates
status_json=$("$SYSTEM_UPDATER" waybar)
status_text=$(echo "$status_json" | grep -o '"text":"[^"]*"' | cut -d'"' -f4)

# Extrair número de updates
updates=$(echo "$status_text" | grep -o '[0-9]\+' | head -1)
if [ -z "$updates" ]; then
    updates="1"
fi
echo -e "${CYAN}Found ${BOLD}$updates${NC}${CYAN} update(s) available${NC}"
echo ""

# Perguntar senha com interface bonita
echo -e "${YELLOW}🔐 Administrator authentication required${NC}"
echo ""
doas echo "" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}Authentication failed${NC}"
    echo ""
    echo -e "${GRAY}Press Enter to close...${NC}"
    read
    exit 1
fi

# Executar atualizações (inclui config, apt, flatpak)
"$SYSTEM_UPDATER" update

echo ""
echo -e " ${GREEN}${CHECKMARK}${NC} ${BOLD}All updates have been applied${NC}"
echo ""

# Re-check para atualizar waybar
echo -e "${GRAY}Refreshing update status...${NC}"
"$SYSTEM_UPDATER" check >/dev/null 2>&1

echo ""
echo -e "${GRAY}Press Enter to close...${NC}"
read
EOF

chmod +x "$TEMP_SCRIPT"

# Executar em terminal flutuante
kitty --app-id floating-terminal --title "System Updates" -e bash -c "$TEMP_SCRIPT; rm -f $TEMP_SCRIPT" &