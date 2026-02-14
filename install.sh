#!/bin/bash
set -e

# ============================================================================
# ANM - Advanced Network Monitor Installer
# ============================================================================

REPO_OWNER="sundaresan-dev"
REPO_NAME="advanced-network-monitor"
BRANCH="main"
SCRIPT_NAME="anm"   # <-- GitHub repo-la irukka file name
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

# Banner
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
                INSTALL_CMD="dnf install -y"
                UPDATE_CMD="dnf check-update"
            else
                INSTALL_CMD="yum install -y"
                UPDATE_CMD="yum check-update"
            fi
            DEPS="bind-utils iputils traceroute nc openssl bc jq curl"
            ;;
        arch|manjaro)
            INSTALL_CMD="pacman -S --noconfirm"
            UPDATE_CMD="pacman -Sy"
            DEPS="bind inetutils traceroute gnu-netcat openssl bc jq curl"
            ;;
        alpine)
            INSTALL_CMD="apk add"
            UPDATE_CMD="apk update"
            DEPS="bind-tools busybox-extras traceroute netcat-openbsd openssl bc jq curl"
            ;;
        *)
            print_status "warn" "Unknown OS: $OS. Skipping dependency auto install."
            DEPS=""
            ;;
    esac

    print_status "info" "Detected OS: $OS $VER"
}

install_deps() {
    print_status "info" "Installing dependencies..."
    if [ -n "$DEPS" ]; then
        $UPDATE_CMD || true
        $INSTALL_CMD $DEPS
    fi
    print_status "success" "Dependencies done"
}

create_dirs() {
    print_status "info" "Creating directories..."

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"

    # Permissions
    chmod 755 "$CONFIG_DIR"
    chmod 755 "$DATA_DIR"

    # Log directory should be writable by normal user
    chown -R root:adm "$LOG_DIR" 2>/dev/null || chown -R root:root "$LOG_DIR"
    chmod -R 775 "$LOG_DIR"

    # Add current user to adm group if possible (Ubuntu/Debian)
    if getent group adm >/dev/null 2>&1; then
        if ! groups "$SUDO_USER" | grep -q "\badm\b"; then
            print_status "info" "Adding $SUDO_USER to adm group for log write access..."
            usermod -aG adm "$SUDO_USER" || true
            print_status "warn" "Please logout/login once for group changes to take effect."
        fi
    fi

    print_status "success" "Directories created with proper permissions"
}

install_anm() {
    print_status "info" "Downloading ANM from GitHub..."

    local script_url="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}/${SCRIPT_NAME}"
    local temp_file="/tmp/anm"

    print_status "info" "URL: $script_url"

    if curl -fsSL "$script_url" -o "$temp_file"; then
        cp "$temp_file" "${INSTALL_DIR}/anm"
        chmod 755 "${INSTALL_DIR}/anm"
        rm -f "$temp_file"
        print_status "success" "Installed to ${INSTALL_DIR}/anm"
    else
        print_status "error" "Failed to download ANM. Check file name/path in GitHub repo."
        exit 1
    fi
}

create_config() {
    print_status "info" "Creating configuration..."

    cat > "$CONFIG_DIR/anm.conf" << EOF
DEFAULT_TARGET="localhost"
DEFAULT_PORTS=(22 80 443 3306 5432 27017 6379 8080 8443 9200 5601 9090 3000)

LATENCY_WARN=150
LATENCY_CRIT=300
PACKET_LOSS_WARN=2
PACKET_LOSS_CRIT=5

LOG_DIR="$LOG_DIR"
PERFORMANCE_LOG="\$LOG_DIR/performance-\$(date +%Y%m%d).csv"

ENABLE_SECURITY_CHECKS=true
ENABLE_DEPENDENCY_ANALYSIS=true
ENABLE_TRACEROUTE=true

DNS_SERVERS="8.8.8.8 1.1.1.1 208.67.222.222"
EOF

    cat > "$CONFIG_DIR/aliases" << EOF
# alias=hostname
# prod=example.com
EOF

    chmod 644 "$CONFIG_DIR/anm.conf" "$CONFIG_DIR/aliases"
    print_status "success" "Config created"
}

verify_install() {
    print_status "info" "Verifying installation..."
    if command -v anm &>/dev/null; then
        print_status "success" "ANM installed successfully 🎉"
    else
        print_status "error" "ANM not found in PATH"
        exit 1
    fi
}

main() {
    print_status "info" "Starting installation..."
    detect_os
    install_deps
    create_dirs
    install_anm
    create_config
    verify_install

    echo
    echo -e "${GREEN}ANM Installation Complete!${NC}"
    echo -e "${CYAN}Try:${NC} anm --help"
}

main "$@"
