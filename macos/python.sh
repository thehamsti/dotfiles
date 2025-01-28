#!/bin/sh

# Check if uv is already installed
if ! command -v uv &> /dev/null; then
    echo "uv not installed. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
else
    echo "uv is already installed"
fi

# Install Python versions using uv
echo "Installing Python versions 3.10, 3.11, and 3.12..."
uv python install 3.10 3.11 3.12

# Verify the installation
echo "Installed Python versions:"
uv python list

