#!/bin/sh
## Install ohmyzsh
sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

## Setup .zshrc by sourcing aliases.sh in it
echo "source ~/dotfiles/macos/aliases.sh" >>~/.zshrc
