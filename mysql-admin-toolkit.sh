#!/bin/bash

# =============================================================================
# MySQL Administration Toolkit
# =============================================================================
# Description: Comprehensive MySQL administration toolkit with user management, 
#              database cloning, synchronization, and administrative features
# Author: System Administrator
# Version: 2.0
# Compatible with: MySQL 5.7+, MySQL 8.0+
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
LOG_FILE="/var/log/mysql-admin-toolkit.log"
CONFIG_FILE="/etc/mysql-admin-toolkit.conf"
BACKUP_DIR="/var/backups/mysql-users"
DATA_SYNC_DIR="/var/backups/mysql-data-sync"

# MySQL connection variables
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD=""

# Remote MySQL connection variables
REMOTE_MYSQL_HOST=""
REMOTE_MYSQL_PORT="3306"
REMOTE_MYSQL_USER="root"
REMOTE_MYSQL_PASSWORD=""

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
# MYSQL CONNECTION FUNCTIONS
# =============================================================================

setup_mysql_connection() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        print_info "Loaded configuration from $CONFIG_FILE"
    else
        print_info "No configuration file found. Using interactive setup."

        read -p "MySQL Host (default: localhost): " input_host
        MYSQL_HOST=${input_host:-localhost}

        read -p "MySQL Port (default: 3306): " input_port
        MYSQL_PORT=${input_port:-3306}

        read -p "MySQL Root Username (default: root): " input_user
        MYSQL_ROOT_USER=${input_user:-root}

        read -s -p "MySQL Root Password: " MYSQL_ROOT_PASSWORD
        echo

        # Save configuration
        read -p "Save configuration to $CONFIG_FILE? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat > "$CONFIG_FILE" <<EOF
MYSQL_HOST="$MYSQL_HOST"
MYSQL_PORT="$MYSQL_PORT"
MYSQL_ROOT_USER="$MYSQL_ROOT_USER"
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
EOF
            chmod 600 "$CONFIG_FILE"
            print_success "Configuration saved to $CONFIG_FILE"
        fi
    fi
}

test_mysql_connection() {
    print_info "Testing MySQL connection..."

    if mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -e "SELECT 1" &>/dev/null; then
        print_success "MySQL connection successful"
        return 0
    else
        print_error "MySQL connection failed"
        return 1
    fi
}

execute_mysql_query() {
    local query="$1"
    local silent="${2:-false}"

    if [[ "$silent" == "false" ]]; then
        log_message "Executing MySQL query: $query"
    fi

    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -e "$query" 2>/dev/null
}

# =============================================================================
# USER VALIDATION FUNCTIONS
# =============================================================================

validate_username() {
    local username="$1"

    # Check if username is provided
    if [[ -z "$username" ]]; then
        print_error "Username cannot be empty"
        return 1
    fi

    # Check username length (MySQL limit is 32 characters)
    if [[ ${#username} -gt 32 ]]; then
        print_error "Username too long (maximum 32 characters)"
        return 1
    fi

    # Check for invalid characters
    if [[ ! "$username" =~ ^[a-zA-Z0-9_]+$ ]]; then
        print_error "Username contains invalid characters (only letters, numbers, and underscores allowed)"
        return 1
    fi

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

    # Check for strong password (at least one uppercase, lowercase, number, and special character)
    if [[ ! "$password" =~ [A-Z] ]] || [[ ! "$password" =~ [a-z] ]] || [[ ! "$password" =~ [0-9] ]] || [[ ! "$password" =~ [^a-zA-Z0-9] ]]; then
        print_warning "Password should contain at least one uppercase letter, one lowercase letter, one number, and one special character"
    fi

    return 0
}

validate_hostname() {
    local hostname="$1"

    # Common hostname patterns
    local valid_patterns=("localhost" "127.0.0.1" "%" "*.%" "192.168.%" "10.%" "172.16.%")

    if [[ -z "$hostname" ]]; then
        print_error "Hostname cannot be empty"
        return 1
    fi

    # Check if it's a valid IP address or hostname pattern
    if [[ "$hostname" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] ||
       [[ "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]] ||
       [[ "$hostname" =~ ^[a-zA-Z0-9.-]*%$ ]]; then
        return 0
    else
        print_error "Invalid hostname format"
        return 1
    fi
}

user_exists() {
    local username="$1"
    local hostname="$2"

    local count=$(execute_mysql_query "SELECT COUNT(*) FROM mysql.user WHERE User='$username' AND Host='$hostname';" | tail -n 1)

    if [[ "$count" -gt 0 ]]; then
        return 0  # User exists
    else
        return 1  # User does not exist
    fi
}

database_exists() {
    local database="$1"

    local count=$(execute_mysql_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$database';" | tail -n 1)

    if [[ "$count" -gt 0 ]]; then
        return 0  # Database exists
    else
        return 1  # Database does not exist
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

backup_user_grants() {
    local username="$1"
    local hostname="$2"

    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/user_grants_${username}_${hostname//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).sql"

    print_info "Creating backup of user grants..."

    # Export user grants
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -e "SHOW GRANTS FOR '$username'@'$hostname';" > "$backup_file" 2>/dev/null

    if [[ $? -eq 0 ]]; then
        print_success "User grants backed up to $backup_file"
    else
        print_warning "Failed to backup user grants"
    fi
}

backup_all_users() {
    print_info "Creating backup of all MySQL users..."

    mkdir -p "$BACKUP_DIR"

    local backup_file="$BACKUP_DIR/all_users_$(date +%Y%m%d_%H%M%S).sql"

    # Export all users and their grants
    mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_ROOT_USER" -p"$MYSQL_ROOT_PASSWORD" -e "
    SELECT CONCAT('CREATE USER ''', User, '''@''', Host, ''' IDENTIFIED BY PASSWORD ''', Password, ''';') AS CreateUser
    FROM mysql.user WHERE User != 'root' AND User != '' AND User != 'mysql.sys' AND User != 'mysql.session';
    " > "$backup_file" 2>/dev/null

    print_success "All users backed up to $backup_file"
}

# =============================================================================
# DATA CLONING AND SYNCHRONIZATION FUNCTIONS
# =============================================================================

# Remote MySQL connection setup
setup_remote_mysql_connection() {
    print_header "Remote MySQL Server Configuration"
    
    read -p "Remote MySQL Host/IP: " REMOTE_MYSQL_HOST
    read -p "Remote MySQL Port (default: 3306): " input_port
    REMOTE_MYSQL_PORT=${input_port:-3306}
    read -p "Remote MySQL Username (default: root): " input_user
    REMOTE_MYSQL_USER=${input_user:-root}
    read -s -p "Remote MySQL Password: " REMOTE_MYSQL_PASSWORD
    echo
    
    # Test remote connection
    if test_remote_mysql_connection; then
        print_success "Remote MySQL connection configured successfully"
        return 0
    else
        print_error "Failed to connect to remote MySQL server"
        return 1
    fi
}

# Test remote MySQL connection
test_remote_mysql_connection() {
    print_info "Testing remote MySQL connection..."
    
    if [[ -z "$REMOTE_MYSQL_HOST" ]]; then
        print_error "Remote MySQL host not configured"
        return 1
    fi
    
    if mysql -h"$REMOTE_MYSQL_HOST" -P"$REMOTE_MYSQL_PORT" -u"$REMOTE_MYSQL_USER" -p"$REMOTE_MYSQL_PASSWORD" -e "SELECT 1" &>/dev/null; then
        print_success "Remote MySQL connection successful"
        return 0
    else
        print_error "Remote MySQL connection failed"
        return 1
    fi
}

# Execute query on remote MySQL server
execute_remote_mysql_query() {
    local query="$1"
    local silent="${2:-false}"
    
    if [[ "$silent" == "false" ]]; then
        log_message "Executing remote MySQL query: $query"
    fi
    
    mysql -h"$REMOTE_MYSQL_HOST" -P"$REMOTE_MYSQL_PORT" -u"$REMOTE_MYSQL_USER" -p"$REMOTE_MYSQL_PASSWORD" -e "$query" 2>/dev/null
}

# List databases on remote server
list_remote_databases() {
    print_header "Remote Server Databases"
    
    if ! test_remote_mysql_connection; then
        return 1
    fi
    
    print_info "Databases on remote server ($REMOTE_MYSQL_HOST):"
    execute_remote_mysql_query "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys"
}

# List databases on local server
list_local_databases() {
    print_header "Local Server Databases"
    
    print_info "Databases on local server ($MYSQL_HOST):"
    execute_mysql_query "SHOW DATABASES;" | grep -v "Database\|information_schema\|performance_schema\|mysql\|sys"
}

# Export database to SQL file
export_database() {
    local database="$1"
    local export_file="$2"
    local server_type="$3"  # "local" or "remote"
    
    print_info "Exporting database '$database' to '$export_file'..."
    
    # Create sync directory if it doesn't exist
    mkdir -p "$DATA_SYNC_DIR"
    
    local dump_command=""
    if [[ "$server_type" == "remote" ]]; then
        dump_command="mysqldump -h$REMOTE_MYSQL_HOST -P$REMOTE_MYSQL_PORT -u$REMOTE_MYSQL_USER -p$REMOTE_MYSQL_PASSWORD"
    else
        dump_command="mysqldump -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD"
    fi
    
    # Export database with additional options for better compatibility
    if $dump_command \
        --single-transaction \
        --routines \
        --triggers \
        --events \
        --hex-blob \
        --complete-insert \
        --add-drop-database \
        --create-options \
        --disable-keys \
        --extended-insert \
        --lock-tables=false \
        --quick \
        --set-charset \
        "$database" > "$export_file" 2>/dev/null; then
        
        print_success "Database '$database' exported successfully"
        print_info "Export file: $export_file"
        print_info "File size: $(du -h "$export_file" | cut -f1)"
        return 0
    else
        print_error "Failed to export database '$database'"
        return 1
    fi
}

# Import database from SQL file
import_database() {
    local database="$1"
    local import_file="$2"
    local server_type="$3"  # "local" or "remote"
    local create_db="${4:-true}"  # Whether to create database if not exists
    
    print_info "Importing database '$database' from '$import_file'..."
    
    if [[ ! -f "$import_file" ]]; then
        print_error "Import file not found: $import_file"
        return 1
    fi
    
    local mysql_command=""
    if [[ "$server_type" == "remote" ]]; then
        mysql_command="mysql -h$REMOTE_MYSQL_HOST -P$REMOTE_MYSQL_PORT -u$REMOTE_MYSQL_USER -p$REMOTE_MYSQL_PASSWORD"
    else
        mysql_command="mysql -h$MYSQL_HOST -P$MYSQL_PORT -u$MYSQL_ROOT_USER -p$MYSQL_ROOT_PASSWORD"
    fi
    
    # Create database if requested
    if [[ "$create_db" == "true" ]]; then
        print_info "Creating database '$database' if it doesn't exist..."
        if [[ "$server_type" == "remote" ]]; then
            execute_remote_mysql_query "CREATE DATABASE IF NOT EXISTS \`$database\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        else
            execute_mysql_query "CREATE DATABASE IF NOT EXISTS \`$database\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        fi
    fi
    
    # Import database
    if $mysql_command "$database" < "$import_file" 2>/dev/null; then
        print_success "Database '$database' imported successfully"
        return 0
    else
        print_error "Failed to import database '$database'"
        return 1
    fi
}

# Clone database from remote server to local server
clone_database_from_remote() {
    local database="$1"
    local local_db_name="${2:-$database}"
    
    print_header "Cloning Database from Remote Server"
    
    # Test connections
    if ! test_mysql_connection; then
        print_error "Cannot connect to local MySQL server"
        return 1
    fi
    
    if ! test_remote_mysql_connection; then
        print_error "Cannot connect to remote MySQL server"
        return 1
    fi
    
    # Check if database exists on remote server
    local remote_db_count=$(execute_remote_mysql_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$database';" | tail -n 1)
    if [[ "$remote_db_count" -eq 0 ]]; then
        print_error "Database '$database' does not exist on remote server"
        return 1
    fi
    
    # Check if local database already exists
    if database_exists "$local_db_name"; then
        print_warning "Local database '$local_db_name' already exists"
        read -p "Overwrite existing database? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Clone operation cancelled"
            return 0
        fi
        
        # Backup existing database
        local backup_file="$DATA_SYNC_DIR/backup_${local_db_name}_$(date +%Y%m%d_%H%M%S).sql"
        print_info "Creating backup of existing database..."
        export_database "$local_db_name" "$backup_file" "local"
        
        # Drop existing database
        execute_mysql_query "DROP DATABASE IF EXISTS \`$local_db_name\`;"
    fi
    
    # Export from remote
    local export_file="$DATA_SYNC_DIR/clone_${database}_$(date +%Y%m%d_%H%M%S).sql"
    if ! export_database "$database" "$export_file" "remote"; then
        return 1
    fi
    
    # Import to local
    if import_database "$local_db_name" "$export_file" "local"; then
        print_success "Database '$database' cloned successfully from remote server"
        print_info "Remote: $REMOTE_MYSQL_HOST/$database → Local: $MYSQL_HOST/$local_db_name"
        
        # Clean up temporary file
        rm -f "$export_file"
        return 0
    else
        print_error "Failed to clone database"
        return 1
    fi
}

# Push database from local server to remote server
push_database_to_remote() {
    local database="$1"
    local remote_db_name="${2:-$database}"
    
    print_header "Pushing Database to Remote Server"
    
    # Test connections
    if ! test_mysql_connection; then
        print_error "Cannot connect to local MySQL server"
        return 1
    fi
    
    if ! test_remote_mysql_connection; then
        print_error "Cannot connect to remote MySQL server"
        return 1
    fi
    
    # Check if database exists on local server
    if ! database_exists "$database"; then
        print_error "Database '$database' does not exist on local server"
        return 1
    fi
    
    # Check if remote database already exists
    local remote_db_count=$(execute_remote_mysql_query "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$remote_db_name';" | tail -n 1)
    if [[ "$remote_db_count" -gt 0 ]]; then
        print_warning "Remote database '$remote_db_name' already exists"
        read -p "Overwrite existing remote database? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Push operation cancelled"
            return 0
        fi
        
        # Backup existing remote database
        local backup_file="$DATA_SYNC_DIR/remote_backup_${remote_db_name}_$(date +%Y%m%d_%H%M%S).sql"
        print_info "Creating backup of existing remote database..."
        export_database "$remote_db_name" "$backup_file" "remote"
        
        # Drop existing remote database
        execute_remote_mysql_query "DROP DATABASE IF EXISTS \`$remote_db_name\`;"
    fi
    
    # Export from local
    local export_file="$DATA_SYNC_DIR/push_${database}_$(date +%Y%m%d_%H%M%S).sql"
    if ! export_database "$database" "$export_file" "local"; then
        return 1
    fi
    
    # Import to remote
    if import_database "$remote_db_name" "$export_file" "remote"; then
        print_success "Database '$database' pushed successfully to remote server"
        print_info "Local: $MYSQL_HOST/$database → Remote: $REMOTE_MYSQL_HOST/$remote_db_name"
        
        # Clean up temporary file
        rm -f "$export_file"
        return 0
    else
        print_error "Failed to push database"
        return 1
    fi
}

# Synchronize databases (bidirectional)
synchronize_databases() {
    local local_database="$1"
    local remote_database="$2"
    local sync_direction="$3"  # "pull", "push", or "bidirectional"
    
    print_header "Database Synchronization"
    
    case "$sync_direction" in
        "pull")
            print_info "Pulling database from remote to local..."
            clone_database_from_remote "$remote_database" "$local_database"
            ;;
        "push")
            print_info "Pushing database from local to remote..."
            push_database_to_remote "$local_database" "$remote_database"
            ;;
        "bidirectional")
            print_warning "Bidirectional synchronization requires careful consideration"
            print_info "This will compare timestamps and synchronize both directions"
            
            # Get modification times
            local local_mod_time=$(execute_mysql_query "SELECT MAX(UPDATE_TIME) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$local_database';" | tail -n 1)
            local remote_mod_time=$(execute_remote_mysql_query "SELECT MAX(UPDATE_TIME) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='$remote_database';" | tail -n 1)
            
            if [[ "$local_mod_time" > "$remote_mod_time" ]]; then
                print_info "Local database is newer. Pushing to remote..."
                push_database_to_remote "$local_database" "$remote_database"
            elif [[ "$remote_mod_time" > "$local_mod_time" ]]; then
                print_info "Remote database is newer. Pulling from remote..."
                clone_database_from_remote "$remote_database" "$local_database"
            else
                print_info "Databases appear to be in sync"
            fi
            ;;
        *)
            print_error "Invalid sync direction: $sync_direction"
            return 1
            ;;
    esac
}

# Interactive database cloning
interactive_clone_database() {
    print_header "Interactive Database Cloning"
    
    # Setup remote connection if not configured
    if [[ -z "$REMOTE_MYSQL_HOST" ]]; then
        if ! setup_remote_mysql_connection; then
            return 1
        fi
    fi
    
    echo
    echo "Choose cloning direction:"
    echo "1) Clone from remote server to local"
    echo "2) Push from local server to remote"
    echo "3) Synchronize databases"
    read -p "Enter choice (1-3): " direction_choice
    
    case "$direction_choice" in
        1)
            echo
            print_info "Available databases on remote server:"
            list_remote_databases
            echo
            read -p "Enter remote database name to clone: " remote_db
            read -p "Enter local database name (default: $remote_db): " local_db
            local_db=${local_db:-$remote_db}
            
            clone_database_from_remote "$remote_db" "$local_db"
            ;;
        2)
            echo
            print_info "Available databases on local server:"
            list_local_databases
            echo
            read -p "Enter local database name to push: " local_db
            read -p "Enter remote database name (default: $local_db): " remote_db
            remote_db=${remote_db:-$local_db}
            
            push_database_to_remote "$local_db" "$remote_db"
            ;;
        3)
            echo
            read -p "Enter local database name: " local_db
            read -p "Enter remote database name: " remote_db
            echo
            echo "Synchronization direction:"
            echo "1) Pull (remote → local)"
            echo "2) Push (local → remote)"
            echo "3) Bidirectional (auto-detect)"
            read -p "Enter choice (1-3): " sync_choice
            
            case "$sync_choice" in
                1) synchronize_databases "$local_db" "$remote_db" "pull" ;;
                2) synchronize_databases "$local_db" "$remote_db" "push" ;;
                3) synchronize_databases "$local_db" "$remote_db" "bidirectional" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

# =============================================================================
# USER CREATION FUNCTIONS
# =============================================================================

create_user_with_global_rights() {
    local username="$1"
    local password="$2"
    local hostname="$3"
    local privilege_level="$4"

    print_header "Creating User with Global Rights"

    # Validate inputs
    if ! validate_username "$username" || ! validate_password "$password" || ! validate_hostname "$hostname"; then
        return 1
    fi

    # Check if user already exists
    if user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' already exists"
        return 1
    fi

    # Create user
    print_info "Creating user '$username'@'$hostname'..."

    local create_query="CREATE USER '$username'@'$hostname' IDENTIFIED BY '$password';"

    if execute_mysql_query "$create_query"; then
        print_success "User created successfully"
    else
        print_error "Failed to create user"
        return 1
    fi

    # Grant privileges based on level
    local grant_query=""
    case "$privilege_level" in
        "SUPERUSER"|"ADMIN")
            grant_query="GRANT ALL PRIVILEGES ON *.* TO '$username'@'$hostname' WITH GRANT OPTION;"
            ;;
        "DEVELOPER"|"FULL")
            grant_query="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON *.* TO '$username'@'$hostname';"
            ;;
        "READONLY"|"SELECT")
            grant_query="GRANT SELECT, SHOW VIEW ON *.* TO '$username'@'$hostname';"
            ;;
        "BACKUP")
            grant_query="GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO '$username'@'$hostname';"
            ;;
        *)
            print_error "Invalid privilege level: $privilege_level"
            print_info "Available levels: SUPERUSER, DEVELOPER, READONLY, BACKUP"
            return 1
            ;;
    esac

    print_info "Granting $privilege_level privileges..."

    if execute_mysql_query "$grant_query"; then
        print_success "Privileges granted successfully"
    else
        print_error "Failed to grant privileges"
        return 1
    fi

    # Flush privileges
    execute_mysql_query "FLUSH PRIVILEGES;"

    print_success "User '$username'@'$hostname' created with $privilege_level privileges"

    # Log the action
    log_message "Created user '$username'@'$hostname' with $privilege_level privileges"

    return 0
}

create_user_with_database_rights() {
    local username="$1"
    local password="$2"
    local hostname="$3"
    local database="$4"
    local privilege_level="$5"

    print_header "Creating User with Database-Specific Rights"

    # Validate inputs
    if ! validate_username "$username" || ! validate_password "$password" || ! validate_hostname "$hostname"; then
        return 1
    fi

    # Check if database exists
    if ! database_exists "$database"; then
        print_error "Database '$database' does not exist"
        read -p "Create database '$database'? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if execute_mysql_query "CREATE DATABASE \`$database\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; then
                print_success "Database '$database' created"
            else
                print_error "Failed to create database"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Check if user already exists
    if user_exists "$username" "$hostname"; then
        print_warning "User '$username'@'$hostname' already exists. Adding database privileges..."
    else
        # Create user
        print_info "Creating user '$username'@'$hostname'..."

        local create_query="CREATE USER '$username'@'$hostname' IDENTIFIED BY '$password';"

        if execute_mysql_query "$create_query"; then
            print_success "User created successfully"
        else
            print_error "Failed to create user"
            return 1
        fi
    fi

    # Grant database-specific privileges
    local grant_query=""
    case "$privilege_level" in
        "FULL"|"ALL")
            grant_query="GRANT ALL PRIVILEGES ON \`$database\`.* TO '$username'@'$hostname';"
            ;;
        "DEVELOPER"|"STANDARD")
            grant_query="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON \`$database\`.* TO '$username'@'$hostname';"
            ;;
        "READONLY"|"SELECT")
            grant_query="GRANT SELECT, SHOW VIEW ON \`$database\`.* TO '$username'@'$hostname';"
            ;;
        "READWRITE"|"BASIC")
            grant_query="GRANT SELECT, INSERT, UPDATE, DELETE ON \`$database\`.* TO '$username'@'$hostname';"
            ;;
        *)
            print_error "Invalid privilege level: $privilege_level"
            print_info "Available levels: FULL, DEVELOPER, READONLY, READWRITE"
            return 1
            ;;
    esac

    print_info "Granting $privilege_level privileges on database '$database'..."

    if execute_mysql_query "$grant_query"; then
        print_success "Privileges granted successfully"
    else
        print_error "Failed to grant privileges"
        return 1
    fi

    # Flush privileges
    execute_mysql_query "FLUSH PRIVILEGES;"

    print_success "User '$username'@'$hostname' created with $privilege_level privileges on database '$database'"

    # Log the action
    log_message "Created user '$username'@'$hostname' with $privilege_level privileges on database '$database'"

    return 0
}

# =============================================================================
# USER MODIFICATION FUNCTIONS
# =============================================================================

modify_user_password() {
    local username="$1"
    local hostname="$2"
    local new_password="$3"

    print_header "Modifying User Password"

    # Validate inputs
    if ! validate_username "$username" || ! validate_hostname "$hostname" || ! validate_password "$new_password"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' does not exist"
        return 1
    fi

    # Backup current grants
    backup_user_grants "$username" "$hostname"

    # Change password
    print_info "Changing password for user '$username'@'$hostname'..."

    local alter_query="ALTER USER '$username'@'$hostname' IDENTIFIED BY '$new_password';"

    if execute_mysql_query "$alter_query"; then
        print_success "Password changed successfully"
        log_message "Password changed for user '$username'@'$hostname'"
        return 0
    else
        print_error "Failed to change password"
        return 1
    fi
}

modify_user_privileges() {
    local username="$1"
    local hostname="$2"
    local action="$3"  # GRANT or REVOKE
    local privileges="$4"
    local database="$5"

    print_header "Modifying User Privileges"

    # Validate inputs
    if ! validate_username "$username" || ! validate_hostname "$hostname"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' does not exist"
        return 1
    fi

    # Backup current grants
    backup_user_grants "$username" "$hostname"

    # Construct query based on action
    local query=""
    if [[ "$action" == "GRANT" ]]; then
        if [[ -n "$database" ]]; then
            query="GRANT $privileges ON \`$database\`.* TO '$username'@'$hostname';"
        else
            query="GRANT $privileges ON *.* TO '$username'@'$hostname';"
        fi
    elif [[ "$action" == "REVOKE" ]]; then
        if [[ -n "$database" ]]; then
            query="REVOKE $privileges ON \`$database\`.* FROM '$username'@'$hostname';"
        else
            query="REVOKE $privileges ON *.* FROM '$username'@'$hostname';"
        fi
    else
        print_error "Invalid action: $action (must be GRANT or REVOKE)"
        return 1
    fi

    print_info "${action}ING privileges for user '$username'@'$hostname'..."

    if execute_mysql_query "$query"; then
        execute_mysql_query "FLUSH PRIVILEGES;"
        print_success "Privileges ${action}ED successfully"
        log_message "${action}ED privileges '$privileges' for user '$username'@'$hostname'"
        return 0
    else
        print_error "Failed to ${action,,} privileges"
        return 1
    fi
}

# =============================================================================
# USER DELETION FUNCTIONS
# =============================================================================

delete_user() {
    local username="$1"
    local hostname="$2"
    local force="${3:-false}"

    print_header "Deleting User"

    # Validate inputs
    if ! validate_username "$username" || ! validate_hostname "$hostname"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' does not exist"
        return 1
    fi

    # Show current user privileges
    print_info "Current privileges for user '$username'@'$hostname':"
    execute_mysql_query "SHOW GRANTS FOR '$username'@'$hostname';"

    # Confirmation
    if [[ "$force" != "true" ]]; then
        echo
        read -p "Are you sure you want to delete user '$username'@'$hostname'? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "User deletion cancelled"
            return 0
        fi
    fi

    # Backup current grants
    backup_user_grants "$username" "$hostname"

    # Delete user
    print_info "Deleting user '$username'@'$hostname'..."

    local drop_query="DROP USER '$username'@'$hostname';"

    if execute_mysql_query "$drop_query"; then
        execute_mysql_query "FLUSH PRIVILEGES;"
        print_success "User '$username'@'$hostname' deleted successfully"
        log_message "Deleted user '$username'@'$hostname'"
        return 0
    else
        print_error "Failed to delete user"
        return 1
    fi
}

# =============================================================================
# INFORMATION FUNCTIONS
# =============================================================================

list_users() {
    print_header "MySQL Users List"

    print_info "Current MySQL users:"
    execute_mysql_query "SELECT User, Host, account_locked, password_expired FROM mysql.user ORDER BY User, Host;"
}

show_user_privileges() {
    local username="$1"
    local hostname="$2"

    print_header "User Privileges"

    # Validate inputs
    if ! validate_username "$username" || ! validate_hostname "$hostname"; then
        return 1
    fi

    # Check if user exists
    if ! user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' does not exist"
        return 1
    fi

    print_info "Privileges for user '$username'@'$hostname':"
    execute_mysql_query "SHOW GRANTS FOR '$username'@'$hostname';"
}

# =============================================================================
# INTERACTIVE FUNCTIONS
# =============================================================================

interactive_create_user() {
    print_header "Interactive User Creation"

    # Get user details
    read -p "Enter username: " username
    read -s -p "Enter password: " password
    echo
    read -s -p "Confirm password: " password_confirm
    echo

    if [[ "$password" != "$password_confirm" ]]; then
        print_error "Passwords do not match"
        return 1
    fi

    read -p "Enter hostname (default: localhost): " hostname
    hostname=${hostname:-localhost}

    # Choose privilege scope
    echo
    echo "Choose privilege scope:"
    echo "1) Global privileges"
    echo "2) Database-specific privileges"
    read -p "Enter choice (1-2): " scope_choice

    case "$scope_choice" in
        1)
            echo
            echo "Available global privilege levels:"
            echo "1) SUPERUSER - Full admin access"
            echo "2) DEVELOPER - Development privileges"
            echo "3) READONLY - Read-only access"
            echo "4) BACKUP - Backup privileges"
            read -p "Enter privilege level (1-4): " priv_choice

            case "$priv_choice" in
                1) privilege_level="SUPERUSER" ;;
                2) privilege_level="DEVELOPER" ;;
                3) privilege_level="READONLY" ;;
                4) privilege_level="BACKUP" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac

            create_user_with_global_rights "$username" "$password" "$hostname" "$privilege_level"
            ;;
        2)
            read -p "Enter database name: " database

            echo
            echo "Available database privilege levels:"
            echo "1) FULL - Full database access"
            echo "2) DEVELOPER - Development privileges"
            echo "3) READONLY - Read-only access"
            echo "4) READWRITE - Basic read/write access"
            read -p "Enter privilege level (1-4): " priv_choice

            case "$priv_choice" in
                1) privilege_level="FULL" ;;
                2) privilege_level="DEVELOPER" ;;
                3) privilege_level="READONLY" ;;
                4) privilege_level="READWRITE" ;;
                *) print_error "Invalid choice"; return 1 ;;
            esac

            create_user_with_database_rights "$username" "$password" "$hostname" "$database" "$privilege_level"
            ;;
        *)
            print_error "Invalid choice"
            return 1
            ;;
    esac
}

interactive_modify_user() {
    print_header "Interactive User Modification"

    # Get user details
    read -p "Enter username: " username
    read -p "Enter hostname (default: localhost): " hostname
    hostname=${hostname:-localhost}

    # Check if user exists
    if ! user_exists "$username" "$hostname"; then
        print_error "User '$username'@'$hostname' does not exist"
        return 1
    fi

    # Show current privileges
    show_user_privileges "$username" "$hostname"

    echo
    echo "What would you like to modify?"
    echo "1) Change password"
    echo "2) Grant privileges"
    echo "3) Revoke privileges"
    read -p "Enter choice (1-3): " modify_choice

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

            modify_user_password "$username" "$hostname" "$new_password"
            ;;
        2)
            read -p "Enter privileges to grant (e.g., SELECT, INSERT, UPDATE): " privileges
            read -p "Enter database name (leave empty for global): " database

            modify_user_privileges "$username" "$hostname" "GRANT" "$privileges" "$database"
            ;;
        3)
            read -p "Enter privileges to revoke (e.g., SELECT, INSERT, UPDATE): " privileges
            read -p "Enter database name (leave empty for global): " database

            modify_user_privileges "$username" "$hostname" "REVOKE" "$privileges" "$database"
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
    read -p "Enter hostname (default: localhost): " hostname
    hostname=${hostname:-localhost}

    delete_user "$username" "$hostname"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    clear
    print_header "MySQL Administration Toolkit"
    echo
    echo -e "${WHITE}Please select an option:${NC}"
    echo
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${GREEN}USER CREATION OPTIONS${NC}                                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}1)${NC} Create user with global rights                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}2)${NC} Create user with database-specific rights                                           ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}8)${NC} Interactive user creation (guided)                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${PURPLE}USER MODIFICATION OPTIONS${NC}                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}3)${NC} Modify user password                                                                ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}4)${NC} Modify user privileges                                                              ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}9)${NC} Interactive user modification (guided)                                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}USER MANAGEMENT OPTIONS${NC}                                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}5)${NC} Delete user                                                                         ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}6)${NC} List all users                                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}7)${NC} Show user privileges                                                               ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}10)${NC} Interactive user deletion (guided)                                               ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}DATA CLONING & SYNCHRONIZATION${NC}                                                           ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}11)${NC} Setup remote MySQL connection                                                     ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}12)${NC} Clone database from remote server                                                 ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}13)${NC} Push database to remote server                                                    ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}14)${NC} Synchronize databases                                                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}15)${NC} Interactive database cloning (guided)                                            ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}16)${NC} List remote databases                                                             ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${WHITE}SYSTEM OPTIONS${NC}                                                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}17)${NC} Backup all users                                                                  ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}18)${NC} Test MySQL connection                                                             ${CYAN}║${NC}"
    echo -e "${CYAN}║${NC} ${YELLOW}19)${NC} Test remote MySQL connection                                                      ${CYAN}║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} ${RED}0)${NC} Exit                                                                                   ${CYAN}║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${WHITE}Enter your choice (0-19): ${NC}\c"
    read choice

    case "$choice" in
        1)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}
            read -p "Privilege level (SUPERUSER/DEVELOPER/READONLY/BACKUP): " privilege_level

            create_user_with_global_rights "$username" "$password" "$hostname" "$privilege_level"
            ;;
        2)
            read -p "Username: " username
            read -s -p "Password: " password
            echo
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}
            read -p "Database name: " database
            read -p "Privilege level (FULL/DEVELOPER/READONLY/READWRITE): " privilege_level

            create_user_with_database_rights "$username" "$password" "$hostname" "$database" "$privilege_level"
            ;;
        3)
            read -p "Username: " username
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}
            read -s -p "New password: " new_password
            echo

            modify_user_password "$username" "$hostname" "$new_password"
            ;;
        4)
            read -p "Username: " username
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}
            read -p "Action (GRANT/REVOKE): " action
            read -p "Privileges (e.g., SELECT, INSERT, UPDATE): " privileges
            read -p "Database name (leave empty for global): " database

            modify_user_privileges "$username" "$hostname" "$action" "$privileges" "$database"
            ;;
        5)
            read -p "Username: " username
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}

            delete_user "$username" "$hostname"
            ;;
        6)
            list_users
            ;;
        7)
            read -p "Username: " username
            read -p "Hostname (default: localhost): " hostname
            hostname=${hostname:-localhost}

            show_user_privileges "$username" "$hostname"
            ;;
        8)
            interactive_create_user
            ;;
        9)
            interactive_modify_user
            ;;
        10)
            interactive_delete_user
            ;;
        11)
            setup_remote_mysql_connection
            ;;
        12)
            echo
            print_info "Available databases on remote server:"
            list_remote_databases
            echo
            read -p "Enter remote database name to clone: " remote_db
            read -p "Enter local database name (default: $remote_db): " local_db
            local_db=${local_db:-$remote_db}
            clone_database_from_remote "$remote_db" "$local_db"
            ;;
        13)
            echo
            print_info "Available databases on local server:"
            list_local_databases
            echo
            read -p "Enter local database name to push: " local_db
            read -p "Enter remote database name (default: $local_db): " remote_db
            remote_db=${remote_db:-$local_db}
            push_database_to_remote "$local_db" "$remote_db"
            ;;
        14)
            echo
            read -p "Enter local database name: " local_db
            read -p "Enter remote database name: " remote_db
            echo
            echo "Synchronization direction:"
            echo "1) Pull (remote → local)"
            echo "2) Push (local → remote)"
            echo "3) Bidirectional (auto-detect)"
            read -p "Enter choice (1-3): " sync_choice
            
            case "$sync_choice" in
                1) synchronize_databases "$local_db" "$remote_db" "pull" ;;
                2) synchronize_databases "$local_db" "$remote_db" "push" ;;
                3) synchronize_databases "$local_db" "$remote_db" "bidirectional" ;;
                *) print_error "Invalid choice" ;;
            esac
            ;;
        15)
            interactive_clone_database
            ;;
        16)
            list_remote_databases
            ;;
        17)
            backup_all_users
            ;;
        18)
            test_mysql_connection
            ;;
        19)
            test_remote_mysql_connection
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
# COMMAND LINE INTERFACE
# =============================================================================

show_help() {
    echo "MySQL Administration Toolkit"
    echo
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo
    echo "Commands:"
    echo "  create-global USERNAME PASSWORD HOSTNAME PRIVILEGE_LEVEL"
    echo "  create-database USERNAME PASSWORD HOSTNAME DATABASE PRIVILEGE_LEVEL"
    echo "  modify-password USERNAME HOSTNAME NEW_PASSWORD"
    echo "  modify-privileges USERNAME HOSTNAME ACTION PRIVILEGES [DATABASE]"
    echo "  delete-user USERNAME HOSTNAME"
    echo "  list-users"
    echo "  show-privileges USERNAME HOSTNAME"
    echo "  backup-users"
    echo "  test-connection"
    echo
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -i, --interactive   Run in interactive mode"
    echo "  -c, --config FILE   Use custom configuration file"
    echo "  -f, --force    Force operation without confirmation"
    echo
    echo "Examples:"
    echo "  $0 create-global myuser mypass123 localhost DEVELOPER"
    echo "  $0 create-database appuser apppass123 localhost myapp_db FULL"
    echo "  $0 modify-password myuser localhost newpass123"
    echo "  $0 delete-user myuser localhost"
    echo "  $0 --interactive"
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

    log_message "MySQL Administration Toolkit started"

    # Setup MySQL connection
    setup_mysql_connection

    # Test connection
    if ! test_mysql_connection; then
        print_error "Cannot connect to MySQL. Please check your configuration."
        exit 1
    fi

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
        create-global)
            if [[ $# -eq 5 ]]; then
                create_user_with_global_rights "$2" "$3" "$4" "$5"
            else
                print_error "Usage: $0 create-global USERNAME PASSWORD HOSTNAME PRIVILEGE_LEVEL"
                exit 1
            fi
            ;;
        create-database)
            if [[ $# -eq 6 ]]; then
                create_user_with_database_rights "$2" "$3" "$4" "$5" "$6"
            else
                print_error "Usage: $0 create-database USERNAME PASSWORD HOSTNAME DATABASE PRIVILEGE_LEVEL"
                exit 1
            fi
            ;;
        modify-password)
            if [[ $# -eq 4 ]]; then
                modify_user_password "$2" "$3" "$4"
            else
                print_error "Usage: $0 modify-password USERNAME HOSTNAME NEW_PASSWORD"
                exit 1
            fi
            ;;
        modify-privileges)
            if [[ $# -ge 5 ]]; then
                modify_user_privileges "$2" "$3" "$4" "$5" "$6"
            else
                print_error "Usage: $0 modify-privileges USERNAME HOSTNAME ACTION PRIVILEGES [DATABASE]"
                exit 1
            fi
            ;;
        delete-user)
            if [[ $# -eq 3 ]]; then
                delete_user "$2" "$3"
            else
                print_error "Usage: $0 delete-user USERNAME HOSTNAME"
                exit 1
            fi
            ;;
        list-users)
            list_users
            ;;
        show-privileges)
            if [[ $# -eq 3 ]]; then
                show_user_privileges "$2" "$3"
            else
                print_error "Usage: $0 show-privileges USERNAME HOSTNAME"
                exit 1
            fi
            ;;
        backup-users)
            backup_all_users
            ;;
        test-connection)
            test_mysql_connection
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

# Check if script is run as root for certain operations
if [[ $EUID -ne 0 ]] && [[ "${1:-}" != "--help" ]] && [[ "${1:-}" != "-h" ]]; then
    print_warning "Some operations may require root privileges"
fi

# Run main function
main "$@"
