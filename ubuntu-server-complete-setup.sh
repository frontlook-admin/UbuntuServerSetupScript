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

    # Set MySQL root password non-interactively
    if [[ -z "$MYSQL_ROOT_PASSWORD" ]]; then
        print_info "Generating random MySQL root password..."
        MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)
        print_warning "Generated MySQL root password: $MYSQL_ROOT_PASSWORD"
        print_warning "Please save this password securely!"
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
    print_info "Creating MySQL configuration..."
    cat > /etc/mysql/conf.d/custom.cnf <<EOF
[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
max_connections = 200
innodb_buffer_pool_size = 256M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2
EOF

    # Restart MySQL to apply configuration
    systemctl restart mysql

    print_success "MySQL Server installation completed"

    # Display MySQL information
    print_info "MySQL Status:"
    systemctl status mysql --no-pager -l
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

configure_git_github() {
    print_header "Configuring Git and GitHub"

    log_message "Configuring Git and GitHub"

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        return 1
    fi

    # Configure Git user information
    if [[ -n "$GITHUB_USERNAME" && -n "$GITHUB_EMAIL" ]]; then
        print_info "Configuring Git user information..."
        git config --global user.name "$GITHUB_USERNAME"
        git config --global user.email "$GITHUB_EMAIL"
        print_success "Git user configuration completed"
    fi

    # Configure Git settings
    print_info "Configuring Git settings..."
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global core.editor vim
    git config --global color.ui auto

    # Generate SSH key for GitHub
    read -p "Generate SSH key for GitHub authentication? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SSH_KEY_PATH="/root/.ssh/id_rsa"
        if [[ ! -f "$SSH_KEY_PATH" ]]; then
            print_info "Generating SSH key..."
            ssh-keygen -t rsa -b 4096 -C "$GITHUB_EMAIL" -f "$SSH_KEY_PATH" -N ""
            
            # Start ssh-agent and add key
            eval "$(ssh-agent -s)"
            ssh-add "$SSH_KEY_PATH"
            
            print_success "SSH key generated successfully"
            print_warning "Add the following public key to your GitHub account:"
            echo "=====================================>"
            cat "${SSH_KEY_PATH}.pub"
            echo "<====================================="
            
            read -p "Press Enter after adding the key to GitHub..."
            
            # Test GitHub connection
            print_info "Testing GitHub connection..."
            if ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated"; then
                print_success "GitHub SSH connection successful"
            else
                print_warning "GitHub SSH connection test failed - please verify the key was added correctly"
            fi
        else
            print_info "SSH key already exists at $SSH_KEY_PATH"
        fi
    fi

    # Configure GitHub CLI (optional)
    read -p "Install GitHub CLI (gh)? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
        apt update >> "$LOG_FILE" 2>&1
        apt install -y gh >> "$LOG_FILE" 2>&1
        print_success "GitHub CLI installed successfully"
        print_info "Run 'gh auth login' to authenticate with GitHub"
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
        echo "Username: $(git config --global user.name)"
        echo "Email: $(git config --global user.email)"
        if [[ -f "/root/.ssh/id_rsa.pub" ]]; then
            echo "SSH Key: /root/.ssh/id_rsa.pub"
        fi
        if command -v gh &> /dev/null; then
            echo "GitHub CLI: Installed"
        fi
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
        echo "6. Test GitHub connection: ssh -T git@github.com"
        if command -v gh &> /dev/null; then
            echo "7. Authenticate GitHub CLI: gh auth login"
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

# Function to run MySQL user management
run_mysql_user_manager() {
    print_header "MySQL User Management"
    
    if [[ -f "mysql-user-manager.sh" ]]; then
        print_info "Running MySQL User Manager..."
        if [[ -x "mysql-user-manager.sh" ]]; then
            ./mysql-user-manager.sh "$@"
        else
            chmod +x mysql-user-manager.sh
            ./mysql-user-manager.sh "$@"
        fi
    else
        print_error "mysql-user-manager.sh not found in current directory"
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
                print_info "Starting MySQL User Management..."
                run_mysql_user_manager
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
        echo -e "${CYAN}║${NC} ${RED}0)${NC} Exit                                                                                   ${CYAN}║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Enter your choice (0-16): ${NC}\c"
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
                print_info "Starting MySQL User Management..."
                check_root
                run_mysql_user_manager
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
                echo "  --no-git            Skip Git/GitHub configuration"
                echo "  --no-monitoring     Skip monitoring tools installation"
                echo "  --no-interactive    Skip all interactive prompts"
                echo
                echo "USER MANAGEMENT OPTIONS:"
                echo "  --manage-users      Run Ubuntu user management"
                echo "  --manage-mysql      Run MySQL user management"
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
                echo "  • mysql-user-manager.sh      - MySQL user management"
                echo "  • ftp-user-manager.sh        - FTP server and user management"
                echo "  • make-executable.sh         - Script permission manager"
                echo
                echo "EXAMPLES:"
                echo "  $0                           # Show main menu"
                echo "  $0 --auto                    # Automatic installation"
                echo "  $0 --make-executable         # Make all scripts executable"
                echo "  $0 --manage-users            # Manage Ubuntu users"
                echo "  $0 --manage-mysql            # Manage MySQL users"
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
            0)
                print_info "Exiting Ubuntu Server Setup..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-16."
                sleep 2
                ;;
        esac
    done
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
        echo "  --dotnet-only       Install only .NET"
        echo "  --git-only          Install and configure Git/GitHub only"
        echo "  --monitoring-only   Install system monitoring tools only"
        echo "  --security-only     Configure firewall and security only"
        echo "  --no-git            Skip Git/GitHub configuration"
        echo "  --no-monitoring     Skip monitoring tools installation"
        echo "  --no-interactive    Skip all interactive prompts"
        echo
        echo "USER MANAGEMENT OPTIONS:"
        echo "  --manage-users      Run Ubuntu user management"
        echo "  --manage-mysql      Run MySQL user management"
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
        echo "  • mysql-user-manager.sh      - MySQL user management"
        echo "  • ftp-user-manager.sh        - FTP server and user management"
        echo "  • make-executable.sh         - Script permission manager"
        echo
        echo "EXAMPLES:"
        echo "  $0                           # Show main menu"
        echo "  $0 --auto                    # Automatic installation"
        echo "  $0 --make-executable         # Make all scripts executable"
        echo "  $0 --manage-users            # Manage Ubuntu users"
        echo "  $0 --manage-mysql            # Manage MySQL users"
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
    --manage-users)
        print_info "Running Ubuntu User Management"
        check_root
        shift  # Remove the --manage-users argument
        run_ubuntu_user_manager "$@"
        exit 0
        ;;
    --manage-mysql)
        print_info "Running MySQL User Management"
        check_root
        shift  # Remove the --manage-mysql argument
        run_mysql_user_manager "$@"
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
