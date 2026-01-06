#!/bin/sh
# Shared env loader: load project-root .env (authoritative) then fill missing from .devcontainer/config/.env
# Usage:
#   # from inside container: source /workspace/.devcontainer/scripts/env-loader.sh && load_project_env /workspace [debug]
#   # from host script: source "$PROJECT_DIR/.devcontainer/scripts/env-loader.sh" && load_project_env "$PROJECT_DIR" [debug]
#
# Debug mode:
#   - Set ENV_LOADER_DEBUG=1 (exported) or pass second param as 1 to load_project_env to print newly loaded vars.

load_project_env() {
    workspace_dir="$1"
    debug=""

    if [ -z "$workspace_dir" ]; then
        echo "Error: load_project_env requires a workspace directory"
        return 1
    fi

    if [ $# -ge 2 ]; then
        debug="$2"
    elif [ -n "${ENV_LOADER_DEBUG+x}" ]; then
        debug="$ENV_LOADER_DEBUG"
    fi
    project_env="$workspace_dir/.env"
    dev_env="$workspace_dir/.devcontainer/config/.env"

    # Capture current exported variables
    before_file="$(mktemp)"
    printenv | cut -d= -f1 | sort > "$before_file"

    # Load project root .env first (authoritative); preserve quoting
    if [ -f "$project_env" ]; then
        set -a
        # shellcheck disable=SC1090
        . "$project_env"
        set +a
    fi

    # Fill missing variables from devcontainer config without overwriting existing ones
    if [ -f "$dev_env" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            # Trim whitespace
            trimmed="$(echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
            # Skip blank lines and comments
            [ -z "$trimmed" ] && continue
            case "$trimmed" in \#*) continue ;; esac
            key="${trimmed%%=*}"
            key="$(echo "$key" | xargs)"
            current_value="$(printenv "$key" 2>/dev/null || true)"
            if [ -z "$current_value" ]; then
                # Preserve quoting in value
                eval "export $trimmed"
            fi
        done < "$dev_env"
    fi

    # Capture after state and compute newly added variables
    after_file="$(mktemp)"
    printenv | cut -d= -f1 | sort > "$after_file"

    if [ "$debug" = "1" ] || [ "$debug" = "true" ]; then
        echo "env-loader: debug enabled — listing variables added by load_project_env (workspace: $workspace_dir)"
        # comm -13 shows lines present in after_file but not before_file
        if command -v comm >/dev/null 2>&1; then
            comm -13 "$before_file" "$after_file" > "${after_file}.new"
            while IFS= read -r var; do
                [ -z "$var" ] && continue
                value="$(printenv "$var" 2>/dev/null || true)"
                printf '%s=%s\n' "$var" "$value"
            done < "${after_file}.new"
        else
            # Fallback: simple grep/diff approach
            echo "env-loader: comm not available; showing all variables (best-effort)"
            while IFS= read -r var; do
                [ -z "$var" ] && continue
                value="$(printenv "$var" 2>/dev/null || true)"
                printf '%s=%s\n' "$var" "$value"
            done < "$after_file"
        fi
    fi

    # Clean up
    rm -f "$before_file" "$after_file" "${after_file}.new" 2>/dev/null || true
}
