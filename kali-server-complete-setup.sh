#!/bin/bash

# =============================================================================
# Kali Linux Complete Development Environment Setup Script
# =============================================================================
# Description: Automated installation script for MySQL Server, .NET Runtime/SDK,
#              Git/GitHub configuration, system monitoring tools, security tools,
#              and penetration testing utilities for Kali Linux
# Compatible with: Kali Linux 2024.x, 2023.x, 2022.x
# Author: System Administrator
# Version: 2.0
# Features:
#   - MySQL Server installation and configuration
#   - .NET SDK/Runtime installation
#   - Git and GitHub SSH configuration
#   - System monitoring tools (htop, iotop, glances, netdata, etc.)
#   - Enhanced firewall and security (UFW, fail2ban)
#   - Comprehensive penetration testing tools
#   - Development tools and environment setup
#   - System aliases and monitoring scripts
#   - Web app deployment configuration
#   - Service user creation
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
LOG_FILE="/var/log/kali-setup-install.log"
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
            LOG_FILE="./kali-setup-install.log"
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

check_kali() {
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS version"
        exit 1
    fi

    . /etc/os-release
    if [[ "$ID" != "kali" ]]; then
        print_error "This script is designed for Kali Linux only"
        print_info "Detected OS: $ID"
        exit 1
    fi

    print_info "Detected Kali Linux $VERSION_ID"
}

# =============================================================================
# SYSTEM UPDATE AND PREPARATION
# =============================================================================

update_system() {
    print_header "Updating Kali Linux System Packages"

    log_message "Starting Kali Linux system update"

    # Update package lists
    print_info "Updating package lists..."
    apt update -y >> "$LOG_FILE" 2>&1

    # Upgrade existing packages
    print_info "Upgrading existing packages..."
    apt upgrade -y >> "$LOG_FILE" 2>&1

    # Install essential packages for Kali Linux
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
        build-essential \
        python3 \
        python3-pip \
        python3-dev \
        golang-go \
        nodejs \
        npm \
        default-jdk \
        cmake \
        make \
        gcc \
        g++ \
        gdb \
        valgrind >> "$LOG_FILE" 2>&1

    print_success "Kali Linux system update completed"
}

# =============================================================================
# MYSQL INSTALLATION FOR KALI LINUX
# =============================================================================

install_mysql() {
    print_header "Installing MySQL Server on Kali Linux"

    log_message "Starting MySQL installation for Kali Linux"

    # Pre-configuration for MySQL installation
    print_info "Pre-configuring MySQL Server..."
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
        print_warning "Generated random MySQL root password: $MYSQL_ROOT_PASSWORD"
    fi

    # Set debconf values for MySQL installation
    echo "mysql-server mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
    echo "mysql-server mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections

    # Install MySQL Server
    print_info "Installing MySQL Server..."
    apt install -y mysql-server mysql-client >> "$LOG_FILE" 2>&1

    # Start and enable MySQL service
    print_info "Starting and enabling MySQL service..."
    systemctl start mysql
    systemctl enable mysql

    # Secure MySQL installation
    print_info "Securing MySQL installation..."
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='';" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DROP DATABASE IF EXISTS test;" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1

    # Create custom MySQL configuration
    print_info "Creating custom MySQL configuration..."
    cat > /etc/mysql/conf.d/kali-custom.cnf <<EOF
[mysqld]
# Basic Settings
user = mysql
pid-file = /var/run/mysqld/mysqld.pid
socket = /var/run/mysqld/mysqld.sock
port = 3306
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp

# Character Set and Collation
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Networking
bind-address = 0.0.0.0
max_connections = 151

# Query Cache Configuration
query_cache_type = 1
query_cache_size = 16M

# Logging
log_error = /var/log/mysql/error.log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# InnoDB Settings for Kali Linux
innodb_buffer_pool_size = 128M
innodb_log_file_size = 32M
innodb_file_per_table = 1
innodb_flush_method = O_DIRECT

# Binary Logging
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
expire_logs_days = 10
max_binlog_size = 100M

# Security
local_infile = 0
EOF

    # Restart MySQL to apply configuration
    print_info "Restarting MySQL service..."
    systemctl restart mysql

    # Verify MySQL installation
    if systemctl is-active --quiet mysql; then
        print_success "MySQL Server installed and running successfully"
        mysql_version=$(mysql --version | awk '{print $5}' | sed 's/,//')
        print_info "MySQL version: $mysql_version"
    else
        print_error "MySQL service failed to start"
        return 1
    fi

    print_success "MySQL installation completed successfully"
}

# =============================================================================
# .NET INSTALLATION FOR KALI LINUX
# =============================================================================

install_dotnet() {
    print_header "Installing .NET SDK and Runtime on Kali Linux"

    log_message "Starting .NET installation for Kali Linux"

    # Add Microsoft package repository for Debian-based systems
    print_info "Adding Microsoft package repository..."
    wget https://packages.microsoft.com/config/debian/11/packages-microsoft-prod.deb -O packages-microsoft-prod.deb >> "$LOG_FILE" 2>&1
    dpkg -i packages-microsoft-prod.deb >> "$LOG_FILE" 2>&1
    rm packages-microsoft-prod.deb

    # Update package list
    apt update -y >> "$LOG_FILE" 2>&1

    # Install .NET SDK
    if [[ "$INSTALL_DOTNET_SDK" == true ]]; then
        print_info "Installing .NET SDK $DOTNET_VERSION..."
        apt install -y dotnet-sdk-$DOTNET_VERSION >> "$LOG_FILE" 2>&1
        print_success ".NET SDK $DOTNET_VERSION installed successfully"
    fi

    # Install .NET Runtime
    if [[ "$INSTALL_DOTNET_RUNTIME" == true ]]; then
        print_info "Installing .NET Runtime $DOTNET_VERSION..."
        apt install -y dotnet-runtime-$DOTNET_VERSION >> "$LOG_FILE" 2>&1
        print_success ".NET Runtime $DOTNET_VERSION installed successfully"
    fi

    # Install ASP.NET Core Runtime
    print_info "Installing ASP.NET Core Runtime $DOTNET_VERSION..."
    apt install -y aspnetcore-runtime-$DOTNET_VERSION >> "$LOG_FILE" 2>&1

    # Verify installation
    print_info "Verifying .NET installation..."
    if dotnet --version >> "$LOG_FILE" 2>&1; then
        local dotnet_version=$(dotnet --version)
        print_success ".NET version $dotnet_version installed and working correctly"
    else
        print_error "Failed to verify .NET installation"
        return 1
    fi

    print_success ".NET installation completed successfully"
}

# =============================================================================
# GIT AND GITHUB CONFIGURATION FOR KALI
# =============================================================================

# Install Git system-wide
install_git_system() {
    print_info "Installing Git system-wide..."
    
    # Install Git and related tools
    apt install -y git git-lfs >> "$LOG_FILE" 2>&1
    
    # Install GitHub CLI
    read -p "Install GitHub CLI (gh)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        apt update -y >> "$LOG_FILE" 2>&1
        apt install -y gh >> "$LOG_FILE" 2>&1
        print_success "GitHub CLI installed successfully"
    fi
    
    print_success "Git installed system-wide"
}

# Setup GitHub for specific user
setup_user_github() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        print_error "Username required for GitHub setup"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    local user_home=$(eval echo ~$username)
    
    print_info "Setting up GitHub for user: $username"
    
    # Get user information
    read -p "Enter GitHub username for $username: " github_user
    read -p "Enter GitHub email for $username: " github_email
    
    # Configure Git as the user
    print_info "Configuring Git for user $username..."
    sudo -u "$username" git config --global user.name "$github_user"
    sudo -u "$username" git config --global user.email "$github_email"
    sudo -u "$username" git config --global init.defaultBranch main
    
    # Generate SSH key as the user
    print_info "Generating SSH key for $username..."
    local ssh_dir="$user_home/.ssh"
    local ssh_key="$ssh_dir/id_rsa_kali_github"
    
    # Create .ssh directory if it doesn't exist
    sudo -u "$username" mkdir -p "$ssh_dir"
    sudo -u "$username" chmod 700 "$ssh_dir"
    
    # Generate SSH key if it doesn't exist
    if [[ ! -f "$ssh_key" ]]; then
        sudo -u "$username" ssh-keygen -t rsa -b 4096 -C "$github_email" -f "$ssh_key" -N ""
        print_success "SSH key generated for $username"
    else
        print_info "SSH key already exists for $username"
    fi
    
    # Create SSH config
    print_info "Creating SSH config for $username..."
    sudo -u "$username" tee "$ssh_dir/config" > /dev/null <<EOF

# GitHub configuration for Kali Linux
Host github.com
    HostName github.com
    User git
    IdentityFile $ssh_key
    IdentitiesOnly yes
EOF
    
    sudo -u "$username" chmod 600 "$ssh_dir/config"
    
    # Display public key
    print_success "GitHub setup completed for $username!"
    print_warning "Add this SSH key to GitHub account for $username:"
    echo -e "${CYAN}$(cat ${ssh_key}.pub)${NC}"
    print_info "Go to GitHub.com → Settings → SSH and GPG keys → New SSH key"
    
    # Offer to test connection
    read -p "Test GitHub connection now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Testing GitHub SSH connection..."
        if sudo -u "$username" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            print_success "GitHub SSH connection successful!"
        else
            print_warning "GitHub SSH connection test failed. Make sure to add the SSH key to your GitHub account."
        fi
    fi
}

# Create setup script for GitHub configuration
create_github_setup_script() {
    print_info "Creating GitHub setup script..."
    
    cat > /usr/local/bin/setup-user-github <<'EOF'
#!/bin/bash

# Setup GitHub for a specific user on Kali Linux
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root (use sudo)"
    exit 1
fi

if [[ -z "$1" ]]; then
    echo "Usage: $0 <username>"
    echo "Example: $0 kaliuser"
    exit 1
fi

USERNAME="$1"

if ! id "$USERNAME" &>/dev/null; then
    echo "Error: User '$USERNAME' does not exist"
    exit 1
fi

USER_HOME=$(eval echo ~$USERNAME)

echo "Setting up GitHub for user: $USERNAME"

# Get user information
read -p "Enter GitHub username for $USERNAME: " GITHUB_USER
read -p "Enter GitHub email for $USERNAME: " GITHUB_EMAIL

# Configure Git as the user
echo "Configuring Git for user $USERNAME..."
sudo -u "$USERNAME" git config --global user.name "$GITHUB_USER"
sudo -u "$USERNAME" git config --global user.email "$GITHUB_EMAIL"
sudo -u "$USERNAME" git config --global init.defaultBranch main

# Generate SSH key as the user
echo "Generating SSH key for $USERNAME..."
SSH_DIR="$USER_HOME/.ssh"
SSH_KEY="$SSH_DIR/id_rsa_kali_github"

# Create .ssh directory if it doesn't exist
sudo -u "$USERNAME" mkdir -p "$SSH_DIR"
sudo -u "$USERNAME" chmod 700 "$SSH_DIR"

# Generate SSH key if it doesn't exist
if [[ ! -f "$SSH_KEY" ]]; then
    sudo -u "$USERNAME" ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f "$SSH_KEY" -N ""
    echo "SSH key generated for $USERNAME"
else
    echo "SSH key already exists for $USERNAME"
fi

# Create SSH config
echo "Creating SSH config for $USERNAME..."
sudo -u "$USERNAME" tee "$SSH_DIR/config" > /dev/null <<EOL

# GitHub configuration for Kali Linux
Host github.com
    HostName github.com
    User git
    IdentityFile $SSH_KEY
    IdentitiesOnly yes
EOL

sudo -u "$USERNAME" chmod 600 "$SSH_DIR/config"

# Display public key
echo
echo "GitHub setup completed for $USERNAME!"
echo "Add this SSH key to GitHub account for $USERNAME:"
echo "$(cat ${SSH_KEY}.pub)"
echo
echo "Go to GitHub.com → Settings → SSH and GPG keys → New SSH key"
echo
echo "To test connection: sudo -u $USERNAME ssh -T git@github.com"
EOF

    chmod +x /usr/local/bin/setup-user-github
    print_success "GitHub setup script created at /usr/local/bin/setup-user-github"
}

configure_git_github() {
    print_header "Git and GitHub Configuration for Kali Linux"
    
    # Check if Git should be configured
    if [[ "$INSTALL_GIT" != true ]]; then
        print_info "Git installation skipped"
        return 0
    fi
    
    # Install Git system-wide
    install_git_system
    
    # Create the setup script for future use
    create_github_setup_script
    
    # Ask if admin wants to configure GitHub for a user right now
    read -p "Configure GitHub for a specific user now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -p "Enter username to configure GitHub for: " SETUP_USERNAME
        if id "$SETUP_USERNAME" &>/dev/null; then
            setup_user_github "$SETUP_USERNAME"
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
# KALI SECURITY TOOLS INSTALLATION
# =============================================================================

install_kali_security_tools() {
    print_header "Installing Kali Linux Security Tools"

    log_message "Starting Kali Linux security tools installation"

    print_info "Installing comprehensive penetration testing toolkit..."

    # Core penetration testing tools
    print_info "Installing core penetration testing tools..."
    apt install -y \
        metasploit-framework \
        nmap \
        wireshark \
        aircrack-ng \
        john \
        hashcat \
        sqlmap \
        nikto \
        dirb \
        gobuster \
        wpscan \
        burpsuite \
        zaproxy >> "$LOG_FILE" 2>&1

    # Network analysis tools
    print_info "Installing network analysis tools..."
    apt install -y \
        netdiscover \
        masscan \
        zmap \
        hping3 \
        tcpdump \
        tshark \
        ettercap-text-only \
        dsniff \
        arpspoof \
        macchanger >> "$LOG_FILE" 2>&1

    # Web application testing tools
    print_info "Installing web application testing tools..."
    apt install -y \
        wfuzz \
        ffuf \
        dirbuster \
        commix \
        xsser \
        skipfish \
        uniscan >> "$LOG_FILE" 2>&1

    # Forensics tools
    print_info "Installing forensics tools..."
    apt install -y \
        volatility3 \
        autopsy \
        sleuthkit \
        binwalk \
        foremost \
        scalpel \
        ddrescue \
        dc3dd >> "$LOG_FILE" 2>&1

    # Reverse engineering tools
    print_info "Installing reverse engineering tools..."
    apt install -y \
        gdb \
        radare2 \
        ghidra \
        objdump \
        hexdump \
        strings \
        ltrace \
        strace >> "$LOG_FILE" 2>&1

    # Wireless security tools
    print_info "Installing wireless security tools..."
    apt install -y \
        kismet \
        reaver \
        pixiewps \
        fern-wifi-cracker \
        wifite \
        hostapd \
        dnsmasq >> "$LOG_FILE" 2>&1

    # Password attack tools
    print_info "Installing password attack tools..."
    apt install -y \
        hydra \
        medusa \
        patator \
        crowbar \
        thc-pptp-bruter \
        onesixtyone \
        crunch \
        cewl >> "$LOG_FILE" 2>&1

    print_success "Kali Linux security tools installation completed"
}

# =============================================================================
# DEVELOPMENT TOOLS INSTALLATION
# =============================================================================

install_development_tools() {
    print_header "Installing Development Tools for Kali Linux"

    log_message "Starting development tools installation"

    # Container and virtualization tools
    print_info "Installing Docker and virtualization tools..."
    apt install -y \
        docker.io \
        docker-compose \
        vagrant \
        virtualbox \
        qemu-kvm \
        libvirt-daemon-system >> "$LOG_FILE" 2>&1

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    # Infrastructure tools
    print_info "Installing infrastructure tools..."
    apt install -y \
        ansible \
        terraform \
        packer >> "$LOG_FILE" 2>&1

    # Cloud tools
    print_info "Installing cloud tools..."
    # AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" >> "$LOG_FILE" 2>&1
    unzip awscliv2.zip >> "$LOG_FILE" 2>&1
    ./aws/install >> "$LOG_FILE" 2>&1
    rm -rf aws awscliv2.zip

    # Google Cloud SDK
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    apt update -y >> "$LOG_FILE" 2>&1
    apt install -y google-cloud-sdk >> "$LOG_FILE" 2>&1

    # Programming languages and runtimes
    print_info "Installing additional programming languages..."
    apt install -y \
        ruby \
        ruby-dev \
        php \
        php-cli \
        rustc \
        cargo \
        lua5.3 \
        luarocks \
        perl \
        cpanminus >> "$LOG_FILE" 2>&1

    # Python packages for development and security
    print_info "Installing Python packages for security and development..."
    pip3 install \
        requests \
        beautifulsoup4 \
        scrapy \
        paramiko \
        pycryptodome \
        scapy \
        netaddr \
        dnspython \
        python-nmap \
        pwntools \
        ropper \
        capstone \
        keystone-engine \
        unicorn >> "$LOG_FILE" 2>&1

    print_success "Development tools installation completed"
}

# =============================================================================
# SYSTEM MONITORING TOOLS FOR KALI
# =============================================================================

install_monitoring_tools() {
    print_header "Installing System Monitoring Tools for Kali Linux"

    log_message "Installing system monitoring tools for Kali Linux"

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

    # Create monitoring aliases for Kali Linux
    print_info "Creating useful monitoring aliases for Kali Linux..."
    cat >> /root/.bashrc <<EOF

# Kali Linux System Monitoring Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Security Tool Shortcuts
alias nmap_scan='nmap -sS -O -v'
alias vuln_scan='nmap --script vuln'
alias stealth_scan='nmap -sS -T2 -f'
alias quick_scan='nmap -T4 -F'
alias ping_sweep='nmap -sn'

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

# .NET Shortcuts
alias dotnet-new-web='dotnet new webapp'
alias dotnet-new-api='dotnet new webapi'
alias dotnet-watch='dotnet watch run'
alias dotnet-test='dotnet test --logger console'

# MySQL Shortcuts
alias mysql-start='systemctl start mysql'
alias mysql-stop='systemctl stop mysql'
alias mysql-status='systemctl status mysql'
alias mysql-connect='mysql -u root -p'

# Docker Shortcuts (if installed)
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dsp='docker system prune -f'

# Network Analysis
alias ips='ip addr show | grep inet'
alias check_ufw='ufw status verbose'
alias check_fail2ban='fail2ban-client status'
alias check_services='systemctl list-units --type=service --state=running'
EOF

    # Install sensors for temperature monitoring
    print_info "Installing temperature monitoring..."
    apt install -y lm-sensors >> "$LOG_FILE" 2>&1
    sensors-detect --auto >> "$LOG_FILE" 2>&1

    # Create custom monitoring script for Kali
    print_info "Creating custom Kali system monitoring script..."
    cat > /usr/local/bin/kali-sysmon <<'EOF'
#!/bin/bash

echo "================== KALI LINUX SYSTEM MONITOR =================="
echo "Hostname: $(hostname)"
echo "Kali Version: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

echo "==================== MEMORY USAGE ===================="
free -h

echo

echo "==================== DISK USAGE ===================="
df -h | grep -vE '^Filesystem|tmpfs|cdrom'

echo

echo "==================== NETWORK INTERFACES ===================="
ip addr show | grep -E '^[0-9]+:|inet ' | grep -v '127.0.0.1'

echo

echo "==================== SECURITY SERVICES ===================="
echo "MySQL: $(systemctl is-active mysql 2>/dev/null || echo 'not installed')"
echo "SSH: $(systemctl is-active ssh 2>/dev/null || echo 'not active')"
echo "UFW: $(systemctl is-active ufw 2>/dev/null || echo 'not active')"
echo "Fail2ban: $(systemctl is-active fail2ban 2>/dev/null || echo 'not installed')"

echo

echo "==================== AVAILABLE SECURITY TOOLS ===================="
command -v nmap >/dev/null && echo "✓ Nmap: $(nmap --version 2>/dev/null | head -1 | cut -d' ' -f3)" || echo "✗ Nmap not found"
command -v msfconsole >/dev/null && echo "✓ Metasploit available" || echo "✗ Metasploit not found"
command -v sqlmap >/dev/null && echo "✓ SQLMap available" || echo "✗ SQLMap not found"
command -v john >/dev/null && echo "✓ John the Ripper available" || echo "✗ John the Ripper not found"
command -v hashcat >/dev/null && echo "✓ Hashcat available" || echo "✗ Hashcat not found"

echo

echo "==================== TOP PROCESSES BY CPU ===================="
ps aux --sort=-%cpu | head -6

echo

echo "==================== TOP PROCESSES BY MEMORY ===================="
ps aux --sort=-%mem | head -6

echo

echo "==================== NETWORK CONNECTIONS ===================="
netstat -tuln | grep LISTEN | wc -l
echo "Listening ports: $(netstat -tuln | grep LISTEN | wc -l)"

echo

echo "==================== SYSTEM LOAD ===================="
cat /proc/loadavg

echo

echo "==================== NETDATA WEB INTERFACE ===================="
echo "Access Netdata at: http://$(hostname -I | awk '{print $1}'):19999"
echo "=============================================================="
EOF

    chmod +x /usr/local/bin/kali-sysmon

    print_success "System monitoring tools installation completed"
    print_info "Use 'kali-sysmon' command for quick system overview"
    print_info "Use 'glances' for real-time system monitoring"
}

# =============================================================================
# ENHANCED FIREWALL CONFIGURATION FOR KALI
# =============================================================================

configure_firewall() {
    print_header "Configuring Enhanced Firewall for Kali Linux"

    log_message "Configuring enhanced firewall rules for Kali Linux"

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

    # Allow SSH with rate limiting
    print_info "Enabling SSH with rate limiting..."
    ufw limit ssh >> "$LOG_FILE" 2>&1

    # Allow HTTP and HTTPS
    print_info "Enabling HTTP and HTTPS..."
    ufw allow 80/tcp >> "$LOG_FILE" 2>&1
    ufw allow 443/tcp >> "$LOG_FILE" 2>&1

    # Allow development ports
    ufw allow 3000:3999/tcp >> "$LOG_FILE" 2>&1  # Development servers
    ufw allow 5000:5999/tcp >> "$LOG_FILE" 2>&1  # .NET applications
    ufw allow 8000:8999/tcp >> "$LOG_FILE" 2>&1  # Web development

    # Allow monitoring tools
    ufw allow 19999/tcp >> "$LOG_FILE" 2>&1  # Netdata

    # Allow MySQL only from localhost for security
    ufw allow from 127.0.0.1 to any port 3306 >> "$LOG_FILE" 2>&1

    # Block common attack ports
    print_info "Blocking common attack ports..."
    ufw deny 23/tcp >> "$LOG_FILE" 2>&1   # Telnet
    ufw deny 135/tcp >> "$LOG_FILE" 2>&1  # RPC
    ufw deny 139/tcp >> "$LOG_FILE" 2>&1  # NetBIOS
    ufw deny 445/tcp >> "$LOG_FILE" 2>&1  # SMB
    ufw deny 1433/tcp >> "$LOG_FILE" 2>&1 # SQL Server
    ufw deny 1521/tcp >> "$LOG_FILE" 2>&1 # Oracle
    ufw deny 5432/tcp >> "$LOG_FILE" 2>&1 # PostgreSQL

    # Configure fail2ban
    print_info "Configuring fail2ban..."
    cat > /etc/fail2ban/jail.d/kali-custom.conf <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[mysql]
enabled = true
port = 3306
logpath = /var/log/mysql/error.log
maxretry = 3

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 2

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
logpath = /var/log/nginx/error.log
maxretry = 2
EOF

    # Start and enable fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban

    # Enable automatic security updates (optional)
    read -p "Enable automatic security updates? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Enabling automatic security updates..."
        apt install -y unattended-upgrades >> "$LOG_FILE" 2>&1
        dpkg-reconfigure -plow unattended-upgrades
        print_success "Automatic security updates enabled"
    fi

    print_success "Enhanced firewall configuration completed"
    print_info "UFW Status:"
    ufw status verbose
}

# =============================================================================
# SERVICE USER CREATION FOR KALI
# =============================================================================

create_service_user() {
    print_header "Creating Service User for Kali Linux Applications"

    log_message "Creating service user for Kali Linux applications"

    local username="kaliapp"
    local home_dir="/home/$username"

    # Create user if it doesn't exist
    if ! id "$username" &>/dev/null; then
        print_info "Creating service user: $username"
        useradd -m -s /bin/bash "$username"
        print_success "Service user $username created"
    else
        print_info "Service user $username already exists"
    fi

    # Create directories
    print_info "Creating application directories..."
    mkdir -p "$home_dir"/{apps,logs,scripts,tools}
    mkdir -p /var/www/kali-apps
    mkdir -p /var/log/kali-apps

    # Set proper permissions
    chown -R "$username:$username" "$home_dir"
    chown -R "$username:$username" /var/www/kali-apps
    chown -R "$username:$username" /var/log/kali-apps

    print_success "Service user configuration completed"
}

# =============================================================================
# DATABASE USER CREATION
# =============================================================================

create_database_user() {
    print_header "Creating Database Users"

    log_message "Creating database users"

    # Check if MySQL is running
    if ! systemctl is-active --quiet mysql; then
        print_warning "MySQL is not running. Skipping database user creation."
        return 0
    fi

    # Create application database user
    local db_user="kaliapp"
    local db_password=$(openssl rand -base64 16)

    print_info "Creating database user: $db_user"
    
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$db_password';" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT CREATE, ALTER, SELECT, INSERT, UPDATE, DELETE ON *.* TO '$db_user'@'localhost';" >> "$LOG_FILE" 2>&1
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;" >> "$LOG_FILE" 2>&1

    print_success "Database user created successfully"
    print_warning "Database credentials - User: $db_user, Password: $db_password"

    # Save credentials to file
    echo "MySQL Application User Credentials" > /root/.mysql_app_credentials
    echo "Username: $db_user" >> /root/.mysql_app_credentials
    echo "Password: $db_password" >> /root/.mysql_app_credentials
    echo "Created: $(date)" >> /root/.mysql_app_credentials
    chmod 600 /root/.mysql_app_credentials

    print_info "Database credentials saved to /root/.mysql_app_credentials"
}

# =============================================================================
# SYSTEMD TEMPLATE CREATION
# =============================================================================

create_systemd_template() {
    print_header "Creating Systemd Service Template"

    log_message "Creating systemd service template"

    # Create systemd service template for .NET applications
    print_info "Creating systemd service template for .NET applications..."
    cat > /etc/systemd/system/dotnet-app.service.template <<EOF
[Unit]
Description=.NET Web Application
After=network.target

[Service]
Type=notify
# will set the Current Working Directory (CWD)
WorkingDirectory=/var/www/dotnet-apps/APP_NAME
# systemd will run this executable to start the service
ExecStart=/usr/bin/dotnet APP_NAME.dll
# to query logs using journalctl, set a logical name here
SyslogIdentifier=dotnet-APP_NAME
# Use your username to keep things simple.
# If you pick a different user, make sure dotnet and all permissions are set correctly to run the app
# To update permissions, use 'chown -R www-data:www-data /var/www/dotnet-apps/APP_NAME'
User=kaliapp
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false
# This environment variable is necessary for Kestrel to work correctly when running behind nginx
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=ASPNETCORE_URLS=http://localhost:APP_PORT

# ensure the service restarts after crashing
Restart=always
# amount of time to wait before restarting the service
RestartSec=5

# copied from dotnet documentation at
# https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/linux-nginx
KillSignal=SIGINT
TimeoutStopSec=30
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

    print_success "Systemd service template created"
    print_info "Template location: /etc/systemd/system/dotnet-app.service.template"
}

# =============================================================================
# SYSTEM INFORMATION DISPLAY
# =============================================================================

display_system_info() {
    print_header "Kali Linux Installation Summary"

    echo -e "${WHITE}System Information:${NC}"
    echo -e "${WHITE}==================${NC}"
    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    echo -e "${WHITE}Operating System:${NC} $(lsb_release -d | cut -f2)"
    echo -e "${WHITE}Kernel Version:${NC} $(uname -r)"
    echo -e "${WHITE}Architecture:${NC} $(uname -m)"
    echo -e "${WHITE}Current User:${NC} $(whoami)"
    echo

    echo -e "${WHITE}Installed Software:${NC}"
    echo -e "${WHITE}==================${NC}"
    
    if command -v mysql &> /dev/null; then
        mysql_version=$(mysql --version | awk '{print $5}' | sed 's/,//')
        echo -e "${WHITE}MySQL Server:${NC} $mysql_version"
        echo -e "${WHITE}MySQL Status:${NC} $(systemctl is-active mysql)"
        if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
            echo -e "${WHITE}MySQL Root Password:${NC} $MYSQL_ROOT_PASSWORD"
        fi
    else
        echo -e "${WHITE}MySQL Server:${NC} Not installed"
    fi
    
    if command -v dotnet &> /dev/null; then
        dotnet_version=$(dotnet --version)
        echo -e "${WHITE}.NET SDK:${NC} $dotnet_version"
        echo -e "${WHITE}.NET Status:${NC} Installed and working"
    else
        echo -e "${WHITE}.NET SDK:${NC} Not installed"
    fi

    if [[ "$CONFIGURE_GITHUB" == true ]]; then
        echo -e "${WHITE}Git Configuration:${NC} Completed"
        echo -e "${WHITE}GitHub Setup Script:${NC} /usr/local/bin/setup-user-github"
    fi

    if [[ "$INSTALL_MONITORING" == true ]]; then
        echo -e "${WHITE}System Monitoring:${NC} Installed"
        echo -e "${WHITE}Monitoring Script:${NC} /usr/local/bin/kali-sysmon"
        echo -e "${WHITE}Netdata Dashboard:${NC} http://localhost:19999"
    fi

    # Display key security tools status
    echo -e "${WHITE}Security Tools Status:${NC}"
    command -v nmap &> /dev/null && echo -e "  ${GREEN}✓${NC} Nmap: $(nmap --version 2>/dev/null | head -1 | cut -d' ' -f3)" || echo -e "  ${RED}✗${NC} Nmap: Not installed"
    command -v msfconsole &> /dev/null && echo -e "  ${GREEN}✓${NC} Metasploit: Available" || echo -e "  ${RED}✗${NC} Metasploit: Not installed"
    command -v john &> /dev/null && echo -e "  ${GREEN}✓${NC} John the Ripper: Available" || echo -e "  ${RED}✗${NC} John the Ripper: Not installed"
    command -v hashcat &> /dev/null && echo -e "  ${GREEN}✓${NC} Hashcat: Available" || echo -e "  ${RED}✗${NC} Hashcat: Not installed"

    echo
    if [[ "$INSTALL_MONITORING" == true ]]; then
        echo "System monitoring tools installed:"
        echo "- htop, iotop, nmon, sysstat"
        echo "- nethogs, iftop, tcptrack, bmon"
        echo "- vnstat, glances, ncdu, dstat"
        echo "- Custom aliases added to /root/.bashrc"
        echo "- Kali system monitoring script: /usr/local/bin/kali-sysmon"
        echo "- Temperature monitoring: sensors"
        echo ""
        echo "Quick Commands:"
        echo "- 'kali-sysmon' - System overview"
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
    echo "  • Ports 3000-3999 (Development) - Enabled"
    echo "  • Ports 5000-5999 (.NET Applications) - Enabled"
    echo "  • Ports 8000-8999 (Web Development) - Enabled"
    echo "  • Port 3306 (MySQL) - Localhost only"
    echo "  • Port 19999 (Netdata Monitoring) - Enabled"
    echo
    echo "Important Files:"
    echo "================"
    echo "Installation Log: $LOG_FILE"
    echo "Systemd Template: /etc/systemd/system/dotnet-app.service.template"
    echo "Fail2ban Config: /etc/fail2ban/jail.d/kali-custom.conf"
    echo "Firewall Rules: ufw status verbose"
    echo
    echo "Security Tool Aliases:"
    echo "====================="
    echo "- 'nmap_scan' - Basic Nmap scan"
    echo "- 'vuln_scan' - Vulnerability scan"
    echo "- 'stealth_scan' - Stealth scan"
    echo "- 'quick_scan' - Quick port scan"
    echo "- 'ping_sweep' - Network discovery"
    echo
    echo "Next Steps:"
    echo "==========="
    echo "1. Secure your MySQL installation further if needed"
    echo "2. Configure your .NET application"
    echo "3. Set up SSL certificates for HTTPS"
    echo "4. Configure backup strategies"
    echo "5. Monitor system performance with installed tools"
    echo "6. Explore installed penetration testing tools"
    echo "7. Run 'kali-sysmon' to check system status"
}

# =============================================================================
# INTERACTIVE CONFIGURATION
# =============================================================================

interactive_config() {
    clear
    print_header "Kali Linux Complete Setup - Interactive Configuration"
    
    echo -e "${WHITE}This script will set up a complete development and security testing environment on Kali Linux.${NC}"
    echo
    echo -e "${CYAN}Components to be installed:${NC}"
    echo -e "${WHITE}• MySQL Server $MYSQL_VERSION with security hardening${NC}"
    echo -e "${WHITE}• .NET SDK/Runtime $DOTNET_VERSION for web development${NC}"
    echo -e "${WHITE}• Comprehensive penetration testing tools${NC}"
    echo -e "${WHITE}• Development environment (Docker, cloud tools, languages)${NC}"
    echo -e "${WHITE}• System monitoring tools and web dashboard${NC}"
    echo -e "${WHITE}• Enhanced security (UFW firewall, fail2ban)${NC}"
    echo -e "${WHITE}• Git/GitHub SSH configuration${NC}"
    echo -e "${WHITE}• System aliases and utilities${NC}"
    echo

    # MySQL root password
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        read -s -p "Enter MySQL root password (leave blank for auto-generated): " mysql_pass
        echo
        if [[ -n "$mysql_pass" ]]; then
            MYSQL_ROOT_PASSWORD="$mysql_pass"
        fi
    fi

    # .NET SDK installation
    read -p "Install .NET SDK? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_DOTNET_SDK=false
    fi

    # .NET Runtime installation
    read -p "Install .NET Runtime? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_DOTNET_RUNTIME=false
    fi

    # Git and GitHub configuration
    read -p "Configure Git and GitHub? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        CONFIGURE_GITHUB=false
    fi

    # System monitoring tools
    read -p "Install system monitoring tools? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        INSTALL_MONITORING=false
    fi

    print_info "Configuration completed"
    return 0
}

# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

main() {
    print_header "Kali Linux Complete Development Environment Setup"
    print_info "Main function started successfully"

    # Create log file
    mkdir -p /var/log
    touch "$LOG_FILE"

    log_message "Starting Kali Linux installation process"

    # Pre-installation checks
    print_info "Performing pre-installation checks..."
    check_root
    check_kali
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
    
    # Install security tools
    print_info "Installing Kali security tools..."
    install_kali_security_tools
    print_success "Security tools installation completed"
    
    # Install development tools
    print_info "Installing development tools..."
    install_development_tools
    print_success "Development tools installation completed"
    
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

    log_message "Kali Linux installation process completed successfully"

    print_success "Installation completed! Please reboot the system to ensure all changes take effect."
    
    return 0
}

# =============================================================================
# INTEGRATED SCRIPT FUNCTIONS
# =============================================================================

# Function to make scripts executable
make_scripts_executable() {
    print_header "Making Scripts Executable"
    
    local scripts=(
        "kali-server-complete-setup.sh"
        "ubuntu-user-manager.sh"
        "mysql-admin-toolkit.sh"
        "ftp-user-manager.sh"
        "make-executable.sh"
        "test-installation.sh"
        "install.sh"
        "clone-and-run.sh"
        "dotnet-web-app-deployer.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            print_info "Making $script executable..."
            chmod +x "$script" 2>/dev/null || print_warning "Could not make $script executable"
            if [[ -x "$script" ]]; then
                print_success "$script is now executable"
            else
                print_warning "$script could not be made executable"
            fi
        else
            print_info "$script not found (skipping)"
        fi
    done
    
    print_success "Script executable permissions updated"
}

# Function to run Ubuntu user manager (adapted for Kali)
run_ubuntu_user_manager() {
    print_header "Kali Linux User Management"
    
    if [[ -f "ubuntu-user-manager.sh" ]]; then
        print_info "Running User Manager (adapted for Kali Linux)..."
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
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Kali Linux System User Management                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} MySQL User Management                                                                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} FTP User Management                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}SCRIPT MANAGEMENT${NC}                                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Make All Scripts Executable                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Return to Main Menu                                                                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} Exit                                                                                ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -n "Select an option (1-6): "
        read -r choice

        case $choice in
            1)
                print_info "Starting Kali Linux System User Management..."
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
# .NET WEB APP DEPLOYMENT FUNCTIONS (Simplified for Kali)
# =============================================================================

# Simple MySQL uninstall function for Kali
uninstall_mysql() {
    print_header "MySQL Uninstallation for Kali Linux"
    
    print_warning "This will remove MySQL Server and optionally delete all data!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "MySQL uninstallation cancelled"
        return 0
    fi
    
    read -p "Delete all MySQL data? (y/N): " -n 1 -r
    echo
    local delete_data=false
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        delete_data=true
    fi
    
    print_info "Stopping MySQL service..."
    systemctl stop mysql 2>/dev/null || true
    
    print_info "Removing MySQL packages..."
    apt purge -y mysql-server mysql-client mysql-common >> "$LOG_FILE" 2>&1
    apt autoremove -y >> "$LOG_FILE" 2>&1
    
    if [[ "$delete_data" == true ]]; then
        print_info "Removing MySQL data..."
        rm -rf /var/lib/mysql
        rm -rf /etc/mysql
        rm -rf /var/log/mysql
    fi
    
    print_success "MySQL uninstallation completed"
}

# Simple dotnet deployment check
check_dotnet_system_requirements() {
    print_header "Checking .NET System Requirements"
    
    if command -v dotnet &> /dev/null; then
        print_success ".NET is installed: $(dotnet --version)"
    else
        print_error ".NET is not installed"
        return 1
    fi
    
    if command -v nginx &> /dev/null; then
        print_success "Nginx is available"
    else
        print_warning "Nginx is not installed"
    fi
    
    print_success "System requirements check completed"
}

# =============================================================================
# MAIN MENU SYSTEM
# =============================================================================

show_main_menu() {
    while true; do
        clear
        print_header "Kali Linux Complete Setup - Main Menu"
        echo
        echo -e "${WHITE}Please select an option:${NC}"
        echo
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}INSTALLATION OPTIONS${NC}                                                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Complete Kali Setup (Interactive)                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Complete Kali Setup (Automatic)                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Install MySQL Only                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Install .NET Only                                                                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Configure Git/GitHub Only                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} Install Monitoring Tools Only                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} Configure Security/Firewall Only                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Install Security Tools Only                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${PURPLE}USER MANAGEMENT OPTIONS${NC}                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Manage Kali Users                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}10)${NC} Manage MySQL Users                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}11)${NC} Manage FTP Users                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}12)${NC} Show User Management Menu                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}SCRIPT MANAGEMENT OPTIONS${NC}                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}13)${NC} Make All Scripts Executable                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}14)${NC} Run All Available Scripts                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}15)${NC} Test Installation Scripts                                                          ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}INFORMATION OPTIONS${NC}                                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}16)${NC} Show Help/Usage Information                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}17)${NC} Display System Information                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}18)${NC} Uninstall MySQL                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}19)${NC} Check .NET Requirements                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}0)${NC} Exit                                                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -n "Select an option (0-19): "
        read -r choice

        case $choice in
            1)
                print_info "Starting Complete Kali Setup (Interactive)..."
                make_scripts_executable
                main
                read -p "Press Enter to continue..." && continue
                ;;
            2)
                print_info "Starting Complete Kali Setup (Automatic)..."
                CONFIGURE_GITHUB=false
                INSTALL_MONITORING=false
                make_scripts_executable
                main
                read -p "Press Enter to continue..." && continue
                ;;
            3)
                print_info "Installing MySQL Only..."
                check_root
                check_kali
                update_system
                install_mysql
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            4)
                print_info "Installing .NET Only..."
                check_root
                check_kali
                update_system
                install_dotnet
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            5)
                print_info "Configuring Git and GitHub Only..."
                check_root
                check_kali
                CONFIGURE_GITHUB=true
                update_system
                configure_git_github
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            6)
                print_info "Installing System Monitoring Tools Only..."
                check_root
                check_kali
                INSTALL_MONITORING=true
                update_system
                install_monitoring_tools
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            7)
                print_info "Configuring Firewall and Security Only..."
                check_root
                check_kali
                update_system
                configure_firewall
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            8)
                print_info "Installing Security Tools Only..."
                check_root
                check_kali
                update_system
                install_kali_security_tools
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            9)
                print_info "Starting Kali User Management..."
                check_root
                run_ubuntu_user_manager
                read -p "Press Enter to continue..." && continue
                ;;
            10)
                print_info "Starting MySQL Administration Toolkit..."
                check_root
                run_mysql_admin_toolkit
                read -p "Press Enter to continue..." && continue
                ;;
            11)
                print_info "Starting FTP User Management..."
                check_root
                run_ftp_user_manager
                read -p "Press Enter to continue..." && continue
                ;;
            12)
                print_info "Showing User Management Menu..."
                check_root
                show_user_management_menu
                read -p "Press Enter to continue..." && continue
                ;;
            13)
                print_info "Making All Scripts Executable..."
                make_scripts_executable
                read -p "Press Enter to continue..." && continue
                ;;
            14)
                print_info "Running All Available Scripts..."
                check_root
                check_kali
                run_all_scripts
                read -p "Press Enter to continue..." && continue
                ;;
            15)
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
            16)
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
                echo "  --security-tools    Install Kali security tools only"
                echo "  --uninstall-mysql   Uninstall MySQL with optional data removal"
                echo "  --no-git            Skip Git/GitHub configuration"
                echo "  --no-monitoring     Skip monitoring tools installation"
                echo "  --no-interactive    Skip all interactive prompts"
                echo
                echo "USER MANAGEMENT OPTIONS:"
                echo "  --manage-users      Run Kali user management"
                echo "  --manage-mysql      Run MySQL administration toolkit"
                echo "  --manage-ftp        Run FTP user management"
                echo "  --user-menu         Show user management menu"
                echo
                echo "SCRIPT MANAGEMENT OPTIONS:"
                echo "  --make-executable   Make all scripts in directory executable"
                echo "  --run-all           Run all available scripts and tools"
                echo
                echo "AVAILABLE SCRIPTS:"
                echo "  • kali-server-complete-setup.sh - Complete Kali setup script"
                echo "  • ubuntu-user-manager.sh     - System user management (compatible with Kali)"
                echo "  • mysql-admin-toolkit.sh     - MySQL administration toolkit"
                echo "  • ftp-user-manager.sh        - FTP server and user management"
                echo "  • make-executable.sh         - Script permission manager"
                echo
                echo "EXAMPLES:"
                echo "  $0                           # Show main menu"
                echo "  $0 --auto                    # Automatic installation"
                echo "  $0 --make-executable         # Make all scripts executable"
                echo "  $0 --manage-users            # Manage Kali users"
                echo "  $0 --manage-mysql            # Manage MySQL administration"
                echo "  $0 --manage-ftp              # Manage FTP users"
                echo "  $0 --user-menu               # Show user management menu"
                echo "  $0 --run-all                 # Run everything"
                read -p "Press Enter to continue..." && continue
                ;;
            17)
                print_info "Displaying System Information..."
                display_system_info
                read -p "Press Enter to continue..." && continue
                ;;
            18)
                print_info "Starting MySQL Uninstallation..."
                check_root
                uninstall_mysql
                read -p "Press Enter to continue..." && continue
                ;;
            19)
                print_info "Checking .NET Requirements..."
                check_dotnet_system_requirements
                read -p "Press Enter to continue..." && continue
                ;;
            0)
                print_info "Exiting Kali Linux Setup Script..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-19."
                sleep 2
                ;;
        esac
    done
}

# =============================================================================
# COMMAND-LINE ARGUMENT PROCESSING
# =============================================================================

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
        echo "  --security-tools    Install Kali security tools only"
        echo "  --uninstall-mysql   Uninstall MySQL with optional data removal"
        echo "  --no-git            Skip Git/GitHub configuration"
        echo "  --no-monitoring     Skip monitoring tools installation"
        echo "  --no-interactive    Skip all interactive prompts"
        echo
        echo "USER MANAGEMENT OPTIONS:"
        echo "  --manage-users      Run Kali user management"
        echo "  --manage-mysql      Run MySQL administration toolkit"
        echo "  --manage-ftp        Run FTP user management"
        echo "  --user-menu         Show user management menu"
        echo
        echo "SCRIPT MANAGEMENT OPTIONS:"
        echo "  --make-executable   Make all scripts in directory executable"
        echo "  --run-all           Run all available scripts and tools"
        echo
        echo "AVAILABLE SCRIPTS:"
        echo "  • kali-server-complete-setup.sh - Complete Kali setup script"
        echo "  • ubuntu-user-manager.sh     - System user management (compatible with Kali)"
        echo "  • mysql-admin-toolkit.sh     - MySQL administration toolkit"
        echo "  • ftp-user-manager.sh        - FTP server and user management"
        echo "  • make-executable.sh         - Script permission manager"
        echo
        echo "EXAMPLES:"
        echo "  $0                           # Show main menu"
        echo "  $0 --auto                    # Automatic installation"
        echo "  $0 --mysql-password mypass   # Set MySQL root password"
        echo "  $0 --make-executable         # Make all scripts executable"
        echo "  $0 --manage-users            # Manage Kali users"
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
        check_kali
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
        check_kali
        update_system
        install_dotnet
        display_system_info
        exit 0
        ;;
    --git-only)
        print_info "Configuring Git and GitHub only"
        check_root
        check_kali
        CONFIGURE_GITHUB=true
        update_system
        configure_git_github
        display_system_info
        exit 0
        ;;
    --monitoring-only)
        print_info "Installing system monitoring tools only"
        check_root
        check_kali
        INSTALL_MONITORING=true
        update_system
        install_monitoring_tools
        display_system_info
        exit 0
        ;;
    --security-only)
        print_info "Configuring firewall and security only"
        check_root
        check_kali
        update_system
        configure_firewall
        display_system_info
        exit 0
        ;;
    --security-tools)
        print_info "Installing Kali security tools only"
        check_root
        check_kali
        update_system
        install_kali_security_tools
        display_system_info
        exit 0
        ;;
    --uninstall-mysql)
        print_info "Uninstalling MySQL with optional data removal"
        check_root
        uninstall_mysql
        exit 0
        ;;
    --manage-users)
        print_info "Running Kali User Management"
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
        check_kali
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