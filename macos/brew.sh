#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

errors=()

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

    if command -v brew &>/dev/null; then
        # Add Homebrew to PATH for Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)" || note_error "Failed to eval Homebrew shellenv"
        fi
    else
        note_error "Homebrew install did not add brew to PATH"
    fi
else
    echo "Homebrew is already installed"
fi

# Update Homebrew
run_step "Updating Homebrew..." brew update

# Install from Brewfile
if [[ -f "$BREWFILE" ]]; then
    run_step "Installing packages from Brewfile..." brew bundle --file="$BREWFILE"
    run_step "Cleaning up..." brew cleanup
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
