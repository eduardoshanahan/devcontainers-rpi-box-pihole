#!/bin/bash
set -euo pipefail

# Determine project directory
if [ -z "${PROJECT_DIR+x}" ] || [ -z "$PROJECT_DIR" ]; then
    echo "Error: PROJECT_DIR is required"
    exit 1
fi
ENV_LOADER="$PROJECT_DIR/.devcontainer/scripts/env-loader.sh"

if [ ! -f "$ENV_LOADER" ]; then
    echo "Error: env-loader.sh not found at $ENV_LOADER"
    exit 1
fi

# Load variables: project root .env is authoritative, .devcontainer/config/.env supplies defaults
# shellcheck disable=SC1090
source "$ENV_LOADER"
load_project_env "$PROJECT_DIR"

require_var() {
    local var_name="$1"
    local value
    value="$(printenv "$var_name" 2>/dev/null || true)"
    if [ -z "$value" ]; then
        echo "Error: $var_name is required"
        exit 1
    fi
}

require_var "CONTAINER_MEMORY"
require_var "CONTAINER_CPUS"
require_var "CONTAINER_SHM_SIZE"
require_var "CONTAINER_HOSTNAME"
require_var "PYTHON_VERSION"
require_var "ANSIBLE_CORE_VERSION"
require_var "ANSIBLE_LINT_VERSION"
require_var "YAMLLINT_VERSION"

echo "Container configuration:"
echo "  Memory: $CONTAINER_MEMORY"
echo "  CPUs: $CONTAINER_CPUS"
echo "  Shared Memory: $CONTAINER_SHM_SIZE"
echo "  Hostname: $CONTAINER_HOSTNAME"
echo "  Python: $PYTHON_VERSION"
echo "  Ansible Core: $ANSIBLE_CORE_VERSION"
echo "  Ansible Lint: $ANSIBLE_LINT_VERSION"
echo "  Yamllint: $YAMLLINT_VERSION"
