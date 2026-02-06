#!/usr/bin/env zsh

# =============================================================================
# Navigation
# =============================================================================

# Easier navigation: .., ..., ...., .....
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."


# Shortcuts
alias dl="cd ~/Downloads"
alias dt="cd ~/Desktop"
alias p="cd ~/projects"

# =============================================================================
# File Listing (using eza if available, fallback to ls)
# =============================================================================

if command -v eza &>/dev/null; then
    alias ls="eza --icons"
    alias ll="eza -lah --icons --git"
    alias la="eza -a --icons"
    alias lt="eza --tree --level=2 --icons"
    alias lta="eza --tree --level=2 -a --icons"
else
    alias ll="ls -lah"
    alias la="ls -A"
fi

# =============================================================================
# Modern CLI replacements
# =============================================================================

# Use bat instead of cat if available
if command -v bat &>/dev/null; then
    alias cat="bat --paging=never"
    alias catp="bat"  # with paging
fi



# Zoxide aliases are set up after zoxide init in .zshrc

# Quick directory back
alias -- -="cd -"

# =============================================================================
# Git
# =============================================================================

alias g="git"
alias gs="git status"
alias gd="git diff"
alias gds="git diff --staged"
alias gl="git log --oneline -20"
alias glo="git log --oneline --graph --all"
alias gp="git push"
alias gpu="git pull"
alias gco="git checkout"
alias gcb="git checkout -b"
alias ga="git add"
alias gaa="git add -A"
alias gc="git commit"
alias gcm="git commit -m"
alias gca="git commit --amend"
alias gb="git branch"
alias gbd="git branch -d"
alias gst="git stash"
alias gstp="git stash pop"
alias gf="git fetch"
alias gr="git rebase"
alias gri="git rebase -i"

# Modern git commands (switch/restore)
alias gsw="git switch"
alias gswc="git switch -c"
alias grs="git restore"
alias grss="git restore --staged"

# =============================================================================
# Docker
# =============================================================================

alias d="docker"
alias dc="docker compose"
alias dps="docker ps"
alias dpsa="docker ps -a"
alias di="docker images"
alias dex="docker exec -it"
alias dlogs="docker logs -f"
alias dprune="docker system prune -af"

# =============================================================================
# Development
# =============================================================================

alias vim="nvim"
alias v="nvim"
alias code="zed"

# Node/Bun
alias nr="npm run"
alias ni="npm install"
alias br="bun run"
alias bi="bun install"
alias bx="bunx"
alias bt="bun test"
alias btw="bun test --watch"

# Python (using uv for package management)
alias py="python3"
alias pip="uv pip"
alias venv="uv venv"
alias activate="source .venv/bin/activate"

# =============================================================================
# System
# =============================================================================

alias week='date +%V'
alias ip="dig +short myip.opendns.com @resolver1.opendns.com"
alias localip="ipconfig getifaddr en0"
alias path='echo $PATH | tr ":" "\n"'

# VPN (WireGuard)
#
# Defaults match the existing ~/.zshrc-style setup:
#   vpnup -> sudo wg-quick up ~/wg0-bastion.conf
# Override:
#   VPN_CONF=~/foo.conf vpnup
#   VPN_PROFILE=wg0 vpnup
_vpn_target() {
    local arg="${1:-}"
    local conf="${VPN_CONF:-$HOME/wg0-bastion.conf}"

    if [[ -n "$arg" ]]; then
        echo "$arg"
        return 0
    fi

    if [[ -f "$conf" ]]; then
        echo "$conf"
        return 0
    fi

    if [[ -n "${VPN_PROFILE:-}" ]]; then
        echo "$VPN_PROFILE"
        return 0
    fi

    echo ""
    return 1
}

vpnup() {
    local target
    target="$(_vpn_target "${1:-}")" || true
    if [[ -z "$target" ]]; then
        echo "Usage: vpnup [wg-profile|/path/to/config.conf]"
        echo "Defaults: VPN_CONF (or ~/wg0-bastion.conf if it exists), then VPN_PROFILE"
        return 2
    fi

    command -v wg-quick >/dev/null 2>&1 || { echo "wg-quick not found (brew install wireguard-tools)"; return 127; }
    sudo wg-quick up "$target"
}

vpndown() {
    local target
    target="$(_vpn_target "${1:-}")" || true
    if [[ -z "$target" ]]; then
        echo "Usage: vpndown [wg-profile|/path/to/config.conf]"
        echo "Defaults: VPN_CONF (or ~/wg0-bastion.conf if it exists), then VPN_PROFILE"
        return 2
    fi

    command -v wg-quick >/dev/null 2>&1 || { echo "wg-quick not found (brew install wireguard-tools)"; return 127; }
    sudo wg-quick down "$target"
}

vpnstatus() {
    command -v wg >/dev/null 2>&1 || { echo "wg not found (brew install wireguard-tools)"; return 127; }
    sudo wg show
}

alias vpn="vpnstatus"

# System update
alias update='sudo softwareupdate -i -a; nup; brew update; brew upgrade; brew cleanup; bun-update-globals'

# Clipboard
alias c="tr -d '\n' | pbcopy"
alias paste="pbpaste"

# Show/hide hidden files in Finder
alias show="defaults write com.apple.finder AppleShowAllFiles -bool true && killall Finder"
alias hide="defaults write com.apple.finder AppleShowAllFiles -bool false && killall Finder"

# Hide/show all desktop icons (useful when presenting)
alias hidedesktop="defaults write com.apple.finder CreateDesktop -bool false && killall Finder"
alias showdesktop="defaults write com.apple.finder CreateDesktop -bool true && killall Finder"

# Lock screen / AFK
alias afk="/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend"

# See what's listening on ports
alias ports='lsof -i -P -n | grep LISTEN'

# =============================================================================
# Nix / nix-darwin
# =============================================================================

# Use /run path as fallback if darwin-rebuild not in PATH yet
_nix_rebuild() { 
  local cmd="darwin-rebuild"
  if ! command -v darwin-rebuild &>/dev/null; then
    cmd="/run/current-system/sw/bin/darwin-rebuild"
  fi
  sudo "$cmd" "$@"
}

_nix_quiet_git_perm() {
  "$@" 2>&1 | grep -v '\.git: Permission denied'
  return ${pipestatus[1]}
}
alias nrs="_nix_rebuild switch --flake ~/dotfiles/nix"    # rebuild & switch
alias nfu="(builtin cd ~/dotfiles/nix && _nix_quiet_git_perm nix flake update)"  # update flake inputs
alias nup="(builtin cd ~/dotfiles/nix && _nix_quiet_git_perm nix flake update) && _nix_quiet_git_perm _nix_rebuild switch --flake ~/dotfiles/nix"  # update all
alias nrb="_nix_rebuild --rollback"                       # rollback to previous
alias ngen="_nix_rebuild --list-generations"              # list generations
alias ngc="nix-collect-garbage -d"                        # garbage collect
alias nsp="nix search nixpkgs"                            # search nixpkgs
alias npkgs='${EDITOR:-nvim} ~/dotfiles/nix/darwin/packages.nix'    # edit nix packages
alias nbrew='${EDITOR:-nvim} ~/dotfiles/nix/darwin/homebrew.nix'    # edit homebrew config

# =============================================================================
# Config shortcuts
# =============================================================================

alias reload='source ~/.zshrc'
alias zshrc='${EDITOR:-nvim} ~/.zshrc'
alias aliases='${EDITOR:-nvim} ~/dotfiles/macos/aliases.sh'
alias dotfiles='cd ~/dotfiles'

# =============================================================================
# MLX Local LLM Server
# =============================================================================

alias mlx-serve="mlx-openai-server launch \
  --model-path mlx-community/GLM-4.7-Flash-8bit \
  --model-type lm \
  --context-length 65536 \
  --port 5001 \
  --host 0.0.0.0 \
  --max-concurrency 2 \
  --queue-timeout 600 \
  --queue-size 10 \
  --tool-call-parser glm4_moe \
  --reasoning-parser glm4_moe \
  --message-converter glm4_moe \
  --enable-auto-tool-choice \
  --log-level INFO \
  --no-log-file"

# =============================================================================
# Misc
# =============================================================================

# Quick HTTP server
alias serve="python3 -m http.server 8000"

# Weather
alias weather="curl wttr.in"

# Generate random password
alias randpw="openssl rand -base64 32"

# Disk usage (dush to avoid shadowing duf tool)
alias dush="du -sh * | sort -hr"

# =============================================================================
# Functions
# =============================================================================

# Make directory and cd into it
mkcd() {
    mkdir -p "$1" && cd "$1" || return
}

# Extract any archive
extract() {
    if [ -f "$1" ]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar x "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick note taking
note() {
    if [ -z "$1" ]; then
        ${EDITOR:-nvim} ~/notes.md
    else
        echo "$(date '+%Y-%m-%d %H:%M'): $*" >> ~/notes.md
    fi
}

# Find process by name
psg() {
    ps aux | grep -v grep | grep -i "$1"
}

# Update all globally installed bun packages to latest
bun-update-globals() {
    # Disable trace/verbose for this function
    setopt localoptions noxtrace noverbose 2>/dev/null

    local bun_install="${BUN_INSTALL:-$HOME/.bun}"
    local global_pkg_json="$bun_install/install/global/package.json"
    local pkg_list
    local -a pkg_names pkg_targets

    echo "Updating globally installed bun packages..."

    if [[ ! -r "$global_pkg_json" ]]; then
        echo "Bun global package list not readable: $global_pkg_json"
        return 1
    fi

    if ! pkg_list="$(python3 - "$global_pkg_json" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

deps = data.get("dependencies") or {}
for name in deps:
    print(name)
PY
    )"; then
        echo "Failed to parse bun global package list: $global_pkg_json"
        return 1
    fi

    pkg_names=("${(@f)pkg_list}")

    if (( ${#pkg_names[@]} == 0 )); then
        echo "No global bun packages found."
        return 0
    fi

    pkg_targets=("${pkg_names[@]/%/@latest}")

    if [[ -n "${BUN_UPDATE_GLOBALS_DRY_RUN:-}" ]]; then
        printf "Would update %d package(s):\n" "${#pkg_targets[@]}"
        printf "  %s\n" "${pkg_targets[@]}"
        return 0
    fi

    bun install --global "${pkg_targets[@]}"
}

# Kill process on a specific port
killport() {
    local port=$1
    if [ -z "$port" ]; then
        echo "Usage: killport <port>"
        return 1
    fi
    local pids=$(lsof -ti:"$port" 2>/dev/null)
    if [ -z "$pids" ]; then
        echo "No process found on port $port"
    else
        echo "$pids" | xargs kill -9
        echo "Killed process(es) on port $port"
    fi
}
