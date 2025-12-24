# How to Test

This document lists lightweight validation checks for the app deployment repo.

## Apps Playbook

- Re-run for idempotency:

  ```bash
  cd src
  ansible-playbook playbooks/pi-apps.yml -l rpi_box_01
  ```

## Smoke Script

- Run the smoke tests against all Raspberry Pi hosts:

  ```bash
  ./scripts/ansible-smoke.sh src/playbooks/pi-apps.yml src/inventory/hosts.ini
  ```

## Pi-hole

- Check container status (requires sudo, use `-b`):

  ```bash
  ansible rpi_box_01 -m command -a "docker ps --filter name=pihole" -b
  ```

- Check admin UI responds (requires sudo, use `-b`):

  ```bash
  ansible rpi_box_01 -m command -a "curl -I http://localhost:80/admin/" -b
  ```

- The admin password is enforced from `PIHOLE_WEB_PASSWORD` during playbook runs.

- Check admin UI from your local machine:

  ```bash
  curl -I http://<ansible_host>:80/admin/
  ```

- Trigger the daily report manually (requires SMTP credentials on the host):

  ```bash
  ansible rpi_box_01 -b -m shell -a ". /etc/pihole-report.env && /usr/local/bin/pihole-report.py"
  ```

## Client DNS Troubleshooting

If your LAN DNS is set to Pi-hole but queries do not show up, verify that your
client is actually using the Pi-hole IP for DNS.

- Linux (systemd-resolved):

  ```bash
  resolvectl status
  ```

  Ensure the active interface lists `Current DNS Server: <pihole-ip>`.

- macOS:

  ```bash
  scutil --dns | grep 'nameserver\\[[0-9]*\\]'
  ```

- Windows (PowerShell):

  ```powershell
  Get-DnsClientServerAddress | Select-Object -Property InterfaceAlias,ServerAddresses
  ```

If DNS is correct but queries still do not appear, disable browser or OS
"Secure DNS"/DoH temporarily to confirm traffic reaches Pi-hole.
