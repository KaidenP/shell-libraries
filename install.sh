#!/usr/bin/env bash
# Installation script for require.d shell library collection
# Usage: bash install.sh [--user|--system] [--force]
#   --user   Install to ~/.local (default if not root)
#   --system Install to /usr (default if root)
#   --force  Force reinstall if already installed

set -euo pipefail

readonly REPO_URL="https://github.com/KaidenP/shell-libraries.git"
readonly REPO_BRANCH="master"

_die() {
    printf 'Error: %s\n' "$@" >&2
    exit 1
}

_info() {
    printf '%s\n' "$@"
}

_is_installed_user() {
    [[ -d "${HOME}/.local/lib/require.d" ]] && [[ -f "${HOME}/.local/bin/require.d" ]]
}

_is_installed_system() {
    [[ -d "/usr/lib/require.d" ]] && [[ -f "/usr/bin/require.d" ]]
}

_uninstall_user() {
    _info "Uninstalling existing user installation..."
    rm -f "${HOME}/.local/bin/require.d"
    rm -rf "${HOME}/.local/lib/require.d"
    _info "Uninstall complete."
}

_uninstall_system() {
    _info "Uninstalling existing system installation..."
    rm -f "/usr/bin/require.d"
    rm -rf "/usr/lib/require.d"
    _info "Uninstall complete."
}

_install_user() {
    local lib_dir="${HOME}/.local/lib/require.d"
    local bin_dir="${HOME}/.local/bin"
    local tmp_dir

    if _is_installed_user; then
        _die "require.d is already installed to $lib_dir. Use --force to reinstall."
    fi

    tmp_dir=$(mktemp -d) || _die "Failed to create temporary directory"
    trap "rm -rf '$tmp_dir'" EXIT

    _info "Cloning repository..."
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$tmp_dir" \
        || _die "Failed to clone repository"

    _info "Installing (user) to $lib_dir"

    mkdir -p "$lib_dir" "$bin_dir"
    cp -r "$tmp_dir/src"/. "$lib_dir/" || _die "Failed to copy library files"

    # Create symlink to the main script in bin_dir
    if [[ -f "$lib_dir/require.d/required.sh" ]]; then
        ln -sf "$lib_dir/require.d/required.sh" "$bin_dir/require.d"
        chmod 755 "$bin_dir/require.d"
    fi

    _info "Installed to: $lib_dir"
    _info "Binary:       $bin_dir/require.d"
    _info ""
    _info "Add to PATH if not already present:"
    _info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
}

_install_system() {
    local lib_dir="/usr/lib/require.d"
    local bin_dir="/usr/bin"
    local tmp_dir

    if _is_installed_system; then
        _die "require.d is already installed to $lib_dir. Use --force to reinstall."
    fi

    tmp_dir=$(mktemp -d) || _die "Failed to create temporary directory"
    trap "rm -rf '$tmp_dir'" EXIT

    _info "Cloning repository..."
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$tmp_dir" \
        || _die "Failed to clone repository"

    _info "Installing (system) to $lib_dir"

    mkdir -p "$lib_dir"
    cp -r "$tmp_dir/src"/. "$lib_dir/" || _die "Failed to copy library files"

    # Create symlink to the main script in bin_dir
    if [[ -f "$lib_dir/require.d/required.sh" ]]; then
        ln -sf "$lib_dir/require.d/required.sh" "$bin_dir/require.d"
        chmod 755 "$bin_dir/require.d"
    fi

    _info "Installed to: $lib_dir"
    _info "Binary:       $bin_dir/require.d"
}

main() {
    local mode="auto"
    local force=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)   mode="user"   ;;
            --system) mode="system" ;;
            -f|--force) force=1     ;;
            -h|--help)
                _info "Usage: $0 [--user|--system] [--force]"
                _info ""
                _info "Options:"
                _info "  --user    Install to ~/.local (default if not root)"
                _info "  --system  Install to /usr (default if root)"
                _info "  --force   Uninstall and reinstall if already installed"
                exit 0
                ;;
            *)
                _die "Unknown option: $1"
                ;;
        esac
        shift
    done

    # Auto-select based on effective user ID
    if [[ "$mode" == "auto" ]]; then
        if [[ "$(id -u)" -eq 0 ]]; then
            mode="system"
        else
            mode="user"
        fi
    fi

    # Handle --force flag
    if [[ $force -eq 1 ]]; then
        case "$mode" in
            user)
                if _is_installed_user; then
                    _uninstall_user
                fi
                ;;
            system)
                if _is_installed_system; then
                    _uninstall_system
                fi
                ;;
        esac
    fi

    case "$mode" in
        user)   _install_user ;;
        system) _install_system ;;
        *)      _die "Unknown mode: $mode" ;;
    esac
}

main "$@"
