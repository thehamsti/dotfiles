#!/bin/bash
set -euo pipefail

echo "Configuring git defaults..."

# Use main as default branch
git config --global init.defaultBranch main

# Better diffs
if command -v delta &>/dev/null; then
    git config --global core.pager delta
    git config --global interactive.diffFilter "delta --color-only"
    git config --global delta.navigate true
    git config --global delta.side-by-side true
    git config --global delta.line-numbers true
    echo "Configured delta as git pager"
elif command -v diff-so-fancy &>/dev/null; then
    git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
    echo "Configured diff-so-fancy as git pager"
fi

# Better merge conflict markers
git config --global merge.conflictstyle diff3

# Auto-setup remote tracking
git config --global push.autoSetupRemote true

# Push only current branch by default
git config --global push.default current

# Rebase on pull by default
git config --global pull.rebase true

# Auto-stash when rebasing
git config --global rebase.autoStash true

# Prune deleted remote branches on fetch
git config --global fetch.prune true

# Better log format
git config --global format.pretty "%C(yellow)%h%C(reset) %s %C(cyan)<%an>%C(reset) %C(green)(%cr)%C(reset)"

# Use nvim as editor if available
if command -v nvim &>/dev/null; then
    git config --global core.editor nvim
fi

# Useful aliases
git config --global alias.co checkout
git config --global alias.br branch
git config --global alias.ci commit
git config --global alias.st status
git config --global alias.unstage "reset HEAD --"
git config --global alias.last "log -1 HEAD"
git config --global alias.visual "!gitk"
git config --global alias.lg "log --oneline --graph --all"
git config --global alias.amend "commit --amend --no-edit"
git config --global alias.undo "reset --soft HEAD~1"

# Enable rerere (reuse recorded resolution)
git config --global rerere.enabled true

# Improve performance for large repos
git config --global feature.manyFiles true
git config --global core.fsmonitor true

# Use global gitignore
git config --global core.excludesfile ~/.gitignore_global

# macOS credential helper
git config --global credential.helper osxkeychain

# Sort branches by most recent commit
git config --global branch.sort -committerdate

# Better merge tool (nvim)
if command -v nvim &>/dev/null; then
    git config --global merge.tool nvimdiff
    git config --global mergetool.nvimdiff.cmd 'nvim -d "$LOCAL" "$REMOTE" "$MERGED" -c "wincmd w" -c "wincmd J"'
    git config --global mergetool.prompt false
    git config --global mergetool.keepBackup false
fi

# Expand save panel by default (for git gui tools)
git config --global gui.displayuntracked true

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
