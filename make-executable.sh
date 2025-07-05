#!/bin/bash

# =============================================================================
# Script Permission Manager
# =============================================================================
# Description: Automatically set execute permissions for script files in directory
# Author: System Administrator
# Version: 1.0
# Usage: ./make-executable.sh [OPTIONS] [DIRECTORY]
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
SCRIPT_NAME=$(basename "$0")
DEFAULT_DIRECTORY="."
LOG_FILE="/tmp/make-executable.log"
DRY_RUN=false
RECURSIVE=false
VERBOSE=false
FORCE=false
BACKUP=false

# Script file extensions to process
SCRIPT_EXTENSIONS=("sh" "bash" "py" "pl" "rb" "js" "php" "lua" "awk" "sed" "tcl" "expect" "zsh" "fish" "csh" "ksh")

# Files to exclude (patterns)
EXCLUDE_PATTERNS=("*.bak" "*.tmp" "*.log" "*.conf" "*.config" "*.txt" "*.md" "*.json" "*.xml" "*.yaml" "*.yml")

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
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

show_help() {
    cat << EOF
Script Permission Manager - Set execute permissions for script files

Usage: $SCRIPT_NAME [OPTIONS] [DIRECTORY]

DESCRIPTION:
    Automatically identifies and sets execute permissions (chmod +x) for script files
    in the specified directory. Supports various script types and provides comprehensive
    logging and safety features.

OPTIONS:
    -r, --recursive         Process directories recursively
    -d, --dry-run          Show what would be done without making changes
    -v, --verbose          Enable verbose output
    -f, --force            Force execution without confirmation prompts
    -b, --backup           Create backup of original permissions
    -e, --extensions LIST  Comma-separated list of extensions to process
    -x, --exclude PATTERN  Exclude files matching pattern (can be used multiple times)
    -l, --log FILE         Specify custom log file location
    -h, --help             Show this help message

ARGUMENTS:
    DIRECTORY              Directory to process (default: current directory)

EXAMPLES:
    $SCRIPT_NAME                           # Process current directory
    $SCRIPT_NAME /home/user/scripts        # Process specific directory
    $SCRIPT_NAME -r /home/user/projects    # Process recursively
    $SCRIPT_NAME -d -v                     # Dry run with verbose output
    $SCRIPT_NAME -e "sh,py,pl" ./scripts   # Process only specific extensions
    $SCRIPT_NAME -x "*.bak" -x "test*"     # Exclude backup files and test files

SUPPORTED EXTENSIONS:
    ${SCRIPT_EXTENSIONS[@]}

SAFETY FEATURES:
    • Dry run mode to preview changes
    • Backup original permissions
    • Comprehensive logging
    • Exclude patterns for safety
    • Self-exclusion from processing

EOF
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        print_error "Directory '$dir' does not exist or is not a directory"
        return 1
    fi

    if [[ ! -r "$dir" ]]; then
        print_error "Directory '$dir' is not readable"
        return 1
    fi

    return 0
}

is_script_file() {
    local file="$1"
    local filename=$(basename "$file")
    local extension="${filename##*.}"

    # Check if file has a script extension
    for ext in "${SCRIPT_EXTENSIONS[@]}"; do
        if [[ "$extension" == "$ext" ]]; then
            return 0
        fi
    done

    # Check shebang line for files without extension
    if [[ -f "$file" && -r "$file" ]]; then
        local first_line=$(head -n 1 "$file" 2>/dev/null)
        if [[ "$first_line" =~ ^#! ]]; then
            return 0
        fi
    fi

    return 1
}

should_exclude_file() {
    local file="$1"
    local filename=$(basename "$file")

    # Exclude this script itself
    if [[ "$filename" == "$SCRIPT_NAME" ]]; then
        return 0
    fi

    # Check exclude patterns
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        if [[ "$filename" == $pattern ]]; then
            return 0
        fi
    done

    return 1
}

is_already_executable() {
    local file="$1"

    if [[ -x "$file" ]]; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

create_backup() {
    local file="$1"
    local backup_dir="/tmp/permissions_backup_$(date +%Y%m%d_%H%M%S)"
    local relative_path="${file#$DEFAULT_DIRECTORY/}"
    local backup_file="$backup_dir/$relative_path"

    # Create backup directory structure
    mkdir -p "$(dirname "$backup_file")"

    # Store original permissions
    local permissions=$(stat -c "%a" "$file" 2>/dev/null)
    echo "$file:$permissions" >> "$backup_dir/permissions.txt"

    if [[ "$VERBOSE" == true ]]; then
        print_info "Backed up permissions for $file ($permissions)"
    fi

    return 0
}

restore_permissions() {
    local backup_file="$1"

    if [[ ! -f "$backup_file" ]]; then
        print_error "Backup file '$backup_file' not found"
        return 1
    fi

    print_info "Restoring permissions from backup..."

    while IFS=':' read -r file permissions; do
        if [[ -f "$file" ]]; then
            chmod "$permissions" "$file"
            print_success "Restored permissions for $file ($permissions)"
        else
            print_warning "File $file not found, skipping"
        fi
    done < "$backup_file"

    return 0
}

# =============================================================================
# MAIN PROCESSING FUNCTIONS
# =============================================================================

process_file() {
    local file="$1"
    local filename=$(basename "$file")

    # Skip if should be excluded
    if should_exclude_file "$file"; then
        if [[ "$VERBOSE" == true ]]; then
            print_warning "Excluding: $file"
        fi
        return 0
    fi

    # Check if it's a script file
    if ! is_script_file "$file"; then
        if [[ "$VERBOSE" == true ]]; then
            print_info "Not a script file: $file"
        fi
        return 0
    fi

    # Check if already executable
    if is_already_executable "$file"; then
        if [[ "$VERBOSE" == true ]]; then
            print_info "Already executable: $file"
        fi
        return 0
    fi

    # Create backup if requested
    if [[ "$BACKUP" == true ]]; then
        create_backup "$file"
    fi

    # Process the file
    if [[ "$DRY_RUN" == true ]]; then
        print_highlight "Would make executable: $file"
        log_message "DRY RUN: Would chmod +x $file"
    else
        if chmod +x "$file"; then
            print_success "Made executable: $file"
            log_message "Successfully chmod +x $file"
        else
            print_error "Failed to make executable: $file"
            log_message "ERROR: Failed to chmod +x $file"
            return 1
        fi
    fi

    return 0
}

process_directory() {
    local dir="$1"
    local file_count=0
    local processed_count=0
    local error_count=0

    print_header "Processing Directory: $dir"

    # Validate directory
    if ! validate_directory "$dir"; then
        return 1
    fi

    # Get list of files to process
    local find_cmd="find \"$dir\""

    if [[ "$RECURSIVE" == false ]]; then
        find_cmd="$find_cmd -maxdepth 1"
    fi

    find_cmd="$find_cmd -type f"

    # Process files
    while IFS= read -r -d '' file; do
        ((file_count++))

        if process_file "$file"; then
            ((processed_count++))
        else
            ((error_count++))
        fi

    done < <(eval "$find_cmd" -print0)

    # Print summary
    echo
    print_header "Processing Summary"
    print_info "Total files found: $file_count"
    print_info "Files processed: $processed_count"

    if [[ $error_count -gt 0 ]]; then
        print_warning "Errors encountered: $error_count"
    fi

    if [[ "$DRY_RUN" == true ]]; then
        print_highlight "DRY RUN MODE - No changes were made"
    fi

    return 0
}

# =============================================================================
# INTERACTIVE FUNCTIONS
# =============================================================================

interactive_mode() {
    print_header "Interactive Script Permission Manager"

    # Get directory
    read -p "Enter directory path (default: current directory): " target_dir
    target_dir=${target_dir:-$DEFAULT_DIRECTORY}

    # Validate directory
    if ! validate_directory "$target_dir"; then
        return 1
    fi

    # Get options
    echo
    print_info "Configuration Options:"

    read -p "Process recursively? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        RECURSIVE=true
    fi

    read -p "Enable verbose output? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        VERBOSE=true
    fi

    read -p "Create backup of original permissions? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        BACKUP=true
    fi

    read -p "Perform dry run first? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DRY_RUN=true
        print_info "Performing dry run..."
        process_directory "$target_dir"

        echo
        read -p "Proceed with actual changes? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            DRY_RUN=false
        else
            print_info "Operation cancelled by user"
            return 0
        fi
    fi

    # Process directory
    process_directory "$target_dir"

    return 0
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

scan_directory() {
    local dir="$1"

    print_header "Scanning Directory: $dir"

    if ! validate_directory "$dir"; then
        return 1
    fi

    local total_files=0
    local script_files=0
    local executable_files=0
    local needs_permission=0

    # Scan files
    while IFS= read -r -d '' file; do
        ((total_files++))

        if is_script_file "$file"; then
            ((script_files++))

            if is_already_executable "$file"; then
                ((executable_files++))
            else
                ((needs_permission++))
                if [[ "$VERBOSE" == true ]]; then
                    print_info "Needs +x: $file"
                fi
            fi
        fi

    done < <(find "$dir" -type f -print0)

    # Print results
    echo
    print_header "Scan Results"
    print_info "Total files: $total_files"
    print_info "Script files: $script_files"
    print_info "Already executable: $executable_files"
    print_info "Need execute permission: $needs_permission"

    if [[ $needs_permission -gt 0 ]]; then
        print_highlight "$needs_permission script files need execute permission"
    else
        print_success "All script files already have execute permission"
    fi

    return 0
}

list_script_types() {
    local dir="$1"

    print_header "Script Types Found in: $dir"

    if ! validate_directory "$dir"; then
        return 1
    fi

    declare -A extension_count
    declare -A shebang_count

    # Analyze files
    while IFS= read -r -d '' file; do
        local filename=$(basename "$file")
        local extension="${filename##*.}"

        # Count by extension
        if [[ "$filename" != "$extension" ]]; then
            ((extension_count[$extension]++))
        fi

        # Count by shebang
        if [[ -f "$file" && -r "$file" ]]; then
            local first_line=$(head -n 1 "$file" 2>/dev/null)
            if [[ "$first_line" =~ ^#! ]]; then
                local interpreter=$(echo "$first_line" | sed 's/^#!//' | awk '{print $1}' | xargs basename)
                ((shebang_count[$interpreter]++))
            fi
        fi

    done < <(find "$dir" -type f -print0)

    # Print extension summary
    echo
    print_info "Files by Extension:"
    for ext in "${!extension_count[@]}"; do
        printf "  %-10s: %d files\n" "$ext" "${extension_count[$ext]}"
    done

    # Print shebang summary
    echo
    print_info "Files by Interpreter:"
    for interpreter in "${!shebang_count[@]}"; do
        printf "  %-10s: %d files\n" "$interpreter" "${shebang_count[$interpreter]}"
    done

    return 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    local target_directory="$DEFAULT_DIRECTORY"
    local custom_extensions=()
    local custom_excludes=()

    # Initialize log file
    echo "Script Permission Manager - $(date)" > "$LOG_FILE"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -r|--recursive)
                RECURSIVE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -b|--backup)
                BACKUP=true
                shift
                ;;
            -e|--extensions)
                IFS=',' read -ra custom_extensions <<< "$2"
                SCRIPT_EXTENSIONS=("${custom_extensions[@]}")
                shift 2
                ;;
            -x|--exclude)
                custom_excludes+=("$2")
                shift 2
                ;;
            -l|--log)
                LOG_FILE="$2"
                shift 2
                ;;
            -i|--interactive)
                interactive_mode
                exit 0
                ;;
            -s|--scan)
                scan_directory "${2:-$DEFAULT_DIRECTORY}"
                exit 0
                ;;
            --list-types)
                list_script_types "${2:-$DEFAULT_DIRECTORY}"
                exit 0
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                target_directory="$1"
                shift
                ;;
        esac
    done

    # Add custom excludes to exclude patterns
    if [[ ${#custom_excludes[@]} -gt 0 ]]; then
        EXCLUDE_PATTERNS+=("${custom_excludes[@]}")
    fi

    # Validate target directory
    if ! validate_directory "$target_directory"; then
        exit 1
    fi

    # Show configuration if verbose
    if [[ "$VERBOSE" == true ]]; then
        print_header "Configuration"
        print_info "Target Directory: $target_directory"
        print_info "Recursive: $RECURSIVE"
        print_info "Dry Run: $DRY_RUN"
        print_info "Backup: $BACKUP"
        print_info "Log File: $LOG_FILE"
        print_info "Extensions: ${SCRIPT_EXTENSIONS[*]}"
        print_info "Exclude Patterns: ${EXCLUDE_PATTERNS[*]}"
        echo
    fi

    # Confirmation prompt (unless force mode)
    if [[ "$FORCE" == false && "$DRY_RUN" == false ]]; then
        echo
        print_warning "This will modify file permissions in: $target_directory"
        if [[ "$RECURSIVE" == true ]]; then
            print_warning "Recursive mode is enabled"
        fi
        echo
        read -p "Are you sure you want to continue? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled by user"
            exit 0
        fi
    fi

    # Process the directory
    process_directory "$target_directory"

    # Show log file location
    print_info "Log file: $LOG_FILE"

    exit 0
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
