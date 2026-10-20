export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME=""

plugins=(
  git
  fzf
  zoxide
  pyenv
  docker
  kubectl
  z
  colored-man-pages
  command-not-found
  zsh-autosuggestions
  zsh-syntax-highlighting
  rust
  golang
)

source "$ZSH/oh-my-zsh.sh"

if [[ -f /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

BREW_PREFIX="$(brew --prefix 2>/dev/null || echo /opt/homebrew)"

export PATH="$HOME/.local/bin:$PATH"

export EDITOR="zed --wait"
export VISUAL="zed --wait"

if command -v uv &>/dev/null; then
  uv python install 3.12 --quiet 2>/dev/null || true
  export PATH="$(uv python find 3.12 | xargs dirname):$PATH"
fi

# Homebrew's rustup is keg-only: its bin holds the rustc/cargo proxies
export PATH="$BREW_PREFIX/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
if command -v rustup &>/dev/null; then
  export RUST_SRC_PATH="$(rustc --print sysroot)/lib/rustlib/src/rust/src"
fi

export GOPATH="$HOME/go"
export PATH="$GOPATH/bin:$PATH"

if command -v fnm &>/dev/null; then
  eval "$(fnm env --use-on-cd)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

[ -f "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" ] && \
  source "$BREW_PREFIX/opt/fzf/shell/key-bindings.zsh"
[ -f "$BREW_PREFIX/opt/fzf/shell/completion.zsh" ] && \
  source "$BREW_PREFIX/opt/fzf/shell/completion.zsh"

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --preview 'bat --style=numbers --color=always {} 2>/dev/null || echo {}'"

if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
fi

if [ -f "$BREW_PREFIX/share/google-cloud-sdk/path.zsh.inc" ]; then
  source "$BREW_PREFIX/share/google-cloud-sdk/path.zsh.inc"
  source "$BREW_PREFIX/share/google-cloud-sdk/completion.zsh.inc"
fi

alias ls="eza --icons --group-directories-first"
alias ll="eza -lah --icons --group-directories-first --git"
alias lt="eza --tree --level=2 --icons"
alias cat="bat --style=auto"
alias grep="rg"
alias find="fd"
alias top="btop"
alias ps="procs"
alias du="dust"

alias g="git"
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias gb="git branch"
alias glog="git log --oneline --graph --decorate"

alias dotfiles="zed $HOME/repos/personal/dotfiles"
alias reload="source ~/.zshrc"

alias py="python3"
alias python="python3"
alias pip="uv pip"
alias venv="uv venv"

alias rm="rm -i"
alias cp="cp -i"
alias mv="mv -i"

alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias path='echo $PATH | tr ":" "\n"'
alias ports='lsof -i -P -n | grep LISTEN'

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#888888"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

HISTSIZE=50000
SAVEHIST=50000
HISTFILE="$HOME/.zsh_history"
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
