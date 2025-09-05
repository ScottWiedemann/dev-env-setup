#!/usr/bin/env bash

# set -e: Exit immediately if a command exits with a non-zero status.
# set -u: Treat unset variables as an error and exit immediately.
# set -o pipefail: If any command in a pipeline fails, the whole pipeline fails.
set -euo pipefail

# --- Configuration Variables ---
DOTFILES_REPO="https://github.com/ScottWiedemann/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR_BASE="$HOME/.dotfiles_backups"
FORCE_NON_INTERACTIVE=false

# Global variables for OS detection
OS_NAME=""
PACKAGE_MANAGER_CMD=""
DISTRO_ID=""
IS_TERMUX=false

# --- Helper Functions ---

log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "'$1' is not installed. Please install it to proceed."
    fi
    log_info "'$1' command found."
}

confirm_action() {
    if "$FORCE_NON_INTERACTIVE"; then
        log_info "Non-interactive mode: Auto-confirming '$1'."
        true
        return
    fi

    read -r -p "$1 (y/N): " response
    case "$response" in
        [yY][eE][sS]|[yY])
            true
            ;;
        *)
            false
            ;;
    esac
}

# --- OS Detection Function ---
_detect_os() {
    log_info "Detecting operating system..."

    if [ -d "/data/data/com.termux/files/usr/etc/termux" ]; then
        log_info "Detected Termux environment."
        OS_NAME="Termux"
        DISTRO_ID="termux"
        PACKAGE_MANAGER_CMD="pkg install -y"
        IS_TERMUX=true
        log_warn "Note: Termux operates in userland; no 'sudo' required or available for pkg."
        log_info "OS detection complete. Package manager: $PACKAGE_MANAGER_CMD"
        return
    fi

    OS_NAME=$(uname -s) # e.g., Linux, Darwin

    case "$OS_NAME" in
        Linux)
            if [ -f "/etc/os-release" ]; then
                . /etc/os-release
                DISTRO_ID="$ID"
                log_info "Detected Linux distribution: $NAME (ID: $DISTRO_ID)"

                case "$DISTRO_ID" in
                    ubuntu|debian|pop)
                        PACKAGE_MANAGER_CMD="sudo apt-get install -y"
                        log_info "Using apt-get for package management."
                        ;;
                    fedora|centos|rhel)
                        PACKAGE_MANAGER_CMD="sudo dnf install -y"
                        log_info "Using dnf for package management."
                        ;;
                    arch)
                        PACKAGE_MANAGER_CMD="sudo pacman -S --noconfirm"
                        log_info "Using pacman for package management."
                        ;;
                    *)
                        log_error "Unsupported Linux distribution: $DISTRO_ID. Please extend '_detect_os' function."
                        exit 1
                        ;;
                esac
            else
                log_warn "Could not find /etc/os-release. Falling back to generic Linux."
                log_error "Cannot determine Linux distribution for package management. Exiting."
                exit 1
            fi
            ;;
        Darwin)
            log_info "Detected macOS."
            if command -v brew &> /dev/null; then
                PACKAGE_MANAGER_CMD="brew install"
                log_info "Using Homebrew for package management."
            else
                log_error "Homebrew not found. Please install Homebrew (https://brew.sh/) to proceed on macOS."
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $OS_NAME. Exiting."
            exit 1
            ;;
    esac

    if [ "$PACKAGE_MANAGER_CMD" = "" ]; then
        log_error "Failed to determine a package manager for $OS_NAME. Exiting."
        exit 1
    fi

    log_info "OS detection complete. Package manager: $PACKAGE_MANAGER_CMD"
}

# --- Core Logic Functions ---

_setup() {
    log_info "Executing setup process..."
    _detect_os
    log_warn "Setup logic not yet implemented."
}

_takedown() {
    log_info "Executing takedown process..."
    _detect_os
    log_warn "Takedown logic not yet implemented."
}

usage() {
    echo "Usage: $0 [ --setup | --takedown ] [ --force ]"
    echo "  --setup    : Run the setup process."
    echo "  --takedown : Run the takedown process."
    echo "  --force    : Run in non-interactive mode (auto-confirms all prompts)."
    exit 1
}

# --- Main Script Logic ---
main() {
    log_info "Starting environment management script..."

    local action=""

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --setup)
                action="setup"
                ;;
            --takedown)
                action="takedown"
                ;;
            --force)
                FORCE_NON_INTERACTIVE=true
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
        shift
    done

    if [ "$action" = "" ]; then
        log_error "No action specified (--setup or --takedown)."
        usage
    fi

    check_command "git"

    if [ "$action" == "setup" ]; then
        _setup
    elif [ "$action" == "takedown" ]; then
        _takedown
    fi

    log_info "Script finished."
}

main "$@"
