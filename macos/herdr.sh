#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
PROFILE="${ZDOTDIR:-$HOME}/.zshrc"
failed=()

if ! command -v mise >/dev/null 2>&1; then
    echo "Install mise first: brew install mise" >&2
    exit 1
fi

mise use --global --yes herdr@latest
mise reshim
herdr_bin="$(mise -C "$DOTFILES_DIR" which --tool herdr@latest herdr)"

# Validate before replacing the working config; runtime state stays in its directory.
HERDR_CONFIG_PATH="$DOTFILES_DIR/herdr/config.toml" "$herdr_bin" config check
bash "$DOTFILES_DIR/macos/link_config.sh" "$DOTFILES_DIR/herdr/config.toml" "$CONFIG"

mkdir -p "$(dirname "$PROFILE")"
if ! grep -qxF '# Herdr completions' "$PROFILE" 2>/dev/null; then
    cat >>"$PROFILE" <<'EOF'

# Herdr completions
if command -v herdr >/dev/null 2>&1 && (( $+functions[compdef] )); then
    source <(herdr completion zsh)
fi
EOF
fi

while IFS= read -r target || [[ -n "$target" ]]; do
    case "$target" in '' | \#*) continue ;; esac
    if output="$("$herdr_bin" integration install "$target" 2>&1)"; then
        printf '%s\n' "$output"
    else
        # Herdr requires each agent's first-run config before it can add hooks.
        case "$output" in
        *"directory not found at "*"install "*" first"*)
            printf 'Skipping %s: %s\n' "$target" "$output"
            ;;
        *)
            printf '%s\n' "$output" >&2
            failed+=("$target")
            ;;
        esac
    fi
done <"$DOTFILES_DIR/herdr/integrations.txt"

if ((${#failed[@]})); then
    printf 'Herdr integration setup failed:\n' >&2
    printf '  - %s\n' "${failed[@]}" >&2
    exit 1
fi
echo "Herdr config, completions, and integrations installed. Running sessions remain open."
