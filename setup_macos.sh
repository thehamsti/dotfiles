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

# Symlink global gitignore
echo "Step 7: Symlinking global gitignore..."
ln -sf "$SCRIPT_DIR/gitignore_global" "$HOME/.gitignore_global"
echo "Global gitignore symlinked to ~/.gitignore_global"
echo ""

# Symlink starship config if it exists
if [ -f "$SCRIPT_DIR/starship.toml" ]; then
    echo "Step 8: Symlinking starship config..."
    ln -sf "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    echo "Starship config symlinked to ~/.config/starship.toml"
    echo ""
fi

# Setup SSH config (copy, don't symlink for security)
echo "Step 9: Setting up SSH config..."
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ]; then
    cp "$SCRIPT_DIR/ssh_config" "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"
    echo "SSH config copied to ~/.ssh/config"
else
    echo "SSH config already exists, skipping (see ssh_config for template)"
fi
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Open Neovim to install plugins: nvim"
echo "  3. Run 'mise use node@lts' to install Node.js"
echo "  4. Customize ~/.ssh/config if needed"
echo "  5. Some macOS changes may require a logout/restart"
echo ""
echo "Optional: Run ./backup.sh before making system changes"
