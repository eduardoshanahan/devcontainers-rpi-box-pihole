#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    printf 'Usage: %s /path/to/.devcontainer/scripts\n' "$0"
    exit 1
fi

SCRIPTS_DIR="$1"

printf 'Applying executable permissions in: %s\n' "$SCRIPTS_DIR"

for f in env-loader.sh verify-git-ssh.sh init-devcontainer.sh post-create.sh \
         bash-prompt.sh ssh-agent-setup.sh load-env.sh; do
    if [ -f "$SCRIPTS_DIR/$f" ]; then
        chmod +x "$SCRIPTS_DIR/$f"
        printf 'Made executable: %s\n' "$SCRIPTS_DIR/$f"
    else
        printf 'Not found (skipping): %s\n' "$SCRIPTS_DIR/$f"
    fi
done

echo "Done."
