#!/bin/bash
set -euo pipefail

# =============================================================================
# Backup Script - Export current system state before making changes
# =============================================================================

BACKUP_DIR="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "=== Dotfiles Backup ==="
echo "Backup directory: $BACKUP_DIR"
echo ""

# Backup Homebrew packages
echo "Backing up Homebrew packages..."
if command -v brew &>/dev/null; then
    brew bundle dump --file="$BACKUP_DIR/Brewfile" --force
    brew list --versions > "$BACKUP_DIR/brew-list.txt"
    echo "  ✓ Brewfile and package list saved"
else
    echo "  ⚠ Homebrew not installed, skipping"
fi

# Backup global npm packages
echo "Backing up global npm packages..."
if command -v npm &>/dev/null; then
    npm list -g --depth=0 > "$BACKUP_DIR/npm-global.txt" 2>/dev/null || true
    echo "  ✓ npm global packages saved"
fi

# Backup global bun packages
echo "Backing up global bun packages..."
if command -v bun &>/dev/null; then
    bun pm ls -g > "$BACKUP_DIR/bun-global.txt" 2>/dev/null || true
    echo "  ✓ bun global packages saved"
fi

# Backup mise/runtime versions
echo "Backing up runtime versions..."
if command -v mise &>/dev/null; then
    mise list > "$BACKUP_DIR/mise-list.txt" 2>/dev/null || true
    echo "  ✓ mise versions saved"
elif command -v fnm &>/dev/null; then
    fnm list > "$BACKUP_DIR/fnm-list.txt" 2>/dev/null || true
    echo "  ✓ fnm versions saved"
fi

# Backup shell config
echo "Backing up shell configuration..."
[ -f "$HOME/.zshrc" ] && cp "$HOME/.zshrc" "$BACKUP_DIR/zshrc"
[ -f "$HOME/.bashrc" ] && cp "$HOME/.bashrc" "$BACKUP_DIR/bashrc"
[ -f "$HOME/.bash_profile" ] && cp "$HOME/.bash_profile" "$BACKUP_DIR/bash_profile"
echo "  ✓ Shell configs saved"

# Backup git config
echo "Backing up git configuration..."
if [ -f "$HOME/.gitconfig" ]; then
    cp "$HOME/.gitconfig" "$BACKUP_DIR/gitconfig"
    echo "  ✓ Git config saved"
fi
if [ -f "$HOME/.gitignore_global" ]; then
    cp "$HOME/.gitignore_global" "$BACKUP_DIR/gitignore_global"
    echo "  ✓ Global gitignore saved"
fi

# Backup SSH config (excluding keys for security)
echo "Backing up SSH configuration..."
if [ -f "$HOME/.ssh/config" ]; then
    cp "$HOME/.ssh/config" "$BACKUP_DIR/ssh_config"
    echo "  ✓ SSH config saved (keys not included for security)"
fi

# Backup VS Code extensions
echo "Backing up VS Code extensions..."
if command -v code &>/dev/null; then
    code --list-extensions > "$BACKUP_DIR/vscode-extensions.txt" 2>/dev/null || true
    echo "  ✓ VS Code extensions saved"
fi

# Backup Zed settings
echo "Backing up Zed settings..."
if [ -f "$HOME/.config/zed/settings.json" ]; then
    cp "$HOME/.config/zed/settings.json" "$BACKUP_DIR/zed-settings.json"
    echo "  ✓ Zed settings saved"
fi

# Backup starship config
echo "Backing up starship config..."
if [ -f "$HOME/.config/starship.toml" ]; then
    cp "$HOME/.config/starship.toml" "$BACKUP_DIR/starship.toml"
    echo "  ✓ Starship config saved"
fi

# Backup Neovim config reference
echo "Backing up Neovim plugin lock..."
if [ -f "$HOME/.config/nvim/lazy-lock.json" ]; then
    cp "$HOME/.config/nvim/lazy-lock.json" "$BACKUP_DIR/nvim-lazy-lock.json"
    echo "  ✓ Neovim plugin lock saved"
fi

# Export macOS defaults (selected domains)
echo "Backing up macOS preferences..."
{
    echo "# Dock preferences"
    defaults read com.apple.dock 2>/dev/null || true
    echo ""
    echo "# Finder preferences"
    defaults read com.apple.finder 2>/dev/null || true
    echo ""
    echo "# Global preferences"
    defaults read NSGlobalDomain 2>/dev/null || true
} > "$BACKUP_DIR/macos-defaults.txt"
echo "  ✓ macOS defaults saved"

# Create restore instructions
cat > "$BACKUP_DIR/RESTORE.md" << 'EOF'
# Restore Instructions

## Homebrew
```bash
brew bundle --file=Brewfile
```

## npm global packages
```bash
# Review npm-global.txt and install needed packages
```

## VS Code extensions
```bash
cat vscode-extensions.txt | xargs -L 1 code --install-extension
```

## Shell config
```bash
cp zshrc ~/.zshrc
```

## Git config
```bash
cp gitconfig ~/.gitconfig
cp gitignore_global ~/.gitignore_global
```

## SSH config
```bash
cp ssh_config ~/.ssh/config
chmod 600 ~/.ssh/config
```
EOF

echo ""
echo "=== Backup Complete ==="
echo ""
echo "Backup saved to: $BACKUP_DIR"
echo "Contents:"
ls -la "$BACKUP_DIR"
echo ""
echo "Review RESTORE.md for restoration instructions."
