#!/bin/bash
set -euo pipefail
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SOURCE TARGET" >&2
    exit 2
fi

config_source="$1"
config_target="$2"
if [[ ! -e "$config_source" ]]; then
    echo "Config source does not exist: $config_source" >&2
    exit 1
fi
if [[ -L "$config_target" && "$config_target" -ef "$config_source" ]]; then
    exit 0
fi

mkdir -p "$(dirname "$config_target")"
if [[ -e "$config_target" || -L "$config_target" ]]; then
    backup_dir="$(mktemp -d "$config_target.backup.XXXXXX")"
    mv "$config_target" "$backup_dir/original"
    echo "Previous config saved to $backup_dir/original"
fi
ln -s "$config_source" "$config_target"
