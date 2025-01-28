#!/bin/sh

## Install ohmyzsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

## Setup .zshrc by sourcing aliases.sh in it
ALIASES_LINE="source ~/dotfiles/macos/aliases.sh"
grep -qxF "$ALIASES_LINE" ~/.zshrc || echo "$ALIASES_LINE" >>~/.zshrc
