#!/bin/bash
set -uo pipefail

errors=()

record_error() {
    local message="$1"
    errors+=("$message")
    if [ -n "${SETUP_ERRORS_FILE:-}" ]; then
        printf "%s\n" "$message" >> "$SETUP_ERRORS_FILE"
    fi
}

run_step() {
    local label="$1"
    shift
    if "$@"; then
        echo "  ✓ $label"
    else
        local status=$?
        echo "  ✗ $label (exit $status)"
        record_error "$label (exit $status)"
    fi
}

git_config() {
    local label="$1"
    shift
    run_step "$label" git config --global "$@"
}

echo "Configuring git defaults..."

# Use main as default branch
git_config "Set default branch to main" init.defaultBranch main

# Better diffs
if command -v delta &>/dev/null; then
    git_config "Configure delta as pager" core.pager delta
    git_config "Configure delta diff filter" interactive.diffFilter "delta --color-only"
    git_config "Enable delta navigate" delta.navigate true
    git_config "Enable delta side-by-side" delta.side-by-side true
    git_config "Enable delta line numbers" delta.line-numbers true
    echo "Configured delta as git pager"
elif command -v diff-so-fancy &>/dev/null; then
    git_config "Configure diff-so-fancy as pager" core.pager "diff-so-fancy | less --tabs=4 -RFX"
    echo "Configured diff-so-fancy as git pager"
fi

# Better merge conflict markers
git_config "Set merge conflict style to diff3" merge.conflictstyle diff3

# Auto-setup remote tracking
git_config "Enable push.autoSetupRemote" push.autoSetupRemote true

# Push only current branch by default
git_config "Set push.default to current" push.default current

# Rebase on pull by default
git_config "Enable pull.rebase" pull.rebase true

# Auto-stash when rebasing
git_config "Enable rebase.autoStash" rebase.autoStash true

# Prune deleted remote branches on fetch
git_config "Enable fetch.prune" fetch.prune true

# Better log format
git_config "Set custom log format" format.pretty "%C(yellow)%h%C(reset) %s %C(cyan)<%an>%C(reset) %C(green)(%cr)%C(reset)"

# Use nvim as editor if available
if command -v nvim &>/dev/null; then
    git_config "Set core.editor to nvim" core.editor nvim
fi

# Useful aliases
git_config "Alias: co" alias.co checkout
git_config "Alias: br" alias.br branch
git_config "Alias: ci" alias.ci commit
git_config "Alias: st" alias.st status
git_config "Alias: unstage" alias.unstage "reset HEAD --"
git_config "Alias: last" alias.last "log -1 HEAD"
git_config "Alias: visual" alias.visual "!gitk"
git_config "Alias: lg" alias.lg "log --oneline --graph --all"
git_config "Alias: amend" alias.amend "commit --amend --no-edit"
git_config "Alias: undo" alias.undo "reset --soft HEAD~1"

# Enable rerere (reuse recorded resolution)
git_config "Enable rerere" rerere.enabled true

# Improve performance for large repos
git_config "Enable manyFiles optimization" feature.manyFiles true
git_config "Enable fsmonitor" core.fsmonitor true

# Use global gitignore
git_config "Use global gitignore" core.excludesfile ~/.gitignore_global

# macOS credential helper
git_config "Set macOS credential helper" credential.helper osxkeychain

# Sort branches by most recent commit
git_config "Sort branches by recent commit" branch.sort -committerdate

# Better merge tool (nvim)
if command -v nvim &>/dev/null; then
    git_config "Set merge tool to nvimdiff" merge.tool nvimdiff
    git_config "Configure nvimdiff command" mergetool.nvimdiff.cmd 'nvim -d "$LOCAL" "$REMOTE" "$MERGED" -c "wincmd w" -c "wincmd J"'
    git_config "Disable mergetool prompt" mergetool.prompt false
    git_config "Disable mergetool backups" mergetool.keepBackup false
fi

# Expand save panel by default (for git gui tools)
git_config "Show untracked files in GUI" gui.displayuntracked true

echo ""
echo "Git configuration complete!"
echo ""
echo "Note: You may want to set your user info:"
echo "  git config --global user.name \"Your Name\""
echo "  git config --global user.email \"your@email.com\""
echo ""
echo "For GPG signing (optional):"
echo "  git config --global commit.gpgsign true"
echo "  git config --global user.signingkey <your-key-id>"

if [ -z "${SETUP_ERRORS_FILE:-}" ] && ((${#errors[@]} > 0)); then
    echo ""
    echo "Git configuration completed with errors:"
    for err in "${errors[@]}"; do
        echo "  - $err"
    done
    exit 1
fi
