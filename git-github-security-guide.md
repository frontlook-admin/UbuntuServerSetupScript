# Git and GitHub Security Configuration Guide

## Overview

This guide explains the secure approach to Git and GitHub configuration implemented in the Ubuntu Server Setup Script.

## Security Principles

### ✅ **System-wide Installation, User-specific Configuration**
- **Git Installation**: Performed as root for system-wide availability
- **GitHub Profiles**: Configured per-user with isolated settings
- **No Cross-user Access**: Each user's GitHub settings are private

## Implementation Details

### 1. Git Installation (Root Level)
```bash
# Git installed system-wide by root
sudo apt install -y git

# GitHub CLI installed system-wide (optional)
sudo apt install -y gh
```

### 2. User-specific GitHub Configuration
```bash
# Configure GitHub for a specific user
sudo /usr/local/bin/setup-user-github <username>
```

#### What this script does:
- ✅ **User Isolation**: Configurations stored in user's home directory (`~/.gitconfig`)
- ✅ **SSH Key Security**: SSH keys generated in user's `~/.ssh/` directory
- ✅ **Proper Permissions**: Files owned by the user with correct permissions (600/644)
- ✅ **Individual Authentication**: Each user authenticates with GitHub separately

### 3. Security Features

#### File Permissions
| File | Location | Permissions | Owner |
|------|----------|-------------|-------|
| `.gitconfig` | `~user/.gitconfig` | 644 | user:user |
| `id_rsa` | `~user/.ssh/id_rsa` | 600 | user:user |
| `id_rsa.pub` | `~user/.ssh/id_rsa.pub` | 644 | user:user |
| `.ssh/config` | `~user/.ssh/config` | 600 | user:user |

#### Isolation Guarantees
- ❌ **No Root GitHub Access**: Root user doesn't have GitHub configuration
- ❌ **No Cross-user Access**: Users cannot access other users' GitHub settings
- ❌ **No Global Shared Keys**: Each user has unique SSH keys
- ✅ **Individual Control**: Each user manages their own GitHub authentication

## Usage Examples

### For System Administrators

#### Initial Setup (Run as root)
```bash
# Run the main setup script
sudo ./ubuntu-server-complete-setup.sh

# When prompted, choose to install Git system-wide
# Skip configuring GitHub during initial setup
```

#### Configure GitHub for Existing Users
```bash
# Configure GitHub for user 'john'
sudo /usr/local/bin/setup-user-github john

# Configure GitHub for user 'alice'
sudo /usr/local/bin/setup-user-github alice
```

### For End Users

#### After Administrator Setup
```bash
# Check Git is available
git --version

# Check your Git configuration
git config --global --list

# Test GitHub connection (after SSH key setup)
ssh -T git@github.com

# Authenticate GitHub CLI (if installed)
gh auth login
```

#### Daily Git Usage
```bash
# All standard Git commands work as expected
git clone git@github.com:username/repository.git
git add .
git commit -m "Your commit message"
git push origin main
```

## Troubleshooting

### Common Issues

#### 1. Permission Denied (publickey)
```bash
# Check SSH key exists
ls -la ~/.ssh/

# Check SSH key permissions
ls -l ~/.ssh/id_rsa*

# Test GitHub connection
ssh -T git@github.com
```

#### 2. Git Config Not Found
```bash
# Check Git configuration
git config --global --list

# Reconfigure if needed
sudo /usr/local/bin/setup-user-github $(whoami)
```

#### 3. SSH Key Issues
```bash
# Check SSH key format
ssh-keygen -l -f ~/.ssh/id_rsa.pub

# Add key to SSH agent
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa
```

### Verification Commands

#### Check User Configuration
```bash
# Verify Git configuration
git config --global user.name
git config --global user.email

# Verify SSH key
cat ~/.ssh/id_rsa.pub

# Test GitHub authentication
ssh -T git@github.com
```

#### Check File Permissions
```bash
# Check .ssh directory permissions (should be 700)
ls -ld ~/.ssh/

# Check SSH key permissions
ls -l ~/.ssh/id_rsa*

# Check Git config permissions
ls -l ~/.gitconfig
```

## Security Best Practices

### For Administrators
1. **Never configure GitHub as root**: Use the user-specific script
2. **Verify user isolation**: Check that users can't access each other's SSH keys
3. **Regular audits**: Review user Git configurations periodically
4. **Backup considerations**: Include user SSH keys in backup strategies

### For Users
1. **Protect your SSH keys**: Never share private keys
2. **Use strong passphrases**: Consider adding passphrases to SSH keys
3. **Regular key rotation**: Update SSH keys periodically
4. **Monitor access**: Check GitHub account for unauthorized access

## Migration from Old Setup

If you have existing root-level GitHub configuration:

### 1. Backup Existing Configuration
```bash
# Backup root Git config
sudo cp /root/.gitconfig /root/.gitconfig.backup

# Backup root SSH keys
sudo cp -r /root/.ssh /root/.ssh.backup
```

### 2. Remove Root Configuration
```bash
# Clear root Git config
sudo rm /root/.gitconfig

# Clear root SSH keys (optional)
sudo rm -rf /root/.ssh/id_rsa*
```

### 3. Setup User-specific Configuration
```bash
# For each user that needs GitHub access
sudo /usr/local/bin/setup-user-github username1
sudo /usr/local/bin/setup-user-github username2
```

## Advanced Configuration

### SSH Config Customization
```bash
# Edit SSH config for custom settings
nano ~/.ssh/config

# Example: Custom SSH port for GitHub Enterprise
Host github-enterprise.company.com
    HostName github-enterprise.company.com
    User git
    Port 2222
    IdentityFile ~/.ssh/id_rsa_enterprise
```

### Multiple GitHub Accounts
```bash
# Generate additional SSH key
ssh-keygen -t rsa -b 4096 -C "work@company.com" -f ~/.ssh/id_rsa_work

# Configure SSH for multiple accounts
cat >> ~/.ssh/config << EOF
Host github-work
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_work

Host github-personal
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa
EOF

# Clone with specific account
git clone git@github-work:company/repository.git
```

## Conclusion

This secure approach ensures:
- ✅ **System-wide Git availability**
- ✅ **User-specific GitHub configurations**
- ✅ **Complete isolation between users**
- ✅ **Proper security permissions**
- ✅ **No shared credentials**

Each user maintains full control over their GitHub authentication while preventing unauthorized access to other users' configurations. 