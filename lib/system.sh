#!/bin/bash
#==============================================================================
# System Library

#==============================================================================
# FUNCTION: check_btrfs_timeshift_compatibility
#==============================================================================
check_btrfs_timeshift_compatibility() {
    info "Checking system compatibility with Timeshift (BTRFS mode)..."
    local tipo_fs_raiz=$(findmnt -n -o FSTYPE /)
    if [ "$tipo_fs_raiz" != "btrfs" ]; then
        warning "Root filesystem (/) is not BTRFS. BTRFS snapshot feature unavailable."
        return 1
    fi
    local opcoes_montagem=$(findmnt -n -o OPTIONS /)
    local subvolume_raiz=$(echo "$opcoes_montagem" | grep -o 'subvol=[^,]*' | cut -d'=' -f2)
    if [[ -z "$subvolume_raiz" ]]; then
        warning "Root (/) is mounted on top-level subvolume (ID 5)."
        warning "Timeshift BTRFS snapshot feature unavailable. Requires '@' subvolume."
        return 1
    elif [[ "$subvolume_raiz" == "@" ]] || [[ "$subvolume_raiz" == "/@" ]]; then
        success "Timeshift-compatible system (BTRFS mode) detected!"
        return 0
    else
        warning "Root (/) is not mounted on '@' subvolume. Current subvolume: ${subvolume_raiz}"
        warning "Timeshift BTRFS snapshot feature unavailable."
        return 1
    fi
}

#==============================================================================
# FUNCTION: prepare_system
#==============================================================================
prepare_system() {
    clear
    info "All configurations received. Starting system preparation."
    
    export IS_KVM_GUEST=false
    if lscpu | grep -q "Hypervisor vendor:.*KVM"; then 
        info "Detected that the system is running on a KVM VM."
        export IS_KVM_GUEST=true
    fi

    info "Configuring main Debian repositories..."
    export COMPONENTS="main"
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "tor" ]]; then
        warning "Repository 'contrib' will be enabled for Tor Browser."
        export COMPONENTS="main contrib"
    fi
    cat <<EOF > /etc/apt/sources.list.d/debian.sources
Types: deb
URIs: https://deb.debian.org/debian/
Suites: trixie
Components: $COMPONENTS
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security/
Suites: trixie-security
Components: $COMPONENTS
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://deb.debian.org/debian/
Suites: trixie-updates
Components: $COMPONENTS
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    [ -f /etc/apt/sources.list ] && mv /etc/apt/sources.list /etc/apt/sources.list.bak
    success "Debian repositories configured."

    info "Updating package list with new repositories..."
    apt_with_progress "update"

    info "Disabling systemd-timesyncd to avoid conflicts..."
    systemctl stop systemd-timesyncd >/dev/null 2>&1 || true
    systemctl disable systemd-timesyncd >/dev/null 2>&1 || true
    success "systemd-timesyncd disabled."

    info "Installing and synchronizing clock with Chrony..."
    if ! dpkg -l | grep -q " chrony "; then
        run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y chrony" "Installing Chrony"
        success "Chrony installed. Waiting 30 seconds for clock synchronization..."
        sleep 30
    else
        info "Chrony is already installed. Forcing resynchronization..."
        systemctl restart chrony
        sleep 10
    fi
    success "Clock synchronized."

    info "Installing essential tools, certificates and dependencies..."
    PREREQ_TOOLS=(apt-transport-https ca-certificates wget gpg curl coreutils)
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]]; then PREREQ_TOOLS+=("extrepo"); fi
    if [ "$WANT_SNAPSHOTS" = true ]; then PREREQ_TOOLS+=("timeshift"); fi
    
    INSTALL_PREREQS=()
    for tool in "${PREREQ_TOOLS[@]}"; do
        if ! dpkg -l | grep -q " $tool "; then
            INSTALL_PREREQS+=("$tool")
        fi
    done

    if [ ${#INSTALL_PREREQS[@]} -gt 0 ]; then
        apt_with_progress "install" "${INSTALL_PREREQS[@]}"
        success "Essential tools installed."
    else
        info "Essential tools are already installed."
    fi

    if [ "$WANT_SNAPSHOTS" = true ]; then
        info "Creating the first system restore point..."
        warning "This may take a few minutes."
        timeshift --create --comments "Snapshot before post-installation script" --tags D
        success "Restore point 'Before Script' created successfully!"
    fi
}
