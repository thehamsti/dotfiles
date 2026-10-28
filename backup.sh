#!/bin/bash
set -euo pipefail

# Shell and Git configs can contain private hostnames or inline credentials.
umask 077
BACKUP_DIR="$(mktemp -d "$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S).XXXXXX")"
failures=()

export_command() {
    local label="$1" output="$2"
    shift 2
    if "$@" >"$BACKUP_DIR/$output"; then
        echo "Saved $label"
    else
        failures+=("$label")
        echo "Failed to export $label; continuing with the remaining backup." >&2
    fi
}

save_file() {
    local source="$1" name="$2"
    if [[ -f "$source" ]]; then
        if ! cp -L "$source" "$BACKUP_DIR/$name"; then
            failures+=("$name")
        fi
    fi
}

echo "Backing up dotfiles to $BACKUP_DIR"
if command -v brew >/dev/null 2>&1; then
    export_command "Homebrew Brewfile" brew-export.log brew bundle dump --file="$BACKUP_DIR/Brewfile" --force
    export_command "Homebrew package versions" brew-list.txt brew list --versions
fi
if command -v npm >/dev/null 2>&1; then
    export_command "npm globals" npm-global.txt npm list -g --depth=0
fi
if command -v bun >/dev/null 2>&1; then
    export_command "Bun globals" bun-global.txt bun pm ls -g
fi
if command -v mise >/dev/null 2>&1; then
    export_command "global mise versions" mise-list.json mise ls --global --json
fi

mise_config="${MISE_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/mise}/config.toml"
bun_global="${BUN_INSTALL:-$HOME/.bun}/install/global"
save_file "$mise_config" mise-config.toml
save_file "${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}" herdr-config.toml
save_file "$bun_global/package.json" bun-global-package.json
save_file "$bun_global/bun.lock" bun-global.lock
save_file "$bun_global/bun.lockb" bun-global.lockb

for name in zshrc zprofile zshenv; do
    save_file "${ZDOTDIR:-$HOME}/.$name" "$name"
done
for name in bashrc bash_profile gitconfig gitignore_global; do
    save_file "$HOME/.$name" "$name"
done
save_file "${XDG_CONFIG_HOME:-$HOME/.config}/git/config" gitconfig-xdg
save_file "$HOME/.ssh/config" ssh_config
save_file "$HOME/.config/zed/settings.json" zed-settings.json
save_file "$HOME/.config/starship.toml" starship.toml
save_file "$HOME/.config/nvim/lazy-lock.json" nvim-lazy-lock.json

if command -v code >/dev/null 2>&1; then
    export_command "VS Code extensions" vscode-extensions.txt code --list-extensions
fi
for domain in com.apple.dock com.apple.finder NSGlobalDomain; do
    export_command "$domain preferences" "$domain.txt" defaults read "$domain"
done

cat >"$BACKUP_DIR/RESTORE.md" <<'EOF'
# Restore instructions

This backup is private. Review the saved files before replacing current config.
SSH private keys and GitHub CLI credential-store files are not copied.
Shell and Git configs can still contain inline secrets; keep this backup private.

## Packages

Run `brew bundle --file=Brewfile` for the saved Homebrew packages.
Copy `mise-config.toml` to `~/.config/mise/config.toml`, then run
`mise install --yes`. A saved file follows a symlink to capture its contents;
restore the intended dotfiles symlink separately if appropriate.

Review `bun-global-package.json`, `bun-global.txt`, and `npm-global.txt` to
reinstall the global packages you need. Bun lockfiles are included when present.

## Shell, Git, and SSH

Copy `zshrc`, `zprofile`, and `zshenv` to their corresponding dotfiles in
`$ZDOTDIR` (or `$HOME`). Copy the saved Git config and ignore file as needed.
Copy `ssh_config` to `~/.ssh/config` and use `chmod 600 ~/.ssh/config`.

## Applications

Copy `herdr-config.toml` to `~/.config/herdr/config.toml` (or your
`HERDR_CONFIG_PATH`). Run `bash ~/dotfiles/macos/herdr.sh` to recreate the
dotfiles config link, completions, and agent integrations instead. Herdr session
state, sockets, logs, and worktrees are not included in this backup.

The backup includes Zed settings, Starship configuration, a Neovim plugin lock,
and a VS Code extension list when available. The selected macOS preferences
are text snapshots for reference, not executable restore scripts.
EOF

echo "Backup saved to $BACKUP_DIR"
if ((${#failures[@]})); then
    printf 'Backup is partial. Failed exports/files:\n' >&2
    printf '  - %s\n' "${failures[@]}" >&2
    exit 1
fi
echo "Backup complete. See RESTORE.md."
