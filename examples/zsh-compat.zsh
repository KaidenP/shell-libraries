#!/usr/bin/env zsh
# =============================================================================
# examples/zsh-compat.zsh — using require.d from a zsh script
# =============================================================================
# require.d works transparently in zsh.  The only difference is array syntax:
# zsh arrays are 1-indexed and use a slightly different declaration style, but
# REQUIRE_DIRS and REQUIRE_DIRS_ADDITIONAL work the same way.
# =============================================================================

# Bootstrap — identical to bash usage.
$(require.d source)

# In zsh, arrays are declared with parentheses (same syntax works in both).
REQUIRE_DIRS_ADDITIONAL=(
    "${0:A:h}/../lib"   # zsh: ${0:A:h} gives the directory of this script
)

# Require libraries — identical API.
require logging
require colors

log_info "Running in zsh ${ZSH_VERSION}"
print_green "Colour library loaded"
