#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== macOS Dotfiles Setup ==="
echo ""

# Run macOS defaults first (before installing anything)
echo "Step 1: Configuring macOS defaults..."
"$SCRIPT_DIR/macos/macos.sh"
echo ""

# Setup ZSH and Oh My Zsh
echo "Step 2: Setting up ZSH..."
"$SCRIPT_DIR/macos/setup_zsh.sh"
echo ""

# Install Homebrew and packages
echo "Step 3: Installing Homebrew packages..."
"$SCRIPT_DIR/macos/brew.sh"
echo ""

# Setup Python
echo "Step 4: Setting up Python..."
"$SCRIPT_DIR/macos/python.sh"
echo ""

# Setup git defaults
echo "Step 5: Configuring git..."
"$SCRIPT_DIR/macos/git.sh"
echo ""

# Symlink neovim config
echo "Step 6: Symlinking Neovim configuration..."
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    echo "Backing up existing nvim config to ~/.config/nvim.bak"
    mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi
mkdir -p "$HOME/.config"
ln -sf "$SCRIPT_DIR/neovim/nvim" "$HOME/.config/nvim"
echo "Neovim config symlinked to ~/.config/nvim"
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Open Neovim to install plugins: nvim"
echo "  3. Some macOS changes may require a logout/restart"
