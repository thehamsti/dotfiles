#!/usr/bin/env bash
set -euo pipefail

trap 'tmux display-message "switch-session failed at line ${LINENO}: ${BASH_COMMAND} (status $?)"' ERR

if ! command -v fzf >/dev/null 2>&1; then
  tmux choose-tree -s
  exit 0
fi

tmp_sel="$(mktemp -t tmux-sessions.sel.XXXXXX)"
trap 'rm -f "$tmp_sel"' EXIT

# fzf needs a TTY; run it inside a tmux popup when available.
if tmux list-commands | grep -q '^display-popup'; then
  set +e
  tmux display-popup -E "bash -lc 'tmux list-sessions -F \"#S\" | fzf --prompt=\"Session> \" --height=40% > \"$tmp_sel\"'"
  popup_status=$?
  set -e

  # ESC/Ctrl-C in fzf returns 130; treat as a clean cancel.
  if [[ $popup_status -eq 130 || $popup_status -eq 1 ]]; then
    exit 0
  fi
  if [[ $popup_status -ne 0 ]]; then
    tmux display-message "switch-session popup failed (status $popup_status)"
    exit 0
  fi

  session="$(cat "$tmp_sel" 2>/dev/null || true)"
else
  # Fallback is tmux's built-in interactive UI.
  tmux choose-tree -s
  exit 0
fi

if [[ -z "${session:-}" ]]; then
  exit 0
fi

tmux switch-client -t "$session"
