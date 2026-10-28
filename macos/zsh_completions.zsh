#!/usr/bin/env zsh

# NVM_DIR is available after .zshrc; mise owns Node until explicit NVM use.
if [[ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]] && (( ! $+functions[nvm] )); then
    nvm() {
        unfunction nvm
        source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" --no-use || return $?
        if [[ -s "${NVM_DIR:-$HOME/.nvm}/bash_completion" ]]; then
            source "${NVM_DIR:-$HOME/.nvm}/bash_completion"
        fi
        nvm "$@"
    }
fi

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
