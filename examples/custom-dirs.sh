#!/usr/bin/env bash
# =============================================================================
# examples/custom-dirs.sh — controlling where require() searches
# =============================================================================
# Three ways to customise the library search path:
#
#   REQUIRE_DIRS_ADDITIONAL  prepend dirs without replacing defaults
#   REQUIRE_DIRS             replace the entire search path
#   (neither set)            use the default path only
# =============================================================================

$(require.d source)

# ── Option A: add project-local libs alongside the defaults ──────────────────
# REQUIRE_DIRS_ADDITIONAL is prepended to the default list:
#   ~/.local/require.d, /etc/require.d, /usr/lib/require.d
#
# Useful when you have project-specific libraries alongside system ones.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

REQUIRE_DIRS_ADDITIONAL=(
    "${SCRIPT_DIR}/../lib"       # project-local lib/
    "${SCRIPT_DIR}/../vendor"    # vendored libraries
)

require logging    # found in lib/ or vendor/, else falls back to system dirs


# ── Option B: replace the entire search path ─────────────────────────────────
# Set REQUIRE_DIRS directly to have full control.  The default dirs are ignored.
#
# Note: re-assigning REQUIRE_DIRS mid-script affects all subsequent require()
# calls; previously loaded libraries are not re-sourced.

REQUIRE_DIRS=(
    "${SCRIPT_DIR}/../lib"
    "/opt/myapp/lib"
)

require strict-logging   # only searched in the two dirs above


# ── Option C: reset to defaults ───────────────────────────────────────────────
# Unset REQUIRE_DIRS to restore the default search path for subsequent calls.

unset REQUIRE_DIRS
unset REQUIRE_DIRS_ADDITIONAL

require colors   # back to default: ~/.local/require.d, /etc/require.d, …
