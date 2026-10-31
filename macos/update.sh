#!/bin/bash
set -uo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: update [--non-interactive] [--no-system] [--dry-run]

Updates global mise tools, remaining Homebrew packages/apps, Bun globals,
and macOS. Authenticates once and refreshes sudo until the run finishes.

  --non-interactive  Never ask for credentials; requires cached sudo for macOS.
  --no-system        Skip macOS updates and the initial sudo authentication.
  --dry-run          Print commands without updating or authenticating.

macOS updates never request an automatic restart. Apple Silicon updates that
need owner authentication may still require installation in System Settings.
EOF
}

non_interactive=0
system_updates=1
dry_run=0
for arg in "$@"; do
    case "$arg" in
    --non-interactive) non_interactive=1 ;;
    --no-system) system_updates=0 ;;
    --dry-run) dry_run=1 ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        echo "Unknown option: $arg" >&2
        usage >&2
        exit 2
        ;;
    esac
done

failures=()
sudo_keeper=""
cleanup() {
    if [[ -n "$sudo_keeper" ]]; then
        pkill -P "$sudo_keeper" 2>/dev/null || true
        kill "$sudo_keeper" 2>/dev/null || true
        wait "$sudo_keeper" 2>/dev/null || true
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

run_step() {
    local label="$1"
    shift
    printf '\n==> %s\n' "$label"
    if ((dry_run)); then
        printf ' %q' "$@"
        printf '\n'
    elif "$@" </dev/null; then
        return 0
    else
        local result=$?
        failures+=("$label (exit $result)")
        printf 'Failed: %s (exit %s); continuing.\n' "$label" "$result" >&2
        return 1
    fi
}

# Package installers must not reopen credential dialogs after the initial login.
export MISE_YES=1 HOMEBREW_NO_ASK=1
export HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_AUTOREMOVE=1 SUDO_ASKPASS=/usr/bin/false

if ((system_updates && ! dry_run)); then
    sudo_args=(-v)
    if ((non_interactive)); then
        sudo_args=(-n -v)
    fi
    if sudo "${sudo_args[@]}"; then
        (
            while sleep 50; do
                sudo -n -v || exit
            done
        ) >/dev/null 2>&1 &
        sudo_keeper=$!
    else
        failures+=("macOS updates: sudo unavailable; run update in a terminal or use --no-system")
        system_updates=0
    fi
fi

if command -v brew >/dev/null 2>&1; then
    if run_step "Refresh Homebrew metadata" brew update; then
        run_step "Upgrade remaining Homebrew formulae" brew upgrade --formula --yes
        run_step "Upgrade Homebrew apps" brew upgrade --cask --yes
        run_step "Clean Homebrew cache" brew cleanup
    fi
fi

# Homebrew updates mise itself before the new plugin code is loaded.
if command -v mise >/dev/null 2>&1; then
    if run_step "Refresh mise plugin definitions" mise plugins update; then
        run_step "Upgrade global mise tools" mise upgrade --global --yes
        run_step "Refresh mise shims" mise reshim
    fi
else
    failures+=("mise is missing; run macos/brew.sh and macos/mise.sh")
fi

global_package_json="${BUN_INSTALL:-$HOME/.bun}/install/global/package.json"
if [[ -f "$global_package_json" ]]; then
    if command -v mise >/dev/null 2>&1; then
        run_step "Upgrade Bun global packages" mise -C "$DOTFILES_DIR" exec bun@latest -- bun update --global --latest
    else
        run_step "Upgrade Bun global packages" bun update --global --latest
    fi
fi

if ((system_updates)); then
    run_step "Install macOS updates" sudo -n softwareupdate --install --all --agree-to-license
fi

if ((${#failures[@]})); then
    printf '\nUpdate finished with failures:\n' >&2
    printf '  - %s\n' "${failures[@]}" >&2
    exit 1
fi
printf '\nUpdate complete.\n'
