#!/bin/bash
set -euo pipefail

# Required variables with their descriptions and validation rules
declare -A required_vars=(
    ["HOST_USERNAME"]="System username|^[a-z_][a-z0-9_-]*$"
    ["HOST_UID"]="User ID|^[0-9]+$"
    ["HOST_GID"]="Group ID|^[0-9]+$"
    ["GIT_USER_NAME"]="Git author name|^[a-zA-Z0-9 ._-]+$"
    ["GIT_USER_EMAIL"]="Git author email|^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    ["GIT_REMOTE_URL"]="Git remote URL|^(https://|git@).+"
    ["EDITOR_CHOICE"]="Editor selection|^(code|cursor|antigravity)$"
    ["CONTAINER_HOSTNAME"]="Container hostname|^[a-zA-Z][a-zA-Z0-9-]*$"
    ["CONTAINER_MEMORY"]="Container memory limit|^[0-9]+[gGmM]$"
    ["CONTAINER_CPUS"]="Container CPU count|^[0-9]+(\\.[0-9]+)?$"
    ["CONTAINER_SHM_SIZE"]="Container shared memory size|^[0-9]+[gGmM]$"
    ["DOCKER_IMAGE_NAME"]="Docker image name|^[a-z0-9][a-z0-9._-]+$"
    ["DOCKER_IMAGE_TAG"]="Docker image tag|^[a-zA-Z0-9][a-zA-Z0-9._-]+$"
    ["ANSIBLE_USER"]="Ansible SSH user|^[a-z_][a-z0-9_-]*$"
    ["ANSIBLE_SSH_PRIVATE_KEY_FILE"]="Ansible SSH private key file|^.+$"
    ["PIHOLE_WEB_PASSWORD"]="Pi-hole web password|^.+$"
    ["PIHOLE_TIMEZONE"]="Pi-hole timezone|^.+$"
    ["PIHOLE_WEB_PORT"]="Pi-hole web port|^[0-9]+$"
    ["PIHOLE_DNS1"]="Pi-hole upstream DNS 1|^.+$"
    ["PIHOLE_DNS2"]="Pi-hole upstream DNS 2|^.+$"
    ["PIHOLE_LOCAL_IPV4"]="Pi-hole local IPv4|^.+$"
    ["PIHOLE_ENABLE_DHCP"]="Pi-hole DHCP enable flag|^(true|false)$"
)

validate_var() {
    local var_name=$1
    local var_value=$2
    local pattern=$3
    local description=$4

    if ! [[ "$var_value" =~ ${pattern} ]]; then
        echo "Error: $var_name is invalid"
        echo "Description: $description"
        echo "Pattern: $pattern"
        echo "Current value: $var_value"
        return 1
    fi
    return 0
}

errors=0
echo "Validating required variables..."
for var in "${!required_vars[@]}"; do
    IFS="|" read -r description pattern <<< "${required_vars[$var]}"
    if ! printenv "$var" >/dev/null 2>&1; then
        echo "Error: Required variable $var is not set"
        echo "Description: $description"
        ((errors++))
    else
        value="$(printenv "$var")"
        if [ -z "$value" ]; then
            echo "Error: Required variable $var is empty"
            echo "Description: $description"
            ((errors++))
            continue
        fi
        validate_var "$var" "$value" "$pattern" "$description" || ((errors++))
    fi
done

if [ $errors -gt 0 ]; then
    echo -e "\nFound $errors error(s). Please fix them and try again."
    exit 1
else
    echo -e "\nAll environment variables are valid!"
fi
