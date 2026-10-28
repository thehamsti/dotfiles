#!/bin/bash
set -euo pipefail

export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"
if ! command -v powerline-config >/dev/null 2>&1; then
    tmux display-message "Powerline missing: run mise install --yes in ~/dotfiles"
    exit 1
fi
powerline-daemon -q
powerline-config -p "$HOME/.config/powerline" tmux setup
