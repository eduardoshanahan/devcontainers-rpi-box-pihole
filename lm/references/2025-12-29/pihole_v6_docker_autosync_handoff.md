# Pi-hole v6 HA Deployment (Docker Compose) with Automatic API-Based Sync

**Implementation handoff document**  
_UI on primary is authoritative; replicas auto-sync via a small sidecar container_

---

## 1. Executive summary

**Goal:**  
Run multiple Pi-hole v6 instances (Docker Compose on Ubuntu 24.04) where:

- One **primary** node is configured via the Pi-hole UI
- One or more **replicas** automatically and continuously converge to the primary
- Synchronization uses the **Pi-hole v6 REST API**
- **Ansible** is used only for provisioning and upgrades
- After deployment, **no manual actions** or Ansible runs are required for day-to-day operation

This design avoids v5-era file or database replication and aligns with Pi-hole v6’s API-driven model.

---

## 2. Design principles

- **Primary is authoritative**  
  All configuration changes are made via the Pi-hole UI on the primary node.

- **Replicas pull configuration**  
  Each replica periodically pulls configuration from the primary and applies it locally.

- **API-based synchronization only**  
  No rsync, no `gravity.db`, no direct manipulation of `/etc/pihole` contents.

- **Fully containerized runtime**  
  Sync logic runs in a small companion container managed by Docker Compose.

---

## 3. Assumptions and scope

### Environment

- Raspberry Pi hardware running **Ubuntu 24.04 Server**
- Pi-hole v6 running in **Docker via Docker Compose**
- A shared Ansible repository deploys the same Compose project to all nodes
- Secrets are provided via a `.env` file installed by Ansible (permissions `0600`)

### Sync scope

The sync process pulls and applies **all stable configuration exposed by `/api/config`**, typically including:

- Local DNS records (A / AAAA)
- CNAMEs
- Adlists
- Groups
- Clients
- DNS and blocking settings

Host-specific settings (interfaces, IP bindings) must remain **outside the sync scope** and be managed via Ansible host variables.

---

## 4. High-level architecture

Each node runs the same Docker Compose project.

| Node role | Services | Notes |
| --------- | -------- | ----- |
| Primary | `pihole` | Configured via UI; no sync service |
| Replica | `pihole`, `pihole-sync` | Pulls config from primary via API |

**Key property:**  
Replicas remain fully functional DNS resolvers even if the primary is offline. They converge automatically when connectivity returns.

---

## 5. Docker Compose structure

### `docker-compose.yml` (simplified)

```yaml
services:
  pihole:
    image: pihole/pihole:latest
    container_name: pihole
    network_mode: host
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - pihole-data:/etc/pihole

  pihole-sync:
    image: alpine:3
    container_name: pihole-sync
    restart: unless-stopped
    depends_on:
      - pihole
    env_file:
      - .env
    volumes:
      - ./sync:/sync:ro
    command: ["/sync/sync.sh"]

volumes:
  pihole-data:
```

### Notes

- `network_mode: host` is typical for Pi-hole (DNS on port 53).
- Both containers read the same `.env` file.
- On the **primary**, the `pihole-sync` service should be omitted or templated out.

---

## 6. Environment file contract (`.env`)

Installed by Ansible with permissions `0600`.

```dotenv
# Required on all nodes
TZ=Europe/Dublin
PIHOLE_PASSWORD=change_me_to_a_strong_secret

# Required on replica nodes only
PRIMARY_PIHOLE=https://pihole-primary.local
SYNC_INTERVAL=300
```

### Recommendations

- Use a DNS name for `PRIMARY_PIHOLE` backed by DHCP reservation or static DNS.
- `SYNC_INTERVAL` is in seconds; 300 (5 minutes) is a good default.
- If the Pi-hole UI/API password changes, update replicas via Ansible and they will recover automatically.

---

## 7. Replica sync container implementation

### File: `sync/sync.sh`

```sh
#!/bin/sh
set -eu

PRIMARY="${PRIMARY_PIHOLE:?PRIMARY_PIHOLE is required on replicas}"
INTERVAL="${SYNC_INTERVAL:-300}"
PASSWORD="${PIHOLE_PASSWORD:?PIHOLE_PASSWORD is required}"

LOCAL_API="http://127.0.0.1/api"

echo "[pihole-sync] starting; primary=$PRIMARY interval=${INTERVAL}s"

while true; do
  rm -f /tmp/cookies.txt

  # Authenticate to primary (session-based auth in v6)
  if ! curl -sk -c /tmp/cookies.txt -X POST "$PRIMARY/api/auth"       -d "password=$PASSWORD" >/dev/null; then
    echo "[pihole-sync] auth failed; retrying in 30s"
    sleep 30
    continue
  fi

  # Export configuration
  CONFIG="$(curl -sk -b /tmp/cookies.txt "$PRIMARY/api/config" || true)"
  if [ -z "$CONFIG" ]; then
    echo "[pihole-sync] export empty; retrying in 30s"
    sleep 30
    continue
  fi

  # Import configuration locally
  if ! echo "$CONFIG" | curl -sk -X POST       -H "Content-Type: application/json"       --data-binary @-       "$LOCAL_API/config" >/dev/null; then
    echo "[pihole-sync] import failed; retrying in 30s"
    sleep 30
    continue
  fi

  echo "[pihole-sync] sync ok; sleeping ${INTERVAL}s"
  sleep "$INTERVAL"
done
```

---

## 8. Ansible responsibilities (one-time)

Ansible should:

- Install Docker Engine and Docker Compose
- Create the project directory (e.g. `/srv/pihole`)
- Install:
  - `docker-compose.yml`
  - `.env` (0600)
  - `sync/sync.sh` (0755, replicas only)
- Start the stack: `docker compose up -d`
- Disable or omit the sync container on the primary

---

## 9. Security and operations

- Treat the Pi-hole UI/API password as a secret (Ansible Vault recommended).
- Restrict UI/API access to trusted networks.
- Prefer HTTPS for `PRIMARY_PIHOLE`.
- Ensure NTP/time sync is enabled on all nodes.
- Avoid per-node configuration changes via the UI.

---

## 10. Scaling and lifecycle

### Normal operation

- Configure **only** the primary via UI
- Replicas auto-converge
- No Ansible runs required

### Adding a new replica

1. Provision Ubuntu
2. Add host to Ansible inventory
3. Run Ansible once
4. Replica begins syncing automatically

---

End of document
