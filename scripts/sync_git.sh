#!/bin/bash

# Enable strict mode
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
info() { echo -e "${YELLOW}  $1${NC}"; }
success() { echo -e "${GREEN} $1${NC}"; }
error() { echo -e "${RED} $1${NC}" >&2; }

# Get the actual project directory (parent of scripts directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Load environment variables using the shared loader (project root .env is authoritative)
ENV_LOADER="$PROJECT_DIR/.devcontainer/scripts/env-loader.sh"
if [ ! -f "$ENV_LOADER" ]; then
    error "env-loader.sh not found at $ENV_LOADER"
    exit 1
fi
# shellcheck disable=SC1090
source "$ENV_LOADER"
load_project_env "$PROJECT_DIR"

require_env_set() {
    local var_name="$1"
    if ! printenv "$var_name" >/dev/null 2>&1; then
        error "Missing required environment variable: $var_name"
        exit 1
    fi
}

require_env_nonempty() {
    local var_name="$1"
    local value
    value="$(printenv "$var_name" 2>/dev/null || true)"
    if [ -z "$value" ]; then
        error "Missing required environment variable: $var_name"
        exit 1
    fi
}

require_env_nonempty "BRANCH"
require_env_nonempty "FORCE_PULL"
require_env_nonempty "GIT_REMOTE_URL"
require_env_nonempty "GIT_SYNC_REMOTES"
require_env_set "GIT_SYNC_PUSH_REMOTES"

BRANCH="$(printenv BRANCH)"
FORCE_PULL="$(printenv FORCE_PULL)"
GIT_REMOTE_URL="$(printenv GIT_REMOTE_URL)"
GIT_SYNC_REMOTES="$(printenv GIT_SYNC_REMOTES)"
GIT_SYNC_PUSH_REMOTES="$(printenv GIT_SYNC_PUSH_REMOTES)"

normalize_list() {
    local raw="$1"
    raw="${raw//,/ }"
    local result=()
    for item in $raw; do
        [ -z "$item" ] && continue
        local exists=false
        for seen in "${result[@]}"; do
            if [ "$seen" = "$item" ]; then
                exists=true
                break
            fi
        done
        if [ "$exists" = false ]; then
            result+=("$item")
        fi
    done
    if [ "${#result[@]}" -gt 0 ]; then
        printf '%s\n' "${result[@]}"
    fi
}

mapfile -t remote_list < <(normalize_list "$GIT_SYNC_REMOTES")
if [ "${#remote_list[@]}" -eq 0 ]; then
    error "GIT_SYNC_REMOTES is empty after normalization"
    exit 1
fi
primary_remote="${remote_list[0]}"

mapfile -t push_targets < <(normalize_list "$GIT_SYNC_PUSH_REMOTES")

remote_env_key() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g'
}

remote_has_branch() {
    local remote="$1"
    local branch="$2"
    git ls-remote --heads "$remote" "$branch" | grep -q "$branch"
}

ensure_remote() {
    local remote="$1"
    if git remote get-url "$remote" >/dev/null 2>&1; then
        return
    fi

    local env_suffix
    env_suffix="$(remote_env_key "$remote")"
    local remote_url_var="GIT_REMOTE_URL_${env_suffix}"
    local remote_url=""
    if printenv "$remote_url_var" >/dev/null 2>&1; then
        remote_url="$(printenv "$remote_url_var")"
    fi

    if [ -z "$remote_url" ] && [ "$remote" = "$primary_remote" ]; then
        remote_url="$GIT_REMOTE_URL"
    fi

    if [ -z "$remote_url" ]; then
        error "Remote '$remote' is not configured. Set $remote_url_var (or GIT_REMOTE_URL for the primary remote) in .env."
        exit 1
    fi

    git remote add "$remote" "$remote_url"
    info "Added remote '$remote': $remote_url"
}

ensure_branch_checked_out() {
    local branch="$1"
    if git rev-parse --verify --quiet "refs/heads/$branch" >/dev/null; then
        git checkout "$branch" >/dev/null 2>&1 || git checkout "$branch"
    else
        info "Creating local branch $branch"
        git checkout -b "$branch"
    fi
}

sync_remote() {
    local remote="$1"
    local branch="$2"
    if [ $# -lt 3 ] || [ -z "$3" ]; then
        error "sync_remote requires a mode (normal or force)"
        exit 1
    fi
    local mode="$3"

    if [ "$mode" = "force" ]; then
        info "Force syncing from $remote/$branch"
        if remote_has_branch "$remote" "$branch"; then
            git fetch "$remote" "$branch"
            git reset --hard "$remote/$branch"
            git clean -fd
        else
            info "Remote $remote does not have $branch. Pushing current branch upstream."
            git push -u "$remote" "$branch"
        fi
    else
        if remote_has_branch "$remote" "$branch"; then
            info "Rebasing onto $remote/$branch"
            git pull --rebase "$remote" "$branch"
        else
            info "Remote $remote does not have $branch. Pushing current branch upstream."
            git push -u "$remote" "$branch"
        fi
    fi
}

ensure_upstream_tracking() {
    local remote="$1"
    local branch="$2"
    if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
        return
    fi
    if remote_has_branch "$remote" "$branch"; then
        info "Setting upstream of $branch to $remote/$branch"
        git branch --set-upstream-to="$remote/$branch" "$branch" >/dev/null 2>&1 || \
            git branch -u "$remote/$branch" "$branch"
    fi
}

main() {
    cd "$PROJECT_DIR" || { error "Project directory not found!"; exit 1; }
    info "Working in directory: $PROJECT_DIR"

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        error "This directory is not a git repository. Initialize it first."
        exit 1
    fi

    for remote in "${remote_list[@]}"; do
        ensure_remote "$remote"
    done

    current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ "$current_branch" = "HEAD" ] || [ -z "$current_branch" ]; then
        current_branch="main"
    fi
    target_branch="$BRANCH"

    if [ "$FORCE_PULL" != "true" ] && ! git diff --quiet --ignore-submodules HEAD --; then
        error "Local changes detected. Commit/stash them or run FORCE_PULL=true ./scripts/sync_git.sh"
        exit 1
    fi

    ensure_branch_checked_out "$target_branch"
    info "Syncing branch $target_branch"

    for remote in "${remote_list[@]}"; do
        if [ "$remote" = "$primary_remote" ] && [ "$FORCE_PULL" = "true" ]; then
            sync_remote "$remote" "$target_branch" "force"
        else
            sync_remote "$remote" "$target_branch" "normal"
        fi
    done

    ensure_upstream_tracking "$primary_remote" "$target_branch"

    if [ "${#push_targets[@]}" -gt 0 ]; then
        for remote in "${push_targets[@]}"; do
            ensure_remote "$remote"
            info "Pushing $target_branch to $remote"
            if remote_has_branch "$remote" "$target_branch"; then
                git push "$remote" "$target_branch"
            else
                git push -u "$remote" "$target_branch"
            fi
        done
    fi

    success "Git sync complete!"
}

main "$@"
