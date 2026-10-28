#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
remove=0
case "${1:-}" in
--remove-homebrew) remove=1 ;;
"") ;;
*)
    echo "Usage: $0 [--remove-homebrew]" >&2
    exit 2
    ;;
esac

bash "$SCRIPT_DIR/mise.sh"
export PATH="${MISE_DATA_DIR:-$HOME/.local/share/mise}/shims:$PATH"
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ASK=1 SUDO_ASKPASS=/usr/bin/false
export HOMEBREW_NO_AUTOREMOVE=1
cd "$SCRIPT_DIR/.."

# Validate every replacement before removing any package, including dependencies.
while IFS=$'\t' read -r kind name tool executable probe; do
    [[ "$kind" == \#* || -z "$kind" ]] && continue
    binary="$(mise which --tool "$tool" "$executable")"
    echo "Checking $name -> $tool ($binary)"
    mise exec "$tool" -- "$binary" "$probe" </dev/null >/dev/null
done <"$SCRIPT_DIR/mise-migrations.tsv"

if ((! remove)); then
    echo "All replacements passed. Use --remove-homebrew to remove redundant Homebrew installs."
    exit 0
fi

backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/homebrew-to-mise/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_dir"
brew bundle dump --file="$backup_dir/Brewfile" --force
brew list --versions >"$backup_dir/versions.txt"
echo "Homebrew restore inventory: $backup_dir"

# Uninstall consumers first; Homebrew's dependency checks stay enabled.
cellar="$(brew --cellar)"
progress=1
while ((progress)); do
    progress=0
    while IFS=$'\t' read -r kind name tool executable probe; do
        [[ "$kind" == \#* || -z "$kind" ]] && continue
        brew list "--$kind" "$name" >/dev/null 2>&1 || continue
        if [[ "$kind" == formula ]]; then
            # Installed recipes also work when the upstream tap has moved.
            formula="$name"
            for receipt in "$cellar/$name"/*/.brew/"$name.rb"; do
                [[ -f "$receipt" ]] && formula="$receipt"
            done
            dependents="$(brew uses --installed "$formula")"
            [[ -n "$dependents" ]] && continue
        fi
        brew uninstall "--$kind" "$name"
        progress=1
    done <"$SCRIPT_DIR/mise-migrations.tsv"
done

echo "Migration complete. Copies still required by other Homebrew packages are retained."
