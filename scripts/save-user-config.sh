#!/bin/bash

# Script para salvar configurações do usuário
# Usado durante a instalação para manter preferências

USER_CONFIG_DIR="$HOME/.config/system-updater"
USER_PREFERENCES="$USER_CONFIG_DIR/user_preferences.conf"

# Função para salvar configuração
save_config() {
    local key="$1"
    local value="$2"

    mkdir -p "$USER_CONFIG_DIR"

    # Criar arquivo se não existir
    if [ ! -f "$USER_PREFERENCES" ]; then
        cat > "$USER_PREFERENCES" << 'EOF'
# Configurações do usuário salvas automaticamente
# Este arquivo é usado pelo sistema de atualizações automáticas
# para manter as preferências do usuário entre atualizações

EOF
    fi

    # Atualizar ou adicionar configuração
    if grep -q "^$key=" "$USER_PREFERENCES"; then
        sed -i "s|^$key=.*|$key=\"$value\"|" "$USER_PREFERENCES"
    else
        echo "$key=\"$value\"" >> "$USER_PREFERENCES"
    fi

    echo "Configuração salva: $key = $value"
}

# Função para carregar configuração
load_config() {
    local key="$1"

    if [ -f "$USER_PREFERENCES" ]; then
        grep "^$key=" "$USER_PREFERENCES" | cut -d'=' -f2- | tr -d '"'
    fi
}

# Função para listar todas as configurações
list_configs() {
    if [ -f "$USER_PREFERENCES" ]; then
        echo "=== Configurações do Usuário ==="
        cat "$USER_PREFERENCES" | grep -v '^#' | grep -v '^$'
    else
        echo "Nenhuma configuração salva ainda."
    fi
}

# Função principal
case "${1:-help}" in
    "save")
        if [ $# -ne 3 ]; then
            echo "Uso: $0 save <chave> <valor>"
            exit 1
        fi
        save_config "$2" "$3"
        ;;
    "load")
        if [ $# -ne 2 ]; then
            echo "Uso: $0 load <chave>"
            exit 1
        fi
        load_config "$2"
        ;;
    "list")
        list_configs
        ;;
    *)
        echo "Uso: $0 {save|load|list}"
        echo ""
        echo "  save <chave> <valor>  - Salvar configuração"
        echo "  load <chave>          - Carregar configuração"
        echo "  list                  - Listar todas as configurações"
        exit 1
        ;;
esac