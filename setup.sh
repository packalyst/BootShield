#!/bin/bash

################################################################################
#
#   Server Setup Bootstrap Script
#
#   This script detects your Linux distribution and runs the appropriate
#   hardening script for your system.
#
#   Supported distributions:
#   - Ubuntu 20.04, 22.04, 24.04
#   - Debian 11, 12
#   - Rocky Linux 8, 9
#   - AlmaLinux 8, 9
#   - CentOS Stream 8, 9
#
#   Usage:
#     curl -fsSL https://raw.githubusercontent.com/packalyst/BootShield/main/setup.sh | sudo bash
#
#   Or download and run:
#     wget -O setup.sh https://raw.githubusercontent.com/packalyst/BootShield/main/setup.sh
#     chmod +x setup.sh
#     sudo ./setup.sh
#
################################################################################

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# GitHub repository (change this to your repo)
REPO_URL="https://raw.githubusercontent.com/packalyst/BootShield/main"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'

# =============================================================================
# FUNCTIONS
# =============================================================================

print_banner() {
    clear
    printf "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                                                                           ║
    ║   ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗                        ║
    ║   ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗                       ║
    ║   ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝                       ║
    ║   ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗                       ║
    ║   ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║                       ║
    ║   ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝                       ║
    ║                                                                           ║
    ║   ███████╗███████╗████████╗██╗   ██╗██████╗                               ║
    ║   ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗                              ║
    ║   ███████╗█████╗     ██║   ██║   ██║██████╔╝                              ║
    ║   ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝                               ║
    ║   ███████║███████╗   ██║   ╚██████╔╝██║                                   ║
    ║   ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝                                   ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
}

log_info() {
    printf "${CYAN}[INFO]${NC} %s\n" "$1"
}

log_success() {
    printf "${GREEN}[OK]${NC} %s\n" "$1"
}

log_error() {
    printf "${RED}[ERROR]${NC} %s\n" "$1" >&2
}

log_warning() {
    printf "${YELLOW}[WARN]${NC} %s\n" "$1"
}

# Detect the Linux distribution
detect_distro() {
    local distro=""
    local version=""
    local family=""

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        distro="${ID:-unknown}"
        version="${VERSION_ID:-unknown}"

        case "$distro" in
            ubuntu)
                family="debian"
                ;;
            debian)
                family="debian"
                ;;
            rocky|almalinux|centos|rhel|fedora)
                family="rhel"
                ;;
            *)
                family="unknown"
                ;;
        esac
    elif [[ -f /etc/redhat-release ]]; then
        family="rhel"
        if grep -qi "rocky" /etc/redhat-release; then
            distro="rocky"
        elif grep -qi "alma" /etc/redhat-release; then
            distro="almalinux"
        elif grep -qi "centos" /etc/redhat-release; then
            distro="centos"
        else
            distro="rhel"
        fi
        version=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    elif [[ -f /etc/debian_version ]]; then
        family="debian"
        distro="debian"
        version=$(cat /etc/debian_version)
    else
        family="unknown"
        distro="unknown"
        version="unknown"
    fi

    echo "$distro|$version|$family"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo ""
        echo "Please run with sudo:"
        echo "  sudo $0"
        exit 1
    fi
}

# Check internet connectivity
check_internet() {
    log_info "Checking internet connectivity..."

    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null && ! ping -c 1 -W 5 1.1.1.1 &>/dev/null; then
        log_error "No internet connection detected"
        exit 1
    fi

    log_success "Internet connection OK"
}

# Download and run the appropriate script
run_distro_script() {
    local distro="$1"
    local version="$2"
    local family="$3"
    local script_name=""
    local script_url=""
    local tmp_script=""

    # Determine which script to use
    case "$distro" in
        ubuntu)
            script_name="ubuntu.sh"
            ;;
        debian)
            script_name="debian.sh"
            ;;
        rocky|almalinux|centos|rhel)
            script_name="rhel.sh"
            ;;
        *)
            log_error "Unsupported distribution: $distro"
            echo ""
            echo "Supported distributions:"
            echo "  - Ubuntu 20.04, 22.04, 24.04"
            echo "  - Debian 11, 12"
            echo "  - Rocky Linux 8, 9"
            echo "  - AlmaLinux 8, 9"
            echo "  - CentOS Stream 8, 9"
            exit 1
            ;;
    esac

    script_url="${REPO_URL}/distros/${script_name}"
    tmp_script=$(mktemp)

    log_info "Downloading ${script_name}..."

    if command -v curl &>/dev/null; then
        if ! curl -fsSL "$script_url" -o "$tmp_script"; then
            log_error "Failed to download script from $script_url"
            rm -f "$tmp_script"
            exit 1
        fi
    elif command -v wget &>/dev/null; then
        if ! wget -q "$script_url" -O "$tmp_script"; then
            log_error "Failed to download script from $script_url"
            rm -f "$tmp_script"
            exit 1
        fi
    else
        log_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi

    log_success "Downloaded ${script_name}"

    # Make executable and run
    chmod +x "$tmp_script"

    log_info "Starting ${distro^} server setup..."
    echo ""

    # Run the script
    bash "$tmp_script"
    local exit_code=$?

    # Cleanup
    rm -f "$tmp_script"

    return $exit_code
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_banner

    check_root
    check_internet

    echo ""
    log_info "Detecting distribution..."

    local distro_info
    distro_info=$(detect_distro)

    local distro version family
    IFS='|' read -r distro version family <<< "$distro_info"

    echo ""
    printf "  ${WHITE}Distribution:${NC} %s\n" "${distro^}"
    printf "  ${WHITE}Version:${NC}      %s\n" "$version"
    printf "  ${WHITE}Family:${NC}       %s\n" "$family"
    echo ""

    # Version check warnings
    case "$distro" in
        ubuntu)
            case "$version" in
                20.04|22.04|24.04)
                    log_success "Ubuntu $version is supported"
                    ;;
                *)
                    log_warning "Ubuntu $version may not be fully tested"
                    ;;
            esac
            ;;
        debian)
            case "${version%%.*}" in
                11|12)
                    log_success "Debian ${version%%.*} is supported"
                    ;;
                *)
                    log_warning "Debian $version may not be fully tested"
                    ;;
            esac
            ;;
        rocky|almalinux)
            case "${version%%.*}" in
                8|9)
                    log_success "${distro^} ${version%%.*} is supported"
                    ;;
                *)
                    log_warning "${distro^} $version may not be fully tested"
                    ;;
            esac
            ;;
    esac

    echo ""
    # Skip confirmation if running non-interactively (e.g., curl | bash)
    if [[ -t 0 ]]; then
        read -p "Continue with setup? [Y/n] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    else
        log_info "Non-interactive mode detected, continuing automatically..."
    fi

    echo ""
    run_distro_script "$distro" "$version" "$family"
}

# Run main function
main "$@"
