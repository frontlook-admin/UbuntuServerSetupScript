#!/bin/bash

# =============================================================================
# FTP Server Installation and User Management Script
# =============================================================================
# Description: Automated installation and management of FTP server with user controls
# Compatible with: Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, Ubuntu 24.04 LTS
# Author: System Administrator
# Version: 1.0
# Features:
#   - vsftpd FTP server installation and configuration
#   - FTP user creation, modification, and deletion
#   - Secure FTP configuration with chroot
#   - FTP directory management
#   - User permission management
#   - Backup and restore functionality
# =============================================================================

set -e

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
FTP_ROOT_DIR="/srv/ftp"
FTP_CONFIG_FILE="/etc/vsftpd.conf"
FTP_USER_LIST="/etc/vsftpd.userlist"
FTP_CHROOT_LIST="/etc/vsftpd.chroot_list"
LOG_FILE="/var/log/ftp-manager.log"
BACKUP_DIR="/var/backups/ftp"

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
    local log_created=false
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    
    # Try to create log file
    if [[ ! -f "$LOG_FILE" ]]; then
        if touch "$LOG_FILE" 2>/dev/null; then
            log_created=true
        else
            # Fallback to current directory
            LOG_FILE="./ftp-manager.log"
            touch "$LOG_FILE" 2>/dev/null || true
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
# FTP SERVER INSTALLATION
# =============================================================================

install_ftp_server() {
    print_header "Installing FTP Server (vsftpd)"
    
    log_message "Starting FTP server installation"
    
    # Update package lists
    print_info "Updating package lists..."
    apt update -y >> "$LOG_FILE" 2>&1
    
    # Install vsftpd
    print_info "Installing vsftpd FTP server..."
    apt install -y vsftpd >> "$LOG_FILE" 2>&1
    
    # Create backup of original configuration
    print_info "Creating backup of original configuration..."
    if [[ -f "$FTP_CONFIG_FILE" ]]; then
        cp "$FTP_CONFIG_FILE" "${FTP_CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Stop vsftpd for configuration
    print_info "Stopping vsftpd for configuration..."
    systemctl stop vsftpd 2>/dev/null || true
    
    # Create FTP directories
    print_info "Creating FTP directories..."
    mkdir -p "$FTP_ROOT_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Configure vsftpd
    print_info "Configuring vsftpd..."
    configure_vsftpd
    
    # Create user list files
    print_info "Creating user list files..."
    touch "$FTP_USER_LIST"
    touch "$FTP_CHROOT_LIST"
    
    # Set appropriate permissions
    print_info "Setting permissions..."
    chmod 755 "$FTP_ROOT_DIR"
    chmod 600 "$FTP_USER_LIST"
    chmod 600 "$FTP_CHROOT_LIST"
    
    # Configure firewall
    print_info "Configuring firewall for FTP..."
    configure_ftp_firewall
    
    # Start and enable vsftpd
    print_info "Starting vsftpd service..."
    systemctl start vsftpd
    systemctl enable vsftpd
    
    print_success "FTP server installation completed"
    
    # Display service status
    print_info "FTP Service Status:"
    systemctl status vsftpd --no-pager -l
}

configure_vsftpd() {
    print_info "Writing vsftpd configuration..."
    
    cat > "$FTP_CONFIG_FILE" <<EOF
# vsftpd Configuration File
# Generated by FTP User Manager Script

# Basic Settings
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES

# Security Settings
chroot_local_user=YES
chroot_list_enable=YES
chroot_list_file=$FTP_CHROOT_LIST
allow_writeable_chroot=YES

# User Management
userlist_enable=YES
userlist_file=$FTP_USER_LIST
userlist_deny=NO

# Connection Settings
connect_from_port_20=YES
ftpd_banner=Welcome to FTP Server
idle_session_timeout=300
data_connection_timeout=120
max_clients=50
max_per_ip=5

# Logging Settings
xferlog_enable=YES
xferlog_std_format=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES
vsftpd_log_file=/var/log/vsftpd.log

# Passive Mode Settings
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=

# SSL/TLS Settings (commented out by default)
#ssl_enable=YES
#allow_anon_ssl=NO
#force_local_data_ssl=YES
#force_local_logins_ssl=YES
#ssl_tlsv1=YES
#ssl_sslv2=NO
#ssl_sslv3=NO
#rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
#rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key

# Additional Security
hide_ids=YES
use_localtime=YES
secure_chroot_dir=/var/run/vsftpd/empty
EOF

    print_success "vsftpd configuration written"
}

configure_ftp_firewall() {
    print_info "Configuring firewall for FTP..."
    
    # Allow FTP control port
    ufw allow 21/tcp comment "FTP Control Port" >> "$LOG_FILE" 2>&1
    
    # Allow FTP passive mode ports
    ufw allow 40000:50000/tcp comment "FTP Passive Mode" >> "$LOG_FILE" 2>&1
    
    print_success "Firewall configured for FTP"
}

# =============================================================================
# FTP USER MANAGEMENT
# =============================================================================

add_ftp_user() {
    print_header "Adding FTP User"
    
    local username=""
    local password=""
    local home_dir=""
    local create_system_user=true
    
    # Get user input
    while [[ -z "$username" ]]; do
        read -p "Enter FTP username: " username
        if [[ -z "$username" ]]; then
            print_error "Username cannot be empty"
        elif id "$username" &>/dev/null; then
            print_info "User $username already exists in system"
            read -p "Use existing system user? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                create_system_user=false
            else
                username=""
            fi
        fi
    done
    
    # Get password
    while [[ -z "$password" ]]; do
        read -s -p "Enter FTP password: " password
        echo
        if [[ -z "$password" ]]; then
            print_error "Password cannot be empty"
        else
            read -s -p "Confirm FTP password: " password_confirm
            echo
            if [[ "$password" != "$password_confirm" ]]; then
                print_error "Passwords do not match"
                password=""
            fi
        fi
    done
    
    # Get home directory
    read -p "Enter FTP home directory [$FTP_ROOT_DIR/$username]: " home_dir
    if [[ -z "$home_dir" ]]; then
        home_dir="$FTP_ROOT_DIR/$username"
    fi
    
    # Create system user if needed
    if [[ "$create_system_user" == true ]]; then
        print_info "Creating system user: $username"
        useradd -m -d "$home_dir" -s /bin/bash "$username" >> "$LOG_FILE" 2>&1
        print_success "System user created"
    fi
    
    # Set password
    print_info "Setting user password..."
    echo "$username:$password" | chpasswd >> "$LOG_FILE" 2>&1
    
    # Create home directory if it doesn't exist
    if [[ ! -d "$home_dir" ]]; then
        print_info "Creating home directory: $home_dir"
        mkdir -p "$home_dir"
        chown "$username:$username" "$home_dir"
        chmod 755 "$home_dir"
    fi
    
    # Add user to FTP user list
    print_info "Adding user to FTP user list..."
    if ! grep -q "^$username$" "$FTP_USER_LIST" 2>/dev/null; then
        echo "$username" >> "$FTP_USER_LIST"
    fi
    
    # Add user to chroot list (restricted to home directory)
    print_info "Adding user to chroot list..."
    if ! grep -q "^$username$" "$FTP_CHROOT_LIST" 2>/dev/null; then
        echo "$username" >> "$FTP_CHROOT_LIST"
    fi
    
    # Set up user directory structure
    print_info "Setting up user directory structure..."
    mkdir -p "$home_dir/uploads"
    mkdir -p "$home_dir/downloads"
    chown -R "$username:$username" "$home_dir"
    chmod 755 "$home_dir"
    chmod 775 "$home_dir/uploads"
    chmod 755 "$home_dir/downloads"
    
    # Create welcome message
    echo "Welcome to your FTP account, $username!" > "$home_dir/README.txt"
    echo "Upload files to: uploads/" >> "$home_dir/README.txt"
    echo "Download files from: downloads/" >> "$home_dir/README.txt"
    chown "$username:$username" "$home_dir/README.txt"
    
    log_message "FTP user $username created successfully"
    print_completion "FTP user '$username' created successfully"
    
    # Display user information
    print_info "User Information:"
    echo "  Username: $username"
    echo "  Home Directory: $home_dir"
    echo "  Uploads Directory: $home_dir/uploads"
    echo "  Downloads Directory: $home_dir/downloads"
    echo "  Chroot: Enabled (restricted to home directory)"
}

modify_ftp_user() {
    print_header "Modifying FTP User"
    
    # List existing FTP users
    print_info "Existing FTP users:"
    if [[ -f "$FTP_USER_LIST" ]] && [[ -s "$FTP_USER_LIST" ]]; then
        cat "$FTP_USER_LIST" | nl
    else
        print_warning "No FTP users found"
        return 1
    fi
    
    read -p "Enter username to modify: " username
    
    # Verify user exists
    if ! grep -q "^$username$" "$FTP_USER_LIST" 2>/dev/null; then
        print_error "User $username not found in FTP user list"
        return 1
    fi
    
    if ! id "$username" &>/dev/null; then
        print_error "System user $username not found"
        return 1
    fi
    
    print_info "Current user information:"
    echo "  Username: $username"
    echo "  Home Directory: $(eval echo ~$username)"
    echo "  Shell: $(getent passwd $username | cut -d: -f7)"
    
    # Modification options
    while true; do
        echo
        print_info "Modification options:"
        echo "1) Change password"
        echo "2) Change home directory"
        echo "3) Enable/Disable chroot"
        echo "4) Reset directory permissions"
        echo "5) Back to main menu"
        
        read -p "Select option (1-5): " choice
        
        case $choice in
            1)
                print_info "Changing password for $username..."
                read -s -p "Enter new password: " new_password
                echo
                read -s -p "Confirm new password: " password_confirm
                echo
                
                if [[ "$new_password" == "$password_confirm" ]]; then
                    echo "$username:$new_password" | chpasswd >> "$LOG_FILE" 2>&1
                    print_success "Password changed successfully"
                else
                    print_error "Passwords do not match"
                fi
                ;;
            2)
                print_info "Changing home directory for $username..."
                current_home=$(eval echo ~$username)
                read -p "Enter new home directory [$current_home]: " new_home
                
                if [[ -n "$new_home" && "$new_home" != "$current_home" ]]; then
                    mkdir -p "$new_home"
                    usermod -d "$new_home" -m "$username" >> "$LOG_FILE" 2>&1
                    chown -R "$username:$username" "$new_home"
                    print_success "Home directory changed to $new_home"
                else
                    print_info "Home directory unchanged"
                fi
                ;;
            3)
                print_info "Managing chroot for $username..."
                if grep -q "^$username$" "$FTP_CHROOT_LIST" 2>/dev/null; then
                    print_info "User is currently in chroot list (restricted)"
                    read -p "Remove from chroot (allow access to entire system)? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        sed -i "/^$username$/d" "$FTP_CHROOT_LIST"
                        print_success "User removed from chroot list"
                    fi
                else
                    print_info "User is not in chroot list (unrestricted)"
                    read -p "Add to chroot (restrict to home directory)? (y/n): " -n 1 -r
                    echo
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        echo "$username" >> "$FTP_CHROOT_LIST"
                        print_success "User added to chroot list"
                    fi
                fi
                ;;
            4)
                print_info "Resetting directory permissions for $username..."
                user_home=$(eval echo ~$username)
                chown -R "$username:$username" "$user_home"
                chmod 755 "$user_home"
                if [[ -d "$user_home/uploads" ]]; then
                    chmod 775 "$user_home/uploads"
                fi
                if [[ -d "$user_home/downloads" ]]; then
                    chmod 755 "$user_home/downloads"
                fi
                print_success "Directory permissions reset"
                ;;
            5)
                return 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
    done
}

delete_ftp_user() {
    print_header "Deleting FTP User"
    
    # List existing FTP users
    print_info "Existing FTP users:"
    if [[ -f "$FTP_USER_LIST" ]] && [[ -s "$FTP_USER_LIST" ]]; then
        cat "$FTP_USER_LIST" | nl
    else
        print_warning "No FTP users found"
        return 1
    fi
    
    read -p "Enter username to delete: " username
    
    # Verify user exists
    if ! grep -q "^$username$" "$FTP_USER_LIST" 2>/dev/null; then
        print_error "User $username not found in FTP user list"
        return 1
    fi
    
    # Confirmation
    print_warning "This will:"
    echo "  - Remove user from FTP user list"
    echo "  - Remove user from chroot list"
    echo "  - Optionally delete system user"
    echo "  - Optionally delete home directory"
    
    read -p "Are you sure you want to delete FTP user $username? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled"
        return 0
    fi
    
    # Remove from FTP user list
    print_info "Removing user from FTP user list..."
    sed -i "/^$username$/d" "$FTP_USER_LIST"
    
    # Remove from chroot list
    print_info "Removing user from chroot list..."
    sed -i "/^$username$/d" "$FTP_CHROOT_LIST"
    
    # Ask about system user
    if id "$username" &>/dev/null; then
        read -p "Delete system user $username? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            user_home=$(eval echo ~$username)
            
            # Ask about home directory
            if [[ -d "$user_home" ]]; then
                read -p "Delete home directory $user_home? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    print_info "Deleting system user and home directory..."
                    userdel -r "$username" >> "$LOG_FILE" 2>&1
                    print_success "System user and home directory deleted"
                else
                    print_info "Deleting system user (keeping home directory)..."
                    userdel "$username" >> "$LOG_FILE" 2>&1
                    print_success "System user deleted (home directory preserved)"
                fi
            else
                print_info "Deleting system user..."
                userdel "$username" >> "$LOG_FILE" 2>&1
                print_success "System user deleted"
            fi
        else
            print_info "System user preserved"
        fi
    fi
    
    log_message "FTP user $username deleted"
    print_completion "FTP user '$username' deleted successfully"
}

list_ftp_users() {
    print_header "FTP Users List"
    
    if [[ -f "$FTP_USER_LIST" ]] && [[ -s "$FTP_USER_LIST" ]]; then
        print_info "FTP Users:"
        echo
        printf "%-20s %-30s %-10s %-10s\n" "Username" "Home Directory" "Chroot" "Status"
        echo "--------------------------------------------------------------------------------"
        
        while IFS= read -r username; do
            [[ -z "$username" ]] && continue
            
            # Get home directory
            if id "$username" &>/dev/null; then
                home_dir=$(eval echo ~$username)
                user_status="Active"
            else
                home_dir="N/A"
                user_status="Inactive"
            fi
            
            # Check chroot status
            if grep -q "^$username$" "$FTP_CHROOT_LIST" 2>/dev/null; then
                chroot_status="Yes"
            else
                chroot_status="No"
            fi
            
            printf "%-20s %-30s %-10s %-10s\n" "$username" "$home_dir" "$chroot_status" "$user_status"
        done < "$FTP_USER_LIST"
    else
        print_warning "No FTP users found"
    fi
    
    echo
    print_info "FTP Service Status:"
    systemctl status vsftpd --no-pager -l
}

# =============================================================================
# FTP SERVER MANAGEMENT
# =============================================================================

configure_ftp_ssl() {
    print_header "Configuring FTP SSL/TLS"
    
    print_info "SSL/TLS will secure FTP connections"
    read -p "Enable SSL/TLS for FTP? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Generate self-signed certificate
        print_info "Generating SSL certificate..."
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/ssl/private/vsftpd.key \
            -out /etc/ssl/certs/vsftpd.crt \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" >> "$LOG_FILE" 2>&1
        
        # Set permissions
        chmod 600 /etc/ssl/private/vsftpd.key
        chmod 644 /etc/ssl/certs/vsftpd.crt
        
        # Update configuration
        print_info "Updating vsftpd configuration for SSL..."
        sed -i 's/#ssl_enable=YES/ssl_enable=YES/' "$FTP_CONFIG_FILE"
        sed -i 's/#allow_anon_ssl=NO/allow_anon_ssl=NO/' "$FTP_CONFIG_FILE"
        sed -i 's/#force_local_data_ssl=YES/force_local_data_ssl=YES/' "$FTP_CONFIG_FILE"
        sed -i 's/#force_local_logins_ssl=YES/force_local_logins_ssl=YES/' "$FTP_CONFIG_FILE"
        sed -i 's/#ssl_tlsv1=YES/ssl_tlsv1=YES/' "$FTP_CONFIG_FILE"
        sed -i 's/#ssl_sslv2=NO/ssl_sslv2=NO/' "$FTP_CONFIG_FILE"
        sed -i 's/#ssl_sslv3=NO/ssl_sslv3=NO/' "$FTP_CONFIG_FILE"
        sed -i "s|#rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem|rsa_cert_file=/etc/ssl/certs/vsftpd.crt|" "$FTP_CONFIG_FILE"
        sed -i "s|#rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key|rsa_private_key_file=/etc/ssl/private/vsftpd.key|" "$FTP_CONFIG_FILE"
        
        # Restart vsftpd
        print_info "Restarting vsftpd..."
        systemctl restart vsftpd
        
        print_success "SSL/TLS enabled for FTP"
        print_warning "Clients will need to use FTPS (explicit TLS) or SFTP"
    else
        print_info "SSL/TLS not enabled"
    fi
}

backup_ftp_config() {
    print_header "Backing Up FTP Configuration"
    
    local backup_file="$BACKUP_DIR/ftp_backup_$(date +%Y%m%d_%H%M%S).tar.gz"
    
    print_info "Creating backup directory..."
    mkdir -p "$BACKUP_DIR"
    
    print_info "Creating backup archive..."
    tar -czf "$backup_file" \
        "$FTP_CONFIG_FILE" \
        "$FTP_USER_LIST" \
        "$FTP_CHROOT_LIST" \
        "$FTP_ROOT_DIR" \
        2>/dev/null || true
    
    if [[ -f "$backup_file" ]]; then
        print_success "Backup created: $backup_file"
    else
        print_error "Failed to create backup"
    fi
}

restore_ftp_config() {
    print_header "Restoring FTP Configuration"
    
    print_info "Available backups:"
    if ls "$BACKUP_DIR"/ftp_backup_*.tar.gz 1> /dev/null 2>&1; then
        ls -la "$BACKUP_DIR"/ftp_backup_*.tar.gz
        echo
        read -p "Enter backup file path: " backup_file
        
        if [[ -f "$backup_file" ]]; then
            print_warning "This will overwrite current configuration!"
            read -p "Continue? (y/n): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                print_info "Stopping vsftpd..."
                systemctl stop vsftpd
                
                print_info "Extracting backup..."
                tar -xzf "$backup_file" -C / >> "$LOG_FILE" 2>&1
                
                print_info "Starting vsftpd..."
                systemctl start vsftpd
                
                print_success "Configuration restored from backup"
            else
                print_info "Restore cancelled"
            fi
        else
            print_error "Backup file not found"
        fi
    else
        print_warning "No backups found"
    fi
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_ftp_menu() {
    while true; do
        clear
        print_header "FTP Server Management"
        echo
        echo -e "${WHITE}FTP Server Management Options:${NC}"
        echo
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC} ${GREEN}FTP SERVER INSTALLATION${NC}                                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Install FTP Server (vsftpd)                                                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Configure FTP SSL/TLS                                                               ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${PURPLE}FTP USER MANAGEMENT${NC}                                                                    ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Add FTP User                                                                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Modify FTP User                                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Delete FTP User                                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} List FTP Users                                                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${BLUE}BACKUP & RESTORE${NC}                                                                       ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} Backup FTP Configuration                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Restore FTP Configuration                                                           ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${WHITE}INFORMATION${NC}                                                                            ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Show FTP Service Status                                                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC} ${YELLOW}10)${NC} Show FTP Help                                                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╠═══════════════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} ${RED}0)${NC} Exit                                                                                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo
        echo -e "${WHITE}Enter your choice (0-10): ${NC}\c"
        read choice
        
        case $choice in
            1)
                print_info "Installing FTP Server..."
                install_ftp_server
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            2)
                print_info "Configuring FTP SSL/TLS..."
                configure_ftp_ssl
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            3)
                print_info "Adding FTP User..."
                add_ftp_user
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            4)
                print_info "Modifying FTP User..."
                modify_ftp_user
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            5)
                print_info "Deleting FTP User..."
                delete_ftp_user
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            6)
                print_info "Listing FTP Users..."
                list_ftp_users
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            7)
                print_info "Backing up FTP Configuration..."
                backup_ftp_config
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            8)
                print_info "Restoring FTP Configuration..."
                restore_ftp_config
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            9)
                print_info "Showing FTP Service Status..."
                systemctl status vsftpd --no-pager -l
                echo
                print_info "FTP Configuration:"
                echo "  Config File: $FTP_CONFIG_FILE"
                echo "  User List: $FTP_USER_LIST"
                echo "  Chroot List: $FTP_CHROOT_LIST"
                echo "  Root Directory: $FTP_ROOT_DIR"
                echo "  Log File: $LOG_FILE"
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            10)
                print_info "FTP Help Information..."
                echo
                echo "FTP Server Help:"
                echo "================"
                echo "• FTP Server: vsftpd (Very Secure FTP Daemon)"
                echo "• Default Port: 21 (Control), 40000-50000 (Passive Data)"
                echo "• Configuration: $FTP_CONFIG_FILE"
                echo "• User List: $FTP_USER_LIST"
                echo "• Chroot List: $FTP_CHROOT_LIST"
                echo "• Root Directory: $FTP_ROOT_DIR"
                echo
                echo "User Management:"
                echo "• All users are chrooted by default (restricted to home directory)"
                echo "• Each user gets uploads/ and downloads/ directories"
                echo "• Users can be enabled/disabled without deletion"
                echo
                echo "Security Features:"
                echo "• Anonymous access disabled"
                echo "• SSL/TLS encryption available"
                echo "• Connection limits (50 total, 5 per IP)"
                echo "• Firewall rules automatically configured"
                echo
                echo "Connection Examples:"
                echo "• FTP: ftp://username:password@server_ip"
                echo "• FTPS: ftps://username:password@server_ip"
                echo "• Command line: ftp server_ip"
                echo
                read -p "Press Enter to continue..." && continue
                ;;
            0)
                print_info "Exiting FTP Management..."
                exit 0
                ;;
            *)
                print_error "Invalid option. Please select 0-10."
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
        echo "FTP SERVER OPTIONS:"
        echo "  --install           Install FTP server"
        echo "  --add-user          Add FTP user"
        echo "  --modify-user       Modify FTP user"
        echo "  --delete-user       Delete FTP user"
        echo "  --list-users        List FTP users"
        echo "  --configure-ssl     Configure SSL/TLS"
        echo "  --backup            Backup FTP configuration"
        echo "  --restore           Restore FTP configuration"
        echo "  --status            Show FTP service status"
        echo "  --help, -h          Show this help message"
        echo
        echo "EXAMPLES:"
        echo "  $0                  # Show main menu"
        echo "  $0 --install        # Install FTP server"
        echo "  $0 --add-user       # Add FTP user"
        echo "  $0 --list-users     # List FTP users"
        echo "  $0 --status         # Show service status"
        exit 0
        ;;
    --install)
        check_root
        check_ubuntu
        install_ftp_server
        exit 0
        ;;
    --add-user)
        check_root
        add_ftp_user
        exit 0
        ;;
    --modify-user)
        check_root
        modify_ftp_user
        exit 0
        ;;
    --delete-user)
        check_root
        delete_ftp_user
        exit 0
        ;;
    --list-users)
        list_ftp_users
        exit 0
        ;;
    --configure-ssl)
        check_root
        configure_ftp_ssl
        exit 0
        ;;
    --backup)
        check_root
        backup_ftp_config
        exit 0
        ;;
    --restore)
        check_root
        restore_ftp_config
        exit 0
        ;;
    --status)
        systemctl status vsftpd --no-pager -l
        exit 0
        ;;
    "")
        check_root
        check_ubuntu
        show_ftp_menu
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac 