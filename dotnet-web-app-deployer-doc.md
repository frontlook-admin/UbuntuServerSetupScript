# .NET Web App Deployment Script Documentation

## Overview
The `.NET Web App Deployment Script` is a comprehensive bash script designed to automate the deployment of .NET web applications on Ubuntu servers. It provides a complete solution for deploying, managing, and maintaining .NET web applications with proper reverse proxy configuration using Nginx.

## Features

### Core Deployment Features
- **Automatic Dependency Installation**: Installs .NET SDK/Runtime and Nginx if not present
- **Flexible Hosting Options**: Supports both direct hosting and subdirectory hosting
- **Systemd Service Management**: Creates and manages system services for applications
- **Nginx Reverse Proxy**: Configures Nginx as a reverse proxy for the applications
- **Backup and Rollback**: Creates backups before deployment and provides rollback capabilities
- **Interactive Configuration**: Guided setup with validation and error checking

### System Requirements
- Ubuntu 18.04 or later
- Root privileges (sudo access)
- Internet connection for downloading dependencies

### Supported .NET Versions
- .NET 6.0+
- .NET 8.0+ (recommended)

## Installation

### Quick Installation
```bash
# Download the script
wget https://raw.githubusercontent.com/your-repo/dotnet-web-app-deployer.sh

# Make it executable
chmod +x dotnet-web-app-deployer.sh

# Run the script
sudo ./dotnet-web-app-deployer.sh
```

### Manual Installation
1. Copy the script to your Ubuntu server
2. Make it executable: `chmod +x dotnet-web-app-deployer.sh`
3. Run with sudo privileges: `sudo ./dotnet-web-app-deployer.sh`

## Usage

### Interactive Mode (Recommended)
```bash
# Run in interactive mode
sudo ./dotnet-web-app-deployer.sh --interactive

# Or simply
sudo ./dotnet-web-app-deployer.sh
```

### Command Line Mode
```bash
# Deploy a new application
sudo ./dotnet-web-app-deployer.sh deploy

# Check system requirements
sudo ./dotnet-web-app-deployer.sh check-requirements

# Install dependencies
sudo ./dotnet-web-app-deployer.sh install-deps

# Show deployment status
sudo ./dotnet-web-app-deployer.sh status myapp

# Restart application
sudo ./dotnet-web-app-deployer.sh restart myapp

# Remove deployment
sudo ./dotnet-web-app-deployer.sh remove myapp
```

## Configuration Options

### Application Configuration
During deployment, you'll be prompted to configure:

#### Application Name
- Must contain only letters, numbers, hyphens, and underscores
- Used for service names and directory naming
- Example: `mywebapp`, `ecommerce-site`, `api_service`

#### Source Directory
- Path to your compiled .NET application
- Must contain .dll or .exe files
- Example: `/home/user/myapp/bin/Release/net8.0/publish/`

#### Port Configuration
- Port number for the application (1024-65535)
- Recommended range: 5000-5999
- Must not conflict with existing services

#### Hosting Mode
Two hosting modes are available:

##### Direct Hosting
- Application accessible at the root URL
- Example: `http://your-server/`
- Suitable for single applications or main websites

##### Subdirectory Hosting
- Application accessible under a subdirectory
- Example: `http://your-server/myapp/`
- Suitable for multiple applications on the same server

### Advanced Configuration

#### Service Configuration
The script creates systemd services with the following characteristics:
- Service name: `dotnet-{app-name}`
- Runs as `www-data` user
- Automatic restart on failure
- Production environment configuration

#### Nginx Configuration
Nginx is configured as a reverse proxy with:
- HTTP/1.1 support
- WebSocket support (upgrade headers)
- Proper proxy headers for client information
- Buffering disabled for real-time applications
- Configurable timeouts (300 seconds default)

## Directory Structure

### Application Files
```
/var/www/dotnet-apps/
├── app1/
│   ├── app1.dll
│   ├── appsettings.json
│   └── wwwroot/
├── app2/
│   ├── app2.dll
│   ├── appsettings.json
│   └── wwwroot/
└── ...
```

### Service Files
```
/etc/systemd/system/
├── dotnet-app1.service
├── dotnet-app2.service
└── ...
```

### Nginx Configuration
```
/etc/nginx/sites-available/
├── app1
├── app2
└── ...

/etc/nginx/sites-enabled/
├── app1 -> ../sites-available/app1
├── app2 -> ../sites-available/app2
└── ...
```

### Backups
```
/var/backups/dotnet-apps/
├── app1_backup_20241201_143022/
├── app2_removal_backup_20241201_150000/
└── ...
```

## Deployment Process

### Step-by-Step Deployment
1. **System Check**: Verifies Ubuntu version and root privileges
2. **Dependency Check**: Checks for .NET SDK and Nginx installation
3. **Configuration**: Collects application configuration interactively
4. **Directory Creation**: Creates application directories with proper permissions
5. **File Copy**: Copies application files to the deployment directory
6. **Service Creation**: Creates and enables systemd service
7. **Nginx Configuration**: Creates and enables Nginx reverse proxy
8. **Verification**: Tests the deployment and shows access URLs

### Validation and Error Handling
- Input validation for all user inputs
- Port conflict detection
- Service status verification
- Nginx configuration testing
- Comprehensive error messages and logging

## Management Commands

### Service Management
```bash
# Check service status
sudo systemctl status dotnet-myapp

# Start service
sudo systemctl start dotnet-myapp

# Stop service
sudo systemctl stop dotnet-myapp

# Restart service
sudo systemctl restart dotnet-myapp

# View service logs
sudo journalctl -u dotnet-myapp -f
```

### Nginx Management
```bash
# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Restart Nginx
sudo systemctl restart nginx

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## Troubleshooting

### Common Issues

#### Application Not Starting
1. Check service logs: `sudo journalctl -u dotnet-myapp -f`
2. Verify .NET runtime is installed: `dotnet --version`
3. Check application files permissions
4. Verify main .dll file exists

#### Port Already in Use
1. Check what's using the port: `sudo ss -tuln | grep :5000`
2. Choose a different port
3. Stop conflicting service if necessary

#### Nginx Configuration Issues
1. Test configuration: `sudo nginx -t`
2. Check Nginx logs: `sudo tail -f /var/log/nginx/error.log`
3. Verify site is enabled: `ls -la /etc/nginx/sites-enabled/`

#### Permission Issues
1. Check file ownership: `ls -la /var/www/dotnet-apps/myapp/`
2. Fix permissions: `sudo chown -R www-data:www-data /var/www/dotnet-apps/myapp/`

### Log Files
- Deployment logs: `/var/log/dotnet-deployment.log`
- Application logs: `sudo journalctl -u dotnet-{app-name}`
- Nginx logs: `/var/log/nginx/access.log` and `/var/log/nginx/error.log`

## Security Considerations

### Application Security
- Applications run as `www-data` user (non-root)
- Files have restricted permissions
- Production environment configuration

### Network Security
- Consider using HTTPS with SSL certificates
- Configure firewall rules appropriately
- Use strong passwords for any database connections

### Recommended Security Enhancements
1. **SSL/TLS Configuration**:
   ```bash
   # Install Certbot for Let's Encrypt
   sudo apt install certbot python3-certbot-nginx
   
   # Get SSL certificate
   sudo certbot --nginx -d your-domain.com
   ```

2. **Firewall Configuration**:
   ```bash
   # Allow HTTP and HTTPS
   sudo ufw allow 80
   sudo ufw allow 443
   
   # Block direct access to application ports
   sudo ufw deny 5000:5999/tcp
   ```

## Performance Optimization

### Application Performance
- Use `Production` environment for deployed applications
- Configure appropriate memory limits
- Enable gzip compression in Nginx
- Use static file serving for wwwroot content

### Nginx Optimization
```nginx
# Add to Nginx configuration for better performance
gzip on;
gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

# Enable static file caching
location ~* \.(css|js|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

## Backup and Recovery

### Automatic Backups
The script automatically creates backups:
- Before overwriting existing deployments
- Before removing deployments
- Backups stored in `/var/backups/dotnet-apps/`

### Manual Backup
```bash
# Create manual backup
sudo cp -r /var/www/dotnet-apps/myapp /var/backups/dotnet-apps/myapp_manual_$(date +%Y%m%d_%H%M%S)
```

### Recovery Process
1. Stop the service: `sudo systemctl stop dotnet-myapp`
2. Restore files: `sudo cp -r /var/backups/dotnet-apps/myapp_backup_* /var/www/dotnet-apps/myapp/`
3. Fix permissions: `sudo chown -R www-data:www-data /var/www/dotnet-apps/myapp/`
4. Start the service: `sudo systemctl start dotnet-myapp`

## Best Practices

### Development Workflow
1. **Local Development**: Develop and test locally
2. **Build Release**: Create release build with `dotnet publish`
3. **Test Deployment**: Test on staging environment first
4. **Production Deployment**: Deploy to production using this script

### Monitoring
1. Set up log monitoring for application errors
2. Monitor service health with systemd
3. Set up Nginx access log monitoring
4. Consider using application performance monitoring tools

### Maintenance
1. Regular security updates: `sudo apt update && sudo apt upgrade`
2. Monitor disk space usage
3. Regular backup verification
4. Log rotation configuration

## Examples

### Example 1: Simple Blog Application
```bash
# Application details
App Name: myblog
Source Path: /home/user/blog/bin/Release/net8.0/publish/
Port: 5000
Hosting Mode: Direct

# Result
Access URL: http://your-server/
Service: dotnet-myblog
```

### Example 2: API Service in Subdirectory
```bash
# Application details
App Name: myapi
Source Path: /home/user/api/bin/Release/net8.0/publish/
Port: 5001
Hosting Mode: Subdirectory
Subdirectory: api/v1

# Result
Access URL: http://your-server/api/v1/
Service: dotnet-myapi
```

### Example 3: Multiple Applications
```bash
# First app - Main website
App Name: website
Port: 5000
Hosting Mode: Direct

# Second app - Admin panel
App Name: admin
Port: 5001
Hosting Mode: Subdirectory
Subdirectory: admin

# Third app - API
App Name: api
Port: 5002
Hosting Mode: Subdirectory
Subdirectory: api

# Access URLs
# http://your-server/         (website)
# http://your-server/admin/   (admin)
# http://your-server/api/     (api)
```

## Support and Troubleshooting

### Getting Help
1. Check the logs first: `/var/log/dotnet-deployment.log`
2. Use the built-in status command: `sudo ./dotnet-web-app-deployer.sh status myapp`
3. Check service status: `sudo systemctl status dotnet-myapp`

### Common Commands Reference
```bash
# Script commands
sudo ./dotnet-web-app-deployer.sh deploy
sudo ./dotnet-web-app-deployer.sh status myapp
sudo ./dotnet-web-app-deployer.sh restart myapp
sudo ./dotnet-web-app-deployer.sh remove myapp

# System commands
sudo systemctl status dotnet-myapp
sudo journalctl -u dotnet-myapp -f
sudo nginx -t
sudo systemctl reload nginx
```

## Changelog

### Version 1.0
- Initial release
- Basic deployment functionality
- Interactive configuration
- Systemd service management
- Nginx reverse proxy configuration
- Backup and recovery features
- Command-line interface

---

*This documentation is part of the Ubuntu Server Setup Script collection. For more server management tools, visit the project repository.* 