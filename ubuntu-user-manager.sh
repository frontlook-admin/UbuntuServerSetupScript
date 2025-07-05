#!/bin/bash

# =============================================================================
# Ubuntu User Management Script
# =============================================================================
# Description: Comprehensive Ubuntu system user management with rights control
# Author: System Administrator
# Version: 1.0
# Compatible with: Ubuntu 18.04+, 20.04+, 22.04+, 24.04+
# =============================================================================

set -e  # Exit on any error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="/var/log/ubuntu-user-management.log"
CONFIG_FILE="/etc/ubuntu-user-manager.conf"
BACKUP_DIR="/var/backups/system-users"
DEFAULT_SHELL="/bin/bash"
DEFAULT_HOME_DIR="/home"

# Common system groups
COMMON_GROUPS=("sudo" "docker" "www-data" "dialout" "cdrom" "floppy" "audio" "video" "plugdev" "users" "netdev" "bluetooth" "scanner" "wireshark")

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${BLUE}=================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}=================================${NC}"
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

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

create_log_file() {
    mkdir -p /var/log
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
}

create_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    chmod 700 "$BACKUP_DIR"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_username() {
    local username="$1"

    # Check if username is provided
    if [[ -z "$username" ]]; then
        print_error "Username cannot be empty"
        return 1
    fi

    # Check username length (maximum 32 characters)
    if [[ ${#username} -gt 32 ]]; then
        print_error "Username too long (maximum 32 characters)"
        return 1
    fi

    # Check for invalid characters (only lowercase letters, numbers, underscores, hyphens)
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        print_error "Username contains invalid characters (must start with letter, only lowercase letters, numbers, underscores, and hyphens allowed)"
        return 1
    fi

    # Check for reserved usernames
    local reserved_users=("root" "daemon" "bin" "sys" "sync" "games" "man" "lp" "mail" "news" "uucp" "proxy" "www-data" "backup" "list" "irc" "gnats" "nobody" "systemd-network" "systemd-resolve" "messagebus" "systemd-timesync" "syslog" "uuidd" "tcpdump" "tss" "landscape" "pollinate" "sshd" "fwupd-refresh" "systemd-coredump" "lxd" "mysql" "redis" "mongodb" "postgres" "nginx" "apache" "bind")

    for reserved in "${reserved_users[@]}"; do
        if [[ "$username" == "$reserved" ]]; then
            print_error "Username '$username' is reserved and cannot be used"
            return 1
        fi
    done

    return 0
}

validate_password() {
    local password="$1"

    # Check if password is provided
    if [[ -z "$password" ]]; then
        print_error "Password cannot be empty"
        return 1
    fi

    # Check password length (minimum 8 characters)
    if [[ ${#password} -lt 8 ]]; then
        print_error "Password too short (minimum 8 characters)"
        return 1
    fi

    # Check for strong password complexity
    local has_upper=false
    local has_lower=false
    local has_digit=false
    local has_special=false

    if [[ "$password" =~ [A-Z] ]]; then has_upper=true; fi
    if [[ "$password" =~ [a-z] ]]; then has_lower=true; fi
    if [[ "$password" =~ [0-9] ]]; then has_digit=true; fi
    if [[ "$password" =~ [^a-zA-Z0-9] ]]; then has_special=true; fi

    if [[ "$has_upper" == false ]] || [[ "$has_lower" == false ]] || [[ "$has_digit" == false ]] || [[ "$has_special" == false ]]; then
        print_warning "Password should contain at least one uppercase letter, one lowercase letter, one number, and one special character"
    fi

    return 0
}

validate_email() {
    local email="$1"

    if [[ -n "$email" ]]; then
        if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            print_error "Invalid email format"
            return 1
        fi
    fi

    return 0
}

user_exists() {
    local username="$1"

    if id "$username" &>/dev/null; then
        return 0  # User exists
    else
        return 1  # User does not exist
    fi
}

group_exists() {
    local group="$1"

    if getent group "$group" &>/dev/null; then
        return 0  # Group exists
    else
        return 1  # Group does not exist
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

backup_user_info() {
    local username="$1"

    create_backup_dir

    local backup_file="$BACKUP_DIR/user_${username}_$(date +%Y%m%d_%H%M%S).bak"

    print_info "Creating backup of user information..."

    {
        echo "# User backup for $username - $(date)"
        echo "# Generated by Ubuntu User Management Script"
        echo ""
        echo "# User information"
        getent passwd "$username" 2>/dev/null || echo "User not found in passwd"
        echo ""
        echo "# User groups"
        groups "$username" 2>/dev/null || echo "User not found for groups"
        echo ""
        echo "# User shadow information"
        getent shadow "$username" 2>/dev/null || echo "User not found in shadow"
        echo ""
        echo "# User sudo privileges"
        sudo -l -U "$username" 2>/dev/null || echo "No sudo privileges or user not found"
        echo ""
        echo "# Home directory listing"
        if [[ -d "/home/$username" ]]; then
            ls -la "/home/$username" 2>/dev/null || echo "Cannot access home directory"
        else
            echo "Home directory does not exist"
        fi
    } > "$backup_file"

    chmod 600 "$backup_file"
    print_success "User information backed up to $backup_file"
}

backup_system_files() {
    print_info "Creating backup of system files..."

    create_backup_dir

    local backup_file="$BACKUP_DIR/system_files_$(date +%Y%m%d_%H%M%S).tar.gz"

    tar -czf "$backup_file" /etc/passwd /etc/group /etc/shadow /etc/sudoers.d/ 2>/dev/null || true

    chmod 600 "$backup_file"
    print_success "System files backed up to $backup_file"
}

# =============================================================================
# USER CREATION FUNCTIONS
# =============================================================================

create_user_basic() {
    local username="$1"
    local password="$2"
    local full_name="$3"
    local shell="$4"
    local home_dir="$5"

    print_header "Creating Basic User"

    # Validate inputs
    if ! validate_username "$username" || ! validate_password "$password"; then
        return 1
    fi

    # Check if user already exists
    if user_exists "$username"; then
        print_error "User '$username' already exists"
        return 1
    fi

    # Set defaults
    shell=${shell:-$DEFAULT_SHELL}
    home_dir=${home_dir:-$DEFAULT_HOME_DIR/$username}

    # Backup system files
    backup_system_files

    # Create user
    print_info "Creating user '$username'..."

    if useradd -m -d "$home_dir" -s "$shell" -c "$full_name" "$username"; then
        print_success "User '$username' created successfully"
    else
        print_error "Failed to create user '$username'"
        return 1
    fi

    # Set password
    print_info "Setting password for user '$username'..."

    if echo "$username:$password" | chpasswd; then
        print_success "Password set successfully"
    else
        print_error "Failed to set password"
        return 1
    fi

    # Set proper permissions on home directory
    chown -R "$username:$username" "$home_dir"
    chmod 755 "$home_dir"

    # Force password change on first login
    passwd -e "$username" &>/dev/null

    log_message "Created basic user '$username' with home directory '$home_dir'"

    return 0
}

create_user_with_groups() {
    local username="$1"
    local password="$2"
    local full_name="$3"
    local groups="$4"
    local shell="$5"

    print_header "Creating User with Groups"

    # Create basic user first
    if ! create_user_basic "$username" "$password" "$full_name" "$shell"; then
        return 1
    fi

    # Add user to groups
    if [[ -n "$groups" ]]; then
        print_info "Adding user '$username' to groups: $groups"

        IFS=',' read -ra GROUP_ARRAY <<< "$groups"
        for group in "${GROUP_ARRAY[@]}"; do
            group=$(echo "$group" | xargs)  # Trim whitespace

            if group_exists "$group"; then
                if usermod -a -G "$group" "$username"; then
                    print_success "Added user '$username' to group '$group'"
                else
                    print_error "Failed to add user '$username' to group '$group'"
                fi
            else
                print_warning "Group '$group' does not exist, skipping"
            fi
        done
    fi

    log_message "Created user '$username' with groups: $groups"

    return 0
}

create_user_with_sudo() {
    local username="$1"
    local password="$2"
    local full_name="$3"
    local sudo_type="$4"  # full, limited, passwordless

    print_header "Creating User with Sudo Access"

    # Create basic user first
    if ! create_user_basic "$username" "$password" "$full_name"; then
        return 1
    fi

    # Add sudo access
    case "$sudo_type" in
        "full")
            print_info "Granting full sudo access to user '$username'..."
            usermod -a -G sudo "$username"
            print_success "User '$username' added to sudo group"
            ;;
        "limited")
            print_info "Granting limited sudo access to user '$username'..."
            cat > "/etc/sudoers.d/$username" <<EOF
# Limited sudo access for $username
$username ALL=(ALL) /usr/bin/apt, /usr/bin/systemctl, /usr/bin/service, /usr/bin/mount, /usr/bin/umount
EOF
            chmod 440 "/etc/sudoers.d/$username"
            print_success "Limited sudo access granted to user '$username'"
            ;;
        "passwordless")
            print_info "Granting passwordless sudo access to user '$username'..."
            cat > "/etc/sudoers.d/$username" <<EOF
# Passwordless sudo access for $username
$username ALL=(ALL) NOPASSWD: ALL
EOF
            chmod 440 "/etc/sudoers.d/$username"
            print_success "Passwordless sudo access granted to user '$username'"
            ;;
        *)
            print_error "Invalid sudo type: $sudo_type (must be: full, limited, passwordless)"
            return 1
            ;;
    esac

    log_message "Created user '$username' with sudo access: $sudo_type"

    return 0
}

create_service_user() {
    local username="$1"
    local home_dir="$2"
    local shell="$3"

    print_header "Creating Service User"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user already exists
    if user_exists "$username"; then
        print_error "User '$username' already exists"
        return 1
    fi

    # Set defaults for service user
    shell=${shell:-"/bin/false"}
    home_dir=${home_dir:-"/var/lib/$username"}

    # Backup system files
    backup_system_files

    # Create service user
    print_info "Creating service user '$username'..."

    if useradd -r -m -d "$home_dir" -s "$shell" -c "Service user for $username" "$username"; then
        print_success "Service user '$username' created successfully"
    else
        print_error "Failed to create service user '$username'"
        return 1
    fi

    # Set proper permissions
    chown -R "$username:$username" "$home_dir"
    chmod 750 "$home_dir"

    # Lock the account (no password login)
    passwd -l "$username" &>/dev/null

    log_message "Created service user '$username' with home directory '$home_dir'"

    return 0
}

# =============================================================================
# USER MODIFICATION FUNCTIONS
# =============================================================================

modify_user_password() {
    local username="$1"
    local new_password="$2"

    print_header "Modifying User Password"

    # Validate inputs
    if ! validate_username "$username" || ! validate_password "$new_password"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Backup user info
    backup_user_info "$username"

    # Change password
    print_info "Changing password for user '$username'..."

    if echo "$username:$new_password" | chpasswd; then
        print_success "Password changed successfully"

        # Unlock account if it was locked
        passwd -u "$username" &>/dev/null

        log_message "Changed password for user '$username'"
        return 0
    else
        print_error "Failed to change password"
        return 1
    fi
}

modify_user_info() {
    local username="$1"
    local full_name="$2"
    local shell="$3"
    local home_dir="$4"

    print_header "Modifying User Information"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Backup user info
    backup_user_info "$username"

    # Modify user information
    print_info "Modifying user information for '$username'..."

    # Change full name
    if [[ -n "$full_name" ]]; then
        if usermod -c "$full_name" "$username"; then
            print_success "Updated full name to '$full_name'"
        else
            print_error "Failed to update full name"
        fi
    fi

    # Change shell
    if [[ -n "$shell" ]]; then
        if usermod -s "$shell" "$username"; then
            print_success "Updated shell to '$shell'"
        else
            print_error "Failed to update shell"
        fi
    fi

    # Change home directory
    if [[ -n "$home_dir" ]]; then
        if usermod -d "$home_dir" -m "$username"; then
            print_success "Updated home directory to '$home_dir'"
        else
            print_error "Failed to update home directory"
        fi
    fi

    log_message "Modified user information for '$username'"

    return 0
}

modify_user_groups() {
    local username="$1"
    local action="$2"      # add, remove, replace
    local groups="$3"

    print_header "Modifying User Groups"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Backup user info
    backup_user_info "$username"

    # Show current groups
    print_info "Current groups for user '$username':"
    groups "$username"

    # Process groups
    IFS=',' read -ra GROUP_ARRAY <<< "$groups"

    case "$action" in
        "add")
            print_info "Adding user '$username' to groups: $groups"

            for group in "${GROUP_ARRAY[@]}"; do
                group=$(echo "$group" | xargs)  # Trim whitespace

                if group_exists "$group"; then
                    if usermod -a -G "$group" "$username"; then
                        print_success "Added user '$username' to group '$group'"
                    else
                        print_error "Failed to add user '$username' to group '$group'"
                    fi
                else
                    print_warning "Group '$group' does not exist, skipping"
                fi
            done
            ;;
        "remove")
            print_info "Removing user '$username' from groups: $groups"

            for group in "${GROUP_ARRAY[@]}"; do
                group=$(echo "$group" | xargs)  # Trim whitespace

                if group_exists "$group"; then
                    if gpasswd -d "$username" "$group" &>/dev/null; then
                        print_success "Removed user '$username' from group '$group'"
                    else
                        print_warning "User '$username' was not in group '$group' or removal failed"
                    fi
                else
                    print_warning "Group '$group' does not exist, skipping"
                fi
            done
            ;;
        "replace")
            print_info "Replacing groups for user '$username' with: $groups"

            # Validate all groups exist first
            for group in "${GROUP_ARRAY[@]}"; do
                group=$(echo "$group" | xargs)  # Trim whitespace
                if ! group_exists "$group"; then
                    print_error "Group '$group' does not exist"
                    return 1
                fi
            done

            # Replace groups
            if usermod -G "$groups" "$username"; then
                print_success "Replaced groups for user '$username'"
            else
                print_error "Failed to replace groups"
                return 1
            fi
            ;;
        *)
            print_error "Invalid action: $action (must be: add, remove, replace)"
            return 1
            ;;
    esac

    # Show updated groups
    print_info "Updated groups for user '$username':"
    groups "$username"

    log_message "Modified groups for user '$username': $action - $groups"

    return 0
}

modify_user_sudo() {
    local username="$1"
    local action="$2"      # grant, revoke, modify
    local sudo_type="$3"   # full, limited, passwordless

    print_header "Modifying User Sudo Access"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Backup user info
    backup_user_info "$username"

    case "$action" in
        "grant")
            print_info "Granting sudo access to user '$username'..."

            case "$sudo_type" in
                "full")
                    usermod -a -G sudo "$username"
                    print_success "User '$username' added to sudo group"
                    ;;
                "limited")
                    cat > "/etc/sudoers.d/$username" <<EOF
# Limited sudo access for $username
$username ALL=(ALL) /usr/bin/apt, /usr/bin/systemctl, /usr/bin/service, /usr/bin/mount, /usr/bin/umount
EOF
                    chmod 440 "/etc/sudoers.d/$username"
                    print_success "Limited sudo access granted to user '$username'"
                    ;;
                "passwordless")
                    cat > "/etc/sudoers.d/$username" <<EOF
# Passwordless sudo access for $username
$username ALL=(ALL) NOPASSWD: ALL
EOF
                    chmod 440 "/etc/sudoers.d/$username"
                    print_success "Passwordless sudo access granted to user '$username'"
                    ;;
                *)
                    print_error "Invalid sudo type: $sudo_type (must be: full, limited, passwordless)"
                    return 1
                    ;;
            esac
            ;;
        "revoke")
            print_info "Revoking sudo access from user '$username'..."

            # Remove from sudo group
            gpasswd -d "$username" sudo &>/dev/null || true

            # Remove sudoers file
            if [[ -f "/etc/sudoers.d/$username" ]]; then
                rm -f "/etc/sudoers.d/$username"
                print_success "Removed sudoers file for user '$username'"
            fi

            print_success "Revoked sudo access from user '$username'"
            ;;
        "modify")
            print_info "Modifying sudo access for user '$username'..."

            # First revoke existing access
            modify_user_sudo "$username" "revoke"

            # Then grant new access
            modify_user_sudo "$username" "grant" "$sudo_type"
            ;;
        *)
            print_error "Invalid action: $action (must be: grant, revoke, modify)"
            return 1
            ;;
    esac

    log_message "Modified sudo access for user '$username': $action - $sudo_type"

    return 0
}

# =============================================================================
# USER DELETION FUNCTIONS
# =============================================================================

delete_user() {
    local username="$1"
    local remove_home="$2"    # true/false
    local remove_mail="$3"    # true/false
    local force="$4"          # true/false

    print_header "Deleting User"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Check if user is currently logged in
    if who | grep -q "^$username "; then
        print_warning "User '$username' is currently logged in"
        if [[ "$force" != "true" ]]; then
            read -p "Continue anyway? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "User deletion cancelled"
                return 0
            fi
        fi
    fi

    # Show user information
    print_info "User information for '$username':"
    getent passwd "$username"
    print_info "User groups:"
    groups "$username"

    # Confirmation
    if [[ "$force" != "true" ]]; then
        echo
        print_warning "This will permanently delete the user '$username'"
        if [[ "$remove_home" == "true" ]]; then
            print_warning "Home directory will be deleted"
        fi
        if [[ "$remove_mail" == "true" ]]; then
            print_warning "Mail spool will be deleted"
        fi
        echo
        read -p "Are you sure you want to delete user '$username'? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "User deletion cancelled"
            return 0
        fi
    fi

    # Backup user info
    backup_user_info "$username"

    # Kill all processes owned by the user
    print_info "Killing all processes owned by user '$username'..."
    pkill -u "$username" 2>/dev/null || true
    sleep 2
    pkill -9 -u "$username" 2>/dev/null || true

    # Remove from all groups
    print_info "Removing user '$username' from all groups..."
    for group in $(groups "$username" 2>/dev/null | cut -d: -f2); do
        gpasswd -d "$username" "$group" &>/dev/null || true
    done

    # Remove sudoers file
    if [[ -f "/etc/sudoers.d/$username" ]]; then
        rm -f "/etc/sudoers.d/$username"
        print_success "Removed sudoers file for user '$username'"
    fi

    # Construct userdel command
    local userdel_cmd="userdel"
    if [[ "$remove_home" == "true" ]]; then
        userdel_cmd="$userdel_cmd -r"
    fi
    if [[ "$remove_mail" == "true" ]]; then
        userdel_cmd="$userdel_cmd -f"
    fi

    # Delete user
    print_info "Deleting user '$username'..."

    if $userdel_cmd "$username"; then
        print_success "User '$username' deleted successfully"
    else
        print_error "Failed to delete user '$username'"
        return 1
    fi

    # Clean up any remaining files
    if [[ "$remove_home" == "true" ]]; then
        # Remove any remaining files in /tmp
        find /tmp -user "$username" -delete 2>/dev/null || true

        # Remove any remaining files in /var/spool
        find /var/spool -user "$username" -delete 2>/dev/null || true
    fi

    log_message "Deleted user '$username' (remove_home: $remove_home, remove_mail: $remove_mail)"

    return 0
}

# =============================================================================
# INFORMATION FUNCTIONS
# =============================================================================

list_users() {
    print_header "System Users List"

    print_info "All system users:"
    echo "Username:UID:GID:Full Name:Home Directory:Shell"
    echo "================================================="

    # Get all users with UID >= 1000 (regular users) and some system users
    awk -F: '$3 >= 1000 || $1 ~ /^(root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody)$/ {print $1":"$3":"$4":"$5":"$6":"$7}' /etc/passwd | sort -t: -k3 -n

    echo ""
    print_info "User groups summary:"
    echo "Username:Groups"
    echo "==============="

    # Show groups for each user
    awk -F: '$3 >= 1000 {print $1}' /etc/passwd | while read username; do
        echo "$username:$(groups "$username" 2>/dev/null | cut -d: -f2 | tr ' ' ',')"
    done
}

show_user_info() {
    local username="$1"

    print_header "User Information"

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Basic user information
    print_info "Basic Information:"
    getent passwd "$username"

    # User groups
    print_info "Groups:"
    groups "$username"

    # Sudo privileges
    print_info "Sudo Privileges:"
    if sudo -l -U "$username" 2>/dev/null | grep -q "may run"; then
        sudo -l -U "$username" 2>/dev/null
    else
        echo "No sudo privileges"
    fi

    # Home directory information
    local home_dir=$(getent passwd "$username" | cut -d: -f6)
    print_info "Home Directory: $home_dir"
    if [[ -d "$home_dir" ]]; then
        ls -la "$home_dir" 2>/dev/null || echo "Cannot access home directory"
    else
        echo "Home directory does not exist"
    fi

    # Last login information
    print_info "Last Login:"
    last -n 5 "$username" 2>/dev/null || echo "No login history found"

    # Account status
    print_info "Account Status:"
    if passwd -S "$username" 2>/dev/null; then
        echo "Account is active"
    else
        echo "Account status unknown"
    fi

    # Process information
    print_info "Running Processes:"
    ps -u "$username" -o pid,ppid,cmd 2>/dev/null || echo "No processes running"
}

show_available_groups() {
    print_header "Available System Groups"

    print_info "Common groups for user assignment:"
    for group in "${COMMON_GROUPS[@]}"; do
        if group_exists "$group"; then
            echo "✓ $group"
        else
            echo "✗ $group (not available)"
        fi
    done

    echo ""
    print_info "All system groups:"
    cut -d: -f1 /etc/group | sort | column -c 80
}

# =============================================================================
# INTERACTIVE FUNCTIONS
# =============================================================================

interactive_create_user() {
    print_header "Interactive User Creation"

    # Get user details
    read -p "Enter username: " username

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if user_exists "$username"; then
        print_error "User '$username' already exists"
        return 1
    fi

    # Get password
    read -s -p "Enter password: " password
    echo
    read -s -p "Confirm password: " password_confirm
    echo

    if [[ "$password" != "$password_confirm" ]]; then
        print_error "Passwords do not match"
        return 1
    fi

    # Get full name
    read -p "Enter full name (optional): " full_name

    # Choose user type
    echo
    echo "Choose user type:"
    echo "1) Basic user"
    echo "2) User with specific groups"
    echo "3) User with sudo access"
    echo "4) Service user"
    read -p "Enter choice (1-4): " user_type

    case "$user_type" in
        1)
            create_user_basic "$username" "$password" "$full_name"
            ;;
        2)
            show_available_groups
            echo
            read -p "Enter groups (comma-separated): " groups
            create_user_with_groups "$username" "$password" "$full_name" "$groups"
            ;;
        3)
            echo
            echo "Choose sudo access level:"
            echo "1) Full sudo access"
            echo "2) Limited sudo access"
            echo "3) Passwordless sudo access"
            read -p "Enter choice (1-3): " sudo_choice

            case "$sudo_choice" in
                1) sudo_type="full" ;;
                2) sudo_type="limited" ;;
                3) sudo_type="passwordless" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac

            create_user_with_sudo "$username" "$password" "$full_name" "$sudo_type"
            ;;
        4)
            read -p "Enter home directory (optional): " home_dir
            read -p "Enter shell (default: /bin/false): " shell
            shell=${shell:-"/bin/false"}

            create_service_user "$username" "$home_dir" "$shell"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

interactive_modify_user() {
    print_header "Interactive User Modification"

    # Get username
    read -p "Enter username to modify: " username

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Show current user information
    show_user_info "$username"

    echo
    echo "What would you like to modify?"
    echo "1) Change password"
    echo "2) Modify user information"
    echo "3) Modify groups"
    echo "4) Modify sudo access"
    read -p "Enter choice (1-4): " modify_choice

    case "$modify_choice" in
        1)
            read -s -p "Enter new password: " new_password
            echo
            read -s -p "Confirm new password: " new_password_confirm
            echo

            if [[ "$new_password" != "$new_password_confirm" ]]; then
                print_error "Passwords do not match"
                return 1
            fi

            modify_user_password "$username" "$new_password"
            ;;
        2)
            read -p "Enter new full name (leave empty to keep current): " full_name
            read -p "Enter new shell (leave empty to keep current): " shell
            read -p "Enter new home directory (leave empty to keep current): " home_dir

            modify_user_info "$username" "$full_name" "$shell" "$home_dir"
            ;;
        3)
            echo
            echo "Choose group action:"
            echo "1) Add to groups"
            echo "2) Remove from groups"
            echo "3) Replace all groups"
            read -p "Enter choice (1-3): " group_action

            case "$group_action" in
                1) action="add" ;;
                2) action="remove" ;;
                3) action="replace" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac

            if [[ "$action" == "add" || "$action" == "replace" ]]; then
                show_available_groups
                echo
            fi

            read -p "Enter groups (comma-separated): " groups

            modify_user_groups "$username" "$action" "$groups"
            ;;
        4)
            echo
            echo "Choose sudo action:"
            echo "1) Grant sudo access"
            echo "2) Revoke sudo access"
            echo "3) Modify sudo access"
            read -p "Enter choice (1-3): " sudo_action

            case "$sudo_action" in
                1) action="grant" ;;
                2) action="revoke" ;;
                3) action="modify" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac

            if [[ "$action" == "grant" || "$action" == "modify" ]]; then
                echo
                echo "Choose sudo access level:"
                echo "1) Full sudo access"
                echo "2) Limited sudo access"
                echo "3) Passwordless sudo access"
                read -p "Enter choice (1-3): " sudo_choice

                case "$sudo_choice" in
                    1) sudo_type="full" ;;
                    2) sudo_type="limited" ;;
                    3) sudo_type="passwordless" ;;
                    *) print_error "Invalid choice"; return 1 ;;
                esac
            fi

            modify_user_sudo "$username" "$action" "$sudo_type"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

interactive_delete_user() {
    print_header "Interactive User Deletion"

    # List current users
    list_users

    echo
    read -p "Enter username to delete: " username

    # Validate username
    if ! validate_username "$username"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    # Show user information
    show_user_info "$username"

    echo
    read -p "Remove home directory? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        remove_home="true"
    else
        remove_home="false"
    fi

    read -p "Remove mail spool? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        remove_mail="true"
    else
        remove_mail="false"
    fi

    delete_user "$username" "$remove_home" "$remove_mail"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    clear
    print_header "Ubuntu User Management Script"

    echo "1)  Create basic user"
    echo "2)  Create user with groups"
    echo "3)  Create user with sudo access"
    echo "4)  Create service user"
    echo "5)  Modify user password"
    echo "6)  Modify user information"
    echo "7)  Modify user groups"
    echo "8)  Modify user sudo access"
    echo "9)  Delete user"
    echo "10) List all users"
    echo "11) Show user information"
    echo "12) Show available groups"
    echo "13) Interactive user creation"
    echo "14) Interactive user modification"
    echo "15) Interactive user deletion"
    echo "16) Backup system files"
    echo "0)  Exit"
    echo
    read -p "Enter your choice (0-16): " choice

    case "$choice" in
        1)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            read -p "Full name: " full_name
            read -p "Shell (default: $DEFAULT_SHELL): " shell
            shell=${shell:-$DEFAULT_SHELL}

            create_user_basic "$username" "$password" "$full_name" "$shell"
            ;;
        2)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            read -p "Full name: " full_name
            read -p "Groups (comma-separated): " groups
            read -p "Shell (default: $DEFAULT_SHELL): " shell
            shell=${shell:-$DEFAULT_SHELL}

            create_user_with_groups "$username" "$password" "$full_name" "$groups" "$shell"
            ;;
        3)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            read -p "Full name: " full_name
            read -p "Sudo type (full/limited/passwordless): " sudo_type

            create_user_with_sudo "$username" "$password" "$full_name" "$sudo_type"
            ;;
        4)
            read -p "Username: " username
            read -p "Home directory (optional): " home_dir
            read -p "Shell (default: /bin/false): " shell
            shell=${shell:-"/bin/false"}

            create_service_user "$username" "$home_dir" "$shell"
            ;;
        5)
            read -p "Username: " username
            read -s -p "New password: " new_password
            echo

            modify_user_password "$username" "$new_password"
            ;;
        6)
            read -p "Username: " username
            read -p "New full name (leave empty to keep current): " full_name
            read -p "New shell (leave empty to keep current): " shell
            read -p "New home directory (leave empty to keep current): " home_dir

            modify_user_info "$username" "$full_name" "$shell" "$home_dir"
            ;;
        7)
            read -p "Username: " username
            read -p "Action (add/remove/replace): " action
            read -p "Groups (comma-separated): " groups

            modify_user_groups "$username" "$action" "$groups"
            ;;
        8)
            read -p "Username: " username
            read -p "Action (grant/revoke/modify): " action
            read -p "Sudo type (full/limited/passwordless): " sudo_type

            modify_user_sudo "$username" "$action" "$sudo_type"
            ;;
        9)
            read -p "Username: " username
            read -p "Remove home directory? (true/false): " remove_home
            read -p "Remove mail spool? (true/false): " remove_mail

            delete_user "$username" "$remove_home" "$remove_mail"
            ;;
        10)
            list_users
            ;;
        11)
            read -p "Username: " username
            show_user_info "$username"
            ;;
        12)
            show_available_groups
            ;;
        13)
            interactive_create_user
            ;;
        14)
            interactive_modify_user
            ;;
        15)
            interactive_delete_user
            ;;
        16)
            backup_system_files
            ;;
        0)
            print_info "Goodbye!"
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            ;;
    esac

    echo
    read -p "Press Enter to continue..."
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

show_help() {
    echo "Ubuntu User Management Script"
    echo
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  create-basic USERNAME PASSWORD FULL_NAME [SHELL]"
    echo "  create-groups USERNAME PASSWORD FULL_NAME GROUPS [SHELL]"
    echo "  create-sudo USERNAME PASSWORD FULL_NAME SUDO_TYPE"
    echo "  create-service USERNAME [HOME_DIR] [SHELL]"
    echo "  modify-password USERNAME NEW_PASSWORD"
    echo "  modify-info USERNAME [FULL_NAME] [SHELL] [HOME_DIR]"
    echo "  modify-groups USERNAME ACTION GROUPS"
    echo "  modify-sudo USERNAME ACTION [SUDO_TYPE]"
    echo "  delete-user USERNAME [REMOVE_HOME] [REMOVE_MAIL]"
    echo "  list-users"
    echo "  show-info USERNAME"
    echo "  show-groups"
    echo "  backup-system"
    echo
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -i, --interactive Run in interactive mode"
    echo "  -f, --force       Force operation without confirmation"
    echo "  -v, --verbose     Enable verbose output"
    echo
    echo "Examples:"
    echo "  $0 create-basic johndoe mypassword123 'John Doe'"
    echo "  $0 create-groups appuser apppass123 'App User' 'www-data,docker'"
    echo "  $0 create-sudo admin adminpass123 'Admin User' full"
    echo "  $0 modify-groups johndoe add 'docker,sudo'"
    echo "  $0 delete-user johndoe true true"
    echo "  $0 --interactive"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    # Check root privileges
    check_root

    # Create log file and backup directory
    create_log_file
    create_backup_dir

    log_message "Ubuntu User Management Script started"

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
        create-basic)
            if [[ $# -ge 4 ]]; then
                create_user_basic "$2" "$3" "$4" "$5"
            else
                                print_error "Usage: $0 create-basic USERNAME PASSWORD FULL_NAME [SHELL]"
                exit 1
            fi
            ;;
        create-groups)
            if [[ $# -ge 5 ]]; then
                create_user_with_groups "$2" "$3" "$4" "$5" "$6"
            else
                print_error "Usage: $0 create-groups USERNAME PASSWORD FULL_NAME GROUPS [SHELL]"
                exit 1
            fi
            ;;
        create-sudo)
            if [[ $# -eq 5 ]]; then
                create_user_with_sudo "$2" "$3" "$4" "$5"
            else
                print_error "Usage: $0 create-sudo USERNAME PASSWORD FULL_NAME SUDO_TYPE"
                exit 1
            fi
            ;;
        create-service)
            if [[ $# -ge 2 ]]; then
                create_service_user "$2" "$3" "$4"
            else
                print_error "Usage: $0 create-service USERNAME [HOME_DIR] [SHELL]"
                exit 1
            fi
            ;;
        modify-password)
            if [[ $# -eq 3 ]]; then
                modify_user_password "$2" "$3"
            else
                print_error "Usage: $0 modify-password USERNAME NEW_PASSWORD"
                exit 1
            fi
            ;;
        modify-info)
            if [[ $# -ge 2 ]]; then
                modify_user_info "$2" "$3" "$4" "$5"
            else
                print_error "Usage: $0 modify-info USERNAME [FULL_NAME] [SHELL] [HOME_DIR]"
                exit 1
            fi
            ;;
        modify-groups)
            if [[ $# -eq 4 ]]; then
                modify_user_groups "$2" "$3" "$4"
            else
                print_error "Usage: $0 modify-groups USERNAME ACTION GROUPS"
                exit 1
            fi
            ;;
        modify-sudo)
            if [[ $# -ge 3 ]]; then
                modify_user_sudo "$2" "$3" "$4"
            else
                print_error "Usage: $0 modify-sudo USERNAME ACTION [SUDO_TYPE]"
                exit 1
            fi
            ;;
        delete-user)
            if [[ $# -ge 2 ]]; then
                delete_user "$2" "$3" "$4" "$5"
            else
                print_error "Usage: $0 delete-user USERNAME [REMOVE_HOME] [REMOVE_MAIL] [FORCE]"
                exit 1
            fi
            ;;
        list-users)
            list_users
            ;;
        show-info)
            if [[ $# -eq 2 ]]; then
                show_user_info "$2"
            else
                print_error "Usage: $0 show-info USERNAME"
                exit 1
            fi
            ;;
        show-groups)
            show_available_groups
            ;;
        backup-system)
            backup_system_files
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

    log_message "Ubuntu User Management Script completed"
}

# =============================================================================
# CLEANUP AND EXIT
# =============================================================================

cleanup() {
    log_message "Script interrupted or completed"
}

# Set trap for cleanup
trap cleanup EXIT

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Run main function with all arguments
main "$@"
