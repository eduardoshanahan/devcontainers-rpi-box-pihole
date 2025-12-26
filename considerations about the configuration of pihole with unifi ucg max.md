# Considerations about the Configuration of Pi-hole with UniFi UCG Max

This document summarizes a **working, production‑ready setup** for running **Pi-hole in Docker** on a LAN with a **UniFi UCG Max** as the router and DHCP server.

The goal is:
- Centralized DNS via Pi-hole
- Clean local name resolution
- Predictable behavior
- Minimal magic and easy debugging

---

## 1. Reference Topology

| Component | IP | Role |
|---------|----|-----|
| UniFi UCG Max | 192.168.1.1 | Router, Firewall, DHCP |
| Pi-hole (Docker on RPi) | 192.168.1.58 | DNS |
| LAN Clients | DHCP | Use Pi-hole |

---

## 2. Core Design Principles

1. **Pi-hole is the only DNS authority**
2. **UniFi provides DHCP only**
3. **Infrastructure devices get static DNS records**
4. **Clients use DHCP + search domain**
5. Avoid DNS loops and fallbacks

---

## 3. Pi-hole Docker Setup Notes

### Volumes (example)
```yaml
/etc/pihole        -> /srv/apps/pihole/etc-pihole
/etc/dnsmasq.d     -> /srv/apps/pihole/etc-dnsmasq.d
```

### Networking (recommended)
```yaml
network_mode: host
```

### Restart policy
```yaml
restart: unless-stopped
```

---

## 4. Pi-hole DNS Settings

### Upstream DNS
Use **one provider only**.

Recommended:
- Cloudflare
  - 1.1.1.1
  - 1.0.0.1

Do **not** mix providers.

---

### Advanced DNS
- Enable:
  - Never forward non-FQDNs
  - Never forward reverse lookups for private IP ranges
- Disable:
  - DNSSEC (can cause SERVFAIL in Docker/RPi setups)

---

### Interface Settings
Recommended and safe:
```
Allow only local requests
```

This allows LAN clients but prevents Pi-hole from becoming an open resolver.

---

## 5. Local Domain Design

### Recommended local domain
```
home.arpa
```

Example used in this setup:
```
examplelab.home.arpa
```

This domain is:
- RFC-compliant
- Never public
- Ideal for home networks

---

### Pi-hole Domain Settings
```
Settings → DNS → DNS domain settings
```

Set:
```
Domain: examplelab.home.arpa
Enable: Expand hostnames
```

---

## 6. Local DNS Records (Important)

Infrastructure devices **must be added manually**.

Example:
```
rpi-box-01 → 192.168.1.58
usw-lite-poe → 192.168.1.4
```

With the domain set, Pi-hole resolves:
- rpi-box-01
- rpi-box-01.examplelab.home.arpa

---

## 7. UniFi UCG Max Configuration

### DHCP (LAN Network)
```
DNS Server: Manual
Primary DNS: 192.168.1.58
Secondary DNS: (empty)
Domain Name: examplelab.home.arpa
```

This pushes the **search domain** to clients.

---

### Important Note on UniFi Device Names
- UniFi device names are **UI metadata only**
- They do **not** create DNS records
- Switches/APs will not auto-register in DNS

Always use Pi-hole for naming infrastructure.

---

## 8. Infrastructure Device DNS Settings

For switches, APs, servers:

```
Preferred DNS: 192.168.1.58
Alternate DNS: (empty)
Gateway: 192.168.1.1
```

Avoid pointing devices to the router for DNS.

---

## 9. Client Behavior (Linux example)

After DHCP renew, clients should show:
```
DNS Server: 192.168.1.58
DNS Domain: examplelab.home.arpa
```

Then both work:
```bash
ping rpi-box-01
ping rpi-box-01.examplelab.home.arpa
ssh user@rpi-box-01
```

If short names don’t work:
```bash
sudo dhclient -r
sudo dhclient
```

---

## 10. Common Pitfalls to Avoid

| Mistake | Result |
|------|-------|
| Secondary DNS set to 8.8.8.8 | Pi-hole bypassed |
| DNSSEC enabled | SERVFAIL |
| Using router as DNS upstream | DNS loops |
| Expecting UniFi names to resolve | Failure |
| No DHCP search domain | Short names fail |

---

## 11. Debugging Checklist

### Test Pi-hole directly
```bash
nslookup google.com 192.168.1.58
```

### Check client DNS
```bash
resolvectl status
```

### Tail Pi-hole logs
```
Tools → Tail pihole.log
```

---

## 12. Final Recommended Architecture

```
Client
  ↓
systemd / OS resolver
  ↓
Pi-hole (192.168.1.58)
  ↓
Cloudflare DNS
```

---

## 13. Final Thoughts

This setup prioritizes:
- Simplicity
- Explicit configuration
- Debuggability
- Long-term stability

It avoids relying on hidden UniFi behaviors and keeps DNS logic in one place: **Pi-hole**.

---

End of document.
