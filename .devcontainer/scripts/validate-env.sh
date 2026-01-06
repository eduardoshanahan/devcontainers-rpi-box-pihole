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
    # ["PIHOLE_LOCAL_IPV4"]="Pi-hole local IPv4|^.+$"
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

require_var() {
    local var_name=$1
    local description=$2
    local pattern=$3

    if ! printenv "$var_name" >/dev/null 2>&1; then
        echo "Error: Required variable $var_name is not set"
        echo "Description: $description"
        ((errors++))
        return
    fi

    local value
    value="$(printenv "$var_name")"
    if [ -z "$value" ]; then
        echo "Error: Required variable $var_name is empty"
        echo "Description: $description"
        ((errors++))
        return
    fi

    validate_var "$var_name" "$value" "$pattern" "$description" || ((errors++))
}

is_true() {
    case "$1" in
        true|TRUE|True) return 0 ;;
        *) return 1 ;;
    esac
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

pihole_sync_enabled="$(printenv PIHOLE_SYNC_ENABLED 2>/dev/null || true)"
if is_true "$pihole_sync_enabled"; then
    require_var "PIHOLE_SYNC_PRIMARY_URL" "Pi-hole sync primary URL" "^https?://.+"
    require_var "PIHOLE_SYNC_PRIMARY_IP" "Pi-hole sync primary IP URL" "^https?://.+"
    require_var "PIHOLE_SYNC_INTERVAL" "Pi-hole sync interval seconds" "^[0-9]+$"
    require_var "PIHOLE_SYNC_BACKOFF_SECONDS" "Pi-hole sync backoff seconds" "^[0-9]+$"
    require_var "PIHOLE_SYNC_IMAGE" "Pi-hole sync image" "^.+$"
    require_var "PIHOLE_SYNC_PASSWORD" "Pi-hole sync password" "^.+$"
    require_var "PIHOLE_SYNC_LOCAL_API" "Pi-hole sync local API URL" "^https?://.+/api/?$"
    require_var "PIHOLE_SYNC_VERIFY" "Pi-hole sync verify flag" "^(true|false)$"
    require_var "PIHOLE_SYNC_VERIFY_DELAY" "Pi-hole sync verify delay seconds" "^[0-9]+$"
fi

pihole_alert_enabled="$(printenv PIHOLE_ALERT_ENABLED 2>/dev/null || true)"
if is_true "$pihole_alert_enabled"; then
    require_var "PIHOLE_ALERT_EMAIL_TO" "Pi-hole alert recipient email" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    require_var "PIHOLE_ALERT_EMAIL_FROM" "Pi-hole alert sender email" "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    require_var "PIHOLE_ALERT_SMTP_HOST" "Pi-hole alert SMTP host" "^.+$"
    require_var "PIHOLE_ALERT_SMTP_PORT" "Pi-hole alert SMTP port" "^[0-9]+$"
    require_var "PIHOLE_ALERT_SMTP_USER" "Pi-hole alert SMTP user" "^.+$"
    require_var "PIHOLE_ALERT_SMTP_PASSWORD" "Pi-hole alert SMTP password" "^.+$"
    require_var "PIHOLE_ALERT_PEER_HOST" "Pi-hole alert peer host" "^.+$"
    require_var "PIHOLE_ALERT_WEB_URL" "Pi-hole alert web URL" "^https?://.+/admin/.*$"
    require_var "PIHOLE_ALERT_WEB_URL_HOSTNAME" "Pi-hole alert web URL hostname" "^.+$"
    require_var "PIHOLE_ALERT_WEB_URL_IP" "Pi-hole alert web URL IP" "^.+$"
    require_var "PIHOLE_ALERT_VERIFY_TLS" "Pi-hole alert TLS verify flag" "^(true|false)$"
    require_var "PIHOLE_ALERT_LOG" "Pi-hole alert log path" "^.+$"
    require_var "PIHOLE_ALERT_TIMEOUT_SECONDS" "Pi-hole alert timeout seconds" "^[0-9]+$"
    require_var "PIHOLE_ALERT_CRON_MINUTE" "Pi-hole alert cron minute" "^.+$"
    require_var "PIHOLE_ALERT_CRON_HOUR" "Pi-hole alert cron hour" "^.+$"
    require_var "PIHOLE_ALERT_CRON_USER" "Pi-hole alert cron user" "^.+$"
    require_var "PIHOLE_ALERT_ENV_PATH" "Pi-hole alert env path" "^.+$"
    require_var "PIHOLE_ALERT_SCRIPT_PATH" "Pi-hole alert script path" "^.+$"
fi

if [ $errors -gt 0 ]; then
    echo -e "\nFound $errors error(s). Please fix them and try again."
    exit 1
else
    echo -e "\nAll environment variables are valid!"
fi
