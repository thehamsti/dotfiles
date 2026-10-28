#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 || ! -f "$1" ]]; then
    echo "Usage: $0 EXISTING_PAM_REATTACH_MODULE SUDO_LOCAL_FILE" >&2
    exit 1
fi
module="$1"
pam_file="$2"
if [[ "$module" == *[[:space:]]* ]]; then
    echo "PAM module paths cannot contain whitespace: $module" >&2
    exit 1
fi
temporary="$(mktemp -t sudo-local.XXXXXX)"
trap 'rm -f "$temporary"' EXIT

existing=/dev/null
[[ ! -f "$pam_file" ]] || existing="$pam_file"
# Keep custom policy ordering; only move reattach immediately before Touch ID.
awk -v module="$module" '
    $1 == "auth" && $3 ~ /(^|\/)pam_reattach[.]so$/ { next }
    { lines[++count] = $0 }
    END {
        for (i = 1; i <= count; i++) {
            split(lines[i], fields)
            if (!inserted && fields[1] == "auth" && fields[3] ~ /(^|\/)pam_tid[.]so$/) {
                print "auth optional " module " ignore_ssh"
                inserted = 1
            }
            print lines[i]
        }
        if (!inserted) {
            print "auth optional " module " ignore_ssh"
            print "auth sufficient pam_tid.so"
        }
    }
' "$existing" >"$temporary"

if [[ -f "$pam_file" ]] && ! cmp -s "$temporary" "$pam_file"; then
    backup="$(sudo mktemp "$pam_file.backup.XXXXXX")"
    sudo cp -p "$pam_file" "$backup"
    echo "Previous local PAM config saved to $backup"
fi
# Moving a user-owned temporary file into /etc preserves the wrong ownership.
sudo install -o root -g wheel -m 644 "$temporary" "$pam_file"
