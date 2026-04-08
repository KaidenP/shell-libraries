#!/usr/bin/env bash
# =============================================================================
# examples/basic.sh — basic require.d usage
# =============================================================================
# This example shows how to:
#   1. Bootstrap require.d at the top of any script.
#   2. Source a local library by name.
#   3. Guard against missing libraries with a clear error.
# =============================================================================

# ── Bootstrap ─────────────────────────────────────────────────────────────────
# This single line loads the require() function into the current shell.
# require.d must already be on PATH (or installed via `require.d install`).
$(require.d source)

# ── Optional: add extra search directories ────────────────────────────────────
# REQUIRE_DIRS_ADDITIONAL is prepended to the default search path.
# This is useful for project-local libraries.
REQUIRE_DIRS_ADDITIONAL=("$(dirname "$0")/../lib")

# ── Load a library ────────────────────────────────────────────────────────────
# Searches REQUIRE_DIRS for:
#   <dir>/logging.sh
#   <dir>/logging/index.sh
require logging

# ── Use the library ───────────────────────────────────────────────────────────
log_info  "Application started"
log_debug "Debug information"
log_warn  "Something looks off"
log_error "Non-fatal error"
