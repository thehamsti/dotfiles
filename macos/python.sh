#!/bin/bash
set -uo pipefail

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

# Check if uv is installed (should be installed via Brewfile)
if ! command -v uv &>/dev/null; then
    record_error "uv is not installed. Run brew.sh first or install via: brew install uv"
else
    echo "uv is installed: $(uv --version)"
fi

# Install Python versions using uv
echo ""
echo "Installing Python versions 3.10, 3.11, and 3.12..."
if command -v uv &>/dev/null; then
    run_step "Installing Python 3.10, 3.11, 3.12" uv python install 3.10 3.11 3.12
fi

# Set default Python version
echo ""
echo "Setting Python 3.12 as default..."
if command -v uv &>/dev/null; then
    run_step "Setting default Python to 3.12" uv python pin 3.12
fi

# Verify the installation
echo ""
echo "Installed Python versions:"
if command -v uv &>/dev/null; then
    run_step "Listing installed Python versions" uv python list
fi

echo ""
echo "Python setup complete!"

if [ -z "${SETUP_ERRORS_FILE:-}" ] && ((${#errors[@]} > 0)); then
    echo ""
    echo "Python setup completed with errors:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
