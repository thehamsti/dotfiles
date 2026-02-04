#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ERRORS_FILE="$(mktemp -t setup_macos_errors.XXXXXX 2>/dev/null || printf "/tmp/setup_macos_errors.%s" "$$")"
errors=()

record_error() {
    local message="$1"
    errors+=("$message")
}

run_step() {
    local label="$1"
    shift
    echo "$label"
    if "$@"; then
        echo "  ✓ OK"
    else
        local status=$?
        echo "  ✗ Failed (exit $status)"
        record_error "$label (exit $status)"
    fi
}

echo "=== macOS Dotfiles Setup ==="
echo ""

# Run macOS defaults first (before installing anything)
export SETUP_ERRORS_FILE="$ERRORS_FILE"
run_step "Step 1: Configuring macOS defaults..." "$SCRIPT_DIR/macos/macos.sh"
echo ""

# Setup ZSH and Oh My Zsh
run_step "Step 2: Setting up ZSH..." "$SCRIPT_DIR/macos/setup_zsh.sh"
echo ""

# Install Homebrew and packages
run_step "Step 3: Installing Homebrew packages..." "$SCRIPT_DIR/macos/brew.sh"
echo ""

# Setup Python
run_step "Step 4: Setting up Python..." "$SCRIPT_DIR/macos/python.sh"
echo ""

# Setup git defaults
run_step "Step 5: Configuring git..." "$SCRIPT_DIR/macos/git.sh"
echo ""

# Symlink neovim config
echo "Step 6: Symlinking Neovim configuration..."
if [ -d "$HOME/.config/nvim" ] && [ ! -L "$HOME/.config/nvim" ]; then
    run_step "Backing up existing nvim config to ~/.config/nvim.bak" mv "$HOME/.config/nvim" "$HOME/.config/nvim.bak"
fi
run_step "Ensuring ~/.config exists" mkdir -p "$HOME/.config"
run_step "Symlinking Neovim config to ~/.config/nvim" ln -sf "$SCRIPT_DIR/neovim/nvim" "$HOME/.config/nvim"
echo ""

# Symlink global gitignore
run_step "Step 7: Symlinking global gitignore..." ln -sf "$SCRIPT_DIR/gitignore_global" "$HOME/.gitignore_global"
echo ""

# Symlink starship config if it exists
if [ -f "$SCRIPT_DIR/starship.toml" ]; then
    echo "Step 8: Symlinking starship config..."
    if [ -f "$HOME/.config/starship.toml" ] && [ ! -L "$HOME/.config/starship.toml" ]; then
        run_step "Backing up existing starship config to ~/.config/starship.toml.bak" mv "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.bak"
    fi
    run_step "Ensuring ~/.config exists" mkdir -p "$HOME/.config"
    run_step "Symlinking starship config to ~/.config/starship.toml" ln -sf "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    echo ""
fi

# Symlink tmux config
if [ -f "$SCRIPT_DIR/tmux/tmux.conf" ]; then
    echo "Step 9: Symlinking tmux config..."
    if [ -f "$HOME/.config/tmux/tmux.conf" ] && [ ! -L "$HOME/.config/tmux/tmux.conf" ]; then
        run_step "Backing up existing tmux config to ~/.config/tmux/tmux.conf.bak" mv "$HOME/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf.bak"
    fi
    if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
        run_step "Backing up existing ~/.tmux.conf to ~/.tmux.conf.bak" mv "$HOME/.tmux.conf" "$HOME/.tmux.conf.bak"
    fi
    run_step "Ensuring ~/.config/tmux exists" mkdir -p "$HOME/.config/tmux"
    run_step "Symlinking tmux config to ~/.config/tmux/tmux.conf" ln -sf "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    run_step "Symlinking tmux config to ~/.tmux.conf" ln -sf "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
    echo ""
fi

# Install TPM + tmux plugins (automated)
if command -v tmux >/dev/null 2>&1; then
    echo "Step 10: Installing tmux plugins..."
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        run_step "Cloning TPM" git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
    if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        run_step "Installing tmux plugins" "$HOME/.tmux/plugins/tpm/bin/install_plugins"
    else
        echo "TPM install script not found, skipping plugin install"
    fi
    echo ""
else
    echo "Step 10: tmux not found, skipping plugin install"
    echo ""
fi

# Setup SSH config (copy, don't symlink for security)
echo "Step 11: Setting up SSH config..."
run_step "Ensuring ~/.ssh exists" mkdir -p "$HOME/.ssh"
run_step "Setting ~/.ssh permissions" chmod 700 "$HOME/.ssh"
if [ ! -f "$HOME/.ssh/config" ]; then
    run_step "Copying SSH config to ~/.ssh/config" cp "$SCRIPT_DIR/ssh_config" "$HOME/.ssh/config"
    run_step "Setting ~/.ssh/config permissions" chmod 600 "$HOME/.ssh/config"
else
    echo "SSH config already exists, skipping (see ssh_config for template)"
fi
echo ""

echo "=== Setup Complete ==="
echo ""
if [ -f "$ERRORS_FILE" ] && [ -s "$ERRORS_FILE" ]; then
    echo "Detailed errors from child scripts:"
    while IFS= read -r line; do
        [ -n "$line" ] && echo "  - $line"
    done < "$ERRORS_FILE"
    echo ""
fi

if ((${#errors[@]} > 0)); then
    echo "Summary of errors:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    echo ""
fi

echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Open Neovim to install plugins: nvim"
echo "  3. Run 'mise use node@lts' to install Node.js"
echo "  4. Customize ~/.ssh/config if needed"
echo "  5. Some macOS changes may require a logout/restart"
echo ""
echo "Optional: Run ./backup.sh before making system changes"

if ((${#errors[@]} > 0)) || { [ -f "$ERRORS_FILE" ] && [ -s "$ERRORS_FILE" ]; }; then
    exit 1
fi
