# utils

General-purpose utility functions for shell scripts, including command detection, privilege escalation, source detection, and platform checks.

Works in **bash** (3.2+) and **zsh** (5+).

---

## Quick start

```sh
$(require.d source utils)

# Check if a command exists
if has_command docker; then
  echo "Docker is available"
fi

# Run a command with sudo if needed
sudo_if_possible systemctl restart nginx

# Detect if script is sourced
if is_sourced; then
  echo "This script is being sourced"
else
  echo "This script is being executed"
fi
```

---

## Usage

```sh
# Add to your script
$(require.d source utils)
```

---

## API Reference

### `has_command <command>`

Check if a command is available in the current `PATH`.

**Parameters:**
- `<command>` — Command name to check (e.g., `git`, `docker`, `curl`)

**Returns:**
- `0` if command exists, `1` otherwise

**Example:**

```sh
if has_command git; then
  git clone https://example.com/repo.git
else
  echo "git is not installed" >&2
  exit 1
fi
```

---

### `sudo_if_possible [OPTIONS] <command> [<args>...]`

Run a command with `sudo` if not already root, with fallback behavior for environments where `sudo` is unavailable.

**Parameters:**
- `<command>` — Command to run
- `[<args>...]` — Arguments to pass to the command

**Options:**

| Flag | Long form | Description |
|---|---|---|
| `-r` | `--run-anyways` | Run as current user if `sudo` unavailable (default: fail) |
| `-f` | `--force` | Log error and exit 1 if sudo unavailable (default: return 1) |
| `-u <user>` | `--user <user>` | Run as specified user instead of root |
| `-t` | `--test` | Only test if sudo is available (no command needed) |
| `--` | — | Stop option parsing; remaining args are the command |

**Returns:**
- `0` on success
- `1` if `sudo` unavailable and `-r` not given (or `-f` given with unavailable `sudo`)

**Examples:**

```sh
# Simple: restart nginx with sudo if needed
sudo_if_possible systemctl restart nginx

# Force: require sudo or exit with error
sudo_if_possible -f systemctl restart nginx

# Fallback: run as current user if sudo unavailable
sudo_if_possible -r apt update

# Run as specific user
sudo_if_possible -u postgres psql -c "SELECT version();"

# Test if sudo available without running anything
if sudo_if_possible -t; then
  echo "sudo is available"
fi

# Run a command with spaces/args
sudo_if_possible -- docker run --rm alpine:latest ls /
```

---

### `is_sourced`

Detect whether the current script is being sourced or executed directly.

**Returns:**
- `0` if sourced (script should not exit)
- `1` if executed directly (script should call `exit`)

**Example:**

```sh
# my-script.sh
if ! is_sourced; then
  set -euo pipefail
fi

my_function() {
  echo "Hello from my-script"
}

if ! is_sourced; then
  my_function "$@"
fi
```

Works in both **bash** (via `BASH_SOURCE`) and **zsh** (via `ZSH_EVAL_CONTEXT`).

---

### `is_wsl`

Detect if the script is running on Windows Subsystem for Linux (WSL).

**Returns:**
- `0` if running on WSL, `1` otherwise

**Notes:**
- Checks `/proc/version` and `/proc/sys/kernel/osrelease` for "microsoft"
- Works on both WSL1 and WSL2
- Silent failure if files are unreadable

**Example:**

```sh
if is_wsl; then
  export DOCKER_HOST=unix:///run/docker.sock
fi
```

---

### `is_wsl_interop`

Detect if WSL interop with Windows executables is available.

**Returns:**
- `0` if WSL interop available, `1` otherwise

**Notes:**
- Checks for `/proc/sys/fs/binfmt_misc/WSLInterop` file
- Indicates Windows `.exe` executables can be run from within WSL
- Only meaningful on WSL2 with Windows interop enabled

**Example:**

```sh
if is_wsl && is_wsl_interop; then
  # Can run Windows executables from WSL
  powershell.exe -Command "Get-Date"
fi
```

---

## Environment variables

The utils library does not require or export any environment variables.

---

## Dependencies

The utils library has no external dependencies beyond POSIX shell built-ins. The `sudo_if_possible` function attempts to use:

- `sudo` (if available)
- `runuser` (preferred for user switching when root)

But gracefully degrades if these tools are unavailable.

---

## Examples

### Check for required tools before proceeding

```sh
$(require.d source utils)

# Ensure required tools are available
for cmd in git curl tar; do
  if ! has_command "$cmd"; then
    echo "Error: $cmd is required but not installed" >&2
    exit 1
  fi
done

echo "All required tools are available"
```

### Conditional privilege escalation

```sh
$(require.d source utils)

# Try to restart systemd service with sudo if needed
if ! sudo_if_possible systemctl restart myservice; then
  echo "Could not restart service (sudo unavailable)" >&2
  exit 1
fi
```

### Platform-aware script initialization

```sh
$(require.d source utils)

# WSL-specific setup
if is_wsl; then
  echo "Running on WSL"
  
  if is_wsl_interop; then
    echo "WSL interop enabled — Windows executables available"
  else
    echo "WSL interop disabled"
  fi
fi

# Script setup
if is_sourced; then
  echo "Loaded as library"
else
  echo "Executing as main script"
  my_main_function "$@"
fi
```

### Guarded command execution

```sh
$(require.d source utils)

if has_command systemctl; then
  # Use systemd
  sudo_if_possible systemctl status myapp
elif has_command service; then
  # Fallback to init.d
  sudo_if_possible service myapp status
else
  echo "No service manager found" >&2
  exit 1
fi
```

---

## Portability

| Shell | Version | Status |
|---|---|---|
| bash | 3.2+ | ✓ Full support |
| zsh | 5.0+ | ✓ Full support |
| dash | — | ⚠ `is_sourced` always returns 1 |

The `is_sourced` function uses shell-specific introspection and has sensible fallbacks for shells that don't support it.

---

## License

MIT
