# Raspberry Pi Apps (Pihole by way of Ansible)

This repo deploys Docker-based applications to Raspberry Pi hosts that have
already been provisioned by the [rpi-box project](https://github.com/eduardoshanahan/devcontainers-rpi-box). It is designed to run inside a similar devcontainer workflow and focus only on app stacks (Pi-hole in this case).

## Quick Start

1. Copy `.env.example` to `.env`, then run `./launch.sh`.
2. Reopen in container (VS Code/Cursor/Antigravity) to use the preconfigured Ansible tools.
3. Configure inventory + host vars for your Pi.
4. Run the apps playbook: `ansible-playbook src/playbooks/pi-apps.yml -l rpi_box_01`.

## Key Docs

- Environment variables: [working with environment variables](working%20with%20environment%20variables.md)
- Usage: [how to use this project.md](how%20to%20use%20this%20project.md)
- Pi-hole considerations: [considerations about the configuration of pihole with unifi ucg max.md](considerations%20about%20the%20configuration%20of%20pihole%20with%20unifi%20ucg%20max.md)
- Testing: [how to test.md](how%20to%20test.md)

## Helpful Scripts

- Lint + idempotence + checks: `scripts/ansible-smoke.sh`
- Devcontainer launcher: `launch.sh`
