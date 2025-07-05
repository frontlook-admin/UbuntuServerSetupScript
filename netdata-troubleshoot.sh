#!/bin/bash

# =============================================================================
# Netdata Troubleshooting and Repair Script
# =============================================================================
# Description: Comprehensive script to diagnose and fix Netdata permission 
#              and configuration issues
# Author: System Administrator
# Version: 1.0
# Compatible with: Ubuntu 20.04 LTS, Ubuntu 22.04 LTS, Ubuntu 24.04 LTS
# Features:
#   - Diagnose Netdata permission issues
#   - Fix web directory permissions
#   - Check and repair service configurations
#   - Validate SELinux/AppArmor contexts
#   - Comprehensive logging and reporting
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
NETDATA_USER="netdata"
NETDATA_GROUP="netdata"
NETDATA_WEB_DIR="/usr/share/netdata/web"
NETDATA_CONFIG_DIR="/etc/netdata"
NETDATA_LIB_DIR="/var/lib/netdata"
NETDATA_CACHE_DIR="/var/cache/netdata"
NETDATA_LOG_DIR="/var/log/netdata"
NETDATA_SERVICE="netdata"
NETDATA_PORT="19999"
LOG_FILE="/var/log/netdata-troubleshoot.log"
BACKUP_DIR="/var/backups/netdata-troubleshoot"

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
    log_message "SUCCESS" "$1"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    log_message "ERROR" "$1"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
    log_message "INFO" "$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    log_message "WARNING" "$1"
}

print_highlight() {
    echo -e "${PURPLE}★ $1${NC}"
    log_message "HIGHLIGHT" "$1"
}

print_step() {
    echo -e "${WHITE}→ $1${NC}"
    log_message "STEP" "$1"
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Only log if we have write permissions (running as root)
    if [[ $EUID -eq 0 ]] && [[ -w "$(dirname "$LOG_FILE")" || -w "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# =============================================================================
# DIAGNOSTIC FUNCTIONS
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    print_success "Running as root"
    
    # Create log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    # Create backup directory
    mkdir -p "$BACKUP_DIR"
    chmod 755 "$BACKUP_DIR"
    
    print_success "Prerequisites check completed"
}

check_netdata_installation() {
    print_header "Checking Netdata Installation"
    
    # Check if Netdata is installed
    if ! command -v netdata &> /dev/null; then
        print_error "Netdata is not installed"
        return 1
    fi
    print_success "Netdata binary found: $(which netdata)"
    
    # Check Netdata version
    local version=$(netdata -v 2>/dev/null | head -1)
    print_info "Netdata version: $version"
    
    # Check if service exists
    if ! systemctl list-units --full -all | grep -Fq "$NETDATA_SERVICE.service"; then
        print_error "Netdata service not found"
        return 1
    fi
    print_success "Netdata service found"
    
    return 0
}

check_service_status() {
    print_header "Checking Service Status"
    
    # Check service status
    if systemctl is-active --quiet "$NETDATA_SERVICE"; then
        print_success "Netdata service is running"
        
        # Get service details
        local pid=$(systemctl show -p MainPID --value "$NETDATA_SERVICE")
        print_info "Netdata PID: $pid"
        
        # Check service user
        if [ "$pid" != "0" ] && [ -n "$pid" ]; then
            local service_user=$(ps -o user= -p "$pid" 2>/dev/null)
            print_info "Service running as user: $service_user"
        fi
        
    else
        print_error "Netdata service is not running"
        
        # Check service logs for errors
        print_info "Recent service errors:"
        systemctl status "$NETDATA_SERVICE" --no-pager -l || true
        
        return 1
    fi
    
    # Check if service is enabled
    if systemctl is-enabled --quiet "$NETDATA_SERVICE"; then
        print_success "Netdata service is enabled"
    else
        print_warning "Netdata service is not enabled for auto-start"
    fi
    
    return 0
}

check_network_connectivity() {
    print_header "Checking Network Connectivity"
    
    # Check if port is listening
    if netstat -tuln | grep -q ":$NETDATA_PORT "; then
        print_success "Netdata is listening on port $NETDATA_PORT"
        
        # Show listening details
        local listen_info=$(netstat -tuln | grep ":$NETDATA_PORT ")
        print_info "Listening details: $listen_info"
        
    else
        print_error "Netdata is not listening on port $NETDATA_PORT"
        return 1
    fi
    
    # Test local connectivity
    print_step "Testing local connectivity..."
    if curl -s -f "http://localhost:$NETDATA_PORT/" > /dev/null; then
        print_success "Local HTTP connection successful"
    else
        print_error "Local HTTP connection failed"
        
        # Try to get more details
        local curl_output=$(curl -s "http://localhost:$NETDATA_PORT/" 2>&1 || true)
        print_info "Curl output: $curl_output"
        
        return 1
    fi
    
    return 0
}

check_file_permissions() {
    print_header "Checking File Permissions"
    
    local issues_found=0
    
    # Check web directory
    if [[ -d "$NETDATA_WEB_DIR" ]]; then
        print_success "Netdata web directory found: $NETDATA_WEB_DIR"
        
        # Check directory permissions
        local dir_perms=$(stat -c "%a" "$NETDATA_WEB_DIR")
        local dir_owner=$(stat -c "%U:%G" "$NETDATA_WEB_DIR")
        
        print_info "Web directory permissions: $dir_perms"
        print_info "Web directory owner: $dir_owner"
        
        # Check if readable by others
        if [[ ! "$dir_perms" =~ [0-9][0-9][5-7] ]]; then
            print_warning "Web directory may not be readable by web server"
            ((issues_found++))
        fi
        
        # Check index.html
        local index_file="$NETDATA_WEB_DIR/index.html"
        if [[ -f "$index_file" ]]; then
            local file_perms=$(stat -c "%a" "$index_file")
            local file_owner=$(stat -c "%U:%G" "$index_file")
            
            print_info "Index file permissions: $file_perms"
            print_info "Index file owner: $file_owner"
            
            if [[ ! "$file_perms" =~ [0-9][0-9][4-7] ]]; then
                print_warning "Index file may not be readable"
                ((issues_found++))
            fi
        else
            print_error "Index file not found: $index_file"
            ((issues_found++))
        fi
        
    else
        print_error "Netdata web directory not found: $NETDATA_WEB_DIR"
        ((issues_found++))
    fi
    
    # Check other important directories
    local dirs=("$NETDATA_CONFIG_DIR" "$NETDATA_LIB_DIR" "$NETDATA_LOG_DIR")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            local perms=$(stat -c "%a" "$dir")
            local owner=$(stat -c "%U:%G" "$dir")
            print_info "$dir - Permissions: $perms, Owner: $owner"
        else
            print_warning "Directory not found: $dir"
        fi
    done
    
    return $issues_found
}

check_user_and_groups() {
    print_header "Checking User and Groups"
    
    # Check if netdata user exists
    if id "$NETDATA_USER" &>/dev/null; then
        print_success "Netdata user exists: $NETDATA_USER"
        
        # Get user details
        local user_info=$(id "$NETDATA_USER")
        print_info "User details: $user_info"
        
        # Check user shell
        local user_shell=$(getent passwd "$NETDATA_USER" | cut -d: -f7)
        print_info "User shell: $user_shell"
        
    else
        print_error "Netdata user does not exist: $NETDATA_USER"
        return 1
    fi
    
    # Check if netdata group exists
    if getent group "$NETDATA_GROUP" &>/dev/null; then
        print_success "Netdata group exists: $NETDATA_GROUP"
        
        # Get group members
        local group_members=$(getent group "$NETDATA_GROUP" | cut -d: -f4)
        print_info "Group members: ${group_members:-none}"
        
    else
        print_error "Netdata group does not exist: $NETDATA_GROUP"
        return 1
    fi
    
    return 0
}

check_selinux_apparmor() {
    print_header "Checking SELinux/AppArmor Status"
    
    # Check SELinux
    if command -v getenforce &> /dev/null; then
        local selinux_status=$(getenforce)
        print_info "SELinux status: $selinux_status"
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            print_warning "SELinux is enforcing - may cause permission issues"
            
            # Check SELinux contexts for Netdata files
            if command -v ls &> /dev/null; then
                print_info "Checking SELinux contexts..."
                ls -lZ "$NETDATA_WEB_DIR" 2>/dev/null | head -5 || true
            fi
        fi
    else
        print_info "SELinux not installed"
    fi
    
    # Check AppArmor
    if command -v aa-status &> /dev/null; then
        print_info "AppArmor is installed"
        
        # Check if Netdata has AppArmor profile
        if aa-status | grep -q netdata; then
            print_warning "Netdata has AppArmor profile - may cause permission issues"
            aa-status | grep netdata || true
        else
            print_info "No AppArmor profile for Netdata"
        fi
    else
        print_info "AppArmor not installed"
    fi
    
    return 0
}

check_firewall_status() {
    print_header "Checking Firewall Configuration"
    
    # Check UFW status
    if command -v ufw &> /dev/null; then
        local ufw_status=$(ufw status | head -1)
        print_info "UFW status: $ufw_status"
        
        if ufw status | grep -q "$NETDATA_PORT"; then
            print_success "UFW allows port $NETDATA_PORT"
            ufw status | grep "$NETDATA_PORT" || true
        else
            print_warning "UFW does not explicitly allow port $NETDATA_PORT"
        fi
    else
        print_info "UFW not installed"
    fi
    
    # Check iptables rules
    if command -v iptables &> /dev/null; then
        print_info "Checking iptables rules for port $NETDATA_PORT..."
        if iptables -L -n | grep -q "$NETDATA_PORT"; then
            print_info "Found iptables rules for port $NETDATA_PORT"
            iptables -L -n | grep "$NETDATA_PORT" || true
        else
            print_info "No specific iptables rules found for port $NETDATA_PORT"
        fi
    fi
    
    return 0
}

# =============================================================================
# REPAIR FUNCTIONS
# =============================================================================

fix_file_permissions() {
    print_header "Fixing File Permissions"
    
    # Backup current permissions
    print_step "Creating permissions backup..."
    local backup_file="$BACKUP_DIR/permissions-$(date +%Y%m%d-%H%M%S).txt"
    
    # Save current permissions
    {
        echo "# Netdata permissions backup - $(date)"
        echo "# Web directory permissions"
        find "$NETDATA_WEB_DIR" -exec stat -c "%n %a %U:%G" {} \; 2>/dev/null || true
        echo "# Config directory permissions"
        find "$NETDATA_CONFIG_DIR" -exec stat -c "%n %a %U:%G" {} \; 2>/dev/null || true
    } > "$backup_file"
    
    print_success "Permissions backed up to: $backup_file"
    
    # Fix web directory permissions
    if [[ -d "$NETDATA_WEB_DIR" ]]; then
        print_step "Fixing web directory permissions..."
        
        # Set directory permissions (755 = rwxr-xr-x)
        find "$NETDATA_WEB_DIR" -type d -exec chmod 755 {} \;
        
        # Set file permissions (644 = rw-r--r--)
        find "$NETDATA_WEB_DIR" -type f -exec chmod 644 {} \;
        
        # Ensure proper ownership
        chown -R "$NETDATA_USER:$NETDATA_GROUP" "$NETDATA_WEB_DIR"
        
        print_success "Web directory permissions fixed"
    fi
    
    # Fix other Netdata directories
    local dirs=("$NETDATA_LIB_DIR" "$NETDATA_CACHE_DIR" "$NETDATA_LOG_DIR")
    for dir in "${dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_step "Fixing permissions for $dir..."
            chown -R "$NETDATA_USER:$NETDATA_GROUP" "$dir"
            chmod 755 "$dir"
            print_success "Fixed permissions for $dir"
        fi
    done
    
    # Fix config directory (more restrictive)
    if [[ -d "$NETDATA_CONFIG_DIR" ]]; then
        print_step "Fixing config directory permissions..."
        chown -R root:"$NETDATA_GROUP" "$NETDATA_CONFIG_DIR"
        chmod -R 640 "$NETDATA_CONFIG_DIR"
        find "$NETDATA_CONFIG_DIR" -type d -exec chmod 750 {} \;
        print_success "Config directory permissions fixed"
    fi
    
    return 0
}

fix_user_and_groups() {
    print_header "Fixing User and Groups"
    
    # Create netdata group if it doesn't exist
    if ! getent group "$NETDATA_GROUP" &>/dev/null; then
        print_step "Creating netdata group..."
        groupadd "$NETDATA_GROUP"
        print_success "Created netdata group"
    fi
    
    # Create netdata user if it doesn't exist
    if ! id "$NETDATA_USER" &>/dev/null; then
        print_step "Creating netdata user..."
        useradd -r -g "$NETDATA_GROUP" -c "Netdata monitoring user" \
                -s /bin/false -d /var/lib/netdata "$NETDATA_USER"
        print_success "Created netdata user"
    fi
    
    # Ensure user is in correct group
    usermod -g "$NETDATA_GROUP" "$NETDATA_USER"
    print_success "User group membership verified"
    
    return 0
}

fix_service_configuration() {
    print_header "Fixing Service Configuration"
    
    # Check if systemd service file exists and is correct
    local service_file="/etc/systemd/system/netdata.service"
    local original_service="/lib/systemd/system/netdata.service"
    
    if [[ -f "$original_service" ]]; then
        print_info "Found original service file: $original_service"
        
        # Check if custom service file exists
        if [[ -f "$service_file" ]]; then
            print_step "Backing up custom service file..."
            cp "$service_file" "$BACKUP_DIR/netdata.service.backup-$(date +%Y%m%d-%H%M%S)"
        fi
        
        # Ensure service is using correct user
        if grep -q "User=$NETDATA_USER" "$original_service"; then
            print_success "Service file has correct user configuration"
        else
            print_warning "Service file may need user configuration update"
        fi
    fi
    
    # Reload systemd and restart service
    print_step "Reloading systemd configuration..."
    systemctl daemon-reload
    
    # Enable service
    print_step "Enabling Netdata service..."
    systemctl enable "$NETDATA_SERVICE"
    
    # Restart service
    print_step "Restarting Netdata service..."
    systemctl restart "$NETDATA_SERVICE"
    
    # Wait for service to start
    sleep 3
    
    if systemctl is-active --quiet "$NETDATA_SERVICE"; then
        print_success "Netdata service restarted successfully"
    else
        print_error "Failed to restart Netdata service"
        return 1
    fi
    
    return 0
}

fix_selinux_contexts() {
    print_header "Fixing SELinux Contexts"
    
    if command -v getenforce &> /dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
        print_step "Fixing SELinux contexts for Netdata..."
        
        # Restore default contexts
        if command -v restorecon &> /dev/null; then
            restorecon -R "$NETDATA_WEB_DIR" 2>/dev/null || true
            restorecon -R "$NETDATA_CONFIG_DIR" 2>/dev/null || true
            restorecon -R "$NETDATA_LIB_DIR" 2>/dev/null || true
            print_success "SELinux contexts restored"
        else
            print_warning "restorecon command not found"
        fi
        
        # Check if httpd_exec_t context is needed
        if command -v setsebool &> /dev/null; then
            print_step "Setting SELinux booleans for web access..."
            setsebool -P httpd_can_network_connect 1 2>/dev/null || true
            print_success "SELinux booleans configured"
        fi
    else
        print_info "SELinux not enforcing - no context fixes needed"
    fi
    
    return 0
}

# =============================================================================
# COMPREHENSIVE TESTS
# =============================================================================

run_comprehensive_test() {
    print_header "Running Comprehensive Test"
    
    local test_results=0
    
    # Test 1: Basic HTTP connectivity
    print_step "Testing basic HTTP connectivity..."
    if curl -s -f "http://localhost:$NETDATA_PORT/" > /dev/null; then
        print_success "Basic HTTP test passed"
    else
        print_error "Basic HTTP test failed"
        ((test_results++))
    fi
    
    # Test 2: Web interface accessibility
    print_step "Testing web interface accessibility..."
    local response=$(curl -s "http://localhost:$NETDATA_PORT/" | head -10)
    if echo "$response" | grep -q -i "netdata\|html"; then
        print_success "Web interface accessible"
    else
        print_error "Web interface not accessible"
        print_info "Response preview: $response"
        ((test_results++))
    fi
    
    # Test 3: API endpoint test
    print_step "Testing API endpoints..."
    if curl -s -f "http://localhost:$NETDATA_PORT/api/v1/info" > /dev/null; then
        print_success "API endpoints accessible"
    else
        print_error "API endpoints not accessible"
        ((test_results++))
    fi
    
    # Test 4: File access test
    print_step "Testing direct file access..."
    local index_file="$NETDATA_WEB_DIR/index.html"
    if [[ -r "$index_file" ]]; then
        print_success "Index file is readable"
    else
        print_error "Index file is not readable"
        ((test_results++))
    fi
    
    # Test 5: Service status
    print_step "Testing service status..."
    if systemctl is-active --quiet "$NETDATA_SERVICE"; then
        print_success "Service is running"
    else
        print_error "Service is not running"
        ((test_results++))
    fi
    
    return $test_results
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

run_diagnostics() {
    print_header "Running Complete Diagnostics"
    
    local diagnostic_results=0
    
    check_prerequisites || ((diagnostic_results++))
    check_netdata_installation || ((diagnostic_results++))
    check_service_status || ((diagnostic_results++))
    check_network_connectivity || ((diagnostic_results++))
    check_file_permissions || ((diagnostic_results++))
    check_user_and_groups || ((diagnostic_results++))
    check_selinux_apparmor || ((diagnostic_results++))
    check_firewall_status || ((diagnostic_results++))
    
    print_header "Diagnostic Summary"
    if [[ $diagnostic_results -eq 0 ]]; then
        print_success "All diagnostic checks passed!"
    else
        print_warning "$diagnostic_results issue(s) found during diagnostics"
    fi
    
    return $diagnostic_results
}

run_repairs() {
    print_header "Running Automatic Repairs"
    
    local repair_results=0
    
    # Ask for confirmation
    echo
    read -p "Do you want to proceed with automatic repairs? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Repairs cancelled by user"
        return 0
    fi
    
    fix_user_and_groups || ((repair_results++))
    fix_file_permissions || ((repair_results++))
    fix_selinux_contexts || ((repair_results++))
    fix_service_configuration || ((repair_results++))
    
    print_header "Repair Summary"
    if [[ $repair_results -eq 0 ]]; then
        print_success "All repairs completed successfully!"
    else
        print_warning "$repair_results repair(s) failed"
    fi
    
    # Run post-repair test
    echo
    run_comprehensive_test
    
    return $repair_results
}

show_help() {
    cat << EOF
Netdata Troubleshooting and Repair Script

Usage: $0 [OPTION]

Options:
    --diagnose          Run diagnostic checks only
    --repair           Run automatic repairs (interactive)
    --test             Run comprehensive connectivity tests
    --full             Run diagnostics, repairs, and tests (default)
    --help             Show this help message

Examples:
    $0                 # Run full diagnostic and repair process
    $0 --diagnose      # Only run diagnostic checks
    $0 --repair        # Only run repairs (will ask for confirmation)
    $0 --test          # Only run connectivity tests

Log file: $LOG_FILE
Backup directory: $BACKUP_DIR

This script helps diagnose and fix common Netdata issues including:
- Permission problems with web files
- Service configuration issues
- User and group problems
- SELinux/AppArmor context issues
- Network connectivity problems
EOF
}

main() {
    case "${1:-}" in
        --diagnose)
            run_diagnostics
            ;;
        --repair)
            check_prerequisites
            run_repairs
            ;;
        --test)
            check_prerequisites
            run_comprehensive_test
            ;;
        --help)
            show_help
            ;;
        --full|"")
            run_diagnostics
            echo
            run_repairs
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
}

# Initialize logging (only if running as root)
if [[ $EUID -eq 0 ]]; then
    log_message "STARTUP" "Netdata troubleshooting script started with args: $*"
fi

# Run main function
main "$@"