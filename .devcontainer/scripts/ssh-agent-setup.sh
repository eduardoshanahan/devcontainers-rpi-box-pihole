#!/bin/bash
# --- SSH Agent Setup ---

# Exit on error, undefined vars, and pipe failures
set -euo pipefail
IFS=$'\n\t'

# Function to check file permissions
check_file_permissions() {
  local file="$1"
  local expected_perms="$2"
  local actual_perms

  actual_perms=$(stat -c %a "$file")
  if [ "$actual_perms" != "$expected_perms" ]; then
    echo "Warning: $file has incorrect permissions ($actual_perms). Expected: $expected_perms"
    return 1
  fi
  return 0
}

# Check for an interactive shell.
if [[ $- == *i* ]]; then
  # Create .ssh directory with proper permissions if it doesn't exist
  if [ ! -d "$HOME/.ssh" ]; then
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
  else
    check_file_permissions "$HOME/.ssh" "700" || chmod 700 "$HOME/.ssh"
  fi

  # If SSH_AUTH_SOCK points to a forwarded agent, trust it; otherwise start our own
  if [ -n "${SSH_AUTH_SOCK+x}" ]; then
    if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
      echo "Using forwarded SSH agent at ${SSH_AUTH_SOCK}"
    else
      echo "SSH_AUTH_SOCK is set but invalid. Starting a new agent..."
      eval "$(ssh-agent -s)" >/dev/null
      export SSH_AUTH_SOCK SSH_AGENT_PID
    fi
  else
    echo "No forwarded SSH agent detected. Starting a new agent..."
    eval "$(ssh-agent -s)" >/dev/null
    export SSH_AUTH_SOCK SSH_AGENT_PID
  fi

  # Save the agent variables with proper permissions
  umask 077
  ssh_agent_pid=""
  if [ -n "${SSH_AGENT_PID+x}" ]; then
    ssh_agent_pid="$SSH_AGENT_PID"
  fi
  {
    echo "export SSH_AUTH_SOCK=${SSH_AUTH_SOCK}"
    echo "export SSH_AGENT_PID=${ssh_agent_pid}"
  } >"$HOME/.ssh/agent_env"

  if [ -z "$ssh_agent_pid" ]; then
    echo "Warning: SSH_AGENT_PID is not set (using forwarded agent)."
  fi

  # Only add private keys when we're running our own agent to avoid duplicating host-managed keys
  if [ -n "$ssh_agent_pid" ]; then
    echo "Looking for SSH keys in $HOME/.ssh/"
    for key in "$HOME/.ssh/"*; do
      if [ -f "$key" ]; then
        if [[ "$key" != *.pub ]] && [[ "$key" != *known_hosts* ]] && [[ "$key" != *agent_env ]]; then
          echo "Attempting to add private key: $key"
          if check_file_permissions "$key" "600"; then
            if ssh-add "$key" 2>/dev/null; then
              echo "Successfully added key: $key"
            else
              echo "Failed to add key: $key"
            fi
          else
            echo "Warning: $key has incorrect permissions. Skipping."
          fi
        fi
      fi
    done
  else
    echo "Skipping ssh-add because we are using the forwarded agent."
  fi

  # Show all loaded keys
  echo "Currently loaded keys:"
  ssh-add -l || echo "ssh-add failed (no identities or agent not available)."
fi

set +e
# --- End SSH Agent Setup ---
