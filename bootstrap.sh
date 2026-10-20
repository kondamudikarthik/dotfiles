#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — Karthik's dotfiles installer
#
# Reads config.yaml and sets up a new Mac from scratch:
#   - Installs Xcode Command Line Tools (git, clang/clang++, make)
#   - Creates ~/repos/personal and ~/repos/work
#   - Installs Homebrew (if missing)
#   - Installs all formulae and casks declared in config.yaml
#   - Installs Oh My Zsh + plugins
#   - Creates symlinks for all dotfiles (incl. per-folder git identity)
#   - Logs in to each GitHub host in config.yaml (personal)
#   - Clones every repo listed in config.yaml
#   - Runs post-install hooks (Rust, Python, Java, ...)
#
# Layout:
#   ~/repos/personal/   personal repos (this dotfiles repo lives here)
#   ~/repos/work/       work repos (cloned separately — not listed in this public repo)
#
# Usage:
#   ./bootstrap.sh [--dry-run] [--help]
#
# To bootstrap a brand-new machine (before you've cloned the repo). It
# installs the Command Line Tools, clones this repo into
# ~/repos/personal/dotfiles and re-runs itself from there:
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/kondamudikarthik/dotfiles/main/bootstrap.sh)"
# =============================================================================

set -uo pipefail

ORIG_ARGS=("$@")

# -----------------------------------------------------------------------------
# Flags
# -----------------------------------------------------------------------------
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      echo "Usage: bootstrap.sh [--dry-run]"
      echo ""
      echo "Options:"
      echo "  --dry-run   Print commands without executing them."
      exit 0
      ;;
    --dry-run)
      DRY_RUN=true
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
  shift
done

[[ "$DRY_RUN" == "true" ]] && echo "⚠️  Running in dry-run mode — no changes will be made."

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

info()    { echo -e "${BOLD}==> $*${RESET}"; }
success() { echo -e "${GREEN}✔  $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠  $*${RESET}"; }
error()   { echo -e "${RED}✘  $*${RESET}" >&2; }

# Exec-or-dry-run wrapper
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] $*"
  else
    eval "$*"
  fi
}

# Signal handling
trap 'echo ""; warn "Interrupted — exiting."; exit 130' SIGINT SIGTERM

GITHUB_USER="${GITHUB_USER:-kondamudikarthik}"
REPOS_DIR="$HOME/repos"
PERSONAL_DIR="$REPOS_DIR/personal"
WORK_DIR="$REPOS_DIR/work"
DEFAULT_DOTFILES_DIR="$PERSONAL_DIR/dotfiles"

# -----------------------------------------------------------------------------
# Step 1: Prerequisites (macOS + Xcode Command Line Tools)
# -----------------------------------------------------------------------------
info "Step 1/9: Checking prerequisites..."

OS=$(uname -s)
if [[ "$OS" != "Darwin" ]]; then
  error "This script currently targets macOS only."
  exit 1
fi

# Command Line Tools provide git, clang/clang++, make. Full Xcode is NOT required.
clt_installed() { xcode-select -p &>/dev/null && [[ -x "$(xcode-select -p)/usr/bin/git" ]]; }

if clt_installed; then
  success "Xcode Command Line Tools already installed."
elif [[ "$DRY_RUN" == "true" ]]; then
  echo "  [dry-run] Would run: xcode-select --install (and wait for it to finish)"
else
  warn "Xcode Command Line Tools not found — starting install."
  xcode-select --install &>/dev/null || true
  echo "  A dialog should have appeared. Click Install and wait for it to finish..."
  until clt_installed; do
    sleep 5
  done
  success "Xcode Command Line Tools installed."
fi

# -----------------------------------------------------------------------------
# Locate the dotfiles directory (where this script lives). If we were piped
# from curl there is no repo next to us, so clone it and re-run from there.
# -----------------------------------------------------------------------------
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"

if [[ ! -f "$DOTFILES_DIR/config.yaml" ]]; then
  CLONE_URL="https://github.com/${GITHUB_USER}/dotfiles.git"
  warn "No config.yaml next to this script — cloning $CLONE_URL → $DEFAULT_DOTFILES_DIR"
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] git clone $CLONE_URL $DEFAULT_DOTFILES_DIR, then re-run from there"
    exit 0
  fi
  mkdir -p "$PERSONAL_DIR"
  if [[ ! -d "$DEFAULT_DOTFILES_DIR/.git" ]]; then
    git clone "$CLONE_URL" "$DEFAULT_DOTFILES_DIR" || { error "Clone failed."; exit 1; }
  fi
  exec "$DEFAULT_DOTFILES_DIR/bootstrap.sh" ${ORIG_ARGS[@]+"${ORIG_ARGS[@]}"}
fi

CONFIG="$DOTFILES_DIR/config.yaml"

if [[ "$DOTFILES_DIR" != "$DEFAULT_DOTFILES_DIR" ]]; then
  warn "Dotfiles are at $DOTFILES_DIR, expected $DEFAULT_DOTFILES_DIR. Symlinks will point at the current location."
fi

# In dry-run mode skip the backup prompt — nothing will be changed anyway
if [[ "$DRY_RUN" == "false" ]]; then
  read -rp "Have you backed up any existing config files you care about? (y/n): " _bak
  if [[ "$_bak" =~ ^[Nn] || -z "$_bak" ]]; then
    warn "Please back up your config files first."
    exit 1
  fi
else
  echo "  [dry-run] Skipping backup check."
fi

# -----------------------------------------------------------------------------
# Step 2: Workspace folders
# -----------------------------------------------------------------------------
info "Step 2/9: Creating ~/repos/personal and ~/repos/work..."

run "mkdir -p \"$PERSONAL_DIR\" \"$WORK_DIR\""
success "Workspace ready:  personal → personal repos,  work → work repos."

# -----------------------------------------------------------------------------
# Step 3: Homebrew
# -----------------------------------------------------------------------------
info "Step 3/9: Ensuring Homebrew is installed..."

BREW_INSTALLED=false
if command -v brew &>/dev/null; then
  BREW_INSTALLED=true
  success "Homebrew already installed."
elif [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
  BREW_INSTALLED=true
  success "Homebrew already installed (added to PATH for this session)."
else
  warn "Homebrew not found."
  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] Would install Homebrew via official install script."
    BREW_INSTALLED=false   # brew not actually available; skip brew-dependent checks below
  else
    read -rp "Install Homebrew now? [Y/n]: " _brew
    if [[ ! "$_brew" =~ ^[Nn] ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      # Add brew to PATH for Apple Silicon
      if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
      command -v brew &>/dev/null || { error "Homebrew install failed."; exit 1; }
      BREW_INSTALLED=true
      success "Homebrew installed."
    else
      error "Homebrew is required. Exiting."
      exit 1
    fi
  fi
fi

# Resolve brew prefix once (used later for plugin symlinks)
if [[ "$BREW_INSTALLED" == "true" ]]; then
  BREW_PREFIX="$(brew --prefix)"
else
  BREW_PREFIX="/opt/homebrew"   # sensible default for dry-run output
fi

# -----------------------------------------------------------------------------
# Config parsing — pure bash, no yq needed
# Parses the simple list sections out of config.yaml without any external tool.
# -----------------------------------------------------------------------------

# cfg_list SECTION — prints one item per line from a top-level YAML list section
# e.g. cfg_list formulae  →  ripgrep\nfd\nbat\n...
cfg_list() {
  local section="$1" in_section=false
  while IFS= read -r line; do
    # Detect the section header (e.g. "formulae:")
    if [[ "$line" =~ ^${section}: ]]; then
      in_section=true
      continue
    fi
    # Stop when we hit the next top-level key
    if $in_section && [[ "$line" =~ ^[a-zA-Z] ]]; then
      break
    fi
    # Emit list items (lines starting with "  - ")
    if $in_section && [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
      # Strip leading "  - " and any inline comment
      item="${BASH_REMATCH[1]%%#*}"
      item="$(echo "$item" | xargs)"   # trim whitespace
      [[ -n "$item" ]] && echo "$item"
    fi
  done < "$CONFIG"
}

# cfg_symlinks — prints "repo_rel|home_rel" pairs from the symlinks section
cfg_symlinks() {
  local in_section=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^symlinks: ]]; then
      in_section=true; continue
    fi
    if $in_section && [[ "$line" =~ ^[a-zA-Z] ]]; then
      break
    fi
    if $in_section && [[ "$line" =~ ^[[:space:]]+\"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]+)\" ]]; then
      echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
    fi
  done < "$CONFIG"
}

# cfg_github_hosts — prints "group|host" pairs from the github section
cfg_github_hosts() {
  local in_section=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^github: ]]; then
      in_section=true; continue
    fi
    if $in_section && [[ "$line" =~ ^[a-zA-Z] ]]; then
      break
    fi
    if $in_section && [[ "$line" =~ ^[[:space:]]+([a-z]+):[[:space:]]*\"?([^\"[:space:]]+)\"? ]]; then
      echo "${BASH_REMATCH[1]}|${BASH_REMATCH[2]}"
    fi
  done < "$CONFIG"
}

# cfg_repos — prints "group|url" pairs from the repos section
# (group = personal | work, i.e. the folder under ~/repos)
cfg_repos() {
  local in_section=false group=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^repos: ]]; then
      in_section=true; continue
    fi
    if $in_section && [[ "$line" =~ ^[a-zA-Z] ]]; then
      break
    fi
    $in_section || continue
    if [[ "$line" =~ ^[[:space:]]+([a-z]+):[[:space:]]*$ ]]; then
      group="${BASH_REMATCH[1]}"
    elif [[ -n "$group" && "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
      local url="${BASH_REMATCH[1]%%#*}"
      url="$(echo "$url" | xargs)"
      [[ -n "$url" ]] && echo "${group}|${url}"
    fi
  done < "$CONFIG"
}

# cfg_omz_install — returns "true" or "false"
cfg_omz_install() {
  grep -A1 '^oh_my_zsh:' "$CONFIG" | grep 'install:' | awk '{print $2}' | tr -d '"'
}

# cfg_hooks — prints hook lines as "description|||cmd|||skip_if"
cfg_hooks() {
  local desc="" cmd="" skip_if="" in_post=false
  while IFS= read -r line; do
    if [[ "$line" =~ ^post_install: ]]; then
      in_post=true; continue
    fi
    if $in_post && [[ "$line" =~ ^[a-zA-Z] ]]; then
      break
    fi
    if $in_post; then
      if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+description:[[:space:]]+\"(.*)\" ]]; then
        # Flush previous hook if any
        if [[ -n "$desc" ]]; then
          echo "${desc}|||${cmd}|||${skip_if}"
          desc=""; cmd=""; skip_if=""
        fi
        desc="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^[[:space:]]+cmd:[[:space:]]+\"(.*)\" ]]; then
        cmd="${BASH_REMATCH[1]}"
      elif [[ "$line" =~ ^[[:space:]]+skip_if:[[:space:]]+\"(.*)\" ]]; then
        skip_if="${BASH_REMATCH[1]}"
      fi
    fi
  done < "$CONFIG"
  # Flush last hook
  [[ -n "$desc" ]] && echo "${desc}|||${cmd}|||${skip_if}"
}

# -----------------------------------------------------------------------------
# Step 4: Homebrew formulae & casks
# -----------------------------------------------------------------------------
info "Step 4/9: Installing Homebrew packages from config.yaml..."

FORMULAE=()
while IFS= read -r formula; do
  [[ -n "$formula" ]] && FORMULAE+=("$formula")
done < <(cfg_list formulae)

if [[ ${#FORMULAE[@]} -gt 0 ]]; then
  echo "  ${#FORMULAE[@]} formulae declared in config.yaml:"
  for formula in "${FORMULAE[@]}"; do
    if [[ "$BREW_INSTALLED" == "true" ]] && brew list --formula "$formula" &>/dev/null 2>&1; then
      echo "    ✔ $formula (already installed)"
    else
      echo "    Installing $formula..."
      run "brew install $formula" || warn "$formula failed to install — skipping"
    fi
  done
fi

CASKS=()
while IFS= read -r cask; do
  [[ -n "$cask" ]] && CASKS+=("$cask")
done < <(cfg_list casks)

if [[ ${#CASKS[@]} -gt 0 ]]; then
  echo "  ${#CASKS[@]} casks declared in config.yaml:"
  for cask in "${CASKS[@]}"; do
    if [[ "$BREW_INSTALLED" == "true" ]] && brew list --cask "$cask" &>/dev/null 2>&1; then
      echo "    ✔ $cask (already installed via brew)"
    else
      echo "    Installing $cask..."
      # --force lets brew take ownership of apps already in /Applications
      # (e.g. manually installed before running bootstrap)
      run "brew install --cask --force $cask" || warn "$cask failed to install — skipping"
    fi
  done
fi

success "All packages processed."

# -----------------------------------------------------------------------------
# Step 5: Oh My Zsh
# -----------------------------------------------------------------------------
info "Step 5/9: Setting up Oh My Zsh..."

OMZ_INSTALL=$(cfg_omz_install)

if [[ "$OMZ_INSTALL" == "true" ]]; then
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    success "Oh My Zsh already installed."
  else
    echo "  Installing Oh My Zsh..."
    run 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"'
    [[ "$DRY_RUN" == "false" ]] && success "Oh My Zsh installed."
  fi

  ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  run "mkdir -p \"$ZSH_CUSTOM/plugins\""

  # oh-my-zsh requires a file named <plugin>.plugin.zsh inside the plugin dir.
  # Brew installs <plugin>.zsh, so we create a plugin dir with a shim that sources it.
  if [[ -f "$BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    echo "  Setting up zsh-autosuggestions plugin..."
    run "mkdir -p \"$ZSH_CUSTOM/plugins/zsh-autosuggestions\""
    run "echo 'source $BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh' > \"$ZSH_CUSTOM/plugins/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh\""
  else
    warn "zsh-autosuggestions not found at $BREW_PREFIX/share — skipping"
  fi

  if [[ -f "$BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    echo "  Setting up zsh-syntax-highlighting plugin..."
    run "mkdir -p \"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting\""
    run "echo 'source $BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh' > \"$ZSH_CUSTOM/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh\""
  else
    warn "zsh-syntax-highlighting not found at $BREW_PREFIX/share — skipping"
  fi
else
  echo "  Skipping Oh My Zsh (disabled in config.yaml)."
fi

# -----------------------------------------------------------------------------
# Step 6: Dotfile symlinks
# -----------------------------------------------------------------------------
info "Step 6/9: Creating symlinks..."

#######################################
# symlink src dst
# Backs up dst if it exists and isn't already a symlink.
#######################################
symlink() {
  local src="$1" dst="$2"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] link  $src  →  $dst"
    return
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -e "$dst" && ! -L "$dst" ]]; then
    warn "Backing up $dst → ${dst}.bak"
    mv "$dst" "${dst}.bak"
  elif [[ -L "$dst" ]]; then
    rm "$dst"
  fi

  ln -sf "$src" "$dst"
  echo "  linked $src → $dst"
}

# Read symlink map from config.yaml via pure-bash parser
while IFS= read -r pair; do
  repo_rel="${pair%%|*}"
  home_rel="${pair#*|}"

  src="$DOTFILES_DIR/$repo_rel"
  dst="$HOME/$home_rel"

  if [[ -e "$src" || -d "$src" ]]; then
    symlink "$src" "$dst"
  else
    warn "Source not found, skipping: $src"
  fi
done < <(cfg_symlinks)

success "Symlinks processed."

# -----------------------------------------------------------------------------
# Step 7: GitHub logins (hosts from config.yaml)
# git credentials for these hosts are wired to `gh` in git/.gitconfig.
# -----------------------------------------------------------------------------
info "Step 7/9: Logging in to GitHub..."

while IFS= read -r pair; do
  group="${pair%%|*}"
  host="${pair#*|}"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  [dry-run] gh auth login --hostname $host ($group)"
  elif ! command -v gh &>/dev/null; then
    warn "gh not installed — skipping login to $host"
  elif gh auth status --hostname "$host" &>/dev/null; then
    success "Already logged in to $host ($group) as $(gh api user --hostname "$host" -q .login 2>/dev/null)."
  else
    echo "  Logging in to $host ($group) — a browser window will open..."
    gh auth login --hostname "$host" --git-protocol https --web \
      || warn "Login to $host failed — run: gh auth login --hostname $host"
  fi
done < <(cfg_github_hosts)

success "GitHub logins processed."

# -----------------------------------------------------------------------------
# Step 8: Clone repos (list from config.yaml)
# -----------------------------------------------------------------------------
info "Step 8/9: Cloning repos..."

while IFS= read -r pair; do
  group="${pair%%|*}"
  url="${pair#*|}"

  name="$(basename "$url" .git)"
  dst="$REPOS_DIR/$group/$name"

  if [[ -d "$dst/.git" ]]; then
    echo "    ✔ $group/$name (already cloned)"
  elif [[ -e "$dst" ]]; then
    warn "$dst exists but isn't a git repo — skipping $url"
  else
    echo "    Cloning $url → $group/$name"
    run "mkdir -p \"$REPOS_DIR/$group\" && git clone \"$url\" \"$dst\"" || warn "Clone of $url failed — skipping"
  fi
done < <(cfg_repos)

success "Repos processed."

# -----------------------------------------------------------------------------
# Step 9: Post-install hooks
# -----------------------------------------------------------------------------
info "Step 9/9: Running post-install hooks..."

while IFS= read -r hook_line; do
  desc="${hook_line%%|||*}"
  rest="${hook_line#*|||}"
  cmd="${rest%%|||*}"
  skip_if="${rest#*|||}"

  echo "  Hook: $desc"

  # Evaluate skip condition (always show in dry-run so you can see what would run)
  if [[ "$DRY_RUN" == "false" && -n "$skip_if" ]] && eval "$skip_if" &>/dev/null; then
    echo "    ↳ skipped (already done)"
    continue
  fi

  run "$cmd"
  [[ "$DRY_RUN" == "false" ]] && echo "    ↳ done"
done < <(cfg_hooks)

success "Post-install hooks complete."

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
echo ""
if [[ "$DRY_RUN" == "true" ]]; then
  echo -e "${YELLOW}${BOLD}Dry-run complete. No changes were made.${RESET}"
  echo "  Run without --dry-run to apply everything."
else
  echo -e "${GREEN}${BOLD}✔ Bootstrap complete! Open a new terminal (or run: exec zsh) to get started.${RESET}"
  echo ""
  echo "  Tips:"
  echo "  • Work repos go in ~/repos/work, personal ones in ~/repos/personal"
  echo "  • Edit ~/repos/personal/dotfiles/config.yaml to add tools or repos"
  echo "  • Re-run bootstrap.sh any time — it's idempotent"
  echo "  • zed .   → open current directory in Zed"
  echo "  • rg, fd, bat, eza, fzf, zoxide are all ready to go"
fi
echo ""
