#!/bin/bash
#==============================================================================
# Auto Configuration Update Script
#
# PURPOSE: Silent configuration update using main.sh --auto-config
#          Automatically detects hardware profile and updates configs
#==============================================================================

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "\033[0;31mERRO:\033[0m Este script precisa ser executado como root (ou com sudo)."
    exit 1
fi

# Get script directory
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Run main.sh in auto-config mode
echo "Starting automatic configuration update..."
exec "$SCRIPT_DIR/main.sh" --auto-config