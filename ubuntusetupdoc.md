# MySQL and .NET Installation Script Documentation

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [Installation Options](#installation-options)
5. [Configuration](#configuration)
6. [Post-Installation](#post-installation)
7. [Security Considerations](#security-considerations)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)
10. [FAQ](#faq)
11. [Support](#support)

---

## Overview

This automated installation script provides a streamlined way to install and configure MySQL Server and .NET SDK/Runtime on Ubuntu Server. The script is designed for production environments and includes security hardening, service configuration, and comprehensive logging.

### What gets installed:
- **MySQL Server 8.0** with secure configuration
- **.NET SDK/Runtime** (configurable version)
- **ASP.NET Core Runtime**
- **UFW Firewall** with basic security rules
- **Essential system packages** and dependencies

### Supported Platforms:
- Ubuntu 20.04 LTS (Focal Fossa)
- Ubuntu 22.04 LTS (Jammy Jellyfish)
- Ubuntu 24.04 LTS (Noble Numbat)

---

## Prerequisites

### System Requirements:
- Fresh Ubuntu Server installation
- Minimum 2GB RAM
- 20GB available disk space
- Internet connectivity for package downloads
- Root or sudo access

### Network Requirements:
- Access to Ubuntu package repositories
- Access to Microsoft package repositories
- Access to MySQL APT repository

---

## Quick Start

### 1. Download the Script
```bash
# Download directly
wget https://raw.githubusercontent.com/your-repo/install-mysql-dotnet.sh

# Or create manually
sudo nano install-mysql-dotnet.sh
# Copy and paste the script content
```

### 2. Make Executable
```bash
sudo chmod +x install-mysql-dotnet.sh
```

### 3. Run Installation
```bash
# Interactive installation (recommended for first-time users)
sudo ./install-mysql-dotnet.sh

# Automatic installation with defaults
sudo ./install-mysql-dotnet.sh --auto
```

---

## Installation Options

### Interactive Mode (Default)
```bash
sudo ./install-mysql-dotnet.sh
```
- Prompts for configuration options
- Allows custom MySQL root password
- Lets you choose .NET version
- Creates database user if needed

### Automatic Mode
```bash
sudo ./install-mysql-dotnet.sh --auto
```
- Uses default settings
- Generates random MySQL root password
- Installs .NET 8.0 LTS
- No user interaction required

### Component-Specific Installation
```bash
# Install only MySQL
sudo ./install-mysql-dotnet.sh --mysql-only

# Install only .NET
sudo ./install-mysql-dotnet.sh --dotnet-only
```

### Help
```bash
sudo ./install-mysql-dotnet.sh --help
```

---

## Configuration

### MySQL Configuration

#### Default Settings:
- **Version**: MySQL 8.0
- **Character Set**: UTF8MB4
- **Collation**: utf8mb4_unicode_ci
- **Max Connections**: 200
- **InnoDB Buffer Pool**: 256MB
- **Slow Query Log**: Enabled

#### Custom Configuration:
The script creates `/etc/mysql/conf.d/custom.cnf` with optimized settings:

```ini
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
```

### .NET Configuration

#### Available Versions:
- **.NET 8.0** (LTS) - Default
- **.NET 7.0** (Current)
- **.NET 6.0** (LTS)

#### Installation Components:
- **SDK**: Full development kit (includes runtime)
- **Runtime**: Required for running applications
- **ASP.NET Core Runtime**: For web applications

### Firewall Configuration

#### Default UFW Rules:
```bash
# Incoming connections
SSH (22/tcp)     - ALLOW
HTTP (80/tcp)    - ALLOW
HTTPS (443/tcp)  - ALLOW
MySQL (3306/tcp) - DENY (local only)

# Default policies
Incoming: DENY
Outgoing: ALLOW
```

---

## Post-Installation

### 1. Verify Installation

#### Check MySQL Status:
```bash
sudo systemctl status mysql
mysql --version
```

#### Check .NET Installation:
```bash
dotnet --version
dotnet --list-sdks
dotnet --list-runtimes
```

### 2. Secure MySQL (Additional Steps)

#### Connect to MySQL:
```bash
mysql -u root -p
# Enter the root password displayed during installation
```

#### Create Application Database:
```sql
CREATE DATABASE myapp_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'appuser'@'localhost' IDENTIFIED BY 'strong_password';
GRANT ALL PRIVILEGES ON myapp_db.* TO 'appuser'@'localhost';
FLUSH PRIVILEGES;
```

### 3. Deploy .NET Application

#### Create Application Directory:
```bash
sudo mkdir -p /opt/myapp
sudo chown dotnetapp:dotnetapp /opt/myapp
```

#### Copy Application Files:
```bash
sudo cp -r /path/to/your/app/* /opt/myapp/
sudo chown -R dotnetapp:dotnetapp /opt/myapp
```

#### Create Systemd Service:
```bash
sudo cp /etc/systemd/system/dotnet-app.service.template /etc/systemd/system/myapp.service
sudo nano /etc/systemd/system/myapp.service
```

Edit the service file:
```ini
[Unit]
Description=My .NET Application
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/dotnet /opt/myapp/MyApp.dll
Restart=always
RestartSec=10
KillSignal=SIGINT
SyslogIdentifier=myapp
User=dotnetapp
Group=dotnetapp
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_PRINT_TELEMETRY_MESSAGE=false

[Install]
WantedBy=multi-user.target
```

#### Enable and Start Service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable myapp
sudo systemctl start myapp
```

---

## Security Considerations

### MySQL Security

#### Password Policy:
- Use strong passwords (minimum 12 characters)
- Include uppercase, lowercase, numbers, and symbols
- Avoid dictionary words

#### Network Security:
- MySQL is configured for local connections only
- External access requires firewall modification
- Consider using SSL/TLS for remote connections

#### Regular Updates:
```bash
sudo apt update && sudo apt upgrade mysql-server
```

### .NET Security

#### Application Security:
- Run applications as non-root user (`dotnetapp`)
- Use HTTPS for web applications
- Implement proper input validation
- Keep runtime updated

#### File Permissions:
```bash
# Set proper permissions for application files
sudo chown -R dotnetapp:dotnetapp /opt/myapp
sudo chmod -R 755 /opt/myapp
```

### System Security

#### Firewall Management:
```bash
# View current rules
sudo ufw status verbose

# Add custom rules
sudo ufw allow from 192.168.1.0/24 to any port 3306

# Remove rules
sudo ufw delete allow 80/tcp
```

#### System Updates:
```bash
# Regular system updates
sudo apt update && sudo apt upgrade
sudo apt autoremove
```

---

## Troubleshooting

### Common Issues

#### 1. MySQL Installation Fails
```bash
# Check if MySQL is already installed
systemctl status mysql

# Remove existing installation
sudo apt remove --purge mysql-server mysql-client mysql-common
sudo apt autoremove
sudo apt autoclean

# Clean up configuration files
sudo rm -rf /etc/mysql /var/lib/mysql
sudo deluser mysql

# Re-run the script
sudo ./install-mysql-dotnet.sh --mysql-only
```

#### 2. .NET Installation Fails
```bash
# Check Microsoft repository
apt-cache policy dotnet-sdk-8.0

# Remove Microsoft repository and re-add
sudo rm /etc/apt/sources.list.d/microsoft-prod.list
sudo apt update

# Re-run the script
sudo ./install-mysql-dotnet.sh --dotnet-only
```

#### 3. Permission Denied Errors
```bash
# Check script permissions
ls -la install-mysql-dotnet.sh

# Fix permissions
sudo chmod +x install-mysql-dotnet.sh

# Run as root
sudo ./install-mysql-dotnet.sh
```

#### 4. MySQL Connection Issues
```bash
# Check MySQL service status
sudo systemctl status mysql

# Check MySQL logs
sudo tail -f /var/log/mysql/error.log

# Reset MySQL root password
sudo mysql
ALTER USER 'root'@'localhost' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

### Log Files

#### Installation Log:
```bash
# View installation log
sudo tail -f /var/log/mysql-dotnet-install.log

# Search for errors
sudo grep -i error /var/log/mysql-dotnet-install.log
```

#### MySQL Logs:
```bash
# Error log
sudo tail -f /var/log/mysql/error.log

# Slow query log
sudo tail -f /var/log/mysql/slow.log
```

#### System Logs:
```bash
# View systemd logs
sudo journalctl -u mysql
sudo journalctl -u myapp
```

---

## Maintenance

### Regular Tasks

#### Daily:
- Monitor application logs
- Check disk space usage
- Review system metrics

#### Weekly:
- Update system packages
- Review security logs
- Backup databases

#### Monthly:
- Update MySQL and .NET runtime
- Review firewall rules
- Clean up log files

### Backup Strategy

#### MySQL Backup:
```bash
# Create backup script
sudo nano /usr/local/bin/mysql-backup.sh
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/mysql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="myapp_db"
DB_USER="appuser"
DB_PASS="password"

mkdir -p $BACKUP_DIR
mysqldump -u$DB_USER -p$DB_PASS $DB_NAME > $BACKUP_DIR/${DB_NAME}_$DATE.sql
gzip $BACKUP_DIR/${DB_NAME}_$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete
