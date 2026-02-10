#!/usr/bin/env bash
# TPM entry point for tmux-sessions-sidebar.
# All tmux calls are guarded — plugin load must never produce errors.
set -uo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Set defaults only if not already configured by the user
tmux show-option -gv @sidebar-width     >/dev/null 2>&1 || tmux set-option -g @sidebar-width 24 2>/dev/null
tmux show-option -gv @sidebar-min-width >/dev/null 2>&1 || tmux set-option -g @sidebar-min-width 140 2>/dev/null
tmux set-option -g @sidebar-was-open 0   2>/dev/null || true
tmux set-option -g @sidebar-pane-id ""   2>/dev/null || true
tmux set-option -g @sidebar-prev-pane "" 2>/dev/null || true

# Toggle sidebar (prefix + e): open+focus / close
tmux bind-key e run-shell "bash '${CURRENT_DIR}/scripts/toggle.sh'" 2>/dev/null || true

# Kill session picker (prefix + E)
tmux bind-key E run-shell "bash '${CURRENT_DIR}/scripts/kill-session.sh'" 2>/dev/null || true

# prefix + o: if in sidebar, return to previous pane. Otherwise, default pane cycling.
tmux bind-key o if-shell \
  "test \"\$(tmux display-message -p '#{pane_title}')\" = '__sessions_sidebar__'" \
  "run-shell \"tmux select-pane -t \\\"\$(tmux show-option -gv @sidebar-prev-pane)\\\"\"" \
  "select-pane -t :.+" \
  2>/dev/null || true

# Auto-hide/show on resize
tmux set-hook -g after-resize-pane  "run-shell -b 'bash \"${CURRENT_DIR}/scripts/auto-hide.sh\"'" 2>/dev/null || true
tmux set-hook -g client-resized     "run-shell -b 'bash \"${CURRENT_DIR}/scripts/auto-hide.sh\"'" 2>/dev/null || true

# Move sidebar to current window on window switch
tmux set-hook -g after-select-window "run-shell -b 'bash \"${CURRENT_DIR}/scripts/move-to-window.sh\"'" 2>/dev/null || true
