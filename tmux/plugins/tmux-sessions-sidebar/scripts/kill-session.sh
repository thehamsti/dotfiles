#!/usr/bin/env bash
# Kill one or more sessions via fzf multi-select.
# Bound to prefix + E. Protects the current session from being killed.
# No set -e — runs from a tmux keybinding, must handle errors gracefully.
set -uo pipefail

current_session="$(tmux display-message -p '#S' 2>/dev/null)" || {
  tmux display-message "kill-session: could not determine current session" 2>/dev/null
  exit 0
}

if ! command -v fzf >/dev/null 2>&1; then
  tmux display-message "kill-session: fzf is required" 2>/dev/null
  exit 0
fi

tmp_sel="$(mktemp -t tmux-kill-sessions.XXXXXX 2>/dev/null)" || {
  tmux display-message "kill-session: mktemp failed" 2>/dev/null
  exit 0
}
trap 'rm -f "$tmp_sel"' EXIT

# Build session list, excluding current session
session_list() {
  local name windows attached activity now diff age attach_str
  now="$(date +%s)"
  while IFS='|' read -r name windows attached activity; do
    [[ -z "$name" ]] && continue
    [[ "$name" == "$current_session" ]] && continue
    diff=$(( now - activity ))
    if [[ $diff -lt 60 ]]; then age="now"
    elif [[ $diff -lt 3600 ]]; then age="$(( diff / 60 ))m ago"
    elif [[ $diff -lt 86400 ]]; then age="$(( diff / 3600 ))h ago"
    else age="$(( diff / 86400 ))d ago"
    fi
    attach_str=""
    [[ "${attached:-0}" -gt 0 ]] && attach_str=" [attached]"
    printf '%-20s %sw  %s%s\n' "$name" "$windows" "$age" "$attach_str"
  done < <(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_attached}|#{session_activity}' 2>/dev/null)
}

# Check popup support
if ! tmux list-commands 2>/dev/null | grep -q '^display-popup'; then
  tmux display-message "kill-session: display-popup not supported" 2>/dev/null
  exit 0
fi

# Run fzf in a popup. Export the function for the subshell.
export current_session
tmux display-popup -w 60 -h 20 -E \
  "bash -lc '$(declare -f session_list); current_session=\"${current_session}\" session_list | fzf --multi --prompt=\"Kill session> \" --header=\"(current: ${current_session} is protected)\" --header-first > \"$tmp_sel\"'" \
  2>/dev/null || true

# If the file is empty or missing, user cancelled
[[ -s "$tmp_sel" ]] || exit 0

# Parse and kill selected sessions
killed=0
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  name="${line%% *}"  # first field (no awk fork)
  [[ -z "$name" ]] && continue
  [[ "$name" == "$current_session" ]] && continue
  if tmux kill-session -t "$name" 2>/dev/null; then
    killed=$((killed + 1))
  fi
done < "$tmp_sel"

if [[ $killed -gt 0 ]]; then
  tmux display-message "Killed ${killed} session(s)" 2>/dev/null
fi
