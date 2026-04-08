# Shell Logging Library

A portable, structured logging system for bash and zsh scripts. Provides simple log levels, configurable output, optional colorization, and thread-safe file operations.

## Features

- **6 Log Levels**: TRACE, DEBUG, INFO, WARN, ERROR, FATAL
- **Configurable Filtering**: Set a global log level; messages below that level are silently ignored
- **Structured Format**: Timestamp, level name, prefix, and message in every log entry
- **Multiple Outputs**: Log to stdout, stderr, files, or any combination
- **Auto-Detecting Colors**: Colorization is automatic (TTY detected), configurable, or disabled
- **Safe for `set -u`**: Handles unset variables gracefully
- **Special Character Safe**: Properly quoted and escaped for all shell contexts
- **Append-Safe**: Thread and process-safe file operations
- **Portable**: Works in bash 3.2+, zsh 4.0+

## Installation

Source the library in your script:

```bash
#!/usr/bin/env bash

# Using require.d
$(require.d source)
require logging

# Or directly
source ./src/logging/index.sh
```

## Quick Start

```bash
#!/usr/bin/env bash
$(require.d source)
require logging

log_info "Starting application"
log_debug "Processing item #42"
log_warn "This operation may take a while"
log_error "Failed to connect to database"
log_fatal "Critical error; cannot continue"
```

## API Reference

### Leveled Logging Functions

```bash
log_trace "message"    # Level 0 - Most verbose
log_debug "message"    # Level 1
log_info "message"     # Level 2 (default)
log_warn "message"     # Level 3
log_error "message"    # Level 4
log_fatal "message"    # Level 5 (exits with code 1)
```

All functions accept multiple arguments, which are joined with spaces:

```bash
log_info "Processing" "$filename" "completed"
# Output: [2026-04-08 10:30:45] [INFO] Processing /path/to/file completed
```

### Generic Logging Function

```bash
log <level> <message>
```

Where `<level>` is one of: `TRACE`, `DEBUG`, `INFO`, `WARN`, `ERROR`, `FATAL` (case-insensitive).

```bash
LEVEL="warn"
log "$LEVEL" "Database query took 5.2 seconds"
```

## Configuration

All configuration is done via environment variables, which can be set before sourcing or at any time.

### `LOG_LEVEL`

**Type**: Integer (0-5) or level name  
**Default**: `2` (INFO)  
**Description**: Minimum log level to display. Messages below this level are ignored.

```bash
export LOG_LEVEL=0      # Show all messages (TRACE and up)
export LOG_LEVEL=1      # DEBUG and up
export LOG_LEVEL=4      # ERROR and FATAL only
```

Level constants are available as variables:

```bash
export LOG_LEVEL=$LOG_LEVEL_DEBUG
```

### `LOG_OUTPUTS`

**Type**: Bash array  
**Default**: `(/dev/stdout)`  
**Description**: Destinations for log output. Can be files, device files, or stdout/stderr.

```bash
# Log to multiple places
export LOG_OUTPUTS=("/dev/stdout" "/var/log/myapp.log")

# Log to file only
export LOG_OUTPUTS=("/var/log/myapp.log")

# Log to stderr
export LOG_OUTPUTS=("/dev/stderr")
```

### `LOG_COLOR`

**Type**: String  
**Default**: `auto`  
**Options**: `auto`, `always`, `never`  
**Description**: Control colorized output.

```bash
export LOG_COLOR=never      # Disable colors
export LOG_COLOR=always     # Force colors (even if not a TTY)
export LOG_COLOR=auto       # Detect TTY (default)
```

### `LOG_TIMESTAMP_FORMAT`

**Type**: String (strftime format)  
**Default**: `%Y-%m-%d %H:%M:%S`  
**Description**: Format for timestamps in log output.

```bash
export LOG_TIMESTAMP_FORMAT="%H:%M:%S"        # Time only
export LOG_TIMESTAMP_FORMAT="%s"              # Unix timestamp
export LOG_TIMESTAMP_FORMAT="%Y-%m-%dT%H:%M:%SZ"  # ISO 8601
```

### `LOG_PREFIX`

**Type**: String  
**Default**: `` (empty)  
**Description**: Optional prefix added to every log message (e.g., script name).

```bash
export LOG_PREFIX="myscript"
log_info "Starting"
# Output: [2026-04-08 10:30:45] [INFO] [myscript] Starting
```

## Examples

### Basic Usage

```bash
#!/usr/bin/env bash
$(require.d source)
require logging

log_info "Application started"
log_warn "Configuration file not found; using defaults"
log_error "Failed to parse JSON: $error"
```

### Logging to a File

```bash
#!/usr/bin/env bash
$(require.d source)
require logging

export LOG_OUTPUTS=("$HOME/myapp.log")
export LOG_LEVEL=$LOG_LEVEL_DEBUG

log_info "Logging to $HOME/myapp.log"
log_debug "Internal state: x=$x"
```

### Multiple Outputs (Console and File)

```bash
#!/usr/bin/env bash
$(require.d source)
require logging

export LOG_OUTPUTS=("/dev/stdout" "/var/log/myapp.log")
export LOG_PREFIX="myapp"

log_info "This appears in both stdout and /var/log/myapp.log"
```

### Disabling Colors for Piping

```bash
#!/usr/bin/env bash
$(require.d source)
require logging

export LOG_COLOR=never

log_info "This message has no ANSI codes"
log_info "Safe to pipe to files or other programs"
```

### Dynamic Log Level Control

```bash
#!/usr/bin/env bash
source <(require logging)

export LOG_LEVEL=$LOG_LEVEL_WARN

log_debug "Not shown (level < LOG_LEVEL)"
log_info "Not shown (level < LOG_LEVEL)"
log_warn "Shown"
log_error "Shown"

# Change level at runtime
export LOG_LEVEL=$LOG_LEVEL_DEBUG
log_debug "Now this is shown"
```

## Color Output

When colors are enabled, log levels are displayed in the following colors:

| Level | Color   |
|-------|---------|
| TRACE | White   |
| DEBUG | Cyan    |
| INFO  | Green   |
| WARN  | Yellow  |
| ERROR | Red     |
| FATAL | Magenta |

Colors are automatically detected when writing to a TTY (`/dev/stdout` or `/dev/stderr`). Set `LOG_COLOR` to override this behavior.

## Portability and Limitations

### Supported Shells

- **bash**: 3.2 and later
- **zsh**: 4.0 and later

### Limitations

- **`date` command required**: Timestamps require the `date` utility
- **Array syntax**: Uses bash/zsh array syntax; not compatible with POSIX sh
- **Subshell context**: Functions must be exported to be available in subshells
- **File permissions**: Log files must be writable by the script user
- **Timestamp format**: The `LOG_TIMESTAMP_FORMAT` is passed directly to `date +`; invalid formats will cause errors

### Best Practices

1. **Set configuration early**: Configure logging before any log calls
2. **Use `log_fatal` sparingly**: It exits the script; use `log_error` and manual exit for cleaner control
3. **Prefix for clarity**: Set `LOG_PREFIX` in main scripts to identify log sources
4. **File rotation**: For long-running processes, implement log rotation externally (e.g., logrotate)
5. **Performance**: Avoid excessive logging in tight loops; consider raising `LOG_LEVEL`

## Thread Safety

Log writes to files use atomic append operations (`>>`), which are safe for concurrent writes on most modern filesystems. However, for high-concurrency scenarios, consider:

- Using a dedicated logging process
- Implementing a per-process log file
- Using a centralized logging service

## Error Handling

The logging library handles errors gracefully:

- If an output file cannot be written, the error is silently suppressed and other outputs are attempted
- If `date` fails, logs will not be written (return code is non-zero)
- If `LOG_TIMESTAMP_FORMAT` is invalid, `date` will fail and produce no output

## License

Part of the require.d shell script library collection.
