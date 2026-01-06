# Agent Instructions

This file defines **rules and expectations for AI coding agents**
(Codex, Cursor, Continue, Claude-based agents, etc.) operating in this repository.

If there is any conflict between this file and README.md, **this file takes precedence for AI behavior**.

---

## 1. Project Type

- Infrastructure-as-Code repository
- Primary tools:
  - **Ansible**
  - **Docker**
- Target systems: Linux (Ubuntu, Raspberry Pi)
- Deployment style: idempotent, reproducible, non-interactive, fail-fast

---

## 2. Allowed Languages & Formats

Preferred and allowed:

- YAML (Ansible playbooks, roles, Docker Compose)
- Jinja2 templates (`.j2`)
- Markdown (`.md`)
- Shell scripts (`.sh`) — POSIX-compliant only
- `.env` files (configuration only)

Avoid unless explicitly requested:

- Python (only for Ansible filters or helpers)
- Any compiled languages

---

## 3. Ansible Rules (IMPORTANT)

### General

- Follow **Ansible best practices**
- Tasks MUST be:
  - idempotent
  - deterministic
  - safe to re-run
- Always prefer:
  - `ansible.builtin.*` modules
  - explicit modules over `shell` / `command`
- Use `become: true` explicitly when required
- Do NOT assume passwordless sudo

---

### Variables & Configuration (NO MAGIC DEFAULTS)

- **Avoid implicit or “magical” defaults**
- Required variables MUST:
  - be explicitly documented
  - fail execution if missing
- Prefer configuration via:
  - `.env` files
  - inventory variables
  - group_vars / host_vars (non-vaulted)

#### Mandatory behavior

If a required variable is missing:

- The playbook or role **MUST FAIL**
- Use:
  - `assert`
  - `fail`
  - `ansible.builtin.assert`

**Example pattern (preferred):**

```yaml
- name: Validate required variables
  ansible.builtin.assert:
    that:
      - my_required_var is defined
      - my_required_var | length > 0
    fail_msg: "Required variable 'my_required_var' is missing or empty"
```

---

### Environment Variables

- Do NOT silently fall back to defaults
- `.env` variables are preferred when applicable
- If `.env` variables are required and missing:
  - execution MUST fail
- Do NOT auto-generate values

---

## 4. Docker Rules (IMPORTANT)

### Dockerfiles

- Use explicit base image versions (no `latest`)
- Prefer:
  - small, well-known images
  - multi-stage builds where appropriate
- Avoid unnecessary packages
- Never bake secrets into images

---

### Docker Compose

- Use explicit image tags
- Prefer `env_file:` over inline `environment:` blocks
- `.env` files:
  - are configuration, not secrets
  - MUST be documented
  - MUST be validated if required

If a required environment variable is missing:

- container startup SHOULD fail clearly
- prefer Compose-level validation where possible

---

### Docker + Ansible Integration

- Ansible tasks managing Docker MUST:
  - check that Docker is installed
  - ensure Docker daemon is running
- Prefer:
  - `community.docker.*` modules
- Do NOT assume Docker socket permissions

---

## 5. Files & Paths Safety

### DO NOT MODIFY unless explicitly instructed

- `.vault*`
- `*.key`, `*.pem`
- `group_vars/*vault*`
- `host_vars/*vault*`
- Generated files
- Inventory files unless asked
- `.env` files (unless explicitly requested)

### SAFE TO MODIFY

- `roles/**/tasks/*.yml`
- `roles/**/templates/*.j2`
- `roles/**/defaults/*.yml` (documented defaults only)
- Dockerfiles
- `docker-compose*.yml`
- Playbooks under root or `playbooks/`

---

## 6. Secrets & Security

- NEVER generate real passwords, tokens, or API keys
- Use placeholders:
  - `CHANGEME`
  - `example_password`
  - `{{ vault_* }}` variables
- Never echo secrets
- Never disable TLS or certificate validation unless explicitly instructed

---

## 7. Style & Formatting

### YAML

- 2-space indentation
- Explicit booleans (`true` / `false`)
- No implicit defaults
- Consistent key ordering within files

### Ansible

- Task names are mandatory and descriptive
- Avoid unnamed or inline tasks
- Validation tasks should run early

### Docker

- Readable, commented Dockerfiles
- Minimal layers
- Clear separation between build-time and runtime config

---

## 8. Tooling & Execution Assumptions

- Assume execution via:
  - `ansible-playbook`
  - CI pipelines
- Do NOT:
  - prompt for input
  - assume a TTY
  - rely on interactive shells

---

## 9. Change Scope Rules

- Make the **smallest change necessary**
- Do NOT refactor unrelated code
- Do NOT rename files, services, or roles unless asked
- When unsure, ask for clarification

---

## 10. Documentation Expectations

- Document:
  - required variables
  - required `.env` entries
  - failure conditions
- Prefer concise, factual documentation
- No marketing language

---

## 11. Git & Workflow

- Do NOT create git commits
- Do NOT bump versions
- Do NOT modify CI/CD unless explicitly requested

---

## 12. Agent Behavior

- Explain *what* changed and *why*
- Prefer safety over convenience
- Fail fast and loudly on misconfiguration
- Never assume production access
- Never assume internet access on target hosts

---

## End of Agent Instructions
