#!/bin/bash

# Set strict bash options
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print error messages
error() {
  echo -e "${RED}ERROR: $1${NC}" >&2
}

# Function to print success messages
success() {
  echo -e "${GREEN}$1${NC}"
}

# Function to print info messages
info() {
  echo -e "${YELLOW}$1${NC}"
}

# Load project environment via shared loader (root .env is authoritative)
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_LOADER="$PROJECT_DIR/.devcontainer/scripts/env-loader.sh"

if [ ! -f "$ENV_LOADER" ]; then
  error "Cannot find env-loader at $ENV_LOADER"
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_LOADER"
load_project_env "$PROJECT_DIR"

# Validate environment variables before launching anything
VALIDATOR="$PROJECT_DIR/.devcontainer/scripts/validate-env.sh"
if [ -f "$VALIDATOR" ]; then
  info "Validating environment variables..."
  if ! bash "$VALIDATOR"; then
    error "Environment validation failed. Please fix your .env values."
    exit 1
  fi
else
  info "Warning: validator not found at $VALIDATOR; skipping validation."
fi

# Export variables explicitly for devcontainer
export HOST_USERNAME
export HOST_UID
export HOST_GID
export GIT_USER_NAME
export GIT_USER_EMAIL
export GIT_REMOTE_URL
export EDITOR_CHOICE
export DOCKER_IMAGE_NAME
export DOCKER_IMAGE_TAG

# Validate editor choice
if [ "${EDITOR_CHOICE}" != "code" ] && [ "${EDITOR_CHOICE}" != "cursor" ] && [ "${EDITOR_CHOICE}" != "antigravity" ]; then
  error "EDITOR_CHOICE must be set to either 'code' or 'cursor' or 'antigravity' in .devcontainer/config/.env"
  exit 1
fi

# Check if the chosen editor is installed
if ! command -v "${EDITOR_CHOICE}" &>/dev/null; then
  error "${EDITOR_CHOICE} is not installed!"
  if [ "${EDITOR_CHOICE}" = "code" ]; then
    error "Please install VS Code from https://code.visualstudio.com/"
  elif [ "${EDITOR_CHOICE}" = "cursor" ]; then
    error "Please install Cursor from https://cursor.sh"
  elif [ "${EDITOR_CHOICE}" = "antigravity" ]; then
    error "Please install Antigravity from https://antigravity"
  fi
  exit 1
fi

# Launch the editor (let Dev Containers handle building/running the container)
info "Launching ${EDITOR_CHOICE} with workspace ${PWD}..."
case "${EDITOR_CHOICE}" in
  code)
    code "${PWD}" >/dev/null 2>&1 &
    ;;
  cursor)
    cursor "${PWD}" --no-sandbox >/dev/null 2>&1 &
    ;;
  antigravity)
    antigravity "${PWD}" >/dev/null 2>&1 &
    ;;
esac

success "Editor launched. Use the Dev Containers extension's \"Reopen in Container\" to start the environment."
disown || true
