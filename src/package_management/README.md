# Package Management Library

Utilities for cross-platform package detection and installation. Supports `apt`, `dnf`, `yum`, `pacman`, and `zypper` package managers with platform-aware package specification.

## Features

- **Platform Detection**: Automatically detects OS and installed package manager
- **Package Manager Support**: apt, dnf, yum, pacman, zypper
- **Batch Installation**: Queue packages and install them in a single operation
- **Platform-Specific Packages**: Specify different packages per platform/version
- **Custom Install Scripts**: Fall back to custom scripts for packages not in standard managers
- **Optional Dependencies**: Mark dependencies as optional to skip gracefully

## Dependencies

- `logging` library (for log output)
- `utils` library (for `has_command` and `sudo_if_possible`)

## API Reference

### `detect_platform()`

Detects the current OS platform and available package manager, populating these variables:

- `PLATFORM` (string): OS identifier (e.g., `ubuntu`, `fedora`, `arch`, `opensuse`)
- `VERSION` (string): OS version from `/etc/os-release` if available
- `PKG_MGR` (string): Package manager name (`apt`, `dnf`, `yum`, `pacman`, `zypper`, or `unknown`)
- `UPDATE_CMD` (string): Command to update package lists
- `UPGRADE_CMD` (string): Command to upgrade packages
- `INSTALL_CMD` (string): Command to install packages

Automatically called on library load.

```bash
detect_platform
echo "Using $PKG_MGR on $PLATFORM"
```

### `queue_install_deps(input_file [required_by])`

Queues packages for installation from a specification file.

**Parameters:**
- `input_file` (path): File containing one package specification per line
- `required_by` (string, optional): Context string for logging; overrides trailing context in spec

**Spec Format:**

```
<command> <platform>[-<version>]:<package> [,<platform>[-<version>]:<package>] [,script:/path/to/script] [,optional] [required_by_context]
```

**Fields:**
- `<command>`: Command name to check and install (e.g., `git`, `docker`)
- `<platform>[-<version>]:<package>`: Package name for specific platform/version
  - Matches exact version if version is specified
  - Matches any version if only platform given
- `script:/path/to/script`: Custom script to run instead of package manager
- `optional`: Skip gracefully if command not found
- `required_by_context`: Appended to logs (e.g., "required by myapp")

**Examples:**

```
git ubuntu:git,fedora:git,alpine:git
docker debian:docker.io,fedora:docker,arch:docker,script:/tmp/install-docker.sh,required by build-system
gcc ubuntu:build-essential,fedora:gcc-c++ gcc-gfortran
node optional
```

**Behavior:**
- Skips if command already installed
- Matches platform first exact version, then any version
- Falls back to custom script if platform not matched
- Skips optional dependencies if not found on platform
- Logs all decisions at INFO/WARN/ERROR level

```bash
# Create spec file
cat > /tmp/deps.txt <<'EOF'
git ubuntu:git,fedora:git,arch:git,required by myapp
docker ubuntu:docker.io,fedora:docker,arch:docker
gcc ubuntu:build-essential,fedora:gcc-c++
node ubuntu:nodejs,fedora:nodejs,arch:nodejs,optional
EOF

# Queue packages
queue_install_deps /tmp/deps.txt
```

### `install_deps()`

Executes queued package installations after updating package lists once.

Updates package manager cache on first call, then installs all queued packages together.

```bash
queue_install_deps /tmp/deps.txt
install_deps  # Updates cache + installs all packages
```

### `upgrade_packages()`

Upgrades all installed packages using the detected package manager.

```bash
upgrade_packages
```

## Usage Example

```bash
#!/usr/bin/env bash
eval "$(require.d source logging)"
eval "$(require.d source package_management)"

# Create dependency specification
cat > /tmp/build-deps.txt <<'EOF'
git ubuntu:git,fedora:git,arch:git
make ubuntu:make,fedora:make,arch:make
gcc ubuntu:build-essential,fedora:gcc-c++,arch:base-devel
EOF

# Queue and install
queue_install_deps /tmp/build-deps.txt "build-environment"
install_deps

echo "Build dependencies installed"
```

## Variables

Global variables set by `detect_platform()`:

| Variable | Type | Description |
| -------- | ---- | ----------- |
| `PLATFORM` | string | OS platform ID (e.g., ubuntu, fedora) |
| `VERSION` | string | OS version if available |
| `PKG_MGR` | string | Package manager name |
| `UPDATE_CMD` | string | Cache update command |
| `UPGRADE_CMD` | string | Package upgrade command |
| `INSTALL_CMD` | string | Package install command |
| `batch_packages` | array | Queued packages awaiting installation |
| `UPDATED` | int | Internal flag for cache update state |

## Notes

- All package manager commands execute with `sudo_if_possible`, which prompts for password only if needed
- Commands are checked with `has_command` before queuing installation
- The library is idempotent: running `detect_platform` multiple times is safe
- Version matching requires exact format in spec file (e.g., `ubuntu-22.04`)
