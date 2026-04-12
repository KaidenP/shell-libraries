#!/usr/bin/env bash
set -euo pipefail
# logging/index.sh - Portable shell logging library
# Provides structured logging with configurable levels, outputs, and formatting

$(require.d source); require colors

# Log level constants (numeric for comparison)
readonly LOG_LEVEL_TRACE=0
readonly LOG_LEVEL_DEBUG=1
readonly LOG_LEVEL_INFO=2
readonly LOG_LEVEL_WARN=3
readonly LOG_LEVEL_ERROR=4
readonly LOG_LEVEL_FATAL=5

# Default configuration
LOG_LEVEL="${LOG_LEVEL:-2}"  # Default to INFO
LOG_COLOR="${LOG_COLOR:-auto}"  # auto|always|never
LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
LOG_PREFIX="${LOG_PREFIX:-}"

# Initialize output destinations if not already set
if [[ ! -v LOG_OUTPUTS || -z "${LOG_OUTPUTS[0]:-}" ]]; then
    declare -ag LOG_OUTPUTS=("/dev/stdout")
fi

# Internal: Map level name to number
_log_level_to_num() {
    local level="$1"
    # Convert to uppercase for portability (zsh + bash)
    level=$(printf '%s\n' "$level" | tr '[:lower:]' '[:upper:]')
    case "$level" in
        TRACE) echo "$LOG_LEVEL_TRACE" ;;
        DEBUG) echo "$LOG_LEVEL_DEBUG" ;;
        INFO) echo "$LOG_LEVEL_INFO" ;;
        WARN) echo "$LOG_LEVEL_WARN" ;;
        ERROR) echo "$LOG_LEVEL_ERROR" ;;
        FATAL) echo "$LOG_LEVEL_FATAL" ;;
        *) return 1 ;;
    esac
}

# Internal: Check if output is a TTY
_log_is_tty() {
    local output="$1"
    [[ "$output" == "/dev/stdout" || "$output" == "/dev/stderr" ]] && [[ -t 1 ]]
}

# Internal: Determine if colors should be used
_log_should_color() {
    case "$LOG_COLOR" in
        always) return 0 ;;
        never) return 1 ;;
        auto) _log_is_tty "/dev/stdout" && return 0 ;;
    esac
    return 1
}

# Internal: Get color code for level
_log_get_color() {
    local level="$1"
    if ! _log_should_color; then
        return 0
    fi

    # Convert to uppercase for portability
    level=$(printf '%s\n' "$level" | tr '[:lower:]' '[:upper:]')
    case "$level" in
        TRACE) echo "$C_WHITE" ;;
        DEBUG) echo "$C_CYAN" ;;
        INFO) echo "$C_GREEN" ;;
        WARN) echo "$C_YELLOW" ;;
        ERROR) echo "$C_RED" ;;
        FATAL) echo "$C_MAGENTA" ;;
    esac
}

# Internal: Core logging implementation
_log_write() {
    local level_num="$1"
    local level_name="$2"
    local color="$3"
    shift 3
    local message="$*"

    # Check if we should log this level
    if [[ "$level_num" -lt "$LOG_LEVEL" ]]; then
        return 0
    fi

    # Get timestamp
    local timestamp
    timestamp=$(date "+${LOG_TIMESTAMP_FORMAT}")

    # Build prefix
    local prefix=""
    if [[ -n "$LOG_PREFIX" ]]; then
        prefix="[$LOG_PREFIX] "
    fi

    # Build log line with color
    local reset_color
    if _log_should_color; then
        reset_color="$C_RESET"
    else
        reset_color=""
    fi

    local log_line
    log_line=$(printf '%s[%s] [%s]%s %s%s\n' \
        "$color" "$timestamp" "$level_name" "$reset_color" "$prefix" "$message")

    # Write to all configured outputs
    local output
    for output in "${LOG_OUTPUTS[@]:-/dev/stdout}"; do
        {
            printf '%s\n' "$log_line"
        } >> "$output" 2>/dev/null || true
    done
}

# Public API: Log at TRACE level
log_trace() {
    local color
    color=$(_log_get_color "TRACE")
    _log_write "$LOG_LEVEL_TRACE" "TRACE" "$color" "$@"
}

# Public API: Log at DEBUG level
log_debug() {
    local color
    color=$(_log_get_color "DEBUG")
    _log_write "$LOG_LEVEL_DEBUG" "DEBUG" "$color" "$@"
}

# Public API: Log at INFO level
log_info() {
    local color
    color=$(_log_get_color "INFO")
    _log_write "$LOG_LEVEL_INFO" "INFO" "$color" "$@"
}

# Public API: Log at WARN level
log_warn() {
    local color
    color=$(_log_get_color "WARN")
    _log_write "$LOG_LEVEL_WARN" "WARN" "$color" "$@"
}

# Public API: Log at ERROR level
log_error() {
    local color
    color=$(_log_get_color "ERROR")
    _log_write "$LOG_LEVEL_ERROR" "ERROR" "$color" "$@"
}

# Public API: Log at FATAL level (exits with code 1)
log_fatal() {
    local color
    color=$(_log_get_color "FATAL")
    _log_write "$LOG_LEVEL_FATAL" "FATAL" "$color" "$@"
    exit 1
}

# Public API: Generic log function
log() {
    local level="$1"
    shift
    local message="$*"

    local level_num
    level_num=$(_log_level_to_num "$level") || return 1

    local color
    color=$(_log_get_color "$level")

    # Convert level to uppercase for display
    level=$(printf '%s\n' "$level" | tr '[:lower:]' '[:upper:]')
    _log_write "$level_num" "$level" "$color" "$message"
}

# Export all public functions for subshells
export -f log_trace log_debug log_info log_warn log_error log_fatal log
