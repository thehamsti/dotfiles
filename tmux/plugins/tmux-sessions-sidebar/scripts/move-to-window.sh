#!/usr/bin/env bash
# Moves the sidebar pane into the current window (if it exists elsewhere).
# Called by the window-linked / after-select-window hook.
# If the sidebar is already in the current window, this is a no-op.
set -uo pipefail

SIDEBAR_TITLE="__sessions_sidebar__"
SIDEBAR_WIDTH="$(tmux show-option -gv @sidebar-width 2>/dev/null)" || SIDEBAR_WIDTH=24
[[ "$SIDEBAR_WIDTH" =~ ^[0-9]+$ ]] || SIDEBAR_WIDTH=24
MIN_WIDTH="$(tmux show-option -gv @sidebar-min-width 2>/dev/null)" || MIN_WIDTH=140
[[ "$MIN_WIDTH" =~ ^[0-9]+$ ]] || MIN_WIDTH=140

# Get current window ID
current_window="$(tmux display-message -p '#{window_id}' 2>/dev/null)" || exit 0

# Find the sidebar pane anywhere in the session
sidebar_pane=""
sidebar_window=""

stored="$(tmux show-option -gv @sidebar-pane-id 2>/dev/null)" || stored=""

if [[ -n "$stored" ]]; then
  # Check it still exists and find which window it's in
  while IFS='|' read -r wid pid ptitle; do
    if [[ "$pid" == "$stored" ]]; then
      sidebar_pane="$pid"
      sidebar_window="$wid"
      break
    fi
  done < <(tmux list-panes -s -F '#{window_id}|#{pane_id}|#{pane_title}' 2>/dev/null)
fi

# Fallback: search by title if stored ID is stale
if [[ -z "$sidebar_pane" ]]; then
  while IFS='|' read -r wid pid ptitle; do
    if [[ "$ptitle" == "$SIDEBAR_TITLE" ]]; then
      sidebar_pane="$pid"
      sidebar_window="$wid"
      tmux set-option -g @sidebar-pane-id "$pid" 2>/dev/null || true
      break
    fi
  done < <(tmux list-panes -s -F '#{window_id}|#{pane_id}|#{pane_title}' 2>/dev/null)
fi

# No sidebar? Nothing to move.
[[ -z "$sidebar_pane" ]] && exit 0

# Already in the current window? No-op.
[[ "$sidebar_window" == "$current_window" ]] && exit 0

# Check width
win_width="$(tmux display-message -p '#{window_width}' 2>/dev/null)" || win_width=0
[[ "$win_width" =~ ^[0-9]+$ ]] || win_width=0
if [[ $win_width -lt $MIN_WIDTH ]]; then
  # Too narrow — don't move, just leave it hidden in the other window
  exit 0
fi

# Remember active pane
active_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || exit 0

# Move the sidebar pane into this window (left side)
tmux join-pane -hbl "$SIDEBAR_WIDTH" -s "$sidebar_pane" -t "$active_pane" 2>/dev/null || exit 0

# Restore focus to the user's pane
tmux select-pane -t "$active_pane" 2>/dev/null || true
