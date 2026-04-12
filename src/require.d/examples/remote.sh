#!/usr/bin/env bash
set -euo pipefail
# =============================================================================
# examples/remote.sh — installing libraries from remote sources
# =============================================================================
# Demonstrates the three URI formats supported by require().
# If the library is already installed locally, the remote fetch is skipped.
# =============================================================================

$(require.d source)

# ── 1. Git repository ─────────────────────────────────────────────────────────
# Format: git://git@<host>:<path>[:<branch|tag>]
#
# Clones into ~/.local/require.d/<lib_name>/
# A branch or tag may be appended after a final ':'.

require colors 'git://git@github.com:example/shell-colors'

# With a specific tag:
# require colors 'git://git@github.com:example/shell-colors:v2.1.0'

# With a branch:
# require colors 'git://git@github.com:example/shell-colors:stable'


# ── 2. HTTP(S) tarball ────────────────────────────────────────────────────────
# Any http/https URL that does not end in .sh is treated as a tarball.
# Supported extensions: .tar, .tar.gz, .tgz, .tar.bz2, .tar.xz, .tar.zst, .zip
#
# Downloaded to a temp file, extracted into ~/.local/require.d/<lib_name>/
# --strip-components=1 is attempted first (strips the top-level archive dir).

require spinner 'https://example.com/releases/spinner-1.0.tar.gz'


# ── 3. Install script ─────────────────────────────────────────────────────────
# Any http/https URL ending in .sh is fetched and executed.
# The library name is passed as the first (and only) argument.
# The script is responsible for placing files under ~/.local/require.d/<lib_name>/

require mytools 'https://example.com/install/mytools.sh'


# ── Now use the installed libraries ──────────────────────────────────────────

print_green "Libraries loaded successfully"

spinner_start "Processing…"
sleep 2
spinner_stop "Done"
