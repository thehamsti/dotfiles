#!/usr/bin/env bash
set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bind-key ? run-shell "${CURRENT_DIR}/scripts/hints.sh"
