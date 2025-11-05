#!/bin/bash
#==============================================================================
# Configuration Library

#==============================================================================
# FUNCTION: run_as_user
# DESCRIPTION: Runs command as user using available privilege escalation tool
#==============================================================================
run_as_user() {
    local user="$1"
    shift

    # Use the privilege escalation tool defined in main.sh
    if [ "${PRIV_EXEC:-}" = "doas" ]; then
        doas -u "$user" "$@"
    else
        sudo -u "$user" "$@"
    fi
}

#==============================================================================
# FUNCTION: validate_sudo_user
# DESCRIPTION: Validates SUDO_USER variable for security
#==============================================================================
validate_sudo_user() {
    if [ -z "$SUDO_USER" ]; then
        error "ERRO: Variável SUDO_USER não está definida."
        exit 1
    fi

    if ! [[ "$SUDO_USER" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        error "ERRO: Nome de usuário '$SUDO_USER' contém caracteres inválidos."
        exit 1
    fi

    if ! id "$SUDO_USER" &>/dev/null; then
        error "ERRO: Usuário '$SUDO_USER' não existe no sistema."
        exit 1
    fi

    local USER_ID=$(id -u "$SUDO_USER")
    if ! [[ "$USER_ID" =~ ^[0-9]+$ ]] || [ "$USER_ID" -lt 1000 ]; then
        error "ERRO: UID do usuário '$SUDO_USER' inválido ou é usuário do sistema."
        exit 1
    fi
}

#==============================================================================
# FUNCTION: apply_critical_sway_configurations
# DESCRIPTION: Applies all critical Sway configurations including systemd timers,
#              scripts, and other essential components that must always work.
#==============================================================================
apply_critical_sway_configurations() {
    local LOCAL_CONFIG_DIR="$1"
    local SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    info "Applying critical Sway configurations..."

    # Ensure user directories exist
    mkdir -p "$USER_HOME/.config"
    mkdir -p "$USER_HOME/.local/bin"
    SYSTEMD_USER_DIR="$USER_HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"

    # Copy and setup systemd services (CRITICAL)
    if [ -d "$LOCAL_CONFIG_DIR/systemd" ]; then
        info "Setting up systemd user services..."

        # Remove old timer files if they exist (migrating to daemon services)
        for timer in sway-wallpaper.timer sway-theme-switcher.timer system-updater.timer package-sync.timer; do
            if [ -f "$SYSTEMD_USER_DIR/$timer" ]; then
                warning "Removing old timer: $timer (migrating to daemon service)"
                rm -f "$SYSTEMD_USER_DIR/$timer"
            fi
        done

        # Stop and disable old timers if running
        info "Cleaning up old systemd timers..."
        for timer in sway-wallpaper sway-theme-switcher system-updater package-sync; do
            su - "$SUDO_USER" -c "systemctl --user stop ${timer}.timer 2>/dev/null || true"
            su - "$SUDO_USER" -c "systemctl --user disable ${timer}.timer 2>/dev/null || true"
        done

        # Copy ALL systemd service files (but NOT timers)
        cp "$LOCAL_CONFIG_DIR/systemd"/*.service "$SYSTEMD_USER_DIR/" 2>/dev/null || true

        # Setup system-updater with user replacement
        if [ -f "$LOCAL_CONFIG_DIR/systemd/system-updater.service" ]; then
            info "Configuring system updater service..."
            sed "s/%i/$SUDO_USER/g" "$LOCAL_CONFIG_DIR/systemd/system-updater.service" > "$SYSTEMD_USER_DIR/system-updater.service"

            # Copy all essential scripts from repository
            for script in system-updater.sh system-monitor.sh backup-system.sh \
                          sway-wallpaper-daemon.sh sway-theme-switcher-daemon.sh \
                          system-updater-daemon.sh package-sync-daemon.sh; do
                if [ -f "$SCRIPT_DIR/../scripts/$script" ]; then
                    cp "$SCRIPT_DIR/../scripts/$script" "$USER_HOME/.local/bin/"
                    chmod +x "$USER_HOME/.local/bin/$script"
                fi
            done
        fi

        # Ensure proper ownership
        chown -R "$SUDO_USER":"$SUDO_USER" "$SYSTEMD_USER_DIR"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local"

        # Setup user systemd session and enable all services
        setup_user_systemd_session
        success "Systemd daemon services configured."
    fi

    # Copy essential scripts to .local/bin (CRITICAL)
    if [ -d "$LOCAL_CONFIG_DIR/scripts" ]; then
        info "Copying essential user scripts from profile..."
        cp "$LOCAL_CONFIG_DIR/scripts"/* "$USER_HOME/.local/bin/" 2>/dev/null || true
    fi
    
    # Copy essential scripts from main scripts directory if they don't exist
    if [ -d "$SCRIPT_DIR/../scripts" ]; then
        info "Copying essential scripts from main directory..."
        for script in "$SCRIPT_DIR/../scripts"/*.sh; do
            if [ -f "$script" ]; then
                script_name=$(basename "$script")
                if [ ! -f "$USER_HOME/.local/bin/$script_name" ]; then
                    cp "$script" "$USER_HOME/.local/bin/" 2>/dev/null || true
                fi
            fi
        done
    fi
    
    # Make all scripts executable and set proper ownership
    if [ -d "$USER_HOME/.local/bin" ]; then
        chmod +x "$USER_HOME/.local/bin"/* 2>/dev/null || true
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local/bin"
        success "Essential scripts copied and configured."
    fi

    # Sync waybar configuration (CRITICAL for UI)
    if [ -d "$LOCAL_CONFIG_DIR/waybar" ]; then
        info "Syncing waybar configuration..."
        rm -rf "$USER_HOME/.config/waybar"
        cp -a "$LOCAL_CONFIG_DIR/waybar" "$USER_HOME/.config/waybar" 2>/dev/null || true
        chmod +x "$USER_HOME/.config/waybar/scripts"/*.sh 2>/dev/null || true
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/waybar"
        success "Waybar configuration synced."
    fi

    # Sync sway configuration (CRITICAL for WM)
    if [ -d "$LOCAL_CONFIG_DIR/sway" ]; then
        info "Syncing sway configuration..."
        rm -rf "$USER_HOME/.config/sway"
        cp -a "$LOCAL_CONFIG_DIR/sway" "$USER_HOME/.config/sway" 2>/dev/null || true

        # Sync common sway scripts (overlay on top)
        if [ -d "$SCRIPT_DIR/../config-common/sway/scripts" ]; then
            mkdir -p "$USER_HOME/.config/sway/scripts"
            cp -a "$SCRIPT_DIR/../config-common/sway/scripts"/. "$USER_HOME/.config/sway/scripts"/ 2>/dev/null || true
        fi

        chmod +x "$USER_HOME/.config/sway/scripts"/*.sh 2>/dev/null || true

        # Apply mouse acceleration settings if needed
        if [ "$DISABLE_MOUSE_ACCEL" = "true" ]; then
            apply_mouse_acceleration_config "$USER_HOME/.config/sway/config"
        fi

        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/sway"
        success "Sway configuration synced."
    fi

    # Sync wallpapers (CRITICAL for wallpaper timer)
    if [ -d "$SCRIPT_DIR/../assets/wallpapers" ]; then
        info "Syncing wallpapers..."
        rm -rf "$USER_HOME/.config/wallpapers"
        mkdir -p "$USER_HOME/.config/wallpapers"
        if cp -a "$SCRIPT_DIR/../assets/wallpapers"/. "$USER_HOME/.config/wallpapers"/; then
            chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/wallpapers"
            # Verify wallpapers were copied successfully
            if [ -d "$USER_HOME/.config/wallpapers/day" ] && [ -d "$USER_HOME/.config/wallpapers/night" ]; then
                success "Wallpapers synced successfully."
            else
                error "Wallpaper directories are missing after copy!"
                exit 1
            fi
        else
            error "Failed to copy wallpapers!"
            exit 1
        fi
    else
        warning "Wallpaper assets directory not found at $SCRIPT_DIR/../assets/wallpapers"
    fi

    # Sync all other configuration directories (swaync, wofi, wlogout, kitty, etc.)
    info "Syncing all application configurations..."
    for config_dir in "$LOCAL_CONFIG_DIR"/*/; do
        if [ -d "$config_dir" ]; then
            dir_name=$(basename "$config_dir")
            # Skip directories already synced or special directories
            if [[ "$dir_name" != "systemd" && "$dir_name" != "sway" && "$dir_name" != "waybar" ]]; then
                info "Syncing $dir_name configuration..."
                rm -rf "$USER_HOME/.config/$dir_name"
                cp -a "$config_dir" "$USER_HOME/.config/$dir_name" 2>/dev/null || true
                chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/$dir_name"
            fi
        fi
    done
    success "All application configurations synced."

    # Copy essential dotfiles (CRITICAL for session)
    info "Ensuring essential dotfiles..."
    for dotfile in ".profile" ".sway-session" ".bashrc"; do
        if [ -f "$LOCAL_CONFIG_DIR/$dotfile" ]; then
            cp "$LOCAL_CONFIG_DIR/$dotfile" "$USER_HOME/"
            if [ "$dotfile" = ".sway-session" ]; then
                chmod +x "$USER_HOME/$dotfile"
            fi
            chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/$dotfile"
        fi
    done
    success "Essential dotfiles ensured."

    # Save installed commit for future update tracking
    info "Saving installed configuration commit..."
    local state_dir="$USER_HOME/.local/state/system-updater"
    mkdir -p "$state_dir"
    if [ -d "$SCRIPT_DIR/../.git" ]; then
        cd "$SCRIPT_DIR/.."
        git rev-parse HEAD > "$state_dir/installed_commit" 2>/dev/null || true
        chown "$SUDO_USER":"$SUDO_USER" "$state_dir/installed_commit"
        success "Installed commit saved: $(cat "$state_dir/installed_commit" 2>/dev/null || echo 'unknown')"
    fi

    # Initialize update notification system
    if [ -f "$USER_HOME/.local/bin/system-updater.sh" ]; then
        info "Initializing update notification system..."
        # Run initial check to populate caches (run as user, in background to not block)
        su - "$SUDO_USER" -c "$USER_HOME/.local/bin/system-updater.sh check >/dev/null 2>&1" & disown
        success "Update system will run initial check in background"
    fi

    success "All critical Sway configurations applied successfully."
}

#==============================================================================
# FUNCTION: setup_user_systemd_session
# DESCRIPTION: Ensures user systemd session is active and enables all timers
#==============================================================================
setup_user_systemd_session() {
    info "Setting up user systemd session and daemon services..."
    local USER_ID=$(id -u "$SUDO_USER")

    # Ensure user has a systemd session and enable lingering
    loginctl enable-linger "$SUDO_USER" 2>/dev/null || true

    # Make sure XDG_RUNTIME_DIR exists
    if [ ! -d "/run/user/$USER_ID" ]; then
        mkdir -p "/run/user/$USER_ID"
        chown "$SUDO_USER":"$SUDO_USER" "/run/user/$USER_ID"
        chmod 700 "/run/user/$USER_ID"
    fi

    # Enable systemd daemon services for the user
    info "Enabling user systemd daemon services..."
    export XDG_RUNTIME_DIR="/run/user/$USER_ID"
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"

    # Reload systemd user daemon
    su - "$SUDO_USER" -c "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR systemctl --user daemon-reload" 2>/dev/null || true

    # Enable and start all daemon services
    for service in "$SYSTEMD_USER_DIR"/*.service; do
        if [ -f "$service" ]; then
            service_name=$(basename "$service")
            info "Enabling and starting $service_name..."
            su - "$SUDO_USER" -c "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR systemctl --user enable $service_name" 2>/dev/null || true
            su - "$SUDO_USER" -c "XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR systemctl --user start $service_name" 2>/dev/null || true
        fi
    done

    success "User systemd daemon services configured and enabled."
}

#==============================================================================
# FUNCTION: finalize_configuration
#==============================================================================
finalize_configuration() {
    info "Iniciando fase de configuração final do sistema..."

    # Validate SUDO_USER for security before any operations
    validate_sudo_user

    info "Configurando o ZRAM (lz4, 30% da RAM)..."
    echo -e "ALGO=lz4\nPERCENT=30" > /etc/default/zramswap
    success "ZRAM configurado."

    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "kvm" ]]; then
        info "Adicionando usuário '$SUDO_USER' ao grupo 'libvirt' para KVM..."
        run_with_progress "usermod -aG libvirt '$SUDO_USER'" "Adicionando usuário ao grupo libvirt"
        success "Usuário adicionado. (Requer novo login para ter efeito)"
    fi

    if [ "$DESKTOP_ENV" == "GNOME" ]; then
        info "Verificando pacotes desnecessários do GNOME para remover..."
        GNOME_PURGE_LIST=(gnome-terminal gnome-calendar gnome-contacts gnome-weather gnome-maps gnome-clocks totem gnome-calculator gnome-characters yelp simple-scan malcontent gnome-font-viewer gnome-logs gnome-connections evince loupe system-config-printer zutty gnome-snapshot gnome-tour baobab)
        PKGS_TO_PURGE=()
        for pkg in "${GNOME_PURGE_LIST[@]}"; do
            if dpkg -l | grep -q " $pkg "; then
                PKGS_TO_PURGE+=("$pkg")
            fi
        done
        if [ ${#PKGS_TO_PURGE[@]} -gt 0 ]; then
            run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get purge --ignore-hold -qq -y ${PKGS_TO_PURGE[*]}" "Removendo pacotes do GNOME"
        else
            info "Nenhum pacote desnecessário do GNOME para remover."
        fi
    elif [ "$DESKTOP_ENV" == "KDE" ]; then
        info "Verificando pacotes desnecessários do KDE para remover..."
        KDE_PURGE_LIST=(zutty kdeconnect konqueror khelpcenter kwalletmanager plasma-welcome kfind)
        PKGS_TO_PURGE=()
        for pkg in "${KDE_PURGE_LIST[@]}"; do
            if dpkg -l | grep -q " $pkg "; then
                PKGS_TO_PURGE+=("$pkg")
            fi
        done
        if [ ${#PKGS_TO_PURGE[@]} -gt 0 ]; then
            run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get purge --ignore-hold -qq -y ${PKGS_TO_PURGE[*]}" "Removendo pacotes do KDE"
        else
            info "Nenhum pacote desnecessário do KDE para remover."
        fi
    fi

    if [ "$DESKTOP_ENV" == "Sway" ]; then
        info "Verificando e removendo o terminal 'foot' (se instalado)..."
        if dpkg -l | grep -q " foot "; then
            run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get purge -qq -y foot" "Removendo terminal foot"
        else
            info "Pacote 'foot' não está instalado."
        fi

        info "Configurando o módulo i2c-dev para ser carregado na inicialização (para ddcutil)..."
        echo "i2c-dev" > /etc/modules-load.d/ddcutil.conf
        success "Módulo i2c-dev configurado."
    fi

    run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get autoremove --purge -qq -y" "Limpando pacotes órfãos"

    if [ "$WANT_SNAPSHOTS" = true ]; then 
        info "Criando o ponto de restauração final do sistema..."
        timeshift --create --comments "Snapshot após o script de pós-instalação" --tags D
        success "Ponto de restauração 'Depois do Script' criado com sucesso!"
    fi

    if [ "$DESKTOP_ENV" == "Sway" ]; then
        if [ -z "$CONFIG_TYPE" ]; then
            warning "A variável CONFIG_TYPE não está definida. Pulando a cópia de configurações do Sway."
            return
        fi

        info "Verificando arquivos de configuração locais para o Sway ($CONFIG_TYPE)..."
        SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

        if [ "$CONFIG_TYPE" == "mac" ]; then
            LOCAL_CONFIG_DIR="$SCRIPT_DIR/../config.mac"
        elif [ "$CONFIG_TYPE" == "qemu" ]; then
            LOCAL_CONFIG_DIR="$SCRIPT_DIR/../config.qemu"
        else
            LOCAL_CONFIG_DIR="$SCRIPT_DIR/../config.notebook"
        fi

        if [ -d "$LOCAL_CONFIG_DIR" ]; then
            # Check if .config exists BEFORE applying critical configurations
            local config_exists=false
            if [ -e "$USER_HOME/.config" ]; then
                config_exists=true
            fi

            if [ "$config_exists" = false ]; then
                info "Syncing new configuration directory..."
                mkdir -p "$USER_HOME/.config"

                # Sync all config directories from profile
                for config_dir in "$LOCAL_CONFIG_DIR"/*/; do
                    if [ -d "$config_dir" ]; then
                        dir_name=$(basename "$config_dir")
                        rm -rf "$USER_HOME/.config/$dir_name"
                        cp -a "$config_dir" "$USER_HOME/.config/$dir_name" 2>/dev/null || true
                    fi
                done

                # Sync unified wallpapers
                if [ -d "$SCRIPT_DIR/../assets/wallpapers" ]; then
                    info "Syncing unified wallpapers..."
                    rm -rf "$USER_HOME/.config/wallpapers"
                    mkdir -p "$USER_HOME/.config/wallpapers"
                    if cp -a "$SCRIPT_DIR/../assets/wallpapers"/. "$USER_HOME/.config/wallpapers"/; then
                        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/wallpapers"
                        # Verify wallpapers were copied successfully
                        if [ -d "$USER_HOME/.config/wallpapers/day" ] && [ -d "$USER_HOME/.config/wallpapers/night" ]; then
                            success "Wallpapers synced successfully."
                        else
                            error "Wallpaper directories are missing after copy!"
                            exit 1
                        fi
                    else
                        error "Failed to copy wallpapers!"
                        exit 1
                    fi
                else
                    warning "Wallpaper assets directory not found at $SCRIPT_DIR/../assets/wallpapers"
                fi

                chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
                success "Configuration directory synced successfully."
            else
                info "Configuration directory exists. Will apply critical configurations only."
            fi

            # Apply critical configurations AFTER checking/syncing
            apply_critical_sway_configurations "$LOCAL_CONFIG_DIR"

            # Criar e configurar diretório cache do kitty
            info "Configurando permissões do cache do kitty..."
            mkdir -p "$USER_HOME/.cache/kitty"
            chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.cache"
            success "Permissões do cache do kitty configuradas."

            # Aplicar configuração de aceleração se solicitado
            if [ "$DISABLE_MOUSE_ACCEL" = "true" ]; then
                info "Aplicando configuração para desabilitar aceleração de mouse/touchpad..."
                apply_mouse_acceleration_config "$USER_HOME/.config/sway/config"
            fi

            info "Copiando arquivo .profile para a home do usuário..."
            if [ -f "$LOCAL_CONFIG_DIR/.profile" ]; then
                cp "$LOCAL_CONFIG_DIR/.profile" "$USER_HOME/"
                chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.profile"
                success "Arquivo .profile copiado."
            fi

            info "Copiando script de sessão do Sway..."
            if [ -f "$LOCAL_CONFIG_DIR/.sway-session" ]; then
                cp "$LOCAL_CONFIG_DIR/.sway-session" "$USER_HOME/"
                chmod +x "$USER_HOME/.sway-session"
                chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.sway-session"
                success "Script .sway-session copiado e configurado."
            fi

            info "Copiando arquivo .bashrc..."
            if [ -f "$LOCAL_CONFIG_DIR/.bashrc" ]; then
                cp "$LOCAL_CONFIG_DIR/.bashrc" "$USER_HOME/"
                chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.bashrc"
                success "Arquivo .bashrc copiado."
            fi

            # Setup standard home directories
            info "Creating standard home directories..."
            if [ -f "$SCRIPT_DIR/../scripts/setup-home-directories.sh" ]; then
                su - "$SUDO_USER" -c "bash $SCRIPT_DIR/../scripts/setup-home-directories.sh"
                success "Home directories created."
            else
                warning "Home directories setup script not found."
            fi

        else
            warning "Local configuration directory not found. Skipping Sway configuration."
        fi

        # --- Configuração do Doas para Sway ---
        info "Iniciando a substituição do 'sudo' pelo 'doas' para o ambiente Sway..."
        kill $SUDO_KEEPALIVE_PID
        trap - EXIT

        info "Criando o arquivo de configuração para 'doas'..."
        DOAS_CONF_CONTENT="permit persist :$SUDO_USER as root"

        if [ "$CONFIG_TYPE" == "notebook" ]; then
            info "Adicionando regra do ddcutil sem senha para o perfil notebook."
            DOAS_CONF_CONTENT+="\npermit nopass :$SUDO_USER cmd ddcutil"
        fi

        echo -e "$DOAS_CONF_CONTENT" > /etc/doas.conf
        chown root:root /etc/doas.conf
        chmod 0400 /etc/doas.conf
        success "Configuração do 'doas' para '$SUDO_USER' concluída."

        if dpkg -l | grep -q " sudo "; then
            run_with_progress "DEBIAN_FRONTEND=noninteractive SUDO_FORCE_REMOVE=yes apt-get purge -qq -y sudo" "Removendo sudo"
        fi
        run_with_progress "ln -s /usr/bin/doas /usr/bin/sudo" "Criando link simbólico sudo->doas"

        # --- Configurações de Screenshot e Gerenciador de Arquivos ---
        info "Criando diretório de screenshots e configurando atalhos..."
        mkdir -p "$USER_HOME/screenshots"
        chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/screenshots"

        info "Configurando permissões do ranger..."
        mkdir -p "$USER_HOME/.local/share/ranger"
        mkdir -p "$USER_HOME/.config/ranger"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local/share/ranger"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/ranger"
        success "Permissões do ranger configuradas."

        info "Configurando permissões e diretórios do Neovim..."
        mkdir -p "$USER_HOME/.local/share/nvim"
        mkdir -p "$USER_HOME/.local/state/nvim"
        mkdir -p "$USER_HOME/.cache/nvim"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local/share/nvim"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local/state/nvim"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.cache/nvim"
        success "Permissões do Neovim configuradas."

        info "Instalando LazyVim conforme documentação oficial..."
        # Backup existing neovim files if they exist
        run_as_user "$SUDO_USER" bash -c "
            if [ -d '$USER_HOME/.config/nvim' ]; then
                mv '$USER_HOME/.config/nvim' '$USER_HOME/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)'
            fi
            if [ -d '$USER_HOME/.local/share/nvim' ]; then
                mv '$USER_HOME/.local/share/nvim' '$USER_HOME/.local/share/nvim.bak.$(date +%Y%m%d_%H%M%S)'
            fi
            if [ -d '$USER_HOME/.local/state/nvim' ]; then
                mv '$USER_HOME/.local/state/nvim' '$USER_HOME/.local/state/nvim.bak.$(date +%Y%m%d_%H%M%S)'
            fi
            if [ -d '$USER_HOME/.cache/nvim' ]; then
                mv '$USER_HOME/.cache/nvim' '$USER_HOME/.cache/nvim.bak.$(date +%Y%m%d_%H%M%S)'
            fi
        "

        # Clone LazyVim starter following official documentation
        run_as_user "$SUDO_USER" bash -c "
            git clone https://github.com/LazyVim/starter '$USER_HOME/.config/nvim'
            rm -rf '$USER_HOME/.config/nvim/.git'
        "

        # Set proper ownership
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/nvim"

        # Adicionar alguns plugins úteis extras
        run_as_user "$SUDO_USER" bash -c "
            mkdir -p '$USER_HOME/.config/nvim/lua/plugins'
            cat > '$USER_HOME/.config/nvim/lua/plugins/extras.lua' << 'LUA_END'
return {
  -- Git integration
  {
    \"tpope/vim-fugitive\",
    cmd = { \"Git\", \"Gstatus\", \"Gblame\", \"Gpush\", \"Gpull\" },
  },

  -- Better syntax highlighting
  {
    \"nvim-treesitter/nvim-treesitter-textobjects\",
    dependencies = \"nvim-treesitter/nvim-treesitter\",
  },

  -- File explorer improvements
  {
    \"stevearc/oil.nvim\",
    config = function()
      require(\"oil\").setup()
    end,
  },

  -- Terminal integration
  {
    \"akinsho/toggleterm.nvim\",
    config = function()
      require(\"toggleterm\").setup()
    end,
  },
}
LUA_END
        "

        success "LazyVim instalado com plugins extras seguindo a documentação oficial."

        configure_default_file_manager

        # Systemd services and timers are now handled by apply_critical_sway_configurations
        info "Systemd timers configured by critical configuration function."

        # System updater and scripts are now handled by apply_critical_sway_configurations
        info "System updater configured by critical configuration function."
    fi

    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "firefox-esr" ]] || \
       [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-browser" ]] || \
       [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]] || \
       [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "tor" ]]; then

        info "Criando script de customização para navegadores..."

        cat > "$USER_HOME/browser_themes.sh" <<'BROWSER_SCRIPT_EOF'
#!/bin/bash
#==============================================================================
# Script de Customização de Navegadores - Remove botões da barra de título
#==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}Script de Customização dos Navegadores Firefox${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""
echo -e "${YELLOW}Este script aplicará customização CSS para remover os botões X, minimizar${NC}"
echo -e "${YELLOW}e maximizar da barra de título dos navegadores baseados em Firefox.${NC}"
echo ""
echo -e "${RED}IMPORTANTE: Antes de executar este script, você DEVE:${NC}"
echo ""
echo -e "  1. ${GREEN}Abrir CADA navegador instalado pelo menos uma vez${NC}"
echo -e "     (para criar o perfil)"
echo ""
echo -e "  2. ${GREEN}Em cada navegador, abrir 'about:config'${NC}"
echo ""
echo -e "  3. ${GREEN}Buscar por:${NC} toolkit.legacyUserProfileCustomizations.stylesheets"
echo ""
echo -e "  4. ${GREEN}Mudar o valor para 'true'${NC} (clique no botão de toggle)"
echo ""
echo -e "  5. ${GREEN}Reiniciar o navegador${NC}"
echo ""
echo -e "${BLUE}====================================================================${NC}"
echo ""
read -p "Você já fez todos os passos acima? (s/N): " response

if [[ ! "$response" =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${YELLOW}Operação cancelada.${NC}"
    echo -e "Execute este script novamente quando estiver pronto."
    echo -e "Script localizado em: ${GREEN}~/browser_themes.sh${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}Iniciando aplicação das customizações...${NC}"
echo ""

# Contador de sucessos e falhas
SUCCESS_COUNT=0
FAIL_COUNT=0
BROWSERS_FOUND=()
BROWSERS_NOT_FOUND=()

#==============================================================================
# Função para aplicar o CSS
#==============================================================================
apply_css() {
    local profile_dir="$1"
    local browser_name="$2"

    if [ -z "$profile_dir" ] || [ ! -d "$profile_dir" ]; then
        echo -e "${RED}✗${NC} ${browser_name}: Perfil não encontrado"
        echo -e "  ${YELLOW}→${NC} Caminho esperado: $profile_dir"
        echo -e "  ${YELLOW}→${NC} Certifique-se de abrir o navegador ao menos uma vez"
        BROWSERS_NOT_FOUND+=("$browser_name")
        ((FAIL_COUNT++))
        return 1
    fi

    echo -e "${GREEN}✓${NC} ${browser_name}: Perfil encontrado!"
    echo -e "  ${BLUE}→${NC} Localização: $profile_dir"

    local chrome_dir="$profile_dir/chrome"
    mkdir -p "$chrome_dir"

    cat > "$chrome_dir/userChrome.css" <<'CSS_EOF'
/* Remove title bar buttons (close, minimize, maximize) */
.titlebar-buttonbox-container { display: none !important; }

/* Remove spacing after tabs */
.titlebar-spacer[type="post-tabs"] { display: none !important; }

/* Additional cleanup */
#TabsToolbar .titlebar-spacer { display: none !important; }
CSS_EOF

    if [ -f "$chrome_dir/userChrome.css" ]; then
        echo -e "${GREEN}✓${NC} ${browser_name}: userChrome.css criado com sucesso!"
        echo -e "  ${BLUE}→${NC} Arquivo: $chrome_dir/userChrome.css"
        BROWSERS_FOUND+=("$browser_name")
        ((SUCCESS_COUNT++))
        return 0
    else
        echo -e "${RED}✗${NC} ${browser_name}: Falha ao criar userChrome.css"
        BROWSERS_NOT_FOUND+=("$browser_name")
        ((FAIL_COUNT++))
        return 1
    fi
}

#==============================================================================
# Detectar e aplicar para cada navegador
#==============================================================================

BROWSER_SCRIPT_EOF

        # Add browser-specific code based on what was selected
        if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "firefox-esr" ]]; then
            cat >> "$USER_HOME/browser_themes.sh" <<'FIREFOX_EOF'
# Firefox ESR
echo -e "\n${BLUE}[1/X] Procurando Firefox ESR...${NC}"
FIREFOX_PROFILE=$(find "$HOME/.mozilla/firefox/" -maxdepth 1 -type d -name "*.default-esr" 2>/dev/null | head -n 1)
apply_css "$FIREFOX_PROFILE" "Firefox ESR"

FIREFOX_EOF
        fi

        if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-browser" ]]; then
            cat >> "$USER_HOME/browser_themes.sh" <<'MULLVAD_EOF'
# Mullvad Browser
echo -e "\n${BLUE}[2/X] Procurando Mullvad Browser...${NC}"
MULLVAD_PROFILE=$(find "$HOME/.mullvad-browser/" -type d -name "*.default" 2>/dev/null | head -n 1)
apply_css "$MULLVAD_PROFILE" "Mullvad Browser"

MULLVAD_EOF
        fi

        if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]]; then
            cat >> "$USER_HOME/browser_themes.sh" <<'LIBREWOLF_EOF'
# LibreWolf
echo -e "\n${BLUE}[3/X] Procurando LibreWolf...${NC}"
LIBREWOLF_PROFILE=$(find "$HOME/.librewolf/" -maxdepth 1 -type d -name "*.default-default" 2>/dev/null | head -n 1)
apply_css "$LIBREWOLF_PROFILE" "LibreWolf"

LIBREWOLF_EOF
        fi

        if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "tor" ]]; then
            cat >> "$USER_HOME/browser_themes.sh" <<'TOR_EOF'
# Tor Browser
echo -e "\n${BLUE}[4/X] Procurando Tor Browser...${NC}"
TOR_PROFILE="$HOME/.local/share/torbrowser/tbb/x86_64/tor-browser/Browser/TorBrowser/Data/Browser/profile.default"
apply_css "$TOR_PROFILE" "Tor Browser"

TOR_EOF
        fi

        # Add the final summary section
        cat >> "$USER_HOME/browser_themes.sh" <<'BROWSER_FOOTER_EOF'

#==============================================================================
# Resumo Final
#==============================================================================
echo ""
echo -e "${BLUE}====================================================================${NC}"
echo -e "${BLUE}RESUMO DA OPERAÇÃO${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""
echo -e "Navegadores customizados com sucesso: ${GREEN}${SUCCESS_COUNT}${NC}"
echo -e "Navegadores não encontrados: ${RED}${FAIL_COUNT}${NC}"
echo ""

if [ ${#BROWSERS_FOUND[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Customizados:${NC}"
    for browser in "${BROWSERS_FOUND[@]}"; do
        echo -e "  • $browser"
    done
    echo ""
fi

if [ ${#BROWSERS_NOT_FOUND[@]} -gt 0 ]; then
    echo -e "${RED}✗ Não encontrados:${NC}"
    for browser in "${BROWSERS_NOT_FOUND[@]}"; do
        echo -e "  • $browser"
    done
    echo ""
fi

echo -e "${BLUE}====================================================================${NC}"
echo -e "${YELLOW}PRÓXIMOS PASSOS:${NC}"
echo -e "${BLUE}====================================================================${NC}"
echo ""

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "1. ${GREEN}Feche TODOS os navegadores completamente${NC}"
    echo ""
    echo -e "2. ${GREEN}Abra os navegadores novamente${NC}"
    echo ""
    echo -e "3. ${GREEN}Os botões X, minimizar e maximizar devem ter sumido!${NC}"
    echo ""
    echo -e "${YELLOW}Nota:${NC} Se os botões ainda aparecerem, verifique se você"
    echo -e "      ativou 'toolkit.legacyUserProfileCustomizations.stylesheets'"
    echo -e "      em about:config de cada navegador."
fi

if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Para os navegadores não encontrados:${NC}"
    echo ""
    echo -e "1. Abra o navegador ao menos uma vez"
    echo -e "2. Configure about:config conforme instruções acima"
    echo -e "3. Execute este script novamente: ${GREEN}~/browser_themes.sh${NC}"
fi

echo ""
echo -e "${BLUE}====================================================================${NC}"
echo ""

# Perguntar se quer deletar o script
read -p "Deseja deletar este script agora? (s/N): " delete_response

if [[ "$delete_response" =~ ^[Ss]$ ]]; then
    echo ""
    echo -e "${GREEN}Script será deletado.${NC}"
    rm -- "$0"
    echo -e "${GREEN}Script deletado com sucesso!${NC}"
else
    echo ""
    echo -e "${YELLOW}Script mantido em:${NC} ${GREEN}~/browser_themes.sh${NC}"
    echo -e "Você pode executá-lo novamente a qualquer momento."
fi

echo ""
echo -e "${GREEN}Operação finalizada!${NC}"
echo ""
BROWSER_FOOTER_EOF

        chmod +x "$USER_HOME/browser_themes.sh"
        chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/browser_themes.sh"

        success "Script de customização criado: ~/browser_themes.sh"
        warning "Execute o script após abrir os navegadores e configurar about:config"
        warning "Comando: ~/browser_themes.sh"
    fi

    # Arkenfox user.js for Firefox ESR
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "firefox-esr" ]]; then
        info "Criando script para aplicar arkenfox user.js no Firefox..."

        cat <<'ARKENFOX_SCRIPT' > "$USER_HOME/apply_arkenfox.sh"
#!/bin/bash
#==============================================================================
# Arkenfox user.js Installer for Firefox ESR
#==============================================================================

echo "=================================================="
echo "Arkenfox user.js Installer"
echo "=================================================="
echo ""
echo "Este script irá baixar e aplicar o arkenfox user.js"
echo "no seu perfil do Firefox ESR."
echo ""
echo "IMPORTANTE: Execute este script APÓS abrir o Firefox"
echo "pela primeira vez para criar o perfil."
echo ""

# Verificar navegadores instalados
echo "Verificando navegadores instalados..."
echo ""

BROWSERS_FOUND=()
BROWSERS_NOT_FOUND=()

# Lista de navegadores para verificar
declare -A BROWSER_PATHS=(
    ["Firefox ESR"]="/usr/bin/firefox-esr"
    ["Chromium"]="/usr/bin/chromium"
    ["Brave Browser"]="/usr/bin/brave-browser"
    ["Helium"]="$HOME/.local/bin/helium"
)

for browser in "${!BROWSER_PATHS[@]}"; do
    if [ -f "${BROWSER_PATHS[$browser]}" ]; then
        BROWSERS_FOUND+=("$browser")
        echo "✓ $browser: Instalado"
    else
        BROWSERS_NOT_FOUND+=("$browser")
        echo "✗ $browser: Não encontrado"
    fi
done

echo ""

if [ ${#BROWSERS_NOT_FOUND[@]} -gt 0 ]; then
    echo "⚠️  AVISO: Alguns navegadores não foram encontrados."
    echo "Instale-os primeiro se desejar usar todos os recursos de privacidade."
    echo ""
    read -p "Deseja continuar mesmo assim? (s/N): " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Ss]$ ]]; then
        echo "Script cancelado pelo usuário."
        exit 0
    fi
    echo ""
fi

# Encontrar o perfil do Firefox
PROFILE=$(find "$HOME/.mozilla/firefox/" -maxdepth 1 -type d -name "*.default-esr" 2>/dev/null | head -n 1)

if [ -z "$PROFILE" ]; then
    echo "❌ ERRO: Perfil do Firefox ESR não encontrado!"
    echo ""
    echo "Por favor:"
    echo "1. Abra o Firefox ESR uma vez para criar o perfil"
    echo "2. Execute este script novamente"
    echo ""
    exit 1
fi

echo "✓ Perfil do Firefox encontrado: $PROFILE"
echo ""

# Baixar arkenfox user.js
if run_with_progress "curl -sL 'https://raw.githubusercontent.com/arkenfox/user.js/master/user.js' -o '$PROFILE/user.js'" "Baixando arkenfox user.js"; then
    echo "✓ Arkenfox user.js baixado com sucesso!"

    # Criar user-overrides.js com configurações específicas
    echo "Criando user-overrides.js com configurações personalizadas..."
    cat > "$PROFILE/user-overrides.js" << 'EOF'
// User overrides for arkenfox user.js
// https://github.com/arkenfox/user.js/wiki/3.1-Overrides

// Enable letterboxing (desabilitado por padrão no arkenfox)
user_pref("privacy.resistFingerprinting.letterboxing", true);

// Relaxar algumas configurações que podem quebrar sites comuns
user_pref("webgl.disabled", false); // Habilita WebGL (necessário para muitos sites)
user_pref("dom.event.clipboardevents.enabled", true); // Permite clipboard events

// Permitir alguns recursos de conveniência
user_pref("geo.enabled", false); // Mantém geolocalização desabilitada por privacidade
user_pref("dom.battery.enabled", false); // Mantém battery API desabilitada

// Configurar search engine padrão
user_pref("browser.search.defaultenginename", "DuckDuckGo");
user_pref("browser.urlbar.placeholderName", "DuckDuckGo");
EOF

    echo "✓ User-overrides.js criado com configurações otimizadas!"

    # Instalar extensões de segurança automaticamente
    echo "Configurando instalação automática de extensões de segurança..."

    # Criar diretório de extensões se não existir
    EXTENSIONS_DIR="$PROFILE/extensions"
    mkdir -p "$EXTENSIONS_DIR"

    # Configurar auto-instalação de extensões
    cat >> "$PROFILE/user-overrides.js" << 'EXTENSIONS_EOF'

// Auto-install extensions
user_pref("extensions.autoDisableScopes", 0);
user_pref("extensions.enabledScopes", 15);
user_pref("xpinstall.signatures.required", false);
EXTENSIONS_EOF

    # Contador para sucessos
    EXTENSIONS_INSTALLED=0

    # Baixar uBlock Origin
    echo "Baixando uBlock Origin..."
    UBLOCK_XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/addon-5252-latest.xpi"
    UBLOCK_ID="uBlock0@raymondhill.net"

    if run_with_progress "curl -sL '$UBLOCK_XPI_URL' -o '$EXTENSIONS_DIR/$UBLOCK_ID.xpi'" "Baixando uBlock Origin"; then
        echo "✓ uBlock Origin baixado com sucesso!"
        EXTENSIONS_INSTALLED=$((EXTENSIONS_INSTALLED + 1))
    else
        echo "⚠ Aviso: Não foi possível baixar o uBlock Origin."
    fi

    # Baixar NoScript
    echo "Baixando NoScript..."
    NOSCRIPT_XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/noscript/addon-722-latest.xpi"
    NOSCRIPT_ID="{73a6fe31-595d-460b-a920-fcc0f8843232}"

    if run_with_progress "curl -sL '$NOSCRIPT_XPI_URL' -o '$EXTENSIONS_DIR/$NOSCRIPT_ID.xpi'" "Baixando NoScript"; then
        echo "✓ NoScript baixado com sucesso!"
        EXTENSIONS_INSTALLED=$((EXTENSIONS_INSTALLED + 1))
    else
        echo "⚠ Aviso: Não foi possível baixar o NoScript."
    fi

    if [ $EXTENSIONS_INSTALLED -gt 0 ]; then
        echo "✓ $EXTENSIONS_INSTALLED extensão(ões) configurada(s) para instalação automática!"
    else
        echo "⚠ Nenhuma extensão pôde ser baixada. Instale manualmente em about:addons"
    fi

    echo ""
    echo "=================================================="
    echo "PRÓXIMOS PASSOS:"
    echo "=================================================="
    echo ""
    echo "1. Feche o Firefox completamente"
    echo "2. Abra novamente o Firefox"
    echo "3. As configurações do arkenfox + overrides serão aplicadas"
    echo "4. Letterboxing estará habilitado para máxima privacidade"
    echo "5. uBlock Origin e NoScript serão instalados automaticamente"
    echo ""
    echo "CONFIGURAÇÃO MANUAL NECESSÁRIA:"
    echo "=================================================="
    echo ""
    echo "Para habilitar temas CSS customizados no Firefox:"
    echo "1. Digite 'about:config' na barra de endereços"
    echo "2. Aceite o aviso de risco"
    echo "3. Procure por: toolkit.legacyUserProfileCustomizations.stylesheets"
    echo "4. Defina o valor como 'true' (duplo clique)"
    echo "5. Reinicie o Firefox"
    echo ""
    echo "NOTA: Se alguns sites quebrarem, você pode editar:"
    echo "      $PROFILE/user-overrides.js"
    echo ""
    echo "Este script se autodestruirá agora."
    rm -- "$0"
else
    echo "❌ ERRO: Falha ao baixar arkenfox user.js"
    echo ""
    echo "Verifique sua conexão com a internet e tente novamente."
    exit 1
fi
ARKENFOX_SCRIPT

        chmod +x "$USER_HOME/apply_arkenfox.sh"
        chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/apply_arkenfox.sh"

        warning "Script criado: ~/apply_arkenfox.sh"
        warning "Execute após abrir o Firefox pela primeira vez para aplicar as configurações de privacidade do arkenfox."
    fi

    # Script para remover botões X do Thunderbird e navegadores
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "thunderbird" ]] || [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "chromium" ]] || [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "brave-browser" ]]; then
        info "Criando script para remover botões de janela..."

        cat <<'REMOVE_BUTTONS_SCRIPT' > "$USER_HOME/remove_window_buttons.sh"
#!/bin/bash
#==============================================================================
# Script para Remover Botões de Janela (X, Minimizar, Maximizar)
#==============================================================================

echo "=================================================="
echo "Removedor de Botões de Janela para Sway"
echo "=================================================="
echo ""
echo "Este script remove os botões X, minimizar e maximizar"
echo "de aplicativos para uma experiência mais limpa no Sway."
echo ""

# Verificar aplicativos instalados
APPS_FOUND=()
APPS_NOT_FOUND=()

declare -A APP_PATHS=(
    ["Thunderbird"]="/usr/bin/thunderbird"
    ["Chromium"]="/usr/bin/chromium"
    ["Brave"]="/usr/bin/brave-browser"
)

for app in "${!APP_PATHS[@]}"; do
    if [ -f "${APP_PATHS[$app]}" ]; then
        APPS_FOUND+=("$app")
        echo "✓ $app: Instalado"
    else
        APPS_NOT_FOUND+=("$app")
        echo "✗ $app: Não encontrado"
    fi
done

echo ""

if [ ${#APPS_FOUND[@]} -eq 0 ]; then
    echo "❌ Nenhum aplicativo compatível encontrado."
    echo "Instale Thunderbird, Chromium ou Brave primeiro."
    exit 1
fi

# Thunderbird - userChrome.css
if [[ " ${APPS_FOUND[*]} " =~ "Thunderbird" ]]; then
    echo "Configurando Thunderbird..."

    # Encontrar perfil do Thunderbird
    THUNDERBIRD_PROFILE=$(find "$HOME/.thunderbird/" -maxdepth 1 -type d -name "*.default-release" 2>/dev/null | head -n 1)

    if [ -z "$THUNDERBIRD_PROFILE" ]; then
        echo "⚠️  Perfil do Thunderbird não encontrado. Abra o Thunderbird uma vez primeiro."
    else
        mkdir -p "$THUNDERBIRD_PROFILE/chrome"
        cat > "$THUNDERBIRD_PROFILE/chrome/userChrome.css" << 'CSS_END'
/* Remove window control buttons */
.titlebar-buttonbox-container {
    display: none !important;
}

/* Hide titlebar completely for even cleaner look */
.titlebar-spacer[type="pre-tabs"] {
    display: none !important;
}

.titlebar-spacer[type="post-tabs"] {
    display: none !important;
}
CSS_END
        echo "✓ Thunderbird configurado"
    fi
fi

# Navegadores Chromium
for browser in "Chromium" "Brave"; do
    if [[ " ${APPS_FOUND[*]} " =~ "$browser" ]]; then
        echo "Configurando $browser..."

        # Determinar diretório de configuração
        case "$browser" in
            "Chromium")
                CONFIG_DIR="$HOME/.config/chromium"
                ;;
            "Brave")
                CONFIG_DIR="$HOME/.config/BraveSoftware/Brave-Browser"
                ;;
        esac

        # Criar configuração CSS personalizada
        PROFILE_DIR="$CONFIG_DIR/Default"
        if [ ! -d "$PROFILE_DIR" ]; then
            echo "⚠️  Perfil do $browser não encontrado. Abra o $browser uma vez primeiro."
            continue
        fi

        # Criar extensão personalizada para remover botões
        EXTENSION_DIR="$PROFILE_DIR/Extensions/window-controls-remover"
        mkdir -p "$EXTENSION_DIR"

        cat > "$EXTENSION_DIR/manifest.json" << 'MANIFEST_END'
{
    "manifest_version": 3,
    "name": "Remove Window Controls",
    "version": "1.0",
    "description": "Remove window control buttons for Sway WM",
    "content_scripts": [
        {
            "matches": ["<all_urls>"],
            "css": ["remove-controls.css"],
            "run_at": "document_start"
        }
    ]
}
MANIFEST_END

        cat > "$EXTENSION_DIR/remove-controls.css" << 'CSS_END'
/* Hide window controls in Chromium-based browsers */
.titlebar,
.browser-header-top,
.-webkit-app-region\:drag {
    -webkit-app-region: no-drag !important;
}

/* Alternative selectors for different Chromium versions */
[role="toolbar"]:has([aria-label*="Minimize"]),
[role="toolbar"]:has([aria-label*="Maximize"]),
[role="toolbar"]:has([aria-label*="Close"]) {
    display: none !important;
}
CSS_END

        echo "✓ $browser configurado"
    fi
done

echo ""
echo "=================================================="
echo "CONFIGURAÇÃO CONCLUÍDA"
echo "=================================================="
echo ""

if [[ " ${APPS_FOUND[*]} " =~ "Thunderbird" ]]; then
    echo "📧 THUNDERBIRD:"
    echo "1. Feche o Thunderbird completamente"
    echo "2. Abra novamente o Thunderbird"
    echo "3. Os botões de janela devem ter sumido"
    echo ""
fi

if [[ " ${APPS_FOUND[*]} " =~ "Chromium" ]] || [[ " ${APPS_FOUND[*]} " =~ "Brave" ]]; then
    echo "🌐 NAVEGADORES:"
    echo "1. Feche todos os navegadores completamente"
    echo "2. Abra os navegadores novamente"
    echo "3. Se necessário, habilite o modo de desenvolvedor em chrome://extensions/"
    echo "4. Carregue a extensão sem pacote do diretório ~/.config/[browser]/Default/Extensions/window-controls-remover"
    echo ""
fi

echo "🎉 Agora você tem uma interface mais limpa no Sway!"
echo ""

# Perguntar se quer deletar o script
read -p "Deseja deletar este script agora? (s/N): " delete_response

if [[ "$delete_response" =~ ^[Ss]$ ]]; then
    echo ""
    echo "Script será deletado."
    rm -- "$0"
else
    echo ""
    echo "Script mantido em: $0"
fi
REMOVE_BUTTONS_SCRIPT

        chmod +x "$USER_HOME/remove_window_buttons.sh"
        chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/remove_window_buttons.sh"

        warning "Script criado: ~/remove_window_buttons.sh"
        warning "Execute após abrir os aplicativos pela primeira vez para remover os botões de janela."
    fi

    if [ "$DESKTOP_ENV" == "GNOME" ]; then
        info "Iniciando a substituição do 'sudo' pelo 'doas'..."
        kill $SUDO_KEEPALIVE_PID
        trap - EXIT
        info "Criando o arquivo de configuração para 'doas'..."; echo "permit persist :$SUDO_USER as root" > /etc/doas.conf; chown root:root /etc/doas.conf; chmod 0400 /etc/doas.conf
        success "Configuração do 'doas' para '$SUDO_USER' concluída."
        if dpkg -l | grep -q " sudo "; then
            run_with_progress "DEBIAN_FRONTEND=noninteractive SUDO_FORCE_REMOVE=yes apt-get purge -qq -y sudo" "Removendo sudo do sistema"
        fi
        info "Criando link simbólico de /usr/bin/doas para /usr/bin/sudo..."; ln -s /usr/bin/doas /usr/bin/sudo; success "Link simbólico criado."
    elif [ "$DESKTOP_ENV" == "KDE" ]; then
        info "Removendo a regra de sudo padrão para o usuário $SUDO_USER..."
        sed -i.bak "/^${SUDO_USER}\s\+ALL=(ALL:ALL)\s\+ALL/d" /etc/sudoers
        success "Regra do usuário removida de /etc/sudoers. Backup salvo em /etc/sudoers.bak."
    fi

    if [ "$CONFIG_TYPE" == "mac" ]; then
        info "Configurando o keyd para o layout do MacBook..."
        mkdir -p /etc/keyd
        cat <<'EOF' > /etc/keyd/default.conf
[ids]
*

[main]
leftalt = layer(control)
EOF
        run_with_progress "systemctl enable keyd" "Habilitando serviço keyd"
        run_with_progress "systemctl restart keyd" "Reiniciando serviço keyd"
        success "Configuração do keyd para MacBook aplicada."

        info "Instalando firmware b43 para Wi-Fi Broadcom (comum em Macs)..."
        if ! dpkg -l | grep -q " firmware-b43-installer "; then
            # Instalar o instalador de firmware b43
            if run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y firmware-b43-installer" "Instalando firmware b43 para Mac"; then
                success "Firmware b43 instalado com sucesso."
                info "Os firmwares necessários para Wi-Fi Broadcom estão agora disponíveis."
                info "Arquivos instalados: b43-open/ucode16_mimo.fw, b43/ucode_mimo.fw"
            else
                warning "Falha ao instalar firmware-b43-installer. Pode ser necessário instalar manualmente."
            fi
        else
            info "Firmware b43 já está instalado."
        fi
    fi

    info "Verificando e instalando JetBrainsMono Nerd Font..."
    local SCRIPT_DIR_FONT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local FONT_SOURCE_DIR="$SCRIPT_DIR_FONT/../fonts/JetBrainsMono"
    local FONT_INSTALL_PARENT_DIR="/usr/local/share/fonts"
    local FONT_INSTALL_DIR="$FONT_INSTALL_PARENT_DIR/JetBrainsMono"

    if [ -d "$FONT_SOURCE_DIR" ]; then
        if [ ! -d "$FONT_INSTALL_DIR" ]; then
            info "Copiando o diretório de fontes JetBrainsMono..."
            run_with_progress "$PRIV_EXEC cp -r '$FONT_SOURCE_DIR' '$FONT_INSTALL_PARENT_DIR/'" "Copiando fontes JetBrainsMono"
            info "Atualizando cache de fontes..."
            run_with_progress "$PRIV_EXEC fc-cache -f" "Atualizando cache de fontes"
            success "JetBrainsMono Nerd Font instalada e cache atualizado."
        else
            info "JetBrainsMono Nerd Font já parece estar instalada em $FONT_INSTALL_DIR."
        fi
    else
        warning "Diretório de fonte fonts/JetBrainsMono não encontrado. Pulando instalação de fonte."
    fi

    info "Copiando temas GTK personalizados..."
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    LOCAL_THEMES_DIR="$SCRIPT_DIR/../gtk-themes"
    if [ -d "$LOCAL_THEMES_DIR" ]; then
        run_with_progress "$PRIV_EXEC cp -r '$LOCAL_THEMES_DIR'/* /usr/share/themes/" "Copiando temas GTK"
        success "Temas GTK copiados para /usr/share/themes/."
    else
        info "Nenhum diretório de temas GTK local encontrado. Pulando."
    fi

    if [ "$DESKTOP_ENV" == "GNOME" ]; then
        info "Aplicando tema de ícones Papirus para GNOME..."
        $PRIV_EXEC -u "$SUDO_USER" GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme "Papirus"
        success "Tema de ícones Papirus definido."
    elif [ "$DESKTOP_ENV" == "Sway" ]; then
        info "Aplicando tema de ícones Papirus para Sway..."
        # Configurar tema de ícones via gsettings para aplicações GTK
        $PRIV_EXEC -u "$SUDO_USER" GSETTINGS_BACKEND=dconf gsettings set org.gnome.desktop.interface icon-theme "Papirus"

        # Configurar via arquivo de configuração GTK
        mkdir -p "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0"

        # GTK 3
        if [ ! -f "$USER_HOME/.config/gtk-3.0/settings.ini" ] || ! grep -q "gtk-icon-theme-name" "$USER_HOME/.config/gtk-3.0/settings.ini"; then
            cat >> "$USER_HOME/.config/gtk-3.0/settings.ini" << EOF

# Tema de ícones
gtk-icon-theme-name=Papirus
EOF
        fi

        # GTK 4
        if [ ! -f "$USER_HOME/.config/gtk-4.0/settings.ini" ] || ! grep -q "gtk-icon-theme-name" "$USER_HOME/.config/gtk-4.0/settings.ini"; then
            cat >> "$USER_HOME/.config/gtk-4.0/settings.ini" << EOF

# Tema de ícones
gtk-icon-theme-name=Papirus
EOF
        fi

        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/gtk-4.0"
        success "Tema de ícones Papirus configurado para Sway."
    fi

    info "Removendo entradas de menu de aplicativos desnecessários..."
    rm -f /usr/share/applications/btop.desktop \
          /usr/share/applications/nvim.desktop \
          /usr/share/applications/system-config-printer.desktop \
          /usr/share/applications/vim.desktop \
          /usr/share/applications/gammastep.desktop \
          /usr/share/applications/ranger.desktop \
          /usr/share/applications/Alacritty.desktop \
          /usr/share/applications/org.pulseaudio.pavucontrol.desktop \
          /usr/share/applications/kitty.desktop \
          /usr/share/applications/bulk-rename.desktop \
          /usr/share/applications/thunar.desktop \
          /usr/share/applications/thunar-*
    success "Ícones de menu desnecessários removidos."

    # Corrigir problemas GTK do gufw no Wayland/Sway
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "gufw" ]] || dpkg -l | grep -q gufw; then
        info "Configurando gufw para funcionar corretamente no Sway..."

        # Configurar PolicyKit para permitir gufw sem senha (mais seguro que wrapper)
        cat > /etc/polkit-1/localauthority/50-local.d/50-gufw.pkla << 'EOF'
[Allow gufw for admin users]
Identity=unix-group:sudo;unix-group:wheel;unix-group:admin
Action=com.ubuntu.pkexec.gufw
ResultActive=auth_admin_keep
EOF

        # Instalar wrapper script para Wayland
        cat > /usr/local/bin/gufw-wayland << 'EOF'
#!/bin/bash
export GDK_BACKEND=wayland
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=sway
pkexec env DISPLAY=$WAYLAND_DISPLAY WAYLAND_DISPLAY=$WAYLAND_DISPLAY GDK_BACKEND=wayland /usr/bin/gufw "$@"
EOF
        chmod +x /usr/local/bin/gufw-wayland

        # Corrigir o arquivo .desktop original do gufw para usar o wrapper
        if [ -f /usr/share/applications/gufw.desktop ]; then
            # Fazer backup do original
            run_with_progress "cp /usr/share/applications/gufw.desktop /usr/share/applications/gufw.desktop.bak" "Backup do gufw.desktop original"

            # Corrigir o Exec para usar o wrapper Wayland
            run_with_progress "sed -i 's|^Exec=.*|Exec=/usr/local/bin/gufw-wayland|' /usr/share/applications/gufw.desktop" "Configurando wrapper Wayland do gufw"
        fi

        # Remover arquivos de wrapper antigos se existirem
        if [ -f /usr/local/bin/gufw-sway ]; then
            run_with_progress "rm -f /usr/local/bin/gufw-sway" "Removendo wrapper antigo"
        fi
        if [ -f /usr/share/applications/gufw-sway.desktop ]; then
            run_with_progress "rm -f /usr/share/applications/gufw-sway.desktop" "Removendo .desktop duplicado"
        fi

        success "Gufw configurado para funcionar no Sway."

        # Aplicar configuração segura padrão
        info "Aplicando configuração segura do firewall..."

        # Habilitar UFW
        run_with_progress "ufw --force enable" "Habilitando UFW"

        # Configurar perfil office (mais restritivo mas funcional)
        run_with_progress "ufw --force reset" "Resetando regras do firewall"
        run_with_progress "ufw default deny incoming" "Configurando regra padrão entrada"
        run_with_progress "ufw default allow outgoing" "Configurando regra padrão saída"

        # Permitir conexões essenciais
        run_with_progress "ufw allow ssh" "Permitindo SSH"
        run_with_progress "ufw allow out 53" "Permitindo DNS"
        run_with_progress "ufw allow out 80" "Permitindo HTTP"
        run_with_progress "ufw allow out 443" "Permitindo HTTPS"
        run_with_progress "ufw allow out 123" "Permitindo NTP"

        # Reativar o firewall
        run_with_progress "ufw --force enable" "Reativando firewall"

        success "Firewall configurado com perfil de segurança 'office'."
    fi

    # Configurar aparência do Thunar se instalado
    if [[ " ${CHOSEN_FILE_MANAGERS[*]} " =~ "thunar" ]] || dpkg -l | grep -q thunar; then
        info "Configurando aparência do Thunar..."

        # Criar diretório de configuração do Thunar
        mkdir -p "$USER_HOME/.config/Thunar"

        # Configurar Thunar para modo escuro e aparência melhorada
        cat > "$USER_HOME/.config/Thunar/thunarrc" << 'EOF'
[Configuration]
DefaultView=ThunarIconView
LastCompactViewZoomLevel=THUNAR_ZOOM_LEVEL_SMALLER
LastDetailsViewColumnOrder=THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE,THUNAR_COLUMN_DATE_MODIFIED
LastDetailsViewColumnWidths=50,50,50,50
LastDetailsViewFixedColumns=FALSE
LastDetailsViewVisibleColumns=THUNAR_COLUMN_DATE_MODIFIED,THUNAR_COLUMN_NAME,THUNAR_COLUMN_SIZE,THUNAR_COLUMN_TYPE
LastDetailsViewZoomLevel=THUNAR_ZOOM_LEVEL_SMALLER
LastIconViewZoomLevel=THUNAR_ZOOM_LEVEL_NORMAL
LastLocationBar=ThunarLocationEntry
LastSeparatorPosition=170
LastShowHidden=FALSE
LastSidePane=ThunarShortcutsPane
LastSortColumn=THUNAR_COLUMN_NAME
LastSortOrder=GTK_SORT_ASCENDING
LastStatusbarVisible=TRUE
LastView=ThunarIconView
LastWindowHeight=480
LastWindowWidth=640
LastWindowMaximized=FALSE
MiscVolumeManagement=TRUE
MiscCaseSensitive=FALSE
MiscDateStyle=THUNAR_DATE_STYLE_SIMPLE
MiscFoldersFirst=TRUE
MiscHorizontalWheelNavigates=FALSE
MiscRecursivePermissions=THUNAR_RECURSIVE_PERMISSIONS_ASK
MiscRememberGeometry=TRUE
MiscShowAboutTemplates=TRUE
MiscShowThumbnails=TRUE
MiscSingleClick=FALSE
MiscSingleClickTimeout=500
MiscTextBesideIcons=FALSE
ShortcutsIconEmblems=TRUE
ShortcutsIconSize=THUNAR_ICON_SIZE_SMALLER
SidebarWidth=148
TreeIconEmblems=TRUE
TreeIconSize=THUNAR_ICON_SIZE_SMALLEST
EOF

        # Configurar tema escuro para Thunar via GTK
        mkdir -p "$USER_HOME/.config/gtk-3.0"
        if [ ! -f "$USER_HOME/.config/gtk-3.0/settings.ini" ]; then
            cat > "$USER_HOME/.config/gtk-3.0/settings.ini" << EOF
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=Papirus
gtk-font-name=Sans 10
EOF
        else
            # Adicionar configuração de tema escuro se não existir
            if ! grep -q "gtk-application-prefer-dark-theme" "$USER_HOME/.config/gtk-3.0/settings.ini"; then
                echo "gtk-application-prefer-dark-theme=1" >> "$USER_HOME/.config/gtk-3.0/settings.ini"
            fi
        fi

        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/Thunar" "$USER_HOME/.config/gtk-3.0"
        success "Thunar configurado com aparência otimizada."
    fi

    info "Ajustando a configuração de rede para ser gerenciada pelo NetworkManager..."
    if [ -f /etc/network/interfaces ]; then mv /etc/network/interfaces /etc/network/interfaces.bak; fi
    cat <<'EOF' > /etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback
EOF
    success "Arquivo /etc/network/interfaces configurado."

    info "Limpando arquivos de backup de sources.list..."
    rm -f /etc/apt/sources.list~ /etc/apt/sources.list.bak

    if [ "$DESKTOP_ENV" == "Sway" ]; then
        info "Iniciando configuração do greetd em 4 etapas..."

        info "(1/4) Instalando o pacote greetd..."
        if ! dpkg -l | grep -q " greetd "; then run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y greetd" "Instalando greetd"; else info "greetd já instalado."; fi

        info "(2/4) Habilitando o serviço greetd..."
        run_with_progress "systemctl enable greetd" "Habilitando serviço greetd"

        info "(3/4) Criando o arquivo de configuração config.toml..."
        mkdir -p /etc/greetd
        cat <<'EOF' > /etc/greetd/config.toml
[terminal]
vt = 7

[default_session]
command = "sway --config /etc/greetd/sway-config"
user = "_greetd"
EOF

        info "(4/4) Instalando o wlgreet..."
        if ! dpkg -l | grep -q " wlgreet "; then run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y wlgreet" "Instalando wlgreet"; else info "wlgreet já instalado."; fi

        info "Criando arquivo de sessão Wayland para o Sway..."
        mkdir -p /usr/share/wayland-sessions
        cat <<'EOF' > /usr/share/wayland-sessions/sway.desktop
[Desktop Entry]
Name=Sway
Comment=Sway Wayland compositor
Exec=/home/$SUDO_USER/.sway-session
Type=Application
EOF
        sed -i "s|\$SUDO_USER|$SUDO_USER|g" /usr/share/wayland-sessions/sway.desktop
        success "Arquivo de sessão criado."

        success "Configuração do greetd concluída."
    fi
}

#==============================================================================
# FUNCTION: verify_and_fix_wallpapers
# DESCRIPTION: Verifies wallpaper installation and fixes if needed
#==============================================================================
verify_and_fix_wallpapers() {
    local REPO_DIR="$1"
    local needs_fix=false

    info "Verifying wallpaper installation..."

    # Check if wallpaper directory exists
    if [ ! -d "$USER_HOME/.config/wallpapers" ]; then
        warning "Wallpaper directory not found"
        needs_fix=true
    elif [ ! -d "$USER_HOME/.config/wallpapers/day" ] || [ ! -d "$USER_HOME/.config/wallpapers/night" ]; then
        warning "Wallpaper subdirectories (day/night) are missing"
        needs_fix=true
    else
        # Check if directories have wallpapers
        local day_count=$(find "$USER_HOME/.config/wallpapers/day" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l)
        local night_count=$(find "$USER_HOME/.config/wallpapers/night" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \) 2>/dev/null | wc -l)

        if [ "$day_count" -eq 0 ] || [ "$night_count" -eq 0 ]; then
            warning "Wallpaper directories are empty (day: $day_count, night: $night_count)"
            needs_fix=true
        else
            success "Wallpapers are correctly installed (day: $day_count, night: $night_count)"
            return 0
        fi
    fi

    if [ "$needs_fix" = true ]; then
        info "Fixing wallpaper installation..."

        if [ -d "$REPO_DIR/assets/wallpapers" ]; then
            rm -rf "$USER_HOME/.config/wallpapers"
            mkdir -p "$USER_HOME/.config/wallpapers"
            if cp -a "$REPO_DIR/assets/wallpapers"/. "$USER_HOME/.config/wallpapers"/; then
                chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/wallpapers"

                # Verify the fix worked
                if [ -d "$USER_HOME/.config/wallpapers/day" ] && [ -d "$USER_HOME/.config/wallpapers/night" ]; then
                    success "Wallpapers fixed successfully!"

                    # Restart wallpaper if sway is running
                    if pgrep -x "sway" >/dev/null; then
                        info "Restarting wallpaper service..."
                        run_as_user "$SUDO_USER" pkill -x swaybg 2>/dev/null || true
                        sleep 1
                        run_as_user "$SUDO_USER" SWAYSOCK=$(find /run/user/$(id -u "$SUDO_USER") -name "sway-ipc.*.sock" 2>/dev/null | head -1) "$USER_HOME/.config/sway/scripts/change-wallpaper.sh" &
                        success "Wallpaper service restarted"
                    fi
                    return 0
                else
                    error "Fix failed: wallpaper directories still missing!"
                    return 1
                fi
            else
                error "Failed to copy wallpapers from repository!"
                return 1
            fi
        else
            error "Wallpaper assets not found in repository at $REPO_DIR/assets/wallpapers"
            return 1
        fi
    fi
}

#==============================================================================
# FUNCTION: force_update_sway_configs
# DESCRIPTION: Destructively updates Sway configs by backing up the old
#              .config directory and copying the new one from the repo.
#==============================================================================
force_update_sway_configs() {
    # Validate SUDO_USER for security before any operations
    validate_sudo_user

    # Skip interactive prompts if in auto-config mode
    if [ "$AUTO_CONFIG_MODE" != "true" ]; then
        CONFIG_TYPE=$(whiptail --title "Configuration Type" --menu "Choose the type of configuration to apply:" 18 65 3 \
            "notebook" "Notebook Configuration" \
            "mac" "Desktop/Mac Configuration" \
            "qemu" "QEMU/KVM Virtual Machine" 3>&1 1>&2 2>&3)

        if [ $? -ne 0 ]; then
            info "Configuration update cancelled."
            return
        fi

        if ! whiptail --title "Confirm Update" --yesno "This action will replace your current configurations in ~/.config with those from the repository ($CONFIG_TYPE).\n\nA backup of your current directory will be created (e.g., ~/.config.bak_...)\n\nDo you want to continue?" 12 80; then
            info "Configuration update cancelled."
            return
        fi
    fi

    if [ "$AUTO_CONFIG_MODE" = "true" ]; then
        info "Auto-config mode: Starting silent configuration update for $CONFIG_TYPE profile..."
    else
        info "Forcing update of Sway configuration files..."
    fi
    
    # Use the same repository as system-updater
    REPO_DIR="$USER_HOME/.local/share/custom-debian-repo"
        
    # Update repository to latest
    if [ -d "$REPO_DIR/.git" ]; then
        info "Updating repository to latest version..."
        cd "$REPO_DIR"
        git pull origin main >/dev/null 2>&1 || warning "Could not update repository"
    fi

    # Verify and fix wallpapers if needed (for existing installations)
    verify_and_fix_wallpapers "$REPO_DIR"

    # Initialize update system if needed
    if [ -f "$USER_HOME/.local/bin/system-updater.sh" ]; then
        info "Initializing update notification system..."
        # Run initial check to populate caches (run as user, in background to not block)
        su - "$SUDO_USER" -c "$USER_HOME/.local/bin/system-updater.sh check >/dev/null 2>&1" & disown
        success "Update system initialized"
    fi

    if [ "$CONFIG_TYPE" == "mac" ]; then
        LOCAL_CONFIG_DIR="$REPO_DIR/config.mac"
    elif [ "$CONFIG_TYPE" == "qemu" ]; then
        LOCAL_CONFIG_DIR="$REPO_DIR/config.qemu"
    else
        LOCAL_CONFIG_DIR="$REPO_DIR/config.notebook"
    fi

    if [ -d "$LOCAL_CONFIG_DIR" ]; then
        if [ -e "$USER_HOME/.config" ]; then
            BACKUP_NAME=".config.bak_$(date +%Y-%m-%d_%H-%M-%S)"
            warning "Criando backup do diretório .config atual para ~/${BACKUP_NAME}"
            mv "$USER_HOME/.config" "$USER_HOME/$BACKUP_NAME"
            success "Backup criado com sucesso."
        fi
        info "Syncing new configuration directory..."
        mkdir -p "$USER_HOME/.config"

        # Sync all config directories from profile
        for config_dir in "$LOCAL_CONFIG_DIR"/*/; do
            if [ -d "$config_dir" ]; then
                dir_name=$(basename "$config_dir")
                rm -rf "$USER_HOME/.config/$dir_name"
                cp -a "$config_dir" "$USER_HOME/.config/$dir_name" 2>/dev/null || true
            fi
        done

        # Sync unified wallpapers
        if [ -d "$REPO_DIR/assets/wallpapers" ]; then
            info "Syncing unified wallpapers..."
            rm -rf "$USER_HOME/.config/wallpapers"
            mkdir -p "$USER_HOME/.config/wallpapers"
            if cp -a "$REPO_DIR/assets/wallpapers"/. "$USER_HOME/.config/wallpapers"/; then
                chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config/wallpapers"
                # Verify wallpapers were copied successfully
                if [ -d "$USER_HOME/.config/wallpapers/day" ] && [ -d "$USER_HOME/.config/wallpapers/night" ]; then
                    success "Wallpapers synced successfully."
                else
                    error "Wallpaper directories are missing after copy!"
                    exit 1
                fi
            else
                error "Failed to copy wallpapers!"
                exit 1
            fi
        else
            warning "Wallpaper assets directory not found at $REPO_DIR/assets/wallpapers"
        fi

        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.config"
        success "Configuration directory synced successfully."

        # Apply ALL critical configurations including systemd timers
        info "Applying critical Sway configurations including systemd timers..."
        apply_critical_sway_configurations "$LOCAL_CONFIG_DIR"

        # Configure kitty cache directory
        info "Configuring kitty cache permissions..."
        mkdir -p "$USER_HOME/.cache/kitty"
        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.cache"
        success "Kitty cache permissions configured."

        # Apply mouse acceleration configuration if requested
        if [ "$DISABLE_MOUSE_ACCEL" = "true" ]; then
            info "Applying configuration to disable mouse/touchpad acceleration..."
            apply_mouse_acceleration_config "$USER_HOME/.config/sway/config"
        fi

        # Restart Sway to apply new configurations
        info "Restarting Sway to apply new configurations..."
        if pgrep -x "sway" >/dev/null; then
            # Check if user is running sway and restart it using environment variables
            if run_as_user "$SUDO_USER" swaymsg reload 2>/dev/null; then
                success "Sway reloaded successfully."
            else
                # Try with explicit display variables as fallback
                run_as_user "$SUDO_USER" DISPLAY=:0 WAYLAND_DISPLAY=wayland-1 swaymsg reload 2>/dev/null || \
                run_as_user "$SUDO_USER" DISPLAY=:0 WAYLAND_DISPLAY=wayland-0 swaymsg reload 2>/dev/null || \
                warning "Could not restart Sway automatically. Please restart your session manually."
            fi
        else
            info "Sway is not currently running. Configuration will be applied on next start."
        fi

        # Update system updater to mark configs as updated
        update_system_updater_commit
        
        # Run manual update sync to ensure system-updater recognizes the change
        if [ -f "$SCRIPT_DIR/../scripts/sync-manual-update.sh" ]; then
            run_as_user "$SUDO_USER" "$SCRIPT_DIR/../scripts/sync-manual-update.sh"
        fi
    else
        error "Diretório de configuração local ($LOCAL_CONFIG_DIR) não foi encontrado no repositório."
    fi
}

#==============================================================================
# FUNCTION: apply_mouse_acceleration_config
# DESCRIPTION: Modifies Sway config to disable mouse/touchpad acceleration
#==============================================================================
apply_mouse_acceleration_config() {
    local sway_config_path="$1"

    if [ ! -f "$sway_config_path" ]; then
        warning "Arquivo de configuração do Sway não encontrado em $sway_config_path"
        return 1
    fi

    # Desabilitar aceleração para touchpad
    if grep -q "input \"type:touchpad\"" "$sway_config_path"; then
        # Adicionar accel_profile flat se não existir
        if ! grep -A 10 "input \"type:touchpad\"" "$sway_config_path" | grep -q "accel_profile"; then
            sed -i '/input "type:touchpad" {/,/}/{
                /}/i\    accel_profile flat
            }' "$sway_config_path"
        else
            # Substituir perfil existente
            sed -i '/input "type:touchpad" {/,/}/{
                s/accel_profile .*/accel_profile flat/
            }' "$sway_config_path"
        fi
    fi

    # Desabilitar aceleração para mouse específico (se existir)
    if grep -q "input \"5426:110:Razer_Razer_DeathAdder_Essential\"" "$sway_config_path"; then
        # Manter accel_profile flat que já está definido
        success "Configuração de mouse Razer já otimizada"
    fi

    # Adicionar configuração global para mouses genéricos
    if ! grep -q "input \"type:pointer\"" "$sway_config_path"; then
        # Encontrar o final da seção de input e adicionar configuração para mouse genérico
        sed -i '/# Key Bindings/i\
input "type:pointer" {\
    accel_profile flat\
}\
' "$sway_config_path"
    fi

    success "Aceleração de mouse/touchpad desabilitada no Sway"
}

#==============================================================================
# FUNCTION: set_sway_file_manager
# DESCRIPTION: Sets the chosen file manager as the default in the Sway config.
#==============================================================================
set_sway_file_manager() {
    local file_manager=$1
    info "Configurando '$file_manager' como o gerenciador de arquivos padrão no Sway..."

    local sway_config_path="$USER_HOME/.config/sway/config"

    if [ ! -f "$sway_config_path" ]; then
        warning "Arquivo de configuração do Sway não encontrado em $sway_config_path. Pulando."
        return
    fi

    local exec_command
    if [ "$file_manager" == "ranger" ]; then
        exec_command="exec kitty ranger"
    else
        exec_command="exec $file_manager"
    fi

    # Use sed to replace the line. -i.bak creates a backup.
    sed -i.bak "s|bindsym \$mod+e .*|bindsym \$mod+e $exec_command|" "$sway_config_path"
    
    if grep -q "$exec_command" "$sway_config_path"; then
        success "Atalho do gerenciador de arquivos (mod+e) atualizado para '$exec_command'."
    else
        error "Falha ao atualizar o atalho do gerenciador de arquivos no Sway."
    fi
}

#==============================================================================
# FUNCTION: configure_default_file_manager
# DESCRIPTION: Asks the user for the default file manager if multiple are
#              installed and configures it.
#==============================================================================
configure_default_file_manager() {
    if [ "$DESKTOP_ENV" != "Sway" ]; then
        return
    fi

    local ranger_selected=$(echo "$CHOSEN_FILE_MANAGERS" | grep -c "ranger")
    local thunar_selected=$(echo "$CHOSEN_FILE_MANAGERS" | grep -c "thunar")
    local default_fm=""

    if [ "$ranger_selected" -gt 0 ] && [ "$thunar_selected" -gt 0 ]; then
        info "Both Ranger and Thunar were selected. Choose the default one."
        default_fm=$(whiptail --title "Default File Manager" --menu "Which should be the default file manager for the shortcut (mod+e)?" 15 80 2 \
            "ranger" "Ranger (terminal-based)" \
            "thunar" "Thunar (graphical)" 3>&1 1>&2 2>&3) || default_fm="ranger"
    elif [ "$ranger_selected" -gt 0 ]; then
        default_fm="ranger"
    elif [ "$thunar_selected" -gt 0 ]; then
        default_fm="thunar"
    else
        info "Nenhum gerenciador de arquivos selecionado para o Sway. Pulando configuração de atalho."
        return
    fi

    set_sway_file_manager "$default_fm"

    # Salvar configuração do usuário
    save_user_preference "DEFAULT_FILE_MANAGER" "$default_fm"
}

#==============================================================================
# FUNCTION: save_user_preference
# DESCRIPTION: Salva uma preferência do usuário para uso posterior
#==============================================================================
save_user_preference() {
    local key="$1"
    local value="$2"

    local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local save_script="$script_dir/../scripts/save-user-config.sh"

    if [ -f "$save_script" ]; then
        run_as_user "$SUDO_USER" "$save_script" save "$key" "$value"
    fi
}

#==============================================================================
# FUNCTION: save_installation_choices
# DESCRIPTION: Salva todas as escolhas feitas durante a instalação
#==============================================================================
save_installation_choices() {
    local script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local save_script="$script_dir/../scripts/save-user-config.sh"

    if [ -f "$save_script" ]; then
        info "Salvando preferências do usuário para atualizações futuras..."

        # Salvar opções principais (essas variáveis devem existir no contexto)
        if [ -n "${CHOSEN_DEB_OPTIONS:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "CHOSEN_DEB_OPTIONS" "${CHOSEN_DEB_OPTIONS[*]}"
        fi

        if [ -n "${CHOSEN_FILE_MANAGERS:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "CHOSEN_FILE_MANAGERS" "${CHOSEN_FILE_MANAGERS[*]}"
        fi

        if [ -n "${FLATPAK_APPS:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "FLATPAK_APPS" "${FLATPAK_APPS[*]}"
        fi

        if [ -n "${MOUSE_ACCELERATION:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "MOUSE_ACCELERATION" "$MOUSE_ACCELERATION"
        fi

        if [ -n "${CONFIG_TYPE:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "CONFIG_TYPE" "$CONFIG_TYPE"
        fi

        if [ -n "${DESKTOP_ENV:-}" ]; then
            run_as_user "$SUDO_USER" "$save_script" save "DESKTOP_ENV" "$DESKTOP_ENV"
        fi

        run_as_user "$SUDO_USER" "$save_script" save "INSTALLATION_DATE" "$(date)"

        success "Preferências do usuário salvas."
    fi
}

#==============================================================================
# FUNCTION: update_system_updater_commit
# DESCRIPTION: Updates the system-updater commit tracking after manual config update
#==============================================================================
update_system_updater_commit() {
    local repo_dir="$USER_HOME/.local/share/custom-debian-repo"
    local commit_file="$USER_HOME/.local/state/system-updater/installed_commit"
    
    # Update repository to get latest commit
    if [ -d "$repo_dir/.git" ]; then
        cd "$repo_dir"
        git fetch origin main >/dev/null 2>&1
        
        # Get current HEAD commit
        local current_commit=$(git rev-parse HEAD 2>/dev/null)
        if [ -n "$current_commit" ]; then
            mkdir -p "$(dirname "$commit_file")"
            echo "$current_commit" > "$commit_file"
            chown "$SUDO_USER":"$SUDO_USER" "$commit_file" 2>/dev/null || true
            info "System updater commit updated to: ${current_commit:0:8}"
        fi
    fi
}
