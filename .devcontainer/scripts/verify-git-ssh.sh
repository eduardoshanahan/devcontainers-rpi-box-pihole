#!/usr/bin/env bash
set -euo pipefail

# Simple verify script for SSH agent forwarding and git config
# Usage: ./verify-git-ssh.sh git-host
# Example: ./verify-git-ssh.sh git@github.com

if [ $# -lt 1 ]; then
    printf 'Usage: %s git-host\n' "$0"
    exit 1
fi

GIT_HOST="$1"

info() { printf '\033[1;33m%s\033[0m\n' "$1"; }
ok()   { printf '\033[1;32m%s\033[0m\n' "$1"; }
fail() { printf '\033[1;31m%s\033[0m\n' "$1"; }

echo
info "Verifying SSH agent and Git configuration"
echo "Target git host: $GIT_HOST"
echo

PASS=true

# Check SSH_AUTH_SOCK
if [ -n "${SSH_AUTH_SOCK+x}" ]; then
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
        ok "SSH_AUTH_SOCK is set: $SSH_AUTH_SOCK"
    else
        fail "SSH_AUTH_SOCK is set but not a socket. SSH agent forwarding may not be enabled."
        PASS=false
    fi
else
    fail "SSH_AUTH_SOCK is not set. SSH agent forwarding may not be enabled."
    PASS=false
fi

echo
info "Listing keys from ssh-agent (ssh-add -l):"
if ssh-add -l 2>/dev/null; then
    ok "ssh-agent returned identities above."
else
    fail "No identities reported by ssh-agent or ssh-add not available. (ssh-add -l failed)"
    PASS=false
fi

echo
info "Attempting SSH connection test to $GIT_HOST (non-interactive)..."
# Run ssh test in a way that doesn't hang and doesn't accept passwords
SSH_OUTPUT="$(ssh -o BatchMode=yes -o ConnectTimeout=5 -T "$GIT_HOST" 2>&1 || true)"
echo "$SSH_OUTPUT"
# Heuristic: GitHub / Git providers print "successfully authenticated" or similar
if printf '%s\n' "$SSH_OUTPUT" | grep -i -qE 'successfully authenticated|you(\'|’)ve successfully authenticated|welcome'; then
    ok "SSH connection test indicates successful authentication."
else
    # Some providers return different messages; still treat typical failure patterns
    if printf '%s\n' "$SSH_OUTPUT" | grep -i -q 'permission denied|could not resolve hostname|no route to host'; then
        fail "SSH connection test failed. See message above."
        PASS=false
    else
        # Unknown outcome: warn but not necessarily fatal
        info "SSH test returned no clear success message; inspect the output above."
        PASS=false
    fi
fi

echo
info "Git configuration (global and local where applicable):"
if command -v git >/dev/null 2>&1; then
    git config --list --show-origin || true
    echo
    info "Git remotes for current working directory:"
    git remote -v || info "No git repo or no remotes configured in the current directory."
    echo
    info "Current git status (short):"
    git status -s || info "Not a git repository or git status failed."
else
    fail "git command not available in PATH."
    PASS=false
fi

echo
if [ "$PASS" = true ]; then
    ok "Verification completed: all checks passed (SSH agent forwarding and git configuration appear OK)."
    exit 0
else
    fail "Verification completed: some checks failed or are inconclusive. Review the output above."
    exit 2
fi
