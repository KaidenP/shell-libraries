#!/usr/bin/env bash
# =============================================================================
# require.d — portable shell library dependency manager
# =============================================================================
# Dual-mode script: executable CLI or sourceable runtime library.
#
# CLI usage:
#   require.d source [LIB]        # emit source/require commands for inline use
#   require.d install [--user | --system]
#
# Runtime usage (after sourcing):
#   $(require.d source)           # load require() into current shell
#   $(require.d source <lib>)     # load require() and source a library
#   require <library> [URI]       # source a library, optionally auto-install
# =============================================================================

# ── Source-mode detection ────────────────────────────────────────────────────

__require_d_is_sourced() {
    if [[ -n "${ZSH_VERSION:-}" ]]; then
        [[ "${ZSH_EVAL_CONTEXT:-}" == *:file* ]]
    elif [[ -n "${BASH_VERSION:-}" ]]; then
        [[ "${BASH_SOURCE[0]:-}" != "${0}" ]]
    else
        return 1
    fi
}

# =============================================================================
# RUNTIME LIBRARY MODE  (script is being sourced)
# =============================================================================

if __require_d_is_sourced; then

# ── Internal helpers ─────────────────────────────────────────────────────────

# Normalize a library name into a safe variable-name fragment.
__require_safe_name() {
    local name="${1//[^a-zA-Z0-9_]/_}"
    printf '%s' "$name"
}

# Mark a library as loaded.
__require_mark_loaded() {
    local mark="__REQUIRED_$(__require_safe_name "$1")"
    eval "${mark}=1"
}

# Return 0 if a library is already loaded.
__require_is_loaded() {
    local mark="__REQUIRED_$(__require_safe_name "$1")"
    # Portable indirect variable reference for bash and zsh.
    local val
    eval "val=\"\${${mark}:-}\""
    [[ "$val" == "1" ]] || [[ "$1" == "required" ]]
}

# Print an error message to stderr.
__require_err() {
    printf 'require: %s\n' "$*" >&2
}

# Download a URL to a file.  Tries curl then wget.
__require_download() {
    local url="$1" dest="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL --retry 3 -o "$dest" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -q -O "$dest" "$url"
    else
        __require_err "neither curl nor wget found; cannot download '$url'"
        return 1
    fi
}

# Build the default REQUIRE_DIRS array when it is not set.
__require_default_dirs() {
    REQUIRE_DIRS=()
    # Prepend any user-supplied additional dirs.
    if [[ ${#REQUIRE_DIRS_ADDITIONAL[@]} -gt 0 ]]; then
        REQUIRE_DIRS+=("${REQUIRE_DIRS_ADDITIONAL[@]}")
    fi
    REQUIRE_DIRS+=(
        "${HOME}/.local/lib/require.d"
        "/etc/require.d"
        "/usr/lib/require.d"
    )
}

# Locate a library file across all search directories.
# Sets __require_found_path on success, returns 1 on failure.
__require_find_lib() {
    local lib_name="$1"
    __require_found_path=""

    local dirs_ref
    # Use REQUIRE_DIRS if already set and non-empty.
    if [[ ${#REQUIRE_DIRS[@]} -eq 0 ]]; then
        __require_default_dirs
    fi

    local dir
    for dir in "${REQUIRE_DIRS[@]}"; do
        if [[ -f "${dir}/${lib_name}.sh" ]]; then
            __require_found_path="${dir}/${lib_name}.sh"
            return 0
        fi
        if [[ -f "${dir}/${lib_name}/index.sh" ]]; then
            __require_found_path="${dir}/${lib_name}/index.sh"
            return 0
        fi
    done
    return 1
}

# ── Remote installers ────────────────────────────────────────────────────────

# Install a library from a git URI.
# Formats:
#   git://git@host:path[:branch|tag]   SSH-style
#   https://host/path[.git][:branch|tag]
#   http://host/path[.git][:branch|tag]
__require_install_git() {
    local lib_name="$1" uri="$2"
    local target="${HOME}/.local/require.d/${lib_name}"
    local clone_url branch=""

    if ! command -v git >/dev/null 2>&1; then
        __require_err "git not found; cannot install '$lib_name' from $uri"
        return 1
    fi

    case "$uri" in
        git://*)
            # SSH-style: git://git@host:path[:branch|tag]
            local rest="${uri#git://}"

            # Parse optional branch/tag: last ':'-separated token that contains
            # no '/' is treated as a ref; the preceding portion is the clone URL.
            if [[ "$rest" =~ ^(.*):([^/:]+)$ ]]; then
                local candidate_url="${BASH_REMATCH[1]:-}"
                local candidate_ref="${BASH_REMATCH[2]:-}"
                # Confirm the candidate URL looks like a git SSH URL (contains ':')
                if [[ "$candidate_url" == *:* ]]; then
                    clone_url="$candidate_url"
                    branch="$candidate_ref"
                else
                    clone_url="$rest"
                fi
            else
                clone_url="$rest"
            fi

            # Zsh-compatible fallback for BASH_REMATCH.
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                local last_colon_pos="${rest##*:}"
                local before_last="${rest%:*}"
                if [[ "$before_last" == *:* && "$last_colon_pos" != */* ]]; then
                    clone_url="$before_last"
                    branch="$last_colon_pos"
                else
                    clone_url="$rest"
                    branch=""
                fi
            fi
            ;;
        https://*|http://*)
            # HTTP(S) git: https://host/path[.git][:branch|tag]
            # An optional :branch suffix is the last colon-delimited token
            # with no slashes.  Strip it before passing the URL to git clone.
            if [[ "$uri" =~ ^(https?://.+):([^/:]+)$ ]]; then
                clone_url="${BASH_REMATCH[1]}"
                branch="${BASH_REMATCH[2]}"
            else
                clone_url="$uri"
            fi

            # Zsh-compatible fallback for BASH_REMATCH.
            if [[ -n "${ZSH_VERSION:-}" ]]; then
                local last_part="${uri##*/}"
                if [[ "$last_part" == *:* && "${last_part##*:}" != */* ]]; then
                    branch="${last_part##*:}"
                    clone_url="${uri%:${branch}}"
                else
                    clone_url="$uri"
                    branch=""
                fi
            fi
            ;;
    esac

    printf 'require: cloning %s -> %s\n' "$clone_url" "$target" >&2

    local clone_args=(--depth 1)
    [[ -n "$branch" ]] && clone_args+=(--branch "$branch")

    if [[ -d "$target/.git" ]]; then
        printf 'require: %s already cloned; pulling\n' "$lib_name" >&2
        git -C "$target" pull --ff-only || {
            __require_err "git pull failed for '$lib_name'"
            return 1
        }
    else
        mkdir -p "$(dirname "$target")"
        git clone "${clone_args[@]}" "$clone_url" "$target" || {
            __require_err "git clone failed for '$lib_name' from $clone_url"
            return 1
        }
    fi
}

# Install a library from an HTTP(S) tarball.
__require_install_tarball() {
    local lib_name="$1" url="$2"
    local target="${HOME}/.local/require.d/${lib_name}"
    local tmpfile
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/require.d.XXXXXX")"
    # Append a known extension to help tar auto-detect compression.
    local ext=""
    case "$url" in
        *.tar.gz|*.tgz)   ext=".tar.gz"  ;;
        *.tar.bz2|*.tbz2) ext=".tar.bz2" ;;
        *.tar.xz|*.txz)   ext=".tar.xz"  ;;
        *.tar.zst)        ext=".tar.zst"  ;;
        *.tar)            ext=".tar"      ;;
        *.zip)            ext=".zip"      ;;
    esac
    tmpfile="${tmpfile}${ext}"

    printf 'require: downloading %s\n' "$url" >&2
    if ! __require_download "$url" "$tmpfile"; then
        rm -f "$tmpfile"
        return 1
    fi

    mkdir -p "$target"

    if [[ "$ext" == ".zip" ]]; then
        if ! command -v unzip >/dev/null 2>&1; then
            __require_err "unzip not found; cannot extract '$url'"
            rm -f "$tmpfile"
            return 1
        fi
        unzip -q -o "$tmpfile" -d "$target" || {
            __require_err "unzip failed for '$url'"
            rm -f "$tmpfile"
            return 1
        }
    else
        if ! command -v tar >/dev/null 2>&1; then
            __require_err "tar not found; cannot extract '$url'"
            rm -f "$tmpfile"
            return 1
        fi
        tar -xf "$tmpfile" -C "$target" --strip-components=1 2>/dev/null \
            || tar -xf "$tmpfile" -C "$target" || {
            __require_err "tar extraction failed for '$url'"
            rm -f "$tmpfile"
            return 1
        }
    fi

    rm -f "$tmpfile"
    printf 'require: installed %s to %s\n' "$lib_name" "$target" >&2
}

# Install a library via a remote install script.
__require_install_script() {
    local lib_name="$1" url="$2"
    local tmpfile
    tmpfile="$(mktemp "${TMPDIR:-/tmp}/require.d.XXXXXX.sh")"

    printf 'require: downloading install script %s\n' "$url" >&2
    if ! __require_download "$url" "$tmpfile"; then
        rm -f "$tmpfile"
        return 1
    fi

    chmod +x "$tmpfile"
    printf 'require: running install script for %s\n' "$lib_name" >&2
    bash "$tmpfile" "$lib_name" || {
        __require_err "install script failed for '$lib_name'"
        rm -f "$tmpfile"
        return 1
    }
    rm -f "$tmpfile"
}

# Dispatch to the appropriate remote installer based on URI scheme/extension.
__require_install_remote() {
    local lib_name="$1" uri="$2"

    case "$uri" in
        git://*)
            __require_install_git "$lib_name" "$uri"
            ;;
        http://*.sh|https://*.sh)
            __require_install_script "$lib_name" "$uri"
            ;;
        http://*.git|https://*.git|http://*.git:*|https://*.git:*)
            # HTTP(S) URL whose path ends in .git (with optional :branch suffix)
            # is unambiguously a git repository, not a tarball.
            __require_install_git "$lib_name" "$uri"
            ;;
        http://*|https://*)
            __require_install_tarball "$lib_name" "$uri"
            ;;
        *)
            __require_err "unsupported URI scheme: '$uri'"
            return 1
            ;;
    esac
}

# ── Public API ───────────────────────────────────────────────────────────────

# require <library> [URI]
#
# Source a library by name, optionally installing it from a remote URI if it
# cannot be found locally.
require() {
    if [[ $# -lt 1 ]]; then
        __require_err "usage: require <library> [URI]"
        return 1
    fi

    local lib_name="$1"
    local uri="${2:-}"

    # Fast path: already loaded.
    if __require_is_loaded "$lib_name"; then
        return 0
    fi

    # Ensure REQUIRE_DIRS is populated.
    if [[ ${#REQUIRE_DIRS[@]} -eq 0 ]]; then
        __require_default_dirs
    fi

    # Search locally.
    if __require_find_lib "$lib_name"; then
        # shellcheck source=/dev/null
        source "$__require_found_path" || {
            __require_err "failed to source '$__require_found_path'"
            return 1
        }
        __require_mark_loaded "$lib_name"
        return 0
    fi

    # Attempt remote install if a URI was given.
    if [[ -n "$uri" ]]; then
        __require_install_remote "$lib_name" "$uri" || return 1

        # Re-search after install.
        if __require_find_lib "$lib_name"; then
            # shellcheck source=/dev/null
            source "$__require_found_path" || {
                __require_err "failed to source '$__require_found_path' after install"
                return 1
            }
            __require_mark_loaded "$lib_name"
            return 0
        fi

        __require_err \
            "library '$lib_name' not found after install from '$uri'"
        return 1
    fi

    __require_err "library '$lib_name' not found"
    __require_err "search dirs: ${REQUIRE_DIRS[*]}"
    return 1
}

# ── Cleanup internal helper ──────────────────────────────────────────────────

unset -f __require_d_is_sourced   # only needed at load time

# Mark that required.sh has been sourced (for cmd_source to detect).
export __REQUIRE_D_SOURCED=1

# =============================================================================
# CLI MODE  (script is executed directly)
# =============================================================================

else

set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────

_die() { printf 'require.d: %s\n' "$*" >&2; exit 1; }

_self_path() {
    # Resolve the absolute path of this script, following symlinks.
    local src="$0"
    while [[ -L "$src" ]]; do
        local dir
        dir="$(cd -P "$(dirname "$src")" && pwd)"
        src="$(readlink "$src")"
        [[ "$src" != /* ]] && src="${dir}/${src}"
    done
    echo "$(cd -P "$(dirname "$src")" && pwd)/$(basename "$src")"
}

_find_runtime() {
    # Prefer installed copies; fall back to this script itself.
    if [[ -f "${HOME}/.local/require.d/required.sh" ]]; then
        echo "${HOME}/.local/require.d/required.sh"
        return 0
    fi
    if [[ -f "/usr/lib/require.d/required.sh" ]]; then
        echo "/usr/lib/require.d/required.sh"
        return 0
    fi
    # Devlopment / uninstalled: use this file directly.
    local self
    self="$(_self_path)"
    if [[ -f "$self" ]]; then
        echo "$self"
        return 0
    fi
    return 1
}

# ── Subcommands ───────────────────────────────────────────────────────────────

cmd_source() {
    local runtime lib_name="${1:-}"
    runtime="$(_find_runtime)" \
        || _die "runtime not found; run 'require.d install' first"

    # If sourced flag is not set, output source command first.
    if [[ -z "${__REQUIRE_D_SOURCED:-}" ]]; then
        printf 'source %s\n' "$runtime"
    fi

    # If a library name was provided, output require command.
    if [[ -n "$lib_name" ]]; then
        printf 'require %s\n' "$lib_name"
    fi
}

cmd_install() {
    local mode="auto"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --user)   mode="user"   ;;
            --system) mode="system" ;;
            *) _die "unknown option: $1" ;;
        esac
        shift
    done

    # Auto-select based on effective user ID.
    if [[ "$mode" == "auto" ]]; then
        if [[ "$(id -u)" -eq 0 ]]; then
            mode="system"
        else
            mode="user"
        fi
    fi

    local self
    self="$(_self_path)"

    if [[ "$mode" == "user" ]]; then
        local lib_dir="${HOME}/.local/require.d"
        local bin_dir="${HOME}/.local/bin"
        local runtime="${lib_dir}/required.sh"
        local binary="${bin_dir}/require.d"

        printf 'Installing (user) to %s\n' "$lib_dir"

        mkdir -p "$lib_dir" "$bin_dir"
        cp -f "$self" "$runtime"
        chmod 644 "$runtime"

        # Create / update the symlink idempotently.
        ln -sf "$runtime" "$binary"
        chmod 755 "$binary"

        printf 'Installed runtime : %s\n' "$runtime"
        printf 'Installed binary  : %s\n' "$binary"
        printf '\nAdd %s to PATH if not already present:\n' "$bin_dir"
        printf '  export PATH="%s:$PATH"\n' "$bin_dir"

    elif [[ "$mode" == "system" ]]; then
        local lib_dir="/usr/lib/require.d"
        local bin_dir="/usr/bin"
        local runtime="${lib_dir}/required.sh"
        local binary="${bin_dir}/require.d"

        printf 'Installing (system) to %s\n' "$lib_dir"

        mkdir -p "$lib_dir"
        cp -f "$self" "$runtime"
        chmod 644 "$runtime"

        ln -sf "$runtime" "$binary"
        chmod 755 "$binary"

        printf 'Installed runtime : %s\n' "$runtime"
        printf 'Installed binary  : %s\n' "$binary"
    fi
}

cmd_help() {
    cat <<'EOF'
require.d — portable shell library dependency manager

USAGE
  require.d source [LIBRARY]
      Print shell source command(s) to load the require() runtime and/or a
      library. On first use, outputs both the source command and the require
      command; on subsequent uses, outputs only the require command.

      Intended for use as:
          $(require.d source)              # load require() into shell
          $(require.d source logging)      # load both require() and logging

  require.d install [--user | --system]
      Install require.d onto this system.
        --user    install to ~/.local  (default for non-root)
        --system  install to /usr/lib  (default for root)

RUNTIME (after sourcing)
  require <library> [URI]
      Source a library from the search path, optionally auto-installing it
      from a remote URI if not found locally.

ENVIRONMENT
  REQUIRE_DIRS        Array of directories to search (overrides defaults).
  REQUIRE_DIRS_ADDITIONAL
                      Array of directories prepended to the default list.

URI FORMATS
  git://git@host:path[:branch|tag]   Clone a git repository (SSH).
  https://host/path[.git][:branch]   Clone a git repository (HTTPS/HTTP).
  https://…/archive.tar.gz           Download and extract a tarball.
  https://…/install.sh               Download and execute an install script.

  HTTP(S) git URLs are detected by a .git path suffix.  Everything else
  is treated as a tarball (or install script if the URL ends in .sh).

EXAMPLES
  # Load require() into shell (first call outputs source, later calls don't)
  $(require.d source)

  # Load require() and source logging library in one call
  $(require.d source logging)

  # Source a local library (after require() is loaded)
  require logging

  # Source a library, installing from git if missing
  require mylib 'git://git@github.com:user/mylib'

  # Source a library from a tarball
  require mylib 'https://example.com/mylib-1.0.tar.gz'
EOF
}

# ── Entry point ───────────────────────────────────────────────────────────────

readonly _REQUIRE_D_VERSION="1.0.0"

case "${1:-}" in
    source)          shift; cmd_source  "$@" ;;
    install)         shift; cmd_install "$@" ;;
    help|--help|-h)  cmd_help ;;
    version|--version|-V)
        printf 'require.d %s\n' "$_REQUIRE_D_VERSION" ;;
    "")
        printf 'require.d %s  —  use "require.d help" for usage\n' \
            "$_REQUIRE_D_VERSION" ;;
    *)
        _die "unknown subcommand: '$1'  (try 'require.d help')" ;;
esac

fi  # end CLI mode
