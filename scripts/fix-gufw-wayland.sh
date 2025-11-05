#!/bin/bash

# Script para corrigir problemas do gufw no Wayland
# Executa as correções imediatamente

set -e

echo "Corrigindo gufw para funcionar no Wayland..."

# Verificar se gufw está instalado
if ! command -v gufw >/dev/null 2>&1; then
    echo "Erro: gufw não está instalado"
    exit 1
fi

# Criar wrapper script para Wayland
echo "Criando wrapper script para Wayland..."
doas tee /usr/local/bin/gufw-wayland > /dev/null << 'EOF'
#!/bin/bash
export GDK_BACKEND=wayland
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
pkexec env DISPLAY=$WAYLAND_DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY GDK_BACKEND=wayland /usr/bin/gufw "$@"
EOF

doas chmod +x /usr/local/bin/gufw-wayland

# Configurar PolicyKit
echo "Configurando PolicyKit para gufw..."
doas tee /etc/polkit-1/localauthority/50-local.d/50-gufw.pkla > /dev/null << 'EOF'
[Allow gufw for admin users]
Identity=unix-group:sudo;unix-group:wheel;unix-group:admin
Action=com.ubuntu.pkexec.gufw
ResultActive=auth_admin_keep
EOF

# Corrigir arquivo .desktop
if [ -f /usr/share/applications/gufw.desktop ]; then
    echo "Corrigindo arquivo .desktop do gufw..."

    # Fazer backup se não existir
    if [ ! -f /usr/share/applications/gufw.desktop.bak ]; then
        doas cp /usr/share/applications/gufw.desktop /usr/share/applications/gufw.desktop.bak
    fi

    # Atualizar Exec para usar o wrapper
    doas sed -i 's|^Exec=.*|Exec=/usr/local/bin/gufw-wayland|' /usr/share/applications/gufw.desktop
fi

# Remover wrappers antigos
if [ -f /usr/local/bin/gufw-sway ]; then
    echo "Removendo wrapper antigo..."
    doas rm -f /usr/local/bin/gufw-sway
fi

echo "✓ Gufw corrigido para funcionar no Wayland"
echo "Agora você pode abrir o gufw pelo menu de aplicações ou executando: gufw-wayland"