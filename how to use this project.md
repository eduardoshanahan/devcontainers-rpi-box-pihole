# How to Use This Project

This repo deploys application stacks (Pi-hole, etc.) to Raspberry Pi hosts that
already have the base OS/infra configured. Keep the base repo for provisioning
and use this repo for app-specific roles and playbooks.

## 0. Configure the Devcontainer Environment

1. Copy the root `.env.example` to `.env`:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set your host username/UID/GID plus the Ansible-related paths:
   - `ANSIBLE_CONFIG=/workspace/src/ansible.cfg`
   - `ANSIBLE_INVENTORY=/workspace/src/inventory/hosts.ini`
   - `ANSIBLE_COLLECTIONS_PATH=/workspace/src/collections:/home/<your-username>/.ansible/collections`
   - `ANSIBLE_ROLES_PATH=/workspace/src/roles`
   - `ANSIBLE_USER`, `ANSIBLE_SSH_PRIVATE_KEY_FILE`
   - `PIHOLE_WEB_PASSWORD`, `PIHOLE_TIMEZONE`, `PIHOLE_WEB_PORT`
   - `PIHOLE_NETWORK_MODE`, `PIHOLE_DNS1`, `PIHOLE_DNS2`, `PIHOLE_DNSMASQ_LISTENING`
   - `PIHOLE_LOCAL_IPV4`, `PIHOLE_ENABLE_DHCP`

The devcontainer loads these variables from `.env`, so keeping them here makes
the configuration obvious and versioned via `.env.example`.
The Pi-hole role will also keep the web password in sync with
`PIHOLE_WEB_PASSWORD` on each run.

3. Install required Ansible collections:

   ```bash
   cd src
   ansible-galaxy collection install -r requirements.yml
   ```

## 1. Prerequisites

- The Pi is already provisioned with the base OS/infra playbook (Docker Engine installed).
- `/srv/apps` exists on the target (created by the base repo).
- SSH access is working from your devcontainer.

### Base Provisioning Responsibilities

These items belong in the base provisioning project (shared across all app
stacks):

- Disable the systemd-resolved stub listener on port 53 (Pi-hole needs to bind).
- Ensure any host firewall rules allow DNS (TCP/UDP 53) and HTTP 80 as needed.
- Install Docker Engine and create `/srv/apps`.

### Auto-start (Optional)

Set `PIHOLE_SYSTEMD_AUTOSTART=true` to install a systemd unit that runs
`docker compose up -d` on boot. This recreates the container if it was removed,
while keeping data in `/srv/apps/pihole`.

## 2. Configure Inventory Host Vars

1. Copy the example host vars file and keep the real one out of git:

   ```bash
   cp src/inventory/host_vars/rpi_box.example.yml src/inventory/host_vars/rpi_box_01.yml
   ```

2. Edit `src/inventory/host_vars/rpi_box_01.yml` with the correct `ansible_host` and `ansible_port`.
3. Confirm the Pi-hole values are present in `.env` (or override them in host vars).

## 3. Verify Ansible Connectivity

```bash
cd src
ansible rpi_box_01 -i inventory/hosts.ini -m ping
```

## 4. Deploy Apps

```bash
cd src
ansible-playbook playbooks/pi-apps.yml -l rpi_box_01
```

Pi-hole should be available at `http://<pi-ip>:<PIHOLE_WEB_PORT>/admin/`.

## 4.1 Daily Pi-hole Report

The Pi-hole role can send a daily email with summary stats and top queries.

1. Set the email settings in `.env`:
   - `DAILY_REPORT_EMAIL`, `DAILY_REPORT_SENDER`
   - `DAILY_REPORT_SMTP_HOST`, `DAILY_REPORT_SMTP_PORT`
   - `DAILY_REPORT_SMTP_USER`, `DAILY_REPORT_SMTP_PASSWORD`
   - `DAILY_REPORT_SCHEDULE` (set to `daily` or `weekly`)
2. By default the report attempts Pi-hole CLI stats and falls back to the v6
   API if CLI stats are unavailable.
3. Pi-hole v6 session auth is supported when using API mode and uses
   `PIHOLE_API_PASSWORD` if set (falls back to `PIHOLE_WEB_PASSWORD`).
4. Set the API password in the Pi-hole UI to match `PIHOLE_API_PASSWORD`.
5. (Optional) Set `PIHOLE_API_TOKEN` if you want to use the legacy API flow.
6. Re-run the playbook to install the report script and cron job.

## 5. LAN DNS Setup (UCG Max)

If the UCG Max manages DHCP, set the LAN DNS server to the Pi-hole IP so
clients use it for name resolution.

1. In UniFi OS, open the UCG Max console.
2. Go to **Settings → Networks → (your LAN)**.
3. Under DHCP, set **DNS Server** to `192.168.1.58` (your Pi-hole IP).
4. Leave secondary DNS blank if you want all queries to go through Pi-hole.
5. Apply changes, then renew DHCP leases on clients.

Pi-hole should use an upstream DNS that is not itself (for example,
`192.168.1.1` or `1.1.1.1`).

Note: Clients may keep old DNS servers until their DHCP lease renews, and
devices with static DNS or DoH/"Secure DNS" enabled can bypass Pi-hole.
