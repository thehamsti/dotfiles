#!/usr/bin/env zsh

if (( $+functions[compdef] )) && (( $+commands[codex] )); then
    if (( $+functions[_codex] )); then
        compdef _codex codex
    else
        _dotfiles_codex_completion() {
            local completion
            completion="$(codex completion zsh)" || return $?
            eval "$completion" || return $?
            _codex "$@"
        }
        compdef _dotfiles_codex_completion codex
    fi
fi
