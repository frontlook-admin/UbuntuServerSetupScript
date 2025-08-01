#!/bin/bash

# =============================================================================
# .NET Web App Deployment Script for Ubuntu
# =============================================================================
# Description: Comprehensive .NET web application deployment with Nginx reverse proxy
# Author: System Administrator
# Version: 1.0
# Compatible with: Ubuntu 18.04+, .NET 6.0+, .NET 8.0+
# =============================================================================

set -e  # Exit on any error

# Color codes for output - Dark theme compatible
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/var/log/dotnet-deployment.log"
BACKUP_DIR="/var/backups/dotnet-apps"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
APPS_ROOT_DIR="/var/www/dotnet-apps"

# Global variables
APP_NAME=""
APP_SOURCE_PATH=""
APP_DESTINATION_PATH=""
APP_PORT=""
APP_SUBDIRECTORY=""
HOSTING_MODE=""
NGINX_SITE_NAME=""
SERVICE_NAME=""
DOTNET_VERSION=""
USE_HTTPS=""
BIND_ADDRESS=""
USE_NGINX=""
SSL_CERT_PATH=""
SSL_KEY_PATH=""
SSL_CERT_REGISTRY="/etc/ssl/dotnet-apps/.cert_registry"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# =============================================================================
# HTTPS CONFIGURATION FUNCTIONS
# =============================================================================

# SSL Certificate Registry Management
register_ssl_certificate() {
    local cert_name="$1"
    local cert_path="$2"
    local key_path="$3"
    local domain="$4"
    local created_date="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Create SSL directory and registry if they don't exist
    mkdir -p "$(dirname "$SSL_CERT_REGISTRY")"
    
    # Add entry to registry
    echo "$cert_name|$cert_path|$key_path|$domain|$created_date" >> "$SSL_CERT_REGISTRY"
    
    print_info "Certificate registered: $cert_name"
}

remove_expired_certificates() {
    local ssl_dir="/etc/ssl/dotnet-apps"
    
    if [[ ! -f "$SSL_CERT_REGISTRY" ]]; then
        return 0
    fi
    
    print_info "Checking for expired certificates..."
    
    # Create temp file for updated registry
    local temp_registry=$(mktemp)
    
    # Read registry and check each certificate
    while IFS='|' read -r cert_name cert_path key_path domain created_date; do
        if [[ -f "$cert_path" ]]; then
            # Check if certificate is expired
            if openssl x509 -in "$cert_path" -noout -checkend 0 &>/dev/null; then
                # Certificate is valid, keep it
                echo "$cert_name|$cert_path|$key_path|$domain|$created_date" >> "$temp_registry"
            else
                # Certificate is expired, remove it
                print_info "Removing expired certificate: $cert_name"
                rm -f "$cert_path" "$key_path" 2>/dev/null || true
            fi
        fi
    done < "$SSL_CERT_REGISTRY"
    
    # Replace registry with updated version
    mv "$temp_registry" "$SSL_CERT_REGISTRY"
}

get_available_certificates() {
    local ssl_dir="/etc/ssl/dotnet-apps"
    
    if [[ ! -f "$SSL_CERT_REGISTRY" ]]; then
        return 0
    fi
    
    # Remove expired certificates first
    remove_expired_certificates
    
    # Return available certificates
    if [[ -f "$SSL_CERT_REGISTRY" && -s "$SSL_CERT_REGISTRY" ]]; then
        cat "$SSL_CERT_REGISTRY"
    fi
}

list_ssl_certificates() {
    print_header "Available SSL Certificates (Non-Expired)"
    
    # Remove expired certificates first
    remove_expired_certificates
    
    local cert_registry_data=$(get_available_certificates)
    
    if [[ -z "$cert_registry_data" ]]; then
        print_info "No SSL certificates found"
        return 0
    fi
    
    local certs_found=0
    
    # List certificates from registry
    echo "$cert_registry_data" | while IFS='|' read -r cert_name cert_path key_path domain created_date; do
        if [[ -f "$cert_path" && -f "$key_path" ]]; then
            echo
            print_info "Certificate: $cert_name"
            echo "  Certificate file: $cert_path"
            echo "  Key file: $key_path"
            echo "  Domain: $domain"
            echo "  Created: $created_date"
            echo "  Expires: $(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null | grep notAfter | sed 's/notAfter=//')"
            echo "  Days remaining: $(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null | grep notAfter | sed 's/notAfter=//' | xargs -I {} date -d {} '+%s' | xargs -I {} expr \( {} - $(date '+%s') \) / 86400)"
            certs_found=$((certs_found + 1))
        fi
    done
    
    local total_certs=$(echo "$cert_registry_data" | wc -l)
    print_info "Found $total_certs valid SSL certificate(s)"
    
    return 0
}

create_ssl_certificate() {
    print_header "Create SSL Certificate"
    
    # Create SSL directory
    local ssl_dir="/etc/ssl/dotnet-apps"
    mkdir -p "$ssl_dir"
    
    # Get certificate name
    read -p "Enter certificate name (alphanumeric, hyphens, underscores only): " cert_name
    
    # Validate certificate name
    if [[ ! "$cert_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Invalid certificate name. Use only letters, numbers, hyphens, and underscores."
        return 1
    fi
    
    if [[ -z "$cert_name" ]]; then
        print_error "Certificate name cannot be empty"
        return 1
    fi
    
    # Check if certificate already exists in registry
    if [[ -f "$SSL_CERT_REGISTRY" ]]; then
        if grep -q "^$cert_name|" "$SSL_CERT_REGISTRY"; then
            print_warning "Certificate '$cert_name' already exists in registry"
            read -p "Overwrite existing certificate? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Certificate creation cancelled"
                return 0
            fi
            
            # Remove existing certificate from registry
            grep -v "^$cert_name|" "$SSL_CERT_REGISTRY" > "${SSL_CERT_REGISTRY}.tmp" && mv "${SSL_CERT_REGISTRY}.tmp" "$SSL_CERT_REGISTRY"
        fi
    fi
    
    # Set certificate paths
    local cert_path="$ssl_dir/${cert_name}.crt"
    local key_path="$ssl_dir/${cert_name}.key"
    
    # Get domain name
    read -p "Enter domain name or IP address [localhost]: " domain
    domain=${domain:-localhost}
    
    # Get certificate validity period
    read -p "Enter certificate validity in days [365]: " validity_days
    validity_days=${validity_days:-365}
    
    # Validate validity days
    if [[ ! "$validity_days" =~ ^[0-9]+$ ]]; then
        print_error "Invalid validity period. Must be a number."
        return 1
    fi
    
    # Create certificate
    print_info "Creating SSL certificate for domain: $domain (valid for $validity_days days)"
    
    if ! openssl req -x509 -newkey rsa:4096 -keyout "$key_path" -out "$cert_path" -days "$validity_days" -nodes -subj "/CN=$domain"; then
        print_error "Failed to create SSL certificate"
        return 1
    fi
    
    # Set proper permissions
    chown www-data:www-data "$cert_path" "$key_path"
    chmod 644 "$cert_path"
    chmod 600 "$key_path"
    
    # Register certificate
    register_ssl_certificate "$cert_name" "$cert_path" "$key_path" "$domain"
    
    print_success "SSL certificate created successfully"
    print_info "Certificate: $cert_path"
    print_info "Private Key: $key_path"
    print_info "Domain: $domain"
    print_info "Valid for: $validity_days days"
    
    return 0
}

remove_ssl_certificate() {
    print_header "Remove SSL Certificate"
    
    # Remove expired certificates first
    remove_expired_certificates
    
    # Get available certificates
    local cert_registry_data=$(get_available_certificates)
    
    if [[ -z "$cert_registry_data" ]]; then
        print_info "No SSL certificates found"
        return 0
    fi
    
    print_info "Available certificates:"
    echo
    
    # Display available certificates with numbers
    local cert_count=0
    echo "$cert_registry_data" | while IFS='|' read -r cert_name cert_path key_path cert_domain created_date; do
        cert_count=$((cert_count + 1))
        
        echo "$cert_count) $cert_name (domain: $cert_domain)"
        echo "   Created: $created_date"
        echo "   Expires: $(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null | grep notAfter | sed 's/notAfter=//')"
        echo "   Certificate: $cert_path"
        echo "   Key: $key_path"
        echo
    done
    
    # Get the actual count
    local total_certs=$(echo "$cert_registry_data" | wc -l)
    
    if [[ $total_certs -eq 0 ]]; then
        print_info "No certificates to remove"
        return 0
    fi
    
    read -p "Select certificate number to remove (1-$total_certs): " -r
    local cert_choice=${REPLY:-0}
    
    if [[ ! "$cert_choice" =~ ^[0-9]+$ ]] || [[ "$cert_choice" -lt 1 ]] || [[ "$cert_choice" -gt "$total_certs" ]]; then
        print_error "Invalid certificate selection"
        return 1
    fi
    
    # Get selected certificate info
    local selected_cert_info=$(echo "$cert_registry_data" | sed -n "${cert_choice}p")
    IFS='|' read -r selected_cert_name selected_cert_path selected_key_path selected_domain selected_created_date <<< "$selected_cert_info"
    
    print_warning "You are about to remove the following certificate:"
    echo "  Name: $selected_cert_name"
    echo "  Domain: $selected_domain"
    echo "  Certificate: $selected_cert_path"
    echo "  Key: $selected_key_path"
    echo "  Created: $selected_created_date"
    echo
    
    read -p "Are you sure you want to remove this certificate? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Certificate removal cancelled"
        return 0
    fi
    
    # Remove certificate files
    if [[ -f "$selected_cert_path" ]]; then
        rm -f "$selected_cert_path"
        print_info "Certificate file removed: $selected_cert_path"
    fi
    
    if [[ -f "$selected_key_path" ]]; then
        rm -f "$selected_key_path"
        print_info "Key file removed: $selected_key_path"
    fi
    
    # Remove from registry
    if [[ -f "$SSL_CERT_REGISTRY" ]]; then
        grep -v "^$selected_cert_name|" "$SSL_CERT_REGISTRY" > "${SSL_CERT_REGISTRY}.tmp" && mv "${SSL_CERT_REGISTRY}.tmp" "$SSL_CERT_REGISTRY"
        print_info "Certificate removed from registry"
    fi
    
    print_success "SSL certificate '$selected_cert_name' removed successfully"
    
    return 0
}

configure_https() {
    local app_name="$1"
    local domain="$2"
    
    print_header "Configuring HTTPS for $app_name"
    
    # Create SSL directory
    local ssl_dir="/etc/ssl/dotnet-apps"
    mkdir -p "$ssl_dir"
    
    # Remove expired certificates first
    remove_expired_certificates
    
    # Get available certificates
    local cert_registry_data=$(get_available_certificates)
    
    echo
    echo "SSL Certificate options:"
    echo "1) Use existing certificate"
    echo "2) Create new certificate"
    echo "3) Cancel HTTPS configuration"
    echo
    
    read -p "Select option (1-3) [1]: " -r
    local choice=${REPLY:-1}
    
    case "$choice" in
        1)
            if [[ -z "$cert_registry_data" ]]; then
                print_error "No existing certificates found"
                return 1
            fi
            
            print_info "Available certificates:"
            echo
            
            # Display available certificates with numbers
            local cert_count=0
            local cert_names=()
            local cert_paths=()
            local key_paths=()
            
            echo "$cert_registry_data" | while IFS='|' read -r cert_name cert_path key_path cert_domain created_date; do
                cert_count=$((cert_count + 1))
                cert_names+=("$cert_name")
                cert_paths+=("$cert_path")
                key_paths+=("$key_path")
                
                echo "$cert_count) $cert_name (domain: $cert_domain)"
                echo "   Created: $created_date"
                echo "   Expires: $(openssl x509 -in "$cert_path" -noout -dates 2>/dev/null | grep notAfter | sed 's/notAfter=//')"
                echo
            done
            
            if [[ $cert_count -eq 0 ]]; then
                print_error "No valid certificates found"
                return 1
            fi
            
            read -p "Select certificate number (1-$cert_count): " -r
            local cert_choice=${REPLY:-1}
            
            if [[ ! "$cert_choice" =~ ^[0-9]+$ ]] || [[ "$cert_choice" -lt 1 ]] || [[ "$cert_choice" -gt "$cert_count" ]]; then
                print_error "Invalid certificate selection"
                return 1
            fi
            
            # Get selected certificate info
            local selected_cert_info=$(echo "$cert_registry_data" | sed -n "${cert_choice}p")
            IFS='|' read -r selected_cert_name selected_cert_path selected_key_path selected_domain selected_created_date <<< "$selected_cert_info"
            
            SSL_CERT_PATH="$selected_cert_path"
            SSL_KEY_PATH="$selected_key_path"
            
            print_success "Selected certificate: $selected_cert_name"
            print_info "Certificate: $SSL_CERT_PATH"
            print_info "Private Key: $SSL_KEY_PATH"
            
            # Ensure proper permissions
            chown www-data:www-data "$SSL_CERT_PATH" "$SSL_KEY_PATH"
            chmod 644 "$SSL_CERT_PATH"
            chmod 600 "$SSL_KEY_PATH"
            
            return 0
            ;;
        2)
            # Get certificate name
            read -p "Enter certificate name for $app_name [${app_name}-cert]: " cert_name
            cert_name=${cert_name:-"${app_name}-cert"}
            
            # Validate certificate name
            if [[ ! "$cert_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                print_error "Invalid certificate name. Use only letters, numbers, hyphens, and underscores."
                return 1
            fi
            
            # Check if certificate already exists in registry
            if [[ -f "$SSL_CERT_REGISTRY" ]]; then
                if grep -q "^$cert_name|" "$SSL_CERT_REGISTRY"; then
                    print_warning "Certificate '$cert_name' already exists in registry"
                    read -p "Overwrite existing certificate? (y/N): " -n 1 -r
                    echo
                    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                        print_info "Certificate creation cancelled"
                        return 1
                    fi
                    
                    # Remove existing certificate from registry
                    grep -v "^$cert_name|" "$SSL_CERT_REGISTRY" > "${SSL_CERT_REGISTRY}.tmp" && mv "${SSL_CERT_REGISTRY}.tmp" "$SSL_CERT_REGISTRY"
                fi
            fi
            
            # Set certificate paths
            SSL_CERT_PATH="$ssl_dir/${cert_name}.crt"
            SSL_KEY_PATH="$ssl_dir/${cert_name}.key"
            
            # Get certificate validity period
            read -p "Enter certificate validity in days [365]: " validity_days
            validity_days=${validity_days:-365}
            
            # Validate validity days
            if [[ ! "$validity_days" =~ ^[0-9]+$ ]]; then
                print_error "Invalid validity period. Must be a number."
                return 1
            fi
            
            # Generate self-signed certificate
            print_info "Generating self-signed SSL certificate for domain: ${domain:-localhost}"
            if ! openssl req -x509 -newkey rsa:4096 -keyout "$SSL_KEY_PATH" -out "$SSL_CERT_PATH" -days "$validity_days" -nodes -subj "/CN=${domain:-localhost}"; then
                print_error "Failed to generate SSL certificate"
                return 1
            fi
            
            # Set proper permissions
            chown www-data:www-data "$SSL_CERT_PATH" "$SSL_KEY_PATH"
            chmod 644 "$SSL_CERT_PATH"
            chmod 600 "$SSL_KEY_PATH"
            
            # Register certificate
            register_ssl_certificate "$cert_name" "$SSL_CERT_PATH" "$SSL_KEY_PATH" "${domain:-localhost}"
            
            print_success "SSL certificate created and registered successfully"
            print_info "Certificate: $SSL_CERT_PATH"
            print_info "Private Key: $SSL_KEY_PATH"
            
            return 0
            ;;
        3)
            print_info "HTTPS configuration cancelled"
            return 1
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

ask_https_configuration() {
    echo
    print_info "HTTPS Configuration"
    echo "1) HTTP only (default, uses nginx reverse proxy)"
    echo "2) HTTPS direct (application serves HTTPS directly)"
    echo
    
    read -p "Select configuration (1-2) [1]: " -r
    local choice=${REPLY:-1}
    
    case "$choice" in
        1)
            USE_HTTPS="false"
            print_info "Selected: HTTP only (nginx reverse proxy)"
            ;;
        2)
            USE_HTTPS="true"
            print_info "Selected: HTTPS direct"
            
            # Ask for domain name
            read -p "Enter domain name or IP address for SSL certificate [$(hostname -I | awk '{print $1}')]: " -r
            local domain=${REPLY:-$(hostname -I | awk '{print $1}')}
            
            # Configure SSL
            if ! configure_https "$APP_NAME" "$domain"; then
                print_error "Failed to configure HTTPS"
                return 1
            fi
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    return 0
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

check_root_privileges() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

validate_app_name() {
    local app_name="$1"
    
    if [[ -z "$app_name" ]]; then
        print_error "App name cannot be empty"
        return 1
    fi
    
    if [[ ! "$app_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "App name can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    return 0
}

validate_port() {
    local port="$1"
    
    if [[ ! "$port" =~ ^[0-9]+$ ]]; then
        print_error "Port must be a number"
        return 1
    fi
    
    if [[ "$port" -lt 1024 ]] || [[ "$port" -gt 65535 ]]; then
        print_error "Port must be between 1024 and 65535"
        return 1
    fi
    
    # Check if port is already in use
    if ss -tuln | grep -q ":$port "; then
        print_error "Port $port is already in use"
        return 1
    fi
    
    return 0
}

validate_source_path() {
    local source_path="$1"
    
    if [[ ! -d "$source_path" ]]; then
        print_error "Source directory does not exist: $source_path"
        return 1
    fi
    
    # Check if it's a .NET application directory
    # Look for various indicators of a .NET application
    local has_dotnet_files=false
    
    # Check for .dll files (traditional .NET deployment)
    if compgen -G "$source_path/*.dll" > /dev/null; then
        has_dotnet_files=true
        print_info "Found .dll files - traditional .NET deployment detected"
    fi
    
    # Check for .exe files
    if compgen -G "$source_path/*.exe" > /dev/null; then
        has_dotnet_files=true
        print_info "Found .exe files"
    fi
    
    # Check for .NET configuration files (indicates .NET application)
    if [[ -f "$source_path/appsettings.json" ]] || [[ -f "$source_path"/*.runtimeconfig.json ]] || [[ -f "$source_path"/*.deps.json ]]; then
        has_dotnet_files=true
        print_info "Found .NET configuration files"
    fi
    
    # Check for Linux executable files (self-contained deployment)
    if [[ "$has_dotnet_files" == "false" ]]; then
        local executable_files=$(find "$source_path" -type f -executable 2>/dev/null)
        if [[ -n "$executable_files" ]]; then
            # Check if any executable might be a .NET application
            for file in $executable_files; do
                if file "$file" 2>/dev/null | grep -q "ELF.*executable"; then
                    local basename_file=$(basename "$file")
                    # Look for related .NET files
                    if [[ -f "$source_path/$basename_file.deps.json" ]] || [[ -f "$source_path/$basename_file.runtimeconfig.json" ]] || [[ -f "$source_path/appsettings.json" ]]; then
                        has_dotnet_files=true
                        print_info "Found self-contained .NET executable: $basename_file"
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [[ "$has_dotnet_files" == "false" ]]; then
        print_error "Directory does not appear to contain a .NET application"
        print_info "Looking for: .dll, .exe files, .NET config files, or self-contained executables"
        print_info "Contents of directory:"
        ls -la "$source_path/"
        return 1
    fi
    
    return 0
}

validate_subdirectory() {
    local subdir="$1"
    
    if [[ -n "$subdir" ]]; then
        if [[ ! "$subdir" =~ ^[a-zA-Z0-9_/-]+$ ]]; then
            print_error "Subdirectory can only contain letters, numbers, hyphens, underscores, and forward slashes"
            return 1
        fi
        
        # Remove leading/trailing slashes
        subdir=$(echo "$subdir" | sed 's|^/||; s|/$||')
        
        if [[ -z "$subdir" ]]; then
            print_error "Subdirectory cannot be empty after removing slashes"
            return 1
        fi
    fi
    
    return 0
}

# =============================================================================
# SYSTEM REQUIREMENTS CHECK
# =============================================================================

check_system_requirements() {
    print_header "Checking System Requirements"
    
    # Check Ubuntu version
    if [[ ! -f /etc/lsb-release ]]; then
        print_error "This script is designed for Ubuntu systems"
        return 1
    fi
    
    source /etc/lsb-release
    print_info "Detected Ubuntu $DISTRIB_RELEASE"
    
    # Check if running as root
    check_root_privileges
    
    # Update package list
    print_info "Updating package list..."
    apt-get update -qq
    
    return 0
}

check_dotnet_installation() {
    print_header "Checking .NET Installation"
    
    if command -v dotnet &> /dev/null; then
        DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
        print_success ".NET SDK/Runtime is installed (version: $DOTNET_VERSION)"
        
        # Check for supported versions
        if [[ "$DOTNET_VERSION" =~ ^[6-8]\. ]]; then
            print_success ".NET version is supported"
            return 0
        else
            print_warning ".NET version may not be fully supported (recommended: 6.0+)"
            return 0
        fi
    else
        print_warning ".NET is not installed"
        return 1
    fi
}

install_dotnet() {
    print_header "Installing .NET SDK/Runtime"
    
    # Install Microsoft package signing key
    print_info "Installing Microsoft package signing key..."
    wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    
    # Update package list
    print_info "Updating package list..."
    apt-get update -qq
    
    # Install .NET SDK (includes runtime)
    print_info "Installing .NET SDK..."
    apt-get install -y dotnet-sdk-8.0
    
    # Verify installation
    if command -v dotnet &> /dev/null; then
        DOTNET_VERSION=$(dotnet --version)
        print_success ".NET SDK installed successfully (version: $DOTNET_VERSION)"
        return 0
    else
        print_error "Failed to install .NET SDK"
        return 1
    fi
}

check_nginx_installation() {
    print_header "Checking Nginx Installation"
    
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | cut -d' ' -f3)
        print_success "Nginx is installed ($nginx_version)"
        
        # Check if Nginx is running
        if systemctl is-active --quiet nginx; then
            print_success "Nginx is running"
        else
            print_info "Nginx is installed but not running"
        fi
        
        return 0
    else
        print_warning "Nginx is not installed"
        return 1
    fi
}

install_nginx() {
    print_header "Installing Nginx"
    
    # Install Nginx
    print_info "Installing Nginx..."
    apt-get install -y nginx
    
    # Start and enable Nginx
    print_info "Starting and enabling Nginx..."
    systemctl start nginx
    systemctl enable nginx
    
    # Verify installation
    if command -v nginx &> /dev/null && systemctl is-active --quiet nginx; then
        print_success "Nginx installed and started successfully"
        return 0
    else
        print_error "Failed to install or start Nginx"
        return 1
    fi
}

check_and_install_dependencies() {
    print_header "Checking and Installing Dependencies"
    
    local missing_deps=()
    
    # Check for required packages
    local required_packages=("curl" "wget" "unzip" "systemctl")
    
    for package in "${required_packages[@]}"; do
        if ! command -v "$package" &> /dev/null; then
            missing_deps+=("$package")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_info "Installing missing dependencies: ${missing_deps[*]}"
        apt-get install -y "${missing_deps[@]}"
    fi
    
    # Check .NET
    if ! check_dotnet_installation; then
        read -p "Would you like to install .NET SDK? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! install_dotnet; then
                print_error "Failed to install .NET SDK"
                return 1
            fi
        else
            print_error ".NET SDK is required for deployment"
            return 1
        fi
    fi
    
    # Check Nginx
    if ! check_nginx_installation; then
        read -p "Would you like to install Nginx? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! install_nginx; then
                print_error "Failed to install Nginx"
                return 1
            fi
        else
            print_error "Nginx is required for reverse proxy setup"
            return 1
        fi
    fi
    
    print_success "All dependencies are installed"
    return 0
}

# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

get_app_configuration() {
    print_header "Application Configuration"
    
    # Get app name
    while true; do
        read -p "Enter application name: " APP_NAME
        if validate_app_name "$APP_NAME"; then
            break
        fi
    done
    
    # Get source path
    while true; do
        read -p "Enter source directory path (where your .NET app files are): " APP_SOURCE_PATH
        # Expand tilde
        APP_SOURCE_PATH="${APP_SOURCE_PATH/#\~/$HOME}"
        if validate_source_path "$APP_SOURCE_PATH"; then
            break
        fi
    done
    
    # Get port
    while true; do
        read -p "Enter port number for the application (5000-5999 recommended): " APP_PORT
        if validate_port "$APP_PORT"; then
            break
        fi
    done
    
    # Get access configuration
    echo
    echo "Choose access configuration:"
    echo "1) Local only (localhost) - requires nginx reverse proxy for external access"
    echo "2) Global access (0.0.0.0) - directly accessible from external networks (including SSH)"
    echo "3) Loopback only (127.0.0.1) - only accessible from this server"
    read -p "Enter choice (1-3): " access_choice
    
    case "$access_choice" in
        1)
            BIND_ADDRESS="localhost"
            USE_NGINX="true"
            ;;
        2)
            BIND_ADDRESS="0.0.0.0"
            USE_NGINX="false"
            ;;
        3)
            BIND_ADDRESS="127.0.0.1"
            USE_NGINX="false"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Get HTTPS configuration
    echo
    echo "Choose protocol:"
    echo "1) HTTP"
    echo "2) HTTPS (SSL/TLS)"
    read -p "Enter choice (1-2): " protocol_choice
    
    case "$protocol_choice" in
        1)
            USE_HTTPS="false"
            ;;
        2)
            USE_HTTPS="true"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Get hosting mode
    echo
    echo "Choose hosting mode:"
    echo "1) Direct hosting (accessible at https://your-domain/)"
    echo "2) Subdirectory hosting (accessible at https://your-domain/subpath/)"
    read -p "Enter choice (1-2): " hosting_choice
    
    case "$hosting_choice" in
        1)
            HOSTING_MODE="direct"
            APP_SUBDIRECTORY=""
            ;;
        2)
            HOSTING_MODE="subdirectory"
            while true; do
                read -p "Enter subdirectory path (e.g., 'myapp' or 'apps/myapp'): " APP_SUBDIRECTORY
                if validate_subdirectory "$APP_SUBDIRECTORY"; then
                    # Clean up the subdirectory path
                    APP_SUBDIRECTORY=$(echo "$APP_SUBDIRECTORY" | sed 's|^/||; s|/$||')
                    break
                fi
            done
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
    
    # Set derived variables
    SERVICE_NAME="dotnet-${APP_NAME}"
    NGINX_SITE_NAME="${APP_NAME}"
    APP_DESTINATION_PATH="${APPS_ROOT_DIR}/${APP_NAME}"
    
    # Configure HTTPS if needed
    if [[ "$USE_HTTPS" == "true" ]]; then
        configure_https "$APP_NAME" "$(hostname -I | awk '{print $1}')"
    fi
    
    # Show configuration summary
    print_info "Configuration Summary:"
    echo "  App Name: $APP_NAME"
    echo "  Source Path: $APP_SOURCE_PATH"
    echo "  Destination Path: $APP_DESTINATION_PATH"
    echo "  Port: $APP_PORT"
    echo "  Bind Address: $BIND_ADDRESS"
    echo "  Protocol: $([ "$USE_HTTPS" == "true" ] && echo "HTTPS" || echo "HTTP")"
    echo "  Hosting Mode: $HOSTING_MODE"
    if [[ -n "$APP_SUBDIRECTORY" ]]; then
        echo "  Subdirectory: /$APP_SUBDIRECTORY"
    fi
    echo "  Service Name: $SERVICE_NAME"
    if [[ "$USE_NGINX" == "true" ]]; then
        echo "  Nginx Site: $NGINX_SITE_NAME"
        echo "  External Access: Requires nginx reverse proxy"
    else
        echo "  External Access: Direct access on port $APP_PORT"
    fi
    
    echo
    read -p "Continue with this configuration? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Configuration cancelled"
        return 1
    fi
    
    return 0
}

# =============================================================================
# DEPLOYMENT FUNCTIONS
# =============================================================================

create_app_directory() {
    print_header "Creating Application Directory"
    
    # Create apps root directory
    mkdir -p "$APPS_ROOT_DIR"
    
    # Create app-specific directory
    if [[ -d "$APP_DESTINATION_PATH" ]]; then
        print_warning "Application directory already exists: $APP_DESTINATION_PATH"
        
        # Ask if backup is needed
        read -p "Do you want to create a backup of the existing application? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Create backup
            local backup_path="${BACKUP_DIR}/${APP_NAME}_backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            
            print_info "Creating backup of existing application..."
            cp -r "$APP_DESTINATION_PATH" "$backup_path"
            print_success "Backup created at: $backup_path"
        else
            print_info "Skipping backup creation"
        fi
        
        # Remove existing directory
        rm -rf "$APP_DESTINATION_PATH"
    fi
    
    mkdir -p "$APP_DESTINATION_PATH"
    print_success "Application directory created: $APP_DESTINATION_PATH"
    
    return 0
}

copy_application_files() {
    print_header "Copying Application Files"
    
    print_info "Copying files from $APP_SOURCE_PATH to $APP_DESTINATION_PATH..."
    
    # Copy all files
    cp -r "$APP_SOURCE_PATH"/* "$APP_DESTINATION_PATH"/
    
    # Set proper permissions
    chown -R www-data:www-data "$APP_DESTINATION_PATH"
    find "$APP_DESTINATION_PATH" -type f -name "*.dll" -exec chmod 644 {} \;
    find "$APP_DESTINATION_PATH" -type f -name "*.exe" -exec chmod 755 {} \;
    find "$APP_DESTINATION_PATH" -type f -name "*.json" -exec chmod 644 {} \;
    
    # Find the main executable
    local main_dll=$(find "$APP_DESTINATION_PATH" -name "*.dll" | head -n 1)
    if [[ -z "$main_dll" ]]; then
        print_error "No .dll files found in the application directory"
        return 1
    fi
    
    print_success "Application files copied successfully"
    print_info "Main executable: $(basename "$main_dll")"
    
    return 0
}

create_systemd_service() {
    print_header "Creating Systemd Service"
    
    # Create .dotnet directory for www-data user to prevent permission issues
    print_info "Setting up .NET CLI directories..."
    if [[ ! -d "/var/www/.dotnet" ]]; then
        mkdir -p "/var/www/.dotnet"
        chown www-data:www-data "/var/www/.dotnet"
        chmod 755 "/var/www/.dotnet"
        print_success "Created .NET CLI directory: /var/www/.dotnet"
    else
        print_info ".NET CLI directory already exists: /var/www/.dotnet"
    fi
    
    # Find the main executable file using sophisticated detection
    local main_executable=""
    local exec_command=""
    
    # First, try to find .dll files (traditional .NET deployment)
    local main_dll=$(find "$APP_DESTINATION_PATH" -name "*.dll" -type f | head -1)
    if [[ -n "$main_dll" ]]; then
        local dll_name=$(basename "$main_dll")
        main_executable="$dll_name"
        exec_command="/usr/bin/dotnet ${APP_DESTINATION_PATH}/${dll_name}"
        print_info "Found .dll file: $dll_name"
    else
        # Look for Linux executable files (self-contained deployment)
        local executable_files=$(find "$APP_DESTINATION_PATH" -type f -executable | grep -E "(^[^/]*$|/[^/]*$)" | head -5)
        
        # Filter for potential .NET executables
        for file in $executable_files; do
            if [[ -f "$file" ]] && file "$file" 2>/dev/null | grep -q "ELF.*executable"; then
                # Check if it's likely a .NET executable by looking for related files
                local basename_file=$(basename "$file")
                if [[ -f "$APP_DESTINATION_PATH/$basename_file.deps.json" ]] || [[ -f "$APP_DESTINATION_PATH/$basename_file.runtimeconfig.json" ]] || [[ -f "$APP_DESTINATION_PATH/appsettings.json" ]]; then
                    main_executable="$basename_file"
                    exec_command="$APP_DESTINATION_PATH/$basename_file"
                    print_info "Found .NET executable: $basename_file"
                    break
                fi
            fi
        done
    fi
    
    # If no executable found, try to find by app name
    if [[ -z "$main_executable" ]]; then
        # Try to find executable with same name as app
        for potential_name in "$APP_NAME" "${APP_NAME,,}" "${APP_NAME^}"; do
            if [[ -f "$APP_DESTINATION_PATH/$potential_name" ]] && [[ -x "$APP_DESTINATION_PATH/$potential_name" ]]; then
                main_executable="$potential_name"
                exec_command="$APP_DESTINATION_PATH/$potential_name"
                print_info "Found executable by name: $potential_name"
                break
            fi
        done
    fi
    
    # If still no executable found, ask user for executable name
    if [[ -z "$main_executable" ]]; then
        print_warning "No .NET executable automatically detected in $APP_DESTINATION_PATH"
        print_info "Available files:"
        ls -la "$APP_DESTINATION_PATH/"
        echo
        
        while true; do
            read -p "Enter the executable filename (without path): " user_executable
            
            if [[ -z "$user_executable" ]]; then
                print_error "Executable name cannot be empty"
                continue
            fi
            
            if [[ -f "$APP_DESTINATION_PATH/$user_executable" ]]; then
                if [[ -x "$APP_DESTINATION_PATH/$user_executable" ]]; then
                    main_executable="$user_executable"
                    exec_command="$APP_DESTINATION_PATH/$user_executable"
                    print_success "Using executable: $user_executable"
                    break
                else
                    print_error "File '$user_executable' is not executable. Making it executable..."
                    chmod +x "$APP_DESTINATION_PATH/$user_executable"
                    main_executable="$user_executable"
                    exec_command="$APP_DESTINATION_PATH/$user_executable"
                    print_success "Using executable: $user_executable"
                    break
                fi
            else
                print_error "File '$user_executable' not found in $APP_DESTINATION_PATH"
                print_info "Available files:"
                ls -1 "$APP_DESTINATION_PATH/"
            fi
        done
    fi
    
    # Create service file
    if [[ "$USE_HTTPS" == "true" ]]; then
        # HTTPS configuration
        cat > "${SYSTEMD_SERVICE_DIR}/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${APP_NAME} .NET Web Application (HTTPS)
After=network.target

[Service]
Type=notify
WorkingDirectory=${APP_DESTINATION_PATH}
ExecStart=${exec_command} --urls=https://${BIND_ADDRESS}:${APP_PORT}
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=${SERVICE_NAME}
User=www-data
Group=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=DOTNET_CLI_HOME=/var/www/.dotnet
Environment=ASPNETCORE_URLS=https://${BIND_ADDRESS}:${APP_PORT}
Environment=ASPNETCORE_HTTPS_PORT=${APP_PORT}
Environment=ASPNETCORE_Kestrel__Certificates__Default__Path=${SSL_CERT_PATH}
Environment=ASPNETCORE_Kestrel__Certificates__Default__KeyPath=${SSL_KEY_PATH}

[Install]
WantedBy=multi-user.target
EOF
    else
        # HTTP configuration (default)
        cat > "${SYSTEMD_SERVICE_DIR}/${SERVICE_NAME}.service" <<EOF
[Unit]
Description=${APP_NAME} .NET Web Application
After=network.target

[Service]
Type=notify
WorkingDirectory=${APP_DESTINATION_PATH}
ExecStart=${exec_command} --urls=http://${BIND_ADDRESS}:${APP_PORT}
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=${SERVICE_NAME}
User=www-data
Group=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=DOTNET_CLI_HOME=/var/www/.dotnet

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start service
    systemctl enable "$SERVICE_NAME"
    systemctl start "$SERVICE_NAME"
    
    # Check service status
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Systemd service created and started successfully"
        return 0
    else
        print_error "Failed to start systemd service"
        print_info "Check service status with: systemctl status $SERVICE_NAME"
        return 1
    fi
}

create_nginx_config() {
    print_header "Creating Nginx Configuration"
    
    # Skip nginx configuration if using HTTPS directly
    if [[ "$USE_HTTPS" == "true" ]]; then
        print_info "Skipping nginx configuration - using direct HTTPS"
        return 0
    fi
    
    local nginx_config_file="${NGINX_CONFIG_DIR}/${NGINX_SITE_NAME}"
    
    if [[ "$HOSTING_MODE" == "direct" ]]; then
        # Direct hosting configuration
        cat > "$nginx_config_file" <<EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF
    else
        # Subdirectory hosting configuration
        cat > "$nginx_config_file" <<EOF
server {
    listen 80;
    server_name _;
    
    location /${APP_SUBDIRECTORY} {
        proxy_pass http://localhost:${APP_PORT};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix /${APP_SUBDIRECTORY};
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
    
    location /${APP_SUBDIRECTORY}/ {
        proxy_pass http://localhost:${APP_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection keep-alive;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Prefix /${APP_SUBDIRECTORY};
        proxy_cache_bypass \$http_upgrade;
        proxy_buffering off;
        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;
    }
}
EOF
    fi
    
    # Enable the site
    ln -sf "$nginx_config_file" "${NGINX_ENABLED_DIR}/${NGINX_SITE_NAME}"
    
    # Test nginx configuration
    if nginx -t; then
        print_success "Nginx configuration created successfully"
        
        # Reload nginx
        systemctl reload nginx
        print_success "Nginx configuration reloaded"
        
        return 0
    else
        print_error "Nginx configuration test failed"
        return 1
    fi
}

# =============================================================================
# VERIFICATION FUNCTIONS
# =============================================================================

verify_deployment() {
    print_header "Verifying Deployment"
    
    # Check if service is running
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Application service is running"
    else
        print_error "Application service is not running"
        print_info "Check logs with: journalctl -u $SERVICE_NAME -f"
        return 1
    fi
    
    # Check if Nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_error "Nginx is not running"
        return 1
    fi
    
    # Test local connection
    print_info "Testing local connection..."
    if curl -s "http://localhost:${APP_PORT}" > /dev/null; then
        print_success "Application is responding on port $APP_PORT"
    else
        print_warning "Application may not be fully started yet"
    fi
    
    # Show access URLs
    print_info "Access URLs:"
    if [[ "$HOSTING_MODE" == "direct" ]]; then
        echo "  Local: http://localhost"
        echo "  Network: http://$(hostname -I | awk '{print $1}')"
    else
        echo "  Local: http://localhost/${APP_SUBDIRECTORY}"
        echo "  Network: http://$(hostname -I | awk '{print $1}')/${APP_SUBDIRECTORY}"
    fi
    
    return 0
}

# =============================================================================
# MANAGEMENT FUNCTIONS
# =============================================================================

show_deployment_status() {
    print_header "Deployment Status"
    
    echo "Application: $APP_NAME"
    echo "Service: $SERVICE_NAME"
    echo "Status: $(systemctl is-active $SERVICE_NAME 2>/dev/null || echo 'inactive')"
    echo "Port: $APP_PORT"
    echo "Path: $APP_DESTINATION_PATH"
    echo "Hosting Mode: $HOSTING_MODE"
    if [[ -n "$APP_SUBDIRECTORY" ]]; then
        echo "Subdirectory: /$APP_SUBDIRECTORY"
    fi
    echo
    
    # Show service logs
    echo "Recent logs:"
    journalctl -u "$SERVICE_NAME" -n 10 --no-pager
}

restart_application() {
    print_header "Restarting Application"
    
    print_info "Stopping application service..."
    systemctl stop "$SERVICE_NAME"
    
    print_info "Starting application service..."
    systemctl start "$SERVICE_NAME"
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        print_success "Application restarted successfully"
    else
        print_error "Failed to restart application"
        return 1
    fi
}

remove_deployment() {
    print_header "Removing Deployment"
    
    read -p "Are you sure you want to remove the deployment for $APP_NAME? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Removal cancelled"
        return 0
    fi
    
    # Stop and disable service
    print_info "Stopping and disabling service..."
    systemctl stop "$SERVICE_NAME" 2>/dev/null || true
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Remove service file
    rm -f "${SYSTEMD_SERVICE_DIR}/${SERVICE_NAME}.service"
    systemctl daemon-reload
    
    # Remove nginx configuration
    rm -f "${NGINX_CONFIG_DIR}/${NGINX_SITE_NAME}"
    rm -f "${NGINX_ENABLED_DIR}/${NGINX_SITE_NAME}"
    systemctl reload nginx
    
    # Ask if backup is needed before removing application files
    if [[ -d "$APP_DESTINATION_PATH" ]]; then
        read -p "Do you want to create a backup before removing the application files? (Y/n): " -r
        local backup_choice=${REPLY:-Y}
        
        if [[ $backup_choice =~ ^[Yy]$ ]]; then
            local backup_path="${BACKUP_DIR}/${APP_NAME}_removal_backup_$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$BACKUP_DIR"
            
            print_info "Creating backup before removal..."
            cp -r "$APP_DESTINATION_PATH" "$backup_path"
            print_success "Backup created at: $backup_path"
        else
            print_info "Skipping backup creation"
        fi
        
        # Remove application files
        rm -rf "$APP_DESTINATION_PATH"
    fi
    
    print_success "Deployment removed successfully"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    clear
    print_header ".NET Web App Deployment Script"
    echo
    echo -e "${WHITE}Please select an option:${NC}"
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}DEPLOYMENT OPTIONS${NC}                                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Deploy new .NET web application                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Check system requirements                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Install dependencies                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}MANAGEMENT OPTIONS${NC}                                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Show deployment status                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Restart application                                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} Remove deployment                                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}SSL CERTIFICATE MANAGEMENT${NC}                                                          ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} List SSL certificates                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Create SSL certificate                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Remove SSL certificate                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${RED}0)${NC} Exit                                                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Enter your choice (0-9): ${NC}\c"
    read choice

    case "$choice" in
        1)
            deploy_application
            ;;
        2)
            check_system_requirements
            check_dotnet_installation
            check_nginx_installation
            ;;
        3)
            check_and_install_dependencies
            ;;
        4)
            if [[ -n "$APP_NAME" ]]; then
                show_deployment_status
            else
                print_error "No application configured"
            fi
            ;;
        5)
            if [[ -n "$APP_NAME" ]]; then
                restart_application
            else
                print_error "No application configured"
            fi
            ;;
        6)
            if [[ -n "$APP_NAME" ]]; then
                remove_deployment
            else
                print_error "No application configured"
            fi
            ;;
        7)
            list_ssl_certificates
            ;;
        8)
            create_ssl_certificate
            ;;
        9)
            remove_ssl_certificate
            ;;
        0)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            sleep 2
            ;;
    esac

    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# MAIN DEPLOYMENT FUNCTION
# =============================================================================

deploy_application() {
    print_header "Starting .NET Web Application Deployment"
    
    # Check system requirements
    if ! check_system_requirements; then
        print_error "System requirements check failed"
        return 1
    fi
    
    # Check and install dependencies
    if ! check_and_install_dependencies; then
        print_error "Dependencies installation failed"
        return 1
    fi
    
    # Get application configuration
    if ! get_app_configuration; then
        print_error "Application configuration failed"
        return 1
    fi
    
    # Create application directory
    if ! create_app_directory; then
        print_error "Failed to create application directory"
        return 1
    fi
    
    # Copy application files
    if ! copy_application_files; then
        print_error "Failed to copy application files"
        return 1
    fi
    
    # Create systemd service
    if ! create_systemd_service; then
        print_error "Failed to create systemd service"
        return 1
    fi
    
    # Create nginx configuration (only if needed)
    if [[ "$USE_NGINX" == "true" ]]; then
        if ! create_nginx_config; then
            print_error "Failed to create nginx configuration"
            return 1
        fi
    else
        print_info "Skipping nginx configuration (direct access mode)"
    fi
    
    # Verify deployment
    if ! verify_deployment; then
        print_error "Deployment verification failed"
        return 1
    fi
    
    print_success "Deployment completed successfully!"
    
    # Show final information
    print_info "Deployment Summary:"
    echo "  Application: $APP_NAME"
    echo "  Service: $SERVICE_NAME"
    echo "  Port: $APP_PORT"
    echo "  Bind Address: $BIND_ADDRESS"
    echo "  Path: $APP_DESTINATION_PATH"
    
    # Show access URLs based on configuration
    if [[ "$USE_HTTPS" == "true" ]]; then
        if [[ "$BIND_ADDRESS" == "0.0.0.0" ]]; then
            echo "  Access URL: https://$(hostname -I | awk '{print $1}'):$APP_PORT"
            echo "  SSH Access: https://YOUR_SERVER_IP:$APP_PORT"
        else
            echo "  Access URL: https://localhost:$APP_PORT (local only)"
            echo "  SSH Access: Not available (local binding only)"
        fi
    elif [[ "$USE_NGINX" == "true" ]]; then
        if [[ "$HOSTING_MODE" == "direct" ]]; then
            echo "  Access URL: http://$(hostname -I | awk '{print $1}') (via nginx)"
        else
            echo "  Access URL: http://$(hostname -I | awk '{print $1}')/${APP_SUBDIRECTORY} (via nginx)"
        fi
        echo "  SSH Access: Use nginx URL above"
    else
        if [[ "$BIND_ADDRESS" == "0.0.0.0" ]]; then
            echo "  Access URL: http://$(hostname -I | awk '{print $1}'):$APP_PORT"
            echo "  SSH Access: http://YOUR_SERVER_IP:$APP_PORT"
        else
            echo "  Access URL: http://localhost:$APP_PORT (local only)"
            echo "  SSH Access: Not available (local binding only)"
        fi
    fi
    
    log_message "Deployment completed successfully for $APP_NAME"
    
    return 0
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_help() {
    echo ".NET Web App Deployment Script"
    echo
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  deploy             Deploy a new .NET web application"
    echo "  check-requirements Check system requirements"
    echo "  install-deps       Install dependencies"
    echo "  status [APP_NAME]  Show deployment status"
    echo "  restart [APP_NAME] Restart application"
    echo "  remove [APP_NAME]  Remove deployment"
    echo
    echo "Options:"
    echo "  -h, --help         Show this help message"
    echo "  -i, --interactive  Run in interactive mode"
    echo "  -v, --verbose      Verbose output"
    echo
    echo "Examples:"
    echo "  $0 deploy"
    echo "  $0 --interactive"
    echo "  $0 status myapp"
    echo "  $0 restart myapp"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Create log file
    mkdir -p /var/log
    touch "$LOG_FILE"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    
    log_message ".NET Web App Deployment Script started"
    
    # Parse command line arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--interactive)
            while true; do
                show_main_menu
            done
            ;;
        deploy)
            deploy_application
            ;;
        check-requirements)
            check_system_requirements
            check_dotnet_installation
            check_nginx_installation
            ;;
        install-deps)
            check_and_install_dependencies
            ;;
        status)
            if [[ -n "$2" ]]; then
                APP_NAME="$2"
                SERVICE_NAME="dotnet-${APP_NAME}"
                APP_DESTINATION_PATH="${APPS_ROOT_DIR}/${APP_NAME}"
                show_deployment_status
            else
                print_error "Usage: $0 status APP_NAME"
                exit 1
            fi
            ;;
        restart)
            if [[ -n "$2" ]]; then
                APP_NAME="$2"
                SERVICE_NAME="dotnet-${APP_NAME}"
                restart_application
            else
                print_error "Usage: $0 restart APP_NAME"
                exit 1
            fi
            ;;
        remove)
            if [[ -n "$2" ]]; then
                APP_NAME="$2"
                SERVICE_NAME="dotnet-${APP_NAME}"
                APP_DESTINATION_PATH="${APPS_ROOT_DIR}/${APP_NAME}"
                NGINX_SITE_NAME="$APP_NAME"
                remove_deployment
            else
                print_error "Usage: $0 remove APP_NAME"
                exit 1
            fi
            ;;
        "")
            # No arguments, show interactive menu
            while true; do
                show_main_menu
            done
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Check if script is run with appropriate privileges
if [[ "${1:-}" != "--help" ]] && [[ "${1:-}" != "-h" ]]; then
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
fi

# Run main function
main "$@" 