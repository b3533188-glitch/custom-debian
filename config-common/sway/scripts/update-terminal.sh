#!/bin/bash
#==============================================================================
# Interface Visual para Atualizações
#==============================================================================

# Configurações
CACHE_DIR="$HOME/.cache/system-updater"
UPDATE_AVAILABLE_FILE="$CACHE_DIR/updates_available"

# Cores e funções de UI
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
BOLD='\033[1m'; DIM='\033[2m'

# Progress bar personalizada
show_progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Processando}"
    local width=40

    # Calcular porcentagem
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    # Construir barra
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done

    # Mostrar barra com animação
    printf "\r${BLUE}${message}${NC} [${GREEN}${bar}${NC}] ${BOLD}%3d%%${NC} (%d/%d)" "$percent" "$current" "$total"

    # Nova linha se completo
    if [ "$current" -eq "$total" ]; then
        echo ""
    fi
}

# Verificar se há updates available
if [ ! -f "$UPDATE_AVAILABLE_FILE" ]; then
    echo "╔════════════════════════════════════════╗"
    echo "║          System Updated           ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "✅ Não há updates available no momento."
    echo ""
    read -p "Pressione ENTER para fechar..."
    exit 0
fi

# Função para desenhar cabeçalho
draw_header() {
    clear
    echo "╔════════════════════════════════════════╗"
    echo "║        Sistema de Atualizações        ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
}

# Função para mostrar pacotes que serão atualizados
show_update_details() {
    draw_header
    echo "📋 Detalhes das updates available:"
    echo ""

    # Verificar atualizações APT
    echo "🔄 Pacotes do sistema:"
    apt list --upgradable 2>/dev/null | grep -v "WARNING" | tail -n +2 | head -10

    local apt_total=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
    if [ "$apt_total" -gt 10 ]; then
        echo "... e mais $((apt_total - 10)) pacotes"
    fi
    echo ""

    # Verificar atualizações Flatpak se disponível
    if command -v flatpak >/dev/null 2>&1; then
        echo "📱 Aplicações Flatpak:"
        flatpak remote-ls --updates 2>/dev/null | head -5

        local flatpak_total=$(flatpak remote-ls --updates 2>/dev/null | wc -l)
        if [ "$flatpak_total" -gt 5 ]; then
            echo "... e mais $((flatpak_total - 5)) aplicações"
        fi
        echo ""
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Opções:"
    echo "  [1] Aplicar todas as atualizações"
    echo "  [2] Ver mais detalhes"
    echo "  [3] Cancelar"
    echo ""
    read -p "Escolha uma opção [1-3]: " choice

    case "$choice" in
        1)
            apply_updates_with_progress
            ;;
        2)
            show_detailed_view
            ;;
        3|*)
            echo "Operação cancelada."
            exit 0
            ;;
    esac
}

# Função para mostrar visualização detalhada
show_detailed_view() {
    draw_header
    echo "📋 Lista completa de atualizações:"
    echo ""

    echo "🔄 Todos os pacotes do sistema:"
    apt list --upgradable 2>/dev/null | grep -v "WARNING" | tail -n +2
    echo ""

    if command -v flatpak >/dev/null 2>&1; then
        echo "📱 Todas as aplicações Flatpak:"
        flatpak remote-ls --updates 2>/dev/null
        echo ""
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    read -p "Deseja aplicar todas as atualizações? (s/N): " confirm

    if [[ "$confirm" =~ ^[Ss]$ ]]; then
        apply_updates_with_progress
    else
        echo "Operação cancelada."
        exit 0
    fi
}

# Função para aplicar atualizações com barra de progresso visual
apply_updates_with_progress() {
    draw_header
    echo "🚀 Aplicando atualizações..."
    echo ""

    # Função para executar comando com progress bar
    run_update_step() {
        local command="$1"
        local message="$2"
        local steps="${3:-10}"

        # Mostrar progresso
        for ((i=0; i<=steps; i++)); do
            show_progress_bar "$i" "$steps" "$message"

            # Executar comando no meio do progresso
            if [ "$i" -eq $((steps/2)) ]; then
                eval "$command" >/dev/null 2>&1 &
                local cmd_pid=$!

                # Continuar progresso enquanto executa
                while kill -0 "$cmd_pid" 2>/dev/null; do
                    sleep 0.1
                    ((i < steps)) && ((i++))
                    show_progress_bar "$i" "$steps" "$message"
                done
                wait "$cmd_pid"
                local exit_code=$?

                # Completar progresso
                show_progress_bar "$steps" "$steps" "$message"
                if [ "$exit_code" -eq 0 ]; then
                    echo -e " ${GREEN}✓${NC}"
                else
                    echo -e " ${RED}✗${NC}"
                    return $exit_code
                fi
                return 0
            fi
            sleep 0.1
        done
    }

    # Executar atualizações com progress bar
    echo "📦 Executando atualizações do sistema:"
    echo ""

    run_update_step "doas apt update" "Atualizando repositórios" 8
    run_update_step "~/.local/bin/system-updater.sh --no-notify update" "Aplicando atualizações" 15

    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║         Atualizações Concluídas       ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "✅ Todas as atualizações foram aplicadas com sucesso!"
    echo ""

    # Limpar cache de atualizações
    echo "🧹 Finalizando..."
    show_progress_bar 0 3 "Limpando cache"
    rm -f "$UPDATE_AVAILABLE_FILE"
    show_progress_bar 1 3 "Limpando cache"
    ~/.local/bin/system-updater.sh --no-notify check >/dev/null 2>&1
    show_progress_bar 2 3 "Limpando cache"
    sleep 0.2
    show_progress_bar 3 3 "Limpando cache"
    echo -e " ${GREEN}✓${NC}"

    echo ""
    read -p "Pressione ENTER para fechar..."
}

# Executar interface principal
show_update_details