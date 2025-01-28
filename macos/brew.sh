#!/bin/sh

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
    echo "Homebrew not installed. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed"
fi

# Install packages from the text file
echo "Installing packages from brew_packages.txt..."
grep -v '^#\|^$' brew_packages.txt | xargs brew install

