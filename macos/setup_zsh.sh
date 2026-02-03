#!/bin/bash
set -uo pipefail

errors=()
ZSHRC="$HOME/.zshrc"

record_error() {
    local message="$1"
    errors+=("$message")
    if [ -n "${SETUP_ERRORS_FILE:-}" ]; then
        printf "%s\n" "$message" >> "$SETUP_ERRORS_FILE"
    fi
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

# Ensure .zshrc exists
run_step "Ensuring ~/.zshrc exists" touch "$ZSHRC"

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    run_step "Installing Oh My Zsh" bash -c "curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh -s -- --unattended"
else
    echo "Oh My Zsh is already installed"
fi

# Install ZSH plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    run_step "Installing zsh-autosuggestions" git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
else
    echo "zsh-autosuggestions already installed"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    run_step "Installing zsh-syntax-highlighting" git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
else
    echo "zsh-syntax-highlighting already installed"
fi

# zsh-completions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-completions" ]; then
    run_step "Installing zsh-completions" git clone https://github.com/zsh-users/zsh-completions "$ZSH_CUSTOM/plugins/zsh-completions"
else
    echo "zsh-completions already installed"
fi

# Source aliases in .zshrc
ALIASES_LINE="source ~/dotfiles/macos/aliases.sh"
if ! grep -qxF "$ALIASES_LINE" "$ZSHRC" 2>/dev/null; then
    run_step "Adding aliases.sh to .zshrc" bash -c "cat >> \"$ZSHRC\" <<EOF

# Dotfiles aliases
$ALIASES_LINE
EOF"
else
    echo "aliases.sh already sourced in .zshrc"
fi

# Add plugins to .zshrc if not already configured
if grep -q "^plugins=(" "$ZSHRC"; then
    if ! grep -q "zsh-autosuggestions" "$ZSHRC"; then
        echo ""
        echo "NOTE: Add these plugins to your .zshrc plugins=(...) line:"
        echo "  plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions)"
    fi
fi

# Setup zoxide (smarter cd) if installed
if command -v zoxide &>/dev/null; then
    if ! grep -qF "zoxide init" "$ZSHRC" 2>/dev/null; then
        run_step "Adding zoxide to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# Zoxide - smarter cd
eval \"\$(zoxide init zsh)\"
EOF"
    fi
fi

# Setup mise (polyglot runtime manager) if installed
if command -v mise &>/dev/null; then
    if ! grep -qF "mise activate" "$ZSHRC" 2>/dev/null; then
        run_step "Adding mise to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# Mise - Runtime version manager
eval \"\$(mise activate zsh)\"
EOF"
    fi
fi

# Setup fzf keybindings if installed
if command -v fzf &>/dev/null; then
    if ! grep -qF "fzf --zsh" "$ZSHRC" 2>/dev/null; then
        run_step "Adding fzf keybindings to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# FZF keybindings
source <(fzf --zsh)
EOF"
    fi
fi

# Setup starship prompt if installed
if command -v starship &>/dev/null; then
    if ! grep -qF "starship init" "$ZSHRC" 2>/dev/null; then
        run_step "Adding starship to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# Starship prompt
eval \"\$(starship init zsh)\"
EOF"
    fi
fi

# Setup direnv if installed
if command -v direnv &>/dev/null; then
    if ! grep -qF "direnv hook" "$ZSHRC" 2>/dev/null; then
        run_step "Adding direnv to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# Direnv - auto-load env vars
eval \"\$(direnv hook zsh)\"
EOF"
    fi
fi

# Install or upgrade Bun
if command -v bun &>/dev/null; then
    run_step "Upgrading Bun" bun upgrade
elif [ -x "$HOME/.bun/bin/bun" ]; then
    run_step "Upgrading Bun" "$HOME/.bun/bin/bun" upgrade
else
    run_step "Installing Bun" bash -c "curl -fsSL https://bun.sh/install | bash"
fi

# Add Bun to PATH in .zshrc
if ! grep -qF "BUN_INSTALL" "$ZSHRC" 2>/dev/null; then
    run_step "Adding Bun to .zshrc" bash -c "cat >> \"$ZSHRC\" <<'EOF'

# Bun
export BUN_INSTALL=\"\$HOME/.bun\"
export PATH=\"\$BUN_INSTALL/bin:\$PATH\"
EOF"
fi

echo ""
echo "ZSH setup complete!"
echo "Remember to restart your terminal or run: source ~/.zshrc"

if [ -z "${SETUP_ERRORS_FILE:-}" ] && ((${#errors[@]} > 0)); then
    echo ""
    echo "ZSH setup completed with errors:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
