# require.d

A minimal, portable mechanism for dynamically sourcing shell libraries, with
optional auto-installation from remote sources.

Works in **bash** (3.2+) and **zsh** (5+).

---

## Quick start

```sh
# 1. Install (one time)
curl -fsSL https://example.com/require.d -o require.d
chmod +x require.d
./require.d install           # --user by default; use --system as root

# 2. Use in any script
$(require.d source)           # loads require() into the current shell

require logging               # source a local library
require colors 'git://git@github.com:user/shell-colors'   # auto-install if missing
```

---

## Installation

### User install (default for non-root)

```sh
require.d install
# or explicitly:
require.d install --user
```

Installs to:

| File | Path |
|---|---|
| Runtime library | `~/.local/require.d/required.sh` |
| Binary symlink  | `~/.local/bin/require.d` |

Make sure `~/.local/bin` is on your `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### System install (default for root)

```sh
sudo require.d install
# or:
sudo require.d install --system
```

Installs to:

| File | Path |
|---|---|
| Runtime library | `/usr/lib/require.d/required.sh` |
| Binary symlink  | `/usr/bin/require.d` |

Both install commands are **idempotent** — safe to re-run.

---

## CLI reference

```
require.d source
```
Emits a `source <path>` command that loads the `require()` runtime.  Use it
at the top of any script:

```sh
$(require.d source)
```

```
require.d install [--user | --system]
```
Install require.d to the system (see above).

```
require.d help
require.d version
```

---

## Runtime API

### `require <library> [URI]`

Source a library by name, searching the configured directory list.  If the
library is not found locally and a URI is provided, it is installed
automatically.

```sh
# Source a local library
require logging

# Source with auto-install from git
require colors 'git://git@github.com:user/shell-colors'

# Source with auto-install from a tarball
require spinner 'https://example.com/releases/spinner-1.0.tar.gz'

# Source with auto-install via an install script
require mytools 'https://example.com/install/mytools.sh'
```

`require` is idempotent: calling it multiple times with the same library name
is a no-op after the first successful load.

---

## Library resolution

When `require <name>` is called, the search proceeds in this order:

1. Already loaded?  Return immediately (no re-sourcing).
2. Check `REQUIRE_DIRS[]` if set and non-empty.
3. Otherwise build the default search path:
   1. `REQUIRE_DIRS_ADDITIONAL[]` (if set)
   2. `~/.local/require.d/`
   3. `/etc/require.d/`
   4. `/usr/lib/require.d/`
4. For each directory look for, in order:
   - `<dir>/<name>.sh`
   - `<dir>/<name>/index.sh`
5. Stop at the first match and `source` it.
6. If nothing found and a URI was given, run the remote installer then repeat
   step 4.

---

## Remote URI formats

### Git repository

```
git://git@<host>:<path>[:<branch|tag>]
```

Clones via SSH into `~/.local/require.d/<name>/`.  A branch or tag may be
appended after a final `:`.

```sh
# Default branch
require mylib 'git://git@github.com:user/mylib'

# Specific tag
require mylib 'git://git@github.com:user/mylib:v1.2.3'

# Specific branch
require mylib 'git://git@github.com:user/mylib:feature-x'
```

### HTTP(S) tarball

Any `http://` or `https://` URL **not** ending in `.sh` is treated as a
tarball.  Supported formats: `.tar`, `.tar.gz` / `.tgz`, `.tar.bz2` /
`.tbz2`, `.tar.xz` / `.txz`, `.tar.zst`, `.zip`.

```sh
require mylib 'https://example.com/mylib-1.0.tar.gz'
```

The archive is extracted into `~/.local/require.d/<name>/`.
`--strip-components=1` is applied automatically when possible.

### Install script

Any `http://` or `https://` URL ending in `.sh` is downloaded and executed.
The library name is passed as the first argument.  The script is responsible
for placing its files under `~/.local/require.d/<name>/`.

```sh
require mylib 'https://example.com/install/mylib.sh'
```

---

## Customising the search path

### `REQUIRE_DIRS_ADDITIONAL`

Prepend extra directories without replacing the defaults:

```sh
REQUIRE_DIRS_ADDITIONAL=("${SCRIPT_DIR}/lib" "${SCRIPT_DIR}/vendor")
$(require.d source)
```

### `REQUIRE_DIRS`

Replace the entire search path:

```sh
REQUIRE_DIRS=("/opt/myapp/lib" "${HOME}/lib")
$(require.d source)
```

### Restore defaults

```sh
unset REQUIRE_DIRS
unset REQUIRE_DIRS_ADDITIONAL
```

---

## Writing a library

A require.d library is any shell script.  The conventions are:

1. **Single-file library**: place at `<require_dir>/<name>.sh`
2. **Directory library**: place entry point at `<require_dir>/<name>/index.sh`

Recommended guard against double-sourcing:

```sh
# my-library/index.sh
[[ -n "${__MY_LIBRARY_LOADED:-}" ]] && return 0
readonly __MY_LIBRARY_LOADED=1

# … library code …

my_library_hello() {
    printf 'hello from my-library\n'
}
```

See [examples/library-template/index.sh](examples/library-template/index.sh)
for a complete example.

---

## Environment variables

| Variable | Description |
|---|---|
| `REQUIRE_DIRS` | Array — full search path (overrides defaults when non-empty) |
| `REQUIRE_DIRS_ADDITIONAL` | Array — prepended to the default search path |

---

## Dependencies

| Tool | Required for |
|---|---|
| `git` | Git URI installs |
| `curl` or `wget` | HTTP(S) installs |
| `tar` | Tarball extraction (`.tar.*`) |
| `unzip` | Zip extraction (`.zip`) |

All other functionality has no external dependencies beyond a POSIX shell.

---

## Examples

| File | Description |
|---|---|
| [examples/basic.sh](examples/basic.sh) | Bootstrap and source a local library |
| [examples/remote.sh](examples/remote.sh) | Auto-install from git, tarball, and install script |
| [examples/custom-dirs.sh](examples/custom-dirs.sh) | Customise the search path |
| [examples/zsh-compat.zsh](examples/zsh-compat.zsh) | Usage from a zsh script |
| [examples/library-template/index.sh](examples/library-template/index.sh) | Template for writing a library |

---

## File layout (installed)

```
~/.local/
├── bin/
│   └── require.d              → ~/.local/require.d/required.sh  (symlink)
└── require.d/
    ├── required.sh            ← runtime library (this script)
    ├── logging.sh             ← single-file library
    ├── colors/
    │   └── index.sh           ← directory library
    └── spinner/
        └── index.sh
```

---

## License

MIT
