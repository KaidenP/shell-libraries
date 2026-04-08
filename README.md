# shell-libraries

Collection of shell script libraries. Works in bash (3.2+) and zsh (5+).

## Installation

### Quick Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaidenP/shell-libraries/refs/heads/master/install.sh)
```

This will auto-detect whether to install as user or system (requires root for system install).

### Manual Install Options

**User Install** (recommended):
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/KaidenP/shell-libraries/refs/heads/master/install.sh) --user
```

**System Install** (requires sudo):
```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/KaidenP/shell-libraries/refs/heads/master/install.sh) --system
```

### Post-Installation

If you used user install, make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add this to your shell profile (`.bashrc`, `.zshrc`, etc.) to make it permanent.

## Libraries

| Library     | Description                                        | README                                             |
| ----------- | -------------------------------------------------- | -------------------------------------------------- |
| `require.d` | mechanism for dynamically sourcing shell libraries | [src/require.d/README.md](src/require.d/README.md) |

## License

MIT
