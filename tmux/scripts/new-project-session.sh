#!/usr/bin/env bash
set -euo pipefail
trap 'tmux display-message "new-project-session failed at line ${LINENO}: ${BASH_COMMAND} (status $?)"' ERR

if [[ "${1-}" == "--dir" ]]; then
  dir="${2-}"
else
  paths="$(tmux show-option -gv @project-paths 2>/dev/null || true)"
  if [[ -z "$paths" ]]; then
    paths="$HOME/projects $HOME/k16"
  fi

  if command -v fzf >/dev/null 2>&1; then
    tmp_file="$(mktemp -t tmux-projects.XXXXXX)"
    tmp_sel="$(mktemp -t tmux-projects.sel.XXXXXX)"
    trap 'rm -f "$tmp_file" "$tmp_sel"' EXIT
    for p in $paths; do
      if [[ -d "$p" ]]; then
        printf "%s\n" "$p" >>"$tmp_file"
        find "$p" -maxdepth 2 -mindepth 1 -type d 2>/dev/null >>"$tmp_file"
      fi
    done
    if [[ ! -s "$tmp_file" ]]; then
      tmux display-message "No projects found"
      exit 0
    fi
    if tmux list-commands | grep -q '^display-popup'; then
      tmux display-popup -E "bash -lc 'sed \"s|^$HOME|~|\" \"$tmp_file\" | fzf --prompt=\"Project> \" --height=40% > \"$tmp_sel\"'"
      dir="$(cat "$tmp_sel")"
    else
      tmux command-prompt -p "Project dir:" -I "#{pane_current_path}" "run-shell \"$0 --dir %1\""
      exit 0
    fi
    if [[ -z "$dir" ]]; then
      tmux display-message "No project selected"
      exit 0
    fi
    dir="${dir/#\~/$HOME}"
  else
    tmux command-prompt -p "Project dir:" -I "#{pane_current_path}" "run-shell \"$0 --dir %1\""
    exit 0
  fi
fi

if [[ -z "${dir:-}" ]]; then
  tmux display-message "No project selected"
  exit 0
fi

name="$(basename "$dir" | tr " :/" "___")"

if tmux has-session -t "$name" 2>/dev/null; then
  tmux switch-client -t "$name"
  exit 0
fi

tmux new-session -d -s "$name" -c "$dir"
tmux rename-window -t "$name":1 main
tmux split-window -h -t "$name":1 -c "$dir"
tmux split-window -v -t "$name":1.2 -c "$dir"
tmux select-layout -t "$name":1 main-vertical
tmux select-pane -t "$name":1.1
tmux new-window -t "$name" -n bg -c "$dir"
tmux new-window -t "$name" -n logs -c "$dir"
tmux select-window -t "$name":1
tmux switch-client -t "$name"
