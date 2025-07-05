#!/bin/bash
# Ubuntu Server Complete Setup - One-liner Installer
# Usage: curl -sSL https://raw.githubusercontent.com/frontlook-admin/UbuntuServerSetupScript/main/install.sh | sudo bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

# Install git if not present
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    apt update &> /dev/null
    apt install -y git &> /dev/null
fi

# Clone and run
REPO_DIR="UbuntuServerSetupScript"
if [[ -d "$REPO_DIR" ]]; then
    rm -rf "$REPO_DIR"
fi

git clone https://github.com/frontlook-admin/UbuntuServerSetupScript.git && \
cd "$REPO_DIR" && \
chmod +x ubuntu-server-complete-setup.sh && \
./ubuntu-server-complete-setup.sh --auto && \
cd .. && \
rm -rf "$REPO_DIR" 