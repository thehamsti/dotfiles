#!/usr/bin/env zsh

if ! command zsh -n "${ZDOTDIR:-$HOME}/.zshrc"; then
    print -u2 -- "Reload canceled: fix the .zshrc errors above and try again."
    return 1
fi

# Repeated plugin initialization must not accumulate paths or duplicate hooks.
typeset -gU PATH path FPATH fpath
typeset -gaU precmd_functions preexec_functions chpwd_functions

source "${ZDOTDIR:-$HOME}/.zshrc" || return $?

# Atuin loads after the dotfile aliases in .zshrc and can restore stale copies.
source "${${(%):-%x}:A:h}/aliases.sh" || return $?
rehash
