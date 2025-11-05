#!/bin/bash

# Script para traduzir todas as mensagens para inglês

translate_file() {
    local file="$1"

    # System-updater translations
    sed -i 's/Updating Flatpak metadata.../Updating Flatpak metadata.../g' "$file"
    sed -i 's/Updating configuration:/Updating configuration:/g' "$file"
    sed -i 's/Starting forced full check.../Starting forced full check.../g' "$file"
    sed -i 's/Updating all caches.../Updating all caches.../g' "$file"
    sed -i 's/APT cache updated/APT cache updated/g' "$file"
    sed -i 's/APT cache could not be updated (no doas privileges)/APT cache could not be updated (no doas privileges)/g' "$file"
    sed -i 's/Forced full check completed/Forced full check completed/g' "$file"
    sed -i 's/Starting complete verification.../Starting complete verification.../g' "$file"
    sed -i 's/Installing mandatory package:/Installing mandatory package:/g' "$file"
    sed -i 's/Removing non-mandatory package:/Removing non-mandatory package:/g' "$file"
    sed -i 's/Complete verification finished/Complete verification finished/g' "$file"
    sed -i 's/Applying configuration changes/Applying configuration changes/g' "$file"
    sed -i 's/profile/profile/g' "$file"
    sed -i 's/Repository not found. Performing initial clone.../Repository not found. Performing initial clone.../g' "$file"
    sed -i 's/Repository cloned to/Repository cloned to/g' "$file"

    # Package management
    sed -i 's/Missing packages found:/Missing packages found:/g' "$file"
    sed -i 's/Installing package:/Installing package:/g' "$file"
    sed -i 's/Package .* installed successfully/g' "$file"
    sed -i 's/Failed to install package:/Failed to install package:/g' "$file"
    sed -i 's/All mandatory packages are already installed/All mandatory packages are already installed/g' "$file"
    sed -i 's/All configurations are already up to date/All configurations are already up to date/g' "$file"

    # Status messages
    sed -i 's/System Updated/System Updated/g' "$file"
    sed -i 's/No updates available at the moment/No updates available at the moment/g' "$file"
    sed -i 's/Complete Check/Complete Check/g' "$file"
    sed -i 's/Performing complete system check.../Performing complete system check.../g' "$file"
    sed -i 's/Complete check performed. No updates found/Complete check performed. No updates found/g' "$file"
    sed -i 's/Complete check found .* updates!/g' "$file"
    sed -i 's/Updates Found/Updates Found/g' "$file"

    # Notifications
    sed -i 's/updates available/updates available/g' "$file"
    sed -i 's/Last check:/Last check:/g' "$file"
    sed -i 's/Click to update/Click to update/g' "$file"
    sed -i 's/System updated/System updated/g' "$file"
    sed -i 's/Click to check again/Click to check again/g' "$file"

    # Configuration sync
    sed -i 's/Synchronizing configurations/Synchronizing configurations/g' "$file"
    sed -i 's/Configuration .* updated/g' "$file"
    sed -i 's/Wallpapers updated/Wallpapers updated/g' "$file"
    sed -i 's/Checking systemd services.../Checking systemd services.../g' "$file"
    sed -i 's/Systemd service .* updated/g' "$file"

    echo "Translated: $file"
}

# Find and translate all relevant files
find /home/me/Documents/backup-repositories/debian -type f \( -name "*.sh" -o -name "*.service" -o -name "*.timer" \) -not -path "*/.git/*" | while read -r file; do
    if grep -q "Atualizando\|Instalando\|Removendo\|Configurando\|Sincronizando\|Verificando\|Iniciando" "$file" 2>/dev/null; then
        translate_file "$file"
    fi
done

echo "Translation completed!"