# Debian Post-Installation Script

This repository contains an advanced and modular post-installation script for Debian 13 Trixie (testing-based). The main focus is setting up a productive Linux environment with the Sway window manager (Wayland), but it also supports GNOME and KDE.

## Description

The script automates the installation and configuration of a Debian system, including:

- Automatic hardware detection and optimization application (GPU, SSD, power management)
- Installation of essential and optional packages via apt and Flatpak
- Complete Sway configuration with greetd, waybar, wofi, kitty, ranger and others
- Custom GTK themes and icons
- Systemd services for automatic theme and wallpaper switching
- Auxiliary scripts for browser customization (title bar removal)
- Support for differentiated desktop/notebook configurations

## Prerequisites

- **System**: Freshly installed Debian 13 Trixie (testing)
- **Access**: Root or sudo
- **Internet**: Stable connection for downloads
- **Hardware**: Wayland compatible (recommended for Sway)

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://codeberg.org/Brussels9807/custom-debian.git
   cd custom-debian
   ```

2. **Run the main script**:
   ```bash
   sudo ./main.sh
   ```

The script will:
- Check and install necessary dependencies (whiptail, git, curl, wget)
- Automatically detect the default user
- Present an interactive menu with installation options

## Execution Modes

The script offers three main modes:

### 1. Complete Execution (Default)
- Installation of selected packages
- Hardware optimization application
- Final system configuration (Sway/GNOME/KDE)
- System snapshots creation (if timeshift is installed)

### 2. Packages Only
- Installs only the selected packages
- Skips hardware optimizations and final configurations
- Useful for selective installations

### 3. Configuration Only
- Applies only final configurations
- Assumes packages are already installed
- Useful for reconfiguring existing systems

## Configuration Profiles

The script supports two hardware profiles:

### Mac Profile
- Optimized for MacBook hardware
- US keyboard layout
- Specific touchpad and power configurations
- b43 firmware installation for Broadcom Wi-Fi

### Notebook Profile
- Generic notebook configuration
- Brazilian ABNT2 keyboard layout
- Dual monitor support (HDMI + eDP)
- TLP power management optimizations

## Package Categories

### Core Packages
- **Base**: curl, wget, git, unzip, doas, timeshift
- **Sway**: Complete Wayland desktop environment
- **Audio**: pipewire, pavucontrol, playerctl
- **Graphics**: grim, slurp, brightnessctl, gammastep, ddcutil, playerctl
- **Network**: network-manager, mullvad-vpn

### Optional Packages
- **Development**: docker, code, lazygit, github-cli
- **Virtualization**: qemu-kvm, virt-manager
- **Gaming**: steam, lutris, gamemode
- **Office**: libreoffice, gimp, obs-studio
- **Browsers**: firefox, brave-browser
- **Media**: vlc, audacity
- **Communication**: signal-desktop, discord

## Features

### Automatic Hardware Detection
- **GPU**: Intel, AMD, NVIDIA, and hybrid configurations
- **SSD**: TRIM, swappiness, and I/O scheduler optimizations
- **Power**: TLP for notebooks, thermald for Intel CPUs
- **Networking**: Automatic Broadcom firmware (Mac profile)

### Sway Configuration
- **Window Management**: Autotiling, floating rules, workspaces
- **Input**: Keyboard layouts, touchpad configurations
- **Visual**: Nord color scheme, gaps, transparency
- **Scripts**: Screenshots, media control, theme switching
- **Idle Management**: Screen dimming, locking, suspension

### Security Features
- **Input Validation**: All user inputs are sanitized
- **GPG Verification**: Package integrity checks
- **Privilege Escalation**: Secure sudo usage
- **File Permissions**: Proper ownership and permissions

### Browser Customization
- **Firefox**: arkenfox user.js with privacy enhancements
- **Extensions**: Automatic uBlock Origin and NoScript installation
- **Privacy**: Enhanced tracking protection and fingerprinting resistance

## Directory Structure

```
debian/
├── main.sh                 # Main script
├── lib/                   # Core libraries
│   ├── ui.sh             # User interface functions
│   ├── packages.sh       # Package installation
│   ├── configure.sh      # System configuration
│   └── hardware.sh       # Hardware optimizations
├── config.mac/           # Mac profile configurations
│   ├── sway/            # Sway window manager
│   ├── waybar/          # Status bar
│   ├── kitty/           # Terminal emulator
│   └── wofi/            # Application launcher
├── config.notebook/      # Notebook profile configurations
├── config-common/        # Shared configurations
├── gtk-themes/           # Custom GTK themes
├── fonts/               # JetBrains Mono Nerd Font
└── scripts/             # Utility scripts
```

## Usage Examples

### Interactive Installation
```bash
sudo ./main.sh
# Follow the menu prompts to select packages and configurations
```

### Packages Only
```bash
sudo ./main.sh --packages-only
```

### Configuration Only
```bash
sudo ./main.sh --configure-only
```

### Force Profile
```bash
CONFIG_TYPE=mac sudo ./main.sh
# or
CONFIG_TYPE=notebook sudo ./main.sh
```

## Included Scripts

### System Management
- **backup-configs.sh**: Backup configuration files
- **system-monitor.sh**: System resource monitoring
- **monitor-hotplug.sh**: Automatic external monitor detection

### Sway Scripts
- **screenshot.sh**: Advanced screenshot functionality
- **theme-switcher.sh**: Automatic light/dark theme switching
- **start-idle.sh**: Idle management with screen dimming
- **change-wallpaper.sh**: Dynamic wallpaper rotation

## Customization

### Adding New Packages
Edit `lib/packages.sh` and add your package to the appropriate array:
```bash
DEVELOPMENT_PACKAGES+=(your-package)
```

### Custom Configurations
- Place files in `config-common/` for shared configurations
- Use `config.mac/` or `config.notebook/` for profile-specific settings

### Hardware Optimizations
Modify `lib/hardware.sh` to add custom hardware detection and optimization logic.

## Troubleshooting

### Common Issues
1. **Permission Errors**: Ensure running with sudo
2. **Network Issues**: Check internet connection and DNS
3. **Package Conflicts**: Review selected packages for conflicts
4. **Hardware Issues**: Check Wayland compatibility

### Log Files
- System logs: `/var/log/`
- Sway logs: `~/.local/state/sway/`
- Script logs: Check terminal output

### Support
- Check existing issues on the repository
- Create detailed bug reports with system information
- Include relevant log files and error messages

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly on Debian 13 Trixie
5. Submit a pull request

## License

This project is released under the MIT License. See LICENSE file for details.

## Acknowledgments

- Sway community for excellent documentation
- Debian project for the stable base
- Contributors to all included open-source packages

---

**Note**: This script is designed specifically for Debian 13 Trixie. Using it on other distributions or versions may cause issues.