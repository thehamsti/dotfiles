#!/bin/sh

# Run all of the setup scripts in macos including adding aliases to .zshrc
echo "Running setup scripts in macos"
./macos/setup_zsh.sh
./macos/brew.sh
./macos/python.sh
./macos/ollama.sh

echo "Done"
