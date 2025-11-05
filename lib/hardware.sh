#!/bin/bash
#==============================================================================
# Hardware Detection and Optimization Library
#
# PURPOSE: Detect hardware and apply optimizations using only FOSS packages
#          from Debian main repository
#==============================================================================

#==============================================================================
# FUNCTION: detect_and_configure_gpu
# DESCRIPTION: Detects GPU and installs open source drivers from main repo
#              Handles hybrid graphics (Intel + NVIDIA, AMD + NVIDIA)
#==============================================================================
detect_and_configure_gpu() {
    info "Detectando GPU do sistema..."

    local gpu_packages=()
    local has_intel=false
    local has_amd=false
    local has_nvidia=false

    # Detectar todas as GPUs presentes
    if lspci | grep -iE "vga|3d|display" | grep -qi intel; then
        has_intel=true
        info "GPU Intel detectada (integrada)"
    fi

    if lspci | grep -iE "vga|3d|display" | grep -qi amd; then
        has_amd=true
        info "GPU AMD detectada"
    fi

    if lspci | grep -iE "vga|3d|display" | grep -qi nvidia; then
        has_nvidia=true
        info "GPU NVIDIA detectada (dedicada)"

        # Suprimir erros nouveau conhecidos
        info "Configurando supressão de logs nouveau..."
        echo 'kernel.printk = 3 4 1 3' >> /etc/sysctl.conf
        echo 'nouveau.config=NvGrUseFW=1' >> /etc/modprobe.d/nouveau-blacklist.conf
    fi

    # Cenário 1: Intel + NVIDIA (híbrido - comum em notebooks)
    if [ "$has_intel" = true ] && [ "$has_nvidia" = true ]; then
        info "Sistema com GPU híbrida detectado: Intel (integrada) + NVIDIA (dedicada)"
        warning "Configurando apenas drivers Intel (open source)"
        warning "GPU NVIDIA ficará inativa (driver Nouveau desabilitado para evitar conflitos)"
        warning "Para usar NVIDIA com switching: instale 'nvidia-driver' e 'nvidia-prime' manualmente"

        gpu_packages+=(mesa-vulkan-drivers intel-media-va-driver libva-drm2 libva2)

    # Cenário 2: AMD + NVIDIA (híbrido - raro)
    elif [ "$has_amd" = true ] && [ "$has_nvidia" = true ]; then
        info "Sistema com GPU híbrida detectado: AMD + NVIDIA"
        warning "Configurando apenas drivers AMD (open source)"
        warning "GPU NVIDIA ficará inativa (driver Nouveau desabilitado)"

        gpu_packages+=(mesa-vulkan-drivers libva-drm2 libva2)

    # Cenário 3: Apenas Intel
    elif [ "$has_intel" = true ]; then
        info "GPU Intel (única)"
        gpu_packages+=(mesa-vulkan-drivers intel-media-va-driver libva-drm2 libva2)

        # Adicionar otimizações Intel específicas para Mac (somente se necessário)
        if [ "$CONFIG_TYPE" = "mac" ]; then
            # Verificar se é realmente uma GPU Intel que se beneficia dessas otimizações
            local intel_gpu_info=$(lspci | grep -i "vga.*intel")
            local intel_generation=""

            if echo "$intel_gpu_info" | grep -qi "HD Graphics\|UHD Graphics\|Iris"; then
                intel_generation="modern"
            elif echo "$intel_gpu_info" | grep -qi "GMA\|945G\|965G"; then
                intel_generation="legacy"
            fi

            if [ "$intel_generation" = "modern" ]; then
                info "Detectada GPU Intel moderna - aplicando otimizações..."

                # Verificar se o arquivo grub existe e se o sistema usa GRUB
                if [ -f "/etc/default/grub" ] && command -v update-grub &> /dev/null; then
                    # Verificar se os parâmetros já existem
                    if ! grep -q "i915.enable_guc" /etc/default/grub; then
                        # Backup do arquivo original
                        cp /etc/default/grub /etc/default/grub.bak

                        # Adicionar parâmetros Intel
                        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 i915.enable_guc=2 i915.enable_fbc=1"/' /etc/default/grub
                        info "Parâmetros Intel adicionados ao GRUB"
                        warning "Execute 'update-grub' e reinicie para aplicar otimizações de GPU"
                    else
                        info "Otimizações Intel já aplicadas no GRUB"
                    fi
                else
                    warning "GRUB não encontrado ou update-grub não disponível - pulando otimizações Intel"
                fi
            elif [ "$intel_generation" = "legacy" ]; then
                info "Detectada GPU Intel legada - otimizações modernas não são compatíveis"
            else
                info "GPU Intel não identificada ou não se beneficia das otimizações - pulando"
            fi
        fi

    # Cenário 4: Apenas AMD
    elif [ "$has_amd" = true ]; then
        info "GPU AMD (única)"
        gpu_packages+=(mesa-vulkan-drivers libva-drm2 libva2)

    # Cenário 5: Apenas NVIDIA
    elif [ "$has_nvidia" = true ]; then
        info "GPU NVIDIA (única)"
        warning "Usando driver open source Nouveau (do repositório main)"
        warning "Performance limitada. Para melhor desempenho:"
        warning "  1. Adicione 'contrib non-free-firmware' ao sources.list"
        warning "  2. Instale: apt install nvidia-driver"
        gpu_packages+=(mesa-vulkan-drivers libva-drm2 libva2)
    fi

    # Instalar pacotes se necessário
    if [ ${#gpu_packages[@]} -gt 0 ]; then
        info "Instalando drivers de GPU open source..."

        # Remover duplicatas do array
        local unique_packages=($(echo "${gpu_packages[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

        for pkg in "${unique_packages[@]}"; do
            if ! dpkg -l | grep -q " $pkg "; then
                run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y $pkg" "Instalando driver GPU $pkg"
            fi
        done
        success "Drivers de GPU instalados (FOSS - repositório main)"
    else
        info "Nenhuma GPU conhecida detectada ou drivers já instalados"
    fi

    # Se híbrido com NVIDIA, criar arquivo blacklist para nouveau
    if ([ "$has_intel" = true ] || [ "$has_amd" = true ]) && [ "$has_nvidia" = true ]; then
        info "Criando blacklist para driver Nouveau (evitar conflitos em GPU híbrida)..."
        cat > /etc/modprobe.d/blacklist-nouveau.conf <<'EOF'
# Blacklist Nouveau em sistemas com GPU híbrida
# GPU integrada (Intel/AMD) será usada por padrão
blacklist nouveau
options nouveau modeset=0
EOF
        success "Driver Nouveau desabilitado (GPU integrada será usada)"

        # Atualizar initramfs
        info "Atualizando initramfs..."
        update-initramfs -u &> /dev/null
        warning "Reinicialização necessária para aplicar mudanças de GPU"
    fi
}

#==============================================================================
# FUNCTION: configure_ssd_optimizations
# DESCRIPTION: Configures SSD optimizations (TRIM, etc)
#==============================================================================
configure_ssd_optimizations() {
    info "Verificando e configurando otimizações para SSD..."

    # Verificar se há SSDs no sistema
    local has_ssd=false
    for disk in /sys/block/sd* /sys/block/nvme*; do
        if [ -e "$disk/queue/rotational" ]; then
            if [ "$(cat $disk/queue/rotational)" = "0" ]; then
                has_ssd=true
                local disk_name=$(basename $disk)
                info "SSD detectado: $disk_name"
            fi
        fi
    done

    if [ "$has_ssd" = false ]; then
        info "Nenhum SSD detectado. Pulando otimizações de SSD."
        return
    fi

    # Habilitar TRIM automático (fstrim.timer)
    if systemctl is-enabled fstrim.timer &> /dev/null; then
        info "fstrim.timer já está habilitado"
    else
        run_with_progress "systemctl enable fstrim.timer" "Habilitando TRIM automático semanal"
    fi

    # Verificar configuração de swap (reduzir swappiness para SSDs)
    local current_swappiness=$(cat /proc/sys/vm/swappiness)
    if [ "$current_swappiness" -gt 10 ]; then
        info "Ajustando swappiness para 10 (otimização SSD)..."
        echo "vm.swappiness=10" > /etc/sysctl.d/99-ssd-swappiness.conf
        sysctl -w vm.swappiness=10 &> /dev/null
        success "Swappiness ajustado para 10"
    else
        info "Swappiness já está otimizado ($current_swappiness)"
    fi

    # Configurar I/O scheduler para SSDs (mq-deadline ou none para NVMe)
    for disk in /sys/block/sd* /sys/block/nvme*; do
        if [ -e "$disk/queue/rotational" ] && [ "$(cat $disk/queue/rotational)" = "0" ]; then
            local disk_name=$(basename $disk)
            if [ -e "$disk/queue/scheduler" ]; then
                # Para NVMe, none é geralmente melhor; para SATA SSDs, mq-deadline
                if [[ "$disk_name" == nvme* ]]; then
                    echo "none" > "$disk/queue/scheduler" 2>/dev/null && \
                        info "Scheduler 'none' definido para $disk_name"
                else
                    echo "mq-deadline" > "$disk/queue/scheduler" 2>/dev/null && \
                        info "Scheduler 'mq-deadline' definido para $disk_name"
                fi
            fi
        fi
    done

    # Configurar otimizações avançadas somente se há SSDs detectados
    if [ "$has_ssd" = true ]; then
        # Verificar se as otimizações já foram aplicadas
        if [ ! -f "/etc/udev/rules.d/60-ssd-scheduler.rules" ]; then
            info "Configurando readahead otimizado para SSDs..."
            cat > /etc/udev/rules.d/60-ssd-scheduler.rules <<'EOF'
# Configurações para SSDs
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/read_ahead_kb}="128"
ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/read_ahead_kb}="128"
EOF
        else
            info "Regras udev para SSD já configuradas"
        fi

        # Verificar se os parâmetros de sistema já foram configurados
        if [ ! -f "/etc/sysctl.d/99-performance.conf" ]; then
            info "Configurando parâmetros de sistema para performance com SSD..."
            cat > /etc/sysctl.d/99-performance.conf <<'EOF'
# Otimizações de performance para SSD
vm.dirty_ratio=5
vm.dirty_background_ratio=2
vm.vfs_cache_pressure=50
kernel.nmi_watchdog=0
EOF
        else
            info "Parâmetros de performance já configurados"
        fi
    else
        info "Nenhum SSD detectado - pulando otimizações avançadas de I/O"
    fi

    success "Otimizações de SSD aplicadas"
}

#==============================================================================
# FUNCTION: configure_tlp_power_management
# DESCRIPTION: Configures TLP for notebook power management
#==============================================================================
configure_tlp_power_management() {
    # Verificar se é notebook (tem bateria)
    if [ ! -d /sys/class/power_supply/BAT* ] 2>/dev/null; then
        info "Sistema não é um notebook. Pulando configuração do TLP."
        return
    fi

    info "Notebook detectado. Configurando TLP para gerenciamento de energia..."

    # Instalar TLP
    if ! dpkg -l | grep -q " tlp "; then
        run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y tlp" "Instalando TLP"
    else
        info "TLP já está instalado"
    fi

    # Criar configuração personalizada do TLP
    info "Criando configuração otimizada do TLP..."
    cat > /etc/tlp.d/01-custom.conf <<'EOF'
# Configuração TLP customizada para notebooks

# CPU
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave
CPU_ENERGY_PERF_POLICY_ON_AC=performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# Platform
PLATFORM_PROFILE_ON_AC=performance
PLATFORM_PROFILE_ON_BAT=low-power

# Disk
DISK_DEVICES="nvme0n1 sda"
DISK_APM_LEVEL_ON_AC="254 254"
DISK_APM_LEVEL_ON_BAT="128 128"

# PCI Express
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersupersave

# USB
USB_AUTOSUSPEND=1
USB_EXCLUDE_AUDIO=1
USB_EXCLUDE_BTUSB=0
USB_EXCLUDE_PHONE=0
USB_EXCLUDE_PRINTER=1
USB_EXCLUDE_WWAN=0

# Battery
START_CHARGE_THRESH_BAT0=75
STOP_CHARGE_THRESH_BAT0=80
RESTORE_THRESHOLDS_ON_BAT=1
EOF

    # Habilitar e iniciar TLP
    run_with_progress "systemctl enable tlp" "Habilitando serviço TLP"
    run_with_progress "systemctl start tlp" "Iniciando serviço TLP"

    success "TLP configurado e habilitado"
}

#==============================================================================
# FUNCTION: configure_thermald
# DESCRIPTION: Configures thermald for thermal management (Intel only)
#==============================================================================
configure_thermald() {
    # Verificar se é CPU Intel
    if ! grep -qi intel /proc/cpuinfo; then
        info "CPU Intel não detectada. thermald funciona apenas com Intel."
        return
    fi

    info "CPU Intel detectada. Configurando thermald..."

    # Instalar thermald
    if ! dpkg -l | grep -q " thermald "; then
        run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y thermald" "Instalando thermald"
    else
        info "thermald já está instalado"
    fi

    # Habilitar e iniciar thermald
    run_with_progress "systemctl enable thermald" "Habilitando serviço thermald"
    run_with_progress "systemctl start thermald" "Iniciando serviço thermald"

    success "thermald configurado e habilitado"
}

#==============================================================================
# FUNCTION: apply_hardware_optimizations
# DESCRIPTION: Main function to apply all hardware optimizations
#==============================================================================
apply_hardware_optimizations() {
    info "Iniciando detecção de hardware e otimizações..."

    detect_and_configure_gpu
    configure_ssd_optimizations
    configure_tlp_power_management
    configure_thermald

    success "Todas as otimizações de hardware foram aplicadas"
}
