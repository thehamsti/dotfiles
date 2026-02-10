#!/usr/bin/env bash
# Renders the session list for the sidebar pane.
# Long-running, interactive process — must never crash. No set -e.
#
# Navigation: j/k, up/down arrows to move cursor. Enter to switch session.
# q to close sidebar.
set -uo pipefail

# ── Terminal escape sequences ────────────────────────────

EL=$'\033[K'
CURSOR_HOME=$'\033[H'
HIDE_CUR=$'\033[?25l'
SHOW_CUR=$'\033[?25h'
CLR=$'\033[2J'
NL=$'\n'

# ── Everforest palette ───────────────────────────────────

C_FG=$'\033[38;2;211;198;170m'
C_GREEN=$'\033[38;2;167;192;128m'
C_BLUE=$'\033[38;2;127;187;179m'
C_YELLOW=$'\033[38;2;219;188;127m'
C_ORANGE=$'\033[38;2;230;152;117m'
C_GREY=$'\033[38;2;82;92;98m'
C_DIM=$'\033[2m'
C_BOLD=$'\033[1m'
C_RESET=$'\033[0m'

BG_GREEN=$'\033[48;2;167;192;128m'
BG_SEL=$'\033[48;2;60;71;77m'
FG_DARK=$'\033[38;2;47;56;62m'

SIDEBAR_WIDTH="${TMUX_SIDEBAR_WIDTH:-24}"

# Pre-compute divider
_divider=""
_d=0
while [[ $_d -lt $SIDEBAR_WIDTH ]]; do _divider+="─"; _d=$((_d + 1)); done

prev_frame=""
prev_line_count=0
_now=0

# Cursor state
cursor_pos=0
declare -a NAV_SESSIONS=()  # session names in display order

# ── Cleanup ──────────────────────────────────────────────

cleanup() {
  printf '%s' "$SHOW_CUR" 2>/dev/null
  exit 0
}
trap cleanup EXIT INT TERM HUP PIPE

# ── Helpers (pure bash, no subshells) ────────────────────

_relative_time() {
  local diff=$(( _now - $1 ))
  if [[ $diff -lt 0 ]]; then REPLY="now"
  elif [[ $diff -lt 60 ]]; then REPLY="now"
  elif [[ $diff -lt 3600 ]]; then REPLY="$(( diff / 60 ))m"
  elif [[ $diff -lt 86400 ]]; then REPLY="$(( diff / 3600 ))h"
  else REPLY="$(( diff / 86400 ))d"
  fi
}

_truncate() {
  local str="$1" max="$2"
  if [[ $max -lt 1 ]]; then REPLY=""; return; fi
  if [[ ${#str} -gt $max ]]; then
    REPLY="${str:0:$((max - 1))}…"
  else
    REPLY="$str"
  fi
}

_pad() {
  REPLY=""
  if [[ $1 -gt 0 ]]; then
    printf -v REPLY '%*s' "$1" ''
  fi
}

# ── Data collection ──────────────────────────────────────

declare -a S_NAME=() S_WINS=() S_ATTACHED=() S_ACTIVITY=() S_PATH=() S_WINNAMES=()

collect_sessions() {
  S_NAME=() S_WINS=() S_ATTACHED=() S_ACTIVITY=() S_PATH=() S_WINNAMES=()

  local raw idx=0
  raw="$(tmux list-sessions -F '#{session_name}|#{session_windows}|#{session_attached}|#{session_activity}|#{session_path}' 2>/dev/null)" || return 0

  local name wins att act path
  while IFS='|' read -r name wins att act path; do
    [[ -z "$name" ]] && continue
    S_NAME[idx]="$name"
    S_WINS[idx]="$wins"
    S_ATTACHED[idx]="$att"
    S_ACTIVITY[idx]="$act"
    S_PATH[idx]="$path"
    S_WINNAMES[idx]=""
    idx=$((idx + 1))
  done <<< "$raw"

  # Only fetch window names for the current session
  local current i wn
  current="$(tmux display-message -p '#S' 2>/dev/null)" || current=""
  for (( i = 0; i < ${#S_NAME[@]}; i++ )); do
    if [[ "${S_NAME[i]}" == "$current" ]]; then
      wn="$(tmux list-windows -t "${S_NAME[i]}" -F '#{window_name}' 2>/dev/null | paste -sd '│' -)" || wn=""
      S_WINNAMES[i]="$wn"
      break
    fi
  done
}

# ── Grouping ─────────────────────────────────────────────

declare -a G_LABELS=() G_MEMBERS=()

group_sessions() {
  G_LABELS=() G_MEMBERS=()

  local project_paths
  project_paths="$(tmux show-option -gv @project-paths 2>/dev/null)" || project_paths=""
  [[ -z "$project_paths" ]] && project_paths="$HOME/projects $HOME/k16"

  local -A label_idx=()
  local i spath matched pp label gi

  for (( i = 0; i < ${#S_NAME[@]}; i++ )); do
    spath="${S_PATH[i]}"
    matched=0

    for pp in $project_paths; do
      pp="${pp%/}"
      if [[ "$spath" == "$pp"/* || "$spath" == "$pp" ]]; then
        label="${pp##*/}"
        matched=1
        break
      fi
    done

    [[ $matched -eq 0 ]] && label="other"

    if [[ -z "${label_idx[$label]+x}" ]]; then
      label_idx[$label]=${#G_LABELS[@]}
      G_LABELS+=("$label")
      G_MEMBERS+=("$i")
    else
      gi="${label_idx[$label]}"
      G_MEMBERS[gi]="${G_MEMBERS[gi]}|$i"
    fi
  done
}

# ── Draw ─────────────────────────────────────────────────

draw() {
  local current_session pane_height buf line_count
  current_session="$(tmux display-message -p '#S' 2>/dev/null)" || current_session=""
  _now="$(date +%s)" || _now=0
  pane_height="$(tput lines 2>/dev/null)" || pane_height=24

  buf=""
  line_count=0
  NAV_SESSIONS=()

  # Header
  buf+="${C_BOLD}${C_BLUE} Sessions${C_RESET}${EL}${NL}"
  buf+="${C_GREY}${_divider}${C_RESET}${EL}${NL}"
  line_count=2

  collect_sessions
  group_sessions

  local max_lines=$((pane_height - 5))
  local total=0 nav_idx=0 gi si
  local label dname pad right age indicator wnames
  local name wins att act
  local is_cursor is_current

  for (( gi = 0; gi < ${#G_LABELS[@]}; gi++ )); do
    [[ $line_count -ge $max_lines ]] && break

    label="${G_LABELS[gi]}"

    # Blank line before group (except first)
    if [[ $total -gt 0 ]]; then
      buf+="${EL}${NL}"
      line_count=$((line_count + 1))
      [[ $line_count -ge $max_lines ]] && break
    fi

    # Group header
    _truncate "$label" "$((SIDEBAR_WIDTH - 2))"
    buf+="${C_DIM}${C_ORANGE} ${REPLY}${C_RESET}${EL}${NL}"
    line_count=$((line_count + 1))

    # Parse member indices
    local IFS='|'
    local -a member_indices
    read -ra member_indices <<< "${G_MEMBERS[gi]}"
    IFS=' '

    for si in "${member_indices[@]}"; do
      [[ $line_count -ge $max_lines ]] && break

      name="${S_NAME[si]}"
      wins="${S_WINS[si]}"
      att="${S_ATTACHED[si]}"
      act="${S_ACTIVITY[si]}"
      wnames="${S_WINNAMES[si]}"
      total=$((total + 1))

      NAV_SESSIONS[nav_idx]="$name"
      is_cursor=0
      [[ $nav_idx -eq $cursor_pos ]] && is_cursor=1
      is_current=0
      [[ "$name" == "$current_session" ]] && is_current=1

      if [[ $is_current -eq 1 ]] && [[ $is_cursor -eq 1 ]]; then
        # ── Current session + cursor ──
        right="${wins}w"
        _truncate "$name" "$((SIDEBAR_WIDTH - 4 - ${#right}))"
        dname="$REPLY"
        _pad "$((SIDEBAR_WIDTH - 3 - ${#dname} - ${#right}))"
        pad="$REPLY"; [[ -z "$pad" ]] && pad=" "

        buf+="${BG_GREEN}${FG_DARK}${C_BOLD} ▸ ${dname}${pad}${right} ${C_RESET}${EL}${NL}"
        line_count=$((line_count + 1))

        if [[ -n "$wnames" ]] && [[ $line_count -lt $max_lines ]]; then
          _truncate "$wnames" "$((SIDEBAR_WIDTH - 5))"
          buf+="${C_DIM}${C_GREEN}   ${REPLY}${C_RESET}${EL}${NL}"
          line_count=$((line_count + 1))
        fi

      elif [[ $is_current -eq 1 ]]; then
        # ── Current session, no cursor ──
        right="${wins}w"
        _truncate "$name" "$((SIDEBAR_WIDTH - 4 - ${#right}))"
        dname="$REPLY"
        _pad "$((SIDEBAR_WIDTH - 3 - ${#dname} - ${#right}))"
        pad="$REPLY"; [[ -z "$pad" ]] && pad=" "

        buf+="${C_GREEN}${C_BOLD} ● ${dname}${pad}${C_DIM}${right} ${C_RESET}${EL}${NL}"
        line_count=$((line_count + 1))

        if [[ -n "$wnames" ]] && [[ $line_count -lt $max_lines ]]; then
          _truncate "$wnames" "$((SIDEBAR_WIDTH - 5))"
          buf+="${C_DIM}${C_GREEN}   ${REPLY}${C_RESET}${EL}${NL}"
          line_count=$((line_count + 1))
        fi

      elif [[ $is_cursor -eq 1 ]]; then
        # ── Cursor on inactive session ──
        _relative_time "$act"
        age="$REPLY"
        local max_n=$((SIDEBAR_WIDTH - 5 - ${#age}))
        [[ $max_n -lt 4 ]] && max_n=4
        _truncate "$name" "$max_n"
        dname="$REPLY"
        _pad "$((SIDEBAR_WIDTH - 4 - ${#dname} - ${#age}))"
        pad="$REPLY"; [[ -z "$pad" ]] && pad=" "

        indicator=""
        [[ "${att:-0}" -gt 0 ]] && indicator=" ${C_YELLOW}●${C_RESET}"

        buf+="${BG_SEL}${C_FG}${C_BOLD} ▸ ${dname}${pad}${C_DIM}${age}${indicator}${C_RESET}${EL}${NL}"
        line_count=$((line_count + 1))

      else
        # ── Inactive session, no cursor ──
        _relative_time "$act"
        age="$REPLY"
        local max_n=$((SIDEBAR_WIDTH - 5 - ${#age}))
        [[ $max_n -lt 4 ]] && max_n=4
        _truncate "$name" "$max_n"
        dname="$REPLY"
        _pad "$((SIDEBAR_WIDTH - 4 - ${#dname} - ${#age}))"
        pad="$REPLY"; [[ -z "$pad" ]] && pad=" "

        indicator=""
        [[ "${att:-0}" -gt 0 ]] && indicator=" ${C_YELLOW}●${C_RESET}"

        buf+="${C_FG}   ${dname}${pad}${C_DIM}${age}${indicator}${C_RESET}${EL}${NL}"
        line_count=$((line_count + 1))
      fi

      nav_idx=$((nav_idx + 1))
    done
  done

  # Footer
  buf+="${EL}${NL}"
  buf+="${C_GREY}${_divider}${C_RESET}${EL}${NL}"
  buf+="${C_DIM}${C_GREY} ${total} sessions${C_RESET}${EL}${NL}"
  buf+="${C_DIM}${C_GREY} j/k navigate  ⏎ switch${C_RESET}${EL}"
  line_count=$((line_count + 4))

  # Clear leftover lines
  local i
  for (( i = line_count; i < prev_line_count; i++ )); do
    buf+="${NL}${EL}"
  done
  prev_line_count=$line_count

  # Clamp cursor for next frame (session count may have changed)
  local max_cursor=$((nav_idx - 1))
  [[ $max_cursor -lt 0 ]] && max_cursor=0
  [[ $cursor_pos -gt $max_cursor ]] && cursor_pos=$max_cursor

  # Only write if frame changed
  if [[ "$buf" != "$prev_frame" ]]; then
    printf '%s%s' "$CURSOR_HOME" "$buf"
    prev_frame="$buf"
  fi
}

# ── Input handling ───────────────────────────────────────

handle_input() {
  local key=""
  IFS= read -rsn1 -t 2 key 2>/dev/null || return 0

  local nav_count=${#NAV_SESSIONS[@]}
  [[ $nav_count -eq 0 ]] && return 0

  case "$key" in
    j)
      cursor_pos=$((cursor_pos + 1))
      [[ $cursor_pos -ge $nav_count ]] && cursor_pos=0
      prev_frame=""  # force redraw
      ;;
    k)
      cursor_pos=$((cursor_pos - 1))
      [[ $cursor_pos -lt 0 ]] && cursor_pos=$((nav_count - 1))
      prev_frame=""
      ;;
    $'\033')
      # Arrow keys: ESC [ A/B
      local seq=""
      IFS= read -rsn1 -t 0.1 seq 2>/dev/null || return 0
      if [[ "$seq" == "[" ]]; then
        local arrow=""
        IFS= read -rsn1 -t 0.1 arrow 2>/dev/null || return 0
        case "$arrow" in
          A) # Up
            cursor_pos=$((cursor_pos - 1))
            [[ $cursor_pos -lt 0 ]] && cursor_pos=$((nav_count - 1))
            prev_frame=""
            ;;
          B) # Down
            cursor_pos=$((cursor_pos + 1))
            [[ $cursor_pos -ge $nav_count ]] && cursor_pos=0
            prev_frame=""
            ;;
        esac
      fi
      ;;
    "")
      # Enter key
      local target="${NAV_SESSIONS[$cursor_pos]:-}"
      if [[ -n "$target" ]]; then
        tmux switch-client -t "$target" 2>/dev/null || true
        prev_frame=""  # force redraw after switch
      fi
      ;;
    q|Q)
      # Close sidebar by killing our own pane
      exit 0
      ;;
    g)
      # g = go to top
      cursor_pos=0
      prev_frame=""
      ;;
    G)
      # G = go to bottom
      cursor_pos=$((nav_count - 1))
      prev_frame=""
      ;;
  esac
}

# ── Main loop ────────────────────────────────────────────

printf '%s%s%s' "$HIDE_CUR" "$CLR" "$CURSOR_HOME"

while true; do
  draw || true
  handle_input
done
