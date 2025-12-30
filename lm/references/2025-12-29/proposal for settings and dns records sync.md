# Pi-hole Primary → Secondary Sync (Ansible Design)

Scope

This document describes how to synchronize a secondary Pi-hole instance with a primary using Ansible, combining:

Pi-hole v6 API for runtime and structured configuration

File-based sync (rsync) for local DNS records and gravity-related data

This approach is compatible with Pi-hole v6.x, Docker or bare-metal.

High-Level Architecture
Primary Pi-hole
 ├─ API (export config snapshot)
 ├─ /etc/pihole/custom.list
 ├─ /etc/dnsmasq.d/05-pihole-custom-cname.conf
 └─ gravity / adlists (optional)

        ↓ Ansible (push)

Secondary Pi-hole
 ├─ API (import config)
 ├─ local DNS files
 └─ DNS reload / container restart

Responsibilities Split
API-managed (JSON)

Global Pi-hole configuration

DNS behavior (upstreams, DNSSEC, interfaces)

DHCP configuration (if enabled)

Privacy & query logging

FTL engine tuning

File-managed (rsync)

Local DNS A / AAAA records (custom.list)

Local DNS CNAMEs (05-pihole-custom-cname.conf)

Adlists (optional)

Gravity DB (optional)

Inventory Assumptions
[pihole_primary]
pihole-01 ansible_host=192.168.1.58

[pihole_secondary]
pihole-02 ansible_host=192.168.1.59

[pihole:children]
pihole_primary
pihole_secondary

Required Variables
pihole_api_password: "super_secret_password"

pihole_api_base_path: "/api"
pihole_config_dir: "/srv/pihole-config"

pihole_custom_dns_files:

- custom.list
- 05-pihole-custom-cname.conf

Role Layout
roles/
└─ pihole_sync/
   ├─ tasks/
   │  ├─ export.yml
   │  ├─ import.yml
   │  ├─ filesync.yml
   │  └─ reload.yml
   ├─ templates/
   │  └─ pihole-sync-snapshot.json.j2
   └─ handlers/
      └─ main.yml

TASK: Export config from PRIMARY (API)

roles/pihole_sync/tasks/export.yml

- name: Authenticate to Pi-hole API (primary)
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/auth"
    method: POST
    body_format: json
    body:
      password: "{{ pihole_api_password }}"
    validate_certs: false
    return_content: true
  register: pihole_auth
  delegate_to: localhost

- name: Get global config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config"
    method: GET
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"
  register: pihole_global
  delegate_to: localhost

- name: Get DNS config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config/dns"
    method: GET
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"
  register: pihole_dns
  delegate_to: localhost

- name: Get DHCP config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config/dhcp"
    method: GET
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"
  register: pihole_dhcp
  delegate_to: localhost

TEMPLATE: Config snapshot

roles/pihole_sync/templates/pihole-sync-snapshot.json.j2

{
  "global": {{ pihole_global.json.config | to_nice_json }},
  "dns": {{ pihole_dns.json.dns | to_nice_json }},
  "dhcp": {{ pihole_dhcp.json.dhcp | to_nice_json }}
}

TASK: Apply config to SECONDARY (API)

roles/pihole_sync/tasks/import.yml

- name: Authenticate to Pi-hole API (secondary)
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/auth"
    method: POST
    body_format: json
    body:
      password: "{{ pihole_api_password }}"
    validate_certs: false
    return_content: true
  register: pihole_auth

- name: Apply global config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config"
    method: PUT
    body_format: json
    body:
      config: "{{ pihole_snapshot.global }}"
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"

- name: Apply DNS config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config/dns"
    method: PUT
    body_format: json
    body:
      dns: "{{ pihole_snapshot.dns }}"
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"

- name: Apply DHCP config
  uri:
    url: "https://{{ inventory_hostname }}{{ pihole_api_base_path }}/config/dhcp"
    method: PUT
    body_format: json
    body:
      dhcp: "{{ pihole_snapshot.dhcp }}"
    validate_certs: false
    headers:
      Cookie: "{{ pihole_auth.set_cookie }}"

TASK: Sync local DNS records (files)

roles/pihole_sync/tasks/filesync.yml

- name: Ensure config directory exists on secondary
  file:
    path: "{{ pihole_config_dir }}"
    state: directory
    owner: root
    group: root
    mode: "0755"

- name: Sync local DNS records from primary
  synchronize:
    src: "{{ pihole_config_dir }}/"
    dest: "{{ pihole_config_dir }}/"
    delete: true
    archive: true
  delegate_to: "{{ groups['pihole_primary'][0] }}"
  notify: Reload Pi-hole DNS

HANDLER: Reload DNS

roles/pihole_sync/handlers/main.yml

- name: Reload Pi-hole DNS
  command: pihole restartdns reload

For Docker-based Pi-hole, replace with:

command: docker restart pihole

Playbook Example

- name: Export config from primary
  hosts: pihole_primary
  roles:
  - pihole_sync
  tasks:
  - import_tasks: roles/pihole_sync/tasks/export.yml
  - set_fact:
        pihole_snapshot:
          global: "{{ pihole_global.json.config }}"
          dns: "{{ pihole_dns.json.dns }}"
          dhcp: "{{ pihole_dhcp.json.dhcp }}"

- name: Sync secondary
  hosts: pihole_secondary
  roles:
  - pihole_sync
  tasks:
  - import_tasks: roles/pihole_sync/tasks/import.yml
  - import_tasks: roles/pihole_sync/tasks/filesync.yml

Validation Checklist

dig hostname.local @secondary_ip resolves

/api/config matches primary

pihole -q example.com behaves identically

Gravity update does not overwrite local records

Known Limitations

Local DNS records are not exposed via API

Regex rules require DB sync

Group assignments require gravity DB copy
