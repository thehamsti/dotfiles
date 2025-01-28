#!/bin/sh

# Run all of the setup scripts in macos including adding aliases to .zshrc
echo "Running setup scripts in macos"
./setup_zsh.sh
./brew.sh
./python.sh
./ollama.sh

echo "Done"
