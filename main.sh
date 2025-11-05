#!/bin/bash
#===================================================================================
# Script de Pós-Instalação Avançado para Debian 13 Trixie (v17 - Modular)
#
# OBJETIVO: Orquestrador principal para provisionamento de um sistema Debian.
#===================================================================================

# --- Parse Arguments ---
VERBOSE_MODE=false
export VERBOSE_MODE

for arg in "$@"; do
    case $arg in
        --verbose|-v|--debug)
            VERBOSE_MODE=true
            echo "Verbose mode enabled - all logs will be shown"
            ;;
        --help|-h)
echo "Usage: sudo ./main.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v, --debug    Show all logs including APT output"
            echo "  --auto-config             Silent configuration update (auto-detects profile)"
            echo "  --help, -h                Show this help message"
            echo ""
            echo "Alternative for auto-config:"
            echo "  sudo ./auto-config.sh    Simple silent configuration update"
            echo ""
            exit 0
            ;;
        --auto-config)
            # Silent config update mode
            export AUTO_CONFIG_MODE=true
            export RUN_MODE="configs"
            VERBOSE_MODE=true
            echo "Auto-config mode: Detecting profile and updating silently..."
            ;;
    esac
done

# --- Validações Iniciais e Detecção de Usuário ---
if [[ $EUID -ne 0 ]]; then
    echo -e "\n\033[0;31mERRO:\033[0m Este script precisa ser executado como root."
    echo -e "Execute com: \033[1msudo ./main.sh\033[0m ou \033[1mdoas ./main.sh\033[0m"
    exit 1
fi

# Get script directory early
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Verificar e Instalar Dependências Necessárias
echo "Checking required dependencies..."
REQUIRED_DEPS=(whiptail git curl wget)

MISSING_DEPS=()

for dep in "${REQUIRED_DEPS[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        MISSING_DEPS+=("$dep")
    fi
done

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "Installing missing dependencies: ${MISSING_DEPS[*]}"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -qq -y "${MISSING_DEPS[@]}"
fi

# Load libraries after dependencies are installed
source "$SCRIPT_DIR/lib/ui.sh"

# Save original user from whatever privilege escalation method was used
if [ -n "$SUDO_USER" ]; then
    ORIGINAL_SUDO_USER="$SUDO_USER"
elif [ -n "$DOAS_USER" ]; then
    ORIGINAL_SUDO_USER="$DOAS_USER"
else
    ORIGINAL_SUDO_USER=""
fi

#==============================================================================
# FUNCTION: validate_system_requirements
# DESCRIPTION: Validates system requirements before proceeding
#==============================================================================
validate_system_requirements() {
    info "Validando requisitos do sistema..."

    # Check if running on Debian
    if ! grep -q "Debian" /etc/os-release; then
        error "This script is only compatible with Debian. System detected: $(grep -oP '(?<=^ID=).*' /etc/os-release)"
        exit 1
    fi

    # Check Debian version (Trixie/testing)
    local debian_version=$(grep -oP '(?<=VERSION_CODENAME=).*' /etc/os-release)
    if [ "$debian_version" != "trixie" ]; then
        warning "Script optimized for Debian Trixie (testing). Version detected: $debian_version"
        warning "Continuing anyway, but some packages may not be available."
    fi

    # Check architecture
    local arch=$(dpkg --print-architecture)
    if [[ ! "$arch" =~ ^(amd64|arm64)$ ]]; then
        warning "Arquitetura $arch detectada. Script testado principalmente em amd64/arm64."
    fi

    # Check available disk space (minimum 5GB)
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [ "$available_space" -lt 5242880 ]; then  # 5GB in KB
        error "Insufficient disk space. Minimum required: 5GB. Available: $(($available_space / 1024 / 1024))GB"
        exit 1
    fi

    # Check internet connectivity
    if ! ping -c 1 -W 5 codeberg.org &> /dev/null; then
        error "No internet connectivity. Check your connection."
        exit 1
    fi

    success "System requirements validated."
}

STANDARD_USER=""

# Try multiple methods to detect the real user
# 1. Check SUDO_USER (from sudo)
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ] && id "$SUDO_USER" &>/dev/null; then
    STANDARD_USER="$SUDO_USER"
    info "User detected from SUDO_USER: $STANDARD_USER"
# 2. Check DOAS_USER (from doas)
elif [ -n "$DOAS_USER" ] && [ "$DOAS_USER" != "root" ] && id "$DOAS_USER" &>/dev/null; then
    STANDARD_USER="$DOAS_USER"
    info "User detected from DOAS_USER: $STANDARD_USER"
# 3. Check LOGNAME if running as root
elif [ "$EUID" -eq 0 ] && [ -n "$LOGNAME" ] && [ "$LOGNAME" != "root" ] && id "$LOGNAME" &>/dev/null; then
    STANDARD_USER="$LOGNAME"
    info "User detected from LOGNAME: $STANDARD_USER"
# 4. Try to auto-detect from /home if only one user exists
else
    CANDIDATE_USERS=($(ls /home 2>/dev/null | grep -v -E '^(lost\+found)$'))
    if [ "${#CANDIDATE_USERS[@]}" -eq 1 ]; then
        # Validate the user exists
        if id "${CANDIDATE_USERS[0]}" &>/dev/null; then
            STANDARD_USER="${CANDIDATE_USERS[0]}"
            info "Default user automatically detected from /home: $STANDARD_USER"
        fi
    elif [ "${#CANDIDATE_USERS[@]}" -gt 1 ]; then
        info "Multiple users found in /home: ${CANDIDATE_USERS[*]}"
    fi
fi

# Validate detected user has a home directory
if [ -n "$STANDARD_USER" ] && [ ! -d "/home/$STANDARD_USER" ]; then
    warning "Detected user '$STANDARD_USER' does not have a home directory at /home/$STANDARD_USER"
    STANDARD_USER=""
fi

ATTEMPT_COUNT=0
MAX_ATTEMPTS=5

while [ -z "$STANDARD_USER" ] && [ $ATTEMPT_COUNT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT_COUNT=$((ATTEMPT_COUNT + 1))

    if [ $ATTEMPT_COUNT -gt 1 ]; then
        PROMPT_TEXT="Attempt $ATTEMPT_COUNT of $MAX_ATTEMPTS\n\nCould not detect default user.\n\nFor which user is this installation intended?"
    else
        PROMPT_TEXT="Could not detect default user.\n\nFor which user is this installation intended?"
    fi

    INPUT_USER=$(whiptail --title "Username" --inputbox "$PROMPT_TEXT" 12 60 3>&1 1>&2 2>&3)
    if [ $? -ne 0 ]; then info "Installation cancelled."; exit 1; fi

    if [ -n "$INPUT_USER" ] && id "$INPUT_USER" &>/dev/null; then
        STANDARD_USER="$INPUT_USER"
    else
        if [ -z "$INPUT_USER" ]; then
            whiptail --title "Error" --msgbox "Username cannot be empty. Please try again." 8 60
        else
            whiptail --title "Error" --msgbox "User '$INPUT_USER' not found. Please try again." 8 60
        fi
    fi
done

if [ -z "$STANDARD_USER" ]; then
    error "Too many failed attempts. Could not obtain a valid user."
    error "Check if you typed the username correctly."
    exit 1
fi

# --- Variáveis Globais e Setup ---
export SUDO_USER="$STANDARD_USER"
export USER_HOME="/home/$SUDO_USER"
export LOG_FILE="$USER_HOME/install_log_$(date +%Y%m%d_%H%M%S).log"

# --- Source das Bibliotecas ---
source "$SCRIPT_DIR/config.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/lib/packages.sh"
source "$SCRIPT_DIR/lib/configure.sh"
source "$SCRIPT_DIR/lib/hardware.sh"

#==============================================================================
# FUNCTION: detect_profile
# DESCRIPTION: Automatically detects hardware profile (mac/notebook/qemu)
#==============================================================================
detect_profile() {
    if lspci | grep -i apple >/dev/null 2>&1 || sysctl hw.model 2>/dev/null | grep -i mac >/dev/null; then
        echo "mac"
    elif grep -q "QEMU" /proc/cpuinfo 2>/dev/null || grep -q "VMware" /proc/cpuinfo 2>/dev/null; then
        echo "qemu"
    else
        echo "notebook"
    fi
}

# Set CONFIG_TYPE for auto-config mode after libraries are loaded
if [ "$AUTO_CONFIG_MODE" = "true" ]; then
    export CONFIG_TYPE=$(detect_profile)
    echo "Auto-config mode: Updating $CONFIG_TYPE profile silently..."
fi

#==============================================================================
# FUNCTION: select_run_mode
# DESCRIPTION: Detects if a DE is present and asks the user for the run mode.
# EXPORTS: RUN_MODE variable.
#==============================================================================
select_run_mode() {
    # Skip selection if in auto-config mode
    if [ "$AUTO_CONFIG_MODE" = "true" ]; then
        export RUN_MODE="configs"
        return
    fi
    
    export RUN_MODE="full"
    if dpkg -l | grep -q -E "sway|gnome-shell|plasma-desktop"; then
        info "A graphical environment seems to be already installed."
        export RUN_MODE=$(whiptail --title "Execution Mode" --menu "What would you like to do?" 15 80 4 \
            "full" "Complete Execution (Default)" \
            "packages" "Package Management Only" \
            "configs" "Force Config Update (Sway)" \
            "exit" "Exit" 3>&1 1>&2 2>&3) || export RUN_MODE="exit"
    fi
}

# --- Detect and Setup Privilege Escalation Command ---
# Detect which privilege escalation tool is available
PRIV_EXEC=""
if command -v doas &> /dev/null; then
    PRIV_EXEC="doas"
    info "Using doas for privilege escalation"
elif command -v sudo &> /dev/null; then
    PRIV_EXEC="sudo"
    info "Using sudo for privilege escalation"
else
    error "Neither sudo nor doas were found. Cannot continue."
    exit 1
fi
export PRIV_EXEC

# Only setup keepalive for sudo (doas doesn't support -v and -n flags)
if [ -n "$ORIGINAL_SUDO_USER" ] && [ "$ORIGINAL_SUDO_USER" != "root" ]; then
    if [ "$PRIV_EXEC" = "sudo" ]; then
        info "Keeping sudo privileges active..."
        if ! $PRIV_EXEC -v; then error "Incorrect password or not provided."; exit 1; fi
        ( while true; do $PRIV_EXEC -n true; sleep 60; kill -0 "$$" || exit; done ) &
        SUDO_KEEPALIVE_PID=$!
        trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
    fi
fi

# --- Execução Principal ---
main() {
    validate_system_requirements
    select_run_mode

    { 
        case "$RUN_MODE" in
            "full")
                info "Starting complete execution..."
                get_user_choices
                prepare_system

                install_packages
                apply_hardware_optimizations
                finalize_configuration
                ;;
            "packages")
                info "Starting package management mode..."
                get_user_choices
                install_packages
                ;;
            "configs")
                info "Starting Sway configuration update mode..."
                force_update_sway_configs
                ;;
            "exit")
                info "Exiting script."
                exit 0
                ;;
            *)
                error "Invalid execution mode."
                exit 1
                ;;
        esac

        # --- Mensagens Finais ---
        echo -e "\n===================================================================="
        success "Operation completed successfully."

        # Informar sobre ativação dos timers
        echo -e "\n${YELLOW}📋 IMPORTANTE: Para ativar os timers automatizados (theme-switcher, etc.):${NC}"
        echo -e "${GREEN}   ./scripts/enable-user-timers.sh${NC}"
        echo -e "${BLUE}   Execute este comando APÓS fazer login na sessão gráfica.${NC}"

        # Perguntar se deseja salvar o log da instalação
        if whiptail --title "Save Log" --yesno "Would you like to save the complete installation log to the user's home folder?" 10 80; then
            local home_log_file="$USER_HOME/debian-installation-$(date +%Y%m%d_%H%M%S).log"
            cp "$LOG_FILE" "$home_log_file"
            chown "$SUDO_USER":"$SUDO_USER" "$home_log_file"
            success "Installation log saved to: ${GREEN}${home_log_file}${NC}"
        else
            info "Installation log will not be saved to user's home."
        fi

        success "Temporary log available at: ${GREEN}${LOG_FILE}${NC}"
        chown "$SUDO_USER":"$SUDO_USER" "$LOG_FILE"

        if [ "$RUN_MODE" == "full" ]; then
            if [ "$DESKTOP_ENV" == "GNOME" ]; then warning "Remember to manually install GNOME extensions: Blur my Shell, Tray Icons: Reloaded."; fi
            echo ""
            if whiptail --title "Restart" --yesno "Installation completed. Would you like to restart now?" 12 80; then
                info "Restarting system in 3 seconds..."; sleep 3; systemctl reboot
            else
                info "Please restart the system manually later."
            fi
        fi

    } 2>&1 | tee -a "$LOG_FILE"
}

main

exit 0
