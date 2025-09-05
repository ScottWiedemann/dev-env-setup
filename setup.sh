#!/usr/bin/env bash

# set -e: Exit immediately if a command exits with a non-zero status.
# set -u: Treat unset variables as an error and exit immediately.
# set -o pipefail: If any command in a pipeline fails, the whole pipeline fails.
set -euo pipefail

# --- Configuration Variables ---
DOTFILES_REPO="git@github.com:ScottWiedemann/.dotfiles.git"
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

# Function to safely move a file/directory to a backup location
_backup_item() {
    local source_path="$1"
    local backup_path="$2"

    if [ -e "$source_path" ]; then # Check if the source exists
        log_warn "Backing up existing '$source_path' to '$backup_path'..."
        if ! mkdir -p "$(dirname "$backup_path")"; then
            log_error "Failed to create backup directory for '$source_path'."
            exit 1
        fi
        if ! mv "$source_path" "$backup_path"; then
            log_error "Failed to move '$source_path' to '$backup_path'."
            exit 1
        fi
        log_info "Backed up '$source_path'."
    else
        log_info "'$source_path' does not exist, no backup needed."
    fi
}

_restore_item() {
    local backup_source_path="$1"
    local restore_target_path="$2"

    if [ -e "$backup_source_path" ]; then
        log_info "Restoring '$backup_source_path' to '$restore_target_path'..."
        if ! mkdir -p "$(dirname "$restore_target_path")"; then
          log_error "Failed to create directory for restoring '$restore_target_path'."
          exit 1
        fi

        if ! mv "$backup_source_path" "$restore_target_path"; then
          log_error "Failed to move '$backup_source_path' to '$restore_target_path'." 
          exit 1
        fi
        log_info "Restored '$restore_target_path'."
    else
        log_warn "Backup item '$backup_source_path' not found, skipping restore for '$restore_target_path'."
    fi
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

# --- Git SSH Setup Function ---
_setup_git_ssh() {
    log_info "Setting up Git SSH authentication..."

    check_command "ssh-keygen"
    check_command "ssh-agent"
    check_command "ssh-add"

    local ssh_key_path="$HOME/.ssh/id_ed25519"
    local old_ssh_key_path="$HOME/.ssh/id_rsa"

    if [ -f "$ssh_key_path" ]; then
        log_info "SSH key '$ssh_key_path' already exists."
    elif [ -f "$old_ssh_key_path" ]; then
        log_warn "Older SSH key '$old_ssh_key_path' found. Consider generating a new 'id_ed25519' key for better security."
        ssh_key_path="$old_ssh_key_path"
    else
        log_warn "No SSH key found. Generating a new ED25519 key at '$ssh_key_path'."
        if ! confirm_action "Generate a new SSH key now?"; then
            log_error "SSH key generation cancelled. Git operations will likely fail without an SSH key."
            exit 1
        fi
        log_info "Running 'ssh-keygen -t ed25519 -f \"$ssh_key_path\" -C \"$(whoami)@$(hostname)-dotfiles\"'."
        if ! ssh-keygen -t ed25519 -f "$ssh_key_path" -C "$(whoami)@$(hostname)-dotfiles"; then
            log_error "Failed to generate SSH key."
            exit 1
        fi
        log_info "SSH key generated. Remember your passphrase if you set one."
    fi

    log_info "Ensuring SSH agent is running and key is loaded..."

    if ! pgrep -q "ssh-agent"; then
        log_info "SSH agent not running, starting it."
        eval "$(ssh-agent -s)" || log_error "Failed to start ssh-agent." && exit 1
        log_info "SSH agent started."
    else
        log_info "SSH agent already running."
    fi

    if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$ssh_key_path" | awk '{print $2}')"; then
        log_info "Adding SSH key '$ssh_key_path' to agent."
        if ! ssh-add "$ssh_key_path"; then
            log_error "Failed to add SSH key to agent. Make sure you entered the correct passphrase if applicable."
            exit 1
        fi
        log_info "SSH key added to agent."
    else
        log_info "SSH key '$ssh_key_path' already loaded in agent."
    fi

    local public_key_file="$ssh_key_path.pub"
    if [ -f "$public_key_file" ]; then
        log_warn "IMPORTANT: Please add the following public SSH key to your GitHub account settings."
        log_warn "Go to GitHub -> Settings -> SSH and GPG keys -> New SSH key."
        log_warn "Copy the content of this file and paste it there:"
        log_info "--------------------------------------------------------------------------------"
        cat "$public_key_file"
        log_info "--------------------------------------------------------------------------------"
        if ! confirm_action "Have you added the public SSH key to GitHub? (Crucial for next steps)"; then
            log_error "Public SSH key not added to GitHub. Git operations may fail. Exiting."
            exit 1
        fi
    else
        log_error "Public SSH key file '$public_key_file' not found. Cannot provide key for GitHub."
        exit 1
    fi

    log_info "Git SSH setup complete."
}

# Function to get a list of dotfiles from the bare repo
_get_repo_dotfiles() {
    git --git-dir="$DOTFILES_DIR" ls-tree -r main --name-only | \
    grep -vE "^(\.git(ignore)?|\.mailmap|\.DS_Store|README\.md|LICENSE)$"
}

# --- Dotfiles Management Function ---
_manage_dotfiles_setup() {
    log_info "Managing dotfiles from $DOTFILES_REPO..."

    local current_backup_dir="$BACKUP_DIR_BASE/$(date +%Y%m%d%H%M%S)"
    log_info "Current backup directory for this run: $current_backup_dir"

    if [ -d "$DOTFILES_DIR" ]; then
        log_info "Dotfiles bare repository already exists. Updating..."
        local git_pull_output
        local git_pull_exit_code
        git_pull_output=$(git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" pull origin main 2>&1)
        git_pull_exit_code=$?

        if [ "$git_pull_exit_code" -ne 0 ]; then
            if echo "$git_pull_output" | grep -q "Already up to date."; then
                log_info "Dotfiles repository is already up to date."
            else
                log_error "Failed to pull dotfiles. Output:\n$git_pull_output"
                exit 1
            fi
        else
            log_info "Dotfiles repository updated successfully."
        fi
    else
        log_info "Cloning dotfiles bare repository..."
        if ! git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"; then
            log_error "Failed to clone dotfiles repository."
            exit 1
        fi
        log_info "Dotfiles bare repository cloned to $DOTFILES_DIR."
    fi

    log_info "Configuring Git for bare repository..."
    if ! git --git-dir="$DOTFILES_DIR" config status.showUntrackedFiles no; then
        log_error "Failed to configure Git with 'status.showUntrackedFiles no'."
        exit 1
    fi
    log_info "Git config 'status.showUntrackedFiles no' applied."

    log_info "Preparing to deploy dotfiles. Existing files will be backed up."

    while IFS= read -r dotfile; do
        echo "$dotfile"
        local full_path="$HOME/$dotfile"
        local backup_path="$current_backup_dir/$dotfile"

        if [ -e "$full_path" ]; then
            log_info "Detected existing $full_path."
            _backup_item "$full_path" "$backup_path"
        fi
    done < <(_get_repo_dotfiles)

    log_info "Checking out dotfiles into $HOME..."
    if confirm_action "This will overwrite existing dotfiles in your home directory with your repository's versions. Proceed?"; then
        if ! git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout main --force; then
            log_error "Failed to checkout dotfiles."
            exit 1
        fi
        log_info "Dotfiles deployed to $HOME."
    else
        log_warn "Dotfile checkout cancelled by user. Dotfiles may not be fully deployed. Exiting."
        exit 1
    fi

    if ! mkdir -p "$BACKUP_DIR_BASE"; then
        log_error "Failed to create base backup directory '$BACKUP_DIR_BASE'."
        exit 1
    fi
    if ! echo "$current_backup_dir" >> "$BACKUP_DIR_BASE/manifest.log"; then
        log_error "Failed to update backup manifest '$BACKUP_DIR_BASE/manifest.log'."
        exit 1
    fi
    log_info "Backup directory '$current_backup_dir' recorded in manifest."
}

_manage_dotfiles_takedown() {
    log_info "Beginning dotfiles takedown process..."

    if [ ! -d "$DOTFILES_DIR" ]; then
        log_warn "Dotfiles bare repository not found at '$DOTFILES_DIR'. Skipping dotfile takedown."
        return 0
    fi

    local last_backup_dir=""
    if [ -f "$BACKUP_DIR_BASE/manifest.log" ]; then
        last_backup_dir=$(tail -n 1 "$BACKUP_DIR_BASE/manifest.log")
        if [ "$last_backup_dir" = "" ]; then
            log_warn "Manifest log '$BACKUP_DIR_BASE/manifest.log' is empty or corrupt. Cannot determine last backup to restore."
        elif [ ! -d "$last_backup_dir" ]; then
            log_warn "Last recorded backup directory '$last_backup_dir' does not exist. Cannot restore original dotfiles."
            last_backup_dir=""
        fi
    else
        log_warn "Dotfiles backup manifest not found at '$BACKUP_DIR_BASE/manifest.log'. Cannot restore original dotfiles."
    fi

    log_info "Removing deployed dotfiles from $HOME..."
    while IFS= read -r dotfile; do
        local full_path="$HOME/$dotfile"
        if [ -e "$full_path" ]; then
            log_info "Removing '$full_path'."
            if ! rm -rf "$full_path"; then
                log_error "Failed to remove '$full_path'."
                exit 1
            fi
        else
            log_info "Dotfile '$full_path' not found in HOME, skipping removal."
        fi
    done < <(_get_repo_dotfiles)
    log_info "Deployed dotfiles removed from $HOME."

    if [ "$last_backup_dir" != "" ]; then
        log_info "Restoring original dotfiles from '$last_backup_dir'..."

        if find "$last_backup_dir" -type f -print0 | while IFS= read -r -d '' backup_file; do
            local relative_path="${backup_file#$last_backup_dir/}"
            local original_path="$HOME/$relative_path"
            _restore_item "$backup_file" "$original_path"
        done; then
            log_info "Files restored successfully."
        else
            log_error "Failed to restore some files from '$last_backup_dir'."
            exit 1
        fi

        if find "$last_backup_dir" -mindepth 1 -maxdepth 1 -type d -print0 | while IFS= read -r -d '' backup_dir; do
            local relative_path="${backup_dir#$last_backup_dir/}"
            local original_path="$HOME/$relative_path"
            _restore_item "$backup_dir" "$original_path"
        done; then
            log_info "Directories restored successfully."
        else
            log_error "Failed to restore some directories from '$last_backup_dir'."
            exit 1
        fi

        log_info "Original dotfiles restored from '$last_backup_dir'."

        if confirm_action "Delete the backup directory '$last_backup_dir'? (Recommended for clean takedown)"; then
            log_info "Removing backup directory '$last_backup_dir'..."
            if ! rm -rf "$last_backup_dir"; then
                log_error "Failed to remove backup directory '$last_backup_dir'."
                exit 1
            fi

            if ! sed -i '$d' "$BACKUP_DIR_BASE/manifest.log"; then
                log_warn "Failed to remove last entry from manifest.log. Manual cleanup may be required."
            fi
            log_info "Backup directory '$last_backup_dir' removed."
        else
            log_info "Skipping deletion of backup directory '$last_backup_dir'."
        fi
    else
        log_warn "No valid backup directory found/specified for restoration. User-specific dotfiles in $HOME were removed, but no original files were restored."
    fi

    if confirm_action "Delete the dotfiles bare repository '$DOTFILES_DIR'? (Recommended for clean takedown)"; then
        log_info "Removing dotfiles bare repository '$DOTFILES_DIR'..."
        if ! rm -rf "$DOTFILES_DIR"; then
            log_error "Failed to remove dotfiles bare repository."
            exit 1
        fi

        if [ -f "$BACKUP_DIR_BASE/manifest.log" ] && [ ! -s "$BACKUP_DIR_BASE/manifest.log" ]; then
            if ! rm -f "$BACKUP_DIR_BASE/manifest.log"; then
                log_warn "Failed to remove empty manifest.log."
            fi
        fi
        log_info "Dotfiles bare repository removed."
    else
        log_info "Skipping deletion of dotfiles bare repository."
    fi

    log_info "Dotfiles takedown complete."
}

# --- Core Logic Functions ---

_setup() {
    log_info "Executing setup process..."
    _detect_os
    _manage_dotfiles_setup
    log_warn "Setup logic not yet implemented."
}

_takedown() {
    log_info "Executing takedown process..."
    _detect_os
    _manage_dotfiles_takedown
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
