# subcommand

Dispatching and help system for subcommand-based CLI applications.

`subcommand` provides a framework for building CLI tools with multiple subcommands (like `git commit`, `docker run`, etc.). It handles:
- **Command dispatching** to functions matching `<prefix>_cmd_<subcommand>`
- **Lazy loading** of subcommand implementations from files
- **Help generation** from predefined help functions or discovered subcommands
- **Flexible discovery** from directories or predefined functions

## API

### `subcommand_run [-p prefix] [-d search_dir] [subcommand] [args...]`

Main entry point for dispatching subcommands.

**Options:**
- `-p prefix` — Function-name prefix (default: script's basename, with hyphens converted to underscores)
- `-d search_dir` — Directory to lazy-load subcommand files from (optional)

**Behavior:**
- No subcommand: calls `<prefix>_cmd()` if defined, otherwise prints help
- Help request (`-h` / `--help`): prints help and exits with 0
- Unknown subcommand: prints error and exits with 1
- Known subcommand: calls `<prefix>_cmd_<subcommand>` with remaining args

## Examples

### Example 1: Simple File-Based Subcommands

```bash
#!/bin/bash
$(require.d source);
require subcommand
require logging

# Directory structure:
# bin/mycli
# bin/commands/start.sh
# bin/commands/stop.sh
# bin/commands/restart.sh

# In start.sh:
# mycli_cmd_start() {
#   log_info "Starting service..."
# }

# In stop.sh:
# mycli_cmd_stop() {
#   log_info "Stopping service..."
# }

# In restart.sh:
# mycli_cmd_restart() {
#   mycli_cmd_stop
#   mycli_cmd_start
# }

subcommand_run -p mycli -d "$(dirname "$0")/commands" "$@"
```

Usage:
```bash
mycli start         # calls mycli_cmd_start (after lazy-loading from commands/start.sh)
mycli stop          # calls mycli_cmd_stop
mycli restart       # calls mycli_cmd_restart
mycli -h            # prints help with all subcommands
```

### Example 2: Predefined Functions with Help

```bash
#!/bin/bash
$(require.d source);
require subcommand
require logging

# Define help functions alongside command functions
mycli_help() {
  cat <<EOF
my-cli — example CLI tool

Usage: my-cli <subcommand> [args...]
       my-cli -h
EOF
}

mycli_help_deploy() {
  echo "  deploy <env>      Deploy to an environment (dev, staging, prod)"
}

mycli_cmd_deploy() {
  local env="${1:?Environment required}"
  log_info "Deploying to $env..."
}

mycli_help_logs() {
  echo "  logs [--tail N]   Show application logs"
}

mycli_cmd_logs() {
  local tail="${2:-50}"
  log_info "Showing last $tail lines..."
}

# No search directory — uses predefined functions only
subcommand_run -p mycli "$@"
```

Usage:
```bash
mycli deploy prod              # calls mycli_cmd_deploy prod
mycli logs --tail 100          # calls mycli_cmd_logs --tail 100
mycli -h                       # prints mycli_help() and lists all help_* subcommands
```

### Example 3: Hybrid Approach (Files + Predefined)

```bash
#!/bin/bash
$(require.d source);
require subcommand
require logging

# Predefined help for built-in commands
myapp_help_version() {
  echo "  version           Show version information"
}

myapp_cmd_version() {
  echo "myapp 1.0.0"
}

# Directory structure:
# bin/myapp
# bin/plugins/build/build.sh
# bin/plugins/test/test.sh

myapp_help_build() {
  echo "  build [target]    Build a target (default: all)"
}

myapp_help_test() {
  echo "  test [pattern]    Run tests matching pattern"
}

subcommand_run -p myapp -d "$(dirname "$0")/plugins" "$@"
```

Usage:
```bash
myapp version                  # predefined: calls myapp_cmd_version
myapp build                    # file-based: lazy-loads from plugins/build/build.sh, calls myapp_cmd_build
myapp test unit                # file-based: lazy-loads from plugins/test/test.sh, calls myapp_cmd_test unit
myapp -h                       # lists all subcommands (both predefined and from directory)
```

### Example 4: Directory Structure Patterns

Two directory layouts are supported:

**Flat structure:**
```
commands/
  start.sh        → defines mycli_cmd_start()
  stop.sh         → defines mycli_cmd_stop()
  backup.sh       → defines mycli_cmd_backup()
```

**Nested structure:**
```
commands/
  start/
    start.sh      → defines mycli_cmd_start()
  stop/
    stop.sh       → defines mycli_cmd_stop()
  backup/
    backup.sh     → defines mycli_cmd_backup()
```

Both patterns are discovered automatically.

## Implementation Details

### Subcommand Discovery

Subcommands are discovered from two sources:

1. **Directory scanning** (if `-d search_dir` provided):
   - Files matching `<dir>/<name>.sh`
   - Directories with `<dir>/<name>/<name>.sh`

2. **Predefined functions**:
   - Functions matching `<prefix>_help_*`
   - Subcommand name extracted from function name suffix

### Function Naming

All commands follow the pattern: `<prefix>_cmd_<subcommand>`

Hyphens in subcommand names are converted to underscores:
```bash
subcommand_run -p mycli config-set  # calls mycli_cmd_config_set
```

### Help Generation

Help is generated in this order:

1. If `<prefix>_help()` is defined, call it
2. Print default usage line
3. For each discovered subcommand:
   - If `<prefix>_help_<subcommand>()` exists, call it
   - Otherwise print subcommand name in list format

### Lazy Loading

Subcommand files are only sourced when:
1. The subcommand is invoked
2. Its function cannot be found in the current shell

This allows large CLI tools with many subcommands to start quickly.
