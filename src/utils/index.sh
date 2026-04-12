has_command() { command -v "$1" &> /dev/null; }

# sudo_if_possible [-r|--run-anyways] [-f|--force] [-u|--user <user>] [-t|--test] <command> [<args>]
# Runs <command> with sudo if not already root, or as specified user.
# Returns 1 (without running) if sudo is unavailable, unless -r is given.
# With -f, logs to stderr and exits 1 if root/sudo is unavailable.
# With -t, no command is needed, it only tests if sudo is available
sudo_if_possible() {
  local run_anyways=false force=false as_user="" test_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -r | --run-anyways)
      run_anyways=true
      shift
      ;;
    -f | --force)
      force=true
      shift
      ;;
    -t | --test)
      test_only=true
      shift
      ;;
    -u | --user)
      as_user="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      log_err "sudo_if_possible: unknown option $1"
      return 1
      ;;
    *) break ;;
    esac
  done

  if [[ "$test_only" == false && $# -eq 0 ]]; then
    log_err "sudo_if_possible: no command specified"
    return 1
  fi

  local uid
  uid="$(id -u)"
  local -a prefix=()

  if [[ -n "$as_user" ]]; then
    # User switching: prefer runuser (no sudo needed when root), fall back to sudo
    if [[ "$uid" -eq 0 ]] && has_command runuser; then
      prefix=(runuser -u "$as_user" --)
    elif has_command sudo && ([[ "$uid" -eq 0 ]] || ! (LANG= sudo -n -v 2>&1 | grep -q "may not run sudo")); then
      prefix=(sudo -u "$as_user")
    else
      [[ "$force" == true ]] && {
        log_err "Cannot run as '$as_user': sudo/runuser unavailable"
        exit 1
      }
      return 1
    fi
  elif [[ "$uid" -eq 0 ]]; then
    : # already root, run directly
  elif has_command sudo && ! (LANG= sudo -n -v 2>&1 | grep -q "may not run sudo"); then
    prefix=(sudo)
  elif [[ "$run_anyways" == true ]]; then
    : # run as current user
  else
    [[ "$force" == true ]] && {
      log_err "Root required, not running as root and sudo unavailable"
      exit 1
    }
    return 1
  fi

  [[ "$test_only" == true ]] && return 0
  "${prefix[@]}" "$@"
}

is_sourced() {
  # $ZSH_EVAL_CONTEXT exists only in Zsh
  if [[ -n "${ZSH_EVAL_CONTEXT:-}" ]]; then
    case $ZSH_EVAL_CONTEXT in *:file) return 1 ;; esac # sourced
    return 0                                           # executed
  fi
  # Bash
  [ "${BASH_SOURCE[0]}" != "$0" ] && return 0 || return 1
}

is_wsl() { grep -qi microsoft /proc/version /proc/sys/kernel/osrelease 2> /dev/null; }
is_wsl_interop() { [[ -e /proc/sys/fs/binfmt_misc/WSLInterop ]]; }
