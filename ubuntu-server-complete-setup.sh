#!/bin/bash

# =============================================================================
# Ubuntu Server Complete Development Environment Setup Script
# =============================================================================
# Description: Automated installation script for MySQL Server, .NET Runtime/SDK,
#              Git/GitHub configuration, system monitoring tools, and security
# Compatible with: Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, Ubuntu 24.04 LTS
# Author: System Administrator
# Version: 2.0
# Features:
#   - MySQL Server installation and configuration
#   - .NET SDK/Runtime installation
#   - Git and GitHub SSH configuration
#   - System monitoring tools (htop, iotop, glances, netdata, etc.)
#   - Enhanced firewall and security (UFW, fail2ban)
#   - System aliases and monitoring scripts
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

# Configuration variables
MYSQL_ROOT_PASSWORD=""
INSTALL_DOTNET_SDK=true
INSTALL_DOTNET_RUNTIME=true
DOTNET_VERSION="8.0"  # LTS version
MYSQL_VERSION="8.0"
LOG_FILE="/var/log/mysql-dotnet-install.log"
INSTALL_GIT=true
CONFIGURE_GITHUB=true
INSTALL_MONITORING=true
GITHUB_USERNAME=""
GITHUB_EMAIL=""

# .NET Web App Deployment Configuration
DOTNET_DEPLOYMENT_LOG_FILE="/var/log/dotnet-deployment.log"
DOTNET_BACKUP_DIR="/var/backups/dotnet-apps"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
APPS_ROOT_DIR="/var/www/dotnet-apps"
DOTNET_DEPLOYMENT_LOG_FILE="/var/log/dotnet-deployment.log"
DOTNET_BACKUP_DIR="/var/backups/dotnet-apps"
NGINX_CONFIG_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
SYSTEMD_SERVICE_DIR="/etc/systemd/system"
APPS_ROOT_DIR="/var/www/dotnet-apps"

# Global variables for deployment
DOTNET_APP_NAME=""
DOTNET_APP_SOURCE_PATH=""
DOTNET_APP_DESTINATION_PATH=""
DOTNET_APP_PORT=""
DOTNET_APP_SUBDIRECTORY=""
DOTNET_HOSTING_MODE=""
DOTNET_NGINX_SITE_NAME=""
DOTNET_SERVICE_NAME=""
DOTNET_APP_VERSION=""
DOTNET_USE_HTTPS=""
DOTNET_BIND_ADDRESS=""
DOTNET_USE_NGINX=""

# SSL Certificate Management Variables
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

print_highlight() {
    echo -e "${PURPLE}★ $1${NC}"
}

print_step() {
    echo -e "${WHITE}→ $1${NC}"
}

print_completion() {
    echo
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC} ${WHITE}✓ COMPLETED: $1${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

log_message() {
    # Try to create log file in /var/log first, fallback to current directory
    local log_created=false
    
    # Try to create log file in preferred location
    if [[ ! -f "$LOG_FILE" ]]; then
        if mkdir -p /var/log 2>/dev/null && touch "$LOG_FILE" 2>/dev/null; then
            log_created=true
        else
            # Fallback to current directory
            LOG_FILE="./mysql-dotnet-install.log"
            if touch "$LOG_FILE" 2>/dev/null; then
                log_created=true
            else
                # If all else fails, just output to stdout
                echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
                return 0
            fi
        fi
    fi
    
    # Log to file if available
    if [[ -f "$LOG_FILE" ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    fi
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

check_ubuntu() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS version"
        exit 1
    fi

    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        print_error "This script is designed for Ubuntu only"
        exit 1
    fi

    print_info "Detected Ubuntu $VERSION_ID"
}

# =============================================================================
# SYSTEM UPDATE AND PREPARATION
# =============================================================================

update_system() {
    print_header "Updating System Packages"

    log_message "Starting system update"

    # Update package lists
    print_info "Updating package lists..."
    apt update -y >> "$LOG_FILE" 2>&1

    # Upgrade existing packages
    print_info "Upgrading existing packages..."
    apt upgrade -y >> "$LOG_FILE" 2>&1

    # Install essential packages
    print_info "Installing essential packages..."
    apt install -y \
        curl \
        wget \
        apt-transport-https \
        software-properties-common \
        gnupg2 \
        ca-certificates \
        lsb-release \
        unzip \
        git \
        vim \
        nano \
        tree \
        htop \
        iotop \
        netstat-nat \
        net-tools \
        build-essential >> "$LOG_FILE" 2>&1

    print_success "System update completed"
}

# =============================================================================
# MYSQL INSTALLATION
# =============================================================================

install_mysql() {
    print_header "Installing MySQL Server"

    log_message "Starting MySQL installation"

    # Set MySQL root password with user choice
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        echo
        print_info "MySQL Root Password Setup"
        echo "Choose how to set the MySQL root password:"
        echo "  1) Set my own password (recommended for production)"
        echo "  2) Auto-generate a secure random password"
        echo
        echo -e "${WHITE}Select option (1-2): ${NC}\c"
        read -r password_choice
        
        case $password_choice in
            1)
                echo
                print_info "Setting custom MySQL root password..."
                
                # Function to read password securely
                read_mysql_password() {
                    local password=""
                    local confirm_password=""
                    local attempts=0
                    local max_attempts=3
                    
                    while [[ $attempts -lt $max_attempts ]]; do
                        echo -e "${WHITE}Enter MySQL root password (minimum 8 characters): ${NC}\c"
                        read -s password
                        echo
                        
                        # Validate password length
                        if [[ ${#password} -lt 8 ]]; then
                            print_error "Password must be at least 8 characters long"
                            ((attempts++))
                            continue
                        fi
                        
                        # Validate password complexity
                        if [[ ! "$password" =~ [A-Za-z] ]] || [[ ! "$password" =~ [0-9] ]]; then
                            print_warning "For better security, password should contain both letters and numbers"
                            echo -e "${WHITE}Continue with this password? (y/N): ${NC}\c"
                            read -r continue_weak
                            if [[ ! "$continue_weak" =~ ^[Yy]$ ]]; then
                                ((attempts++))
                                continue
                            fi
                        fi
                        
                        echo -e "${WHITE}Confirm MySQL root password: ${NC}\c"
                        read -s confirm_password
                        echo
                        
                        if [[ "$password" == "$confirm_password" ]]; then
                            MYSQL_ROOT_PASSWORD="$password"
                            print_success "MySQL root password set successfully"
                            break
                        else
                            print_error "Passwords do not match"
                            ((attempts++))
                        fi
                    done
                    
                    if [[ $attempts -eq $max_attempts ]]; then
                        print_warning "Maximum password attempts reached. Switching to auto-generated password."
                        return 1
                    fi
                    
                    return 0
                }
                
                # Try to get user password
                if ! read_mysql_password; then
                    print_info "Generating random MySQL root password..."
                    MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
                    print_warning "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
                    print_warning "Please save this password securely!"
                fi
                ;;
            2|*)
                print_info "Generating random MySQL root password..."
                MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
                print_warning "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
                print_warning "Please save this password securely!"
                ;;
        esac
        
        echo
    else
        print_info "Using pre-configured MySQL root password"
    fi

    # Pre-configure MySQL installation
    print_info "Pre-configuring MySQL installation..."
    debconf-set-selections <<< "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD"
    debconf-set-selections <<< "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD"

    # Install MySQL Server
    print_info "Installing MySQL Server $MYSQL_VERSION..."
    apt install -y mysql-server >> "$LOG_FILE" 2>&1

    # Start and enable MySQL service
    print_info "Starting MySQL service..."
    systemctl start mysql
    systemctl enable mysql

    # Secure MySQL installation
    print_info "Securing MySQL installation..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF >> "$LOG_FILE" 2>&1
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
EOF

    # Create MySQL configuration file
    print_info "Creating MySQL configuration with lower_case_table_names for cross-platform compatibility..."
    cat > /etc/mysql/conf.d/custom.cnf <<EOF
[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
# Table names are stored in lowercase for cross-platform compatibility
lower_case_table_names = 1
max_connections = 200
innodb_buffer_pool_size = 256M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF

    # Restart MySQL to apply configuration
    systemctl restart mysql

    print_success "MySQL Server installation completed with lower_case_table_names=1 for cross-platform compatibility"

    # Display MySQL information
    print_info "MySQL Status:"
    systemctl status mysql --no-pager -l
}

# =============================================================================
# MYSQL UNINSTALLATION
# =============================================================================

uninstall_mysql() {
    print_header "MySQL Uninstallation"

    log_message "Starting MySQL uninstallation"

    # Check if MySQL is installed
    if ! command -v mysql &> /dev/null && ! systemctl is-active --quiet mysql 2>/dev/null; then
        print_warning "MySQL does not appear to be installed on this system"
        return 0
    fi

    print_warning "═══════════════════════════════════════════════════════════════════════"
    print_warning "                          ⚠ WARNING ⚠"
    print_warning "═══════════════════════════════════════════════════════════════════════"
    print_warning "This will completely remove MySQL Server from your system!"
    print_warning "This action cannot be undone without a full reinstallation."
    echo
    
    # Display what will be removed
    print_info "The following will be removed:"
    echo "  • MySQL Server service"
    echo "  • MySQL packages and dependencies"
    echo "  • MySQL configuration files"
    echo "  • MySQL log files"
    echo
    
    # Ask about data removal
    print_warning "DATA REMOVAL OPTIONS:"
    echo "  1) Standard uninstall (keep data directories for potential recovery)"
    echo "  2) Complete removal (remove ALL data and databases - DESTRUCTIVE!)"
    echo
    echo -e "${WHITE}Select uninstall type (1-2): ${NC}\c"
    read -r uninstall_type
    
    local remove_data=false
    case $uninstall_type in
        1)
            print_info "Standard uninstall selected - data directories will be preserved"
            remove_data=false
            ;;
        2)
            print_warning "Complete removal selected - ALL DATA WILL BE DELETED!"
            echo
            print_warning "This will permanently delete:"
            echo "  • All databases and tables"
            echo "  • All user data"
            echo "  • MySQL data directory (/var/lib/mysql)"
            echo "  • Any custom databases you have created"
            echo
            echo -e "${RED}Type 'DELETE ALL DATA' to confirm complete removal: ${NC}\c"
            read -r confirm_delete
            
            if [[ "$confirm_delete" == "DELETE ALL DATA" ]]; then
                remove_data=true
                print_warning "Complete data removal confirmed"
            else
                print_info "Data removal not confirmed - switching to standard uninstall"
                remove_data=false
            fi
            ;;
        *)
            print_error "Invalid option. Defaulting to standard uninstall."
            remove_data=false
            ;;
    esac
    
    echo
    echo -e "${RED}Are you absolutely sure you want to proceed with MySQL uninstallation? (y/N): ${NC}\c"
    read -n 1 -r final_confirm
    echo
    
    if [[ ! "$final_confirm" =~ ^[Yy]$ ]]; then
        print_info "MySQL uninstallation cancelled"
        return 0
    fi

    # Backup existing databases if doing standard uninstall
    if [[ "$remove_data" == false ]]; then
        print_info "Creating database backup before uninstallation..."
        local backup_dir="/var/backups/mysql-uninstall-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"
        
        if systemctl is-active --quiet mysql; then
            # Try to backup all databases
            if command -v mysqldump &> /dev/null; then
                print_info "Attempting to backup all databases..."
                mysqldump -u root -p"$MYSQL_ROOT_PASSWORD" --all-databases > "$backup_dir/all-databases.sql" 2>/dev/null || {
                    print_warning "Could not create SQL backup (possibly due to authentication)"
                }
            fi
            
            # Copy data directory
            if [[ -d /var/lib/mysql ]]; then
                print_info "Copying MySQL data directory..."
                cp -r /var/lib/mysql "$backup_dir/mysql-data-backup" 2>/dev/null || {
                    print_warning "Could not copy data directory"
                }
            fi
        fi
        
        print_info "Backup created at: $backup_dir"
    fi

    # Stop MySQL service
    print_info "Stopping MySQL service..."
    systemctl stop mysql 2>/dev/null || true
    systemctl disable mysql 2>/dev/null || true

    # Remove MySQL packages
    print_info "Removing MySQL packages..."
    
    # Stop any remaining MySQL processes
    pkill -f mysql 2>/dev/null || true
    
    # Remove MySQL packages
    apt-get remove --purge -y mysql-server mysql-client mysql-common mysql-server-core-* mysql-client-core-* >> "$LOG_FILE" 2>&1
    
    # Remove additional MySQL packages that might be installed
    apt-get remove --purge -y mysql-* >> "$LOG_FILE" 2>&1
    
    # Clean up package manager
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    apt-get autoclean >> "$LOG_FILE" 2>&1

    # Remove configuration files
    print_info "Removing MySQL configuration files..."
    rm -rf /etc/mysql 2>/dev/null || true
    rm -f /etc/mysql/my.cnf 2>/dev/null || true
    rm -f /etc/mysql/mysql.conf.d/* 2>/dev/null || true
    rm -f /etc/mysql/conf.d/* 2>/dev/null || true

    # Remove log files
    print_info "Removing MySQL log files..."
    rm -rf /var/log/mysql 2>/dev/null || true
    rm -f /var/log/mysql.* 2>/dev/null || true

    # Remove run files
    print_info "Removing MySQL runtime files..."
    rm -rf /var/run/mysqld 2>/dev/null || true
    rm -rf /run/mysqld 2>/dev/null || true

    # Remove data directory if requested
    if [[ "$remove_data" == true ]]; then
        print_warning "Removing MySQL data directory and ALL databases..."
        rm -rf /var/lib/mysql 2>/dev/null || true
        print_warning "All MySQL data has been permanently deleted!"
    else
        print_info "MySQL data directory preserved at: /var/lib/mysql"
        print_info "You can restore data if you reinstall MySQL"
    fi

    # Remove MySQL user and group
    print_info "Removing MySQL user and group..."
    userdel mysql 2>/dev/null || true
    groupdel mysql 2>/dev/null || true

    # Remove any remaining MySQL-related files
    print_info "Cleaning up remaining MySQL files..."
    rm -f /tmp/mysql* 2>/dev/null || true
    rm -f /var/tmp/mysql* 2>/dev/null || true

    # Update package database
    print_info "Updating package database..."
    apt-get update >> "$LOG_FILE" 2>&1

    print_completion "MySQL Server Uninstallation"
    
    if [[ "$remove_data" == true ]]; then
        print_warning "MySQL has been completely removed with all data deleted"
    else
        print_success "MySQL has been uninstalled (data preserved for potential recovery)"
        print_info "Data backup location: /var/backups/mysql-uninstall-*"
        print_info "Original data directory: /var/lib/mysql"
    fi
    
    print_info "To reinstall MySQL, you can run this script and select 'Install MySQL Only'"
    
    log_message "MySQL uninstallation completed (remove_data: $remove_data)"
}

# =============================================================================
# .NET INSTALLATION
# =============================================================================

install_dotnet() {
    print_header "Installing .NET $DOTNET_VERSION"

    log_message "Starting .NET installation"

    # Get Ubuntu version
    . /etc/os-release
    UBUNTU_VERSION=$VERSION_ID

    # Add Microsoft package repository
    print_info "Adding Microsoft package repository..."
    wget -q https://packages.microsoft.com/config/ubuntu/$UBUNTU_VERSION/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb >> "$LOG_FILE" 2>&1
    rm packages-microsoft-prod.deb

    # Update package lists
    apt update -y >> "$LOG_FILE" 2>&1

    # Install .NET SDK (includes runtime)
    if [[ "$INSTALL_DOTNET_SDK" == true ]]; then
        print_info "Installing .NET SDK $DOTNET_VERSION..."
        apt install -y dotnet-sdk-$DOTNET_VERSION >> "$LOG_FILE" 2>&1
        print_success ".NET SDK $DOTNET_VERSION installed"
    fi

    # Install .NET Runtime (if SDK is not installed)
    if [[ "$INSTALL_DOTNET_RUNTIME" == true && "$INSTALL_DOTNET_SDK" != true ]]; then
        print_info "Installing .NET Runtime $DOTNET_VERSION..."
        apt install -y dotnet-runtime-$DOTNET_VERSION >> "$LOG_FILE" 2>&1
        print_success ".NET Runtime $DOTNET_VERSION installed"
    fi

    # Install ASP.NET Core Runtime
    print_info "Installing ASP.NET Core Runtime $DOTNET_VERSION..."
    apt install -y aspnetcore-runtime-$DOTNET_VERSION >> "$LOG_FILE" 2>&1

    # Verify installation
    print_info "Verifying .NET installation..."
    dotnet --version >> "$LOG_FILE" 2>&1
    dotnet --list-sdks >> "$LOG_FILE" 2>&1
    dotnet --list-runtimes >> "$LOG_FILE" 2>&1

    print_success ".NET installation completed"
}

# =============================================================================
# GIT AND GITHUB CONFIGURATION
# =============================================================================

# Install Git system-wide (as root)
install_git_system() {
    print_header "Installing Git System-wide"
    
    log_message "Installing Git system-wide"
    
    # Update package lists
    print_info "Updating package lists..."
    apt update >> "$LOG_FILE" 2>&1
    
    # Install Git system-wide
    print_info "Installing Git..."
    apt install -y git >> "$LOG_FILE" 2>&1
    
    # Install GitHub CLI system-wide (optional)
    read -p "Install GitHub CLI system-wide? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing GitHub CLI system-wide..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
        apt update >> "$LOG_FILE" 2>&1
        apt install -y gh >> "$LOG_FILE" 2>&1
        print_success "GitHub CLI installed system-wide"
    fi
    
    # Create user-specific GitHub configuration script
    create_user_github_config_script
    
    print_success "Git system installation completed"
    print_info "Users can now configure their individual GitHub profiles using: sudo /usr/local/bin/setup-user-github"
}

# Create script for user-specific GitHub configuration
create_user_github_config_script() {
    print_info "Creating user-specific GitHub configuration script..."
    
    cat > /usr/local/bin/setup-user-github <<'EOF'
#!/bin/bash

# =============================================================================
# User-Specific GitHub Configuration Script
# =============================================================================
# This script configures Git and GitHub for individual users
# Run as: sudo /usr/local/bin/setup-user-github <username>
# =============================================================================

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
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

print_header() {
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}$1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if username is provided
if [[ -z "$1" ]]; then
    print_error "Usage: $0 <username>"
    print_info "Example: $0 john"
    exit 1
fi

USERNAME="$1"

# Validate user exists
if ! id "$USERNAME" &>/dev/null; then
    print_error "User '$USERNAME' does not exist"
    exit 1
fi

print_header "GitHub Configuration for User: $USERNAME"

# Get user information
USER_HOME=$(eval echo ~"$USERNAME")
USER_UID=$(id -u "$USERNAME")
USER_GID=$(id -g "$USERNAME")

print_info "User home directory: $USER_HOME"
print_info "User UID: $USER_UID, GID: $USER_GID"

# Get GitHub information
read -p "Enter GitHub username for $USERNAME: " GITHUB_USERNAME
read -p "Enter GitHub email for $USERNAME: " GITHUB_EMAIL

# Validate email format
if [[ ! "$GITHUB_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    print_error "Invalid email format"
    exit 1
fi

print_info "Configuring Git for user $USERNAME..."

# Configure Git for this user (run as the user)
sudo -u "$USERNAME" git config --global user.name "$GITHUB_USERNAME"
sudo -u "$USERNAME" git config --global user.email "$GITHUB_EMAIL"
sudo -u "$USERNAME" git config --global init.defaultBranch main
sudo -u "$USERNAME" git config --global pull.rebase false
sudo -u "$USERNAME" git config --global core.editor vim
sudo -u "$USERNAME" git config --global color.ui auto

print_success "Git configuration completed for $USERNAME"

# Generate SSH key for GitHub
read -p "Generate SSH key for GitHub authentication for $USERNAME? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    SSH_DIR="$USER_HOME/.ssh"
    SSH_KEY_PATH="$SSH_DIR/id_rsa"
    
    # Create .ssh directory if it doesn't exist
    if [[ ! -d "$SSH_DIR" ]]; then
        sudo -u "$USERNAME" mkdir -p "$SSH_DIR"
        chmod 700 "$SSH_DIR"
        chown "$USER_UID:$USER_GID" "$SSH_DIR"
    fi
    
    if [[ ! -f "$SSH_KEY_PATH" ]]; then
        print_info "Generating SSH key for $USERNAME..."
        
        # Generate SSH key as the user
        sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N ""
        
        # Set proper permissions
        chmod 600 "$SSH_KEY_PATH"
        chmod 644 "${SSH_KEY_PATH}.pub"
        chown "$USER_UID:$USER_GID" "$SSH_KEY_PATH" "${SSH_KEY_PATH}.pub"
        
        print_success "SSH key generated successfully for $USERNAME"
        print_warning "Add the following public key to $USERNAME's GitHub account:"
        echo "=====================================>"
        cat "${SSH_KEY_PATH}.pub"
        echo "<====================================="
        
        # Create SSH config for GitHub
        SSH_CONFIG="$SSH_DIR/config"
        if [[ ! -f "$SSH_CONFIG" ]]; then
            sudo -u "$USERNAME" cat > "$SSH_CONFIG" <<SSHEOF
# GitHub configuration
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
    IdentitiesOnly yes
SSHEOF
            chmod 600 "$SSH_CONFIG"
            chown "$USER_UID:$USER_GID" "$SSH_CONFIG"
        fi
        
        print_info "SSH configuration created for $USERNAME"
        read -p "Press Enter after adding the key to GitHub..."
        
        # Test GitHub connection as the user
        print_info "Testing GitHub connection for $USERNAME..."
        if sudo -u "$USERNAME" ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
            print_success "GitHub SSH connection successful for $USERNAME"
        else
            print_warning "GitHub SSH connection test failed - please verify the key was added correctly"
        fi
    else
        print_info "SSH key already exists for $USERNAME at $SSH_KEY_PATH"
    fi
fi

# GitHub CLI authentication (user-specific)
if command -v gh &> /dev/null; then
    read -p "Configure GitHub CLI for $USERNAME? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "GitHub CLI is installed system-wide"
        print_info "User $USERNAME should run: gh auth login"
        print_warning "Note: Each user must authenticate GitHub CLI individually"
    fi
fi

# Create user-specific aliases
print_info "Creating Git aliases for $USERNAME..."
sudo -u "$USERNAME" git config --global alias.st status
sudo -u "$USERNAME" git config --global alias.co checkout
sudo -u "$USERNAME" git config --global alias.br branch
sudo -u "$USERNAME" git config --global alias.ci commit
sudo -u "$USERNAME" git config --global alias.lg "log --oneline --graph --decorate"

print_success "GitHub configuration completed for user: $USERNAME"
print_info "Configuration files created in: $USER_HOME/.gitconfig and $USER_HOME/.ssh/"
print_warning "Security: Only $USERNAME has access to their GitHub configuration"

EOF

    chmod +x /usr/local/bin/setup-user-github
    print_success "User-specific GitHub configuration script created"
}

# Main Git and GitHub configuration function
configure_git_github() {
    print_header "Git and GitHub Configuration"
    
    # Check if Git should be configured
    if [[ "$INSTALL_GIT" != true ]]; then
        print_info "Git installation skipped"
        return 0
    fi
    
    # Install Git system-wide
    install_git_system
    
    # Ask if admin wants to configure GitHub for a user right now
    read -p "Configure GitHub for a specific user now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter username to configure GitHub for: " SETUP_USERNAME
        if id "$SETUP_USERNAME" &>/dev/null; then
            /usr/local/bin/setup-user-github "$SETUP_USERNAME"
        else
            print_warning "User '$SETUP_USERNAME' does not exist. You can configure GitHub later using:"
            print_info "sudo /usr/local/bin/setup-user-github <username>"
        fi
    else
        print_info "You can configure GitHub for users later using:"
        print_info "sudo /usr/local/bin/setup-user-github <username>"
    fi
    
    print_success "Git and GitHub configuration completed"
}

# =============================================================================
# SYSTEM MONITORING TOOLS
# =============================================================================

install_monitoring_tools() {
    print_header "Installing System Monitoring Tools"

    log_message "Installing system monitoring tools"

    # Install additional monitoring tools
    print_info "Installing advanced monitoring tools..."
    apt install -y \
        htop \
        iotop \
        nmon \
        sysstat \
        nethogs \
        iftop \
        tcptrack \
        bmon \
        vnstat \
        glances \
        ncdu \
        dstat \
        lsof \
        strace \
        tcpdump \
        wireshark-common \
        speedtest-cli >> "$LOG_FILE" 2>&1

    # Install and configure Netdata (lightweight monitoring)
    read -p "Install Netdata real-time monitoring? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing Netdata..."
        bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait >> "$LOG_FILE" 2>&1
        print_success "Netdata installed - accessible at http://localhost:19999"
    fi

    # Configure vnstat for network monitoring
    print_info "Configuring vnstat for network monitoring..."
    systemctl enable vnstat
    systemctl start vnstat

    # Create monitoring aliases
    print_info "Creating useful monitoring aliases..."
    cat >> /root/.bashrc <<EOF

# System Monitoring Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Monitoring aliases
alias ports='netstat -tulanp'
alias listening='lsof -i'
alias processes='ps auxf'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'
alias cpuinfo='lscpu'
alias meminfo='cat /proc/meminfo'
alias diskusage='df -h'
alias diskusage_sorted='df -h | sort -rn -k 5'
alias networktop='nethogs'
alias iotop='iotop -o'
alias systop='glances'
alias temp='sensors'
alias myip='curl ipinfo.io/ip'
alias speedtest='speedtest-cli'

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
EOF

    # Install sensors for temperature monitoring
    print_info "Installing temperature monitoring..."
    apt install -y lm-sensors >> "$LOG_FILE" 2>&1
    sensors-detect --auto >> "$LOG_FILE" 2>&1

    # Create system monitoring script
    print_info "Creating system monitoring script..."
    cat > /usr/local/bin/sysmon <<'EOF'
#!/bin/bash

echo "=== System Monitoring Summary ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo ""

echo "=== CPU Usage ==="
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print "CPU Usage: " 100 - $1 "%"}'

echo ""
echo "=== Memory Usage ==="
free -h

echo ""
echo "=== Disk Usage ==="
df -h | grep -vE '^Filesystem|tmpfs|cdrom'

echo ""
echo "=== Network Usage ==="
vnstat -i $(ip route | grep default | awk '{print $5}' | head -1)

echo ""
echo "=== Top Processes by CPU ==="
ps aux --sort=-%cpu | head -6

echo ""
echo "=== Top Processes by Memory ==="
ps aux --sort=-%mem | head -6

echo ""
echo "=== Network Connections ==="
netstat -tuln | grep LISTEN | wc -l
echo "Listening ports: $(netstat -tuln | grep LISTEN | wc -l)"

echo ""
echo "=== System Load ==="
cat /proc/loadavg
EOF

    chmod +x /usr/local/bin/sysmon

    print_success "System monitoring tools installation completed"
    print_info "Use 'sysmon' command for quick system overview"
    print_info "Use 'glances' for real-time system monitoring"
}

# =============================================================================
# ENHANCED FIREWALL CONFIGURATION
# =============================================================================

configure_firewall() {
    print_header "Configuring Enhanced Firewall"

    log_message "Configuring enhanced firewall rules"

    # Install UFW if not installed
    if ! command -v ufw &> /dev/null; then
        print_info "Installing UFW firewall..."
        apt install -y ufw >> "$LOG_FILE" 2>&1
    fi

    # Install fail2ban for intrusion prevention
    print_info "Installing fail2ban for intrusion prevention..."
    apt install -y fail2ban >> "$LOG_FILE" 2>&1

    # Configure UFW rules
    print_info "Configuring firewall rules..."
    ufw --force enable >> "$LOG_FILE" 2>&1
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH (Port 22)
    print_info "Allowing SSH (Port 22)..."
    ufw allow ssh >> "$LOG_FILE" 2>&1

    # Allow HTTP (Port 80)
    print_info "Allowing HTTP (Port 80)..."
    ufw allow 80/tcp >> "$LOG_FILE" 2>&1

    # Allow HTTPS (Port 443)
    print_info "Allowing HTTPS (Port 443)..."
    ufw allow 443/tcp >> "$LOG_FILE" 2>&1

    # Allow HTTPS range (Ports 4430-4439)
    print_info "Allowing HTTPS range (Ports 4430-4439)..."
    ufw allow 4430:4439/tcp >> "$LOG_FILE" 2>&1

    # Allow Netdata monitoring (Port 19999)
    print_info "Allowing Netdata monitoring (Port 19999)..."
    ufw allow 19999/tcp >> "$LOG_FILE" 2>&1

    # Allow MySQL (Port 3306) for backups and remote operations
    print_info "Allowing MySQL (Port 3306) for backups and remote operations..."
    ufw allow 3306/tcp >> "$LOG_FILE" 2>&1

    # Configure fail2ban
    print_info "Configuring fail2ban..."
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log

[apache-auth]
enabled = true
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log

[apache-noscript]
enabled = true
port = http,https
filter = apache-noscript
logpath = /var/log/apache2/error.log

[apache-overflows]
enabled = true
port = http,https
filter = apache-overflows
logpath = /var/log/apache2/error.log
EOF

    # Start and enable fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban

    # Configure additional security rules
    print_info "Configuring additional security rules..."
    
    # Rate limiting for SSH
    ufw limit ssh >> "$LOG_FILE" 2>&1
    
    # Block common attack ports
    ufw deny 23/tcp >> "$LOG_FILE" 2>&1    # Telnet
    ufw deny 135/tcp >> "$LOG_FILE" 2>&1   # RPC
    ufw deny 139/tcp >> "$LOG_FILE" 2>&1   # NetBIOS
    ufw deny 445/tcp >> "$LOG_FILE" 2>&1   # SMB

    print_success "Enhanced firewall configuration completed"

    # Display UFW status
    print_info "Firewall Status:"
    ufw status verbose
    
    print_info "Fail2ban Status:"
    systemctl status fail2ban --no-pager -l
}

# =============================================================================
# POST-INSTALLATION CONFIGURATION
# =============================================================================

create_service_user() {
    print_header "Creating Service User"

    # Create a dedicated user for running .NET applications
    if ! id "dotnetapp" &>/dev/null; then
        print_info "Creating dotnetapp user..."
        useradd -r -s /bin/false -d /opt/dotnetapp dotnetapp
        mkdir -p /opt/dotnetapp
        chown dotnetapp:dotnetapp /opt/dotnetapp
        print_success "Service user 'dotnetapp' created"
    else
        print_info "Service user 'dotnetapp' already exists"
    fi
}

create_database_user() {
    print_header "Creating Database User"

    read -p "Create a database user for your application? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter database username: " DB_USER
        read -s -p "Enter database password: " DB_PASSWORD
        echo
        read -p "Enter database name: " DB_NAME

        print_info "Creating database user and database..."
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<EOF >> "$LOG_FILE" 2>&1
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
        print_success "Database user '$DB_USER' and database '$DB_NAME' created"
    fi
}

# =============================================================================
# SYSTEMD SERVICE TEMPLATE
# =============================================================================

create_systemd_template() {
    print_header "Creating Systemd Service Template"

    cat > /etc/systemd/system/dotnet-app.service.template <<EOF
[Unit]
Description=.NET Application
After=network.target

[Service]
Type=notify
# Change this to your application path
ExecStart=/usr/bin/dotnet /opt/dotnetapp/YourApp.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dotnet-app
User=dotnetapp
Group=dotnetapp
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/dotnetapp
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF

    print_success "Systemd service template created at /etc/systemd/system/dotnet-app.service.template"
}

# =============================================================================
# SYSTEM INFORMATION
# =============================================================================

display_system_info() {
    print_header "Installation Summary"

    echo -e "${GREEN}Installation completed successfully!${NC}"
    echo
    echo "System Information:"
    echo "==================="
    echo "OS: $(lsb_release -ds)"
    echo "Kernel: $(uname -r)"
    echo "MySQL Version: $(mysql --version)"
    echo ".NET Version: $(dotnet --version)"
    if command -v git &> /dev/null; then
        echo "Git Version: $(git --version)"
    fi
    echo
    echo "Services Status:"
    echo "================"
    systemctl is-active mysql && echo "MySQL: Running" || echo "MySQL: Not Running"
    if systemctl is-active --quiet fail2ban; then
        echo "Fail2ban: Running"
    fi
    if systemctl is-active --quiet vnstat; then
        echo "VnStat: Running"
    fi
    if systemctl is-active --quiet netdata; then
        echo "Netdata: Running (http://localhost:19999)"
    fi
    echo
    echo "MySQL Information:"
    echo "=================="
    echo "Root Password: $MYSQL_ROOT_PASSWORD"
    echo "Configuration: /etc/mysql/conf.d/custom.cnf"
    echo "Log File: /var/log/mysql/error.log"
    echo "Table Names: Configured with lower_case_table_names=1 for cross-platform compatibility"
    echo
    echo ".NET Information:"
    echo "================="
    echo "Installed SDKs:"
    dotnet --list-sdks
    echo
    echo "Installed Runtimes:"
    dotnet --list-runtimes
    echo
    if [[ "$CONFIGURE_GITHUB" == true ]]; then
        echo "Git Configuration:"
        echo "=================="
        echo "Git: Installed system-wide"
        if command -v gh &> /dev/null; then
            echo "GitHub CLI: Installed system-wide"
        fi
        echo "User Configuration: Use 'sudo /usr/local/bin/setup-user-github <username>'"
        echo "Security: Each user has isolated GitHub configuration"
        echo
    fi
    echo "Monitoring Tools:"
    echo "================="
    if [[ "$INSTALL_MONITORING" == true ]]; then
        echo "System monitoring tools installed:"
        echo "- htop, iotop, nmon, sysstat"
        echo "- nethogs, iftop, tcptrack, bmon"
        echo "- vnstat, glances, ncdu, dstat"
        echo "- Custom aliases added to /root/.bashrc"
        echo "- System monitoring script: /usr/local/bin/sysmon"
        echo "- Temperature monitoring: sensors"
        echo ""
        echo "Quick Commands:"
        echo "- 'sysmon' - System overview"
        echo "- 'glances' - Real-time monitoring"
        echo "- 'htop' - Process monitor"
        echo "- 'iotop' - I/O monitor"
        echo "- 'nethogs' - Network monitor"
    fi
    echo
    echo "Security:"
    echo "========="
    echo "UFW Firewall: $(ufw status | head -1)"
    echo "Fail2ban: Installed and configured"
    echo "SSH rate limiting: Enabled"
    echo "Common attack ports: Blocked"
    echo ""
    echo "Automatically Configured Firewall Ports:"
    echo "  • Port 22 (SSH) - Enabled with rate limiting"
    echo "  • Port 80 (HTTP) - Enabled"
    echo "  • Port 443 (HTTPS) - Enabled"
    echo "  • Ports 4430-4439 (HTTPS Range) - Enabled"
    echo "  • Port 3306 (MySQL) - Enabled for backups and remote operations"
    echo "  • Port 19999 (Netdata Monitoring) - Enabled"
    echo
    echo "Important Files:"
    echo "================"
    echo "Installation Log: $LOG_FILE"
    echo "Systemd Template: /etc/systemd/system/dotnet-app.service.template"
    echo "Fail2ban Config: /etc/fail2ban/jail.local"
    echo "Firewall Rules: ufw status verbose"
    echo
    echo "Next Steps:"
    echo "==========="
    echo "1. Secure your MySQL installation further if needed"
    echo "2. Configure your .NET application"
    echo "3. Set up SSL certificates for HTTPS"
    echo "4. Configure backup strategies"
    echo "5. Monitor system performance with installed tools"
    if [[ "$CONFIGURE_GITHUB" == true ]]; then
        echo "6. Configure GitHub for users: sudo /usr/local/bin/setup-user-github <username>"
        if command -v gh &> /dev/null; then
            echo "7. Users authenticate GitHub CLI individually: gh auth login"
        fi
    fi
    echo "8. Review firewall rules: ufw status verbose"
    echo "9. Monitor security logs: fail2ban-client status"
    echo "10. Secure MySQL remote access (Port 3306 is open):"
    echo "    - Consider IP restrictions: ufw delete allow 3306/tcp && ufw allow from YOUR_IP to any port 3306"
    echo "    - Use strong passwords for all MySQL accounts"
    echo "    - Create limited privilege users for backups"
}

# =============================================================================
# INTERACTIVE CONFIGURATION
# =============================================================================

interactive_config() {
    print_header "Interactive Configuration"

    # MySQL password configuration
    read -p "Set custom MySQL root password? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local password_attempts=0
        local max_attempts=3
        
        while [[ $password_attempts -lt $max_attempts ]]; do
            read -s -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
            echo
            read -s -p "Confirm MySQL root password: " MYSQL_ROOT_PASSWORD_CONFIRM
            echo
            
            if [[ "$MYSQL_ROOT_PASSWORD" == "$MYSQL_ROOT_PASSWORD_CONFIRM" ]]; then
                print_success "Password confirmed successfully"
                break
            else
                ((password_attempts++))
                if [[ $password_attempts -lt $max_attempts ]]; then
                    print_error "Passwords do not match! Attempt $password_attempts/$max_attempts"
                    print_info "Please try again..."
                else
                    print_error "Maximum password attempts reached. Using auto-generated password."
                    MYSQL_ROOT_PASSWORD=""
                fi
            fi
        done
    fi

    # .NET configuration
    read -p "Install .NET SDK? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_DOTNET_SDK=true
    else
        INSTALL_DOTNET_SDK=false
    fi

    # .NET version selection
    echo "Select .NET version:"
    echo "1) .NET 8.0 (LTS)"
    echo "2) .NET 7.0"
    echo "3) .NET 6.0 (LTS)"
    read -p "Choose (1-3): " -n 1 -r
    echo
    case $REPLY in
        1) DOTNET_VERSION="8.0" ;;
        2) DOTNET_VERSION="7.0" ;;
        3) DOTNET_VERSION="6.0" ;;
        *) DOTNET_VERSION="8.0" ;;
    esac

    # Git and GitHub configuration
    read -p "Configure Git and GitHub? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CONFIGURE_GITHUB=true
        read -p "Enter GitHub username: " GITHUB_USERNAME
        read -p "Enter GitHub email: " GITHUB_EMAIL
    else
        CONFIGURE_GITHUB=false
    fi

    # System monitoring tools
    read -p "Install system monitoring tools? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        INSTALL_MONITORING=true
    else
        INSTALL_MONITORING=false
    fi

    print_info "Configuration completed"
    return 0
}

# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

main() {
    print_header "MySQL and .NET Installation Script"
    print_info "Main function started successfully"

    # Create log file
    mkdir -p /var/log
    touch "$LOG_FILE"

    log_message "Starting installation process"

    # Pre-installation checks
    print_info "Performing pre-installation checks..."
    check_root
    check_ubuntu
    print_success "Pre-installation checks completed"

    # Interactive configuration
    print_info "Starting interactive configuration..."
    interactive_config
    print_success "Interactive configuration completed"

    # Installation steps
    print_info "Starting system installation steps..."
    update_system
    install_mysql
    install_dotnet
    print_success "Core installation steps completed"
    
    # Configure Git and GitHub if requested
    if [[ "$CONFIGURE_GITHUB" == true ]]; then
        print_info "Configuring Git and GitHub..."
        configure_git_github
        print_success "Git and GitHub configuration completed"
    fi
    
    # Install monitoring tools if requested
    if [[ "$INSTALL_MONITORING" == true ]]; then
        print_info "Installing monitoring tools..."
        install_monitoring_tools
        print_success "Monitoring tools installation completed"
    fi
    
    print_info "Configuring system security and services..."
    configure_firewall
    create_service_user
    create_database_user
    create_systemd_template
    print_success "System configuration completed"

    # Post-installation
    display_system_info

    log_message "Installation process completed successfully"

    print_success "Installation completed! Please reboot the system to ensure all changes take effect."
    
    return 0
}

# =============================================================================
# INTEGRATED SCRIPT FUNCTIONS
# =============================================================================

# Function to make scripts executable
make_scripts_executable() {
    print_header "Making Scripts Executable"
    
    log_message "Making scripts executable in current directory"
    
    local script_extensions=("sh" "bash" "py" "pl" "rb" "js" "php")
    local processed_count=0
    local error_count=0
    
    for file in *; do
        if [[ -f "$file" ]]; then
            local extension="${file##*.}"
            local is_script=false
            
            # Check if file has a script extension
            for ext in "${script_extensions[@]}"; do
                if [[ "$extension" == "$ext" ]]; then
                    is_script=true
                    break
                fi
            done
            
            # Check shebang line for files without extension
            if [[ "$is_script" == false && -r "$file" ]]; then
                local first_line=$(head -n 1 "$file" 2>/dev/null)
                if [[ "$first_line" =~ ^#! ]]; then
                    is_script=true
                fi
            fi
            
            if [[ "$is_script" == true ]]; then
                if [[ ! -x "$file" ]]; then
                    print_info "Making $file executable..."
                    if chmod +x "$file"; then
                        ((processed_count++))
                        print_success "Made $file executable"
                    else
                        ((error_count++))
                        print_error "Failed to make $file executable"
                    fi
                else
                    print_info "$file is already executable"
                fi
            fi
        fi
    done
    
    print_success "Processed $processed_count script files"
    if [[ $error_count -gt 0 ]]; then
        print_warning "Failed to process $error_count files"
    fi
    print_info "make_scripts_executable function completed successfully"
    
    return 0
}

# Function to run Ubuntu user management
run_ubuntu_user_manager() {
    print_header "Ubuntu User Management"
    
    if [[ -f "ubuntu-user-manager.sh" ]]; then
        print_info "Running Ubuntu User Manager..."
        if [[ -x "ubuntu-user-manager.sh" ]]; then
            ./ubuntu-user-manager.sh "$@"
        else
            chmod +x ubuntu-user-manager.sh
            ./ubuntu-user-manager.sh "$@"
        fi
    else
        print_error "ubuntu-user-manager.sh not found in current directory"
        exit 1
    fi
}

# Function to run MySQL administration toolkit
run_mysql_admin_toolkit() {
    print_header "MySQL Administration Toolkit"
    
    if [[ -f "mysql-admin-toolkit.sh" ]]; then
        print_info "Running MySQL Administration Toolkit..."
        if [[ -x "mysql-admin-toolkit.sh" ]]; then
            ./mysql-admin-toolkit.sh "$@"
        else
            chmod +x mysql-admin-toolkit.sh
            ./mysql-admin-toolkit.sh "$@"
        fi
    else
        print_error "mysql-admin-toolkit.sh not found in current directory"
        exit 1
    fi
}

# Function to run FTP user management
run_ftp_user_manager() {
    print_header "FTP User Management"
    
    if [[ -f "ftp-user-manager.sh" ]]; then
        print_info "Running FTP User Manager..."
        if [[ -x "ftp-user-manager.sh" ]]; then
            ./ftp-user-manager.sh "$@"
        else
            chmod +x ftp-user-manager.sh
            ./ftp-user-manager.sh "$@"
        fi
    else
        print_error "ftp-user-manager.sh not found in current directory"
        exit 1
    fi
}

# Function to show user management menu
show_user_management_menu() {
    while true; do
        clear
        print_header "User Management Menu"
        echo
        echo -e "${WHITE}Available User Management Options:${NC}"
        echo
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${PURPLE}USER MANAGEMENT OPTIONS${NC}                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Ubuntu System User Management                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} MySQL User Management                                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} FTP User Management                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}SCRIPT MANAGEMENT${NC}                                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Make Scripts Executable                                                              ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}NAVIGATION${NC}                                                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}5)${NC} Return to Main Menu                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${RED}6)${NC} Exit                                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Select option (1-6): ${NC}\c"
        read choice
        
        case $choice in
            1)
                print_info "Starting Ubuntu System User Management..."
                run_ubuntu_user_manager
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            2)
                print_info "Starting MySQL Administration Toolkit..."
                run_mysql_admin_toolkit
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            3)
                print_info "Starting FTP User Management..."
                run_ftp_user_manager
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            4)
                print_info "Making Scripts Executable..."
                make_scripts_executable
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            5)
                print_info "Returning to Main Menu..."
                return 0
                ;;
            6)
                print_info "Exiting User Management..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 1-6."
                sleep 2
                ;;
        esac
    done
}

# Function to run all available scripts
run_all_scripts() {
    print_header "Running All Available Scripts"
    
    # First make all scripts executable
    make_scripts_executable
    
    # Run main installation
    main
    
    # Offer to run user management
    echo
    read -p "Would you like to run user management tools? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        show_user_management_menu
    fi
}

# =============================================================================
# .NET WEB APP DEPLOYMENT FUNCTIONS
# =============================================================================

# .NET Web App Deployment utility functions
dotnet_log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$DOTNET_DEPLOYMENT_LOG_FILE"
}

# Validation functions for .NET deployment
validate_dotnet_app_name() {
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

validate_dotnet_port() {
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

validate_dotnet_source_path() {
    local source_path="$1"
    
    if [[ ! -d "$source_path" ]]; then
        print_error "Source directory does not exist: $source_path"
        return 1
    fi
    
    # Check if it's a .NET application directory
    if [[ ! -f "$source_path"/*.dll ]] && [[ ! -f "$source_path"/*.exe ]]; then
        print_error "Directory does not appear to contain a .NET application (no .dll or .exe files found)"
        return 1
    fi
    
    return 0
}

validate_dotnet_subdirectory() {
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

# Configure HTTPS for .NET application deployment
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
            DOTNET_USE_HTTPS="false"
            DOTNET_USE_NGINX="true"
            DOTNET_BIND_ADDRESS="localhost"
            print_info "Selected: HTTP only (nginx reverse proxy)"
            ;;
        2)
            DOTNET_USE_HTTPS="true"
            DOTNET_USE_NGINX="false"
            DOTNET_BIND_ADDRESS="0.0.0.0"
            print_info "Selected: HTTPS direct"
            
            # Ask for domain name
            read -p "Enter domain name or IP address for SSL certificate [$(hostname -I | awk '{print $1}')]: " -r
            local domain=${REPLY:-$(hostname -I | awk '{print $1}')}
            
            # Configure SSL
            if ! configure_https "$DOTNET_APP_NAME" "$domain"; then
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

# System requirements check for .NET deployment
check_dotnet_deployment_requirements() {
    print_header "Checking .NET Web App Deployment Requirements"
    
    # Check if .NET is installed
    if ! command -v dotnet &> /dev/null; then
        print_error ".NET SDK/Runtime is not installed. Please install .NET first."
        return 1
    fi
    
    DOTNET_APP_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
    print_success ".NET SDK/Runtime is installed (version: $DOTNET_APP_VERSION)"
    
    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        print_info "Nginx is not installed. Installing Nginx..."
        apt-get update -qq
        apt-get install -y nginx
        systemctl enable nginx
        systemctl start nginx
        print_success "Nginx installed successfully"
    else
        print_success "Nginx is already installed"
    fi
    
    # Create necessary directories
    mkdir -p "$DOTNET_BACKUP_DIR"
    mkdir -p "$APPS_ROOT_DIR"
    
    print_success "System requirements check completed"
    return 0
}

# Interactive configuration for .NET deployment
configure_dotnet_deployment() {
    print_header "Configuring .NET Web Application Deployment"
    
    # Initialize default values
    DOTNET_USE_HTTPS="false"
    DOTNET_USE_NGINX="true"
    DOTNET_BIND_ADDRESS="localhost"
    SSL_CERT_PATH=""
    SSL_KEY_PATH=""
    
    # Get app name
    while true; do
        read -p "Enter application name (letters, numbers, hyphens, underscores only): " DOTNET_APP_NAME
        if validate_dotnet_app_name "$DOTNET_APP_NAME"; then
            break
        fi
    done
    
    # Get source path
    while true; do
        read -p "Enter source directory path (containing .dll/.exe files): " DOTNET_APP_SOURCE_PATH
        if validate_dotnet_source_path "$DOTNET_APP_SOURCE_PATH"; then
            break
        fi
    done
    
    # Get port
    while true; do
        read -p "Enter port number (1024-65535, recommended: 5000-5999): " DOTNET_APP_PORT
        if validate_dotnet_port "$DOTNET_APP_PORT"; then
            break
        fi
    done
    
    # Configure HTTPS settings
    if ! ask_https_configuration; then
        print_error "HTTPS configuration failed"
        return 1
    fi
    
    # Get hosting mode
    while true; do
        echo
        echo "Select hosting mode:"
        echo "1) Direct hosting (accessible at http://your-server/)"
        echo "2) Subdirectory hosting (accessible at http://your-server/subpath/)"
        read -p "Enter your choice (1-2): " hosting_choice
        
        case $hosting_choice in
            1)
                DOTNET_HOSTING_MODE="direct"
                DOTNET_APP_SUBDIRECTORY=""
                break
                ;;
            2)
                DOTNET_HOSTING_MODE="subdirectory"
                while true; do
                    read -p "Enter subdirectory path (e.g., 'myapp' or 'apps/myapp'): " DOTNET_APP_SUBDIRECTORY
                    if validate_dotnet_subdirectory "$DOTNET_APP_SUBDIRECTORY"; then
                        # Remove leading/trailing slashes
                        DOTNET_APP_SUBDIRECTORY=$(echo "$DOTNET_APP_SUBDIRECTORY" | sed 's|^/||; s|/$||')
                        break
                    fi
                done
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
    
    # Set derived variables
    DOTNET_APP_DESTINATION_PATH="$APPS_ROOT_DIR/$DOTNET_APP_NAME"
    DOTNET_SERVICE_NAME="dotnet-$DOTNET_APP_NAME"
    DOTNET_NGINX_SITE_NAME="$DOTNET_APP_NAME"
    
    # Display configuration summary
    print_header "Configuration Summary"
    echo -e "${CYAN}Application Name:${NC} $DOTNET_APP_NAME"
    echo -e "${CYAN}Source Path:${NC} $DOTNET_APP_SOURCE_PATH"
    echo -e "${CYAN}Destination Path:${NC} $DOTNET_APP_DESTINATION_PATH"
    echo -e "${CYAN}Port:${NC} $DOTNET_APP_PORT"
    echo -e "${CYAN}HTTPS Mode:${NC} $([[ "$DOTNET_USE_HTTPS" == "true" ]] && echo "Direct HTTPS" || echo "HTTP (nginx proxy)")"
    if [[ "$DOTNET_USE_HTTPS" == "true" ]]; then
        echo -e "${CYAN}SSL Certificate:${NC} $SSL_CERT_PATH"
        echo -e "${CYAN}SSL Key:${NC} $SSL_KEY_PATH"
    fi
    echo -e "${CYAN}Hosting Mode:${NC} $DOTNET_HOSTING_MODE"
    if [[ "$DOTNET_HOSTING_MODE" == "subdirectory" ]]; then
        echo -e "${CYAN}Subdirectory:${NC} $DOTNET_APP_SUBDIRECTORY"
    fi
    echo -e "${CYAN}Service Name:${NC} $DOTNET_SERVICE_NAME"
    echo -e "${CYAN}Nginx Site Name:${NC} $DOTNET_NGINX_SITE_NAME"
    echo
    
    read -p "Proceed with deployment? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Deployment cancelled by user"
        return 1
    fi
    
    return 0
}

# Deploy .NET application
deploy_dotnet_application() {
    print_header "Deploying .NET Web Application"
    
    # Create backup if application already exists
    if [[ -d "$DOTNET_APP_DESTINATION_PATH" ]]; then
        print_info "Creating backup of existing application..."
        backup_name="$DOTNET_APP_NAME-$(date +%Y%m%d-%H%M%S)"
        cp -r "$DOTNET_APP_DESTINATION_PATH" "$DOTNET_BACKUP_DIR/$backup_name"
        print_success "Backup created: $DOTNET_BACKUP_DIR/$backup_name"
    fi
    
    # Create application directory
    print_info "Creating application directory..."
    mkdir -p "$DOTNET_APP_DESTINATION_PATH"
    
    # Copy application files
    print_info "Copying application files..."
    cp -r "$DOTNET_APP_SOURCE_PATH"/* "$DOTNET_APP_DESTINATION_PATH/"
    
    # Set permissions
    print_info "Setting file permissions..."
    chown -R www-data:www-data "$DOTNET_APP_DESTINATION_PATH"
    chmod -R 755 "$DOTNET_APP_DESTINATION_PATH"
    
    # Create systemd service
    print_info "Creating systemd service..."
    create_dotnet_systemd_service
    
    # Configure Nginx
    print_info "Configuring Nginx..."
    configure_dotnet_nginx
    
    # Start and enable service
    print_info "Starting application service..."
    systemctl daemon-reload
    systemctl enable "$DOTNET_SERVICE_NAME"
    systemctl start "$DOTNET_SERVICE_NAME"
    
    # Restart Nginx
    print_info "Restarting Nginx..."
    systemctl restart nginx
    
    print_success "Application deployed successfully!"
    
    # Show access information
    display_dotnet_app_info
    
    return 0
}

# Create systemd service file
create_dotnet_systemd_service() {
    local service_file="$SYSTEMD_SERVICE_DIR/$DOTNET_SERVICE_NAME.service"
    
    # Find the main executable
    local main_exe=$(find "$DOTNET_APP_DESTINATION_PATH" -name "*.dll" -o -name "*.exe" | head -1)
    if [[ -z "$main_exe" ]]; then
        print_error "Cannot find main executable in $DOTNET_APP_DESTINATION_PATH"
        return 1
    fi
    
    # Determine URLs based on HTTPS configuration
    local urls
    if [[ "$DOTNET_USE_HTTPS" == "true" ]]; then
        urls="https://$DOTNET_BIND_ADDRESS:$DOTNET_APP_PORT"
    else
        urls="http://$DOTNET_BIND_ADDRESS:$DOTNET_APP_PORT"
    fi
    
    cat > "$service_file" << EOF
[Unit]
Description=.NET Web App - $DOTNET_APP_NAME
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=$DOTNET_APP_DESTINATION_PATH
ExecStart=/usr/bin/dotnet $main_exe --urls=$urls
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dotnet-app
User=dotnetapp
Group=dotnetapp
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/opt/dotnetapp
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true

[Install]
WantedBy=multi-user.target
EOF
    
    print_success "Systemd service created: $service_file"
    return 0
}

# Configure Nginx reverse proxy
configure_dotnet_nginx() {
    local nginx_config_file="$NGINX_CONFIG_DIR/$DOTNET_NGINX_SITE_NAME"
    
    if [[ "$DOTNET_HOSTING_MODE" == "direct" ]]; then
        # Direct hosting configuration
        cat > "$nginx_config_file" << EOF
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:$DOTNET_APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
    else
        # Subdirectory hosting configuration
        cat > "$nginx_config_file" << EOF
server {
    listen 80;
    server_name _;
    
    location /$DOTNET_APP_SUBDIRECTORY/ {
        proxy_pass http://localhost:$DOTNET_APP_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
    fi
    
    # Enable site
    ln -sf "$nginx_config_file" "$NGINX_ENABLED_DIR/$DOTNET_NGINX_SITE_NAME"
    
    print_success "Nginx configuration created and enabled"
    return 0
}

# Display application information
display_dotnet_app_info() {
    print_header "Application Information"
    
    echo -e "${GREEN}✓ Application deployed successfully!${NC}"
    echo
    echo -e "${CYAN}Application Details:${NC}"
    echo -e "  Name: $DOTNET_APP_NAME"
    echo -e "  Service: $DOTNET_SERVICE_NAME"
    echo -e "  Port: $DOTNET_APP_PORT"
    echo -e "  Path: $DOTNET_APP_DESTINATION_PATH"
    echo
    
    echo -e "${CYAN}Access URLs:${NC}"
    local protocol="http"
    local port_suffix=""
    
    if [[ "$DOTNET_USE_HTTPS" == "true" ]]; then
        protocol="https"
        if [[ "$DOTNET_APP_PORT" != "443" ]]; then
            port_suffix=":$DOTNET_APP_PORT"
        fi
    elif [[ "$DOTNET_USE_NGINX" == "false" ]]; then
        # Direct HTTP access
        port_suffix=":$DOTNET_APP_PORT"
    fi
    
    if [[ "$DOTNET_HOSTING_MODE" == "direct" ]]; then
        if [[ "$DOTNET_USE_NGINX" == "true" ]]; then
            echo -e "  ${protocol}://localhost/"
            echo -e "  ${protocol}://$(hostname -I | awk '{print $1}')/"
        else
            echo -e "  ${protocol}://localhost${port_suffix}/"
            echo -e "  ${protocol}://$(hostname -I | awk '{print $1}')${port_suffix}/"
        fi
    else
        if [[ "$DOTNET_USE_NGINX" == "true" ]]; then
            echo -e "  ${protocol}://localhost/$DOTNET_APP_SUBDIRECTORY/"
            echo -e "  ${protocol}://$(hostname -I | awk '{print $1}')/$DOTNET_APP_SUBDIRECTORY/"
        else
            echo -e "  ${protocol}://localhost${port_suffix}/$DOTNET_APP_SUBDIRECTORY/"
            echo -e "  ${protocol}://$(hostname -I | awk '{print $1}')${port_suffix}/$DOTNET_APP_SUBDIRECTORY/"
        fi
    fi
    echo
    
    echo -e "${CYAN}Service Management:${NC}"
    echo -e "  Status: sudo systemctl status $DOTNET_SERVICE_NAME"
    echo -e "  Start:  sudo systemctl start $DOTNET_SERVICE_NAME"
    echo -e "  Stop:   sudo systemctl stop $DOTNET_SERVICE_NAME"
    echo -e "  Restart: sudo systemctl restart $DOTNET_SERVICE_NAME"
    echo -e "  Logs:   sudo journalctl -u $DOTNET_SERVICE_NAME -f"
    echo
    
    # Check service status
    if systemctl is-active --quiet "$DOTNET_SERVICE_NAME"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
    fi
    
    return 0
}

# .NET Web App Deployment Menu
dotnet_web_app_deployment_menu() {
    while true; do
        clear
        print_header ".NET Web Application Deployment"
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
        echo -e "${CYAN}║${NC} ${RED}0)${NC} Back to Main Menu                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Enter your choice (0-9): ${NC}\c"
        read choice
        
        case $choice in
            1)
                print_info "Starting .NET Web Application Deployment..."
                if check_dotnet_deployment_requirements; then
                    if configure_dotnet_deployment; then
                        deploy_dotnet_application
                    fi
                fi
                read -p "Press Enter to continue..."
                ;;
            2)
                print_info "Checking System Requirements..."
                check_dotnet_deployment_requirements
                read -p "Press Enter to continue..."
                ;;
            3)
                print_info "Installing Dependencies..."
                # Add dependency installation logic here
                read -p "Press Enter to continue..."
                ;;
            4)
                print_info "Showing Deployment Status..."
                list_deployed_dotnet_apps
                read -p "Press Enter to continue..."
                ;;
            5)
                print_info "Restarting Application..."
                manage_dotnet_app_service
                read -p "Press Enter to continue..."
                ;;
            6)
                print_info "Removing Application..."
                remove_dotnet_app
                read -p "Press Enter to continue..."
                ;;
            7)
                print_info "Listing SSL Certificates..."
                list_ssl_certificates
                read -p "Press Enter to continue..."
                ;;
            8)
                print_info "Creating SSL Certificate..."
                create_ssl_certificate
                read -p "Press Enter to continue..."
                ;;
            9)
                print_info "Removing SSL Certificate..."
                remove_ssl_certificate
                read -p "Press Enter to continue..."
                ;;
            0)
                print_info "Returning to Main Menu..."
                break
                ;;
            *)
                print_error "Invalid option. Please select 0-9."
                sleep 2
                ;;
        esac
    done
}

# List deployed applications
list_deployed_dotnet_apps() {
    print_header "Deployed .NET Applications"
    
    if [[ ! -d "$APPS_ROOT_DIR" ]]; then
        print_info "No applications deployed yet"
        return 0
    fi
    
    local apps=($(ls -1 "$APPS_ROOT_DIR" 2>/dev/null))
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        print_info "No applications deployed yet"
        return 0
    fi
    
    echo -e "${CYAN}Found ${#apps[@]} deployed application(s):${NC}"
    echo
    
    for app in "${apps[@]}"; do
        local service_name="dotnet-$app"
        local status="Unknown"
        
        if systemctl is-active --quiet "$service_name"; then
            status="${GREEN}Running${NC}"
        elif systemctl is-enabled --quiet "$service_name"; then
            status="${YELLOW}Stopped${NC}"
        else
            status="${RED}Not configured${NC}"
        fi
        
        echo -e "${WHITE}Application:${NC} $app"
        echo -e "${WHITE}Service:${NC} $service_name"
        echo -e "${WHITE}Status:${NC} $status"
        echo -e "${WHITE}Path:${NC} $APPS_ROOT_DIR/$app"
        echo
    done
    
    return 0
}

# Manage application service
manage_dotnet_app_service() {
    print_header "Manage Application Service"
    
    # List available applications
    local apps=($(ls -1 "$APPS_ROOT_DIR" 2>/dev/null))
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        print_info "No applications deployed yet"
        return 0
    fi
    
    echo -e "${CYAN}Available applications:${NC}"
    for i in "${!apps[@]}"; do
        echo -e "${YELLOW}$((i+1)))${NC} ${apps[$i]}"
    done
    echo
    
    read -p "Select application number: " app_choice
    
    if [[ ! "$app_choice" =~ ^[0-9]+$ ]] || [[ "$app_choice" -lt 1 ]] || [[ "$app_choice" -gt ${#apps[@]} ]]; then
        print_error "Invalid selection"
        return 1
    fi
    
    local selected_app="${apps[$((app_choice-1))]}"
    local service_name="dotnet-$selected_app"
    
    echo
    echo -e "${CYAN}Managing service: $service_name${NC}"
    echo
    echo -e "${YELLOW}1)${NC} Start service"
    echo -e "${YELLOW}2)${NC} Stop service"
    echo -e "${YELLOW}3)${NC} Restart service"
    echo -e "${YELLOW}4)${NC} Check status"
    echo -e "${YELLOW}5)${NC} View logs"
    echo -e "${YELLOW}0)${NC} Back"
    echo
    
    read -p "Enter your choice: " action_choice
    
    case $action_choice in
        1)
            print_info "Starting service..."
            systemctl start "$service_name"
            print_success "Service started"
            ;;
        2)
            print_info "Stopping service..."
            systemctl stop "$service_name"
            print_success "Service stopped"
            ;;
        3)
            print_info "Restarting service..."
            systemctl restart "$service_name"
            print_success "Service restarted"
            ;;
        4)
            print_info "Checking service status..."
            systemctl status "$service_name"
            ;;
        5)
            print_info "Viewing logs (press Ctrl+C to exit)..."
            journalctl -u "$service_name" -f
            ;;
        0)
            return 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac
    
    return 0
}

# Remove application
remove_dotnet_app() {
    print_header "Remove Application"
    
    # List available applications
    local apps=($(ls -1 "$APPS_ROOT_DIR" 2>/dev/null))
    
    if [[ ${#apps[@]} -eq 0 ]]; then
        print_info "No applications deployed yet"
        return 0
    fi
    
    echo -e "${CYAN}Available applications:${NC}"
    for i in "${!apps[@]}"; do
        echo -e "${YELLOW}$((i+1)))${NC} ${apps[$i]}"
    done
    echo
    
    read -p "Select application number to remove: " app_choice
    
    if [[ ! "$app_choice" =~ ^[0-9]+$ ]] || [[ "$app_choice" -lt 1 ]] || [[ "$app_choice" -gt ${#apps[@]} ]]; then
        print_error "Invalid selection"
        return 1
    fi
    
    local selected_app="${apps[$((app_choice-1))]}"
    local service_name="dotnet-$selected_app"
    
    print_warning "This will remove the application: $selected_app"
    print_warning "Service: $service_name"
    print_warning "Path: $APPS_ROOT_DIR/$selected_app"
    echo
    
    read -p "Are you sure you want to remove this application? (y/N): " confirm
    
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_info "Removal cancelled"
        return 0
    fi
    
    # Create backup before removal
    print_info "Creating backup before removal..."
    backup_name="$selected_app-removed-$(date +%Y%m%d-%H%M%S)"
    cp -r "$APPS_ROOT_DIR/$selected_app" "$DOTNET_BACKUP_DIR/$backup_name"
    print_success "Backup created: $DOTNET_BACKUP_DIR/$backup_name"
    
    # Stop and disable service
    print_info "Stopping and disabling service..."
    systemctl stop "$service_name" 2>/dev/null || true
    systemctl disable "$service_name" 2>/dev/null || true
    
    # Remove service file
    rm -f "$SYSTEMD_SERVICE_DIR/$service_name.service"
    systemctl daemon-reload
    
    # Remove Nginx configuration
    rm -f "$NGINX_CONFIG_DIR/$selected_app"
    rm -f "$NGINX_ENABLED_DIR/$selected_app"
    systemctl restart nginx
    
    # Remove application directory
    rm -rf "$APPS_ROOT_DIR/$selected_app"
    
    print_success "Application removed successfully"
    print_info "Backup available at: $DOTNET_BACKUP_DIR/$backup_name"
    
    return 0
}

# Create backup of existing application before deployment
create_dotnet_app_backup() {
    local app_name="$1"
    local backup_name="$2"
    
    print_info "Creating backup of existing application..."
    
    # Create backup directory if it doesn't exist
    mkdir -p "$DOTNET_BACKUP_DIR"
    
    # Create backup
    if [[ -d "$APPS_ROOT_DIR/$app_name" ]]; then
        cp -r "$APPS_ROOT_DIR/$app_name" "$DOTNET_BACKUP_DIR/$backup_name"
        print_success "Backup created: $DOTNET_BACKUP_DIR/$backup_name"
    else
        print_info "No existing application found to backup"
    fi
}

# Deploy .NET application
deploy_dotnet_application() {
    local app_name="$1"
    local source_path="$2"
    local port="$3"
    local hosting_mode="$4"
    local subdirectory="$5"
    
    print_header "Deploying .NET Application: $app_name"
    
    # Set global variables
    DOTNET_APP_NAME="$app_name"
    DOTNET_APP_SOURCE_PATH="$source_path"
    DOTNET_APP_PORT="$port"
    DOTNET_HOSTING_MODE="$hosting_mode"
    DOTNET_APP_SUBDIRECTORY="$subdirectory"
    
    # Derive other variables
    DOTNET_APP_DESTINATION_PATH="$APPS_ROOT_DIR/$app_name"
    DOTNET_SERVICE_NAME="dotnet-$app_name"
    
    if [[ "$hosting_mode" == "subdirectory" ]]; then
        DOTNET_NGINX_SITE_NAME="$app_name-subdir"
    else
        DOTNET_NGINX_SITE_NAME="$app_name"
    fi
    
    # Create backup if application exists
    if [[ -d "$DOTNET_APP_DESTINATION_PATH" ]]; then
        local backup_name="$app_name-backup-$(date +%Y%m%d-%H%M%S)"
        create_dotnet_app_backup "$app_name" "$backup_name"
    fi
    
    # Create application directory
    print_info "Creating application directory..."
    mkdir -p "$DOTNET_APP_DESTINATION_PATH"
    
    # Copy application files
    print_info "Copying application files..."
    cp -r "$source_path"/* "$DOTNET_APP_DESTINATION_PATH/"
    
    # Set proper permissions
    print_info "Setting proper permissions..."
    chown -R www-data:www-data "$DOTNET_APP_DESTINATION_PATH"
    chmod -R 755 "$DOTNET_APP_DESTINATION_PATH"
    
    # Create systemd service
    create_dotnet_systemd_service "$app_name" "$port" "$DOTNET_APP_DESTINATION_PATH"
    
    # Configure Nginx
    configure_nginx_for_dotnet_app "$app_name" "$port" "$hosting_mode" "$subdirectory"
    
    # Start services
    start_dotnet_services "$app_name"
    
    # Verify deployment
    verify_dotnet_deployment "$app_name" "$port" "$hosting_mode" "$subdirectory"
    
    print_completion "Application '$app_name' deployed successfully"
}

# Create systemd service for .NET application
create_dotnet_systemd_service() {
    local app_name="$1"
    local port="$2"
    local app_path="$3"
    
    print_info "Creating systemd service..."
    
    # Find the main executable file
    local main_executable=""
    local exec_command=""
    
    # First, try to find .dll files (traditional .NET deployment)
    local main_dll=$(find "$app_path" -name "*.dll" -type f | head -1)
    if [[ -n "$main_dll" ]]; then
        local dll_name=$(basename "$main_dll")
        main_executable="$dll_name"
        exec_command="/usr/bin/dotnet $dll_name"
        print_info "Found .dll file: $dll_name"
    else
        # Look for Linux executable files (self-contained deployment)
        local executable_files=$(find "$app_path" -type f -executable | grep -E "(^[^/]*$|/[^/]*$)" | head -5)
        
        # Filter for potential .NET executables
        for file in $executable_files; do
            if [[ -f "$file" ]] && file "$file" | grep -q "ELF.*executable"; then
                # Check if it's likely a .NET executable by looking for related files
                local basename_file=$(basename "$file")
                if [[ -f "$app_path/$basename_file.deps.json" ]] || [[ -f "$app_path/$basename_file.runtimeconfig.json" ]] || [[ -f "$app_path/appsettings.json" ]]; then
                    main_executable="$basename_file"
                    exec_command="$app_path/$basename_file"
                    print_info "Found .NET executable: $basename_file"
                    break
                fi
            fi
        done
    fi
    
    # If no executable found, try to find by app name
    if [[ -z "$main_executable" ]]; then
        # Try to find executable with same name as app
        for potential_name in "$app_name" "${app_name,,}" "${app_name^}"; do
            if [[ -f "$app_path/$potential_name" ]] && [[ -x "$app_path/$potential_name" ]]; then
                main_executable="$potential_name"
                exec_command="$app_path/$potential_name"
                print_info "Found executable by name: $potential_name"
                break
            fi
        done
    fi
    
    # If still no executable found, ask user for executable name
    if [[ -z "$main_executable" ]]; then
        print_warning "No .NET executable automatically detected in $app_path"
        print_info "Available files:"
        ls -la "$app_path/"
        echo
        
        while true; do
            read -p "Enter the executable filename (without path): " user_executable
            
            if [[ -z "$user_executable" ]]; then
                print_error "Executable name cannot be empty"
                continue
            fi
            
            if [[ -f "$app_path/$user_executable" ]]; then
                if [[ -x "$app_path/$user_executable" ]]; then
                    main_executable="$user_executable"
                    exec_command="$app_path/$user_executable"
                    print_success "Using executable: $user_executable"
                    break
                else
                    print_error "File '$user_executable' is not executable. Making it executable..."
                    chmod +x "$app_path/$user_executable"
                    main_executable="$user_executable"
                    exec_command="$app_path/$user_executable"
                    print_success "Using executable: $user_executable"
                    break
                fi
            else
                print_error "File '$user_executable' not found in $app_path"
                print_info "Available files:"
                ls -1 "$app_path/"
            fi
        done
    fi
    
    # Create systemd service file
    cat > "$SYSTEMD_SERVICE_DIR/dotnet-$app_name.service" <<EOF
[Unit]
Description=.NET Web Application: $app_name
After=network.target

[Service]
Type=notify
WorkingDirectory=$app_path
ExecStart=$exec_command
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=dotnet-$app_name
User=www-data
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
Environment=ASPNETCORE_URLS=https://0.0.0.0:$port

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start service
    systemctl daemon-reload
    systemctl enable "dotnet-$app_name.service"
    
    print_success "Systemd service created and enabled for: $main_executable"
}

# Configure Nginx for .NET application
configure_nginx_for_dotnet_app() {
    local app_name="$1"
    local port="$2"
    local hosting_mode="$3"
    local subdirectory="$4"
    
    print_info "Configuring Nginx..."
    
    local site_name="$app_name"
    if [[ "$hosting_mode" == "subdirectory" ]]; then
        site_name="$app_name-subdir"
    fi
    
    # Create Nginx site configuration
    if [[ "$hosting_mode" == "subdirectory" ]]; then
        # Subdirectory hosting
        cat > "$NGINX_CONFIG_DIR/$site_name" <<EOF
server {
    listen 80;
    server_name _;
    
    location /$subdirectory {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        
        # Remove the subdirectory from the path when forwarding to the app
        rewrite ^/$subdirectory(.*) \$1 break;
    }
}
EOF
    else
        # Direct hosting
        cat > "$NGINX_CONFIG_DIR/$site_name" <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://localhost:$port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
    }
}
EOF
    fi
    
    # Disable default site if using direct hosting
    if [[ "$hosting_mode" == "direct" ]] && [[ -f "$NGINX_ENABLED_DIR/default" ]]; then
        rm -f "$NGINX_ENABLED_DIR/default"
        print_info "Disabled default Nginx site"
    fi
    
    # Enable site
    ln -sf "$NGINX_CONFIG_DIR/$site_name" "$NGINX_ENABLED_DIR/"
    
    # Test Nginx configuration
    if nginx -t; then
        print_success "Nginx configuration is valid"
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        print_error "Nginx configuration is invalid"
        return 1
    fi
}

# Start .NET application services
start_dotnet_services() {
    local app_name="$1"
    
    print_info "Starting services..."
    
    # Start .NET application service
    if systemctl start "dotnet-$app_name.service"; then
        print_success ".NET application service started"
    else
        print_error "Failed to start .NET application service"
        return 1
    fi
    
    # Ensure Nginx is running
    if systemctl is-active --quiet nginx; then
        print_success "Nginx is running"
    else
        print_info "Starting Nginx..."
        systemctl start nginx
    fi
}

# Verify deployment
verify_dotnet_deployment() {
    local app_name="$1"
    local port="$2"
    local hosting_mode="$3"
    local subdirectory="$4"
    
    print_info "Verifying deployment..."
    
    # Check if .NET service is running
    if systemctl is-active --quiet "dotnet-$app_name.service"; then
        print_success ".NET service is running"
    else
        print_error ".NET service is not running"
        return 1
    fi
    
    # Check if application responds on localhost
    sleep 5  # Give the app time to start
    
    if curl -s "http://localhost:$port" > /dev/null; then
        print_success "Application is responding on port $port"
    else
        print_warning "Application may not be responding on port $port"
    fi
    
    # Show access URLs
    print_info "Application Access URLs:"
    if [[ "$hosting_mode" == "subdirectory" ]]; then
        echo "  Local: http://localhost/$subdirectory"
        echo "  External: http://your-server-ip/$subdirectory"
    else
        echo "  Local: http://localhost"
        echo "  External: http://your-server-ip"
    fi
    
    print_info "Service Management:"
    echo "  Status: systemctl status dotnet-$app_name"
    echo "  Logs: journalctl -u dotnet-$app_name -f"
    echo "  Restart: systemctl restart dotnet-$app_name"
    echo "  Stop: systemctl stop dotnet-$app_name"
}

# Main deployment menu
dotnet_web_app_deployment_menu() {
    while true; do
        print_header ".NET Web Application Deployment"
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}Select an option:${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Deploy New Application                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Check System Requirements                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Install Dependencies                                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Check Application Status                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Restart Application                                                              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} Remove Application                                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}SSL CERTIFICATE MANAGEMENT${NC}                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} List SSL Certificates                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Create SSL Certificate                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Remove SSL Certificate                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${RED}0)${NC} Back to Main Menu                                                                ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Enter your choice (0-9): ${NC}\\c"
        
        read -r choice
        
        case $choice in
            1)
                deploy_new_dotnet_application
                ;;
            2)
                check_dotnet_system_requirements
                ;;
            3)
                install_dotnet_dependencies
                ;;
            4)
                check_dotnet_application_status
                ;;
            5)
                restart_dotnet_application
                ;;
            6)
                remove_dotnet_application
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
                return 0
                ;;
            *)
                print_error "Invalid option. Please select 0-9."
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================

# Function to show the main menu
show_main_menu() {
    while true; do
        clear
        print_header "Ubuntu Server Complete Setup - Main Menu"
        echo
        echo -e "${WHITE}Please select an option:${NC}"
        echo
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}INSTALLATION OPTIONS${NC}                                                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Complete Server Setup (Interactive)                                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Complete Server Setup (Automatic)                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Install MySQL Only                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Install .NET Only                                                                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Configure Git/GitHub Only                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} Install Monitoring Tools Only                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} Configure Security/Firewall Only                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${PURPLE}USER MANAGEMENT OPTIONS${NC}                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Manage Ubuntu Users                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Manage MySQL Users                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}10)${NC} Manage FTP Users                                                                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}11)${NC} Show User Management Menu                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}SCRIPT MANAGEMENT OPTIONS${NC}                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}12)${NC} Make All Scripts Executable                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}13)${NC} Run All Available Scripts                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}14)${NC} Test Installation Scripts                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}INFORMATION OPTIONS${NC}                                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}15)${NC} Show Help/Usage Information                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}16)${NC} Display System Information                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}DOTNET APPLICATION DEPLOYMENT${NC}                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}17)${NC} Deploy .NET Web Application                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${RED}UNINSTALL OPTIONS${NC}                                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}18)${NC} Uninstall MySQL (with optional data removal)                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${RED}0)${NC} Exit                                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Enter your choice (0-18): ${NC}\c"
        read choice
        
        case $choice in
            1)
                print_info "Starting Complete Server Setup (Interactive)..."
                make_scripts_executable
                main
                read -p "Press Enter to continue..." && continue
                ;;
            2)
                print_info "Starting Complete Server Setup (Automatic)..."
                CONFIGURE_GITHUB=false
                INSTALL_MONITORING=false
                make_scripts_executable
                main
                read -p "Press Enter to continue..." && continue
                ;;
            3)
                print_info "Installing MySQL Only..."
                check_root
                check_ubuntu
                update_system
                install_mysql
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            4)
                print_info "Installing .NET Only..."
                check_root
                check_ubuntu
                update_system
                install_dotnet
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            5)
                print_info "Configuring Git and GitHub Only..."
                check_root
                check_ubuntu
                CONFIGURE_GITHUB=true
                read -p "Enter GitHub username: " GITHUB_USERNAME
                read -p "Enter GitHub email: " GITHUB_EMAIL
                update_system
                configure_git_github
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            6)
                print_info "Installing System Monitoring Tools Only..."
                check_root
                check_ubuntu
                INSTALL_MONITORING=true
                update_system
                install_monitoring_tools
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            7)
                print_info "Configuring Firewall and Security Only..."
                check_root
                check_ubuntu
                update_system
                configure_firewall
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            8)
                print_info "Starting Ubuntu User Management..."
                check_root
                run_ubuntu_user_manager
                read -p "Press Enter to continue..." && continue
                ;;
            9)
                print_info "Starting MySQL Administration Toolkit..."
                check_root
                run_mysql_admin_toolkit
                read -p "Press Enter to continue..." && continue
                ;;
            10)
                print_info "Starting FTP User Management..."
                check_root
                run_ftp_user_manager
                read -p "Press Enter to continue..." && continue
                ;;
            11)
                print_info "Showing User Management Menu..."
                check_root
                show_user_management_menu
                read -p "Press Enter to continue..." && continue
                ;;
            12)
                print_info "Making All Scripts Executable..."
                make_scripts_executable
                read -p "Press Enter to continue..." && continue
                ;;
            13)
                print_info "Running All Available Scripts..."
                check_root
                check_ubuntu
                run_all_scripts
                read -p "Press Enter to continue..." && continue
                ;;
            14)
                print_info "Testing Installation Scripts..."
                if [[ -f "test-installation.sh" ]]; then
                    if [[ -x "test-installation.sh" ]]; then
                        ./test-installation.sh
                    else
                        print_info "Making test script executable..."
                        chmod +x test-installation.sh 2>/dev/null || true
                        bash test-installation.sh
                    fi
                else
                    print_error "Test script not found (test-installation.sh)"
                fi
                read -p "Press Enter to continue..." && continue
                ;;
            15)
                print_info "Showing Help Information..."
                echo "Usage: $0 [options]"
                echo
                echo "INSTALLATION OPTIONS:"
                echo "  --help, -h          Show this help message"
                echo "  --auto              Run with default settings (non-interactive)"
                echo "  --mysql-only        Install only MySQL"
                echo "  --dotnet-only       Install only .NET"
                echo "  --git-only          Install and configure Git/GitHub only"
                echo "  --monitoring-only   Install system monitoring tools only"
                echo "  --security-only     Configure firewall and security only"
                echo "  --deploy-dotnet-app Deploy .NET web application"
                echo "  --uninstall-mysql   Uninstall MySQL with optional data removal"
                echo "  --no-git            Skip Git/GitHub configuration"
                echo "  --no-monitoring     Skip monitoring tools installation"
                echo "  --no-interactive    Skip all interactive prompts"
                echo
                echo "USER MANAGEMENT OPTIONS:"
                echo "  --manage-users      Run Ubuntu user management"
                echo "  --manage-mysql      Run MySQL administration toolkit"
                echo "  --manage-ftp        Run FTP user management"
                echo "  --user-menu         Show user management menu"
                echo
                echo "SCRIPT MANAGEMENT OPTIONS:"
                echo "  --make-executable   Make all scripts in directory executable"
                echo "  --run-all           Run all available scripts and tools"
                echo
                echo "AVAILABLE SCRIPTS:"
                echo "  • ubuntu-server-complete-setup.sh - Complete server setup script"
                echo "  • ubuntu-user-manager.sh     - Ubuntu system user management"
                echo "  • mysql-admin-toolkit.sh     - MySQL administration toolkit"
                echo "  • ftp-user-manager.sh        - FTP server and user management"
                echo "  • make-executable.sh         - Script permission manager"
                echo
                echo "EXAMPLES:"
                echo "  $0                           # Show main menu"
                echo "  $0 --auto                    # Automatic installation"
                echo "  $0 --make-executable         # Make all scripts executable"
                echo "  $0 --manage-users            # Manage Ubuntu users"
                echo "  $0 --manage-mysql            # Manage MySQL administration"
                echo "  $0 --manage-ftp              # Manage FTP users"
                echo "  $0 --user-menu               # Show user management menu"
                echo "  $0 --run-all                 # Run everything"
                read -p "Press Enter to continue..." && continue
                ;;
            16)
                print_info "Displaying System Information..."
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            17)
                print_info "Starting .NET Web Application Deployment..."
                check_root
                check_ubuntu
                dotnet_web_app_deployment_menu
                read -p "Press Enter to continue..." && continue
                ;;
            18)
                print_info "Starting MySQL Uninstallation..."
                check_root
                uninstall_mysql
                read -p "Press Enter to continue..." && continue
                ;;
            0)
                print_info "Exiting Ubuntu Server Setup..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-18."
                sleep 2
                ;;
        esac
    done
}

# Deploy new .NET application - Interactive function
deploy_new_dotnet_application() {
    print_header "Deploy New .NET Application"
    
    # Get application name
    while true; do
        echo -e "${WHITE}Enter application name (letters, numbers, hyphens, underscores only): ${NC}\\c"
        read -r app_name
        
        if validate_dotnet_app_name "$app_name"; then
            break
        fi
    done
    
    # Get source path
    while true; do
        echo -e "${WHITE}Enter source directory path: ${NC}\\c"
        read -r source_path
        
        if validate_source_path "$source_path"; then
            break
        fi
    done
    
    # Get port
    while true; do
        echo -e "${WHITE}Enter port number (1024-65535, recommended: 5000-5999): ${NC}\\c"
        read -r port
        
        if validate_port "$port"; then
            break
        fi
    done
    
    # Get hosting mode
    while true; do
        echo -e "${WHITE}Choose hosting mode:${NC}"
        echo "  1) Direct hosting (accessible at root URL)"
        echo "  2) Subdirectory hosting (accessible under subdirectory)"
        echo -e "${WHITE}Enter your choice (1-2): ${NC}\\c"
        read -r hosting_choice
        
        case $hosting_choice in
            1)
                hosting_mode="direct"
                subdirectory=""
                break
                ;;
            2)
                hosting_mode="subdirectory"
                while true; do
                    echo -e "${WHITE}Enter subdirectory name: ${NC}\\c"
                    read -r subdirectory
                    
                    if validate_subdirectory "$subdirectory"; then
                        break
                    fi
                done
                break
                ;;
            *)
                print_error "Invalid choice. Please select 1 or 2."
                ;;
        esac
    done
    
    # Confirm deployment
    echo
    print_info "Deployment Configuration:"
    echo "  Application Name: $app_name"
    echo "  Source Path: $source_path"
    echo "  Port: $port"
    echo "  Hosting Mode: $hosting_mode"
    if [[ "$hosting_mode" == "subdirectory" ]]; then
        echo "  Subdirectory: $subdirectory"
    fi
    echo
    
    echo -e "${WHITE}Proceed with deployment? (y/n): ${NC}\\c"
    read -r confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        deploy_dotnet_application "$app_name" "$source_path" "$port" "$hosting_mode" "$subdirectory"
    else
        print_info "Deployment cancelled"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Check system requirements
check_dotnet_system_requirements() {
    print_header "System Requirements Check"
    
    # Check Ubuntu version
    if [[ -f /etc/lsb-release ]]; then
        source /etc/lsb-release
        print_success "Ubuntu $DISTRIB_RELEASE detected"
    else
        print_error "Not running on Ubuntu"
        return 1
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_success "Running as root"
    else
        print_error "Not running as root"
        return 1
    fi
    
    # Check .NET installation
    if command -v dotnet &> /dev/null; then
        DOTNET_VERSION=$(dotnet --version 2>/dev/null || echo "unknown")
        print_success ".NET SDK/Runtime is installed (version: $DOTNET_VERSION)"
    else
        print_warning ".NET is not installed"
    fi
    
    # Check Nginx installation
    if command -v nginx &> /dev/null; then
        local nginx_version=$(nginx -v 2>&1 | cut -d' ' -f3)
        print_success "Nginx is installed ($nginx_version)"
    else
        print_warning "Nginx is not installed"
    fi
    
    # Check systemd
    if command -v systemctl &> /dev/null; then
        print_success "Systemd is available"
    else
        print_error "Systemd is not available"
        return 1
    fi
    
    # Check curl
    if command -v curl &> /dev/null; then
        print_success "curl is installed"
    else
        print_warning "curl is not installed"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Install dependencies
install_dotnet_dependencies() {
    print_header "Installing Dependencies"
    
    # Install .NET if not present
    if ! command -v dotnet &> /dev/null; then
        print_info "Installing .NET SDK..."
        
        # Install Microsoft package signing key
        wget -q https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb
        dpkg -i packages-microsoft-prod.deb
        rm packages-microsoft-prod.deb
        
        # Update package list
        apt-get update -qq
        
        # Install .NET SDK
        apt-get install -y dotnet-sdk-8.0
        
        if command -v dotnet &> /dev/null; then
            print_success ".NET SDK installed successfully"
        else
            print_error "Failed to install .NET SDK"
            return 1
        fi
    else
        print_success ".NET is already installed"
    fi
    
    # Install Nginx if not present
    if ! command -v nginx &> /dev/null; then
        print_info "Installing Nginx..."
        apt-get install -y nginx
        
        # Start and enable Nginx
        systemctl start nginx
        systemctl enable nginx
        
        if command -v nginx &> /dev/null; then
            print_success "Nginx installed successfully"
        else
            print_error "Failed to install Nginx"
            return 1
        fi
    else
        print_success "Nginx is already installed"
    fi
    
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        print_info "Installing curl..."
        apt-get install -y curl
        
        if command -v curl &> /dev/null; then
            print_success "curl installed successfully"
        else
            print_warning "Failed to install curl"
        fi
    else
        print_success "curl is already installed"
    fi
    
    # Create necessary directories
    mkdir -p "$APPS_ROOT_DIR"
    mkdir -p "$DOTNET_BACKUP_DIR"
    
    print_success "All dependencies installed"
    echo
    read -p "Press Enter to continue..."
}

# Check application status
check_dotnet_application_status() {
    print_header "Application Status Check"
    
    # Get application name
    echo -e "${WHITE}Enter application name: ${NC}\\c"
    read -r app_name
    
    if [[ -z "$app_name" ]]; then
        print_error "Application name cannot be empty"
        return 1
    fi
    
    local service_name="dotnet-$app_name"
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "$service_name.service"; then
        print_error "Service $service_name does not exist"
        return 1
    fi
    
    # Check service status
    if systemctl is-active --quiet "$service_name"; then
        print_success "Service $service_name is running"
    else
        print_error "Service $service_name is not running"
    fi
    
    # Check if application directory exists
    if [[ -d "$APPS_ROOT_DIR/$app_name" ]]; then
        print_success "Application directory exists: $APPS_ROOT_DIR/$app_name"
    else
        print_error "Application directory does not exist: $APPS_ROOT_DIR/$app_name"
    fi
    
    # Show detailed service status
    echo
    print_info "Detailed Service Status:"
    systemctl status "$service_name" --no-pager
    
    echo
    read -p "Press Enter to continue..."
}

# Restart application
restart_dotnet_application() {
    print_header "Restart Application"
    
    # Get application name
    echo -e "${WHITE}Enter application name: ${NC}\\c"
    read -r app_name
    
    if [[ -z "$app_name" ]]; then
        print_error "Application name cannot be empty"
        return 1
    fi
    
    local service_name="dotnet-$app_name"
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "$service_name.service"; then
        print_error "Service $service_name does not exist"
        return 1
    fi
    
    # Restart service
    print_info "Restarting $service_name..."
    if systemctl restart "$service_name"; then
        print_success "Service $service_name restarted successfully"
    else
        print_error "Failed to restart service $service_name"
        return 1
    fi
    
    # Check status after restart
    sleep 2
    if systemctl is-active --quiet "$service_name"; then
        print_success "Service is running after restart"
    else
        print_error "Service is not running after restart"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Remove application
remove_dotnet_application() {
    print_header "Remove Application"
    
    # Get application name
    echo -e "${WHITE}Enter application name: ${NC}\\c"
    read -r app_name
    
    if [[ -z "$app_name" ]]; then
        print_error "Application name cannot be empty"
        return 1
    fi
    
    local service_name="dotnet-$app_name"
    
    # Confirm removal
    echo
    print_warning "This will remove the application and all its data."
    echo -e "${WHITE}Are you sure you want to remove '$app_name'? (y/n): ${NC}\\c"
    read -r confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Removal cancelled"
        return 0
    fi
    
    # Create backup before removal
    if [[ -d "$APPS_ROOT_DIR/$app_name" ]]; then
        local backup_name="$app_name-removed-$(date +%Y%m%d-%H%M%S)"
        create_dotnet_app_backup "$app_name" "$backup_name"
    fi
    
    # Stop and disable service
    if systemctl list-unit-files | grep -q "$service_name.service"; then
        print_info "Stopping and disabling service..."
        systemctl stop "$service_name" 2>/dev/null
        systemctl disable "$service_name" 2>/dev/null
        
        # Remove service file
        if [[ -f "$SYSTEMD_SERVICE_DIR/$service_name.service" ]]; then
            rm -f "$SYSTEMD_SERVICE_DIR/$service_name.service"
            print_success "Service file removed"
        fi
        
        systemctl daemon-reload
    fi
    
    # Remove application directory
    if [[ -d "$APPS_ROOT_DIR/$app_name" ]]; then
        rm -rf "$APPS_ROOT_DIR/$app_name"
        print_success "Application directory removed"
    fi
    
    # Remove Nginx configuration
    local nginx_configs=("$app_name" "$app_name-subdir")
    for config in "${nginx_configs[@]}"; do
        if [[ -f "$NGINX_CONFIG_DIR/$config" ]]; then
            rm -f "$NGINX_CONFIG_DIR/$config"
            rm -f "$NGINX_ENABLED_DIR/$config"
            print_success "Nginx configuration removed: $config"
        fi
    done
    
    # Test and reload Nginx
    if nginx -t; then
        systemctl reload nginx
        print_success "Nginx reloaded"
    else
        print_warning "Nginx configuration test failed"
    fi
    
    print_success "Application '$app_name' removed successfully"
    echo
    read -p "Press Enter to continue..."
}

# View application logs
view_dotnet_application_logs() {
    print_header "View Application Logs"
    
    # Get application name
    echo -e "${WHITE}Enter application name: ${NC}\\c"
    read -r app_name
    
    if [[ -z "$app_name" ]]; then
        print_error "Application name cannot be empty"
        return 1
    fi
    
    local service_name="dotnet-$app_name"
    
    # Check if service exists
    if ! systemctl list-unit-files | grep -q "$service_name.service"; then
        print_error "Service $service_name does not exist"
        return 1
    fi
    
    echo
    print_info "Showing logs for $service_name (press Ctrl+C to exit)..."
    echo
    
    # Show logs
    journalctl -u "$service_name" -f
}

# List all applications
list_dotnet_applications() {
    print_header "List All Applications"
    
    local found_apps=false
    
    # Check for applications in the apps directory
    if [[ -d "$APPS_ROOT_DIR" ]]; then
        for app_dir in "$APPS_ROOT_DIR"/*; do
            if [[ -d "$app_dir" ]]; then
                local app_name=$(basename "$app_dir")
                local service_name="dotnet-$app_name"
                
                echo -e "${YELLOW}Application: $app_name${NC}"
                echo "  Directory: $app_dir"
                
                # Check service status
                if systemctl list-unit-files | grep -q "$service_name.service"; then
                    if systemctl is-active --quiet "$service_name"; then
                        echo -e "  Status: ${GREEN}Running${NC}"
                    else
                        echo -e "  Status: ${RED}Stopped${NC}"
                    fi
                else
                    echo -e "  Status: ${RED}No Service${NC}"
                fi
                
                # Check for Nginx configuration
                if [[ -f "$NGINX_CONFIG_DIR/$app_name" ]] || [[ -f "$NGINX_CONFIG_DIR/$app_name-subdir" ]]; then
                    echo -e "  Nginx: ${GREEN}Configured${NC}"
                else
                    echo -e "  Nginx: ${RED}Not Configured${NC}"
                fi
                
                echo
                found_apps=true
            fi
        done
    fi
    
    if [[ "$found_apps" == false ]]; then
        print_info "No applications found"
    fi
    
    echo
    read -p "Press Enter to continue..."
}

# Validation functions
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
    # Look for .dll, .exe files, or executable files that might be .NET applications
    local has_dotnet_files=false
    
    # Check for .dll or .exe files
    if find "$source_path" -maxdepth 1 -name "*.dll" -o -name "*.exe" | grep -q .; then
        has_dotnet_files=true
    fi
    
    # Check for executable files (Linux .NET applications)
    if [[ "$has_dotnet_files" == "false" ]]; then
        # Look for executable files that might be .NET applications
        local executable_files=$(find "$source_path" -maxdepth 1 -type f -executable | head -5)
        if [[ -n "$executable_files" ]]; then
            # Check if any executable file is a .NET application by looking for ELF format
            while IFS= read -r exe_file; do
                if [[ -f "$exe_file" ]] && file "$exe_file" | grep -q "ELF.*executable"; then
                    has_dotnet_files=true
                    break
                fi
            done <<< "$executable_files"
        fi
    fi
    
    # Additional check for .NET specific files
    if [[ "$has_dotnet_files" == "false" ]]; then
        if find "$source_path" -maxdepth 1 -name "*.deps.json" -o -name "*.runtimeconfig.json" -o -name "appsettings.json" | grep -q .; then
            has_dotnet_files=true
        fi
    fi
    
    if [[ "$has_dotnet_files" == "false" ]]; then
        print_error "Directory does not appear to contain a .NET application"
        print_info "Looking for: .dll, .exe files, executable files, or .NET configuration files"
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
# SCRIPT EXECUTION
# =============================================================================

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo
        echo "INSTALLATION OPTIONS:"
        echo "  --help, -h          Show this help message"
        echo "  --auto              Run with default settings (non-interactive)"
        echo "  --mysql-only        Install only MySQL"
        echo "  --mysql-password    Set MySQL root password (next argument)"
        echo "  --dotnet-only       Install only .NET"
        echo "  --git-only          Install and configure Git/GitHub only"
        echo "  --monitoring-only   Install system monitoring tools only"
        echo "  --security-only     Configure firewall and security only"
        echo "  --deploy-dotnet-app Deploy .NET web application"
        echo "  --uninstall-mysql   Uninstall MySQL with optional data removal"
        echo "  --no-git            Skip Git/GitHub configuration"
        echo "  --no-monitoring     Skip monitoring tools installation"
        echo "  --no-interactive    Skip all interactive prompts"
        echo
        echo "USER MANAGEMENT OPTIONS:"
        echo "  --manage-users      Run Ubuntu user management"
        echo "  --manage-mysql      Run MySQL administration toolkit"
        echo "  --manage-ftp        Run FTP user management"
        echo "  --user-menu         Show user management menu"
        echo
        echo "SCRIPT MANAGEMENT OPTIONS:"
        echo "  --make-executable   Make all scripts in directory executable"
        echo "  --run-all           Run all available scripts and tools"
        echo
        echo "AVAILABLE SCRIPTS:"
        echo "  • ubuntu-server-complete-setup.sh - Complete server setup script"
        echo "  • ubuntu-user-manager.sh     - Ubuntu system user management"
        echo "  • mysql-admin-toolkit.sh     - MySQL administration toolkit"
        echo "  • ftp-user-manager.sh        - FTP server and user management"
        echo "  • make-executable.sh         - Script permission manager"
        echo
        echo "EXAMPLES:"
        echo "  $0                           # Show main menu"
        echo "  $0 --auto                    # Automatic installation"
        echo "  $0 --mysql-password mypass   # Set MySQL root password"
        echo "  $0 --make-executable         # Make all scripts executable"
        echo "  $0 --manage-users            # Manage Ubuntu users"
        echo "  $0 --manage-mysql            # Manage MySQL administration"
        echo "  $0 --manage-ftp              # Manage FTP users"
        echo "  $0 --user-menu               # Show user management menu"
        echo "  $0 --run-all                 # Run everything"
        exit 0
        ;;
    --auto)
        print_info "Running in automatic mode with default settings"
        make_scripts_executable
        main
        ;;
    --mysql-only)
        print_info "Installing MySQL only"
        check_root
        check_ubuntu
        update_system
        install_mysql
        display_system_info
        exit 0
        ;;
    --mysql-password)
        if [[ -z "$2" ]]; then
            print_error "MySQL password argument required after --mysql-password"
            echo "Usage: $0 --mysql-password <password>"
            exit 1
        fi
        MYSQL_ROOT_PASSWORD="$2"
        print_info "MySQL root password set via command line"
        shift 2  # Remove both arguments
        # Continue with remaining arguments or show menu
        if [[ $# -eq 0 ]]; then
            show_main_menu
        else
            # Re-process remaining arguments
            exec "$0" "$@"
        fi
        ;;
    --dotnet-only)
        print_info "Installing .NET only"
        check_root
        check_ubuntu
        update_system
        install_dotnet
        display_system_info
        exit 0
        ;;
    --git-only)
        print_info "Configuring Git and GitHub only"
        check_root
        check_ubuntu
        CONFIGURE_GITHUB=true
        read -p "Enter GitHub username: " GITHUB_USERNAME
        read -p "Enter GitHub email: " GITHUB_EMAIL
        update_system
        configure_git_github
        display_system_info
        exit 0
        ;;
    --monitoring-only)
        print_info "Installing system monitoring tools only"
        check_root
        check_ubuntu
        INSTALL_MONITORING=true
        update_system
        install_monitoring_tools
        display_system_info
        exit 0
        ;;
    --security-only)
        print_info "Configuring firewall and security only"
        check_root
        check_ubuntu
        update_system
        configure_firewall
        display_system_info
        exit 0
        ;;
    --deploy-dotnet-app)
        print_info "Deploying .NET Web Application"
        check_root
        check_ubuntu
        dotnet_web_app_deployment_menu
        exit 0
        ;;
    --uninstall-mysql)
        print_info "Uninstalling MySQL with optional data removal"
        check_root
        uninstall_mysql
        exit 0
        ;;
    --manage-users)
        print_info "Running Ubuntu User Management"
        check_root
        shift  # Remove the --manage-users argument
        run_ubuntu_user_manager "$@"
        exit 0
        ;;
    --manage-mysql)
        print_info "Running MySQL Administration Toolkit"
        check_root
        shift  # Remove the --manage-mysql argument
        run_mysql_admin_toolkit "$@"
        exit 0
        ;;
    --manage-ftp)
        print_info "Running FTP User Management"
        check_root
        shift  # Remove the --manage-ftp argument
        run_ftp_user_manager "$@"
        exit 0
        ;;
    --user-menu)
        print_info "Showing User Management Menu"
        check_root
        show_user_management_menu
        exit 0
        ;;
    --make-executable)
        print_info "Making scripts executable"
        make_scripts_executable
        exit 0
        ;;
    --run-all)
        print_info "Running all available scripts and tools"
        check_root
        check_ubuntu
        run_all_scripts
        exit 0
        ;;
    --no-git)
        print_info "Skipping Git/GitHub configuration"
        CONFIGURE_GITHUB=false
        make_scripts_executable
        main
        ;;
    --no-monitoring)
        print_info "Skipping monitoring tools installation"
        INSTALL_MONITORING=false
        make_scripts_executable
        main
        ;;
    --no-interactive)
        print_info "Running in non-interactive mode"
        CONFIGURE_GITHUB=false
        INSTALL_MONITORING=false
        make_scripts_executable
        main
        ;;
    "")
        # Show main menu instead of running installation automatically
        show_main_menu
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
