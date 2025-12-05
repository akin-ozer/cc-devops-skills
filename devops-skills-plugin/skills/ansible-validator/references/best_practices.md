# Ansible Best Practices

## Overview

This guide provides comprehensive best practices for writing clean, maintainable, and reliable Ansible playbooks, roles, and collections.

## Playbook Organization

### Directory Structure

```
ansible-project/
├── ansible.cfg              # Ansible configuration
├── inventory/               # Inventory files
│   ├── production/
│   │   ├── hosts           # Production inventory
│   │   └── group_vars/
│   │       └── all.yml
│   └── staging/
│       ├── hosts           # Staging inventory
│       └── group_vars/
│           └── all.yml
├── group_vars/             # Group-specific variables
│   ├── all.yml
│   ├── webservers.yml
│   └── databases.yml
├── host_vars/              # Host-specific variables
│   └── server1.yml
├── roles/                  # Reusable roles
│   ├── common/
│   ├── webserver/
│   └── database/
├── playbooks/              # Playbooks
│   ├── site.yml           # Master playbook
│   ├── webservers.yml
│   └── databases.yml
├── files/                  # Static files
├── templates/              # Jinja2 templates
├── vars/                   # Additional variables
│   └── external_vars.yml
└── requirements.yml        # Collection dependencies
```

### Role Structure

```
roles/webserver/
├── README.md              # Role documentation
├── defaults/
│   └── main.yml          # Default variables (lowest precedence)
├── vars/
│   └── main.yml          # Role variables (higher precedence)
├── tasks/
│   ├── main.yml          # Main task list
│   ├── install.yml       # Installation tasks
│   └── configure.yml     # Configuration tasks
├── handlers/
│   └── main.yml          # Handlers
├── templates/
│   └── nginx.conf.j2     # Template files
├── files/
│   └── index.html        # Static files
├── meta/
│   └── main.yml          # Role metadata and dependencies
└── molecule/             # Molecule test scenarios
    └── default/
        ├── molecule.yml
        ├── converge.yml
        └── verify.yml
```

## Task Naming and Documentation

### ✅ Good Task Names

```yaml
# Descriptive, action-oriented names
- name: Install nginx web server
  apt:
    name: nginx
    state: present

- name: Configure nginx virtual host for example.com
  template:
    src: vhost.conf.j2
    dest: /etc/nginx/sites-available/example.com

- name: Enable and start nginx service
  systemd:
    name: nginx
    state: started
    enabled: yes

- name: Create application user with limited privileges
  user:
    name: appuser
    system: yes
    shell: /bin/false
    home: /var/lib/app
```

### ❌ Bad Task Names

```yaml
# Vague, uninformative names
- name: Install package
  apt:
    name: nginx

- name: Configure
  template:
    src: vhost.conf.j2
    dest: /etc/nginx/sites-available/example.com

- name: Service
  systemd:
    name: nginx
    state: started

# No name at all
- apt:
    name: nginx
```

### Best Practices

1. **Always name your tasks** - makes output readable
2. **Use action verbs** - Install, Configure, Enable, Create, etc.
3. **Be specific** - mention what is being installed/configured
4. **Keep names concise** - but not at the expense of clarity
5. **Use consistent naming** - across all playbooks

## Variable Management

### Variable Naming Conventions

```yaml
# ✅ Good - Descriptive, namespaced
nginx_version: "1.18.0"
nginx_worker_processes: 4
nginx_worker_connections: 1024
app_database_host: "db.example.com"
app_database_port: 5432

# ❌ Bad - Generic, collision-prone
version: "1.18.0"  # Too generic
workers: 4         # Unclear
db: "db.example.com"  # Vague
```

### Variable Precedence

Understand variable precedence (from lowest to highest):

1. role defaults (defaults/main.yml)
2. inventory file or script group vars
3. inventory group_vars/all
4. playbook group_vars/all
5. inventory group_vars/*
6. playbook group_vars/*
7. inventory file or script host vars
8. inventory host_vars/*
9. playbook host_vars/*
10. host facts / cached set_facts
11. play vars
12. play vars_prompt
13. play vars_files
14. role vars (vars/main.yml)
15. block vars
16. task vars
17. include_vars
18. set_facts / registered vars
19. role (and include_role) params
20. include params
21. extra vars (always win precedence)

### Variable Organization

```yaml
# defaults/main.yml - Intended to be overridden
---
nginx_port: 80
nginx_user: www-data
nginx_worker_processes: "auto"

# vars/main.yml - Should not be overridden
---
nginx_config_dir: /etc/nginx
nginx_log_dir: /var/log/nginx
nginx_pid_file: /run/nginx.pid
```

### Using Defaults and Required Variables

```yaml
# Use default filter for optional variables
- name: Set API endpoint
  set_fact:
    api_endpoint: "{{ custom_api_endpoint | default('https://api.example.com') }}"

# Use required filter for mandatory variables
- name: Configure database
  template:
    src: db.conf.j2
    dest: /etc/app/database.conf
  vars:
    db_password: "{{ database_password | required('database_password must be defined') }}"
```

## Idempotency

### What is Idempotency?

Idempotency means running the same playbook multiple times produces the same result without making unnecessary changes.

### ✅ Idempotent Tasks

```yaml
# File module - inherently idempotent
- name: Ensure configuration directory exists
  file:
    path: /etc/myapp
    state: directory
    mode: '0755'

# Template module - only changes if content differs
- name: Configure application
  template:
    src: app.conf.j2
    dest: /etc/myapp/app.conf
    mode: '0644'

# Package module - idempotent
- name: Install required packages
  apt:
    name:
      - nginx
      - python3
      - git
    state: present

# Service module - idempotent
- name: Ensure service is running
  systemd:
    name: myapp
    state: started
    enabled: yes
```

### ⚠️ Non-Idempotent Tasks (Need Fixes)

```yaml
# Command/shell without creates/removes
- name: Download file
  command: curl -o /tmp/file.tar.gz https://example.com/file.tar.gz
  # This runs every time!

# Fix with creates
- name: Download file
  command: curl -o /tmp/file.tar.gz https://example.com/file.tar.gz
  args:
    creates: /tmp/file.tar.gz

# Or better - use get_url module
- name: Download file
  get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    checksum: sha256:abc123...

# Command that always reports changed
- name: Check service status
  command: systemctl status myapp
  register: service_status
  # Always shows as changed!

# Fix with changed_when
- name: Check service status
  command: systemctl status myapp
  register: service_status
  changed_when: false
  failed_when: service_status.rc not in [0, 3]
```

### Best Practices for Idempotency

1. **Use modules instead of command/shell** whenever possible
2. **Use creates/removes** parameters for command/shell when necessary
3. **Set changed_when appropriately** for read-only commands
4. **Test idempotency** - run playbook twice, second run should show no changes
5. **Use check mode** to verify idempotency without making changes

## Module Selection

### Prefer Modules Over Commands

```yaml
# ❌ Bad - Using shell/command
- name: Create directory
  shell: mkdir -p /opt/myapp

- name: Install package
  command: apt-get install -y nginx

- name: Add line to file
  shell: echo "export PATH=$PATH:/opt/bin" >> ~/.bashrc

# ✅ Good - Using appropriate modules
- name: Create directory
  file:
    path: /opt/myapp
    state: directory
    mode: '0755'

- name: Install package
  apt:
    name: nginx
    state: present

- name: Add line to file
  lineinfile:
    path: ~/.bashrc
    line: 'export PATH=$PATH:/opt/bin'
    create: yes
```

### Module Hierarchy

1. **First choice**: Specific module (apt, yum, systemd, copy, etc.)
2. **Second choice**: Generic module (package, service, etc.)
3. **Last resort**: command or shell module

## Error Handling

### Using Blocks

```yaml
- name: Handle errors gracefully
  block:
    - name: Attempt risky operation
      command: /usr/local/bin/risky-operation.sh
      register: result

    - name: Process successful result
      debug:
        msg: "Operation succeeded: {{ result.stdout }}"

  rescue:
    - name: Handle failure
      debug:
        msg: "Operation failed, applying fallback"

    - name: Apply fallback configuration
      copy:
        src: fallback.conf
        dest: /etc/app/config.conf

  always:
    - name: Cleanup temporary files
      file:
        path: /tmp/operation.lock
        state: absent
```

### Failed When and Changed When

```yaml
# Custom failure conditions
- name: Check disk space
  shell: df -h / | tail -1 | awk '{print $5}' | sed 's/%//'
  register: disk_usage
  failed_when: disk_usage.stdout | int > 90

# Custom changed conditions
- name: Verify configuration
  command: /usr/local/bin/check-config.sh
  register: config_check
  changed_when: false
  failed_when: config_check.rc != 0

# Multiple conditions
- name: Run healthcheck
  uri:
    url: http://localhost:8080/health
    method: GET
  register: health
  failed_when:
    - health.status != 200
    - "'healthy' not in health.json.status"
```

### Ignoring Errors (Use Sparingly)

```yaml
# Only when failure is acceptable
- name: Try to stop service (may not exist)
  systemd:
    name: old-service
    state: stopped
  ignore_errors: yes

# Better approach - check first
- name: Check if service exists
  systemd:
    name: old-service
  register: service_status
  failed_when: false

- name: Stop service if it exists
  systemd:
    name: old-service
    state: stopped
  when: service_status.status.ActiveState is defined
```

## Conditionals and Loops

### When Conditions

```yaml
# Simple condition
- name: Install Apache (Debian)
  apt:
    name: apache2
    state: present
  when: ansible_os_family == "Debian"

# Multiple conditions (AND)
- name: Install package on Ubuntu 20.04
  apt:
    name: package
    state: present
  when:
    - ansible_distribution == "Ubuntu"
    - ansible_distribution_version == "20.04"

# OR conditions
- name: Install on RHEL or CentOS
  yum:
    name: package
    state: present
  when: ansible_distribution == "RedHat" or ansible_distribution == "CentOS"

# Complex conditions
- name: Configure firewall
  ufw:
    rule: allow
    port: '443'
  when:
    - ansible_os_family == "Debian"
    - firewall_enabled | default(true) | bool
    - ansible_virtualization_type != "docker"
```

### Loops

```yaml
# Simple loop
- name: Install packages
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - python3
    - git

# Loop with hash
- name: Create users
  user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    state: present
  loop:
    - { name: 'alice', groups: 'developers' }
    - { name: 'bob', groups: 'operators' }

# Loop with dict
- name: Create directories
  file:
    path: "{{ item.path }}"
    state: directory
    mode: "{{ item.mode }}"
  loop:
    - { path: '/opt/app', mode: '0755' }
    - { path: '/var/log/app', mode: '0755' }
    - { path: '/etc/app', mode: '0750' }

# Loop with conditional
- name: Install debug tools (dev only)
  apt:
    name: "{{ item }}"
    state: present
  loop:
    - strace
    - tcpdump
    - gdb
  when: environment == "development"
```

## Templates and Jinja2

### Template Best Practices

```jinja2
{# templates/nginx.conf.j2 #}

{# Use comments to explain complex logic #}
user {{ nginx_user }};
worker_processes {{ nginx_worker_processes }};
pid {{ nginx_pid_file }};

{# Conditionals in templates #}
{% if nginx_enable_ssl %}
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers HIGH:!aNULL:!MD5;
{% endif %}

{# Loops in templates #}
{% for vhost in nginx_vhosts %}
server {
    listen {{ vhost.port }};
    server_name {{ vhost.server_name }};
    root {{ vhost.document_root }};

    {% if vhost.ssl_enabled | default(false) %}
    ssl_certificate {{ vhost.ssl_cert }};
    ssl_certificate_key {{ vhost.ssl_key }};
    {% endif %}
}
{% endfor %}

{# Filters #}
upstream_servers = {{ backend_servers | join(',') }}
max_connections = {{ max_connections | default(1024) }}
```

### Useful Jinja2 Filters

```yaml
# String manipulation
- debug:
    msg: "{{ 'hello' | upper }}"  # HELLO
    msg: "{{ 'HELLO' | lower }}"  # hello
    msg: "{{ '  hello  ' | trim }}"  # hello

# List operations
- debug:
    msg: "{{ [1,2,3] | first }}"  # 1
    msg: "{{ [1,2,3] | last }}"  # 3
    msg: "{{ [1,2,3] | length }}"  # 3
    msg: "{{ [1,2,3] | join(',') }}"  # 1,2,3

# Default values
- debug:
    msg: "{{ undefined_var | default('default_value') }}"

# Type conversion
- debug:
    msg: "{{ '123' | int }}"  # 123
    msg: "{{ 'true' | bool }}"  # True

# JSON and YAML
- debug:
    msg: "{{ my_dict | to_json }}"
    msg: "{{ my_dict | to_nice_json }}"
    msg: "{{ my_dict | to_yaml }}"
```

## Tags

### Using Tags Effectively

```yaml
---
- name: Configure web server
  hosts: webservers
  tasks:
    - name: Install nginx
      apt:
        name: nginx
      tags:
        - packages
        - nginx

    - name: Configure nginx
      template:
        src: nginx.conf.j2
        dest: /etc/nginx/nginx.conf
      tags:
        - configuration
        - nginx

    - name: Start nginx
      systemd:
        name: nginx
        state: started
      tags:
        - services
        - nginx

    - name: Configure firewall
      ufw:
        rule: allow
        port: '80'
      tags:
        - security
        - firewall
```

### Running with Tags

```bash
# Run only nginx tasks
ansible-playbook site.yml --tags nginx

# Run configuration tasks only
ansible-playbook site.yml --tags configuration

# Skip certain tags
ansible-playbook site.yml --skip-tags packages

# Multiple tags
ansible-playbook site.yml --tags "nginx,firewall"
```

## Handlers

### Handler Best Practices

```yaml
# tasks/main.yml
- name: Configure nginx
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify:
    - Validate nginx configuration
    - Restart nginx

- name: Add virtual host
  template:
    src: vhost.conf.j2
    dest: "/etc/nginx/sites-available/{{ vhost_name }}"
  notify:
    - Reload nginx

# handlers/main.yml
- name: Validate nginx configuration
  command: nginx -t
  changed_when: false

- name: Restart nginx
  systemd:
    name: nginx
    state: restarted

- name: Reload nginx
  systemd:
    name: nginx
    state: reloaded
```

### Handler Facts

1. **Handlers run once** at the end of a play, even if notified multiple times
2. **Handlers run in order** they're defined, not in order they're notified
3. **Use listen** for handler groups
4. **Flush handlers** with `meta: flush_handlers` to run immediately

## Check Mode and Diff Mode

### Supporting Check Mode

```yaml
# Task that supports check mode naturally (file module)
- name: Create directory
  file:
    path: /opt/myapp
    state: directory

# Task that doesn't support check mode, but can run anyway
- name: Check service status
  command: systemctl status myapp
  check_mode: no  # Always run, even in check mode
  changed_when: false

# Task that should be skipped in check mode
- name: Apply complex changes
  command: /usr/local/bin/complex-script.sh
  when: not ansible_check_mode
```

### Using Check Mode

```bash
# Run in check mode (dry-run)
ansible-playbook site.yml --check

# Check mode with diff (show changes)
ansible-playbook site.yml --check --diff

# See what would change
ansible-playbook site.yml --check --diff | grep -A 10 "changed:"
```

## Documentation

### Playbook Documentation

```yaml
---
# site.yml - Master playbook for deploying web application
#
# This playbook:
#   - Configures common settings on all hosts
#   - Deploys web servers
#   - Configures databases
#   - Sets up load balancers
#
# Usage:
#   ansible-playbook -i inventory/production site.yml
#
# Tags:
#   - common: Common configuration tasks
#   - webserver: Web server setup
#   - database: Database configuration
#
# Variables (see group_vars/all.yml):
#   - app_version: Application version to deploy
#   - environment: Environment name (production/staging)

- name: Configure common settings
  hosts: all
  roles:
    - common
  tags: common

- name: Deploy web servers
  hosts: webservers
  roles:
    - webserver
  tags: webserver
```

### Role Documentation (README.md)

```markdown
# Webserver Role

## Description

Installs and configures Nginx web server with virtual hosts and SSL support.

## Requirements

- Ansible >= 2.9
- Supported OS: Ubuntu 20.04, Debian 11

## Role Variables

### Required Variables

- `nginx_vhosts`: List of virtual hosts to configure (see example)

### Optional Variables

- `nginx_worker_processes`: Number of worker processes (default: auto)
- `nginx_worker_connections`: Max connections per worker (default: 1024)
- `nginx_enable_ssl`: Enable SSL support (default: false)

## Dependencies

None

## Example Playbook

```yaml
- hosts: webservers
  roles:
    - role: webserver
      vars:
        nginx_vhosts:
          - server_name: example.com
            port: 80
            document_root: /var/www/example
```

## License

MIT

## Author

Your Name
```

## Testing Best Practices

See the molecule configuration and testing section in the main skill.md for comprehensive testing guidance.

## Performance Tips

1. **Use pipelining** in ansible.cfg
   ```ini
   [ssh_connection]
   pipelining = True
   ```

2. **Enable fact caching**
   ```ini
   [defaults]
   gathering = smart
   fact_caching = jsonfile
   fact_caching_connection = /tmp/ansible_facts
   fact_caching_timeout = 86400
   ```

3. **Limit fact gathering**
   ```yaml
   - hosts: all
     gather_facts: no  # Don't gather if not needed
   ```

4. **Use async for long-running tasks**
   ```yaml
   - name: Long running task
     command: /usr/local/bin/long-task.sh
     async: 3600
     poll: 0
     register: long_task

   - name: Check on long task
     async_status:
       jid: "{{ long_task.ansible_job_id }}"
     register: job_result
     until: job_result.finished
     retries: 30
   ```

## Summary Checklist

- [ ] Playbooks and roles have clear directory structure
- [ ] All tasks have descriptive names
- [ ] Variables use namespacing (role_variable_name)
- [ ] Sensitive data encrypted with Ansible Vault
- [ ] Playbooks are idempotent (can run multiple times safely)
- [ ] Using modules instead of shell/command where possible
- [ ] Error handling with blocks, failed_when, changed_when
- [ ] Conditionals used appropriately
- [ ] Templates properly commented
- [ ] Tags used for granular execution
- [ ] Handlers used for service restarts
- [ ] Check mode supported
- [ ] Documentation complete (README, comments)
- [ ] Tested with molecule or similar framework
- [ ] No hardcoded secrets
- [ ] File permissions explicitly set
