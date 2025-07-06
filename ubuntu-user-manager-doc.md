# Ubuntu User Management Script Documentation

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [User Types](#user-types)
7. [Permission Levels](#permission-levels)
8. [Commands Reference](#commands-reference)
9. [Interactive Mode](#interactive-mode)
10. [Security Considerations](#security-considerations)
11. [Backup and Recovery](#backup-and-recovery)
12. [Troubleshooting](#troubleshooting)
13. [Best Practices](#best-practices)
14. [Examples](#examples)
15. [FAQ](#faq)

---

## Overview

The Ubuntu User Management Script is a comprehensive bash utility designed to simplify Ubuntu system user administration. It provides both command-line and interactive interfaces for creating, modifying, and deleting system users with various permission levels and group memberships.

### Key Capabilities
- Create different types of users (basic, service, sudo-enabled)
- Modify user passwords, information, and group memberships
- Manage sudo access with different privilege levels
- Delete users safely with confirmation and cleanup
- List all users and their detailed information
- Automatic backup of user data before modifications
- Strong validation and error handling
- Comprehensive logging and audit trail

### Compatibility
- **Ubuntu Versions**: 18.04+, 20.04+, 22.04+, 24.04+
- **Shell**: Bash 4.0+
- **Privileges**: Root or sudo access required
- **Dependencies**: Standard Ubuntu utilities (useradd, usermod, userdel, etc.)

---

## Features

### ✅ User Creation
- **Basic Users**: Standard user accounts with home directories
- **Service Users**: System users for applications and services
- **Sudo Users**: Users with administrative privileges
- **Group Users**: Users with specific group memberships

### ✅ User Modification
- **Password Changes**: Secure password updates
- **Information Updates**: Full name, shell, home directory
- **Group Management**: Add, remove, or replace group memberships
- **Sudo Management**: Grant, revoke, or modify sudo access

### ✅ User Deletion
- **Safe Deletion**: Confirmation prompts and process cleanup
- **Home Directory Management**: Option to preserve or remove
- **Mail Spool Cleanup**: Optional mail spool removal
- **Process Termination**: Automatic cleanup of user processes

### ✅ Security Features
- **Strong Validation**: Username, password, and email validation
- **Automatic Backups**: User data backup before modifications
- **Secure Logging**: Comprehensive audit trail
- **Permission Checks**: Proper file and directory permissions

### ✅ User Experience
- **Interactive Mode**: Guided user interface
- **Command Line**: Scriptable automation
- **Comprehensive Help**: Built-in documentation
- **Error Handling**: Clear error messages and recovery

---

## Installation

### 0. Fast Load Script
```bash
#if inside the script folder, go to the parent folder
cd ..
#remove the script folder
sudo rm -rf UbuntuServerSetupScript
#clone the script folder
git clone https://github.com/frontlook-admin/UbuntuServerSetupScript.git
#go to the script folder
cd UbuntuServerSetupScript
#make the script executable
sudo chmod +x ubuntu-server-complete-setup.sh
#run the script
./ubuntu-server-complete-setup.sh
```

```bash
#if inside the script folder, go to the parent folder
cd ..

sudo rm -rf UbuntuServerSetupScript
git clone https://github.com/frontlook-admin/UbuntuServerSetupScript.git
cd UbuntuServerSetupScript
sudo chmod +x ubuntu-server-complete-setup.sh
./ubuntu-server-complete-setup.sh
```

### 1. Download the Script
```bash
# Download directly (replace with actual URL)
wget https://raw.githubusercontent.com/your-repo/ubuntu-user-manager.sh

# Or create the file manually
sudo nano ubuntu-user-manager.sh
# Copy and paste the script content
```

### 2. Make Executable
```bash
chmod +x ubuntu-user-manager.sh
```

### 3. Move to System Path (Optional)
```bash
sudo mv ubuntu-user-manager.sh /usr/local/bin/ubuntu-user-manager
```

### 4. Verify Installation
```bash
sudo ./ubuntu-user-manager.sh --help
```

---

## Configuration

### System Requirements
- Root or sudo access
- Ubuntu 18.04 or later
- Bash shell environment
- Standard Ubuntu user management utilities

### Log Files
- **Main Log**: `/var/log/ubuntu-user-management.log`
- **Backup Directory**: `/var/backups/system-users/`
- **Configuration**: `/etc/ubuntu-user-manager.conf`

### Default Settings
- **Default Shell**: `/bin/bash`
- **Default Home Directory**: `/home/username`
- **Service User Shell**: `/bin/false`
- **Service User Home**: `/var/lib/username`

---

## Usage

### Command Line Interface

#### Basic Syntax
```bash
sudo ./ubuntu-user-manager.sh [OPTIONS] [COMMAND] [ARGUMENTS]
```

#### Available Options
```bash
-h, --help          Show help message
-i, --interactive   Run in interactive mode
-f, --force         Force operation without confirmation
-v, --verbose       Enable verbose output
```

#### Quick Start Examples
```bash
# Interactive mode (recommended for beginners)
sudo ./ubuntu-user-manager.sh --interactive

# Create basic user
sudo ./ubuntu-user-manager.sh create-basic johndoe mypassword123 "John Doe"

# Create user with groups
sudo ./ubuntu-user-manager.sh create-groups appuser apppass123 "App User" "www-data,docker"

# Create sudo user
sudo ./ubuntu-user-manager.sh create-sudo admin adminpass123 "Admin User" full

# Delete user
sudo ./ubuntu-user-manager.sh delete-user johndoe true true

# List all users
sudo ./ubuntu-user-manager.sh list-users

# Show help
sudo ./ubuntu-user-manager.sh --help
```

---

## User Types

### Basic User
Standard user account with home directory and shell access.

**Features:**
- Home directory creation
- Standard shell access
- Basic file permissions
- Password expiration on first login

**Use Cases:**
- Regular system users
- Development accounts
- Personal accounts

### Service User
System user for applications and services.

**Features:**
- No shell access (typically `/bin/false`)
- Custom home directory
- Locked password
- System UID range

**Use Cases:**
- Web server processes
- Database services
- Application daemons

### Sudo User
User with administrative privileges.

**Features:**
- Administrative access
- Configurable sudo levels
- Security logging
- Password or passwordless options

**Use Cases:**
- System administrators
- DevOps engineers
- Maintenance accounts

### Group User
User with specific group memberships.

**Features:**
- Multiple group assignments
- Inherited group permissions
- Flexible access control
- Easy permission management

**Use Cases:**
- Development teams
- Shared resource access
- Role-based access control

---

## Permission Levels

### Sudo Access Levels

#### Full Sudo Access
```bash
# User added to sudo group
usermod -a -G sudo username
```
**Capabilities:**
- Complete system administration
- All sudo commands available
- Password required for sudo

#### Limited Sudo Access
```bash
# Custom sudoers file
username ALL=(ALL) /usr/bin/apt, /usr/bin/systemctl, /usr/bin/service, /usr/bin/mount, /usr/bin/umount
```
**Capabilities:**
- Package management (apt)
- Service management (systemctl, service)
- Filesystem operations (mount, umount)
- Password required for sudo

#### Passwordless Sudo Access
```bash
# Passwordless sudoers entry
username ALL=(ALL) NOPASSWD: ALL
```
**Capabilities:**
- Complete system administration
- No password required for sudo
- **Security Risk**: Use with caution

### Common System Groups

#### Administrative Groups
- **sudo**: Full administrative access
- **adm**: System log access
- **staff**: Local software installation

#### Service Groups
- **www-data**: Web server access
- **docker**: Docker container management
- **mysql**: Database access

#### Hardware Groups
- **audio**: Audio device access
- **video**: Video device access
- **dialout**: Serial port access
- **cdrom**: CD-ROM access

#### Network Groups
- **netdev**: Network device management
- **bluetooth**: Bluetooth access
- **wireshark**: Network packet capture

---

## Commands Reference

### User Creation Commands

#### create-basic
Create a basic user account.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh create-basic USERNAME PASSWORD FULL_NAME [SHELL]
```

**Parameters:**
- `USERNAME`: System username (required)
- `PASSWORD`: User password (required)
- `FULL_NAME`: Full name in quotes (required)
- `SHELL`: Login shell (optional, default: /bin/bash)

**Example:**
```bash
sudo ./ubuntu-user-manager.sh create-basic johndoe "MyP@ssw0rd" "John Doe" "/bin/bash"
```

#### create-groups
Create a user with specific group memberships.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh create-groups USERNAME PASSWORD FULL_NAME GROUPS [SHELL]
```

**Parameters:**
- `USERNAME`: System username (required)
- `PASSWORD`: User password (required)
- `FULL_NAME`: Full name in quotes (required)
- `GROUPS`: Comma-separated group list (required)
- `SHELL`: Login shell (optional, default: /bin/bash)

**Example:**
```bash
sudo ./ubuntu-user-manager.sh create-groups webdev "Dev@2024" "Web Developer" "www-data,docker,sudo"
```

#### create-sudo
Create a user with sudo access.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh create-sudo USERNAME PASSWORD FULL_NAME SUDO_TYPE
```

**Parameters:**
- `USERNAME`: System username (required)
- `PASSWORD`: User password (required)
- `FULL_NAME`: Full name in quotes (required)
- `SUDO_TYPE`: Sudo access level (required: full, limited, passwordless)

**Example:**
```bash
sudo ./ubuntu-user-manager.sh create-sudo admin "Admin@2024" "System Admin" full
```

#### create-service
Create a service user for applications.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh create-service USERNAME [HOME_DIR] [SHELL]
```

**Parameters:**
- `USERNAME`: System username (required)
- `HOME_DIR`: Home directory path (optional, default: /var/lib/username)
- `SHELL`: Login shell (optional, default: /bin/false)

**Example:**
```bash
sudo ./ubuntu-user-manager.sh create-service webapp "/var/lib/webapp" "/bin/false"
```

### User Modification Commands

#### modify-password
Change a user's password.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh modify-password USERNAME NEW_PASSWORD
```

**Example:**
```bash
sudo ./ubuntu-user-manager.sh modify-password johndoe "NewP@ssw0rd"
```

#### modify-info
Update user information.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh modify-info USERNAME [FULL_NAME] [SHELL] [HOME_DIR]
```

**Example:**
```bash
sudo ./ubuntu-user-manager.sh modify-info johndoe "John Smith" "/bin/zsh" "/home/johnsmith"
```

#### modify-groups
Modify user group memberships.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh modify-groups USERNAME ACTION GROUPS
```

**Parameters:**
- `ACTION`: Group action (add, remove, replace)
- `GROUPS`: Comma-separated group list

**Examples:**
```bash
# Add user to groups
sudo ./ubuntu-user-manager.sh modify-groups johndoe add "docker,www-data"

# Remove user from groups
sudo ./ubuntu-user-manager.sh modify-groups johndoe remove "sudo"

# Replace all groups
sudo ./ubuntu-user-manager.sh modify-groups johndoe replace "users,docker"
```

#### modify-sudo
Modify user sudo access.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh modify-sudo USERNAME ACTION [SUDO_TYPE]
```

**Parameters:**
- `ACTION`: Sudo action (grant, revoke, modify)
- `SUDO_TYPE`: Sudo access level (full, limited, passwordless)

**Examples:**
```bash
# Grant sudo access
sudo ./ubuntu-user-manager.sh modify-sudo johndoe grant full

# Revoke sudo access
sudo ./ubuntu-user-manager.sh modify-sudo johndoe revoke

# Modify sudo access
sudo ./ubuntu-user-manager.sh modify-sudo johndoe modify limited
```

### User Information Commands

#### list-users
Display all system users.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh list-users
```

#### show-info
Show detailed information for a specific user.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh show-info USERNAME
```

**Example:**
```bash
sudo ./ubuntu-user-manager.sh show-info johndoe
```

#### show-groups
Display available system groups.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh show-groups
```

### User Deletion Commands

#### delete-user
Delete a system user.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh delete-user USERNAME [REMOVE_HOME] [REMOVE_MAIL] [FORCE]
```

**Parameters:**
- `USERNAME`: System username (required)
- `REMOVE_HOME`: Remove home directory (optional: true/false, default: false)
- `REMOVE_MAIL`: Remove mail spool (optional: true/false, default: false)
- `FORCE`: Force deletion without confirmation (optional: true/false, default: false)

**Examples:**
```bash
# Delete user, keep home directory
sudo ./ubuntu-user-manager.sh delete-user johndoe

# Delete user and home directory
sudo ./ubuntu-user-manager.sh delete-user johndoe true

# Delete user, home directory, and mail spool
sudo ./ubuntu-user-manager.sh delete-user johndoe true true

# Force delete without confirmation
sudo ./ubuntu-user-manager.sh delete-user johndoe true true true
```

### Utility Commands

#### backup-system
Create a backup of system user files.

**Syntax:**
```bash
sudo ./ubuntu-user-manager.sh backup-system
```

---

## Interactive Mode

### Starting Interactive Mode
```bash
sudo ./ubuntu-user-manager.sh --interactive
```

### Main Menu Options
