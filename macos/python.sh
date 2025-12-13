#!/bin/bash
set -euo pipefail

# Check if uv is installed (should be installed via Brewfile)
if ! command -v uv &>/dev/null; then
    echo "Error: uv is not installed. Run brew.sh first or install via: brew install uv"
    exit 1
fi

echo "uv is installed: $(uv --version)"

# Install Python versions using uv
echo ""
echo "Installing Python versions 3.10, 3.11, and 3.12..."
uv python install 3.10 3.11 3.12

# Set default Python version
echo ""
echo "Setting Python 3.12 as default..."
uv python pin 3.12

# Verify the installation
echo ""
echo "Installed Python versions:"
uv python list

echo ""
echo "Python setup complete!"
