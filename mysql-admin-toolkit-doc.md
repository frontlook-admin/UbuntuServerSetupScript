# MySQL Administration Toolkit Documentation

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [User Management](#user-management)
7. [Database Cloning & Synchronization](#database-cloning--synchronization)
8. [Privilege Levels](#privilege-levels)
9. [Commands Reference](#commands-reference)
10. [Interactive Mode](#interactive-mode)
11. [Security Considerations](#security-considerations)
12. [Backup and Recovery](#backup-and-recovery)
13. [Troubleshooting](#troubleshooting)
14. [Best Practices](#best-practices)
15. [FAQ](#faq)
16. [Examples](#examples)

---

## Overview

The MySQL Administration Toolkit is a comprehensive bash utility designed to simplify MySQL administration tasks. It provides both command-line and interactive interfaces for user management, database cloning, synchronization, and comprehensive MySQL administration.

### Key Capabilities
- **User Management**: Create, modify, and delete MySQL users with various privilege levels
- **Database Cloning**: Clone databases from remote servers to local servers
- **Database Synchronization**: Push databases to remote servers and bidirectional sync
- **Remote Server Management**: Connect to and manage multiple MySQL servers
- **Privilege Management**: Comprehensive user privilege control
- **Backup & Recovery**: Automatic backup of user grants and database exports
- **Security**: Strong password validation and secure connections
- **Logging**: Comprehensive logging and error handling
- **Interactive Interface**: Guided user interface for ease of use

### Compatibility
- **MySQL Versions**: 5.7+, 8.0+
- **Operating Systems**: Linux (Ubuntu, CentOS, RHEL, Debian)
- **Shell**: Bash 4.0+
- **Privileges**: Root or sudo access recommended

---

## Features

### ✅ User Management
- **Create Users**: Global or database-specific privileges
- **Modify Users**: Change passwords and privileges
- **Delete Users**: Safe deletion with confirmation
- **List Users**: View all MySQL users and their status

### ✅ Database Cloning & Synchronization
- **Remote Connection**: Connect to multiple MySQL servers
- **Database Cloning**: Clone databases from remote to local servers
- **Database Push**: Push local databases to remote servers
- **Bidirectional Sync**: Automatic synchronization based on timestamps
- **Data Export/Import**: Comprehensive database export and import
- **Cross-Server Management**: Manage multiple MySQL instances

### ✅ Privilege Management
- **Global Privileges**: SUPERUSER, DEVELOPER, READONLY, BACKUP
- **Database Privileges**: FULL, DEVELOPER, READONLY, READWRITE
- **Custom Privileges**: Grant/revoke specific permissions
- **Privilege Validation**: Ensures proper privilege assignment

### ✅ Security Features
- **Password Validation**: Strong password requirements
- **User Validation**: Username and hostname validation
- **Automatic Backups**: Backs up grants and databases before modifications
- **Secure Storage**: Encrypted configuration storage
- **Audit Trail**: Comprehensive logging
- **Remote Authentication**: Secure remote server connections

### ✅ User Experience
- **Interactive Mode**: Guided user interface
- **Command Line**: Scriptable automation
- **Error Handling**: Robust validation and error messages
- **Help System**: Built-in documentation and examples
- **Multi-Server Support**: Manage multiple MySQL servers from one interface

---

## Installation

### 1. Download the Script
```bash
# Download directly (replace with actual URL)
wget https://raw.githubusercontent.com/your-repo/mysql-admin-toolkit.sh

# Or create the file manually
sudo nano mysql-admin-toolkit.sh
# Copy and paste the script content
```

### 2. Make Executable
```bash
chmod +x mysql-admin-toolkit.sh
```

### 3. Move to System Path (Optional)
```bash
sudo mv mysql-admin-toolkit.sh /usr/local/bin/mysql-admin-toolkit
```

### 4. Verify Installation
```bash
./mysql-admin-toolkit.sh --help
```

---

## Configuration

### Initial Setup
The script will prompt for MySQL connection details on first run:

```bash
./mysql-admin-toolkit.sh
```

**Required Information:**
- MySQL Host (default: localhost)
- MySQL Port (default: 3306)
- MySQL Root Username (default: root)
- MySQL Root Password

### Configuration File
The script automatically creates a configuration file at: /etc/mysql-admin-toolkit.conf


**Sample Configuration:**
```bash
MYSQL_HOST="localhost"
MYSQL_PORT="3306"
MYSQL_ROOT_USER="root"
MYSQL_ROOT_PASSWORD="your_secure_password"
```

### Security Note
The configuration file is automatically secured with `chmod 600` to protect sensitive information.

---

## Usage

### Command Line Interface

#### Basic Syntax
```bash
./mysql-admin-toolkit.sh [OPTIONS] [COMMAND] [ARGUMENTS]
```

#### Available Options
```bash
-h, --help          Show help message
-i, --interactive   Run in interactive mode
-c, --config FILE   Use custom configuration file
-f, --force         Force operation without confirmation
```

#### Quick Start Examples
```bash
# Interactive mode (recommended for beginners)
./mysql-admin-toolkit.sh --interactive

# Create user with global developer rights
./mysql-admin-toolkit.sh create-global myuser mypass123 localhost DEVELOPER

# Create user with database-specific rights
./mysql-admin-toolkit.sh create-database appuser apppass123 localhost myapp_db FULL

# List all users
./mysql-admin-toolkit.sh list-users

# Clone database from remote server
./mysql-admin-toolkit.sh clone-database remote_db_name

# Show help
./mysql-admin-toolkit.sh --help
```

---

## Privilege Levels

### Global Privilege Levels

#### SUPERUSER (Full Administrative Access)
```sql
GRANT ALL PRIVILEGES ON *.* TO 'user'@'host' WITH GRANT OPTION;
```
**Use Cases:**
- Database administrators
- Full system management
- Server configuration

**Permissions:**
- All database operations
- User management
- Server administration
- Grant privileges to other users

#### DEVELOPER (Development Access)
```sql
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW,
CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON *.* TO 'user'@'host';
```
**Use Cases:**
- Application developers
- Database developers
- Testing environments

**Permissions:**
- Full CRUD operations
- Schema modifications
- Stored procedures and functions
- Views and triggers

#### READONLY (Read-Only Access)
```sql
GRANT SELECT, SHOW VIEW ON *.* TO 'user'@'host';
```
**Use Cases:**
- Reporting users
- Analytics tools
- Read-only applications

**Permissions:**
- Select data from all tables
- View existing views
- No modification rights

#### BACKUP (Backup Operations)
```sql
GRANT SELECT, LOCK TABLES, SHOW VIEW, EVENT, TRIGGER ON *.* TO 'user'@'host';
```
**Use Cases:**
- Backup applications
- Data migration tools
- Monitoring systems

**Permissions:**
- Read all data
- Lock tables for consistency
- Access to metadata

### Database-Specific Privilege Levels

#### FULL (Complete Database Access)
```sql
GRANT ALL PRIVILEGES ON `database`.* TO 'user'@'host';
```
**Use Cases:**
- Database owners
- Application administrators
- Development environments

#### DEVELOPER (Standard Development Access)
```sql
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER,
CREATE TEMPORARY TABLES, LOCK TABLES, EXECUTE, CREATE VIEW, SHOW VIEW,
CREATE ROUTINE, ALTER ROUTINE, EVENT, TRIGGER ON `database`.* TO 'user'@'host';
```
**Use Cases:**
- Application developers
- Schema management
- Testing environments

#### READONLY (Database Read-Only)
```sql
GRANT SELECT, SHOW VIEW ON `database`.* TO 'user'@'host';
```
**Use Cases:**
- Reporting applications
- Analytics tools
- Read-only API access

#### READWRITE (Basic Operations)
```sql
GRANT SELECT, INSERT, UPDATE, DELETE ON `database`.* TO 'user'@'host';
```
**Use Cases:**
- Application users
- Data entry applications
- Basic CRUD operations

---

## Database Cloning & Synchronization

### Overview
The MySQL Administration Toolkit provides comprehensive database cloning and synchronization capabilities, allowing you to:
- Clone databases from remote servers to local servers
- Push local databases to remote servers
- Perform bidirectional synchronization
- Manage multiple MySQL server connections

### Remote Server Setup
Before using cloning features, you need to configure remote server connections:

```bash
# Setup remote MySQL connection
./mysql-admin-toolkit.sh setup-remote-connection

# Or use interactive mode
./mysql-admin-toolkit.sh --interactive
# Select Option 11: Setup Remote MySQL Connection
```

### Database Cloning Features

#### Clone Database from Remote Server
Clone a database from a remote MySQL server to your local server:

```bash
# Clone specific database
./mysql-admin-toolkit.sh clone-database remote_db_name

# Interactive clone with options
./mysql-admin-toolkit.sh --interactive
# Select Option 12: Clone Database from Remote Server
```

#### Push Database to Remote Server
Push a local database to a remote MySQL server:

```bash
# Push specific database
./mysql-admin-toolkit.sh push-database local_db_name

# Interactive push with options
./mysql-admin-toolkit.sh --interactive
# Select Option 13: Push Database to Remote Server
```

#### Bidirectional Synchronization
Synchronize databases between local and remote servers based on timestamps:

```bash
# Synchronize databases
./mysql-admin-toolkit.sh synchronize-databases

# Interactive synchronization
./mysql-admin-toolkit.sh --interactive
# Select Option 14: Synchronize Databases (Bidirectional)
```

### Security Features
- **Automatic Backups**: Creates backups before any operation
- **Connection Validation**: Tests remote connections before operations
- **Secure Storage**: Encrypted remote connection configuration
- **Comprehensive Logging**: Detailed operation logs

### Backup and Recovery
- Automatic database exports before modifications
- Timestamped backup files
- Recovery assistance for failed operations
- Backup verification and integrity checks

---

## Commands Reference

### User Creation Commands

#### create-global
Create a user with global privileges.

**Syntax:**
```bash
./mysql-user-manager.sh create-global USERNAME PASSWORD HOSTNAME PRIVILEGE_LEVEL
```

**Example:**
```bash
./mysql-user-manager.sh create-global developer dev123pass localhost DEVELOPER
```

#### create-database
Create a user with database-specific privileges.

**Syntax:**
```bash
./mysql-user-manager.sh create-database USERNAME PASSWORD HOSTNAME DATABASE PRIVILEGE_LEVEL
```

**Example:**
```bash
./mysql-user-manager.sh create-database appuser app123pass localhost myapp_db FULL
```

### User Modification Commands

#### modify-password
Change a user's password.

**Syntax:**
```bash
./mysql-user-manager.sh modify-password USERNAME HOSTNAME NEW_PASSWORD
```

**Example:**
```bash
./mysql-user-manager.sh modify-password myuser localhost newpass123
```

#### modify-privileges
Grant or revoke specific privileges.

**Syntax:**
```bash
./mysql-user-manager.sh modify-privileges USERNAME HOSTNAME ACTION PRIVILEGES [DATABASE]
```

**Examples:**
```bash
# Grant privileges
./mysql-user-manager.sh modify-privileges myuser localhost GRANT "SELECT,INSERT,UPDATE" myapp_db

# Revoke privileges
./mysql-user-manager.sh modify-privileges myuser localhost REVOKE "DELETE" myapp_db
```

### User Information Commands

#### list-users
Display all MySQL users.

**Syntax:**
```bash
./mysql-user-manager.sh list-users
```

#### show-privileges
Show privileges for a specific user.

**Syntax:**
```bash
./mysql-user-manager.sh show-privileges USERNAME HOSTNAME
```

**Example:**
```bash
./mysql-user-manager.sh show-privileges myuser localhost
```

### User Deletion Commands

#### delete-user
Delete a MySQL user.

**Syntax:**
```bash
./mysql-user-manager.sh delete-user USERNAME HOSTNAME
```

**Example:**
```bash
./mysql-user-manager.sh delete-user olduser localhost
```

### Utility Commands

#### backup-users
Create a backup of all users and their grants.

**Syntax:**
```bash
./mysql-user-manager.sh backup-users
```

#### test-connection
Test the MySQL connection.

**Syntax:**
```bash
./mysql-user-manager.sh test-connection
```

---

## Interactive Mode

### Starting Interactive Mode
```bash
./mysql-user-manager.sh --interactive
```

### Main Menu Options
