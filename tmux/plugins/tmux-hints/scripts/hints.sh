#!/usr/bin/env bash
set -euo pipefail

prefix_key="$(tmux show-option -gv prefix || echo C-b)"

hint_text() {
	cat <<EOT
Tmux Hints (${prefix_key} is the prefix)

Session / Windows
  ${prefix_key} d        Detach
  ${prefix_key} c        New window
  ${prefix_key} ,        Rename window
  ${prefix_key} n/p      Next/prev window
  ${prefix_key} 0..9     Go to window

Panes
  ${prefix_key} |        Split right
  ${prefix_key} -        Split down
  ${prefix_key} o        Next pane
  ${prefix_key} q        Show pane numbers
  ${prefix_key} x        Kill pane
  ${prefix_key} z        Zoom pane

Navigation
  ${prefix_key} h/j/k/l  Move between panes (vi)
  ${prefix_key} [        Copy mode (vi)
  ${prefix_key} ]        Paste

Other
  ${prefix_key} r        Reload config
EOT
}

if tmux display-message -p '#{?popup_supported,1,0}' | grep -q '^1$'; then
	tmux display-popup -E "bash -lc 'cat <<\"POP\"\n$(hint_text)\nPOP\n\nread -n 1 -s -r -p \"Press any key...\"'"
else
	tmux new-window -n "tmux-hints" "printf '%s\n' \"$(hint_text | sed 's/"/\\"/g')\"; read -n 1 -s -r -p 'Press any key...'; tmux kill-window"
fi
