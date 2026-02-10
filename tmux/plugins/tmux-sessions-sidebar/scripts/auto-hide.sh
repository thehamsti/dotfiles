#!/usr/bin/env bash
# Called by tmux hooks on resize.
# Closes the sidebar if the terminal is too narrow, re-opens if wide enough
# and the user previously had it open.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SIDEBAR_TITLE="__sessions_sidebar__"

MIN_WIDTH="$(tmux show-option -gv @sidebar-min-width 2>/dev/null)" || MIN_WIDTH=140
[[ "$MIN_WIDTH" =~ ^[0-9]+$ ]] || MIN_WIDTH=140

# Search ALL windows in the session for the sidebar pane
find_sidebar_pane() {
  local stored
  stored="$(tmux show-option -gv @sidebar-pane-id 2>/dev/null)" || stored=""
  if [[ -n "$stored" ]]; then
    if tmux list-panes -s -F '#{pane_id}' 2>/dev/null | grep -qxF "$stored"; then
      echo "$stored"
      return 0
    fi
    tmux set-option -g @sidebar-pane-id "" 2>/dev/null || true
  fi

  local id title
  while IFS='|' read -r id title; do
    [[ -z "$id" ]] && continue
    if [[ "$title" == "$SIDEBAR_TITLE" ]]; then
      tmux set-option -g @sidebar-pane-id "$id" 2>/dev/null || true
      echo "$id"
      return 0
    fi
  done < <(tmux list-panes -s -F '#{pane_id}|#{pane_title}' 2>/dev/null)
  return 1
}

win_width="$(tmux display-message -p '#{window_width}' 2>/dev/null)" || win_width=0
[[ "$win_width" =~ ^[0-9]+$ ]] || win_width=0

pane_id="$(find_sidebar_pane)" && sidebar_open=1 || sidebar_open=0

if [[ $sidebar_open -eq 1 ]]; then
  if [[ $win_width -lt $MIN_WIDTH ]]; then
    tmux set-option -g @sidebar-was-open 1 2>/dev/null || true
    tmux kill-pane -t "$pane_id" 2>/dev/null || true
    tmux set-option -g @sidebar-pane-id "" 2>/dev/null || true
  fi
else
  was_open="$(tmux show-option -gv @sidebar-was-open 2>/dev/null)" || was_open=0
  if [[ "$was_open" == "1" ]] && [[ $win_width -ge $MIN_WIDTH ]]; then
    tmux set-option -g @sidebar-was-open 0 2>/dev/null || true
    bash "${SCRIPT_DIR}/toggle.sh" &
    disown 2>/dev/null || true
  fi
fi
