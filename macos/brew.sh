#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"

# Check if Homebrew is installed
if ! command -v brew &>/dev/null; then
    echo "Homebrew not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
else
    echo "Homebrew is already installed"
fi

# Update Homebrew
echo "Updating Homebrew..."
brew update

# Install from Brewfile
if [[ -f "$BREWFILE" ]]; then
    echo "Installing packages from Brewfile..."
    brew bundle --file="$BREWFILE"
    
    echo ""
    echo "Cleaning up..."
    brew cleanup
    
    echo ""
    echo "Brew installation complete!"
else
    echo "Error: Brewfile not found at $BREWFILE"
    exit 1
fi
