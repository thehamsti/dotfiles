#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}"
CONFIG="$CONFIG_DIR/config.toml"

if ! command -v mise >/dev/null 2>&1; then
    echo "Install mise first: brew install mise" >&2
    exit 1
fi

mkdir -p "$CONFIG_DIR"
if [[ -e "$CONFIG" || -L "$CONFIG" ]]; then
    if [[ ! "$CONFIG" -ef "$DOTFILES_DIR/mise.toml" ]]; then
        echo "Existing mise config at $CONFIG; merge it with $DOTFILES_DIR/mise.toml first." >&2
        exit 1
    fi
else
    ln -s "$DOTFILES_DIR/mise.toml" "$CONFIG"
fi

mise trust --yes "$DOTFILES_DIR/mise.toml"
# The full plugin includes helpers missing from mise's embedded gcloud copy.
if [[ ! -f "${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/plugins/gcloud/metadata.lua" ]]; then
    mise plugins install vfox:gcloud https://github.com/jdx/vfox-gcloud.git
fi
mise -C "$DOTFILES_DIR" install --yes
mise reshim
bash "$DOTFILES_DIR/macos/git_credentials.sh"

# Shims also serve noninteractive shells, before interactive activation runs.
# shellcheck disable=SC2016
SHIMS_LINE='export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"'
mkdir -p "${ZDOTDIR:-$HOME}"
for profile in "${ZDOTDIR:-$HOME}/.zprofile" "${ZDOTDIR:-$HOME}/.zshrc"; do
    if ! grep -qxF "$SHIMS_LINE" "$profile" 2>/dev/null; then
        printf '\n# mise tools\n%s\n' "$SHIMS_LINE" >>"$profile"
    fi
done
