#!/bin/bash
set -e

# ============================================================================
# ANM - Advanced Network Monitor Installer
# ============================================================================

REPO_OWNER="sundaresan-dev"
REPO_NAME="advanced-network-monitor"
BRANCH="main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/anm"
LOG_DIR="/var/log/anm"
DATA_DIR="/var/lib/anm"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Print banner
cat << "EOF"
     _    _   _ __  __ 
    / \  | \ | |  \/  |
   / _ \ |  \| | |\/| |
  / ___ \| |\  | |  | |
 /_/   \_\_| \_|_|  |_|
                        
  Advanced Network Monitor - SRE Edition
  Installing version 1.0.0
EOF
echo

# Print status
print_status() {
    local type=$1
    local message=$2
    case $type in
        "info") echo -e "${BLUE}[INFO]${NC} $message" ;;
        "success") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "warn") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "error") echo -e "${RED}[ERROR]${NC} $message" ;;
    esac
}

# Root check
if [ "$EUID" -ne 0 ]; then
    print_status "error" "Please run as root (use sudo)"
    exit 1
fi

# Detect OS and package manager
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
    
    case $OS in
        ubuntu|debian|linuxmint)
            PKG_MANAGER="apt"
            INSTALL_CMD="apt-get install -y"
            UPDATE_CMD="apt-get update"
            DEPS="dnsutils inetutils-ping traceroute netcat-openbsd openssl bc jq curl"
            ;;
        rhel|centos|fedora|rocky|almalinux)
            if command -v dnf &>/dev/null; then
                PKG_MANAGER="dnf"
                INSTALL_CMD="dnf install -y"
                UPDATE_CMD="dnf check-update"
            else
                PKG_MANAGER="yum"
                INSTALL_CMD="yum install -y"
                UPDATE_CMD="yum check-update"
            fi
            DEPS="bind-utils iputils traceroute nc openssl bc jq curl"
            ;;
        suse|opensuse*)
            PKG_MANAGER="zypper"
            INSTALL_CMD="zypper install -y"
            UPDATE_CMD="zypper refresh"
            DEPS="bind-utils iputils traceroute netcat openssl bc jq curl"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            INSTALL_CMD="pacman -S --noconfirm"
            UPDATE_CMD="pacman -Sy"
            DEPS="bind inetutils traceroute gnu-netcat openssl bc jq curl"
            ;;
        alpine)
            PKG_MANAGER="apk"
            INSTALL_CMD="apk add"
            UPDATE_CMD="apk update"
            DEPS="bind-tools busybox-extras traceroute netcat-openbsd openssl bc jq curl"
            ;;
        *)
            print_status "warn" "Unknown OS: $OS. Attempting to continue with common dependencies..."
            PKG_MANAGER="unknown"
            DEPS=""
            ;;
    esac
    
    print_status "info" "Detected OS: $OS $VER"
    print_status "info" "Package manager: ${PKG_MANAGER:-unknown}"
}

# Install dependencies
install_deps() {
    print_status "info" "Checking and installing dependencies..."
    
    if [ -n "$PKG_MANAGER" ] && [ "$PKG_MANAGER" != "unknown" ]; then
        print_status "info" "Updating package cache..."
        $UPDATE_CMD || true
        
        print_status "info" "Installing: $DEPS"
        $INSTALL_CMD $DEPS
    fi
    
    # Check for optional tools
    local optional_tools=("mtr" "redis-cli" "mysql" "psql" "mongosh" "nmap")
    for tool in "${optional_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            print_status "info" "Optional tool found: $tool"
        fi
    done
    
    print_status "success" "Dependencies installed"
}

# Download and install main script
install_anm() {
    print_status "info" "Downloading ANM..."
    
    local script_url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/anm.sh"
    local temp_file="/tmp/anm.sh"
    
    if curl -fsSL "$script_url" -o "$temp_file"; then
        cp "$temp_file" "${INSTALL_DIR}/anm"
        chmod 755 "${INSTALL_DIR}/anm"
        rm -f "$temp_file"
        print_status "success" "Installed to ${INSTALL_DIR}/anm"
    else
        print_status "error" "Failed to download from GitHub"
        exit 1
    fi
}

# Create directories
create_dirs() {
    print_status "info" "Creating directories..."
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$LOG_DIR"
    chmod 755 "$DATA_DIR"
    
    print_status "success" "Directories created"
}

# Create configuration
create_config() {
    print_status "info" "Creating configuration..."
    
    cat > "$CONFIG_DIR/anm.conf" << EOF
# ============================================================================
# ANM - Advanced Network Monitor Configuration
# ============================================================================

# Default target (can be overridden with -t)
DEFAULT_TARGET="localhost"

# Default ports to scan
DEFAULT_PORTS=(22 80 443 3306 5432 27017 6379 8080 8443 9200 5601 9090 3000)

# Thresholds
LATENCY_WARN=150      # ms
LATENCY_CRIT=300      # ms
PACKET_LOSS_WARN=2    # %
PACKET_LOSS_CRIT=5    # %
DNS_TIME_WARN=100     # ms
DNS_TIME_CRIT=200     # ms
SSL_EXPIRY_WARN=30    # days
SSL_EXPIRY_CRIT=7     # days
RESPONSE_TIME_WARN=500   # ms
RESPONSE_TIME_CRIT=1000  # ms

# Logging
LOG_DIR="$LOG_DIR"
PERFORMANCE_LOG="\$LOG_DIR/performance-\$(date +%Y%m%d).csv"

# Features
ENABLE_SECURITY_CHECKS=true
ENABLE_DEPENDENCY_ANALYSIS=true
ENABLE_TRACEROUTE=true

# DNS servers
DNS_SERVERS="8.8.8.8 1.1.1.1 208.67.222.222"
EOF

    # Create aliases file
    cat > "$CONFIG_DIR/aliases" << EOF
# Host aliases for quick monitoring
# Format: alias_name=hostname_or_ip

# Examples:
# prod-db1=192.168.1.100
# web-prod=example.com
EOF

    chmod 644 "$CONFIG_DIR/anm.conf"
    chmod 644 "$CONFIG_DIR/aliases"
    
    print_status "success" "Configuration created"
}

# Create bash completion
create_completion() {
    print_status "info" "Creating bash completion..."
    
    mkdir -p /etc/bash_completion.d
    
    cat > "/etc/bash_completion.d/anm" << 'EOF'
_anm_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    opts="-t --target -p --ports -c --continuous -i --interval -j --json -v --verbose -l --log -h --help --no-traceroute --no-security --no-dependency"
    
    case "${prev}" in
        -t|--target)
            if [ -f /etc/anm/aliases ]; then
                COMPREPLY=($(compgen -W "$(grep -v '^#' /etc/anm/aliases | cut -d'=' -f1)" -- ${cur}))
            fi
            return 0
            ;;
        -p|--ports)
            COMPREPLY=($(compgen -W "22 80 443 3306 5432 6379 8080 9200" -- ${cur}))
            return 0
            ;;
        -i|--interval)
            COMPREPLY=($(compgen -W "10 30 60 300 600" -- ${cur}))
            return 0
            ;;
    esac
    
    COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
    return 0
}

complete -F _anm_completion anm
EOF

    print_status "success" "Bash completion created"
}

# Create man page
create_manpage() {
    print_status "info" "Creating man page..."
    
    mkdir -p /usr/local/man/man1
    
    cat > "/usr/local/man/man1/anm.1" << EOF
.TH ANM 1 "$(date +%B %Y)" "1.0.0" "Advanced Network Monitor"
.SH NAME
anm \- Advanced Network Monitor for SREs
.SH SYNOPSIS
.B anm
[\fB\-t\fR \fITARGET\fR] [\fB\-p\fR \fI"PORTS"\fR] [\fB\-c\fR] [\fB\-j\fR] [\fB\-v\fR] [\fB\-h\fR]
.SH DESCRIPTION
ANM is a comprehensive network monitoring tool designed for Site Reliability Engineers.
It performs DNS checks, network analysis, port scanning, security checks, and dependency analysis.
.SH OPTIONS
.TP
.B \-t, \-\-target DOMAIN/IP
Target domain or IP address to monitor
.TP
.B \-p, \-\-ports "LIST"
Custom ports to check (space-separated in quotes)
.TP
.B \-c, \-\-continuous
Run in continuous monitoring mode
.TP
.B \-i, \-\-interval SECONDS
Check interval in seconds (default: 30)
.TP
.B \-j, \-\-json
Output in JSON format
.TP
.B \-v, \-\-verbose
Verbose output with detailed information
.TP
.B \-l, \-\-log FILE
Log output to specified file
.TP
.B \-h, \-\-help
Show help message
.SH EXAMPLES
.B anm -t google.com
.RS 4
Basic monitoring of google.com
.RE
.B anm -t api.example.com -c -i 60
.RS 4
Continuous monitoring every 60 seconds
.RE
.B anm -t myserver.com -p "80 443 3306" -j
.RS 4
Custom ports with JSON output
.RE
.SH FILES
.I /etc/anm/anm.conf
.RS 4
Main configuration file
.RE
.I /etc/anm/aliases
.RS 4
Host aliases for quick reference
.RE
.SH AUTHOR
Sundaresan
.SH REPORTING BUGS
https://github.com/sundaresan-dev/advanced-network-monitor/issues
EOF

    print_status "success" "Man page created"
}

# Create uninstaller
create_uninstaller() {
    print_status "info" "Creating uninstaller..."
    
    cat > "/usr/local/bin/anm-uninstall" << 'EOF'
#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}ANM Uninstaller${NC}"
echo "This will remove ANM and all its components"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] Please run as root (sudo)${NC}"
    exit 1
fi

read -p "Remove all configuration and data? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing binary..."
    rm -f /usr/local/bin/anm
    
    echo "Removing configuration..."
    rm -rf /etc/anm
    
    echo "Removing logs and data..."
    rm -rf /var/log/anm
    rm -rf /var/lib/anm
    
    echo "Removing documentation..."
    rm -f /usr/local/man/man1/anm.1
    rm -f /etc/bash_completion.d/anm
    
    echo "Removing uninstaller..."
    rm -f /usr/local/bin/anm-uninstall
    
    echo -e "${GREEN}[SUCCESS] ANM has been uninstalled${NC}"
else
    echo "Uninstall cancelled"
fi
EOF

    chmod 755 "/usr/local/bin/anm-uninstall"
    print_status "success" "Uninstaller created: anm-uninstall"
}

# Verify installation
verify_install() {
    print_status "info" "Verifying installation..."
    
    if command -v anm &>/dev/null; then
        local version=$(anm --version 2>/dev/null || echo "1.0.0")
        print_status "success" "ANM installed successfully (version: $version)"
    else
        print_status "error" "Installation verification failed"
        exit 1
    fi
}

# Print summary
print_summary() {
    cat << EOF

${GREEN}════════════════════════════════════════════════════════════════${NC}
${GREEN}              ANM INSTALLATION COMPLETE                         ${NC}
${GREEN}════════════════════════════════════════════════════════════════${NC}

${CYAN}Installation Details:${NC}
  • Binary:      /usr/local/bin/anm
  • Config:      /etc/anm/
  • Logs:        /var/log/anm/
  • Data:        /var/lib/anm/

${CYAN}Quick Start Commands:${NC}
  • Basic check:      ${YELLOW}anm -t example.com${NC}
  • Continuous:       ${YELLOW}anm -t example.com -c -i 30${NC}
  • JSON output:      ${YELLOW}anm -t example.com -j${NC}
  • Verbose mode:     ${YELLOW}anm -t example.com -v${NC}

${CYAN}Documentation:${NC}
  • Help:             ${YELLOW}anm --help${NC}
  • Man page:         ${YELLOW}man anm${NC}
  • Config:           ${YELLOW}cat /etc/anm/anm.conf${NC}

${CYAN}Uninstall:${NC}
  • Run:              ${YELLOW}sudo anm-uninstall${NC}

${GREEN}════════════════════════════════════════════════════════════════${NC}
${GREEN}Thank you for installing ANM!${NC}
EOF
}

# Main installation flow
main() {
    print_status "info" "Starting ANM installation..."
    echo "────────────────────────────────────────────────────"
    
    detect_os
    install_deps
    create_dirs
    install_anm
    create_config
    create_completion
    create_manpage
    create_uninstaller
    verify_install
    
    echo "────────────────────────────────────────────────────"
    print_summary
}

# Run main function
main "$@"
