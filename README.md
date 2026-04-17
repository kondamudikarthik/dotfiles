# dotfiles

Setup for a new Mac.

## How to run

**Always dry-run first** to preview every action without touching your system:

```bash
./bootstrap.sh --dry-run
```

When you're happy with what it'll do, run for real:

```bash
./bootstrap.sh
```

The script is fully **idempotent** — safe to re-run any time. Already-installed packages are skipped, existing symlinks are refreshed, hooks check their own preconditions before running.

```
./bootstrap.sh --help    # show usage
```

## Two responsibilities, two places to edit

This repo has a clear split:

### 1. `config.yaml` — the installation manifest
Edit this to **add or remove tools**. It controls:
- Which Homebrew formulae (CLI tools) to install
- Which Homebrew casks (GUI apps) to install
- Which Oh My Zsh plugins to enable
- Which dotfiles to symlink and where
- Post-install hooks (Rust, default shell, etc.)

You never need to touch `bootstrap.sh` itself.

### 2. The dotfiles — your tool preferences
Edit these directly to **change how a tool behaves**:

| File | Edit this when you want to… |
|------|----------------------------|
| `zsh/.zshrc` | Add a shell alias, change a plugin, tweak PATH |
| `git/.gitconfig` | Change git aliases, editor, diff settings |
| `git/.gitignore_global` | Ignore new file patterns globally |
| `ghostty/config` | Change terminal font, theme, keybindings |
| `zed/settings.json` | Change editor font, theme, formatter settings |
| `zed/keymap.json` | Remap editor shortcuts |
| `tmux/.tmux.conf` | Change tmux prefix, pane behaviour, colours |
| `starship/starship.toml` | Tweak the shell prompt (opt-in, see `.zshrc`) |

Both `config.yaml` and the dotfiles live in this repo and are checked in — they just serve different purposes.

## Adding a new tool

1. Add it to `config.yaml` under `formulae` or `casks`
2. If it has a config file you want to track, create it in this repo and add a `symlinks` entry
3. Re-run `./bootstrap.sh`

## Machine-local overrides

Create `~/.zshrc.local` for anything you don't want in git (API keys, work-specific paths, secrets). It's sourced automatically at the end of `.zshrc`.

## Key tools installed

- **Ghostty** — My terminal. Fast, GPU-accelerated, and actually pretty.
- **Zed** — Primary editor. `zed .` and you're in.
- **PyCharm CE** — Been using IntelliJ-based IDEs for over a decade. Muscle memory at this point.
- **ripgrep** (`rg`) — grep, but fast enough that you'll actually use it.
- **fd** — find, without the flags you can never remember.
- **bat** — cat with syntax highlighting. Can't go back.
- **eza** — ls that shows git status inline.
- **fzf** — Ctrl+R for history search, Ctrl+T for file picker. Gets out of your way.
- **zoxide** — cd that learns where you actually go. Aliased as `cd`.
- **delta** — Side-by-side git diffs that don't hurt to read.
- **uv** — Python packaging done right. Fast, sane, replaces pip/venv/pyenv.
- **starship** — Shell prompt that shows what you need, nothing you don't.
