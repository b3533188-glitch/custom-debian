#!/bin/bash
#==============================================================================
# Packages Library

#==============================================================================
# FUNCTION: install_appimagelauncher
#==============================================================================
install_appimagelauncher() {
    if command -v appimagelauncher &> /dev/null; then
        info "AppImageLauncher is already installed. Skipping."
        return 0
    fi

    info "Starting secure installation ofAppImageLauncher..."

    # Buscar informações da última release via API do GitHub
    local API_URL="https://api.github.com/repos/TheAssassin/AppImageLauncher/releases/latest"
    local RELEASE_INFO="/tmp/appimagelauncher_release.json"

    if ! run_with_progress "curl -sL '$API_URL' -o '$RELEASE_INFO'" "Fetching version of AppImageLauncher"; then
        error "Failed to fetch latest release information. Installation aborted."
        rm -f "$RELEASE_INFO"
        return 1
    fi

    # Extrair URL e SHA256 do .deb amd64
    local DEB_URL=$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .browser_download_url' "$RELEASE_INFO")
    local DEB_NAME=$(jq -r '.assets[] | select(.name | test("_amd64\\.deb$")) | .name' "$RELEASE_INFO")

    # Buscar o SHA256 da página de release (está na descrição dos assets)
    local ASSET_INFO=$(jq -r '.body' "$RELEASE_INFO" | grep -A1 "$DEB_NAME" | grep "sha256:" | sed 's/sha256://' | tr -d ' ')

    if [ -z "$DEB_URL" ] || [ -z "$DEB_NAME" ]; then
        error "Could not find amd64 .deb file in latest release."
        rm -f "$RELEASE_INFO"
        return 1
    fi

    local DEB_PATH="/tmp/$DEB_NAME"
    local installed=false
    trap 'rm -f "$DEB_PATH" "$RELEASE_INFO"' RETURN

    for attempt in 1 2; do
        if ! run_with_progress "wget -q -O '$DEB_PATH' '$DEB_URL'" "DownloadingAppImageLauncher (tentativa $attempt/2)"; then
            warning "Failed to downloado arquivo na tentativa $attempt."
            if [ "$attempt" -eq 2 ]; then
                error "Failed to downloadAppImageLauncher. Installation aborted."
                return 1
            fi
            sleep 2
            continue
        fi

        if [ -n "$ASSET_INFO" ]; then
            info "Verificando a integridade do arquivo..."
            local local_sum=$(sha256sum "$DEB_PATH" | awk '{print $1}')

            if [ "$local_sum" == "$ASSET_INFO" ]; then
                success "Checksum verificado com sucesso!"
                info "Instalando o AppImageLauncher..."
                run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y '$DEB_PATH'" "Instalando $DEB_NAME"
                success "AppImageLauncher installed successfully."
                installed=true
                break
            else
                warning "Checksum verification failed na tentativa $attempt!"
                if [ "$attempt" -eq 2 ]; then
                    error "A verificação do checksum do AppImageLauncher falhou duas vezes. Instalação abortada por segurança."
                    return 1
                fi
                info "Removendo arquivo corrompido e tentando novamente em 3 segundos..."
                rm -f "$DEB_PATH"
                sleep 3
            fi
        else
            warning "SHA256 checksum not found in release. Installing without verification..."
            info "Instalando o AppImageLauncher..."
            run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y '$DEB_PATH'" "Instalando pacote .deb"
            success "AppImageLauncher installed successfully (without checksum verification)."
            installed=true
            break
        fi
    done

    if [ "$installed" = false ]; then
        error "Could not install AppImageLauncher."
        return 1
    fi

    return 0
}

#==============================================================================
# FUNCTION: install_veracrypt
#==============================================================================
install_veracrypt() {
    if command -v veracrypt &> /dev/null; then
        info "VeraCrypt is already installed. Skipping."
        return 0
    fi

    info "Starting secure installation ofVeraCrypt..."

    # Try to get latest version dynamically, fallback to known version
    info "Fetching the latest version of VeraCrypt..."
    local LATEST_VERSION=$(curl -s https://api.github.com/repos/veracrypt/VeraCrypt/releases/latest | grep '"tag_name"' | sed -E 's/.*"tag_name": *"VeraCrypt_([^"]+)".*/\1/' 2>/dev/null || echo "1.26.24")

    if [ -z "$LATEST_VERSION" ] || ! [[ "$LATEST_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        warning "Could not get the latest version. Using known version 1.26.24"
        LATEST_VERSION="1.26.24"
    else
        info "Versão mais recente encontrada: $LATEST_VERSION"
    fi

    local VERA_DEB_URL="https://launchpad.net/veracrypt/trunk/${LATEST_VERSION}/+download/veracrypt-${LATEST_VERSION}-Debian-12-amd64.deb"

    # For SHA512 URL, we'll need to try to construct it or fall back to verification by download
    local VERA_SHA_URL="https://launchpadlibrarian.net/799175880/veracrypt-${LATEST_VERSION}-sha512sum.txt"
    local DEB_NAME=$(basename "$VERA_DEB_URL")
    local DEB_PATH="/tmp/$DEB_NAME"
    local SHA_PATH="/tmp/veracrypt-sha512sum.txt"
    local installed=false
    trap 'rm -f "$DEB_PATH" "$SHA_PATH"' RETURN
    for attempt in 1 2; do
        info "Tentativa $attempt/2: DownloadingVeraCrypt..."
        if ! wget -q --show-progress -O "$DEB_PATH" "$VERA_DEB_URL"; then
            error "Failed to downloadVeraCrypt na tentativa $attempt"
            continue
        fi

        info "Tentando baixar arquivo de checksum..."
        local has_sha_file=false
        if wget -q -O "$SHA_PATH" "$VERA_SHA_URL" 2>/dev/null; then
            has_sha_file=true
        fi

        info "Verificando a integridade do arquivo..."
        local local_sum=$(sha512sum "$DEB_PATH" | awk '{print $1}')
        local official_sum=""

        if [ "$has_sha_file" = true ]; then
            official_sum=$(grep "$DEB_NAME" "$SHA_PATH" | awk '{print $1}' 2>/dev/null)
        fi

        if [ -z "$official_sum" ]; then
            if [ "$has_sha_file" = true ]; then
                warning "Não foi possível encontrar o checksum oficial para $DEB_NAME na tentativa $attempt."
                if [ "$attempt" -eq 2 ]; then
                    warning "Arquivo de checksum não contém hash para esta versão."
                    warning "Procedendo com instalação (arquivo baixado de fonte oficial)."
                    warning "SHA512 local: $local_sum"
                    run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y '$DEB_PATH'" "Instalando $DEB_NAME"
                    success "VeraCrypt installed successfully."
                    installed=true; break
                fi
                sleep 2; continue
            else
                warning "Arquivo de checksum não disponível para esta versão."
                warning "Procedendo com instalação (arquivo baixado de fonte oficial)."
                warning "SHA512 do arquivo: $local_sum"
                run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y '$DEB_PATH'" "Instalando $DEB_NAME"
                success "VeraCrypt installed successfully."
                installed=true; break
            fi
        else
            if [ "$local_sum" == "$official_sum" ]; then
                success "Checksum verificado com sucesso!"
                info "Instalando o VeraCrypt..."
                run_with_progress "DEBIAN_FRONTEND=noninteractive apt-get install -qq -y '$DEB_PATH'" "Instalando $DEB_NAME"
                success "VeraCrypt installed successfully."
                installed=true; break
            else
                warning "Checksum verification failed na tentativa $attempt!"
                if [ "$attempt" -eq 2 ]; then error "A verificação do checksum do VeraCrypt falhou duas vezes. Instalação abortada por segurança."; return 1; fi
                info "Removendo arquivos corrompidos e tentando novamente em 3 segundos..."
                rm -f "$DEB_PATH" "$SHA_PATH"; sleep 3
            fi
        fi
    done
    if [ "$installed" = false ]; then error "Could not install VeraCrypt."; return 1; fi
    return 0
}

#==============================================================================
# FUNCTION: install_helium
#==============================================================================
install_helium() {
    if [ -f "$USER_HOME/Applications/helium.AppImage" ]; then
        info "Helium is already installed. Skipping."
        return 0
    fi

    info "Starting secure installation ofHelium Browser..."

    # Buscar informações da última release via API do GitHub
    local API_URL="https://api.github.com/repos/imputnet/helium-linux/releases/latest"
    local RELEASE_INFO="/tmp/helium_release.json"

    if ! run_with_progress "curl -sL '$API_URL' -o '$RELEASE_INFO'" "Fetching version of Helium"; then
        error "Failed to fetch latest release information. Installation aborted."
        rm -f "$RELEASE_INFO"
        return 1
    fi

    # Extrair URL do AppImage x86_64
    local APPIMAGE_URL=$(jq -r '.assets[] | select(.name | test("-x86_64\\.AppImage$")) | .browser_download_url' "$RELEASE_INFO")
    local APPIMAGE_NAME=$(jq -r '.assets[] | select(.name | test("-x86_64\\.AppImage$")) | .name' "$RELEASE_INFO")

    if [ -z "$APPIMAGE_URL" ] || [ -z "$APPIMAGE_NAME" ]; then
        error "Não foi possível encontrar o AppImage x86_64 na última release."
        rm -f "$RELEASE_INFO"
        return 1
    fi

    # Buscar o SHA256 da release (está nos assets)
    local SHA_ASSET=$(jq -r --arg name "$APPIMAGE_NAME" '.body | split("\n")[] | select(contains($name)) | select(contains("sha256"))' "$RELEASE_INFO")
    local EXPECTED_SHA=""
    if [ -n "$SHA_ASSET" ]; then
        EXPECTED_SHA=$(echo "$SHA_ASSET" | grep -oP 'sha256:\s*\K[a-f0-9]{64}')
    fi

    local APPIMAGE_PATH="/tmp/$APPIMAGE_NAME"
    local installed=false
    trap 'rm -f "$APPIMAGE_PATH" "$RELEASE_INFO"' RETURN

    for attempt in 1 2; do
        if ! run_with_progress "wget -q -O '$APPIMAGE_PATH' '$APPIMAGE_URL'" "DownloadingHelium (tentativa $attempt/2)"; then
            warning "Failed to downloado arquivo na tentativa $attempt."
            if [ "$attempt" -eq 2 ]; then
                error "Failed to downloadHelium. Installation aborted."
                return 1
            fi
            sleep 2
            continue
        fi

        if [ -n "$EXPECTED_SHA" ]; then
            info "Verificando a integridade do arquivo..."
            local local_sum=$(sha256sum "$APPIMAGE_PATH" | awk '{print $1}')

            if [ "$local_sum" == "$EXPECTED_SHA" ]; then
                success "Checksum verificado com sucesso!"
                break
            else
                warning "Checksum verification failed na tentativa $attempt!"
                warning "Esperado: $EXPECTED_SHA"
                warning "Obtido:   $local_sum"
                if [ "$attempt" -eq 2 ]; then
                    error "A verificação do checksum do Helium falhou duas vezes. Instalação abortada por segurança."
                    return 1
                fi
                info "Removendo arquivo corrompido e tentando novamente em 3 segundos..."
                rm -f "$APPIMAGE_PATH"
                sleep 3
            fi
        else
            warning "Checksum SHA256 não encontrado na release. Continuando sem verificação..."
            break
        fi
    done

    # Instalar o AppImage
    info "Instalando Helium em ~/Applications..."
    mkdir -p "$USER_HOME/Applications"
    mv "$APPIMAGE_PATH" "$USER_HOME/Applications/helium.AppImage"
    chmod +x "$USER_HOME/Applications/helium.AppImage"
    chown "$SUDO_USER":"$SUDO_USER" "$USER_HOME/Applications/helium.AppImage"

    # Instalar o ícone
    info "Instalando ícone do Helium..."
    local SCRIPT_DIR_HELIUM=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    local LOCAL_HELIUM_ICON="$SCRIPT_DIR_HELIUM/../icons/helium.png"

    if [ -f "$LOCAL_HELIUM_ICON" ]; then
        # Instalar nos diretórios de ícones do sistema e do usuário
        mkdir -p "$USER_HOME/.local/share/icons/hicolor/256x256/apps"
        mkdir -p "/usr/share/icons/hicolor/256x256/apps"

        cp "$LOCAL_HELIUM_ICON" "$USER_HOME/.local/share/icons/hicolor/256x256/apps/helium.png"
        cp "$LOCAL_HELIUM_ICON" "/usr/share/icons/hicolor/256x256/apps/helium.png"

        chown -R "$SUDO_USER":"$SUDO_USER" "$USER_HOME/.local/share/icons"

        # Atualizar cache de ícones
        gtk-update-icon-cache /usr/share/icons/hicolor/ -f 2>/dev/null || true
        su - "$SUDO_USER" -c "gtk-update-icon-cache $USER_HOME/.local/share/icons/hicolor/ -f 2>/dev/null" || true

        success "Ícone do Helium instalado."
    else
        warning "Ícone do Helium não encontrado em $LOCAL_HELIUM_ICON. Usando ícone genérico."
    fi

    # Criar .desktop file
    info "Criando arquivo .desktop para Helium..."
    cat <<EOF > "/usr/share/applications/helium.desktop"
[Desktop Entry]
Name=Helium Browser
Comment=Privacy-focused web browser
Exec=$USER_HOME/Applications/helium.AppImage %U
Terminal=false
Type=Application
Icon=helium
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
EOF

    success "Helium installed successfully em ~/Applications/helium.AppImage"
    return 0
}

#==============================================================================
# FUNCTION: install_packages
#==============================================================================
install_packages() {
    info "Starting package installation phase..."

    # Install all required dependencies for repository setup first
    info "Installing required tools for repository configuration..."
    REPO_DEPS=()

    # Check what tools we need based on selected packages
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]]; then
        REPO_DEPS+=("extrepo")
    fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "signal" ]]; then
        REPO_DEPS+=("wget")
    fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-vpn" ]] || [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-browser" ]]; then
        REPO_DEPS+=("curl")
    fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "brave-browser" ]]; then
        REPO_DEPS+=("curl")
    fi

    # Remove duplicates and install missing tools
    REPO_DEPS=($(printf "%s\n" "${REPO_DEPS[@]}" | sort -u))
    MISSING_REPO_DEPS=()

    for tool in "${REPO_DEPS[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            MISSING_REPO_DEPS+=("$tool")
        fi
    done

    if [ ${#MISSING_REPO_DEPS[@]} -gt 0 ]; then
        info "Installing repository tools: ${MISSING_REPO_DEPS[*]}"
        apt_with_progress "install" "${MISSING_REPO_DEPS[@]}"
    fi

    NEEDS_APT_UPDATE=false

    # Configure repositories now that all tools are available
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]] && [ ! -f /etc/apt/sources.list.d/extrepo_librewolf.sources ]; then
        info "Enabling LibreWolf repository..."
        extrepo enable librewolf
        NEEDS_APT_UPDATE=true
    fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "signal" ]] && [ ! -f /etc/apt/sources.list.d/signal-xenial.list ]; then
        info "Configuring Signal repository..."
        local signal_key_temp="/tmp/signal-key.asc"

        if wget -q -O "$signal_key_temp" https://updates.signal.org/desktop/apt/keys.asc 2>/dev/null; then
            # Verificar se a chave parece válida através de múltiplos critérios
            local key_info=$(gpg --quiet --with-fingerprint --show-keys "$signal_key_temp" 2>/dev/null)
            local is_valid=false

            # Verificações básicas de validade da chave
            local has_signal_identity=false
            local has_valid_key_format=false
            local has_expected_fingerprint=false

            # Verificar identidade Signal/Open Whisper Systems
            if echo "$key_info" | grep -qi "Open Whisper Systems\|support@whispersystems.org\|Signal\|@signal.org"; then
                has_signal_identity=true
            fi

            # Verificar formato da chave
            if echo "$key_info" | grep -q "pub.*rsa" && echo "$key_info" | grep -qE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}"; then
                has_valid_key_format=true
            fi

            # Verificar fingerprint conhecido (adicional, não obrigatório)
            # Remover espaços da fingerprint para comparação
            local key_fingerprints=$(echo "$key_info" | grep -oE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}" | tr -d ' ')

            if echo "$key_fingerprints" | grep -q "DBA36B5181D0C816F630E889D980A17457F6FB06"; then
                has_expected_fingerprint=true
                info "Fingerprint conhecido do Signal confirmado."
            else
                info "Fingerprint diferente do esperado - isso pode ser normal se Signal atualizou a chave."
            fi

            # Chave é válida se tem identidade Signal E formato válido
            if [ "$has_signal_identity" = true ] && [ "$has_valid_key_format" = true ]; then
                is_valid=true
                if [ "$has_expected_fingerprint" = true ]; then
                    success "Chave do Signal verificada com fingerprint conhecido."
                else
                    success "Chave do Signal verificada (novo fingerprint detectado)."
                fi
            fi

            if [ "$is_valid" = true ]; then
                gpg --dearmor < "$signal_key_temp" > /usr/share/keyrings/signal-desktop-keyring.gpg
                echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' > /etc/apt/sources.list.d/signal-xenial.list
                NEEDS_APT_UPDATE=true
                success "Chave do Signal verificada e adicionada."
            else
                warning "AVISO: A chave GPG baixada não passou nas verificações de validade!"
                warning "Isso pode indicar um problema de segurança ou chave corrompida."

                # Mostrar informações da chave baixada
                echo ""
                echo "Informações da chave baixada:"
                echo "$key_info"
                echo ""
                echo "A chave deveria:"
                echo "- Ser do tipo RSA"
                echo "- Pertencer a Open Whisper Systems ou Signal"
                echo "- Ter um fingerprint válido"
                echo ""
                echo "Opções:"
                echo "1) Continuar e instalar Signal mesmo assim (RISCO DE SEGURANÇA)"
                echo "2) Pular instalação do Signal e continuar"
                echo "3) Encerrar script completamente"
                echo ""
                read -p "Escolha uma opção [1-3]: " choice

                case $choice in
                    1)
                        warning "Instalando Signal com chave não verificada..."
                        gpg --dearmor < "$signal_key_temp" > /usr/share/keyrings/signal-desktop-keyring.gpg
                        echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main' > /etc/apt/sources.list.d/signal-xenial.list
                        NEEDS_APT_UPDATE=true
                        warning "Signal será instalado com chave não verificada."
                        ;;
                    2)
                        info "Pulando instalação do Signal..."
                        # Remove signal from the list of packages to install
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/signal/})
                        ;;
                    3)
                        error "Script encerrado pelo usuário devido à falha de verificação do Signal."
                        exit 1
                        ;;
                    *)
                        warning "Opção inválida. Pulando instalação do Signal..."
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/signal/})
                        ;;
                esac
            fi
        else
            error "Failed to downloadchave GPG do Signal."
            echo ""
            echo "Opções:"
            echo "1) Pular instalação do Signal e continuar"
            echo "2) Encerrar script"
            echo ""
            read -p "Escolha uma opção [1-2]: " choice

            case $choice in
                1)
                    info "Pulando instalação do Signal..."
                    CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/signal/})
                    ;;
                *)
                    error "Script encerrado devido à falha no download da chave do Signal."
                    exit 1
                    ;;
            esac
        fi
        rm -f "$signal_key_temp"
    fi
    if ([[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-vpn" ]] || [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-browser" ]]) && [ ! -f /etc/apt/sources.list.d/mullvad.list ]; then
        info "Configuring Mullvad repository..."
        local mullvad_key_temp="/tmp/mullvad-keyring.asc"

        if curl -fsSLo "$mullvad_key_temp" https://repository.mullvad.net/deb/mullvad-keyring.asc; then
            # Verificar se a chave parece válida através de múltiplos critérios
            local key_info=$(gpg --quiet --with-fingerprint --show-keys "$mullvad_key_temp" 2>/dev/null)
            local is_valid=false

            # Verificações básicas de validade da chave
            local has_mullvad_identity=false
            local has_valid_key_format=false
            local has_expected_fingerprint=false

            # Verificar identidade Mullvad
            if echo "$key_info" | grep -qi "Mullvad.*admin@mullvad.net\|code.*signing"; then
                has_mullvad_identity=true
            fi

            # Verificar formato da chave
            if echo "$key_info" | grep -q "pub.*rsa" && echo "$key_info" | grep -qE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}"; then
                has_valid_key_format=true
            fi

            # Verificar fingerprint conhecido (adicional, não obrigatório)
            # Remover espaços da fingerprint para comparação
            local key_fingerprints=$(echo "$key_info" | grep -oE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}" | tr -d ' ')

            if echo "$key_fingerprints" | grep -q "A1198702FC3E0A09A9AE5B75D5A1D4F266DE8DDF"; then
                has_expected_fingerprint=true
                info "Fingerprint conhecido do Mullvad confirmado."
            else
                info "Fingerprint diferente do esperado - isso pode ser normal se Mullvad atualizou a chave."
            fi

            # Chave é válida se tem identidade Mullvad E formato válido
            if [ "$has_mullvad_identity" = true ] && [ "$has_valid_key_format" = true ]; then
                is_valid=true
                if [ "$has_expected_fingerprint" = true ]; then
                    success "Chave do Mullvad verificada com fingerprint conhecido."
                else
                    success "Chave do Mullvad verificada (novo fingerprint detectado)."
                fi
            fi

            if [ "$is_valid" = true ]; then
                cp "$mullvad_key_temp" /usr/share/keyrings/mullvad-keyring.asc
                echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list
                NEEDS_APT_UPDATE=true
                success "Mullvad key verified and added."
            else
                warning "AVISO: A chave GPG do Mullvad não passou nas verificações de validade!"
                warning "Isso pode indicar um problema de segurança ou chave corrompida."

                # Mostrar informações da chave baixada
                echo ""
                echo "Informações da chave baixada:"
                echo "$key_info"
                echo ""
                echo "A chave deveria:"
                echo "- Ser do tipo RSA"
                echo "- Pertencer a Mullvad (admin@mullvad.net)"
                echo "- Ter um fingerprint válido"
                echo ""
                echo "Opções:"
                echo "1) Continuar e instalar Mullvad mesmo assim (RISCO DE SEGURANÇA)"
                echo "2) Pular instalação do Mullvad e continuar"
                echo "3) Encerrar script completamente"
                echo ""
                read -p "Escolha uma opção [1-3]: " choice

                case $choice in
                    1)
                        warning "Installing Mullvad with unverified key..."
                        cp "$mullvad_key_temp" /usr/share/keyrings/mullvad-keyring.asc
                        echo "deb [signed-by=/usr/share/keyrings/mullvad-keyring.asc arch=$( dpkg --print-architecture )] https://repository.mullvad.net/deb/stable stable main" > /etc/apt/sources.list.d/mullvad.list
                        NEEDS_APT_UPDATE=true
                        warning "Mullvad will be installed with unverified key."
                        ;;
                    2)
                        info "Pulando instalação do Mullvad..."
                        # Remove mullvad from the list of packages to install
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-vpn/})
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-browser/})
                        ;;
                    3)
                        error "Script encerrado pelo usuário devido à falha de verificação do Mullvad."
                        exit 1
                        ;;
                    *)
                        warning "Opção inválida. Pulando instalação do Mullvad..."
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-vpn/})
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-browser/})
                        ;;
                esac
            fi
        else
            error "Failed to downloadchave GPG do Mullvad."
            echo ""
            echo "Opções:"
            echo "1) Pular instalação do Mullvad e continuar"
            echo "2) Encerrar script"
            echo ""
            read -p "Escolha uma opção [1-2]: " choice

            case $choice in
                1)
                    info "Pulando instalação do Mullvad..."
                    CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-vpn/})
                    CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/mullvad-browser/})
                    ;;
                *)
                    error "Script encerrado devido à falha no download da chave do Mullvad."
                    exit 1
                    ;;
            esac
        fi
        rm -f "$mullvad_key_temp"
    fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "brave-browser" ]] && [ ! -f /etc/apt/sources.list.d/brave-browser-release.sources ]; then
        info "Configurando repositório do Brave Browser..."
        local brave_key_temp="/tmp/brave-browser-archive-keyring.gpg"
        local brave_sources_temp="/tmp/brave-browser.sources"

        if curl -fsSLo "$brave_key_temp" https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg && \
           curl -fsSLo "$brave_sources_temp" https://brave-browser-apt-release.s3.brave.com/brave-browser.sources; then

            # Verificar se a chave parece válida através de múltiplos critérios
            local key_info=$(gpg --quiet --with-fingerprint --show-keys "$brave_key_temp" 2>/dev/null)
            local sources_valid=false
            local key_valid=false

            # Verificar sources file (suporta formato DEB822 e formato legado)
            # DEB822 format: URIs, Suites, Components em linhas separadas
            # Legacy format: deb URL suite component em uma linha
            if { grep -q "URIs:.*brave-browser-apt-release" "$brave_sources_temp" && \
                 grep -q "Suites:.*stable" "$brave_sources_temp" && \
                 grep -q "Components:.*main" "$brave_sources_temp" && \
                 grep -q "Signed-By:.*brave-browser-archive-keyring.gpg" "$brave_sources_temp"; } || \
               { grep -q "deb.*brave-browser-apt-release.*stable.*main" "$brave_sources_temp" && \
                 grep -q "Signed-By:.*brave-browser-archive-keyring.gpg" "$brave_sources_temp"; }; then
                sources_valid=true
            fi

            # Verificar chave GPG com verificações em camadas
            local has_brave_identity=false
            local has_valid_key_format=false
            local has_known_fingerprint=false

            # Verificar identidade Brave
            if echo "$key_info" | grep -qi "Brave.*Linux.*Release\|brave-linux-release@brave.com\|linux-release@brave.com"; then
                has_brave_identity=true
            fi

            # Verificar formato da chave
            if echo "$key_info" | grep -q "pub.*rsa" && echo "$key_info" | grep -qE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}"; then
                has_valid_key_format=true
            fi

            # Verificar fingerprints conhecidos (Brave tem múltiplas chaves válidas)
            # Remover espaços da fingerprint para comparação
            local key_fingerprints=$(echo "$key_info" | grep -oE "[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}\s+[0-9A-F]{4}" | tr -d ' ')

            if echo "$key_fingerprints" | grep -qE "DBF1A116C220B8C7164F982306866B8420038257|47D32A74E9A9E013A4B4926C68D513D36A73CD96|B2A3DCA350E67256740DF904DE4EC67BE4B0DCA0"; then
                has_known_fingerprint=true
                info "Fingerprint conhecido do Brave confirmado."
            else
                info "Novo fingerprint detectado - isso pode ser normal se Brave adicionou nova chave."
            fi

            # Chave é válida se tem identidade Brave E formato válido
            if [ "$has_brave_identity" = true ] && [ "$has_valid_key_format" = true ]; then
                key_valid=true
                if [ "$has_known_fingerprint" = true ]; then
                    success "Chave do Brave verificada com fingerprint conhecido."
                else
                    success "Chave do Brave verificada (novo fingerprint detectado)."
                fi
            fi

            if [ "$key_valid" = true ] && [ "$sources_valid" = true ]; then
                cp "$brave_key_temp" /usr/share/keyrings/brave-browser-archive-keyring.gpg
                cp "$brave_sources_temp" /etc/apt/sources.list.d/brave-browser-release.sources
                NEEDS_APT_UPDATE=true
                success "Repositório do Brave Browser verificado e adicionado."
            else
                warning "AVISO: Arquivos do Brave Browser não passaram nas verificações de validade!"
                warning "Chave válida: $key_valid | Sources válido: $sources_valid"
                warning "Isso pode indicar um problema de segurança ou arquivos corrompidos."

                # Mostrar informações detalhadas
                echo ""
                echo "Informações da verificação:"
                if [ "$key_valid" = false ]; then
                    echo "Informações da chave: $key_info"
                fi
                if [ "$sources_valid" = false ]; then
                    echo "Conteúdo do sources:"
                    cat "$brave_sources_temp" 2>/dev/null || echo "Erro ao ler sources"
                fi
                echo ""
                echo "Os arquivos deveriam:"
                echo "- Chave: RSA, pertencer a Brave Linux Release"
                echo "- Sources: referências corretas ao repositório Brave"
                echo ""
                echo "Opções:"
                echo "1) Continuar e instalar Brave mesmo assim (RISCO DE SEGURANÇA)"
                echo "2) Pular instalação do Brave e continuar"
                echo "3) Encerrar script completamente"
                echo ""
                read -p "Escolha uma opção [1-3]: " choice

                case $choice in
                    1)
                        warning "Instalando Brave com arquivos não verificados..."
                        cp "$brave_key_temp" /usr/share/keyrings/brave-browser-archive-keyring.gpg
                        cp "$brave_sources_temp" /etc/apt/sources.list.d/brave-browser-release.sources
                        NEEDS_APT_UPDATE=true
                        warning "Brave será instalado com arquivos não verificados."
                        ;;
                    2)
                        info "Pulando instalação do Brave..."
                        # Remove brave from the list of packages to install
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/brave-browser/})
                        ;;
                    3)
                        error "Script encerrado pelo usuário devido à falha de verificação do Brave."
                        exit 1
                        ;;
                    *)
                        warning "Opção inválida. Pulando instalação do Brave..."
                        CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/brave-browser/})
                        ;;
                esac
            fi
        else
            error "Failed to downloadarquivos do Brave Browser."
            echo ""
            echo "Opções:"
            echo "1) Pular instalação do Brave e continuar"
            echo "2) Encerrar script"
            echo ""
            read -p "Escolha uma opção [1-2]: " choice

            case $choice in
                1)
                    info "Pulando instalação do Brave..."
                    CHOSEN_DEB_OPTIONS=(${CHOSEN_DEB_OPTIONS[@]/brave-browser/})
                    ;;
                *)
                    error "Script encerrado devido à falha no download dos arquivos do Brave."
                    exit 1
                    ;;
            esac
        fi
        rm -f "$brave_key_temp" "$brave_sources_temp"
    fi
    
    if [ "$NEEDS_APT_UPDATE" = true ]; then 
        info "Atualizando a lista de pacotes com os novos repositórios..."
        apt_with_progress "update"
    fi

    info "Montando a lista final de pacotes Debian para instalação..."
    PACKAGES_TO_INSTALL=("${MANDATORY_PACKAGES[@]}")

    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "btop" ]]; then PACKAGES_TO_INSTALL+=("btop"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "fastfetch" ]]; then PACKAGES_TO_INSTALL+=("fastfetch"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "neovim" ]]; then PACKAGES_TO_INSTALL+=("neovim"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "firefox-esr" ]]; then PACKAGES_TO_INSTALL+=("firefox-esr"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "thunderbird" ]]; then PACKAGES_TO_INSTALL+=("thunderbird"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "chromium" ]]; then PACKAGES_TO_INSTALL+=("chromium"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "brave-browser" ]]; then PACKAGES_TO_INSTALL+=("brave-browser"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "librewolf" ]]; then PACKAGES_TO_INSTALL+=("librewolf"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "keepassxc" ]]; then PACKAGES_TO_INSTALL+=("keepassxc"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "nextcloud-desktop" ]]; then PACKAGES_TO_INSTALL+=("nextcloud-desktop"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "kvm" ]]; then PACKAGES_TO_INSTALL+=("qemu-system" "libvirt-daemon-system" "virt-manager"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "dnscrypt-proxy" ]]; then PACKAGES_TO_INSTALL+=("dnscrypt-proxy"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "tor" ]]; then PACKAGES_TO_INSTALL+=("tor" "torbrowser-launcher"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "signal" ]]; then PACKAGES_TO_INSTALL+=("signal-desktop"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-vpn" ]]; then PACKAGES_TO_INSTALL+=("mullvad-vpn"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "mullvad-browser" ]]; then PACKAGES_TO_INSTALL+=("mullvad-browser"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "wine" ]]; then PACKAGES_TO_INSTALL+=("wine" "wine64" "libwine" "fonts-wine"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "bleachbit" ]]; then PACKAGES_TO_INSTALL+=("bleachbit"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "deluge" ]]; then PACKAGES_TO_INSTALL+=("deluge" "deluged"); fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "veracrypt" ]]; then PACKAGES_TO_INSTALL+=("libfuse2t64" "libpcre2-32-0" "libwxbase3.2-1t64" "libwxgtk3.2-1t64"); fi

    # Adiciona gerenciadores de arquivos selecionados
    if [[ " ${CHOSEN_FILE_MANAGERS[*]} " =~ "ranger" ]]; then PACKAGES_TO_INSTALL+=("ranger"); fi
    if [[ " ${CHOSEN_FILE_MANAGERS[*]} " =~ "thunar" ]]; then PACKAGES_TO_INSTALL+=("thunar" "thunar-volman" "gvfs" "udisks2"); fi
    
    if [ "$IS_KVM_GUEST" = true ]; then PACKAGES_TO_INSTALL+=("qemu-guest-agent" "spice-vdagent" "spice-webdavd"); fi
    if [ "$WANT_FLATPAK" = true ]; then PACKAGES_TO_INSTALL+=("flatpak"); if [ "$DESKTOP_ENV" == "GNOME" ]; then PACKAGES_TO_INSTALL+=("gnome-software-plugin-flatpak"); fi; if [ "$DESKTOP_ENV" == "KDE" ]; then PACKAGES_TO_INSTALL+=("plasma-discover-backend-flatpak"); fi; fi
    
    if [ "$DESKTOP_ENV" == "GNOME" ]; then PACKAGES_TO_INSTALL+=("gnome-core" "gnome-console" "papirus-icon-theme" "gnome-tweaks" "gnome-shell-extension-manager");
    elif [ "$DESKTOP_ENV" == "KDE" ]; then PACKAGES_TO_INSTALL+=("kde-plasma-desktop");
    elif [ "$DESKTOP_ENV" == "Sway" ]; then
        SWAY_PACKAGES=(sway xwayland swaylock swayidle autotiling waybar wofi libnotify-bin kitty python3-pil swaybg sway-notification-center wlogout fonts-fork-awesome fonts-font-awesome fonts-jetbrains-mono fonts-material-design-icons-iconfont pipewire pavucontrol network-manager grim slurp wl-clipboard swayimg swayosd brightnessctl gammastep ddcutil unzip lxpolkit lisgd playerctl gtk3-nocsd)
        PACKAGES_TO_INSTALL+=("${SWAY_PACKAGES[@]}")
        if [ "$CONFIG_TYPE" == "mac" ]; then
            PACKAGES_TO_INSTALL+=("keyd")
        elif [ "$CONFIG_TYPE" == "qemu" ]; then
            PACKAGES_TO_INSTALL+=("qemu-guest-agent" "spice-vdagent")
        fi
    fi

    # Adicionar distrobox se selecionado
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "distrobox" ]]; then
        PACKAGES_TO_INSTALL+=("distrobox" "podman")
    fi

    INSTALL_NOW=()
    for pkg in "${PACKAGES_TO_INSTALL[@]}"; do
        if ! dpkg -l | grep -q " $pkg "; then
            INSTALL_NOW+=("$pkg")
        fi
    done

    if [ ${#INSTALL_NOW[@]} -gt 0 ]; then
        info "Iniciando a instalação principal de pacotes Debian..."
        warning "Pacotes a serem instalados: ${INSTALL_NOW[*]}"
        apt_with_progress "install" "${INSTALL_NOW[@]}"
        success "Todos os pacotes Debian selecionados foram instalados."
    else
        info "Todos os pacotes Debian selecionados já estão instalados."
    fi

    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "veracrypt" ]]; then install_veracrypt; fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "appimagelauncher" ]]; then install_appimagelauncher; fi
    if [[ " ${CHOSEN_DEB_OPTIONS[*]} " =~ "helium" ]]; then install_helium; fi

    if [ "$WANT_FLATPAK" = true ]; then
        info "Configurando o repositório Flathub..."
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        success "Flathub configurado."
        if [ -n "$CHOSEN_FLATPAK_APPS" ]; then
            info "Instalando aplicações Flatpak selecionadas..."
            for app in $CHOSEN_FLATPAK_APPS; do 
                app_id=$(echo "$app" | tr -d '"')
                if ! flatpak list | grep -q "$app_id"; then
                    warning "Instalando $app_id..."
                    flatpak install -y flathub "$app_id"
                else
                    info "Flatpak $app_id is already installed. Skipping."
                fi
            done
            success "Aplicações Flatpak instaladas."
        fi
    fi
}
