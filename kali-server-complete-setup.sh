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
#   - .NET SDK/Runtime installation (version 8.0 LTS)
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
INSTALL_SECURITY_TOOLS=true
INSTALL_DEV_TOOLS=true
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

    # Set MySQL root password with user choice
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        echo
        print_info "MySQL Root Password Setup for Kali Linux"
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

    # Pre-configure MySQL installation for Debian-based Kali
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

    # Create MySQL configuration file optimized for Kali
    print_info "Creating MySQL configuration for optimal performance and UTF-8 support..."
    cat > /etc/mysql/conf.d/kali-custom.cnf <<EOF
[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
# Performance configuration for Kali Linux
max_connections = 150
innodb_buffer_pool_size = 128M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
# Security settings - bind to localhost for security testing environment
bind-address = 127.0.0.1
EOF

    # Restart MySQL to apply configuration
    systemctl restart mysql

    print_success "MySQL Server installation completed with Kali-optimized configuration"

    # Display MySQL information
    print_info "MySQL Status:"
    systemctl status mysql --no-pager -l
}

# =============================================================================
# KALI LINUX SECURITY TOOLS INSTALLATION
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
        wapiti \
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

configure_git_github() {
    print_header "Configuring Git and GitHub for Kali Linux"

    log_message "Starting Git and GitHub configuration"

    # Check if Git is installed
    if ! command -v git &> /dev/null; then
        print_info "Installing Git..."
        apt install -y git >> "$LOG_FILE" 2>&1
    fi

    # Get user information if not provided
    if [[ -z "$GITHUB_USERNAME" ]]; then
        echo -e "${WHITE}Enter your GitHub username: ${NC}\c"
        read -r GITHUB_USERNAME
    fi

    if [[ -z "$GITHUB_EMAIL" ]]; then
        echo -e "${WHITE}Enter your GitHub email: ${NC}\c"
        read -r GITHUB_EMAIL
    fi

    # Configure Git
    print_info "Configuring Git with user information..."
    git config --global user.name "$GITHUB_USERNAME"
    git config --global user.email "$GITHUB_EMAIL"
    git config --global init.defaultBranch main

    # Generate SSH key
    print_info "Generating SSH key for GitHub..."
    ssh_key_path="$HOME/.ssh/id_rsa_kali_github"
    
    if [[ ! -f "$ssh_key_path" ]]; then
        ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f "$ssh_key_path" -N ""
        print_success "SSH key generated: $ssh_key_path"
    else
        print_info "SSH key already exists: $ssh_key_path"
    fi

    # Add SSH key to ssh-agent
    print_info "Adding SSH key to ssh-agent..."
    eval "$(ssh-agent -s)" >> "$LOG_FILE" 2>&1
    ssh-add "$ssh_key_path" >> "$LOG_FILE" 2>&1

    # Create SSH config
    print_info "Creating SSH config for GitHub..."
    cat >> "$HOME/.ssh/config" <<EOF

# GitHub configuration for Kali Linux
Host github.com
    HostName github.com
    User git
    IdentityFile $ssh_key_path
    IdentitiesOnly yes
EOF

    # Display public key
    print_success "Git and GitHub configuration completed!"
    print_warning "Add this SSH key to your GitHub account:"
    echo -e "${CYAN}$(cat ${ssh_key_path}.pub)${NC}"
    print_info "Go to GitHub.com → Settings → SSH and GPG keys → New SSH key"
}

# =============================================================================
# MONITORING TOOLS FOR KALI LINUX
# =============================================================================

install_monitoring_tools() {
    print_header "Installing System Monitoring Tools for Kali Linux"

    log_message "Starting monitoring tools installation"

    # Install system monitoring tools
    print_info "Installing system monitoring tools..."
    apt install -y \
        htop \
        iotop \
        nethogs \
        iftop \
        nload \
        bmon \
        vnstat \
        glances \
        ncdu \
        dstat \
        sysstat \
        lsof \
        strace \
        tcpdump >> "$LOG_FILE" 2>&1

    # Install Netdata for web-based monitoring
    print_info "Installing Netdata for web-based monitoring..."
    wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh >> "$LOG_FILE" 2>&1
    sh /tmp/netdata-kickstart.sh --dont-wait --disable-telemetry >> "$LOG_FILE" 2>&1

    # Create custom monitoring script for Kali
    print_info "Creating custom Kali system monitor..."
    cat > /usr/local/bin/kali-sysmon <<'EOF'
#!/bin/bash

# Kali Linux System Monitor
echo "================== KALI LINUX SYSTEM MONITOR =================="
echo "Hostname: $(hostname)"
echo "Kali Version: $(lsb_release -d | cut -f2)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo

echo "==================== MEMORY USAGE ===================="
free -h

echo

echo "==================== DISK USAGE ===================="
df -h | grep -E '^/dev/'

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
command -v nmap >/dev/null && echo "✓ Nmap available" || echo "✗ Nmap not found"
command -v metasploit >/dev/null && echo "✓ Metasploit available" || echo "✗ Metasploit not found"
command -v sqlmap >/dev/null && echo "✓ SQLMap available" || echo "✗ SQLMap not found"
command -v john >/dev/null && echo "✓ John the Ripper available" || echo "✗ John the Ripper not found"
command -v hashcat >/dev/null && echo "✓ Hashcat available" || echo "✗ Hashcat not found"

echo

echo "==================== NETDATA WEB INTERFACE ===================="
echo "Access Netdata at: http://$(hostname -I | awk '{print $1}'):19999"
echo "=============================================================="
EOF

    chmod +x /usr/local/bin/kali-sysmon

    print_success "Monitoring tools installation completed"
    print_info "Use 'kali-sysmon' to view system status"
    print_info "Access Netdata web interface at: http://localhost:19999"
}

# =============================================================================
# FIREWALL AND SECURITY CONFIGURATION FOR KALI
# =============================================================================

configure_firewall() {
    print_header "Configuring Firewall and Security for Kali Linux"

    log_message "Starting firewall and security configuration"

    # Install UFW
    print_info "Installing UFW (Uncomplicated Firewall)..."
    apt install -y ufw >> "$LOG_FILE" 2>&1

    # Configure UFW
    print_info "Configuring UFW rules..."
    ufw --force reset >> "$LOG_FILE" 2>&1
    ufw default deny incoming >> "$LOG_FILE" 2>&1
    ufw default allow outgoing >> "$LOG_FILE" 2>&1

    # Allow SSH
    ufw allow ssh >> "$LOG_FILE" 2>&1

    # Allow development ports
    ufw allow 3000:3999/tcp >> "$LOG_FILE" 2>&1  # Development servers
    ufw allow 5000:5999/tcp >> "$LOG_FILE" 2>&1  # .NET applications
    ufw allow 8000:8999/tcp >> "$LOG_FILE" 2>&1  # Web development

    # Allow monitoring tools
    ufw allow 19999/tcp >> "$LOG_FILE" 2>&1  # Netdata

    # Allow MySQL only from localhost
    ufw allow from 127.0.0.1 to any port 3306 >> "$LOG_FILE" 2>&1

    # Enable UFW
    ufw --force enable >> "$LOG_FILE" 2>&1

    # Install and configure fail2ban
    print_info "Installing and configuring fail2ban..."
    apt install -y fail2ban >> "$LOG_FILE" 2>&1

    # Create fail2ban configuration for Kali
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
EOF

    # Start and enable fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban

    print_success "Firewall and security configuration completed"
    print_info "UFW status:"
    ufw status verbose
}

# =============================================================================
# SERVICE USER CREATION FOR KALI
# =============================================================================

create_service_user() {
    print_header "Creating Service User for Kali Linux Applications"

    log_message "Creating service user for applications"

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
# SYSTEM ALIASES FOR KALI LINUX
# =============================================================================

create_system_aliases() {
    print_header "Creating System Aliases for Kali Linux"

    log_message "Creating system aliases"

    # Create aliases file
    cat > /etc/profile.d/kali-aliases.sh <<'EOF'
#!/bin/bash

# =============================================================================
# Kali Linux System Aliases
# =============================================================================

# Security Tool Shortcuts
alias nmap_scan='nmap -sS -O -v'
alias vuln_scan='nmap --script vuln'
alias stealth_scan='nmap -sS -T2 -f'
alias quick_scan='nmap -T4 -F'
alias ping_sweep='nmap -sn'

# System Shortcuts
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# System Monitoring
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'
alias cpuinfo='lscpu'
alias diskspace='df -H'
alias ksysmon='kali-sysmon'

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

# Git Shortcuts
alias gst='git status'
alias glog='git log --oneline --graph --decorate'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gp='git push'
alias gpl='git pull'

# Docker Shortcuts (if installed)
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dsp='docker system prune -f'

# Network Analysis
alias myip='curl ifconfig.me'
alias ips='ip addr show | grep inet'
alias listening='netstat -tlnp'

# Security Checks
alias check_ufw='ufw status verbose'
alias check_fail2ban='fail2ban-client status'
alias check_services='systemctl list-units --type=service --state=running'

# Quick File Operations
alias backup_dir='rsync -av --progress'
alias secure_delete='shred -vfz -n 3'

# Process Management
alias kill_by_name='pkill -f'
alias process_tree='pstree -p'

EOF

    chmod +x /etc/profile.d/kali-aliases.sh

    print_success "System aliases created"
    print_info "Aliases will be available after next login or run: source /etc/profile.d/kali-aliases.sh"
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

    # Installation type selection
    echo -e "${YELLOW}Choose installation type:${NC}"
    echo "  1) Full installation (recommended for complete setup)"
    echo "  2) Minimal installation (core tools only)"
    echo "  3) Custom installation (choose components)"
    echo
    echo -e "${WHITE}Select option (1-3): ${NC}\c"
    read -r install_type

    case $install_type in
        1)
            print_info "Full installation selected"
            INSTALL_DOTNET_SDK=true
            INSTALL_DOTNET_RUNTIME=true
            INSTALL_MONITORING=true
            INSTALL_SECURITY_TOOLS=true
            INSTALL_DEV_TOOLS=true
            CONFIGURE_GITHUB=true
            ;;
        2)
            print_info "Minimal installation selected"
            INSTALL_DOTNET_SDK=true
            INSTALL_DOTNET_RUNTIME=false
            INSTALL_MONITORING=false
            INSTALL_SECURITY_TOOLS=false
            INSTALL_DEV_TOOLS=false
            CONFIGURE_GITHUB=false
            ;;
        3)
            print_info "Custom installation selected"
            
            echo -e "${WHITE}Install .NET SDK? (Y/n): ${NC}\c"
            read -r sdk_choice
            [[ "$sdk_choice" =~ ^[Nn]$ ]] && INSTALL_DOTNET_SDK=false
            
            echo -e "${WHITE}Install .NET Runtime? (Y/n): ${NC}\c"
            read -r runtime_choice
            [[ "$runtime_choice" =~ ^[Nn]$ ]] && INSTALL_DOTNET_RUNTIME=false
            
            echo -e "${WHITE}Install security tools? (Y/n): ${NC}\c"
            read -r security_choice
            [[ "$security_choice" =~ ^[Nn]$ ]] && INSTALL_SECURITY_TOOLS=false
            
            echo -e "${WHITE}Install development tools? (Y/n): ${NC}\c"
            read -r dev_choice
            [[ "$dev_choice" =~ ^[Nn]$ ]] && INSTALL_DEV_TOOLS=false
            
            echo -e "${WHITE}Install monitoring tools? (Y/n): ${NC}\c"
            read -r monitoring_choice
            [[ "$monitoring_choice" =~ ^[Nn]$ ]] && INSTALL_MONITORING=false
            
            echo -e "${WHITE}Configure Git/GitHub? (Y/n): ${NC}\c"
            read -r github_choice
            [[ "$github_choice" =~ ^[Nn]$ ]] && CONFIGURE_GITHUB=false
            ;;
        *)
            print_warning "Invalid selection. Using full installation."
            ;;
    esac

    # Confirmation
    echo
    print_warning "This script will make significant changes to your Kali Linux system."
    echo -e "${WHITE}Continue with installation? (y/N): ${NC}\c"
    read -r confirm

    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled by user"
        exit 0
    fi

    print_success "Configuration completed. Starting installation..."
    sleep 2
}

# =============================================================================
# MAIN EXECUTION FUNCTION
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
    
    # Install security tools if requested
    if [[ "$INSTALL_SECURITY_TOOLS" == true ]]; then
        print_info "Installing Kali security tools..."
        install_kali_security_tools
        print_success "Security tools installation completed"
    fi
    
    # Install development tools if requested
    if [[ "$INSTALL_DEV_TOOLS" == true ]]; then
        print_info "Installing development tools..."
        install_development_tools
        print_success "Development tools installation completed"
    fi
    
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
    create_system_aliases
    print_success "System configuration completed"

    # Display system information
    display_system_info

    log_message "Kali Linux installation process completed successfully"

    print_completion "KALI LINUX SETUP COMPLETED SUCCESSFULLY!"
    print_warning "Please reboot your Kali Linux system to ensure all changes take effect."
    print_info "After reboot, run 'kali-sysmon' to check system status"
    
    return 0
}

# =============================================================================
# SYSTEM INFORMATION DISPLAY
# =============================================================================

display_system_info() {
    print_header "Kali Linux System Information"

    echo -e "${WHITE}Hostname:${NC} $(hostname)"
    echo -e "${WHITE}OS:${NC} $(lsb_release -d | cut -f2)"
    echo -e "${WHITE}Kernel:${NC} $(uname -r)"
    echo -e "${WHITE}Architecture:${NC} $(uname -m)"
    echo

    if command -v mysql &> /dev/null; then
        echo -e "${WHITE}MySQL:${NC} $(mysql --version | cut -d' ' -f6 | cut -d',' -f1)"
        echo -e "${WHITE}MySQL Status:${NC} $(systemctl is-active mysql)"
    fi

    if command -v dotnet &> /dev/null; then
        echo -e "${WHITE}.NET:${NC} $(dotnet --version)"
    fi

    # Display key security tools status
    echo -e "${WHITE}Security Tools Status:${NC}"
    command -v nmap &> /dev/null && echo -e "  ${GREEN}✓${NC} Nmap: $(nmap --version 2>/dev/null | head -1 | cut -d' ' -f3)" || echo -e "  ${RED}✗${NC} Nmap: Not installed"
    command -v msfconsole &> /dev/null && echo -e "  ${GREEN}✓${NC} Metasploit: Available" || echo -e "  ${RED}✗${NC} Metasploit: Not installed"
    command -v john &> /dev/null && echo -e "  ${GREEN}✓${NC} John the Ripper: Available" || echo -e "  ${RED}✗${NC} John the Ripper: Not installed"
    command -v hashcat &> /dev/null && echo -e "  ${GREEN}✓${NC} Hashcat: Available" || echo -e "  ${RED}✗${NC} Hashcat: Not installed"

    echo
    echo -e "${WHITE}Important Information:${NC}"
    if [[ -n "$MYSQL_ROOT_PASSWORD" ]]; then
        echo -e "${YELLOW}MySQL Root Password:${NC} $MYSQL_ROOT_PASSWORD"
    fi
    
    echo -e "${CYAN}Netdata Dashboard:${NC} http://localhost:19999"
    echo -e "${CYAN}System Monitor:${NC} Run 'kali-sysmon' command"
    echo -e "${CYAN}Security Tool Aliases:${NC} nmap_scan, vuln_scan, stealth_scan"
    echo
}

# =============================================================================
# COMMAND-LINE ARGUMENT PROCESSING
# =============================================================================

case "${1:-}" in
    --help|-h)
        echo "Kali Linux Complete Development Environment Setup Script"
        echo
        echo "USAGE:"
        echo "  $0 [OPTIONS]"
        echo
        echo "OPTIONS:"
        echo "  -h, --help          Show this help message"
        echo "  --version           Show version information"
        echo "  --auto              Run automatic installation with defaults"
        echo "  --mysql-password    Set MySQL root password"
        echo "  --no-security       Skip security tools installation"
        echo "  --no-dev            Skip development tools installation"
        echo "  --no-github         Skip Git/GitHub configuration"
        echo "  --minimal           Minimal installation (core components only)"
        echo
        echo "EXAMPLES:"
        echo "  $0                           # Interactive installation"
        echo "  $0 --auto                    # Automatic installation"
        echo "  $0 --mysql-password mypass   # Set specific MySQL password"
        echo "  $0 --minimal                 # Minimal installation"
        exit 0
        ;;
    --version)
        echo "Kali Linux Complete Setup Script v2.0"
        echo "Compatible with: Kali Linux 2024.x, 2023.x, 2022.x"
        exit 0
        ;;
    --auto)
        print_info "Running in automatic mode with default settings"
        main
        ;;
    --mysql-password)
        if [[ -z "$2" ]]; then
            print_error "MySQL password argument required after --mysql-password"
            echo "Usage: $0 --mysql-password <password>"
            exit 1
        fi
        MYSQL_ROOT_PASSWORD="$2"
        print_info "MySQL root password set via command line"
        shift 2
        main
        ;;
    --no-security)
        print_info "Skipping security tools installation"
        INSTALL_SECURITY_TOOLS=false
        main
        ;;
    --no-dev)
        print_info "Skipping development tools installation"
        INSTALL_DEV_TOOLS=false
        main
        ;;
    --no-github)
        print_info "Skipping Git/GitHub configuration"
        CONFIGURE_GITHUB=false
        main
        ;;
    --minimal)
        print_info "Running minimal installation"
        INSTALL_DOTNET_RUNTIME=false
        INSTALL_MONITORING=false
        INSTALL_SECURITY_TOOLS=false
        INSTALL_DEV_TOOLS=false
        CONFIGURE_GITHUB=false
        main
        ;;
    "")
        # Show main menu and run installation
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac 