#!/bin/bash
set -euo pipefail

# Ensure .zshrc exists
touch ~/.zshrc

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "Oh My Zsh is already installed"
fi

# Install ZSH plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    echo "Installing zsh-autosuggestions..."
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
    echo "zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    echo "Installing zsh-syntax-highlighting..."
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
    echo "zsh-syntax-highlighting already installed"
fi

# zsh-completions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    echo "Installing zsh-completions..."
    git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
else
    echo "zsh-completions already installed"
fi

# Source aliases in .zshrc
ALIASES_LINE="source ~/dotfiles/macos/aliases.sh"
if ! grep -qxF "$ALIASES_LINE" ~/.zshrc 2>/dev/null; then
    {
        echo ""
        echo "# Dotfiles aliases"
        echo "$ALIASES_LINE"
    } >> ~/.zshrc
    echo "Added aliases.sh to .zshrc"
else
    echo "aliases.sh already sourced in .zshrc"
fi

# Add plugins to .zshrc if not already configured
if grep -q "^plugins=(" ~/.zshrc; then
    if ! grep -q "zsh-autosuggestions" ~/.zshrc; then
        echo ""
        echo "NOTE: Add these plugins to your .zshrc plugins=(...) line:"
        echo "  plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)"
    fi
fi

# Setup zoxide (smarter cd) if installed
if command -v zoxide &>/dev/null; then
    if ! grep -qF "zoxide init" ~/.zshrc 2>/dev/null; then
        {
            echo ""
            echo "# Zoxide - smarter cd"
            echo "eval \"\$(zoxide init zsh)\""
        } >> ~/.zshrc
        echo "Added zoxide to .zshrc"
    fi
fi

# Setup mise (polyglot runtime manager) if installed
if command -v mise &>/dev/null; then
    if ! grep -qF "mise activate" ~/.zshrc 2>/dev/null; then
        {
            echo ""
            echo "# Mise - Runtime version manager"
            echo "eval \"\$(mise activate zsh)\""
        } >> ~/.zshrc
        echo "Added mise to .zshrc"
    fi
fi

# Setup fzf keybindings if installed
if command -v fzf &>/dev/null; then
    if ! grep -qF "fzf --zsh" ~/.zshrc 2>/dev/null; then
        {
            echo ""
            echo "# FZF keybindings"
            echo "source <(fzf --zsh)"
        } >> ~/.zshrc
        echo "Added fzf to .zshrc"
    fi
fi

# Setup starship prompt if installed
if command -v starship &>/dev/null; then
    if ! grep -qF "starship init" ~/.zshrc 2>/dev/null; then
        {
            echo ""
            echo "# Starship prompt"
            echo "eval \"\$(starship init zsh)\""
        } >> ~/.zshrc
        echo "Added starship to .zshrc"
    fi
fi

# Setup direnv if installed
if command -v direnv &>/dev/null; then
    if ! grep -qF "direnv hook" ~/.zshrc 2>/dev/null; then
        {
            echo ""
            echo "# Direnv - auto-load env vars"
            echo "eval \"\$(direnv hook zsh)\""
        } >> ~/.zshrc
        echo "Added direnv to .zshrc"
    fi
fi

# Install or upgrade Bun
if command -v bun &>/dev/null; then
    echo "Bun is already installed, upgrading..."
    bun upgrade
elif [ -x "$HOME/.bun/bin/bun" ]; then
    echo "Bun is already installed, upgrading..."
    "$HOME/.bun/bin/bun" upgrade
else
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
fi

# Add Bun to PATH in .zshrc
if ! grep -qF "BUN_INSTALL" ~/.zshrc 2>/dev/null; then
    {
        echo ""
        echo "# Bun"
        echo "export BUN_INSTALL=\"\$HOME/.bun\""
        echo "export PATH=\"\$BUN_INSTALL/bin:\$PATH\""
    } >> ~/.zshrc
    echo "Added Bun to .zshrc"
fi

echo ""
echo "ZSH setup complete!"
echo "Remember to restart your terminal or run: source ~/.zshrc"
