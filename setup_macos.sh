#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ERRORS_FILE="$(mktemp -t setup_macos_errors.XXXXXX)" || exit 1
errors=()
sudo_keeper=""

cleanup() {
    if [[ -n "$sudo_keeper" ]]; then
        pkill -P "$sudo_keeper" 2>/dev/null || true
        kill "$sudo_keeper" 2>/dev/null || true
        wait "$sudo_keeper" 2>/dev/null || true
    fi
    rm -f "$ERRORS_FILE"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

link_config() { bash "$SCRIPT_DIR/macos/link_config.sh" "$@"; }

load_homebrew_env() {
    local brew_binary shellenv profile brew_init
    brew_binary="$(command -v brew || true)"
    if [[ -z "$brew_binary" ]]; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            brew_binary=/opt/homebrew/bin/brew
        else
            brew_binary=/usr/local/bin/brew
        fi
    fi
    shellenv="$("$brew_binary" shellenv)" || return $?
    eval "$shellenv"
    profile="${ZDOTDIR:-$HOME}/.zprofile"
    mkdir -p "$(dirname "$profile")"
    # shellcheck disable=SC2016
    printf -v brew_init 'eval "$(%q shellenv)"' "$brew_binary"
    if ! grep -qxF "$brew_init" "$profile" 2>/dev/null; then
        printf '\n# Homebrew\n%s\n' "$brew_init" >>"$profile"
    fi
}

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

if ! sudo -v; then
    echo "Setup needs administrator access. Run it in an interactive terminal." >&2
    exit 1
fi
(
    while sleep 50; do sudo -n -v || exit; done
) >/dev/null 2>&1 &
sudo_keeper=$!

# Run macOS defaults first (before installing anything)
export SETUP_ERRORS_FILE="$ERRORS_FILE"
run_step "Step 1: Configuring macOS defaults..." "$SCRIPT_DIR/macos/macos.sh"
echo ""

# Install package managers before configuring shell integrations.
run_step "Step 2: Installing Homebrew packages..." "$SCRIPT_DIR/macos/brew.sh"
run_step "Loading Homebrew environment..." load_homebrew_env
echo ""

run_step "Step 3: Installing mise tools..." bash "$SCRIPT_DIR/macos/mise.sh"
export PATH="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims:$PATH"
echo ""

run_step "Setting up ZSH..." "$SCRIPT_DIR/macos/setup_zsh.sh"
echo ""

run_step "Setting up Herdr config and agent integrations..." bash "$SCRIPT_DIR/macos/herdr.sh"
echo ""

# Enable Touch ID for sudo inside tmux
echo "Step 4: Enabling Touch ID for sudo inside tmux..."
PAM_REATTACH_PATH=""
if [ -f "/opt/homebrew/lib/pam/pam_reattach.so" ]; then
    PAM_REATTACH_PATH="/opt/homebrew/lib/pam/pam_reattach.so"
elif [ -f "/usr/local/lib/pam/pam_reattach.so" ]; then
    PAM_REATTACH_PATH="/usr/local/lib/pam/pam_reattach.so"
fi

if [ -n "$PAM_REATTACH_PATH" ]; then
    run_step "Repairing sudo PAM ownership" sudo -n chown root:wheel /etc/pam.d/sudo
    run_step "Repairing sudo PAM permissions" sudo -n chmod 644 /etc/pam.d/sudo
    run_step "Installing Touch ID configuration in sudo_local" bash "$SCRIPT_DIR/macos/setup_sudo.sh" "$PAM_REATTACH_PATH" /etc/pam.d/sudo_local
else
    echo "pam_reattach not found, skipping (brew install pam-reattach)"
fi
echo ""

# Setup Python
run_step "Step 5: Setting up Python..." "$SCRIPT_DIR/macos/python.sh"
echo ""

# Setup git defaults
run_step "Step 6: Configuring git..." "$SCRIPT_DIR/macos/git.sh"
echo ""

# Powerline is installed in an isolated Python environment by mise.
run_step "Step 7: Verifying Powerline..." mise -C "$SCRIPT_DIR" exec -- powerline-config --help
echo ""

# Symlink neovim config
echo "Step 8: Symlinking Neovim configuration..."
run_step "Symlinking Neovim config to ~/.config/nvim" link_config "$SCRIPT_DIR/neovim/nvim" "$HOME/.config/nvim"
echo ""

# Symlink global gitignore
run_step "Step 9: Symlinking global gitignore..." link_config "$SCRIPT_DIR/gitignore_global" "$HOME/.gitignore_global"
echo ""

# Symlink starship config if it exists
if [ -f "$SCRIPT_DIR/starship.toml" ]; then
    echo "Step 10: Symlinking starship config..."
    run_step "Symlinking starship config to ~/.config/starship.toml" link_config "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    echo ""
fi

# Symlink tmux config
if [ -f "$SCRIPT_DIR/tmux/tmux.conf" ]; then
    echo "Step 11: Symlinking tmux config..."
    run_step "Symlinking tmux config to ~/.config/tmux/tmux.conf" link_config "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    run_step "Symlinking tmux config to ~/.tmux.conf" link_config "$HOME/.config/tmux/tmux.conf" "$HOME/.tmux.conf"
    if [ -d "$SCRIPT_DIR/tmux/scripts" ]; then
        run_step "Symlinking tmux scripts to ~/.config/tmux/scripts" link_config "$SCRIPT_DIR/tmux/scripts" "$HOME/.config/tmux/scripts"
    fi
    echo ""
fi

# Symlink tmux plugins
if [ -d "$SCRIPT_DIR/tmux/plugins" ]; then
    echo "Step 12: Symlinking tmux plugins..."
    run_step "Ensuring ~/.tmux/plugins exists" mkdir -p "$HOME/.tmux/plugins"
    for plugin in "$SCRIPT_DIR"/tmux/plugins/*; do
        [ -d "$plugin" ] || continue
        plugin_name="$(basename "$plugin")"
        run_step "Symlinking tmux plugin: $plugin_name" link_config "$plugin" "$HOME/.tmux/plugins/$plugin_name"
    done
    echo ""
fi

# Symlink Powerline config
if [ -d "$SCRIPT_DIR/powerline" ]; then
    echo "Step 13: Symlinking Powerline config..."
    run_step "Symlinking Powerline config to ~/.config/powerline" link_config "$SCRIPT_DIR/powerline" "$HOME/.config/powerline"
    echo ""
fi

# Symlink tmuxinator config
if [ -d "$SCRIPT_DIR/tmuxinator" ]; then
    echo "Step 14: Symlinking tmuxinator config..."
    run_step "Symlinking tmuxinator config to ~/.tmuxinator" link_config "$SCRIPT_DIR/tmuxinator" "$HOME/.tmuxinator"
    echo ""
fi

# Symlink agents config (Claude Code skills)
if [ -d "$SCRIPT_DIR/agents" ]; then
    echo "Step 15: Symlinking agents config..."
    run_step "Symlinking agents config to ~/.agents" link_config "$SCRIPT_DIR/agents" "$HOME/.agents"
    run_step "Installing shared agent skills..." bash "$SCRIPT_DIR/macos/skills.sh"
    echo ""
fi

# Install TPM + tmux plugins (automated)
if command -v tmux >/dev/null 2>&1; then
    echo "Step 16: Installing tmux plugins..."
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        run_step "Cloning TPM" git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    fi
    if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        # TPM's CLI installer reads TMUX_PLUGIN_MANAGER_PATH from the tmux server's
        # environment. If we set it via `tmux set-environment` without an active
        # session, the server can immediately exit and the variable disappears.
        #
        # Workaround: ensure a server stays alive via a temporary detached session
        # (only when no server is running), set the env var, run the installer,
        # then cleanup the temporary session.
        TPM_INSTALL_SESSION="__tpm_install"
        started_tmp_session=0
        if ! tmux ls >/dev/null 2>&1; then
            run_step "Starting temporary tmux server session" tmux new-session -d -s "$TPM_INSTALL_SESSION"
            started_tmp_session=1
        fi

        run_step "Configuring TPM path" tmux set-environment -g TMUX_PLUGIN_MANAGER_PATH "$HOME/.tmux/plugins"
        run_step "Installing tmux plugins" "$HOME/.tmux/plugins/tpm/bin/install_plugins"

        if [ "$started_tmp_session" -eq 1 ]; then
            run_step "Cleaning up temporary tmux session" tmux kill-session -t "$TPM_INSTALL_SESSION"
        fi
    else
        echo "TPM install script not found, skipping plugin install"
    fi
    echo ""
else
    echo "Step 16: tmux not found, skipping plugin install"
    echo ""
fi

# Setup SSH config (copy, don't symlink for security)
echo "Step 17: Setting up SSH config..."
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
    done <"$ERRORS_FILE"
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
echo "  3. Run 'mise ls' to inspect the installed runtimes and CLI tools"
echo "  4. Customize ~/.ssh/config if needed"
echo "  5. Some macOS changes may require a logout/restart"
echo ""
echo "Optional: Run ./backup.sh before making system changes"

if ((${#errors[@]} > 0)) || { [ -f "$ERRORS_FILE" ] && [ -s "$ERRORS_FILE" ]; }; then
    exit 1
fi
