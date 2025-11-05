#!/bin/bash
#==============================================================================
# UI Library
#
# PURPOSE: Contains all functions related to user interface, including
#          output formatting (info, warning) and user input dialogs (whiptail).
#==============================================================================

# --- Cores e Funções de Saída ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'
BOLD='\033[1m'; DIM='\033[2m'

# Configuração de logs
LOG_DIR="/var/log/debian-installer"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"

# Criar diretório de log
mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d_%H%M%S).log"

info() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
    echo -e "\n${BLUE}${msg}${NC}"
    # Clean log entry without ANSI colors
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

warning() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [WARNING] $*"
    echo -e "${YELLOW}${msg}${NC}"
    # Clean log entry without ANSI colors
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [SUCCESS] $*"
    echo -e "${GREEN}${msg}${NC}"
    # Clean log entry without ANSI colors
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    local msg="[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*"
    echo -e "${RED}${msg}${NC}"
    # Clean log entry without ANSI colors
    echo "$msg" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE" 2>/dev/null || true
}

# Spinner para indicar progresso
show_spinner() {
    local pid=$1
    local msg="$2"
    local delay=0.1
    local spinstr='|/-\'

    echo -ne "${BLUE}${msg}${NC} "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Executa comando com progresso visual e log
run_with_progress() {
    local command="$1"
    local message="$2"
    local log_success="${3:-true}"

    echo -e "\n${BLUE}${BOLD}→${NC} ${message}..."
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executando: $command" >> "$LOG_FILE" 2>/dev/null || true

    # Executa comando em background com logs
    if eval "$command" >> "$LOG_FILE" 2>&1; then
        if [ "$log_success" = "true" ]; then
            echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
        fi
        return 0
    else
        local exit_code=$?
        echo -e "${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
        return $exit_code
    fi
}

# Progress bar personalizada
show_progress_bar() {
    local current=$1
    local total=$2
    local message="${3:-Processando}"
    local width=50

    # Validate inputs are numbers
    if ! [[ "$current" =~ ^[0-9]+$ ]]; then
        current=0
    fi
    if ! [[ "$total" =~ ^[0-9]+$ ]] || [ "$total" -eq 0 ]; then
        total=100
    fi

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

# Executa comando com progress bar avançada
run_with_progress_bar() {
    local command="$1"
    local message="$2"
    local steps="${3:-1}"

    echo -e "\n${BLUE}${BOLD}→${NC} ${message}..."
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executando: $command" >> "$LOG_FILE" 2>/dev/null || true

    # Verbose mode: show all output directly
    if [ "${VERBOSE_MODE:-false}" = true ]; then
        echo -e "${DIM}Running: $command${NC}"
        if eval "$command"; then
            echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
            return 0
        else
            local exit_code=$?
            echo -e "${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
            return $exit_code
        fi
    fi

    # Simular progresso para comandos sem progresso real
    if [ "$steps" -eq 1 ]; then
        show_progress_bar 0 3 "$message"
        sleep 0.2
        show_progress_bar 1 3 "$message"

        # Executa comando
        if eval "$command" >> "$LOG_FILE" 2>&1; then
            show_progress_bar 2 3 "$message"
            sleep 0.1
            show_progress_bar 3 3 "$message"
            echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
            return 0
        else
            local exit_code=$?
            echo -e "\n${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
            return $exit_code
        fi
    else
        # Para comandos com múltiplos passos
        for ((i=0; i<=steps; i++)); do
            show_progress_bar "$i" "$steps" "$message"
            if [ "$i" -eq $((steps/2)) ] && [ "$i" -gt 0 ]; then
                # Executa comando no meio do progresso
                eval "$command" >> "$LOG_FILE" 2>&1 || return $?
            fi
            sleep 0.1
        done
        echo -e "${GREEN}  ✓${NC} ${DIM}Concluído${NC}"
        return 0
    fi
}

# Shows apt progress with real-time updates
apt_with_progress() {
    local action="$1"
    shift
    local packages=("$@")

    if [ "$action" = "update" ]; then
        echo -e "\n${BLUE}${BOLD}→${NC} Updating package lists..."
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executing: apt-get update" >> "$LOG_FILE" 2>/dev/null || true

        # Verbose mode: show all APT output
        if [ "${VERBOSE_MODE:-false}" = true ]; then
            echo -e "${DIM}Running: apt-get update${NC}"
            if apt-get update; then
                echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
                return 0
            else
                echo -e "${RED}  ✗${NC} ${DIM}Failed${NC}"
                return 1
            fi
        fi

        # Real progress simulation for apt update
        show_progress_bar 0 100 "Updating package lists"
        (
            apt-get update -q 2>&1 | while IFS= read -r line; do
                # Clean apt output for log (remove progress bars and colors)
                clean_line=$(echo "$line" | sed -e 's/\r//' -e 's/\x1b\[[0-9;]*m//g' -e '/^$/d' -e '/^[[:space:]]*$/d')
                if [[ -n "$clean_line" && ! "$clean_line" =~ ^[[:space:]]*[0-9]+%[[:space:]]*$ ]]; then
                    echo "  $clean_line" >> "$LOG_FILE" 2>/dev/null || true
                fi
            done
        ) &
        local apt_pid=$!

        # Realistic progress simulation for apt update
        local progress=0
        local cycle=0
        while kill -0 $apt_pid 2>/dev/null; do
            cycle=$((cycle + 1))

            # Realistic apt update progression pattern
            if [ $progress -lt 15 ]; then
                # Start slow (reading package lists)
                progress=$((progress + 1))
                sleep 0.3
            elif [ $progress -lt 60 ]; then
                # Medium speed (downloading packages)
                progress=$((progress + 2))
                sleep 0.15
            elif [ $progress -lt 85 ]; then
                # Slower (processing)
                progress=$((progress + 1))
                sleep 0.25
            elif [ $progress -lt 95 ]; then
                # Very slow final processing
                if [ $((cycle % 3)) -eq 0 ]; then
                    progress=$((progress + 1))
                fi
                sleep 0.4
            fi

            show_progress_bar $progress 100 "Updating package lists"
        done

        wait $apt_pid
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            show_progress_bar 100 100 "Updating package lists"
            echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
            return 0
        else
            echo -e "\n${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
            return $exit_code
        fi

    elif [ "$action" = "install" ]; then
        local count=${#packages[@]}
        echo -e "\n${BLUE}${BOLD}→${NC} Installing $count package(s)..."
        echo -e "${DIM}Packages: ${packages[*]}${NC}"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] Executing: apt-get install ${packages[*]}" >> "$LOG_FILE" 2>/dev/null || true

        # Verbose mode: show all APT output
        if [ "${VERBOSE_MODE:-false}" = true ]; then
            echo -e "${DIM}Running: apt-get install -y ${packages[*]}${NC}"
            if DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
                echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
                return 0
            else
                local exit_code=$?
                echo -e "${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
                return $exit_code
            fi
        fi

        # Real progress tracking based on actual apt output
        show_progress_bar 0 100 "Downloading and installing packages"

        local progress_file=$(mktemp)
        echo "0" > "$progress_file"

        (
            DEBIAN_FRONTEND=noninteractive apt-get install -q -y "${packages[@]}" 2>&1 | while IFS= read -r line; do
                # Clean apt output for log
                clean_line=$(echo "$line" | sed -e 's/\r//' -e 's/\x1b\[[0-9;]*m//g' -e '/^$/d' -e '/^[[:space:]]*$/d')
                if [[ -n "$clean_line" && ! "$clean_line" =~ ^[[:space:]]*[0-9]+%[[:space:]]*$ ]]; then
                    echo "  $clean_line" >> "$LOG_FILE" 2>/dev/null || true
                fi

                # Track real progress based on apt output - simplified
                if [[ "$line" =~ ^Get:[0-9]+ ]] || [[ "$line" =~ ^Fetched ]]; then
                    echo "25" > "$progress_file"
                elif [[ "$line" =~ ^Unpacking ]] || [[ "$line" =~ ^Preparing ]]; then
                    echo "50" > "$progress_file"
                elif [[ "$line" =~ ^Setting\ up ]]; then
                    echo "75" > "$progress_file"
                fi
            done
        ) &
        local apt_pid=$!

        # Monitor progress from file
        while kill -0 $apt_pid 2>/dev/null; do
            local progress=$(cat "$progress_file" 2>/dev/null || echo "0")
            # Ensure progress is a valid number
            if ! [[ "$progress" =~ ^[0-9]+$ ]]; then
                progress=0
            fi
            show_progress_bar $progress 100 "Downloading and installing packages"
            sleep 0.3
        done

        # Cleanup temp files
        rm -f "$progress_file"

        wait $apt_pid
        local exit_code=$?

        if [ $exit_code -eq 0 ]; then
            show_progress_bar 100 100 "Downloading and installing packages"
            echo -e "${GREEN}  ✓${NC} ${DIM}Completed${NC}"
            return 0
        else
            echo -e "\n${RED}  ✗${NC} ${DIM}Failed (code: $exit_code)${NC}"
            return $exit_code
        fi
    fi
}

#==============================================================================
# FUNCTION: get_user_choices
# DESCRIPTION: Displays all whiptail dialogs to gather user preferences.
# EXPORTS: Exports all choice variables (DESKTOP_ENV, IS_MACBOOK, etc.)
#==============================================================================
get_user_choices() {
    info "Starting configuration phase..."
    if ! command -v whiptail &> /dev/null; then
        apt-get update >/dev/null; apt-get install -y whiptail
    fi

    export DESKTOP_ENV=$(whiptail --title "Desktop Environment" --menu "Choose the desktop environment you want to install." 15 80 3 "GNOME" "Minimal GNOME installation (gnome-core)" "KDE" "Minimal KDE Plasma installation (kde-plasma-desktop)" "Sway" "Tiling WM for Wayland (advanced)" 3>&1 1>&2 2>&3) || { info "Installation cancelled."; exit 0; }
    
    if [ "$DESKTOP_ENV" == "Sway" ]; then
        export CONFIG_TYPE=$(whiptail --title "Configuration Type" --menu "Choose the type of machine you are installing on:" 18 65 3 \
            "notebook" "Notebook Configuration" \
            "mac" "Desktop/Mac Configuration" \
            "qemu" "QEMU/KVM Virtual Machine" 3>&1 1>&2 2>&3) || { info "Installation cancelled."; exit 0; }
    fi

    export CHOSEN_DEB_OPTIONS=$(whiptail --title "Optional Packages (Debian)" --checklist "Use SPACE to select packages from Debian repositories." 24 80 16 "${DEB_PKGS_CHECKLIST[@]}" 3>&1 1>&2 2>&3) || { info "Installation cancelled."; exit 0; }

    if [ "$DESKTOP_ENV" == "Sway" ]; then
        while true; do
            export CHOSEN_FILE_MANAGERS=$(whiptail --title "File Manager (Sway)" --checklist "Choose one or more file managers." 15 80 5 "${FILE_MANAGERS_CHECKLIST[@]}" 3>&1 1>&2 2>&3)

            # Validate that at least one file manager was selected
            if [ -z "$CHOSEN_FILE_MANAGERS" ]; then
                whiptail --title "Error" --msgbox "You must select at least one file manager for Sway.\n\nPlease choose Ranger, Thunar, or both." 12 60
                continue
            fi
            break
        done
    fi
    
    export WANT_FLATPAK=false
    if whiptail --title "Flatpak Support" --yesno "Do you want to install Flatpak and configure the Flathub repository?" 10 80; then export WANT_FLATPAK=true; fi
    
    if [ "$WANT_FLATPAK" = true ]; then
        export CHOSEN_FLATPAK_APPS=$(whiptail --title "Optional Applications (Flatpak)" --checklist "Select the Flatpak applications you want to install." 20 95 7 "${FLATPAK_PKGS_CHECKLIST[@]}" 3>&1 1>&2 2>&3) || info "No Flatpak apps selected."
    fi

    export WANT_SNAPSHOTS=false
    if check_btrfs_timeshift_compatibility; then
        if whiptail --title "Security Snapshots (BTRFS)" --yesno "Your system is compatible with Timeshift's BTRFS mode.\n\nDo you want to use this feature to create security snapshots (before and after)?\n\n(HIGHLY RECOMMENDED)" 15 80; then export WANT_SNAPSHOTS=true; fi
    fi

    if [ "$DESKTOP_ENV" == "Sway" ]; then
        export DISABLE_MOUSE_ACCEL=false
        if whiptail --title "Mouse/Touchpad Acceleration" --yesno "Do you want to disable mouse and touchpad acceleration?\n\nThis can improve precision for gaming or precision work.\n\nRecommended for gamers and designers." 15 80; then export DISABLE_MOUSE_ACCEL=true; fi
    fi
}
