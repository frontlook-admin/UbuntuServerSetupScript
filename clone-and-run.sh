#!/bin/bash

# =============================================================================
# Clone and Run Ubuntu Server Complete Setup Script
# =============================================================================
# Description: This script clones the repository and runs the main setup script
# Author: System Administrator
# Version: 1.0
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Repository information
REPO_URL="https://github.com/frontlook-admin/UbuntuServerSetupScript.git"
REPO_DIR="UbuntuServerSetupScript"
SCRIPT_NAME="ubuntu-server-complete-setup.sh"

# Print functions
print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        print_info "Git not found. Installing Git..."
        if command -v apt &> /dev/null; then
            apt update &> /dev/null
            apt install -y git &> /dev/null
        elif command -v yum &> /dev/null; then
            yum install -y git &> /dev/null
        elif command -v dnf &> /dev/null; then
            dnf install -y git &> /dev/null
        else
            print_error "Could not install Git. Please install Git manually and try again."
            exit 1
        fi
        print_success "Git installed successfully"
    fi
}

# Clean up function
cleanup() {
    print_info "Cleaning up temporary files..."
    if [[ -d "$REPO_DIR" ]]; then
        rm -rf "$REPO_DIR"
        print_success "Temporary files cleaned up"
    fi
}

# Main execution
main() {
    print_header "Ubuntu Server Complete Setup - Clone and Run"
    
    # Check prerequisites
    check_root
    check_git
    
    # Clean up any existing directory
    if [[ -d "$REPO_DIR" ]]; then
        print_warning "Repository directory already exists. Removing..."
        rm -rf "$REPO_DIR"
    fi
    
    # Clone the repository
    print_info "Cloning repository from $REPO_URL..."
    if git clone "$REPO_URL"; then
        print_success "Repository cloned successfully"
    else
        print_error "Failed to clone repository"
        exit 1
    fi
    
    # Change to repository directory
    cd "$REPO_DIR" || {
        print_error "Failed to change to repository directory"
        exit 1
    }
    
    # Make script executable
    print_info "Making script executable..."
    chmod +x "$SCRIPT_NAME"
    
    # Check if script exists
    if [[ ! -f "$SCRIPT_NAME" ]]; then
        print_error "Setup script not found: $SCRIPT_NAME"
        cleanup
        exit 1
    fi
    
    print_success "Setup script is ready to run"
    echo
    
    # Ask user how to proceed
    echo -e "${YELLOW}Choose how to run the setup script:${NC}"
    echo "1) Interactive mode (recommended for first-time users)"
    echo "2) Automatic mode (uses default settings)"
    echo "3) Show help and exit"
    echo "4) Exit without running"
    echo
    
    read -p "Enter your choice (1-4): " -n 1 -r
    echo
    
    case $REPLY in
        1)
            print_info "Running in interactive mode..."
            ./"$SCRIPT_NAME"
            ;;
        2)
            print_info "Running in automatic mode..."
            ./"$SCRIPT_NAME" --auto
            ;;
        3)
            print_info "Showing help..."
            ./"$SCRIPT_NAME" --help
            ;;
        4)
            print_info "Exiting without running setup..."
            cleanup
            exit 0
            ;;
        *)
            print_error "Invalid choice. Exiting..."
            cleanup
            exit 1
            ;;
    esac
    
    # Post-execution cleanup option
    echo
    read -p "Do you want to clean up the cloned repository? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd ..
        cleanup
    else
        print_info "Repository kept at: $(pwd)"
        print_info "You can manually remove it later with: rm -rf $REPO_DIR"
    fi
    
    print_success "Script execution completed!"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --auto         Clone and run in automatic mode"
        echo "  --interactive  Clone and run in interactive mode"
        echo "  --clone-only   Only clone the repository, don't run"
        echo
        echo "This script will:"
        echo "1. Clone the Ubuntu Server Setup repository"
        echo "2. Make the setup script executable"
        echo "3. Run the setup script with chosen options"
        echo "4. Optionally clean up the cloned repository"
        exit 0
        ;;
    --auto)
        check_root
        check_git
        if [[ -d "$REPO_DIR" ]]; then
            rm -rf "$REPO_DIR"
        fi
        git clone "$REPO_URL" && cd "$REPO_DIR" && chmod +x "$SCRIPT_NAME" && ./"$SCRIPT_NAME" --auto
        ;;
    --interactive)
        check_root
        check_git
        if [[ -d "$REPO_DIR" ]]; then
            rm -rf "$REPO_DIR"
        fi
        git clone "$REPO_URL" && cd "$REPO_DIR" && chmod +x "$SCRIPT_NAME" && ./"$SCRIPT_NAME"
        ;;
    --clone-only)
        check_git
        if [[ -d "$REPO_DIR" ]]; then
            rm -rf "$REPO_DIR"
        fi
        git clone "$REPO_URL" && cd "$REPO_DIR" && chmod +x "$SCRIPT_NAME"
        print_success "Repository cloned and script made executable"
        print_info "Run: sudo ./$SCRIPT_NAME"
        ;;
    "")
        main
        ;;
    *)
        print_error "Unknown option: $1"
        print_info "Use --help for usage information"
        exit 1
        ;;
esac 