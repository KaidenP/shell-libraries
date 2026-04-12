#!/usr/bin/env bash
set -euo pipefail
# Load required libraries
eval "$(require.d source logging)"
eval "$(require.d source utils)"

# Detect package manager and OS info
detect_platform() {
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    PLATFORM="$ID"
    VERSION="$VERSION_ID"
  else
    PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
    VERSION=""
  fi

  if command -v apt-get &> /dev/null; then
    PKG_MGR="apt"
    UPDATE_CMD="apt-get update"
    UPGRADE_CMD="apt-get upgrade -y && apt-get dist-upgrade -y"
    INSTALL_CMD="apt-get install -y"
  elif command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
    UPDATE_CMD="dnf makecache"
    UPGRADE_CMD="dnf upgrade -y"
    INSTALL_CMD="dnf install -y"
  elif command -v yum &> /dev/null; then
    PKG_MGR="yum"
    UPDATE_CMD="yum makecache"
    UPGRADE_CMD="yum update -y"
    INSTALL_CMD="yum install -y"
  elif command -v pacman &> /dev/null; then
    PKG_MGR="pacman"
    UPDATE_CMD="pacman -Sy"
    UPGRADE_CMD="pacman -Syu --noconfirm"
    INSTALL_CMD="pacman -S --noconfirm"
  elif command -v zypper &> /dev/null; then
    PKG_MGR="zypper"
    UPDATE_CMD="zypper refresh"
    UPGRADE_CMD="zypper update -y"
    INSTALL_CMD="zypper install -y"
  else
    log "WARN: No supported package manager found."
    PKG_MGR="unknown"
    UPDATE_CMD="false"
    INSTALL_CMD="false"
  fi
}

upgrade_packages() {
  if [[ -n "${UPGRADE_CMD:-}" ]]; then
    # bash -c needed: UPGRADE_CMD may contain shell operators (e.g. apt's "cmd1 && cmd2")
    sudo_if_possible -f bash -c "$UPGRADE_CMD"
  fi
}

detect_platform
# var for later batch install
declare -a batch_packages=()

# Accepts input as $1
# format is one or more lines of:
# <command> <platform>[-<version>]:<package_name>[,<platform>[-<version>]:<package_name> ...][,script:/path/to/install/script][,optional][ required_by]
# if $2 is specefied, required_by is replaced by $2
queue_install_deps() {
  # Read input from file
  local input_file="$1"
  local lines
  mapfile -t lines < "$input_file"

  for line in "${lines[@]}"; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    # Parse line into components
    parts=($line)
    cmd="${parts[0]}"

    if ((${#parts[@]} >= 3)); then
      required_by="${parts[-1]}"
      rest="${line#"$cmd "}"
      rest="${rest%" $required_by"}"
    else
      rest="${line#"$cmd "}"
      required_by=""
    fi

    if [[ -n "${2:-}" ]]; then
      required_by="$2"
    fi

    # Skip if command exists
    if has_command "$cmd"; then
      log "Skipping $cmd, already installed."
      continue
    fi

    # Parse package list
    IFS=',' read -ra pkg_entries <<< "$rest"
    pkg_to_install=""
    script_to_run=""

    for entry in "${pkg_entries[@]}"; do
      if [[ "$entry" == "optional" ]]; then
        log "Skipping command '$cmd', as it was marked optional"
        script_to_run="true"
        break
      fi
      plat=${entry%%:*}
      pkg=${entry#*:}
      # Check for "script"
      if [[ "$plat" == "script" ]]; then
        script_to_run="$pkg"
        break
      elif [[ "$plat" == "$PLATFORM" || ("$plat" == "$PLATFORM-"* && "$plat" == "$PLATFORM-$VERSION"*) ]]; then
        pkg_to_install="$pkg"
        break
      fi
    done

    if [[ -n "$pkg_to_install" ]]; then
      batch_packages+=("$pkg_to_install")
    elif [[ -n "$script_to_run" ]]; then
      log "Running script for $cmd${required_by:+ as required by $required_by}: $script_to_run"
      $script_to_run
    else
      log "ERROR: Don't know how to install $cmd for $PLATFORM-$VERSION${required_by:+ as required by $required_by}."
      log "ERROR: Known platforms: $(printf '%s ' "${pkg_entries[@]}")"
    fi
  done
}

UPDATED=0
install_deps() {
  # Update package lists and install
  if [[ -v batch_packages && ${#batch_packages[@]} -gt 0 ]]; then
    if [[ "$PKG_MGR" == "unknown" ]]; then
      log "ERROR: Cannot install packages, no supported package manager."
      exit 1
    fi

    if [[ $UPDATED -eq 0 ]]; then
      log "Updating package lists using $PKG_MGR..."
      # shellcheck disable=SC2086
      sudo_if_possible -f $UPDATE_CMD
      UPDATED=1
    fi

    log "Installing packages: ${batch_packages[*]}"
    # shellcheck disable=SC2086
    sudo_if_possible -f $INSTALL_CMD "${batch_packages[@]}"
  fi
}
