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

# --- Core Logic Functions ---

_setup() {
    log_info "Executing setup process..."
    log_warn "Setup logic not yet implemented."
}

_takedown() {
    log_info "Executing takedown process..."
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
