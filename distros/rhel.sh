#!/bin/bash

################################################################################
#
#   ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗
#   ██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
#   ███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
#   ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
#   ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
#   ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝
#
#   ██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███╗   ██╗██╗███╗   ██╗ ██████╗
#   ██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║██║████╗  ██║██╔════╝
#   ███████║███████║██████╔╝██║  ██║█████╗  ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗
#   ██╔══██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██║╚██╗██║██║██║╚██╗██║██║   ██║
#   ██║  ██║██║  ██║██║  ██║██████╔╝███████╗██║ ╚████║██║██║ ╚████║╚██████╔╝
#   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝
#
#   Bulletproof RHEL/Rocky/Alma Server Setup & Hardening Script
#   Version: 2.0.0
#
#   Supported:
#   - Rocky Linux 8, 9
#   - AlmaLinux 8, 9
#   - CentOS Stream 8, 9
#   - RHEL 8, 9
#
#   Features:
#   - Interactive step-by-step configuration
#   - User confirmation for every action
#   - Beautiful CLI interface with progress tracking
#   - SSH hardening with lockout protection
#   - Firewall configuration (firewalld)
#   - Fail2ban setup
#   - SELinux configuration
#   - Kernel hardening
#   - Automatic security updates
#   - Full audit logging
#
################################################################################

set -uo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="Server Hardening"
LOG_DIR="/var/log/server-setup"
LOG_FILE="${LOG_DIR}/setup-$(date +%Y%m%d-%H%M%S).log"
STATE_FILE="/var/lib/server-setup-state"
BACKUP_DIR="/var/backups/server-setup-$(date +%Y%m%d-%H%M%S)"

# Terminal dimensions
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)
TERM_HEIGHT=$(tput lines 2>/dev/null || echo 24)

# =============================================================================
# COLORS & SYMBOLS
# =============================================================================

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'
readonly NC='\033[0m'

# Background colors
readonly BG_RED='\033[41m'
readonly BG_GREEN='\033[42m'
readonly BG_YELLOW='\033[43m'
readonly BG_BLUE='\033[44m'

# Symbols (with fallback for non-unicode terminals)
if [[ "${TERM:-dumb}" != "dumb" ]] && [[ -t 1 ]]; then
    readonly SYM_CHECK="✓"
    readonly SYM_CROSS="✗"
    readonly SYM_ARROW="→"
    readonly SYM_BULLET="•"
    readonly SYM_STAR="★"
    readonly SYM_WARN="⚠"
    readonly SYM_INFO="ℹ"
    readonly SYM_LOCK="🔒"
    readonly SYM_KEY="🔑"
    readonly SYM_SHIELD="🛡"
    readonly SYM_FIRE="🔥"
    readonly SYM_ROCKET="🚀"
    readonly SYM_GEAR="⚙"
    readonly SYM_DISK="💾"
    readonly SYM_NET="🌐"
    readonly SYM_USER="👤"
    readonly SYM_FOLDER="📁"
    readonly SYM_CLOCK="⏱"
    readonly SYM_PARTY="🎉"
else
    readonly SYM_CHECK="[OK]"
    readonly SYM_CROSS="[X]"
    readonly SYM_ARROW="->"
    readonly SYM_BULLET="*"
    readonly SYM_STAR="*"
    readonly SYM_WARN="[!]"
    readonly SYM_INFO="[i]"
    readonly SYM_LOCK="[LOCK]"
    readonly SYM_KEY="[KEY]"
    readonly SYM_SHIELD="[SHIELD]"
    readonly SYM_FIRE="[!!]"
    readonly SYM_ROCKET=">>>"
    readonly SYM_GEAR="[CFG]"
    readonly SYM_DISK="[DSK]"
    readonly SYM_NET="[NET]"
    readonly SYM_USER="[USR]"
    readonly SYM_FOLDER="[DIR]"
    readonly SYM_CLOCK="[TIME]"
    readonly SYM_PARTY="[!!!]"
fi

# =============================================================================
# GLOBAL STATE
# =============================================================================

declare -A MODULE_STATUS
declare -a CHANGES_MADE
declare -a BACKUP_FILES
CURRENT_MODULE=""
CURRENT_STEP=0
TOTAL_STEPS=14
DRY_RUN=false
SKIP_CONFIRMATIONS=false

# Package manager (dnf preferred, fallback to yum)
if command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
else
    PKG_MGR="yum"
fi

# =============================================================================
# UI HELPER FUNCTIONS
# =============================================================================

# Clear screen and move cursor to top
clear_screen() {
    printf '\033[2J\033[H'
}

# Move cursor to position
move_cursor() {
    local row=$1
    local col=$2
    printf '\033[%d;%dH' "$row" "$col"
}

# Hide/show cursor
hide_cursor() { printf '\033[?25l'; }
show_cursor() { printf '\033[?25h'; }

# Draw a horizontal line
draw_line() {
    local char="${1:-─}"
    local width="${2:-$TERM_WIDTH}"
    local color="${3:-$GRAY}"
    printf "${color}"
    printf '%*s' "$width" '' | tr ' ' "$char"
    printf "${NC}\n"
}

# Draw a box around text
draw_box() {
    local text="$1"
    local color="${2:-$CYAN}"
    local padding=2
    local text_len=${#text}
    local box_width=$((text_len + padding * 2 + 2))

    printf "${color}"
    printf "╭%*s╮\n" "$((box_width - 2))" '' | tr ' ' '─'
    printf "│%*s%s%*s│\n" "$padding" '' "$text" "$padding" ''
    printf "╰%*s╯\n" "$((box_width - 2))" '' | tr ' ' '─'
    printf "${NC}"
}

# Print centered text
print_centered() {
    local text="$1"
    local color="${2:-$NC}"
    local width="${3:-$TERM_WIDTH}"
    local text_len=${#text}
    local padding=$(( (width - text_len) / 2 ))
    printf "${color}%*s%s%*s${NC}\n" "$padding" '' "$text" "$padding" ''
}

# Print the main banner
print_banner() {
    clear_screen
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
    ║   ██╗  ██╗ █████╗ ██████╗ ██████╗ ███████╗███╗   ██╗██╗███╗   ██╗ ██████╗ ║
    ║   ██║  ██║██╔══██╗██╔══██╗██╔══██╗██╔════╝████╗  ██║██║████╗  ██║██╔════╝ ║
    ║   ███████║███████║██████╔╝██║  ██║█████╗  ██╔██╗ ██║██║██╔██╗ ██║██║  ███╗║
    ║   ██╔══██║██╔══██║██╔══██╗██║  ██║██╔══╝  ██║╚██╗██║██║██║╚██╗██║██║   ██║║
    ║   ██║  ██║██║  ██║██║  ██║██████╔╝███████╗██║ ╚████║██║██║ ╚████║╚██████╔╝║
    ║   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ║
    ║                                                                           ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
EOF
    printf "${NC}\n"
    print_centered "Bulletproof RHEL/Rocky/Alma Server Setup v${SCRIPT_VERSION}" "$WHITE"
    print_centered "Security Hardening & Configuration Tool" "$GRAY"
    printf "\n"
}

# Print section header
print_section() {
    local title="$1"
    local icon="${2:-$SYM_GEAR}"
    local step="${3:-}"

    printf "\n"
    draw_line "═" "$TERM_WIDTH" "$CYAN"
    if [[ -n "$step" ]]; then
        printf "${CYAN}║${NC} ${icon} ${WHITE}${BOLD}STEP ${step}/${TOTAL_STEPS}: ${title}${NC}\n"
    else
        printf "${CYAN}║${NC} ${icon} ${WHITE}${BOLD}${title}${NC}\n"
    fi
    draw_line "═" "$TERM_WIDTH" "$CYAN"
    printf "\n"
}

# Print sub-section header
print_subsection() {
    local title="$1"
    printf "\n${BLUE}┌─ ${WHITE}${title}${NC}\n"
}

# Print module completion
print_module_complete() {
    local module="$1"
    printf "\n${GREEN}${SYM_CHECK} ${module} completed successfully${NC}\n"
}

# Print module skipped
print_module_skipped() {
    local module="$1"
    printf "\n${YELLOW}${SYM_ARROW} ${module} skipped${NC}\n"
}

# =============================================================================
# PROGRESS BAR
# =============================================================================

# Draw a progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width="${3:-50}"
    local label="${4:-Progress}"

    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))

    printf "\r${CYAN}${label}${NC} ["
    printf "${GREEN}%*s${NC}" "$filled" '' | tr ' ' '█'
    printf "${GRAY}%*s${NC}" "$empty" '' | tr ' ' '░'
    printf "] ${WHITE}%3d%%${NC}" "$percentage"
}

# Spinner animation
spinner() {
    local pid=$1
    local message="${2:-Processing}"
    local spin_chars='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    hide_cursor
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${CYAN}${spin_chars:$i:1}${NC} ${message}..."
        i=$(( (i + 1) % ${#spin_chars} ))
        sleep 0.1
    done
    show_cursor
    printf "\r%*s\r" "$((${#message} + 5))" ''
}

# Animated dots while waiting
waiting_dots() {
    local message="$1"
    local duration="${2:-3}"
    local i=0

    while [[ $i -lt $((duration * 5)) ]]; do
        local dots=$(( (i % 4) ))
        printf "\r${CYAN}${message}%.*s   ${NC}" "$dots" "..."
        sleep 0.2
        ((i++))
    done
    printf "\r%*s\r" "$((${#message} + 6))" ''
}

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

# Initialize logging
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    exec 3>&1 4>&2
    log "=== Server Hardening Script v${SCRIPT_VERSION} started ==="
    log "Date: $(date)"
    log "User: $(whoami)"
    log "Host: $(hostname)"
}

# Log to file
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Log and print success
log_success() {
    local message="$1"
    log "[SUCCESS] $message"
    printf "${GREEN}${SYM_CHECK} ${message}${NC}\n"
}

# Log and print error
log_error() {
    local message="$1"
    log "[ERROR] $message"
    printf "${RED}${SYM_CROSS} ${message}${NC}\n"
}

# Log and print warning
log_warning() {
    local message="$1"
    log "[WARNING] $message"
    printf "${YELLOW}${SYM_WARN} ${message}${NC}\n"
}

# Log and print info
log_info() {
    local message="$1"
    log "[INFO] $message"
    printf "${CYAN}${SYM_INFO} ${message}${NC}\n"
}

# Print status item
print_status() {
    local label="$1"
    local value="$2"
    local status="${3:-info}"  # info, success, warning, error

    local color="$CYAN"
    case "$status" in
        success) color="$GREEN" ;;
        warning) color="$YELLOW" ;;
        error) color="$RED" ;;
    esac

    printf "  ${GRAY}${SYM_BULLET}${NC} %-25s ${color}%s${NC}\n" "$label:" "$value"
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

# Ask yes/no question with default
confirm() {
    local prompt="$1"
    local default="${2:-n}"

    if [[ "$SKIP_CONFIRMATIONS" == true ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
    fi

    local options
    if [[ "$default" == "y" ]]; then
        options="[Y/n]"
    else
        options="[y/N]"
    fi

    while true; do
        printf "${YELLOW}?${NC} ${prompt} ${GRAY}${options}${NC} "
        read -r response </dev/tty
        response=${response:-$default}

        case "${response,,}" in
            y|yes) return 0 ;;
            n|no) return 1 ;;
            *) printf "${RED}  Please answer yes or no${NC}\n" ;;
        esac
    done
}

# Ask for text input
ask_input() {
    local prompt="$1"
    local default="${2:-}"
    local is_secret="${3:-false}"
    local validation="${4:-}"

    local display_default=""
    if [[ -n "$default" ]] && [[ "$is_secret" != true ]]; then
        display_default=" ${GRAY}[${default}]${NC}"
    fi

    while true; do
        printf "${YELLOW}?${NC} ${prompt}${display_default}: " >/dev/tty

        if [[ "$is_secret" == true ]]; then
            read -rs response </dev/tty
            printf "\n" >/dev/tty
        else
            read -r response </dev/tty
        fi

        response="${response:-$default}"

        # Validate if validation function provided
        if [[ -n "$validation" ]]; then
            if ! $validation "$response" 2>/dev/tty; then
                continue
            fi
        fi

        echo "$response"
        return 0
    done
}

# Ask to choose from options
ask_choice() {
    local prompt="$1"
    shift
    local options=("$@")

    printf "${YELLOW}?${NC} ${prompt}\n" >/dev/tty

    local i=1
    for opt in "${options[@]}"; do
        printf "  ${CYAN}%d)${NC} %s\n" "$i" "$opt" >/dev/tty
        ((i++))
    done

    while true; do
        printf "${YELLOW}>${NC} Enter choice [1-${#options[@]}]: " >/dev/tty
        read -r choice </dev/tty

        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            echo "${options[$((choice-1))]}"
            return 0
        fi
        printf "${RED}  Invalid choice. Please try again.${NC}\n" >/dev/tty
    done
}

# Ask for multi-select from options
ask_multiselect() {
    local prompt="$1"
    shift
    local options=("$@")
    local selected=()

    printf "${YELLOW}?${NC} ${prompt}\n" >/dev/tty
    printf "  ${GRAY}(Enter numbers separated by spaces, or 'all' / 'none')${NC}\n" >/dev/tty

    local i=1
    for opt in "${options[@]}"; do
        printf "  ${CYAN}%d)${NC} %s\n" "$i" "$opt" >/dev/tty
        ((i++))
    done

    printf "${YELLOW}>${NC} Your choices: " >/dev/tty
    read -r choices </dev/tty

    if [[ "${choices,,}" == "all" ]]; then
        printf '%s\n' "${options[@]}"
        return 0
    elif [[ "${choices,,}" == "none" ]]; then
        return 0
    fi

    for choice in $choices; do
        if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#options[@]})); then
            echo "${options[$((choice-1))]}"
        fi
    done
}

# Pause and wait for enter
pause() {
    local message="${1:-Press Enter to continue...}"
    printf "\n${GRAY}${message}${NC}"
    read -r </dev/tty
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

validate_port() {
    local port="$1"
    if [[ "$port" =~ ^[0-9]+$ ]] && ((port >= 1 && port <= 65535)); then
        return 0
    fi
    printf "${RED}  Invalid port number. Must be between 1-65535${NC}\n" >/dev/tty
    return 1
}

validate_username() {
    local username="$1"
    if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] && ((${#username} <= 32)); then
        return 0
    fi
    printf "${RED}  Invalid username. Use lowercase letters, numbers, underscores, hyphens${NC}\n" >/dev/tty
    return 1
}

validate_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    printf "${RED}  Invalid IP address format${NC}\n" >/dev/tty
    return 1
}

validate_not_empty() {
    local value="$1"
    if [[ -n "$value" ]]; then
        return 0
    fi
    printf "${RED}  Value cannot be empty${NC}\n" >/dev/tty
    return 1
}

# =============================================================================
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
        OS_ID="${ID:-unknown}"
        OS_CODENAME="${VERSION_CODENAME:-${PLATFORM_ID:-}}"
    elif [[ -f /etc/redhat-release ]]; then
        OS_NAME=$(cat /etc/redhat-release)
        OS_VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
        OS_ID="rhel"
        OS_CODENAME=""
    else
        OS_NAME="Unknown"
        OS_VERSION="Unknown"
        OS_ID="unknown"
        OS_CODENAME=""
    fi
}

detect_connection() {
    # Detect if via SSH
    if [[ -n "${SSH_CLIENT:-}" ]] || [[ -n "${SSH_TTY:-}" ]]; then
        CONNECTION_TYPE="SSH"
        CONNECTION_IP=$(echo "${SSH_CLIENT:-}" | awk '{print $1}')
        CONNECTION_PORT=$(echo "${SSH_CLIENT:-}" | awk '{print $3}')
    else
        CONNECTION_TYPE="Local"
        CONNECTION_IP="N/A"
        CONNECTION_PORT="N/A"
    fi
}

detect_user_context() {
    CURRENT_USER=$(whoami)
    CURRENT_UID=$(id -u)

    # Try to detect real user (who invoked sudo)
    if [[ -n "${SUDO_USER:-}" ]]; then
        REAL_USER="$SUDO_USER"
    elif [[ -n "${LOGNAME:-}" && "${LOGNAME}" != "root" ]]; then
        REAL_USER="$LOGNAME"
    else
        # Fallback: check who owns the terminal
        REAL_USER=$(who am i 2>/dev/null | awk '{print $1}')
        [[ -z "$REAL_USER" ]] && REAL_USER=$(logname 2>/dev/null || echo "$CURRENT_USER")
    fi

    # Check if running as root
    if [[ $CURRENT_UID -eq 0 ]]; then
        IS_ROOT=true
        if [[ "$REAL_USER" != "root" && "$REAL_USER" != "$CURRENT_USER" ]]; then
            RUN_CONTEXT="sudo"
        else
            RUN_CONTEXT="root"
        fi
    else
        IS_ROOT=false
        RUN_CONTEXT="user"
    fi

    # Check for existing sudo users
    SUDO_USERS=$(grep -Po '^sudo.+:\K.*$' /etc/group 2>/dev/null | tr ',' '\n')
}

detect_ssh_config() {
    SSH_CONFIG="/etc/ssh/sshd_config"

    # Current SSH port
    CURRENT_SSH_PORT=$(grep -E "^Port " "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo "22")
    [[ -z "$CURRENT_SSH_PORT" ]] && CURRENT_SSH_PORT="22"

    # Password auth status
    if grep -qE "^PasswordAuthentication\s+no" "$SSH_CONFIG" 2>/dev/null; then
        SSH_PASSWORD_AUTH="disabled"
    else
        SSH_PASSWORD_AUTH="enabled"
    fi

    # Root login status
    if grep -qE "^PermitRootLogin\s+no" "$SSH_CONFIG" 2>/dev/null; then
        SSH_ROOT_LOGIN="disabled"
    else
        SSH_ROOT_LOGIN="enabled"
    fi
}

detect_firewall() {
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        FIREWALLD_STATUS="active"
    elif systemctl is-enabled --quiet firewalld 2>/dev/null; then
        FIREWALLD_STATUS="inactive"
    elif command -v firewall-cmd &>/dev/null; then
        FIREWALLD_STATUS="installed"
    else
        FIREWALLD_STATUS="not installed"
    fi

    if command -v nft &>/dev/null; then
        NFTABLES_INSTALLED=true
    else
        NFTABLES_INSTALLED=false
    fi
}

detect_selinux() {
    if command -v getenforce &>/dev/null; then
        SELINUX_STATUS=$(getenforce 2>/dev/null || echo "unknown")
    else
        SELINUX_STATUS="not installed"
    fi
}

detect_services() {
    # Check various services
    declare -gA SERVICE_STATUS

    local services=("sshd" "firewalld" "fail2ban" "docker" "nginx" "httpd")

    for svc in "${services[@]}"; do
        if systemctl is-active "$svc" &>/dev/null; then
            SERVICE_STATUS[$svc]="running"
        elif systemctl is-enabled "$svc" &>/dev/null; then
            SERVICE_STATUS[$svc]="stopped"
        else
            SERVICE_STATUS[$svc]="not installed"
        fi
    done
}

check_internet() {
    if ping -c 1 -W 3 8.8.8.8 &>/dev/null || ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
        INTERNET_STATUS="connected"
        return 0
    else
        INTERNET_STATUS="disconnected"
        return 1
    fi
}

# =============================================================================
# BACKUP FUNCTIONS
# =============================================================================

init_backup_dir() {
    mkdir -p "$BACKUP_DIR"
    log "Backup directory created: $BACKUP_DIR"
}

backup_file() {
    local file="$1"
    local backup_name="${2:-$(basename "$file")}"

    if [[ -f "$file" ]]; then
        cp "$file" "${BACKUP_DIR}/${backup_name}.bak"
        BACKUP_FILES+=("$file")
        log "Backed up: $file"
        return 0
    fi
    return 1
}

restore_file() {
    local file="$1"
    local backup_name="${2:-$(basename "$file")}"
    local backup_path="${BACKUP_DIR}/${backup_name}.bak"

    if [[ -f "$backup_path" ]]; then
        cp "$backup_path" "$file"
        log "Restored: $file"
        return 0
    fi
    return 1
}

# =============================================================================
# EXECUTION HELPERS
# =============================================================================

# Run command with logging
run_cmd() {
    local cmd="$*"

    if [[ "$DRY_RUN" == true ]]; then
        log "[DRY-RUN] Would execute: $cmd"
        printf "${GRAY}[DRY-RUN] %s${NC}\n" "$cmd"
        return 0
    fi

    log "[EXEC] $cmd"

    if eval "$cmd" >> "$LOG_FILE" 2>&1; then
        return 0
    else
        local exit_code=$?
        log "[FAILED] Command failed with exit code $exit_code"
        return $exit_code
    fi
}

# Run command with spinner
run_with_spinner() {
    local message="$1"
    shift
    local cmd="$*"

    if [[ "$DRY_RUN" == true ]]; then
        printf "${GRAY}[DRY-RUN] %s${NC}\n" "$cmd"
        return 0
    fi

    log "[EXEC] $cmd"

    eval "$cmd" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    spinner $pid "$message"

    wait $pid
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        printf "${GREEN}${SYM_CHECK}${NC} %s\n" "$message"
    else
        printf "${RED}${SYM_CROSS}${NC} %s ${RED}(failed)${NC}\n" "$message"
    fi

    return $exit_code
}

# Record a change made
record_change() {
    local change="$1"
    CHANGES_MADE+=("$change")
    log "[CHANGE] $change"
}

# =============================================================================
# MODULE: PRE-FLIGHT CHECKS
# =============================================================================

module_preflight() {
    print_section "PRE-FLIGHT CHECKS" "$SYM_ROCKET" "1"
    CURRENT_MODULE="Pre-flight Checks"

    # Run all detection functions
    printf "${CYAN}Analyzing system...${NC}\n\n"

    detect_os
    detect_connection
    detect_user_context
    detect_ssh_config
    detect_firewall
    detect_selinux
    detect_services
    check_internet

    # Display system information
    print_subsection "System Information"
    print_status "Operating System" "$OS_NAME $OS_VERSION"
    print_status "Hostname" "$(hostname)"
    print_status "Kernel" "$(uname -r)"
    print_status "Architecture" "$(uname -m)"
    print_status "Package Manager" "$PKG_MGR"

    print_subsection "Connection Details"
    print_status "Connection Type" "$CONNECTION_TYPE"
    if [[ "$CONNECTION_TYPE" == "SSH" ]]; then
        print_status "Client IP" "$CONNECTION_IP"
        print_status "SSH Port" "$CURRENT_SSH_PORT"
    fi
    print_status "Internet" "$INTERNET_STATUS" $([ "$INTERNET_STATUS" == "connected" ] && echo "success" || echo "error")

    print_subsection "User Context"
    print_status "Current User" "$CURRENT_USER"
    print_status "Real User" "$REAL_USER"
    print_status "Running As" "$RUN_CONTEXT"
    print_status "Is Root" "$IS_ROOT"

    print_subsection "Current Security Status"
    print_status "SSH Port" "$CURRENT_SSH_PORT"
    print_status "SSH Password Auth" "$SSH_PASSWORD_AUTH" $([ "$SSH_PASSWORD_AUTH" == "disabled" ] && echo "success" || echo "warning")
    print_status "SSH Root Login" "$SSH_ROOT_LOGIN" $([ "$SSH_ROOT_LOGIN" == "disabled" ] && echo "success" || echo "warning")
    print_status "Firewall (firewalld)" "$FIREWALLD_STATUS" $([ "$FIREWALLD_STATUS" == "active" ] && echo "success" || echo "warning")
    print_status "SELinux" "$SELINUX_STATUS" $([ "$SELINUX_STATUS" == "Enforcing" ] && echo "success" || echo "warning")

    if [[ -n "$SUDO_USERS" ]]; then
        print_status "Wheel Users" "$(echo $SUDO_USERS | tr '\n' ', ')"
    else
        print_status "Wheel Users" "none found" "warning"
    fi

    # Warnings
    printf "\n"

    if [[ "$IS_ROOT" != true ]]; then
        log_error "This script must be run as root or with sudo"
        printf "\n${YELLOW}Run with: ${WHITE}sudo $0${NC}\n"
        exit 1
    fi

    if [[ "$CONNECTION_TYPE" == "SSH" ]]; then
        printf "${BG_YELLOW}${WHITE} ${SYM_WARN} WARNING ${NC}\n"
        printf "${YELLOW}You are connected via SSH. Incorrect configuration could lock you out!${NC}\n"
        printf "${YELLOW}This script includes safety measures, but please be careful.${NC}\n"
        printf "\n"
    fi

    if [[ "$INTERNET_STATUS" != "connected" ]]; then
        log_warning "No internet connection detected. Some features may not work."
    fi

    # Check for RHEL-based distro
    case "$OS_ID" in
        rocky|almalinux|centos|rhel|fedora)
            log_success "Detected $OS_NAME - compatible RHEL-based distribution"
            ;;
        *)
            log_warning "This script is designed for RHEL-based systems. Detected: $OS_NAME"
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
            ;;
    esac

    print_module_complete "Pre-flight Checks"
    MODULE_STATUS["preflight"]="complete"

    pause
}

# =============================================================================
# MODULE: USER MANAGEMENT
# =============================================================================

module_user_management() {
    print_section "USER MANAGEMENT" "$SYM_USER" "2"
    CURRENT_MODULE="User Management"

    if ! confirm "Configure user management?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["user_management"]="skipped"
        return 0
    fi

    print_subsection "Current User Situation"

    # Analyze current state
    local has_sudo_user=false
    local sudo_user_list=""

    if [[ -n "$SUDO_USERS" ]]; then
        has_sudo_user=true
        sudo_user_list="$SUDO_USERS"
        log_info "Found existing sudo users: $sudo_user_list"
    fi

    # Option to create new user
    if confirm "Create a new admin user?"; then
        local new_username
        new_username=$(ask_input "Enter username for new admin user" "" false validate_username)

        if id "$new_username" &>/dev/null; then
            log_warning "User '$new_username' already exists"
            if confirm "Add existing user '$new_username' to wheel group?"; then
                run_cmd "usermod -aG wheel '$new_username'"
                record_change "Added user '$new_username' to wheel group"
                log_success "User '$new_username' added to wheel group"
            fi
        else
            if confirm "Create user '$new_username' with sudo privileges?"; then
                run_cmd "adduser --gecos '' '$new_username'"
                run_cmd "usermod -aG wheel '$new_username'"
                record_change "Created user '$new_username' with sudo privileges"
                log_success "User '$new_username' created"
            fi
        fi
    fi

    # SSH Key setup
    print_subsection "SSH Key Authentication"

    if confirm "Setup SSH key authentication for a user?"; then
        # Get list of users
        local users_list
        users_list=$(awk -F: '$3 >= 1000 && $3 < 65534 {print $1}' /etc/passwd | tr '\n' ' ')

        printf "${CYAN}Available users:${NC} $users_list\n"
        local target_user
        target_user=$(ask_input "Enter username to configure SSH key for" "$REAL_USER" false validate_not_empty)

        if ! id "$target_user" &>/dev/null; then
            log_error "User '$target_user' does not exist"
        else
            local user_home
            user_home=$(eval echo ~"$target_user")
            local ssh_dir="${user_home}/.ssh"
            local auth_keys="${ssh_dir}/authorized_keys"

            # Create .ssh directory if needed
            if [[ ! -d "$ssh_dir" ]]; then
                run_cmd "mkdir -p '$ssh_dir'"
                run_cmd "chmod 700 '$ssh_dir'"
                run_cmd "chown '$target_user:$target_user' '$ssh_dir'"
            fi

            local key_choice
            key_choice=$(ask_choice "How would you like to add SSH key?" \
                "Paste existing public key" \
                "Generate new keypair" \
                "Skip SSH key setup")

            case "$key_choice" in
                "Paste existing public key")
                    printf "${CYAN}Paste your public key (ssh-rsa ... or ssh-ed25519 ...):${NC}\n"
                    read -r pub_key

                    if [[ "$pub_key" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
                        echo "$pub_key" >> "$auth_keys"
                        run_cmd "chmod 600 '$auth_keys'"
                        run_cmd "chown '$target_user:$target_user' '$auth_keys'"
                        record_change "Added SSH public key for user '$target_user'"
                        log_success "SSH key added successfully"
                    else
                        log_error "Invalid public key format"
                    fi
                    ;;

                "Generate new keypair")
                    local key_type
                    key_type=$(ask_choice "Select key type" "ed25519 (recommended)" "rsa (4096 bit)")

                    local key_file="${ssh_dir}/id_generated"

                    if [[ "$key_type" == *"ed25519"* ]]; then
                        run_cmd "ssh-keygen -t ed25519 -f '$key_file' -N '' -C '${target_user}@$(hostname)'"
                    else
                        run_cmd "ssh-keygen -t rsa -b 4096 -f '$key_file' -N '' -C '${target_user}@$(hostname)'"
                    fi

                    # Add public key to authorized_keys
                    cat "${key_file}.pub" >> "$auth_keys"
                    run_cmd "chmod 600 '$auth_keys'"
                    run_cmd "chown '$target_user:$target_user' '$auth_keys' '$key_file' '${key_file}.pub'"

                    printf "\n${BG_RED}${WHITE} IMPORTANT - SAVE THIS PRIVATE KEY ${NC}\n"
                    printf "${RED}This will only be shown once!${NC}\n\n"
                    draw_line "─" 60 "$YELLOW"
                    cat "$key_file"
                    draw_line "─" 60 "$YELLOW"
                    printf "\n"

                    record_change "Generated SSH keypair for user '$target_user'"
                    log_success "SSH keypair generated"

                    pause "Press Enter after saving the private key..."

                    # Option to delete private key from server
                    if confirm "Delete private key from server? (Recommended if you saved it)"; then
                        rm -f "$key_file"
                        log_info "Private key deleted from server"
                    fi
                    ;;

                "Skip SSH key setup")
                    log_info "SSH key setup skipped"
                    ;;
            esac
        fi
    fi

    # Disable root login
    print_subsection "Root Account Security"

    # Check if there's at least one sudo user
    local sudo_count
    sudo_count=$(grep -Po '^sudo.+:\K.*$' /etc/group 2>/dev/null | tr ',' '\n' | wc -l)

    if [[ $sudo_count -gt 0 ]]; then
        if confirm "Lock root password? (sudo users can still use 'sudo -i')"; then
            run_cmd "passwd -l root"
            record_change "Locked root password"
            log_success "Root password locked"
        fi
    else
        log_warning "No sudo users found. Skipping root lock to prevent lockout."
    fi

    print_module_complete "User Management"
    MODULE_STATUS["user_management"]="complete"

    pause
}

# =============================================================================
# MODULE: SSH HARDENING
# =============================================================================

module_ssh_hardening() {
    print_section "SSH HARDENING" "$SYM_KEY" "3"
    CURRENT_MODULE="SSH Hardening"

    if ! confirm "Configure SSH hardening?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["ssh_hardening"]="skipped"
        return 0
    fi

    # Backup SSH config
    backup_file "/etc/ssh/sshd_config" "sshd_config"

    local ssh_config="/etc/ssh/sshd_config"
    local changes_pending=()

    # SSH Port
    print_subsection "SSH Port Configuration"
    printf "${CYAN}Current SSH port:${NC} $CURRENT_SSH_PORT\n"

    if confirm "Change SSH port?"; then
        local new_port
        new_port=$(ask_input "Enter new SSH port" "2222" false validate_port)

        if [[ "$new_port" != "$CURRENT_SSH_PORT" ]]; then
            changes_pending+=("Port $new_port")
            log_info "SSH port will change from $CURRENT_SSH_PORT to $new_port"
        fi
    fi

    # Password Authentication
    print_subsection "Authentication Methods"
    printf "${CYAN}Current password auth:${NC} $SSH_PASSWORD_AUTH\n"

    if [[ "$SSH_PASSWORD_AUTH" == "enabled" ]]; then
        printf "\n${YELLOW}${SYM_WARN} Before disabling password authentication:${NC}\n"
        printf "  ${SYM_BULLET} Ensure you have SSH key access configured\n"
        printf "  ${SYM_BULLET} Test key login in another terminal first\n"
        printf "\n"

        if confirm "Disable password authentication? (SSH keys only)"; then
            changes_pending+=("PasswordAuthentication no")
        fi
    else
        log_info "Password authentication already disabled"
    fi

    # Root Login
    print_subsection "Root Login"
    printf "${CYAN}Current root login:${NC} $SSH_ROOT_LOGIN\n"

    if [[ "$SSH_ROOT_LOGIN" == "enabled" ]]; then
        if confirm "Disable SSH root login?"; then
            changes_pending+=("PermitRootLogin no")
        fi
    else
        log_info "Root login already disabled"
    fi

    # Additional hardening
    print_subsection "Additional SSH Hardening"

    if confirm "Apply additional SSH hardening settings?"; then
        local hardening_options=(
            "MaxAuthTries 3"
            "ClientAliveInterval 300"
            "ClientAliveCountMax 2"
            "LoginGraceTime 60"
            "X11Forwarding no"
            "PermitEmptyPasswords no"
            "StrictModes yes"
            "IgnoreRhosts yes"
            "HostbasedAuthentication no"
        )

        printf "\n${CYAN}The following settings will be applied:${NC}\n"
        for opt in "${hardening_options[@]}"; do
            printf "  ${SYM_BULLET} ${opt}\n"
            changes_pending+=("$opt")
        done
        printf "\n"
    fi

    # AllowUsers
    if confirm "Configure AllowUsers whitelist?"; then
        printf "${CYAN}Enter usernames allowed to SSH (space-separated):${NC}\n"
        local allowed_users
        allowed_users=$(ask_input "Users" "$REAL_USER" false validate_not_empty)
        changes_pending+=("AllowUsers $allowed_users")
    fi

    # Apply changes
    if [[ ${#changes_pending[@]} -gt 0 ]]; then
        print_subsection "Review Changes"
        printf "${CYAN}The following changes will be applied to SSH config:${NC}\n\n"
        for change in "${changes_pending[@]}"; do
            printf "  ${GREEN}${SYM_CHECK}${NC} $change\n"
        done
        printf "\n"

        if confirm "Apply these SSH changes?"; then
            # Apply each setting - update in place or add if missing
            for setting in "${changes_pending[@]}"; do
                local key=$(echo "$setting" | cut -d' ' -f1)
                local value=$(echo "$setting" | cut -d' ' -f2-)

                # Check if key exists (commented or not)
                if grep -qE "^#?\s*${key}\s" "$ssh_config"; then
                    # Replace existing line (whether commented or not)
                    sed -i "s/^#*\s*${key}\s.*/${key} ${value}/" "$ssh_config"
                else
                    # Add new setting at end
                    echo "$setting" >> "$ssh_config"
                fi

                log "Applied SSH setting: $setting"
            done

            # Test SSH config
            printf "\n${CYAN}Testing SSH configuration...${NC}\n"
            if sshd -t -f "$ssh_config" 2>/dev/null; then
                log_success "SSH configuration test passed"

                # Safety for port change
                local new_port_setting=""
                for s in "${changes_pending[@]}"; do
                    if [[ "$s" =~ ^Port ]]; then
                        new_port_setting=$(echo "$s" | cut -d' ' -f2)
                    fi
                done

                if [[ -n "$new_port_setting" ]] && [[ "$new_port_setting" != "$CURRENT_SSH_PORT" ]]; then
                    printf "\n${BG_YELLOW}${WHITE} SSH PORT CHANGE WARNING ${NC}\n"
                    printf "${YELLOW}SSH port will change from ${CURRENT_SSH_PORT} to ${new_port_setting}${NC}\n"
                    printf "${YELLOW}After reload, connect using:${NC}\n"
                    printf "  ${WHITE}ssh -p ${new_port_setting} user@host${NC}\n\n"

                    # If firewall is active, add new port
                    if [[ "$FIREWALLD_STATUS" == "active" ]]; then
                        run_cmd "firewall-cmd --permanent --add-port=${new_port_setting}/tcp"
                        run_cmd "firewall-cmd --reload"
                        log_info "Added firewall rule for new SSH port"
                    fi
                fi

                if confirm "Reload SSH service now?"; then
                    run_cmd "systemctl reload sshd"
                    record_change "SSH hardening applied"
                    log_success "SSH service reloaded"

                    printf "\n${GREEN}${SYM_CHECK} SSH hardening complete!${NC}\n"

                    if [[ -n "$new_port_setting" ]]; then
                        printf "\n${YELLOW}IMPORTANT: Your current session remains active.${NC}\n"
                        printf "${YELLOW}Test new connection in another terminal before disconnecting!${NC}\n"
                    fi
                fi
            else
                log_error "SSH configuration test failed! Reverting..."
                restore_file "/etc/ssh/sshd_config" "sshd_config"
                log_info "Original SSH config restored"
            fi
        fi
    else
        log_info "No SSH changes to apply"
    fi

    print_module_complete "SSH Hardening"
    MODULE_STATUS["ssh_hardening"]="complete"

    pause
}

# =============================================================================
# MODULE: FIREWALL (firewalld)
# =============================================================================

module_firewall() {
    print_section "FIREWALL CONFIGURATION" "$SYM_SHIELD" "4"
    CURRENT_MODULE="Firewall"

    if ! confirm "Configure firewall (firewalld)?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["firewall"]="skipped"
        return 0
    fi

    # Install firewalld if needed
    if ! command -v firewall-cmd &>/dev/null; then
        if confirm "firewalld is not installed. Install it?"; then
            run_with_spinner "Installing firewalld" "$PKG_MGR install -y firewalld"
            run_cmd "systemctl enable firewalld"
            run_cmd "systemctl start firewalld"
            FIREWALLD_STATUS="active"
        else
            print_module_skipped "$CURRENT_MODULE"
            MODULE_STATUS["firewall"]="skipped"
            return 0
        fi
    fi

    # Enable and start firewalld if not running
    if ! systemctl is-active --quiet firewalld; then
        run_cmd "systemctl enable firewalld"
        run_cmd "systemctl start firewalld"
        FIREWALLD_STATUS="active"
    fi

    # Current status
    print_subsection "Current Firewall Status"
    printf "${CYAN}firewalld Status:${NC} $FIREWALLD_STATUS\n\n"

    printf "${CYAN}Active zone:${NC}\n"
    firewall-cmd --get-active-zones

    printf "\n${CYAN}Current rules:${NC}\n"
    firewall-cmd --list-all

    # Reset or configure
    local configure_mode
    if [[ "$FIREWALLD_STATUS" == "active" ]]; then
        configure_mode=$(ask_choice "firewalld is already active. What would you like to do?" \
            "Add rules to existing config" \
            "Reset and reconfigure" \
            "Skip firewall configuration")

        if [[ "$configure_mode" == "Skip firewall configuration" ]]; then
            print_module_skipped "$CURRENT_MODULE"
            MODULE_STATUS["firewall"]="skipped"
            return 0
        fi

        if [[ "$configure_mode" == "Reset and reconfigure" ]]; then
            if confirm "This will reset firewall to defaults. Continue?"; then
                # Remove all custom rules from public zone
                for port in $(firewall-cmd --zone=public --list-ports); do
                    firewall-cmd --permanent --zone=public --remove-port="$port"
                done
                for svc in $(firewall-cmd --zone=public --list-services); do
                    if [[ "$svc" != "ssh" ]] && [[ "$svc" != "dhcpv6-client" ]]; then
                        firewall-cmd --permanent --zone=public --remove-service="$svc"
                    fi
                done
                firewall-cmd --reload
                log_info "Firewall reset to defaults"
            fi
        fi
    fi

    # SSH Port (CRITICAL)
    print_subsection "SSH Access (Required)"

    # Detect current SSH port
    local ssh_port
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    ssh_port="${ssh_port:-22}"

    printf "${YELLOW}${SYM_WARN} SSH access is required to prevent lockout${NC}\n"
    printf "${CYAN}Detected SSH port:${NC} $ssh_port\n\n"

    local confirm_ssh_port
    confirm_ssh_port=$(ask_input "Confirm SSH port to allow" "$ssh_port" false validate_port)

    if [[ "$confirm_ssh_port" == "22" ]]; then
        run_cmd "firewall-cmd --permanent --add-service=ssh"
    else
        run_cmd "firewall-cmd --permanent --add-port=${confirm_ssh_port}/tcp"
        # Update SELinux if needed
        if [[ "$SELINUX_STATUS" == "Enforcing" ]] && command -v semanage &>/dev/null; then
            run_cmd "semanage port -a -t ssh_port_t -p tcp $confirm_ssh_port" || true
        fi
    fi
    log_success "SSH port $confirm_ssh_port allowed"
    record_change "Firewall: Allowed SSH port $confirm_ssh_port"

    # Common ports
    print_subsection "Common Services"

    if confirm "Allow HTTP (port 80)?"; then
        run_cmd "firewall-cmd --permanent --add-service=http"
        record_change "Firewall: Allowed HTTP"
        log_success "HTTP allowed"
    fi

    if confirm "Allow HTTPS (port 443)?"; then
        run_cmd "firewall-cmd --permanent --add-service=https"
        record_change "Firewall: Allowed HTTPS"
        log_success "HTTPS allowed"
    fi

    # Custom ports
    print_subsection "Custom Ports"

    if confirm "Add custom port rules?"; then
        while true; do
            local port_input
            port_input=$(ask_input "Enter port (or 'done' to finish)" "done" false)

            if [[ "$port_input" == "done" ]]; then
                break
            fi

            if ! validate_port "$port_input"; then
                continue
            fi

            local protocol
            protocol=$(ask_choice "Protocol for port $port_input" "tcp" "udp" "both")

            case "$protocol" in
                tcp)
                    run_cmd "firewall-cmd --permanent --add-port=${port_input}/tcp"
                    ;;
                udp)
                    run_cmd "firewall-cmd --permanent --add-port=${port_input}/udp"
                    ;;
                both)
                    run_cmd "firewall-cmd --permanent --add-port=${port_input}/tcp"
                    run_cmd "firewall-cmd --permanent --add-port=${port_input}/udp"
                    ;;
            esac

            record_change "Firewall: Allowed port $port_input/$protocol"
            log_success "Port $port_input/$protocol allowed"
        done
    fi

    # Apply changes
    print_subsection "Apply Changes"

    run_cmd "firewall-cmd --reload"
    record_change "Firewall rules applied"
    log_success "Firewall rules reloaded"

    # Enable logging
    if confirm "Enable firewall logging for denied packets?"; then
        run_cmd "firewall-cmd --set-log-denied=all"
        log_success "Firewall logging enabled"
    fi

    # Show final status
    printf "\n${CYAN}Final firewall status:${NC}\n"
    firewall-cmd --list-all

    print_module_complete "Firewall"
    MODULE_STATUS["firewall"]="complete"

    pause
}

# =============================================================================
# MODULE: FAIL2BAN
# =============================================================================

module_fail2ban() {
    print_section "FAIL2BAN CONFIGURATION" "$SYM_LOCK" "5"
    CURRENT_MODULE="Fail2ban"

    if ! confirm "Configure Fail2ban (intrusion prevention)?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["fail2ban"]="skipped"
        return 0
    fi

    # Install fail2ban if needed
    if ! command -v fail2ban-client &>/dev/null; then
        if confirm "Fail2ban is not installed. Install it?"; then
            # EPEL is required for fail2ban on RHEL
            if ! rpm -q epel-release &>/dev/null; then
                run_with_spinner "Installing EPEL repository" "$PKG_MGR install -y epel-release"
            fi
            run_with_spinner "Installing Fail2ban" "$PKG_MGR install -y fail2ban fail2ban-firewalld"
        else
            print_module_skipped "$CURRENT_MODULE"
            MODULE_STATUS["fail2ban"]="skipped"
            return 0
        fi
    fi

    # Backup existing config
    if [[ -f /etc/fail2ban/jail.local ]]; then
        backup_file "/etc/fail2ban/jail.local" "fail2ban_jail.local"
    fi

    # Get SSH port
    local ssh_port
    ssh_port=$(grep -E "^Port " /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
    ssh_port="${ssh_port:-22}"

    print_subsection "Jail Configuration"

    # Ban time
    printf "${CYAN}Configure ban settings:${NC}\n\n"

    local ban_time
    ban_time=$(ask_choice "Select ban time for offending IPs" \
        "10 minutes" \
        "1 hour" \
        "24 hours" \
        "1 week" \
        "permanent")

    local ban_seconds
    case "$ban_time" in
        "10 minutes") ban_seconds="600" ;;
        "1 hour") ban_seconds="3600" ;;
        "24 hours") ban_seconds="86400" ;;
        "1 week") ban_seconds="604800" ;;
        "permanent") ban_seconds="-1" ;;
    esac

    # Max retry
    local max_retry
    max_retry=$(ask_input "Max authentication failures before ban" "5" false validate_not_empty)

    # Find time
    local find_time
    find_time=$(ask_input "Time window for failures (seconds)" "600" false validate_not_empty)

    # Create jail.local
    print_subsection "Creating Configuration"

    cat > /etc/fail2ban/jail.local << EOF
# Fail2ban configuration
# Generated by Server Hardening Script v${SCRIPT_VERSION}
# Date: $(date)

[DEFAULT]
bantime = ${ban_seconds}
findtime = ${find_time}
maxretry = ${max_retry}
banaction = firewallcmd-rich-rules[actiontype=<multiport>]
banaction_allports = firewallcmd-rich-rules[actiontype=<allports>]

# Email notifications (optional)
#destemail = admin@example.com
#sender = fail2ban@example.com
#mta = sendmail
#action = %(action_mwl)s

[sshd]
enabled = true
port = ${ssh_port}
filter = sshd
logpath = /var/log/secure
maxretry = 3

[sshd-ddos]
enabled = true
port = ${ssh_port}
filter = sshd-ddos
logpath = /var/log/secure
maxretry = 10
EOF

    log_success "Fail2ban jail.local created"

    # Create sshd-ddos filter if not exists
    if [[ ! -f /etc/fail2ban/filter.d/sshd-ddos.conf ]]; then
        cat > /etc/fail2ban/filter.d/sshd-ddos.conf << 'EOF'
[Definition]
failregex = ^.*sshd.*: (Connection closed|Connection reset|Did not receive identification string) .* \[preauth\]$
ignoreregex =
EOF
        log_success "sshd-ddos filter created"
    fi

    # Additional jails
    print_subsection "Additional Jails"

    if confirm "Enable Nginx jails? (if Nginx is installed)"; then
        cat >> /etc/fail2ban/jail.local << 'EOF'

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 2

[nginx-noproxy]
enabled = true
port = http,https
filter = nginx-noproxy
logpath = /var/log/nginx/error.log
maxretry = 2
EOF
        log_info "Nginx jails added"
    fi

    # Start fail2ban
    print_subsection "Starting Fail2ban"

    run_with_spinner "Starting Fail2ban service" "systemctl restart fail2ban"
    run_cmd "systemctl enable fail2ban"

    record_change "Fail2ban configured and enabled"

    # Show status
    printf "\n${CYAN}Fail2ban Status:${NC}\n"
    fail2ban-client status 2>/dev/null

    print_module_complete "Fail2ban"
    MODULE_STATUS["fail2ban"]="complete"

    pause
}

# =============================================================================
# MODULE: SELINUX
# =============================================================================

module_selinux() {
    print_section "SELINUX CONFIGURATION" "$SYM_SHIELD" "6"
    CURRENT_MODULE="SELinux"

    if ! confirm "Configure SELinux?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["selinux"]="skipped"
        return 0
    fi

    print_subsection "Current SELinux Status"
    print_status "SELinux Mode" "$SELINUX_STATUS"

    case "$SELINUX_STATUS" in
        Enforcing)
            log_info "SELinux is already in Enforcing mode (recommended)"
            ;;
        Permissive)
            if confirm "SELinux is in Permissive mode. Switch to Enforcing?"; then
                run_cmd "setenforce 1"
                sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                record_change "Set SELinux to Enforcing mode"
                log_success "SELinux set to Enforcing"
                SELINUX_STATUS="Enforcing"
            fi
            ;;
        Disabled)
            log_warning "SELinux is disabled. Enabling requires a reboot."
            if confirm "Enable SELinux? (will be Permissive until reboot, then Enforcing)"; then
                sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
                record_change "Enabled SELinux (requires reboot)"
                log_warning "SELinux enabled. Reboot required to activate."
            fi
            ;;
        *)
            log_warning "Could not determine SELinux status"
            ;;
    esac

    # Install SELinux tools if needed
    print_subsection "SELinux Management Tools"

    if ! command -v semanage &>/dev/null; then
        if confirm "Install SELinux management tools (policycoreutils-python-utils)?"; then
            run_with_spinner "Installing SELinux tools" "$PKG_MGR install -y policycoreutils-python-utils"
            record_change "Installed SELinux management tools"
        fi
    else
        log_info "SELinux management tools already installed"
    fi

    # Install setroubleshoot for troubleshooting
    if ! command -v sealert &>/dev/null; then
        if confirm "Install SELinux troubleshooting tools (setroubleshoot)?"; then
            run_with_spinner "Installing setroubleshoot" "$PKG_MGR install -y setroubleshoot-server"
            record_change "Installed SELinux troubleshooting tools"
        fi
    fi

    # Show SELinux booleans for common services
    print_subsection "Common SELinux Booleans"

    if confirm "Review and configure common SELinux booleans?"; then
        printf "${CYAN}Current settings for common services:${NC}\n\n"

        # HTTP related
        if getsebool httpd_can_network_connect &>/dev/null; then
            local httpd_network=$(getsebool httpd_can_network_connect | awk '{print $3}')
            print_status "httpd_can_network_connect" "$httpd_network"
        fi

        if getsebool httpd_can_network_connect_db &>/dev/null; then
            local httpd_db=$(getsebool httpd_can_network_connect_db | awk '{print $3}')
            print_status "httpd_can_network_connect_db" "$httpd_db"
        fi

        printf "\n"

        if confirm "Allow HTTPD to make network connections? (needed for reverse proxy)"; then
            run_cmd "setsebool -P httpd_can_network_connect on"
            record_change "Enabled httpd_can_network_connect"
            log_success "httpd_can_network_connect enabled"
        fi

        if confirm "Allow HTTPD to connect to databases?"; then
            run_cmd "setsebool -P httpd_can_network_connect_db on"
            record_change "Enabled httpd_can_network_connect_db"
            log_success "httpd_can_network_connect_db enabled"
        fi
    fi

    print_module_complete "SELinux"
    MODULE_STATUS["selinux"]="complete"

    pause
}

# =============================================================================
# MODULE: SYSTEM CLEANUP
# =============================================================================

module_cleanup() {
    print_section "SYSTEM CLEANUP" "$SYM_FOLDER" "7"
    CURRENT_MODULE="System Cleanup"

    if ! confirm "Perform system cleanup?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["cleanup"]="skipped"
        return 0
    fi

    # Remove old Docker
    print_subsection "Old Docker Removal"

    local old_docker="docker docker-engine docker-common containerd runc docker-compose podman podman-docker"
    local found_docker=false

    for pkg in $old_docker; do
        if rpm -q "$pkg" &>/dev/null; then
            found_docker=true
            printf "${YELLOW}Found:${NC} $pkg\n"
        fi
    done

    if [[ "$found_docker" == true ]]; then
        if confirm "Remove old Docker packages?"; then
            run_cmd "systemctl stop docker" || true
            run_cmd "systemctl stop containerd" || true
            run_with_spinner "Removing old Docker" "$PKG_MGR remove -y $old_docker"
            run_cmd "$PKG_MGR autoremove -y"
            rm -rf /var/lib/docker /var/lib/containerd /etc/docker 2>/dev/null

            record_change "Removed old Docker packages"
            log_success "Old Docker removed"
        fi
    else
        log_info "No old Docker packages found"
    fi

    # Remove old Node.js
    print_subsection "Old Node.js Removal"

    if rpm -q nodejs &>/dev/null; then
        local node_ver
        node_ver=$(node --version 2>/dev/null || echo "unknown")
        printf "${YELLOW}Found Node.js:${NC} $node_ver\n"

        if confirm "Remove system Node.js?"; then
            run_with_spinner "Removing Node.js" "$PKG_MGR remove -y nodejs npm"
            run_cmd "$PKG_MGR autoremove -y"
            rm -rf /usr/local/lib/node_modules 2>/dev/null
            rm -f /usr/local/bin/node /usr/local/bin/npm /usr/local/bin/npx 2>/dev/null

            record_change "Removed old Node.js"
            log_success "Node.js removed"
        fi
    else
        log_info "No system Node.js found"
    fi

    # Remove cloud-init
    print_subsection "Cloud-init Removal"

    if rpm -q cloud-init &>/dev/null; then
        printf "${YELLOW}Found:${NC} cloud-init is installed\n"
        printf "${DIM}Cloud-init is used for initial VM provisioning but is no longer needed${NC}\n\n"

        if confirm "Remove cloud-init?"; then
            # Disable cloud-init first
            run_cmd "touch /etc/cloud/cloud-init.disabled" || true

            # Stop services
            run_cmd "systemctl stop cloud-init" || true
            run_cmd "systemctl stop cloud-config" || true
            run_cmd "systemctl stop cloud-final" || true

            # Remove package
            run_with_spinner "Removing cloud-init" "$PKG_MGR remove -y cloud-init"
            run_cmd "$PKG_MGR autoremove -y"

            # Clean directories
            rm -rf /etc/cloud /var/lib/cloud 2>/dev/null

            record_change "Removed cloud-init"
            log_success "Cloud-init removed"
        fi
    else
        log_info "Cloud-init is not installed"
    fi

    # Remove RHEL subscription/cockpit bloat
    print_subsection "Optional Services Removal"

    local bloat_pkgs=""
    local bloat_found=false

    # Check for each package - these are optional services often not needed on VPS
    for pkg in subscription-manager insights-client cockpit; do
        if rpm -q "$pkg" &>/dev/null; then
            bloat_pkgs="$bloat_pkgs $pkg"
            bloat_found=true
            printf "${YELLOW}Found:${NC} $pkg\n"
        fi
    done

    if [[ "$bloat_found" == true ]]; then
        printf "\n${DIM}These packages provide subscription management or web admin (may not be needed on VPS)${NC}\n\n"

        if confirm "Remove optional service packages?"; then
            run_with_spinner "Removing optional packages" "$PKG_MGR remove -y $bloat_pkgs"
            run_cmd "$PKG_MGR autoremove -y"

            record_change "Removed optional service packages"
            log_success "Optional packages removed"
        fi
    else
        log_info "No optional bloat packages found"
    fi

    # Remove dnf-automatic (if we want manual control)
    print_subsection "Automatic Updates Service"

    if rpm -q dnf-automatic &>/dev/null || systemctl is-active --quiet dnf-automatic.timer 2>/dev/null; then
        printf "${YELLOW}Found:${NC} dnf-automatic\n"
        printf "${DIM}Auto-updates can break things unexpectedly. Manual updates give you control.${NC}\n\n"

        if confirm "Disable and remove dnf-automatic?"; then
            run_cmd "systemctl stop dnf-automatic.timer" || true
            run_cmd "systemctl disable dnf-automatic.timer" || true
            run_with_spinner "Removing dnf-automatic" "$PKG_MGR remove -y dnf-automatic"
            run_cmd "$PKG_MGR autoremove -y"

            record_change "Removed dnf-automatic"
            log_success "dnf-automatic removed"
        fi
    else
        log_info "dnf-automatic is not installed"
    fi

    # Install custom MOTD
    print_subsection "Custom MOTD"

    printf "${DIM}Install a clean, informative MOTD showing system stats${NC}\n\n"

    if confirm "Install custom MOTD?"; then
        # Install figlet if not present (for ASCII banner)
        if ! command -v figlet &>/dev/null; then
            dnf install -y figlet >/dev/null 2>&1 || yum install -y figlet >/dev/null 2>&1 || true
        fi

        # Create profile.d script for MOTD (RHEL way)
        cat > /etc/profile.d/motd.sh << 'MOTDEOF'
#!/bin/bash

# Only show MOTD for interactive SSH sessions
[[ -z "$SSH_TTY" ]] && return

# Colors
C='\033[0;36m'    # Cyan
G='\033[0;32m'    # Green
Y='\033[1;33m'    # Yellow
R='\033[0;31m'    # Red
W='\033[1;37m'    # White
D='\033[0;90m'    # Dim
B='\033[1m'       # Bold
NC='\033[0m'      # No Color

# Box width
WIDTH=96

# Progress bar function
progress_bar() {
    local pct=$1
    local width=20
    local filled=$((pct * width / 100))
    local empty=$((width - filled))
    local color="$G"
    [[ $pct -ge 70 ]] && color="$Y"
    [[ $pct -ge 90 ]] && color="$R"
    printf "${color}["
    printf '█%.0s' $(seq 1 $filled 2>/dev/null) 2>/dev/null || true
    printf '░%.0s' $(seq 1 $empty 2>/dev/null) 2>/dev/null || true
    printf "]${NC}"
}

# Get system info
HOSTNAME=$(hostname)
OS=$(cat /etc/redhat-release 2>/dev/null || grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
KERNEL=$(uname -r)
UPTIME=$(uptime -p 2>/dev/null | sed 's/up //' || echo "unknown")

# CPU
CPU_CORES=$(nproc 2>/dev/null || echo 1)
CPU_LOAD=$(awk '{printf "%.0f", $1 * 100 / '"$CPU_CORES"'}' /proc/loadavg 2>/dev/null || echo 0)
[[ $CPU_LOAD -gt 100 ]] && CPU_LOAD=100

# Memory
MEM_TOTAL=$(free -m 2>/dev/null | awk '/^Mem:/{print $2}' || echo 1)
MEM_USED=$(free -m 2>/dev/null | awk '/^Mem:/{print $3}' || echo 0)
MEM_PERCENT=$((MEM_USED * 100 / MEM_TOTAL))
if [[ $MEM_TOTAL -ge 1024 ]]; then
    MEM_TOTAL_FMT=$(awk "BEGIN {printf \"%.1fGB\", $MEM_TOTAL/1024}")
    MEM_USED_FMT=$(awk "BEGIN {printf \"%.1fGB\", $MEM_USED/1024}")
else
    MEM_TOTAL_FMT="${MEM_TOTAL}MB"
    MEM_USED_FMT="${MEM_USED}MB"
fi

# Swap
SWAP_TOTAL=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}' || echo 0)
SWAP_USED=$(free -m 2>/dev/null | awk '/^Swap:/{print $3}' || echo 0)
if [[ $SWAP_TOTAL -gt 0 ]]; then
    SWAP_PERCENT=$((SWAP_USED * 100 / SWAP_TOTAL))
    if [[ $SWAP_TOTAL -ge 1024 ]]; then
        SWAP_TOTAL_FMT=$(awk "BEGIN {printf \"%.1fGB\", $SWAP_TOTAL/1024}")
        SWAP_USED_FMT=$(awk "BEGIN {printf \"%.1fGB\", $SWAP_USED/1024}")
    else
        SWAP_TOTAL_FMT="${SWAP_TOTAL}MB"
        SWAP_USED_FMT="${SWAP_USED}MB"
    fi
else
    SWAP_PERCENT=0
    SWAP_TOTAL_FMT="N/A"
    SWAP_USED_FMT="N/A"
fi

# Disk
DISK_TOTAL=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G",""); print $2}' || echo 1)
DISK_USED=$(df -BG / 2>/dev/null | awk 'NR==2{gsub("G",""); print $3}' || echo 0)
DISK_PERCENT=$(df / 2>/dev/null | awk 'NR==2{gsub("%",""); print $5}' || echo 0)

# Last login
LAST_LOGIN=$(last -1 2>/dev/null | head -1 | awk '{if(NF>=7) print $5" "$6" "$7" from "$3; else print "N/A"}')
[[ -z "$LAST_LOGIN" || "$LAST_LOGIN" == *"wtmp"* || "$LAST_LOGIN" == *"boot"* ]] && LAST_LOGIN="First login"

# Updates (RHEL uses dnf)
UPDATES="0"

echo ""

# ASCII Banner (figlet or fallback)
if command -v figlet &>/dev/null; then
    figlet -f slant "$HOSTNAME" 2>/dev/null | while read -r line; do
        printf "${C}%s${NC}\n" "$line"
    done
else
    printf "${C}${B}  %s${NC}\n" "$HOSTNAME"
fi

echo ""

# Top border
printf "${C}╔"
printf '═%.0s' $(seq 1 $((WIDTH-2)))
printf "╗${NC}\n"

# Calculate column widths
COL1=$((WIDTH / 2 - 2))
COL2=$((WIDTH - COL1 - 3))

# System | Network header
printf "${C}║${NC}  ${W}${B}SYSTEM${NC}%-*s${C}│${NC}  ${W}${B}NETWORK${NC}%-*s${C}║${NC}\n" $((COL1 - 8)) "" $((COL2 - 9)) ""

# Separator
printf "${C}╠"
printf '─%.0s' $(seq 1 $COL1)
printf "┼"
printf '─%.0s' $(seq 1 $COL2)
printf "╣${NC}\n"

# Collect network interfaces
NET_INFO=""
while read -r iface ip; do
    case "$iface" in
        lo) continue ;;
        wg*) type="vpn" ;;
        docker*|br-*|veth*) continue ;;
        *) type="public" ;;
    esac
    NET_INFO="${NET_INFO}${iface}|${ip}|${type}\n"
done < <(ip -4 -o addr show 2>/dev/null | awk '{print $2, $4}' | cut -d/ -f1)

# Convert to array
IFS=$'\n' read -d '' -ra NET_LINES < <(printf "$NET_INFO") || true

# Row 1: OS | Network 1
net_line=""
if [[ ${#NET_LINES[@]} -ge 1 ]]; then
    IFS='|' read -r n_iface n_ip n_type <<< "${NET_LINES[0]}"
    net_line=$(printf "%-10s %-16s %s" "$n_iface" "$n_ip" "$n_type")
fi
printf "${C}║${NC}  ${D}OS${NC}        %-*s${C}│${NC}  %-*s${C}║${NC}\n" $((COL1 - 12)) "$OS" $((COL2 - 3)) "$net_line"

# Row 2: Kernel | Network 2
net_line=""
if [[ ${#NET_LINES[@]} -ge 2 ]]; then
    IFS='|' read -r n_iface n_ip n_type <<< "${NET_LINES[1]}"
    net_line=$(printf "%-10s %-16s %s" "$n_iface" "$n_ip" "$n_type")
fi
printf "${C}║${NC}  ${D}Kernel${NC}    %-*s${C}│${NC}  %-*s${C}║${NC}\n" $((COL1 - 12)) "$KERNEL" $((COL2 - 3)) "$net_line"

# Row 3: Uptime | Network 3
net_line=""
if [[ ${#NET_LINES[@]} -ge 3 ]]; then
    IFS='|' read -r n_iface n_ip n_type <<< "${NET_LINES[2]}"
    net_line=$(printf "%-10s %-16s %s" "$n_iface" "$n_ip" "$n_type")
fi
printf "${C}║${NC}  ${D}Uptime${NC}    %-*s${C}│${NC}  %-*s${C}║${NC}\n" $((COL1 - 12)) "$UPTIME" $((COL2 - 3)) "$net_line"

# Separator for resources
printf "${C}╠"
printf '═%.0s' $(seq 1 $((WIDTH-2)))
printf "╣${NC}\n"

# Resources header
printf "${C}║${NC}  ${W}${B}RESOURCES${NC}%-*s${C}║${NC}\n" $((WIDTH - 13)) ""

# Separator
printf "${C}╠"
printf '─%.0s' $(seq 1 $((WIDTH-2)))
printf "╣${NC}\n"

# CPU
cpu_info=$(printf "%3d%%   %s cores" "$CPU_LOAD" "$CPU_CORES")
printf "${C}║${NC}  ${D}CPU${NC}       $(progress_bar $CPU_LOAD)  %-*s${C}║${NC}\n" $((WIDTH - 38)) "$cpu_info"

# Memory
mem_info=$(printf "%3d%%   %s / %s" "$MEM_PERCENT" "$MEM_USED_FMT" "$MEM_TOTAL_FMT")
printf "${C}║${NC}  ${D}Memory${NC}    $(progress_bar $MEM_PERCENT)  %-*s${C}║${NC}\n" $((WIDTH - 38)) "$mem_info"

# Disk
disk_info=$(printf "%3d%%   %sGB / %sGB" "$DISK_PERCENT" "$DISK_USED" "$DISK_TOTAL")
printf "${C}║${NC}  ${D}Disk${NC}      $(progress_bar $DISK_PERCENT)  %-*s${C}║${NC}\n" $((WIDTH - 38)) "$disk_info"

# Swap
if [[ "$SWAP_TOTAL_FMT" != "N/A" ]]; then
    swap_info=$(printf "%3d%%   %s / %s" "$SWAP_PERCENT" "$SWAP_USED_FMT" "$SWAP_TOTAL_FMT")
    printf "${C}║${NC}  ${D}Swap${NC}      $(progress_bar $SWAP_PERCENT)  %-*s${C}║${NC}\n" $((WIDTH - 38)) "$swap_info"
fi

# Footer separator
printf "${C}╠"
printf '─%.0s' $(seq 1 $((WIDTH-2)))
printf "╣${NC}\n"

# Footer: Last login | Updates
if [[ "$UPDATES" -gt 0 ]]; then
    footer_left=$(printf "Last login: %s" "$LAST_LOGIN")
    footer_right=$(printf "%s updates available" "$UPDATES")
    padding=$((WIDTH - 6 - ${#footer_left} - ${#footer_right}))
    printf "${C}║${NC}  ${D}%s${NC}%*s${Y}%s${NC}  ${C}║${NC}\n" "$footer_left" "$padding" "" "$footer_right"
else
    printf "${C}║${NC}  ${D}Last login:${NC} %-*s${C}║${NC}\n" $((WIDTH - 17)) "$LAST_LOGIN"
fi

# Bottom border
printf "${C}╚"
printf '═%.0s' $(seq 1 $((WIDTH-2)))
printf "╝${NC}\n"

echo ""
MOTDEOF

        chmod +x /etc/profile.d/motd.sh

        # Also update /etc/motd for non-interactive display
        echo "" > /etc/motd

        record_change "Installed custom MOTD"
        log_success "Custom MOTD installed"

        # Show preview
        printf "\n${CYAN}Preview:${NC}\n\n"
        SSH_TTY=1 source /etc/profile.d/motd.sh
    fi

    # Remove Multipathd
    print_subsection "Multipathd"

    if systemctl is-active --quiet multipathd 2>/dev/null || rpm -q device-mapper-multipath &>/dev/null; then
        printf "${YELLOW}Found:${NC} multipathd (multipath I/O daemon)\n"
        printf "${DIM}Only needed for SAN storage with multiple paths. Not used on VPS.${NC}\n\n"

        if confirm "Remove multipathd?"; then
            run_cmd "systemctl stop multipathd" || true
            run_cmd "systemctl disable multipathd" || true
            run_with_spinner "Removing device-mapper-multipath" "$PKG_MGR remove -y device-mapper-multipath"
            run_cmd "$PKG_MGR autoremove -y"

            record_change "Removed multipathd"
            log_success "Multipathd removed"
        fi
    else
        log_info "Multipathd is not installed"
    fi

    # Clean package cache
    print_subsection "Package Cache Cleanup"

    if confirm "Clean package cache and remove unused packages?"; then
        run_with_spinner "Cleaning package cache" "$PKG_MGR autoremove -y && $PKG_MGR clean all"
        record_change "Cleaned package cache"
        log_success "Package cache cleaned"
    fi

    print_module_complete "System Cleanup"
    MODULE_STATUS["cleanup"]="complete"

    pause
}

# =============================================================================
# MODULE: SOFTWARE INSTALLATION
# =============================================================================

module_software() {
    print_section "SOFTWARE INSTALLATION" "$SYM_GEAR" "8"
    CURRENT_MODULE="Software Installation"

    if ! confirm "Install software packages?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["software"]="skipped"
        return 0
    fi

    # Enable EPEL repository
    print_subsection "EPEL Repository"

    if ! rpm -q epel-release &>/dev/null; then
        if confirm "Enable EPEL repository (required for many packages)?"; then
            run_with_spinner "Installing EPEL repository" "$PKG_MGR install -y epel-release"
            run_cmd "$PKG_MGR makecache"
            record_change "Enabled EPEL repository"
            log_success "EPEL repository enabled"
        fi
    else
        log_info "EPEL repository already enabled"
    fi

    # Essential tools
    print_subsection "Essential Tools"

    local essential_tools=(
        "gcc"
        "gcc-c++"
        "make"
        "git"
        "curl"
        "wget"
        "ca-certificates"
        "gnupg2"
        "tar"
        "bzip2"
    )

    printf "${CYAN}Essential tools to install:${NC}\n"
    printf "  %s\n" "${essential_tools[@]}"
    printf "\n"

    if confirm "Install essential tools?"; then
        run_with_spinner "Updating package lists" "$PKG_MGR makecache"
        run_with_spinner "Installing essential tools" "$PKG_MGR install -y ${essential_tools[*]}"
        record_change "Installed essential tools"
        log_success "Essential tools installed"
    fi

    # System utilities
    print_subsection "System Utilities"

    local system_utils=(
        "htop"
        "iotop"
        "ncdu"
        "tree"
        "tmux"
        "vim-enhanced"
        "nano"
        "unzip"
        "zip"
        "jq"
        "net-tools"
        "bind-utils"
        "traceroute"
        "mtr"
        "sysstat"
    )

    printf "${CYAN}System utilities available:${NC}\n"
    printf "  %s\n" "${system_utils[@]}"
    printf "\n"

    if confirm "Install all system utilities?"; then
        run_with_spinner "Installing system utilities" "$PKG_MGR install -y ${system_utils[*]}"
        record_change "Installed system utilities"
        log_success "System utilities installed"
    fi

    # Docker
    print_subsection "Docker CE"

    local install_docker=false

    if command -v docker &>/dev/null; then
        printf "${CYAN}Docker already installed:${NC} $(docker --version)\n"
        if confirm "Reinstall Docker?"; then
            run_with_spinner "Removing old Docker" \
                "$PKG_MGR remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true"
            install_docker=true
        else
            log_info "Keeping existing Docker installation"
        fi
    else
        if confirm "Install Docker CE?"; then
            install_docker=true
        fi
    fi

    if [[ "$install_docker" == true ]]; then
        # Detect RHEL variant for repo URL
        local docker_repo_os="rhel"
        if [[ -f /etc/centos-release ]] || grep -qi "centos" /etc/os-release 2>/dev/null; then
            docker_repo_os="centos"
        elif grep -qi "fedora" /etc/os-release 2>/dev/null; then
            docker_repo_os="fedora"
        fi

        run_with_spinner "Adding Docker repository" \
            "$PKG_MGR config-manager --add-repo https://download.docker.com/linux/${docker_repo_os}/docker-ce.repo"

        run_with_spinner "Installing Docker CE" \
            "$PKG_MGR install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin"

        run_cmd "systemctl start docker"
        run_cmd "systemctl enable docker"

        # Add user to docker group
        if [[ -n "${SUDO_USER:-}" ]]; then
            run_cmd "usermod -aG docker ${SUDO_USER}"
            log_info "Added ${SUDO_USER} to docker group"
        fi

        record_change "Installed Docker CE"
        log_success "Docker installed: $(docker --version)"
    fi

    # Node.js
    print_subsection "Node.js LTS"

    if command -v node &>/dev/null; then
        printf "${CYAN}Node.js already installed:${NC} $(node --version)\n"
    fi

    if confirm "Install Node.js LTS?"; then
        run_with_spinner "Setting up NodeSource repository" \
            "curl -fsSL https://rpm.nodesource.com/setup_lts.x | bash -"

        run_with_spinner "Installing Node.js" "$PKG_MGR install -y nodejs"

        record_change "Installed Node.js LTS"
        log_success "Node.js installed: $(node --version)"

        if confirm "Install Yarn package manager?"; then
            run_with_spinner "Installing Yarn" "npm install -g yarn"
            log_success "Yarn installed"
        fi

        if confirm "Install PM2 process manager?"; then
            run_with_spinner "Installing PM2" "npm install -g pm2"
            log_success "PM2 installed"
        fi
    fi

    # Optional: Go
    print_subsection "Go Language (Optional)"

    if confirm "Install Go (latest)?"; then
        local go_version
        go_version=$(curl -sL https://go.dev/VERSION?m=text | head -1)

        run_with_spinner "Downloading Go ${go_version}" \
            "wget -q https://go.dev/dl/${go_version}.linux-amd64.tar.gz -O /tmp/go.tar.gz"

        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz

        # Add to path
        echo 'export PATH=$PATH:/usr/local/go/bin' > /etc/profile.d/go.sh

        record_change "Installed Go ${go_version}"
        log_success "Go installed: ${go_version}"
    fi

    print_module_complete "Software Installation"
    MODULE_STATUS["software"]="complete"

    pause
}

# =============================================================================
# MODULE: KERNEL HARDENING
# =============================================================================

module_kernel() {
    print_section "KERNEL HARDENING" "$SYM_SHIELD" "9"
    CURRENT_MODULE="Kernel Hardening"

    if ! confirm "Apply kernel hardening?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["kernel"]="skipped"
        return 0
    fi

    # Backup sysctl.conf
    backup_file "/etc/sysctl.conf" "sysctl.conf"

    print_subsection "Network Security"

    local sysctl_settings=""

    # IP Spoofing protection
    if confirm "Enable IP spoofing protection?"; then
        sysctl_settings+="
# IP Spoofing protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1"
    fi

    # ICMP redirects
    if confirm "Disable ICMP redirects?"; then
        sysctl_settings+="
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0"
    fi

    # Source routing
    if confirm "Disable source packet routing?"; then
        sysctl_settings+="
# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0"
    fi

    # SYN flood protection
    if confirm "Enable SYN flood protection?"; then
        sysctl_settings+="
# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 5
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_max_syn_backlog = 4096"
    fi

    # Log martians
    if confirm "Enable logging of suspicious packets?"; then
        sysctl_settings+="
# Log Martians (suspicious packets)
net.ipv4.conf.all.log_martians = 1"
    fi

    # ICMP broadcasts
    if confirm "Ignore ICMP broadcasts?"; then
        sysctl_settings+="
# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1"
    fi

    print_subsection "IPv6 Configuration"

    if confirm "Disable IPv6? (if not needed)"; then
        sysctl_settings+="
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1"
    fi

    print_subsection "Memory & Limits"

    if confirm "Increase system limits? (file descriptors, ports)"; then
        sysctl_settings+="
# Increase file descriptor limit
fs.file-max = 65535

# Increase ephemeral port range
net.ipv4.ip_local_port_range = 10000 65000

# Memory settings
kernel.randomize_va_space = 2"
    fi

    # Apply settings
    if [[ -n "$sysctl_settings" ]]; then
        print_subsection "Applying Settings"

        # Add header
        local header="
# =============================================================================
# Security Hardening - Added by Server Hardening Script v${SCRIPT_VERSION}
# Date: $(date)
# =============================================================================
"
        echo "$header$sysctl_settings" >> /etc/sysctl.conf

        # Apply
        if run_cmd "sysctl -p"; then
            record_change "Applied kernel hardening settings"
            log_success "Kernel settings applied"
        else
            log_warning "Some settings may not have applied. Check log for details."
        fi
    fi

    # Secure shared memory
    print_subsection "Shared Memory Security"

    if confirm "Secure shared memory (/run/shm)?"; then
        if ! grep -q "/run/shm" /etc/fstab; then
            echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
            record_change "Secured shared memory"
            log_success "Shared memory secured"
        else
            log_info "Shared memory already configured"
        fi
    fi

    print_module_complete "Kernel Hardening"
    MODULE_STATUS["kernel"]="complete"

    pause
}

# =============================================================================
# MODULE: AUTOMATIC UPDATES
# =============================================================================

module_auto_updates() {
    print_section "AUTOMATIC UPDATES" "$SYM_CLOCK" "10"
    CURRENT_MODULE="Automatic Updates"

    if ! confirm "Configure automatic security updates?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["auto_updates"]="skipped"
        return 0
    fi

    # Install dnf-automatic
    if ! rpm -q dnf-automatic &>/dev/null; then
        run_with_spinner "Installing dnf-automatic" "$PKG_MGR install -y dnf-automatic"
    fi

    print_subsection "Update Configuration"

    # Update type
    local update_type
    update_type=$(ask_choice "What should be auto-updated?" \
        "Security updates only (recommended)" \
        "All updates" \
        "Disabled")

    # Backup original config
    backup_file "/etc/dnf/automatic.conf" "dnf-automatic.conf"

    # Create config based on choice
    case "$update_type" in
        "Security updates only (recommended)")
            cat > /etc/dnf/automatic.conf << 'EOF'
[commands]
# What kind of upgrade to perform:
# default                            = all available upgrades
# security                           = only security upgrades
upgrade_type = security
random_sleep = 0

# Whether to reboot when required
# skip_reboot = no

# Maximum time in seconds to wait for the system lock
download_updates = yes
apply_updates = yes

[emitters]
# How to send messages
emit_via = stdio

[email]
# Email configuration (optional)
# email_from = root@localhost
# email_to = root
# email_host = localhost

[command]
# Command to run on update

[command_email]
# Command to run on email send

[base]
# This section overrides dnf.conf
EOF
            ;;
        "All updates")
            cat > /etc/dnf/automatic.conf << 'EOF'
[commands]
# What kind of upgrade to perform:
# default                            = all available upgrades
# security                           = only security upgrades
upgrade_type = default
random_sleep = 0

# Whether to reboot when required
# skip_reboot = no

# Maximum time in seconds to wait for the system lock
download_updates = yes
apply_updates = yes

[emitters]
# How to send messages
emit_via = stdio

[email]
# Email configuration (optional)
# email_from = root@localhost
# email_to = root
# email_host = localhost

[command]
# Command to run on update

[command_email]
# Command to run on email send

[base]
# This section overrides dnf.conf
EOF
            ;;
        "Disabled")
            print_module_skipped "$CURRENT_MODULE"
            MODULE_STATUS["auto_updates"]="skipped"
            return 0
            ;;
    esac

    # Auto-reboot
    print_subsection "Automatic Reboot"

    if confirm "Enable automatic reboot when required? (e.g., kernel updates)"; then
        local reboot_time
        reboot_time=$(ask_input "Reboot time (24h format, e.g., 03:00)" "03:00" false validate_not_empty)

        # Add reboot configuration
        sed -i 's/# skip_reboot = no/reboot = when-needed/' /etc/dnf/automatic.conf

        # Create a systemd timer override for reboot timing
        mkdir -p /etc/systemd/system/dnf-automatic.timer.d
        cat > /etc/systemd/system/dnf-automatic.timer.d/override.conf << EOF
[Timer]
OnCalendar=
OnCalendar=*-*-* ${reboot_time}:00
EOF
        run_cmd "systemctl daemon-reload"
        log_info "Auto-reboot enabled at ${reboot_time}"
    fi

    # Enable the dnf-automatic timer
    run_cmd "systemctl enable dnf-automatic.timer"
    run_cmd "systemctl start dnf-automatic.timer"

    record_change "Configured automatic updates with dnf-automatic"
    log_success "Automatic updates configured"

    print_module_complete "Automatic Updates"
    MODULE_STATUS["auto_updates"]="complete"

    pause
}

# =============================================================================
# MODULE: ADDITIONAL SECURITY
# =============================================================================

module_security_extras() {
    print_section "ADDITIONAL SECURITY" "$SYM_SHIELD" "11"
    CURRENT_MODULE="Additional Security"

    if ! confirm "Configure additional security measures?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["security_extras"]="skipped"
        return 0
    fi

    # Security tools
    print_subsection "Security Tools"

    printf "${CYAN}Available security tools:${NC}\n\n"
    printf "  ${SYM_BULLET} ${WHITE}lynis${NC} - Security auditing (on-demand, no overhead)\n"
    printf "  ${SYM_BULLET} ${WHITE}rkhunter${NC} - Rootkit scanner (on-demand)\n"
    printf "  ${SYM_BULLET} ${WHITE}chkrootkit${NC} - Rootkit checker (on-demand)\n"
    printf "  ${SYM_BULLET} ${WHITE}auditd${NC} - System audit daemon (low overhead)\n"
    printf "  ${SYM_BULLET} ${YELLOW}AIDE${NC} - File integrity (HIGH I/O during scans)\n"
    printf "  ${SYM_BULLET} ${YELLOW}ClamAV${NC} - Antivirus (HIGH RAM ~1GB when active)\n"
    printf "\n"

    if confirm "Install lynis (security auditing tool)?"; then
        run_with_spinner "Installing lynis" "$PKG_MGR install -y lynis"
        log_success "lynis installed"
    fi

    if confirm "Install rkhunter (rootkit scanner)?"; then
        run_with_spinner "Installing rkhunter" "$PKG_MGR install -y rkhunter"
        run_cmd "rkhunter --propupd" || true
        log_success "rkhunter installed"
    fi

    if confirm "Install chkrootkit?"; then
        run_with_spinner "Installing chkrootkit" "$PKG_MGR install -y chkrootkit"
        log_success "chkrootkit installed"
    fi

    if confirm "Install auditd (system auditing)?"; then
        run_with_spinner "Installing auditd" "$PKG_MGR install -y auditd"
        run_cmd "systemctl enable auditd"
        log_success "auditd installed"
    fi

    printf "\n${YELLOW}${SYM_WARN} High resource tools:${NC}\n\n"

    if confirm "Install AIDE? (file integrity - warning: high I/O during scans)"; then
        run_with_spinner "Installing AIDE" "$PKG_MGR install -y aide"
        log_warning "AIDE installed. Initialize with: aideinit (takes time)"
    fi

    if confirm "Install ClamAV? (warning: uses ~1GB RAM when daemon active)"; then
        run_with_spinner "Installing ClamAV" "$PKG_MGR install -y clamav clamav-daemon"
        log_warning "ClamAV installed. Consider disabling clamd daemon if RAM is limited."
    fi

    # Disable unused services
    print_subsection "Disable Unused Services"

    local services_to_check=("cups" "avahi-daemon" "bluetooth" "ModemManager")
    local services_found=()

    for svc in "${services_to_check[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            services_found+=("$svc")
        fi
    done

    if [[ ${#services_found[@]} -gt 0 ]]; then
        printf "${CYAN}The following services are enabled but often unnecessary on servers:${NC}\n"
        for svc in "${services_found[@]}"; do
            printf "  ${SYM_BULLET} $svc\n"
        done
        printf "\n"

        for svc in "${services_found[@]}"; do
            if confirm "Disable $svc?"; then
                run_cmd "systemctl stop $svc" || true
                run_cmd "systemctl disable $svc" || true
                record_change "Disabled service: $svc"
                log_success "Disabled $svc"
            fi
        done
    else
        log_info "No unnecessary services found"
    fi

    # USB storage
    print_subsection "USB Storage"

    if confirm "Disable USB storage? (recommended for servers without USB needs)"; then
        echo "blacklist usb-storage" > /etc/modprobe.d/disable-usb-storage.conf
        record_change "Disabled USB storage"
        log_success "USB storage disabled"
    fi

    # File permissions
    print_subsection "File Permission Hardening"

    if confirm "Apply strict file permissions to sensitive files?"; then
        run_cmd "chmod 700 /root"
        run_cmd "chmod 600 /etc/ssh/sshd_config"
        run_cmd "chmod 644 /etc/passwd"
        run_cmd "chmod 600 /etc/shadow"
        run_cmd "chmod 600 /etc/gshadow"

        record_change "Applied strict file permissions"
        log_success "File permissions hardened"
    fi

    print_module_complete "Additional Security"
    MODULE_STATUS["security_extras"]="complete"

    pause
}

# =============================================================================
# MODULE: DISK MANAGEMENT
# =============================================================================

module_disk() {
    print_section "DISK MANAGEMENT" "$SYM_DISK" "12"
    CURRENT_MODULE="Disk Management"

    if ! confirm "Check disk management options?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["disk"]="skipped"
        return 0
    fi

    # Show current disk usage
    print_subsection "Current Disk Usage"

    printf "${CYAN}Filesystem usage:${NC}\n"
    df -h | grep -E '^/dev/' | awk '{printf "  %-30s %8s / %8s (%s)\n", $6, $3, $2, $5}'
    printf "\n"

    # Check for LVM
    if command -v vgs &>/dev/null && vgs --noheadings 2>/dev/null | grep -q .; then
        print_subsection "LVM Detected"

        printf "${CYAN}Volume Groups:${NC}\n"
        vgs 2>/dev/null
        printf "\n"

        printf "${CYAN}Logical Volumes:${NC}\n"
        lvs 2>/dev/null
        printf "\n"

        if confirm "Attempt to extend LVM volumes with any free space?"; then
            # Rescan for new space
            run_with_spinner "Rescanning disk devices" "
                for host in /sys/class/scsi_host/host*/scan; do
                    echo '- - -' > \"\$host\" 2>/dev/null || true
                done
                for device in /sys/class/scsi_device/*/device/rescan; do
                    echo 1 > \"\$device\" 2>/dev/null || true
                done
                partprobe 2>/dev/null || true
            "

            # Try to extend
            local pv_devices
            pv_devices=$(pvs --noheadings -o pv_name 2>/dev/null | tr -d ' ')

            for pv in $pv_devices; do
                if [[ $pv =~ ^(/dev/[a-z]+)([0-9]+)$ ]]; then
                    local base_dev="${BASH_REMATCH[1]}"
                    local part_num="${BASH_REMATCH[2]}"

                    if command -v growpart &>/dev/null; then
                        if growpart "$base_dev" "$part_num" 2>/dev/null; then
                            log_success "Extended partition $pv"
                            run_cmd "pvresize $pv"
                        fi
                    fi
                fi
            done

            # Extend logical volumes
            local lv_list
            lv_list=$(lvs --noheadings -o lv_path 2>/dev/null)

            for lv in $lv_list; do
                if lvextend -l +100%FREE "$lv" 2>/dev/null; then
                    resize2fs "$lv" 2>/dev/null || xfs_growfs "$lv" 2>/dev/null
                    log_success "Extended $lv"
                fi
            done

            # Show new usage
            printf "\n${CYAN}Updated disk usage:${NC}\n"
            df -h | grep -E '^/dev/' | awk '{printf "  %-30s %8s / %8s (%s)\n", $6, $3, $2, $5}'
        fi
    fi

    print_module_complete "Disk Management"
    MODULE_STATUS["disk"]="complete"

    pause
}

# =============================================================================
# MODULE: DATE & TIMEZONE
# =============================================================================

module_datetime() {
    print_section "DATE & TIMEZONE" "$SYM_CLOCK" "13"
    CURRENT_MODULE="Date & Timezone"

    if ! confirm "Configure date and timezone?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["datetime"]="skipped"
        return 0
    fi

    # Show current settings
    print_subsection "Current Settings"
    local current_tz current_date current_ntp
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
    current_date=$(date '+%Y-%m-%d %H:%M:%S %Z')
    current_ntp=$(timedatectl show --property=NTP --value 2>/dev/null || echo "Unknown")

    printf "  ${WHITE}Timezone:${NC}    %s\n" "$current_tz"
    printf "  ${WHITE}Date/Time:${NC}   %s\n" "$current_date"
    printf "  ${WHITE}NTP Sync:${NC}    %s\n" "$current_ntp"
    printf "\n"

    # Configure timezone
    if confirm "Change timezone?"; then
        print_subsection "Select Timezone"

        # Common timezones
        local timezones=(
            "UTC"
            "Europe/London"
            "Europe/Paris"
            "Europe/Berlin"
            "Europe/Amsterdam"
            "Europe/Riga"
            "Europe/Moscow"
            "America/New_York"
            "America/Chicago"
            "America/Denver"
            "America/Los_Angeles"
            "Asia/Tokyo"
            "Asia/Shanghai"
            "Asia/Singapore"
            "Australia/Sydney"
        )

        printf "${CYAN}Common timezones:${NC}\n"
        for i in "${!timezones[@]}"; do
            printf "  ${WHITE}[%2d]${NC} %s\n" "$((i+1))" "${timezones[$i]}"
        done
        printf "  ${WHITE}[%2d]${NC} Enter custom timezone\n" "$((${#timezones[@]}+1))"
        printf "\n"

        printf "${YELLOW}>${NC} Select timezone [1-%d]: " "$((${#timezones[@]}+1))"
        read -r tz_choice </dev/tty

        local new_tz=""
        if [[ "$tz_choice" =~ ^[0-9]+$ ]]; then
            if [[ "$tz_choice" -ge 1 && "$tz_choice" -le "${#timezones[@]}" ]]; then
                new_tz="${timezones[$((tz_choice-1))]}"
            elif [[ "$tz_choice" -eq "$((${#timezones[@]}+1))" ]]; then
                printf "${YELLOW}>${NC} Enter timezone (e.g., Europe/Berlin): "
                read -r new_tz </dev/tty
            fi
        fi

        if [[ -n "$new_tz" ]]; then
            # Validate timezone
            if [[ -f "/usr/share/zoneinfo/$new_tz" ]]; then
                timedatectl set-timezone "$new_tz"
                log_success "Timezone set to $new_tz"
            else
                log_error "Invalid timezone: $new_tz"
            fi
        fi
    fi

    # Time synchronization options
    print_subsection "Time Synchronization"
    printf "${CYAN}Options:${NC}\n"
    printf "  ${WHITE}[1]${NC} Enable NTP and sync now (automatic)\n"
    printf "  ${WHITE}[2]${NC} Disable NTP (manual time management)\n"
    printf "  ${WHITE}[3]${NC} Skip (keep current settings)\n"
    printf "\n"

    printf "${YELLOW}>${NC} Select option [1-3]: "
    read -r time_choice </dev/tty

    case "$time_choice" in
        1)
            # RHEL uses chronyd for NTP
            if systemctl list-unit-files chronyd.service &>/dev/null; then
                systemctl enable --now chronyd 2>/dev/null
                # Force immediate sync with chrony
                chronyc -a makestep &>/dev/null || true
                log_success "Chrony NTP enabled and time synchronized"
            else
                # Fallback to timedatectl
                timedatectl set-ntp false 2>/dev/null
                timedatectl set-ntp true
                log_success "NTP synchronization enabled"
            fi
            ;;
        2)
            if systemctl is-active chronyd &>/dev/null; then
                systemctl stop chronyd
                systemctl disable chronyd
                log_success "Chrony NTP synchronization disabled"
            else
                timedatectl set-ntp false
                log_success "NTP synchronization disabled"
            fi
            ;;
        3|"")
            log_info "Keeping current time settings"
            ;;
        *)
            log_warning "Invalid option, keeping current settings"
            ;;
    esac

    # Show updated settings
    print_subsection "Updated Settings"
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "Unknown")
    current_date=$(date '+%Y-%m-%d %H:%M:%S %Z')
    current_ntp=$(timedatectl show --property=NTP --value 2>/dev/null || echo "Unknown")

    printf "  ${WHITE}Timezone:${NC}    %s\n" "$current_tz"
    printf "  ${WHITE}Date/Time:${NC}   %s\n" "$current_date"
    printf "  ${WHITE}NTP Sync:${NC}    %s\n" "$current_ntp"
    printf "\n"

    print_module_complete "Date & Timezone"
    MODULE_STATUS["datetime"]="complete"

    pause
}

# =============================================================================
# MODULE: SYSTEM UPDATE
# =============================================================================

module_system_update() {
    print_section "SYSTEM UPDATE" "$SYM_ROCKET" "14"
    CURRENT_MODULE="System Update"

    if ! confirm "Update system packages?"; then
        print_module_skipped "$CURRENT_MODULE"
        MODULE_STATUS["system_update"]="skipped"
        return 0
    fi

    run_with_spinner "Updating package lists" "$PKG_MGR makecache"
    run_with_spinner "Upgrading packages" "$PKG_MGR upgrade -y"

    if confirm "Perform distribution upgrade? (may include kernel updates)"; then
        run_with_spinner "Distribution upgrade" "$PKG_MGR distro-sync -y"
    fi

    run_with_spinner "Removing unused packages" "$PKG_MGR autoremove -y"
    run_with_spinner "Cleaning package cache" "$PKG_MGR clean all"

    record_change "System updated"
    log_success "System update complete"

    print_module_complete "System Update"
    MODULE_STATUS["system_update"]="complete"

    pause
}

# =============================================================================
# MODULE: POST-SETUP
# =============================================================================

module_post_setup() {
    print_section "SETUP COMPLETE" "$SYM_PARTY" "14"
    CURRENT_MODULE="Post Setup"

    # Summary of changes
    print_subsection "Changes Made"

    if [[ ${#CHANGES_MADE[@]} -gt 0 ]]; then
        for change in "${CHANGES_MADE[@]}"; do
            printf "  ${GREEN}${SYM_CHECK}${NC} %s\n" "$change"
        done
    else
        printf "  ${GRAY}No changes were made${NC}\n"
    fi

    # Module status
    print_subsection "Module Status"

    for module in preflight user_management ssh_hardening firewall fail2ban selinux cleanup software kernel auto_updates security_extras disk system_update; do
        local status="${MODULE_STATUS[$module]:-not run}"
        local color="$GRAY"
        local symbol="$SYM_BULLET"

        case "$status" in
            complete) color="$GREEN"; symbol="$SYM_CHECK" ;;
            skipped) color="$YELLOW"; symbol="$SYM_ARROW" ;;
            error) color="$RED"; symbol="$SYM_CROSS" ;;
        esac

        printf "  ${color}${symbol}${NC} %-20s ${color}%s${NC}\n" "$module" "$status"
    done

    # Backup location
    print_subsection "Backups"
    printf "  ${SYM_FOLDER} Backup directory: ${CYAN}%s${NC}\n" "$BACKUP_DIR"
    printf "  ${SYM_FOLDER} Log file: ${CYAN}%s${NC}\n" "$LOG_FILE"

    # Security recommendations
    print_subsection "Next Steps"

    printf "  ${SYM_BULLET} Test SSH access in a new terminal before disconnecting\n"
    printf "  ${SYM_BULLET} Review firewall rules: ${CYAN}firewall-cmd --list-all${NC}\n"
    printf "  ${SYM_BULLET} Check SELinux status: ${CYAN}getenforce${NC}\n"
    printf "  ${SYM_BULLET} Run security audit: ${CYAN}lynis audit system${NC}\n"
    printf "  ${SYM_BULLET} Check fail2ban status: ${CYAN}fail2ban-client status${NC}\n"
    printf "  ${SYM_BULLET} Review logs: ${CYAN}cat %s${NC}\n" "$LOG_FILE"

    # Reboot prompt
    printf "\n"
    draw_line "─" "$TERM_WIDTH" "$CYAN"

    if confirm "Reboot system now? (recommended if kernel was updated)"; then
        printf "\n${YELLOW}System will reboot in 5 seconds...${NC}\n"
        sleep 5
        reboot
    fi

    printf "\n${GREEN}${SYM_PARTY} Server hardening complete! ${SYM_PARTY}${NC}\n\n"

    MODULE_STATUS["post_setup"]="complete"
}

# =============================================================================
# MAIN MENU
# =============================================================================

show_main_menu() {
    print_banner

    printf "${CYAN}╔═══════════════════════════════════════════════════════════════════════════╗${NC}\n"
    printf "${CYAN}║${NC}                           ${WHITE}${BOLD}MAIN MENU${NC}                                       ${CYAN}║${NC}\n"
    printf "${CYAN}╠═══════════════════════════════════════════════════════════════════════════╣${NC}\n"
    printf "${CYAN}║${NC}                                                                           ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[1]${NC} ${SYM_ROCKET} ${GREEN}Quick Setup${NC} - Run all modules interactively                   ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}                                                                           ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[2]${NC} ${SYM_USER} User Management                                                ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[3]${NC} ${SYM_KEY} SSH Hardening                                                  ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[4]${NC} ${SYM_SHIELD} Firewall (firewalld)                                           ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[5]${NC} ${SYM_LOCK} Fail2ban                                                       ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[6]${NC} ${SYM_SHIELD} SELinux                                                        ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[7]${NC} ${SYM_FOLDER} System Cleanup                                                 ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[8]${NC} ${SYM_GEAR} Software Installation                                          ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[9]${NC} ${SYM_SHIELD} Kernel Hardening                                               ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[10]${NC} ${SYM_CLOCK} Automatic Updates                                              ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[11]${NC} ${SYM_LOCK} Additional Security                                            ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[12]${NC} ${SYM_DISK} Disk Management                                                ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[13]${NC} ${SYM_CLOCK} Date & Timezone                                                ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[14]${NC} ${SYM_ROCKET} System Update                                                  ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}                                                                           ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[15]${NC} ${SYM_INFO} System Status                                                  ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}  ${WHITE}[16]${NC} ${SYM_STAR} Security Audit (lynis)                                        ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}                                                                           ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}   ${WHITE}[0]${NC} ${RED}Exit${NC}                                                             ${CYAN}║${NC}\n"
    printf "${CYAN}║${NC}                                                                           ${CYAN}║${NC}\n"
    printf "${CYAN}╚═══════════════════════════════════════════════════════════════════════════╝${NC}\n"
    printf "\n"
}

run_quick_setup() {
    module_preflight
    module_user_management
    module_ssh_hardening
    module_firewall
    module_fail2ban
    module_selinux
    module_cleanup
    module_software
    module_kernel
    module_auto_updates
    module_security_extras
    module_disk
    module_datetime
    module_system_update
    module_post_setup
}

show_system_status() {
    print_section "SYSTEM STATUS" "$SYM_INFO"

    detect_os
    detect_connection
    detect_user_context
    detect_ssh_config
    detect_firewall
    detect_selinux
    detect_services
    check_internet

    print_subsection "System"
    print_status "OS" "$OS_NAME $OS_VERSION"
    print_status "Kernel" "$(uname -r)"
    print_status "Uptime" "$(uptime -p)"
    print_status "Load" "$(cat /proc/loadavg | awk '{print $1, $2, $3}')"

    print_subsection "Resources"
    print_status "Memory" "$(free -h | awk '/Mem:/ {print $3 "/" $2}')"
    print_status "Disk (/)" "$(df -h / | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"

    print_subsection "Security"
    print_status "SSH Port" "$CURRENT_SSH_PORT"
    print_status "SSH Password Auth" "$SSH_PASSWORD_AUTH"
    print_status "Firewall" "$FIREWALLD_STATUS"
    print_status "SELinux" "$SELINUX_STATUS"
    print_status "Fail2ban" "${SERVICE_STATUS[fail2ban]:-not installed}"

    pause
}

run_security_audit() {
    print_section "SECURITY AUDIT" "$SYM_STAR"

    if ! command -v lynis &>/dev/null; then
        if confirm "Lynis is not installed. Install it?"; then
            run_with_spinner "Installing lynis" "$PKG_MGR install -y lynis"
        else
            return
        fi
    fi

    printf "${CYAN}Running Lynis security audit...${NC}\n\n"
    lynis audit system --quick

    printf "\n${CYAN}Full report available at: /var/log/lynis.log${NC}\n"

    pause
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --yes|-y)
                SKIP_CONFIRMATIONS=true
                shift
                ;;
            --help|-h)
                print_banner
                printf "Usage: $0 [options]\n\n"
                printf "Options:\n"
                printf "  --dry-run    Show what would be done without making changes\n"
                printf "  --yes, -y    Skip confirmations (use defaults)\n"
                printf "  --help, -h   Show this help message\n"
                exit 0
                ;;
            *)
                printf "${RED}Unknown option: $1${NC}\n"
                exit 1
                ;;
        esac
    done

    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        printf "${RED}${SYM_CROSS} This script must be run as root${NC}\n"
        printf "${YELLOW}Try: sudo $0${NC}\n"
        exit 1
    fi

    # Initialize
    init_logging
    init_backup_dir

    # Trap for cleanup
    trap 'show_cursor; echo; log "Script interrupted"; exit 130' INT TERM

    # Main menu loop
    while true; do
        show_main_menu

        printf "${YELLOW}>${NC} Enter choice: "
        read -r choice </dev/tty

        case "$choice" in
            1) run_quick_setup ;;
            2) module_user_management ;;
            3) module_ssh_hardening ;;
            4) module_firewall ;;
            5) module_fail2ban ;;
            6) module_selinux ;;
            7) module_cleanup ;;
            8) module_software ;;
            9) module_kernel ;;
            10) module_auto_updates ;;
            11) module_security_extras ;;
            12) module_disk ;;
            13) module_datetime ;;
            14) module_system_update ;;
            15) show_system_status ;;
            16) run_security_audit ;;
            0|q|Q|exit)
                printf "\n${GREEN}${SYM_PARTY} Thanks for using Server Hardening Script!${NC}\n"
                printf "${GRAY}Log saved to: ${LOG_FILE}${NC}\n\n"
                exit 0
                ;;
            *)
                printf "${RED}Invalid option. Please try again.${NC}\n"
                sleep 1
                ;;
        esac
    done
}

# Run main
main "$@"
