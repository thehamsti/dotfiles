#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

errors=()

pick_brew() {
    local arch
    arch="$(uname -m)"

    # Prefer the correct prefix per-arch, regardless of PATH ordering.
    if [[ "$arch" == "arm64" ]] && [[ -x "/opt/homebrew/bin/brew" ]]; then
        echo "/opt/homebrew/bin/brew"
        return 0
    fi
    if [[ "$arch" == "x86_64" ]] && [[ -x "/usr/local/bin/brew" ]]; then
        echo "/usr/local/bin/brew"
        return 0
    fi

    command -v brew 2>/dev/null || true
}

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

note_error() {
    record_error "$1"
}

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    run_step "Homebrew not installed. Installing Homebrew..." \
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed"
fi

BREW="$(pick_brew)"
if [[ -z "$BREW" ]] || [[ ! -x "$BREW" ]]; then
    note_error "Homebrew not found on PATH, and no brew binary found at /opt/homebrew/bin/brew or /usr/local/bin/brew"
    exit 1
fi

# Ensure brew's env is available even when this script is launched from Finder / a non-login shell.
eval "$("$BREW" shellenv)" >/dev/null 2>&1 || note_error "Failed to eval brew shellenv ($BREW)"

# Update Homebrew
BREW_PREFIX="$("$BREW" --prefix 2>/dev/null || true)"
if [[ -n "$BREW_PREFIX" ]] && [[ -d "$BREW_PREFIX/Library/.homebrew-is-managed-by-nix" ]]; then
    echo "Homebrew is managed by nix-homebrew; skipping brew update"
else
    run_step "Updating Homebrew..." "$BREW" update
fi

# Install from Brewfile
if [[ -f "$BREWFILE" ]]; then
    run_step "Installing packages from Brewfile..." "$BREW" bundle --file="$BREWFILE"
    run_step "Cleaning up..." "$BREW" cleanup
else
    note_error "Brewfile not found at $BREWFILE"
fi

echo ""
if ((${#errors[@]} > 0)); then
    if [ -z "${SETUP_ERRORS_FILE:-}" ]; then
        echo "Brew completed with errors:"
        for err in "${errors[@]}"; do
            echo "  - $err"
        done
    fi
    exit 1
else
    echo "Brew installation complete!"
fi
