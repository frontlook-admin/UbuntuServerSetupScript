# Ubuntu Server Complete Development Environment Setup Script

## Overview

This comprehensive bash script automates the installation and configuration of a complete development environment on Ubuntu servers. It provides a secure, monitored, and development-ready server setup with MySQL, .NET, Git/GitHub integration, system monitoring tools, and enhanced security configurations.

## Features

### 🏗️ Core Components
- **MySQL Server 8.0**: Database server with optimized configuration
- **.NET 8.0 LTS**: SDK and runtime installation with ASP.NET Core
- **Git & GitHub**: Version control with SSH key setup and GitHub CLI
- **System Monitoring**: Comprehensive monitoring tools and dashboards
- **Security**: Enhanced firewall, intrusion prevention, and hardening

### 🔧 System Tools
- **Monitoring**: htop, iotop, glances, netdata, vnstat, nmon, sysstat
- **Network**: nethogs, iftop, tcptrack, bmon, tcpdump
- **Security**: UFW firewall, fail2ban, SSH rate limiting
- **Development**: vim, nano, tree, build-essential, curl, wget

### 🛡️ Security Features
- **Fail2ban**: Intrusion prevention system
- **UFW Firewall**: Configured with security-first rules
- **SSH Protection**: Rate limiting and attack prevention
- **Attack Prevention**: Common attack ports blocked
- **MySQL Security**: Automated secure installation

### 📊 Monitoring Dashboard
- **Netdata**: Real-time monitoring at http://localhost:19999
- **Custom Scripts**: System overview and monitoring commands
- **Network Monitoring**: vnstat for traffic analysis
- **Performance Tools**: CPU, memory, disk, and network monitoring

## Prerequisites

### System Requirements
- **Operating System**: Ubuntu 20.04 LTS, 22.04 LTS, or 24.04 LTS
- **Architecture**: x86_64 (64-bit)
- **RAM**: Minimum 2GB (4GB recommended)
- **Storage**: At least 10GB free space
- **Network**: Internet connection for package downloads

### Access Requirements
- **Root Access**: Script must be run with sudo privileges
- **SSH Access**: For remote server management
- **Firewall Access**: Ports 22 (SSH), 80 (HTTP), 443 (HTTPS), 4430-4439 (HTTPS Range), 3306 (MySQL), 19999 (Monitoring)

## Installation

### Quick Start
```bash
# Download the script
wget https://raw.githubusercontent.com/yourusername/UbuntuServerSetupScript/main/install-mysql-dotnet.sh

# Make it executable
chmod +x install-mysql-dotnet.sh

# Run with full installation
sudo ./install-mysql-dotnet.sh
```

### Installation Options

#### Full Interactive Installation
```bash
sudo ./install-mysql-dotnet.sh
```
- Prompts for all configuration options
- Allows customization of each component
- Recommended for first-time setup

#### Automatic Installation (Default Settings)
```bash
sudo ./install-mysql-dotnet.sh --auto
```
- Uses default settings for all components
- No interactive prompts
- Fastest installation method

#### Component-Specific Installation
```bash
# MySQL only
sudo ./install-mysql-dotnet.sh --mysql-only

# .NET only
sudo ./install-mysql-dotnet.sh --dotnet-only

# Git/GitHub only
sudo ./install-mysql-dotnet.sh --git-only

# Monitoring tools only
sudo ./install-mysql-dotnet.sh --monitoring-only

# Security configuration only
sudo ./install-mysql-dotnet.sh --security-only
```

#### Selective Installation
```bash
# Skip Git/GitHub configuration
sudo ./install-mysql-dotnet.sh --no-git

# Skip monitoring tools
sudo ./install-mysql-dotnet.sh --no-monitoring

# Skip all interactive prompts
sudo ./install-mysql-dotnet.sh --no-interactive
```

## Command Line Options

### **🔧 Installation Options**

| Option | Description |
|--------|-------------|
| `--help`, `-h` | Display help information |
| `--auto` | Run with default settings (non-interactive) |
| `--mysql-only` | Install only MySQL Server |
| `--dotnet-only` | Install only .NET SDK/Runtime |
| `--git-only` | Configure Git and GitHub only |
| `--monitoring-only` | Install system monitoring tools only |
| `--security-only` | Configure firewall and security only |
| `--no-git` | Skip Git/GitHub configuration |
| `--no-monitoring` | Skip monitoring tools installation |
| `--no-interactive` | Skip all interactive prompts |

### **👥 User Management Options**

| Option | Description |
|--------|-------------|
| `--manage-users` | Run Ubuntu system user management |
| `--manage-mysql` | Run MySQL user management |
| `--user-menu` | Show interactive user management menu |

### **📋 Script Management Options**

| Option | Description |
|--------|-------------|
| `--make-executable` | Make all scripts in directory executable |
| `--run-all` | Run all available scripts and tools |

### **📁 Available Scripts**

The main script now integrates functionality from all scripts in the folder:

- **`install-mysql-dotnet.sh`** - Main installation script with all features
- **`ubuntu-user-manager.sh`** - Ubuntu system user management
- **`mysql-user-manager.sh`** - MySQL user management  
- **`make-executable.sh`** - Script permission manager

## Configuration Details

### MySQL Configuration
- **Version**: MySQL 8.0
- **Character Set**: UTF8MB4 with Unicode collation
- **Security**: Secure installation with random root password
- **Performance**: Optimized buffer pool and connection settings
- **Logging**: Slow query log enabled
- **Configuration File**: `/etc/mysql/conf.d/custom.cnf`
- **Remote Access**: Port 3306 enabled for backups and remote operations
- **Security Warning**: ⚠️ Port 3306 is open - ensure strong passwords and IP restrictions

### .NET Configuration
- **Version**: .NET 8.0 LTS (configurable)
- **Components**: SDK, Runtime, and ASP.NET Core Runtime
- **Service User**: `dotnetapp` user for running applications
- **Systemd Template**: Service template for .NET applications
- **Security**: Hardened service configuration

### Git/GitHub Configuration
- **SSH Key**: RSA 4096-bit key generation
- **Git Config**: Global user configuration
- **GitHub CLI**: Optional installation and authentication
- **SSH Agent**: Automatic key management
- **Aliases**: Convenient git command shortcuts

### Monitoring Tools
- **Real-time**: htop, iotop, glances
- **Network**: nethogs, iftop, vnstat, tcptrack
- **System**: nmon, sysstat, dstat
- **Storage**: ncdu for disk usage
- **Performance**: lsof, strace for debugging
- **Dashboard**: Netdata for web-based monitoring

### Security Configuration
- **Firewall**: UFW with restrictive default rules and automatic port configuration
- **Intrusion Prevention**: fail2ban with custom rules
- **SSH Protection**: Rate limiting and attack prevention
- **Port Security**: Common attack ports blocked
- **Service Security**: Hardened systemd configurations
- **Automatic Firewall Ports**:
  - Port 22 (SSH) - Enabled with rate limiting
  - Port 80 (HTTP) - Enabled
  - Port 443 (HTTPS) - Enabled
  - Ports 4430-4439 (HTTPS Range) - Enabled
  - Port 3306 (MySQL) - Enabled for backups and remote operations
  - Port 19999 (Netdata Monitoring) - Enabled

## Usage Examples

### Using Integrated Scripts

#### User Management
```bash
# Run Ubuntu user management
sudo ./install-mysql-dotnet.sh --manage-users

# Run MySQL user management
sudo ./install-mysql-dotnet.sh --manage-mysql

# Show user management menu
sudo ./install-mysql-dotnet.sh --user-menu
```

#### Script Management
```bash
# Make all scripts executable
sudo ./install-mysql-dotnet.sh --make-executable

# Run complete installation with all tools
sudo ./install-mysql-dotnet.sh --run-all
```

#### Ubuntu User Management Examples
```bash
# Create new user with sudo privileges
sudo ./install-mysql-dotnet.sh --manage-users --create-user myuser --groups sudo

# Create developer user with Docker access
sudo ./install-mysql-dotnet.sh --manage-users --create-user developer --groups docker,sudo

# List all users
sudo ./install-mysql-dotnet.sh --manage-users --list-users

# Delete user
sudo ./install-mysql-dotnet.sh --manage-users --delete-user olduser
```

#### MySQL User Management Examples
```bash
# Create MySQL user with database access
sudo ./install-mysql-dotnet.sh --manage-mysql --create-user appuser --database myapp

# Create read-only user
sudo ./install-mysql-dotnet.sh --manage-mysql --create-user readonly --privileges SELECT

# List MySQL users
sudo ./install-mysql-dotnet.sh --manage-mysql --list-users

# Delete MySQL user
sudo ./install-mysql-dotnet.sh --manage-mysql --delete-user olduser
```

### After Installation

#### System Monitoring
```bash
# Quick system overview
sysmon

# Real-time monitoring
glances

# Process monitoring
htop

# Network monitoring
nethogs

# I/O monitoring
iotop -o

# Check firewall status
sudo ufw status verbose

# Check fail2ban status
sudo fail2ban-client status
```

#### MySQL Operations
```bash
# Connect to MySQL
mysql -u root -p

# Create database
mysql -u root -p -e "CREATE DATABASE myapp;"

# Show databases
mysql -u root -p -e "SHOW DATABASES;"
```

#### .NET Operations
```bash
# Check .NET version
dotnet --version

# List installed SDKs
dotnet --list-sdks

# List installed runtimes
dotnet --list-runtimes

# Create new project
dotnet new webapi -n MyAPI
```

#### Git Operations
```bash
# Test GitHub connection
ssh -T git@github.com

# Clone repository
git clone git@github.com:username/repository.git

# GitHub CLI authentication
gh auth login
```

### Service Management
```bash
# MySQL service
sudo systemctl status mysql
sudo systemctl restart mysql

# Fail2ban service
sudo systemctl status fail2ban
sudo systemctl restart fail2ban

# UFW firewall
sudo ufw enable
sudo ufw disable
```

## File Locations

### Configuration Files
- **MySQL Config**: `/etc/mysql/conf.d/custom.cnf`
- **Fail2ban Config**: `/etc/fail2ban/jail.local`
- **UFW Rules**: `/etc/ufw/`
- **SSH Keys**: `/root/.ssh/`

### Log Files
- **Installation Log**: `/var/log/mysql-dotnet-install.log`
- **MySQL Logs**: `/var/log/mysql/`
- **Fail2ban Logs**: `/var/log/fail2ban.log`
- **UFW Logs**: `/var/log/ufw.log`

### Scripts and Templates
- **Monitoring Script**: `/usr/local/bin/sysmon`
- **Systemd Template**: `/etc/systemd/system/dotnet-app.service.template`
- **Bash Aliases**: `/root/.bashrc`

## Useful Commands

### System Monitoring Aliases
```bash
# Process monitoring
processes          # ps auxf
psmem             # Sort processes by memory usage
pscpu             # Sort processes by CPU usage

# Network monitoring
ports             # netstat -tulanp
listening         # lsof -i
networktop        # nethogs

# System information
cpuinfo           # lscpu
meminfo           # cat /proc/meminfo
diskusage         # df -h
diskusage_sorted  # df -h | sort -rn -k 5
temp              # sensors
myip              # curl ipinfo.io/ip
speedtest         # speedtest-cli
```

### Git Aliases
```bash
gs                # git status
ga                # git add
gc                # git commit
gp                # git push
gl                # git log --oneline
gd                # git diff
gb                # git branch
gco               # git checkout
```

## Troubleshooting

### Common Issues

#### MySQL Issues
```bash
# Check MySQL status
sudo systemctl status mysql

# View MySQL logs
sudo tail -f /var/log/mysql/error.log

# Reset MySQL password
sudo mysql_secure_installation

# Check MySQL configuration
sudo mysql -u root -p -e "SHOW VARIABLES LIKE 'character_set%';"
```

#### .NET Issues
```bash
# Check .NET installation
dotnet --info

# Clear NuGet cache
dotnet nuget locals all --clear

# Check environment variables
echo $DOTNET_ROOT
echo $PATH
```

#### Git/GitHub Issues
```bash
# Test SSH connection
ssh -T git@github.com

# Check SSH agent
ssh-add -l

# Re-add SSH key
ssh-add ~/.ssh/id_rsa

# Check Git configuration
git config --list --global
```

#### Firewall Issues
```bash
# Check firewall status
sudo ufw status verbose

# Allow specific port
sudo ufw allow 8080/tcp

# Remove rule
sudo ufw delete allow 8080/tcp

# Reset firewall
sudo ufw --force reset
```

#### Monitoring Issues
```bash
# Check service status
sudo systemctl status vnstat
sudo systemctl status netdata

# Restart services
sudo systemctl restart vnstat
sudo systemctl restart netdata

# Check logs
sudo journalctl -u vnstat
sudo journalctl -u netdata
```

### Log Analysis
```bash
# Check installation log
sudo tail -f /var/log/mysql-dotnet-install.log

# Check system logs
sudo journalctl -f

# Check security logs
sudo tail -f /var/log/auth.log
sudo tail -f /var/log/fail2ban.log
```

## Security Considerations

### Best Practices
1. **Change Default Passwords**: Update MySQL root password
2. **SSH Key Management**: Use SSH keys instead of passwords
3. **Firewall Rules**: Review and customize UFW rules
4. **Regular Updates**: Keep system and packages updated
5. **Monitoring**: Regular system monitoring and log analysis

### MySQL Security (Port 3306)
**⚠️ Important**: Port 3306 is automatically opened for MySQL backups and remote operations. Consider these security measures:

1. **Strong Passwords**: Use strong, unique passwords for all MySQL accounts
2. **IP Restrictions**: Restrict MySQL access to specific IP addresses:
   ```bash
   # Allow only specific IP for MySQL
   sudo ufw delete allow 3306/tcp
   sudo ufw allow from YOUR_IP_ADDRESS to any port 3306
   ```
3. **User Privileges**: Follow the principle of least privilege:
   ```bash
   # Create user with limited privileges
   mysql -u root -p -e "CREATE USER 'backup_user'@'%' IDENTIFIED BY 'strong_password';"
   mysql -u root -p -e "GRANT SELECT, LOCK TABLES ON *.* TO 'backup_user'@'%';"
   ```
4. **Regular Backups**: Implement automated backups with proper security
5. **Connection Encryption**: Use SSL/TLS for remote connections
6. **Monitor Access**: Regularly check MySQL logs for unauthorized access attempts

### Security Hardening
```bash
# Disable root login (after setting up SSH keys)
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Change SSH port (optional)
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config

# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### Monitoring Security
```bash
# Check fail2ban status
sudo fail2ban-client status

# View banned IPs
sudo fail2ban-client status sshd

# Monitor authentication attempts
sudo tail -f /var/log/auth.log | grep Failed
```

## Post-Installation Steps

### 1. System Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Reboot system
sudo reboot
```

### 2. Application Deployment
```bash
# Create application directory
sudo mkdir -p /opt/myapp
sudo chown dotnetapp:dotnetapp /opt/myapp

# Deploy .NET application
sudo -u dotnetapp dotnet publish -c Release -o /opt/myapp

# Configure systemd service
sudo cp /etc/systemd/system/dotnet-app.service.template /etc/systemd/system/myapp.service
sudo systemctl enable myapp
sudo systemctl start myapp
```

### 3. SSL Certificate Setup
```bash
# Install Certbot
sudo apt install certbot python3-certbot-apache

# Obtain SSL certificate
sudo certbot --apache -d yourdomain.com
```

### 4. Backup Configuration
```bash
# Create backup script
sudo nano /usr/local/bin/backup.sh

# Schedule backups
sudo crontab -e
# Add: 0 2 * * * /usr/local/bin/backup.sh
```

## Performance Optimization

### MySQL Optimization
```bash
# Tune MySQL configuration
sudo mysql_secure_installation
sudo apt install mysqltuner
sudo mysqltuner
```

### System Optimization
```bash
# Check system performance
sudo sysmon
glances

# Optimize system limits
sudo nano /etc/security/limits.conf
```

## Support and Maintenance

### Regular Maintenance
```bash
# Weekly maintenance script
#!/bin/bash
apt update && apt upgrade -y
apt autoremove -y
apt autoclean
fail2ban-client reload
systemctl restart mysql
systemctl restart fail2ban
```

### Monitoring Alerts
- Set up email alerts for system issues
- Configure monitoring thresholds
- Regular security log analysis

## Version History

### Version 2.0 (Current)
- Added Git/GitHub integration
- Enhanced security with fail2ban
- Comprehensive monitoring tools
- System optimization and hardening
- Improved documentation

### Version 1.0
- Basic MySQL and .NET installation
- Simple firewall configuration
- Basic system updates

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

This script is provided under the MIT License. See LICENSE file for details.

## Support

For issues and questions:
- Create an issue on GitHub
- Check the troubleshooting section
- Review log files for error details

---

**Note**: Always test this script in a development environment before using in production. Ensure you have proper backups and recovery procedures in place. 