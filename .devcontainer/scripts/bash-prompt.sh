#!/bin/sh

# Enable Starship prompt first
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# Load environment variables using shared loader (try workspace first)
if [ -f "/workspace/.devcontainer/scripts/env-loader.sh" ]; then
    # shellcheck disable=SC1090
    . "/workspace/.devcontainer/scripts/env-loader.sh"
    load_project_env "/workspace"
elif [ -f "/workspace/.env" ]; then
    # simple fallback
    # shellcheck disable=SC1090
    . "/workspace/.env"
else
    echo "Warning: .env not found in workspace; continuing without it"
fi

if [ -f /etc/container.env ]; then
    . /etc/container.env
fi

# Source SSH agent setup
if [ -f "$HOME/.devcontainer/scripts/ssh-agent-setup.sh" ]; then
    . "$HOME/.devcontainer/scripts/ssh-agent-setup.sh"
fi

# Source color definitions
if [ -f "$HOME/.devcontainer/scripts/colors.sh" ]; then
    . "$HOME/.devcontainer/scripts/colors.sh"
else
    echo "Warning: colors.sh not found, using default colors"
fi

# Only set up prompt in interactive shells
case $- in
    *i*) ;;
    *) return;;
esac

# Git aliases
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# JSON linting aliases
alias jsonlint='jq "."'
alias jsonformat='jq "."'
alias jsonvalidate='jq empty'
alias jsonpretty='jq "."'

# Export SHELL variable to ensure bash is used
export SHELL=/bin/bash
