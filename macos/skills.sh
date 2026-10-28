#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
skill=pr-ready
source_dir="$DOTFILES_DIR/agents/skills/$skill"

if [[ ! -f "$source_dir/SKILL.md" ]]; then
    echo "Shared skill source is missing: $source_dir/SKILL.md" >&2
    exit 1
fi

directories=(
    "$HOME/.agents/skills"
    "${CODEX_HOME:-$HOME/.codex}/skills"
    "$HOME/.claude/skills"
    "$HOME/.claude_personal1/skills"
    "$HOME/.claude_work/skills"
    "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
    "$HOME/.grok/skills"
    "$HOME/.cursor/skills"
    "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
    "${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}/skills"
)

for directory in "${directories[@]}"; do
    target="$directory/$skill"
    # ~/.agents or an agent's skills directory may already resolve into dotfiles.
    [[ "$target" -ef "$source_dir" ]] && continue
    bash "$DOTFILES_DIR/macos/link_config.sh" "$source_dir" "$target"
done
echo "Installed $skill for Codex, Claude, Grok, Cursor, OpenCode, and Pi."
