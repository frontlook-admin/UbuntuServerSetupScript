#!/bin/bash
# Ubuntu Server Complete Setup - One-liner Installer
# Usage: curl -sSL https://raw.githubusercontent.com/frontlook-admin/UbuntuServerSetupScript/main/install.sh | sudo bash

# Color codes for output - Dark theme compatible
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_header "Ubuntu Server Complete Setup - One-liner Installer"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Install git if not present
if ! command -v git &> /dev/null; then
    print_info "Installing Git..."
    apt update &> /dev/null
    apt install -y git &> /dev/null
    print_success "Git installed"
fi

# Clone and run
REPO_DIR="UbuntuServerSetupScript"
if [[ -d "$REPO_DIR" ]]; then
    print_info "Cleaning up existing directory..."
    rm -rf "$REPO_DIR"
fi

print_info "Cloning repository..."
git clone https://github.com/frontlook-admin/UbuntuServerSetupScript.git && \
cd "$REPO_DIR" && \
chmod +x ubuntu-server-complete-setup.sh && \
print_info "Starting automatic installation..." && \
./ubuntu-server-complete-setup.sh --auto && \
cd .. && \
print_info "Cleaning up..." && \
rm -rf "$REPO_DIR" && \
print_success "Installation completed successfully!" 