#!/bin/bash

# Script para configurar pastas padrão na home e limpar desnecessárias

set -e

echo "Configurando pastas padrão na home..."

# Criar pastas padrão se não existirem
STANDARD_DIRS=(
    "Desktop"
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Pictures/Screenshots"
    "Public"
    "Templates"
    "Videos"
)

for dir in "${STANDARD_DIRS[@]}"; do
    if [ ! -d "$HOME/$dir" ]; then
        echo "Criando diretório: $HOME/$dir"
        mkdir -p "$HOME/$dir"
    else
        echo "✓ Diretório já existe: $HOME/$dir"
    fi
done

# Remover pasta screenshots desnecessária (está vazia e o screenshot usa Pictures/Screenshots)
if [ -d "$HOME/screenshots" ]; then
    if [ -z "$(ls -A "$HOME/screenshots")" ]; then
        echo "Removendo pasta screenshots vazia e desnecessária..."
        rmdir "$HOME/screenshots"
        echo "✓ Pasta screenshots removida"
    else
        echo "⚠ Pasta screenshots não está vazia, mantendo por segurança"
        ls -la "$HOME/screenshots"
    fi
fi

# Verificar se há backups de configuração antigos que podem ser removidos
echo ""
echo "Verificando backups de configuração antigos..."
CONFIG_BACKUPS=$(find "$HOME" -maxdepth 1 -name ".config.bak_*" -type d | wc -l)
if [ "$CONFIG_BACKUPS" -gt 0 ]; then
    echo "Encontrados $CONFIG_BACKUPS backups de configuração:"
    find "$HOME" -maxdepth 1 -name ".config.bak_*" -type d | head -5
    if [ "$CONFIG_BACKUPS" -gt 5 ]; then
        echo "... e mais $((CONFIG_BACKUPS - 5)) backups"
    fi
    echo ""
    echo "Para limpar backups antigos (manter apenas os 3 mais recentes), execute:"
    echo "  find ~/.config.bak_* -maxdepth 0 -type d | sort | head -n -3 | xargs rm -rf"
fi

echo ""
echo "✓ Configuração de pastas da home concluída"