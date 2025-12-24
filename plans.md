# Plans

## What we find

- The repo deploys app stacks to pre-provisioned Raspberry Pi hosts via Ansible.
- Primary playbook: `src/playbooks/pi-apps.yml` targets the `raspberry_pi` group.
- Current app role is `pihole`, which renders a docker-compose file and runs it.
- Required variables are sourced from `.env`/host vars (`pihole_*`, `ANSIBLE_*`).
- Health check hits `http://localhost:<pihole_web_port>/admin/` when enabled.

## What we want to do

- Keep environment variables in `.env` and host-specific overrides in `src/inventory/host_vars/`.
- Confirm inventory and host vars match the target Pi(s).
- Use `scripts/ansible-smoke.sh` for quick lint/idempotence checks.
- Add or update app roles as new stacks are needed.
- Avoid container DNS pointing at itself during bootstrap; use configured upstreams.
- Ensure the Pi-hole web password stays in sync with `PIHOLE_WEB_PASSWORD`.
- Ensure Pi-hole listens on LAN DNS by setting `PIHOLE_DNSMASQ_LISTENING`.
- Prefer host networking for Pi-hole to avoid Docker port-forwarding DNS issues.
- Add a scheduled Pi-hole stats report via SMTP.
- Ensure report API token is available (auto-read or set `PIHOLE_API_TOKEN`).
- Use Pi-hole v6 session auth for report API access.
- Default the report to CLI mode with optional API fallback.
- Improve v6 session auth handling for report API fallback.
- Align report auth with Pi-hole v6 API password settings.
- Add a systemd autostart unit to recreate the container on boot.

## What we did

- Reviewed project structure, docs, playbooks, and the `pihole` role.
- Updated the yaml output settings to use `ansible.builtin.default` with `result_format = yaml`.
- Resolved LAN DNS reachability for Pi-hole (host networking + DNS listening).
