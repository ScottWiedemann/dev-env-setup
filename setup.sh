#!/usr/bin/env bash

# set -e: Exit immediately if a command exits with a non-zero status.
# set -u: Treat unset variables as an error and exit immediately.
# set -o pipefail: If any command in a pipeline fails, the whole pipeline fails.
set -euo pipefail

# --- Configuration Variables ---
# We'll add more here as we progress.
DOTFILES_REPO="https://github.com/ScottWiedemann/.dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
BACKUP_DIR_BASE="$HOME/.dotfiles_backups"

# --- Helper Functions ---

# Functions to print messages with different colors
log_info() {
    echo -e "\033[0;32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[0;33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
    exit 1
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "'$1' is not installed. Please install it to proceed."
    fi
    log_info "'$1' command found."
}

# Function to ask for user confirmation
confirm_action() {
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

# --- Main Script Logic (Placeholder) ---
main() {
    log_info "Starting setup script..."

    # Initial checks
    check_command "git"

    # Placeholder for actual setup/takedown logic
    if confirm_action "Do you want to proceed with a dummy action?"; then
        log_info "Dummy action confirmed. Doing nothing for now."
    else
        log_info "Dummy action cancelled. Exiting."
    fi

    log_info "Script finished."
}

# Call the main function
main "$@"
