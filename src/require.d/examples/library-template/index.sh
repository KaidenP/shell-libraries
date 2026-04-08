#!/usr/bin/env bash
# =============================================================================
# examples/library-template/index.sh — how to write a require.d-compatible lib
# =============================================================================
# A library for require.d is just a shell script.  The only convention is:
#
#   • Place it at  <require_dir>/<name>.sh           (single-file library)
#     or at        <require_dir>/<name>/index.sh     (directory library)
#
#   • Guard against double-sourcing if the library has side effects.
#
#   • Prefer function-namespaced APIs to avoid polluting the global namespace.
# =============================================================================

# Guard: prevent re-sourcing (require() handles this, but belt-and-suspenders).
[[ -n "${__LIB_TEMPLATE_LOADED:-}" ]] && return 0
readonly __LIB_TEMPLATE_LOADED=1

# ── Library implementation ────────────────────────────────────────────────────

# A simple colour-aware logging library used by the examples.
# Functions are prefixed with 'log_' to namespace them.

readonly __LOG_RESET='\033[0m'
readonly __LOG_RED='\033[0;31m'
readonly __LOG_YELLOW='\033[0;33m'
readonly __LOG_CYAN='\033[0;36m'
readonly __LOG_GREY='\033[0;37m'

log_debug() { printf "${__LOG_GREY}[DEBUG]${__LOG_RESET} %s\n"   "$*" >&2; }
log_info()  { printf "${__LOG_CYAN}[INFO] ${__LOG_RESET} %s\n"   "$*";     }
log_warn()  { printf "${__LOG_YELLOW}[WARN] ${__LOG_RESET} %s\n" "$*" >&2; }
log_error() { printf "${__LOG_RED}[ERROR]${__LOG_RESET} %s\n"    "$*" >&2; }

# Return non-zero so callers can do:  log_error "msg" || exit 1
log_fatal() {
    printf "${__LOG_RED}[FATAL]${__LOG_RESET} %s\n" "$*" >&2
    return 1
}
