#!/bin/bash
set -euo pipefail

gh_shim="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims/gh"
# Desktop apps need an absolute helper path that survives tool upgrades.
printf -v helper '!%q auth git-credential' "$gh_shim"

for host in github.com gist.github.com; do
    key="credential.https://$host.helper"
    for prefix in /opt/homebrew /usr/local; do
        old_helper="!$prefix/bin/gh auth git-credential"
        if git config --global --fixed-value --get-all "$key" "$old_helper" >/dev/null; then
            if [[ ! -x "$gh_shim" ]]; then
                echo "Cannot repair $host credentials: mise gh shim missing at $gh_shim. Run macos/mise.sh first." >&2
                exit 1
            fi
            git config --global --fixed-value --replace-all "$key" "$helper" "$old_helper"
            echo "Updated $host credential helper to the mise gh shim."
        fi
    done
done
