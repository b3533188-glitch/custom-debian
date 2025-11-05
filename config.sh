#!/bin/bash
#==============================================================================
# Central Configuration File
#
# PURPOSE: Contains all variables and lists to customize the installation
#          without needing to change script logic.
#==============================================================================

# --- Pacotes Essenciais ---
MANDATORY_PACKAGES=(zram-tools doas gufw bc bash-completion build-essential curl wget jq tmux libglib2.0-bin fonts-noto-color-emoji fonts-symbola)

# --- Pacotes Opcionais (Debian) ---
DEB_PKGS_CHECKLIST=(
    "btop" "Monitor de recursos do sistema" OFF
    "fastfetch" "System information tool" OFF
    "neovim" "Editor de texto Neovim" OFF
    "firefox-esr" "Navegador Web Firefox ESR" OFF
    "thunderbird" "Cliente de E-mail Thunderbird" OFF
    "chromium" "Navegador Web Chromium" OFF
    "brave-browser" "Navegador Web Brave" OFF
    "librewolf" "Navegador Web LibreWolf (privacidade)" OFF
    "keepassxc" "KeePassXC password manager" OFF
    "nextcloud-desktop" "Nextcloud sync client" OFF
    "kvm" "Virtualization support (QEMU/KVM)" OFF
    "dnscrypt-proxy" "Resolvedor de DNS criptografado" OFF
    "tor" "Navegador Tor e ferramentas da rede Tor" OFF
    "signal" "Mensageiro Signal Desktop" OFF
    "mullvad-vpn" "Cliente Mullvad VPN" OFF
    "mullvad-browser" "Navegador Mullvad (privacidade)" OFF
    "helium" "Navegador Helium (AppImage - privacidade)" OFF
    "wine" "Camada de compatibilidade Wine para apps Windows" OFF
    "bleachbit" "Limpador de sistema" OFF
    "deluge" "Cliente BitTorrent Deluge (GUI e Daemon)" OFF
    "veracrypt" "VeraCrypt disk encryption (manual installation)" OFF
    "appimagelauncher" "AppImageLauncher (gerenciador de AppImages)" OFF
    "qbittorrent" "Cliente BitTorrent (avançado)" OFF
    "mediainfo-gui" "Media metadata viewer" OFF
    "filezilla" "Graphical FTP/SFTP client" OFF
    "uget" "Gerenciador de downloads gráfico" OFF
    "vlc" "Reprodutor de mídia VLC" OFF
    "libreoffice-writer" "Processador de texto (Writer)" OFF
    "libreoffice-calc" "Editor de planilhas (Calc)" OFF
    "libreoffice-impress" "Programa de apresentações (Impress)" OFF
    "libreoffice-draw" "Programa de desenho vetorial (Draw)" OFF
    "libreoffice-base" "Gerenciador de banco de dados (Base)" OFF
    "libreoffice-math" "Editor de fórmulas matemáticas (Math)" OFF
    "lazygit" "Interface de terminal para Git (TUI)" OFF
    "distrobox" "Containers com integração nativa (Podman)" OFF
)

# --- Gerenciadores de Arquivos ---
FILE_MANAGERS_CHECKLIST=(
    "ranger" "Gerenciador de arquivos Ranger (CLI)" ON
    "thunar" "Gerenciador de arquivos Thunar (GUI)" OFF
)

# --- Aplicações Opcionais (Flatpak) ---
FLATPAK_PKGS_CHECKLIST=(
    "com.valvesoftware.Steam" "Steam (Plataforma de jogos da Valve)" OFF
    "net.lutris.Lutris" "Lutris (Gerenciador de jogos)" OFF
    "com.heroicgameslauncher.hgl" "Heroic Games Launcher (Epic/GOG)" OFF
    "com.usebottles.bottles" "Bottles (Gerenciador de prefixos Wine)" OFF
    "com.vysp3r.ProtonPlus" "ProtonPlus (Gerenciador de Proton-GE)" OFF
    "com.github.k4zmu2a.spacecadetpinball" "Space Cadet Pinball" OFF
    "com.github.tchx84.Flatseal" "Flatseal (Gerenciador de permissões Flatpak)" OFF
)

# --- Configuração de Tema (Sway) ---
LIGHT_THEME="Graphite-blue-Light"
DARK_THEME="Graphite-blue-Dark"
