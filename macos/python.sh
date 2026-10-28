#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
mise -C "$DOTFILES_DIR" exec -- python3 --version
mise -C "$DOTFILES_DIR" exec -- uv --version
