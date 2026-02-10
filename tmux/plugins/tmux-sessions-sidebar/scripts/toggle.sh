#!/usr/bin/env bash
# Toggle the sessions sidebar pane.
# - If no sidebar: open + focus it, store previous pane
# - If sidebar exists: close it, restore focus to previous pane
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RENDER_SCRIPT="${SCRIPT_DIR}/render.sh"
SIDEBAR_TITLE="__sessions_sidebar__"

SIDEBAR_WIDTH="$(tmux show-option -gv @sidebar-width 2>/dev/null)" || SIDEBAR_WIDTH=24
MIN_WIDTH="$(tmux show-option -gv @sidebar-min-width 2>/dev/null)" || MIN_WIDTH=140
[[ "$SIDEBAR_WIDTH" =~ ^[0-9]+$ ]] || SIDEBAR_WIDTH=24
[[ "$MIN_WIDTH" =~ ^[0-9]+$ ]] || MIN_WIDTH=140

# ── Find sidebar pane across ALL windows in this session ──

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

close_sidebar() {
  local pane_id
  pane_id="$(find_sidebar_pane)" || return 1

  # Restore focus to the previously active pane
  local prev_pane
  prev_pane="$(tmux show-option -gv @sidebar-prev-pane 2>/dev/null)" || prev_pane=""
  if [[ -n "$prev_pane" ]]; then
    tmux select-pane -t "$prev_pane" 2>/dev/null || true
  fi

  tmux kill-pane -t "$pane_id" 2>/dev/null || true
  tmux set-option -g @sidebar-pane-id "" 2>/dev/null || true
  tmux set-option -g @sidebar-prev-pane "" 2>/dev/null || true
  return 0
}

open_sidebar() {
  local win_width
  win_width="$(tmux display-message -p '#{window_width}' 2>/dev/null)" || win_width=0
  [[ "$win_width" =~ ^[0-9]+$ ]] || win_width=0

  if [[ $win_width -lt $MIN_WIDTH ]]; then
    tmux display-message "Terminal too narrow for sidebar (${win_width} < ${MIN_WIDTH})" 2>/dev/null
    return 0
  fi

  # Store the currently active pane so we can return to it later
  local active_pane
  active_pane="$(tmux display-message -p '#{pane_id}' 2>/dev/null)" || {
    tmux display-message "sidebar: could not determine active pane" 2>/dev/null
    return 1
  }
  tmux set-option -g @sidebar-prev-pane "$active_pane" 2>/dev/null || true

  # Count panes before split so we can identify the new one
  local panes_before
  panes_before="$(tmux list-panes -F '#{pane_id}' 2>/dev/null)"

  if ! tmux split-window -hbdl "$SIDEBAR_WIDTH" \
    -t "$active_pane" \
    "TMUX_SIDEBAR_WIDTH=${SIDEBAR_WIDTH} exec bash '${RENDER_SCRIPT}'" 2>/dev/null; then
    tmux display-message "sidebar: split-window failed (pane too small?)" 2>/dev/null
    return 1
  fi

  # Find the new pane (the one that wasn't in the list before)
  local new_pane="" id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! echo "$panes_before" | grep -qxF "$id"; then
      new_pane="$id"
      break
    fi
  done < <(tmux list-panes -F '#{pane_id}' 2>/dev/null)

  if [[ -n "$new_pane" ]]; then
    tmux select-pane -t "$new_pane" -T "$SIDEBAR_TITLE" 2>/dev/null || true
    tmux set-option -g @sidebar-pane-id "$new_pane" 2>/dev/null || true
    # Focus the sidebar pane
    tmux select-pane -t "$new_pane" 2>/dev/null || true
  fi
}

# ── Toggle ───────────────────────────────────────────────

if close_sidebar; then
  tmux set-option -g @sidebar-was-open 0 2>/dev/null || true
  exit 0
fi

open_sidebar
