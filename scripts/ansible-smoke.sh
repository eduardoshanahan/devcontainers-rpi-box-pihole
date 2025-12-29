#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ANSIBLE_ROOT="${REPO_ROOT}/src"
ANSIBLE_CFG="${ANSIBLE_ROOT}/ansible.cfg"
INVENTORY_DIR="${ANSIBLE_ROOT}/inventory"
if [ $# -lt 2 ]; then
    printf 'Usage: %s /path/to/playbook.yml /path/to/inventory.ini\n' "$0" >&2
    printf 'Optional: set SMOKE_GROUP to override the default host group (default: _boxes).\n' >&2
    exit 1
fi

PLAYBOOK="$1"
INVENTORY="$2"

if ! command -v ansible >/dev/null 2>&1; then
    echo "ansible command not found; run this script inside the devcontainer." >&2
    exit 1
fi

export ANSIBLE_CONFIG="$ANSIBLE_CFG"
export ANSIBLE_INVENTORY="$INVENTORY_DIR"

SMOKE_GROUP="${SMOKE_GROUP:-raspberry_pi_boxes}"

echo ">>> Ansible version"
ansible --version | head -n 2
echo

if command -v ansible-lint >/dev/null 2>&1; then
    echo ">>> Running ansible-lint on ${PLAYBOOK}"
    ansible-lint "$PLAYBOOK"
    echo
else
    echo "ansible-lint not available; skipping lint step." >&2
fi

if command -v yamllint >/dev/null 2>&1; then
    echo ">>> Running yamllint on ${ANSIBLE_ROOT}"
    yamllint "$ANSIBLE_ROOT"
    echo
else
    echo "yamllint not available; skipping YAML lint step." >&2
fi

run_playbook() {
    local label="$1"
    local output_file
    output_file="$(mktemp)"

    echo ">>> Executing ansible-playbook ${PLAYBOOK} (${label}, inventory: ${INVENTORY})"
    if ! ansible-playbook -i "$INVENTORY" "$PLAYBOOK" | tee "$output_file"; then
        rm -f "$output_file"
        return 1
    fi

    if [ "$label" = "second-pass" ]; then
        if grep -Eq "changed=[1-9]" "$output_file"; then
            echo "Second pass reported changes; playbook is not idempotent." >&2
            rm -f "$output_file"
            return 1
        fi
    fi

    rm -f "$output_file"
}

run_playbook "first-pass"
run_playbook "second-pass"

echo ">>> Verifying app state (group: ${SMOKE_GROUP})"
ansible -i "$INVENTORY" "$SMOKE_GROUP" -b -m shell -a "docker ps --filter name=pihole --format '{{'{{'}}.Names{{'}}'}}' | grep -q '^pihole$'"
ansible -i "$INVENTORY" "$SMOKE_GROUP" -b -m shell -a "curl -fsS http://localhost:80/admin/ >/dev/null"
