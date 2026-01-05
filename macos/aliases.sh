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



# Zoxide aliases (if using zoxide)
if command -v zoxide &>/dev/null; then
    alias cd="z"
    alias cdi="zi"  # interactive directory picker
fi

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

# System update
alias update='sudo softwareupdate -i -a; brew update; brew upgrade; brew cleanup; bun-update-globals'

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
# Config shortcuts
# =============================================================================

alias reload='source ~/.zshrc'
alias zshrc='${EDITOR:-nvim} ~/.zshrc'
alias aliases='${EDITOR:-nvim} ~/dotfiles/macos/aliases.sh'
alias dotfiles='cd ~/dotfiles'

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
    echo "Checking globally installed bun packages..."
    local pkg_list upgraded=0

    # Parse package names and versions from bun pm ls -g
    pkg_list=$(bun pm ls -g 2>/dev/null | tail -n +2 | sed 's/^[├└]── //' | grep -v "^$")

    if [ -z "$pkg_list" ]; then
        echo "No global bun packages found."
        return 0
    fi

    # Use here-string to avoid subshell (variables persist)
    while read -r line; do
        local pkg_name="${line%@*}"
        local current_version="${line##*@}"
        local latest_version

        # Get latest version from npm registry
        latest_version=$(npm view "$pkg_name" version 2>/dev/null)

        if [ -z "$latest_version" ]; then
            echo "  ⚠ $pkg_name: couldn't fetch latest version"
            continue
        fi

        if [ "$current_version" = "$latest_version" ]; then
            continue
        fi

        echo "  ↑ $pkg_name: $current_version → $latest_version"
        bun install --global "${pkg_name}@latest" >/dev/null 2>&1
        ((upgraded++)) || true
    done <<< "$pkg_list"

    if [ "$upgraded" -eq 0 ]; then
        echo "All packages up to date."
    else
        echo "Done. $upgraded package(s) upgraded."
    fi
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
