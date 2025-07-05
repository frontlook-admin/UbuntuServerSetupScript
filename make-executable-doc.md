# Script Permission Manager Documentation

## Table of Contents
1. [Overview](#overview)
2. [Features](#features)
3. [Installation](#installation)
4. [Configuration](#configuration)
5. [Usage](#usage)
6. [Command Reference](#command-reference)
7. [File Detection](#file-detection)
8. [Safety Features](#safety-features)
9. [Interactive Mode](#interactive-mode)
10. [Backup and Recovery](#backup-and-recovery)
11. [Advanced Usage](#advanced-usage)
12. [Troubleshooting](#troubleshooting)
13. [Best Practices](#best-practices)
14. [Examples](#examples)
15. [FAQ](#faq)

---

## Overview

The Script Permission Manager is a comprehensive bash utility designed to automatically identify and set execute permissions (`chmod +x`) for script files in directories. It provides intelligent file detection, safety features, and comprehensive logging to ensure secure and reliable permission management.

### Key Capabilities
- **Automatic Script Detection**: Identifies scripts by extension and shebang lines
- **Batch Processing**: Process entire directories with optional recursion
- **Safety Features**: Dry run mode, backups, and confirmation prompts
- **Flexible Configuration**: Custom extensions, exclude patterns, and options
- **Interactive Mode**: User-friendly guided interface
- **Comprehensive Logging**: Detailed operation logs and audit trails
- **Analysis Tools**: Scan directories and analyze script types

### Use Cases
- **Development Environments**: Quickly make downloaded scripts executable
- **Project Setup**: Batch process script permissions for new projects
- **System Administration**: Manage script permissions across system directories
- **CI/CD Pipelines**: Automate script permission setup in deployment workflows
- **File Organization**: Maintain proper permissions in script repositories

### Compatibility
- **Operating Systems**: Linux, macOS, Unix-like systems
- **Shell**: Bash 4.0+
- **Dependencies**: Standard Unix utilities (find, chmod, stat)
- **Permissions**: User permissions for target directories

---

## Features

### ✅ Intelligent File Detection
- **Extension-Based**: Recognizes common script file extensions
- **Shebang Detection**: Identifies scripts by interpreter declarations
- **Content Analysis**: Examines file headers for script indicators
- **Customizable Patterns**: User-defined extension and exclusion lists

### ✅ Safety and Security
- **Dry Run Mode**: Preview changes without modifying files
- **Permission Backup**: Save original permissions before changes
- **Confirmation Prompts**: User confirmation for destructive operations
- **Self-Exclusion**: Automatically excludes itself from processing
- **Error Handling**: Robust error checking and recovery

### ✅ Flexible Processing
- **Recursive Processing**: Option to process subdirectories
- **Selective Processing**: Include/exclude specific file patterns
- **Custom Extensions**: Define custom script file extensions
- **Batch Operations**: Process multiple files efficiently

### ✅ User Experience
- **Interactive Mode**: Guided user interface with prompts
- **Verbose Output**: Detailed operation feedback
- **Progress Indicators**: Clear status and progress information
- **Comprehensive Help**: Built-in documentation and examples

### ✅ Logging and Auditing
- **Operation Logs**: Detailed logs of all operations
- **Change Tracking**: Record of permission modifications
- **Error Reporting**: Comprehensive error logging
- **Audit Trail**: Complete history of script operations

---

## Installation

### 1. Download the Script
```bash
# Download directly (replace with actual URL)
wget https://raw.githubusercontent.com/your-repo/make-executable.sh

# Or create the file manually
nano make-executable.sh
# Copy and paste the script content
```

### 2. Make Script Executable
```bash
chmod +x make-executable.sh
```

### 3. Move to System Path (Optional)
```bash
# Move to user binaries
mv make-executable.sh ~/bin/make-executable

# Or move to system binaries (requires sudo)
sudo mv make-executable.sh /usr/local/bin/make-executable
```

### 4. Verify Installation
```bash
./make-executable.sh --help
```

### 5. Test Installation
```bash
# Test with dry run
./make-executable.sh -d -v
```

---

## Configuration

### Default Settings
```bash
# Default directory to process
DEFAULT_DIRECTORY="."

# Log file location
LOG_FILE="/tmp/make-executable.log"

# Processing modes
DRY_RUN=false
RECURSIVE=false
VERBOSE=false
FORCE=false
BACKUP=false
```

### Supported Script Extensions
```bash
SCRIPT_EXTENSIONS=(
    "sh"      # Shell scripts
    "bash"    # Bash scripts
    "py"      # Python scripts
    "pl"      # Perl scripts
    "rb"      # Ruby scripts
    "js"      # JavaScript
    "php"     # PHP scripts
    "lua"     # Lua scripts
    "awk"     # AWK scripts
    "sed"     # SED scripts
    "tcl"     # TCL scripts
    "expect"  # Expect scripts
    "zsh"     # Zsh scripts
    "fish"    # Fish scripts
    "csh"     # C Shell scripts
    "ksh"     # Korn Shell scripts
)
```

### Default Exclude Patterns
```bash
EXCLUDE_PATTERNS=(
    "*.bak"     # Backup files
    "*.tmp"     # Temporary files
    "*.log"     # Log files
    "*.conf"    # Configuration files
    "*.config"  # Configuration files
    "*.txt"     # Text files
    "*.md"      # Markdown files
    "*.json"    # JSON files
    "*.xml"     # XML files
    "*.yaml"    # YAML files
    "*.yml"     # YAML files
)
```

### Environment Variables
```bash
# Set custom log file
export MAKE_EXECUTABLE_LOG="/var/log/make-executable.log"

# Set default behavior
export MAKE_EXECUTABLE_VERBOSE=true
export MAKE_EXECUTABLE_BACKUP=true
```

---

## Usage

### Basic Syntax
```bash
./make-executable.sh [OPTIONS] [DIRECTORY]
```

### Quick Start
```bash
# Process current directory
./make-executable.sh

# Process specific directory
./make-executable.sh /path/to/scripts

# Dry run to preview changes
./make-executable.sh -d

# Recursive processing with verbose output
./make-executable.sh -r -v /path/to/project
```

### Common Use Cases

#### 1. New Project Setup
```bash
# Process entire project recursively
./make-executable.sh -r -v /path/to/new/project

# With backup for safety
./make-executable.sh -r -b /path/to/new/project
```

#### 2. Downloaded Scripts
```bash
# Check what would be changed first
./make-executable.sh -d ~/Downloads

# Apply changes
./make-executable.sh ~/Downloads
```

#### 3. System Administration
```bash
# Process system scripts with backup
sudo ./make-executable.sh -b -v /usr/local/scripts

# Process with custom log location
sudo ./make-executable.sh -l /var/log/scripts.log /opt/scripts
```

---

## Command Reference

### Options

#### `-r, --recursive`
Process directories recursively, including all subdirectories.

**Usage:**
```bash
./make-executable.sh -r /path/to/project
```

**Description:**
- Processes all files in the target directory and subdirectories
- Maintains directory structure in processing
- Useful for complex project hierarchies

#### `-d, --dry-run`
Show what would be done without making actual changes.

**Usage:**
```bash
./make-executable.sh -d /path/to/scripts
```

**Description:**
- Previews all operations without modifying files
- Displays files that would be made executable
- Safe way to test script behavior

#### `-v, --verbose`
Enable detailed output showing all operations.

**Usage:**
```bash
./make-executable.sh -v /path/to/scripts
```

**Description:**
- Shows detailed processing information
- Displays files being processed, skipped, or excluded
- Helpful for debugging and monitoring

#### `-f, --force`
Force execution without confirmation prompts.

**Usage:**
```bash
./make-executable.sh -f /path/to/scripts
```

**Description:**
- Bypasses user confirmation prompts
- Useful for automated scripts and CI/CD
- **Use with caution** in production environments

#### `-b, --backup`
Create backup of original file permissions.

**Usage:**
```bash
./make-executable.sh -b /path/to/scripts
```

**Description:**
- Saves original permissions to backup file
- Allows restoration of original state
- Backup stored in `/tmp/permissions_backup_TIMESTAMP/`

#### `-e, --extensions LIST`
Specify custom list of file extensions to process.

**Usage:**
```bash
./make-executable.sh -e "sh,py,pl" /path/to/scripts
```

**Description:**
- Comma-separated list of extensions
- Overrides default extension list
- Case-sensitive matching

#### `-x, --exclude PATTERN`
Exclude files matching specified pattern.

**Usage:**
```bash
./make-executable.sh -x "*.bak" -x "test*" /path/to/scripts
```

**Description:**
- Can be used multiple times for multiple patterns
- Supports shell glob patterns
- Applied to filenames only, not full paths

#### `-l, --log FILE`
Specify custom log file location.

**Usage:**
```bash
./make-executable.sh -l /var/log/my-scripts.log /path/to/scripts
```

**Description:**
- Custom log file path and name
- Creates log file if it doesn't exist
- Appends to existing log files

#### `-h, --help`
Display comprehensive help information.

**Usage:**
```bash
./make-executable.sh --help
```

### Commands

#### Interactive Mode
```bash
./make-executable.sh -i
```
Launches guided interactive mode with menu-driven interface.

#### Scan Mode
```bash
./make-executable.sh -s [DIRECTORY]
```
Analyzes directory and reports script file statistics without making changes.

#### List Types
```bash
./make-executable.sh --list-types [DIRECTORY]
```
Shows breakdown of script types found in directory by extension and interpreter.

---

## File Detection

### Extension-Based Detection
The script identifies files based on their file extensions:

```bash
# Common script extensions
.sh      # Shell scripts
.bash    # Bash scripts
.py      # Python scripts
.pl      # Perl scripts
.rb      # Ruby scripts
.js      # JavaScript files
.php     # PHP scripts
.lua     # Lua scripts
```

### Shebang-Based Detection
Files without extensions are checked for shebang lines:

```bash
#!/bin/bash       # Bash script
#!/usr/bin/python # Python script
#!/usr/bin/perl   # Perl script
#!/usr/bin/ruby   # Ruby script
#!/usr/bin/env python3  # Python 3 script
```

### Custom Extension Lists
Override default extensions with custom lists:

```bash
# Process only shell and Python scripts
./make-executable.sh -e "sh,py" /path/to/scripts

# Process custom script types
./make-executable.sh -e "script,run,exec" /path/to/custom
```

### Exclusion Patterns
Files matching exclusion patterns are skipped:

```bash
# Default exclusions
*.bak *.tmp *.log *.conf *.txt *.md

# Custom exclusions
./make-executable.sh -x "*.backup" -x "old*" /path/to/scripts
```

---

## Safety Features

### Dry Run Mode
Preview operations without making changes:

```bash
./make-executable.sh -d -v /path/to/scripts
```

**Output Example:**
