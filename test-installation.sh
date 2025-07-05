#!/bin/bash

# =============================================================================
# Ubuntu Server Setup Test Script
# =============================================================================
# Description: Test script to verify the installation setup works correctly
# Author: System Administrator
# Version: 1.0
# =============================================================================

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

test_script_execution() {
    print_header "Testing Script Execution"
    
    # Test make-executable functionality
    print_info "Testing make-executable functionality..."
    if [[ -f "ubuntu-server-complete-setup.sh" ]]; then
        print_success "Main setup script found"
        
        # Test --help option
        print_info "Testing --help option..."
        if ./ubuntu-server-complete-setup.sh --help > /dev/null 2>&1; then
            print_success "Help option works correctly"
        else
            print_error "Help option failed"
            return 1
        fi
        
        # Test --make-executable option
        print_info "Testing --make-executable option..."
        if ./ubuntu-server-complete-setup.sh --make-executable > /dev/null 2>&1; then
            print_success "Make-executable option works correctly"
        else
            print_error "Make-executable option failed"
            return 1
        fi
        
    else
        print_error "Main setup script not found"
        return 1
    fi
    
    return 0
}

test_script_permissions() {
    print_header "Testing Script Permissions"
    
    local script_files=("ubuntu-server-complete-setup.sh" "make-executable.sh" "ubuntu-user-manager.sh" "mysql-user-manager.sh" "clone-and-run.sh" "install.sh")
    
    for script in "${script_files[@]}"; do
        if [[ -f "$script" ]]; then
            if [[ -x "$script" ]]; then
                print_success "$script is executable"
            else
                print_error "$script is not executable"
                return 1
            fi
        else
            print_info "$script not found (optional)"
        fi
    done
    
    return 0
}

test_script_syntax() {
    print_header "Testing Script Syntax"
    
    local script_files=("ubuntu-server-complete-setup.sh" "make-executable.sh" "ubuntu-user-manager.sh" "mysql-user-manager.sh" "clone-and-run.sh" "install.sh")
    
    for script in "${script_files[@]}"; do
        if [[ -f "$script" ]]; then
            print_info "Checking syntax of $script..."
            if bash -n "$script"; then
                print_success "$script syntax is valid"
            else
                print_error "$script has syntax errors"
                return 1
            fi
        else
            print_info "$script not found (optional)"
        fi
    done
    
    return 0
}

main() {
    print_header "Ubuntu Server Setup Test Suite"
    
    local test_results=0
    
    # Run tests
    if test_script_syntax; then
        print_success "Script syntax tests passed"
    else
        print_error "Script syntax tests failed"
        ((test_results++))
    fi
    
    if test_script_permissions; then
        print_success "Script permissions tests passed"
    else
        print_error "Script permissions tests failed"
        ((test_results++))
    fi
    
    if test_script_execution; then
        print_success "Script execution tests passed"
    else
        print_error "Script execution tests failed"
        ((test_results++))
    fi
    
    # Summary
    echo
    print_header "Test Summary"
    if [[ $test_results -eq 0 ]]; then
        print_success "All tests passed! Setup scripts are working correctly."
    else
        print_error "$test_results test(s) failed. Please review the output above."
        exit 1
    fi
    
    return 0
}

# Run the test suite
main "$@" 