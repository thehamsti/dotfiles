#!/usr/bin/env zsh

typeset -gU PATH path FPATH fpath
typeset -gaU precmd_functions preexec_functions chpwd_functions

# Docker completions must be visible to Oh My Zsh's single compinit pass.
if [[ -d "$HOME/.docker/completions" ]]; then
    fpath=("$HOME/.docker/completions" $fpath)
fi
