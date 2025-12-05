# Ansible Best Practices

## Directory Structure

### Standard Playbook Structure
```
playbook.yml
roles/
  common/
    tasks/
      main.yml
    handlers/
      main.yml
    templates/
    files/
    vars/
      main.yml
    defaults/
      main.yml
    meta/
      main.yml
inventory/
  production/
    hosts
    group_vars/
    host_vars/
  staging/
    hosts
    group_vars/
    host_vars/
```

### Role Structure
Each role should have:
- `tasks/main.yml` - Main task list
- `handlers/main.yml` - Handlers triggered by tasks
- `templates/` - Jinja2 templates
- `files/` - Static files to copy
- `vars/main.yml` - Role-specific variables (high priority)
- `defaults/main.yml` - Default variables (low priority, overridable)
- `meta/main.yml` - Role dependencies and metadata

## Naming Conventions

### Files and Directories
- Use lowercase with underscores: `install_nginx.yml`, `backup_database.yml`
- Playbook files: descriptive names ending in `.yml`
- Role names: short, descriptive, lowercase with underscores

### Variables
- Use descriptive names: `nginx_port`, `db_backup_dir`, `app_version`
- Prefix role-specific variables with role name: `nginx_worker_processes`
- Use snake_case, not camelCase or kebab-case
- Group related variables with common prefixes

### Tasks
- Use descriptive names that explain what the task does
- Start with a verb: "Install nginx", "Copy configuration file", "Start service"

## Task Writing Best Practices

### Always Use State Declaration
```yaml
# Good
- name: Ensure nginx is installed
  ansible.builtin.package:
    name: nginx
    state: present

# Bad
- name: Install nginx
  ansible.builtin.package:
    name: nginx
```

### Use Fully Qualified Collection Names (FQCN)
```yaml
# Good - FQCN (Ansible 2.10+)
- name: Copy configuration file
  ansible.builtin.copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf

# Avoid - Short names (deprecated)
- name: Copy configuration file
  copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
```

### Idempotency
- All tasks should be idempotent (safe to run multiple times)
- Use `state: present/absent` instead of imperative commands
- Avoid using `command` or `shell` modules when builtin modules exist
- When using `command`/`shell`, use `creates`, `removes`, or `changed_when`

```yaml
# Good - idempotent
- name: Create directory
  ansible.builtin.file:
    path: /opt/app
    state: directory
    mode: '0755'

# Bad - not idempotent
- name: Create directory
  ansible.builtin.command: mkdir -p /opt/app
```

### Error Handling
```yaml
- name: Attempt to start service
  ansible.builtin.service:
    name: myapp
    state: started
  register: service_result
  failed_when: false
  changed_when: service_result.rc == 0

- name: Handle service failure
  ansible.builtin.debug:
    msg: "Service failed to start: {{ service_result.msg }}"
  when: service_result.failed
```

## Variables and Facts

### Variable Precedence (High to Low)
1. Extra vars (`-e` in CLI)
2. Task vars
3. Block vars
4. Role and include vars
5. Set_facts / registered vars
6. Play vars
7. Play vars_files
8. Role defaults
9. Inventory vars (host_vars, group_vars)

### Using Variables
```yaml
# Use default values
- name: Set port with default
  ansible.builtin.set_fact:
    app_port: "{{ custom_port | default(8080) }}"

# Combine variables
- name: Create full path
  ansible.builtin.set_fact:
    config_path: "{{ base_dir }}/{{ app_name }}/config.yml"
```

## Conditionals and Loops

### When Statements
```yaml
- name: Install on Debian-based systems
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

- name: Install on RedHat-based systems
  ansible.builtin.yum:
    name: nginx
    state: present
  when: ansible_os_family == "RedHat"
```

### Loops
```yaml
# Good - using loop
- name: Install packages
  ansible.builtin.package:
    name: "{{ item }}"
    state: present
  loop:
    - nginx
    - postgresql
    - redis

# Complex loop with dict
- name: Create users
  ansible.builtin.user:
    name: "{{ item.name }}"
    groups: "{{ item.groups }}"
    state: present
  loop:
    - { name: 'alice', groups: 'admin,developers' }
    - { name: 'bob', groups: 'developers' }
```

## Handlers

### Naming and Usage
```yaml
# In tasks/main.yml
- name: Copy nginx configuration
  ansible.builtin.copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
  notify: Restart nginx

# In handlers/main.yml
- name: Restart nginx
  ansible.builtin.service:
    name: nginx
    state: restarted
```

### Handler Best Practices
- Handlers run once at the end of a play
- Use descriptive names
- Listen to multiple notifications with same handler name
- Use `meta: flush_handlers` to run handlers immediately if needed

## Templates

### Jinja2 Templates
```yaml
# Task
- name: Deploy configuration from template
  ansible.builtin.template:
    src: app_config.j2
    dest: /etc/app/config.yml
    mode: '0644'
    backup: yes
```

```jinja2
# Template file: templates/app_config.j2
server:
  port: {{ app_port }}
  host: {{ ansible_default_ipv4.address }}

database:
  host: {{ db_host }}
  port: {{ db_port | default(5432) }}
  name: {{ db_name }}

{% if enable_ssl %}
ssl:
  enabled: true
  cert: {{ ssl_cert_path }}
  key: {{ ssl_key_path }}
{% endif %}
```

## Advanced Jinja2 Templating

### Common Filters

#### Data Format Conversion
```yaml
- name: Convert to JSON
  ansible.builtin.copy:
    content: "{{ my_dict | to_json }}"
    dest: /tmp/config.json

- name: Convert to YAML
  ansible.builtin.copy:
    content: "{{ my_dict | to_yaml }}"
    dest: /tmp/config.yml

- name: Convert to pretty JSON
  ansible.builtin.copy:
    content: "{{ my_dict | to_nice_json }}"
    dest: /tmp/config.json

# Parse JSON/YAML strings
- name: Parse JSON string
  ansible.builtin.set_fact:
    parsed_data: "{{ json_string | from_json }}"

- name: Parse YAML string
  ansible.builtin.set_fact:
    parsed_data: "{{ yaml_string | from_yaml }}"
```

#### String Manipulation
```yaml
# Regex operations
- name: Replace text
  ansible.builtin.set_fact:
    new_string: "{{ original | regex_replace('^old', 'new') }}"

- name: Extract with regex
  ansible.builtin.set_fact:
    extracted: "{{ text | regex_search('version: (\\d+\\.\\d+)', '\\1') }}"

# Case conversion
- name: Convert case
  ansible.builtin.set_fact:
    upper: "{{ text | upper }}"
    lower: "{{ text | lower }}"
    title: "{{ text | title }}"

# String operations
- name: String operations
  ansible.builtin.set_fact:
    trimmed: "{{ '  text  ' | trim }}"
    replaced: "{{ text | replace('old', 'new') }}"
    split_list: "{{ 'a,b,c' | split(',') }}"
    joined: "{{ ['a', 'b', 'c'] | join('-') }}"
```

#### Hashing and Encoding
```yaml
# Hash values
- name: Generate hashes
  ansible.builtin.set_fact:
    md5_hash: "{{ 'mystring' | hash('md5') }}"
    sha256_hash: "{{ 'mystring' | hash('sha256') }}"

# Password hashing
- name: Hash password
  ansible.builtin.user:
    name: myuser
    password: "{{ user_password | password_hash('sha512', 'mysecretsalt') }}"

# Encoding
- name: Encode/decode
  ansible.builtin.set_fact:
    base64_encoded: "{{ 'text' | b64encode }}"
    base64_decoded: "{{ encoded_value | b64decode }}"
    url_encoded: "{{ url_string | urlencode }}"
```

#### List and Dict Operations
```yaml
# List operations
- name: List operations
  ansible.builtin.set_fact:
    unique_items: "{{ my_list | unique }}"
    sorted_items: "{{ my_list | sort }}"
    first_item: "{{ my_list | first }}"
    last_item: "{{ my_list | last }}"
    list_length: "{{ my_list | length }}"
    flattened: "{{ nested_list | flatten }}"

# Dict operations
- name: Dict operations
  ansible.builtin.set_fact:
    dict_keys: "{{ my_dict | dict2items }}"
    dict_values: "{{ my_dict | list }}"
    combined: "{{ dict1 | combine(dict2) }}"

# Extract values
- name: Extract from list of dicts
  ansible.builtin.set_fact:
    names: "{{ users | map(attribute='name') | list }}"
    ids: "{{ items | map(attribute='id') | list }}"
```

#### Network Filters
```yaml
# IP address operations (requires netaddr Python package)
- name: IP operations
  ansible.builtin.set_fact:
    is_valid: "{{ ip_address | ipaddr }}"
    network: "{{ ip_address | ipaddr('network') }}"
    netmask: "{{ ip_address | ipaddr('netmask') }}"
    broadcast: "{{ ip_address | ipaddr('broadcast') }}"
    host_ip: "{{ ip_address | ipaddr('address') }}"

# CIDR operations
- name: CIDR operations
  ansible.builtin.set_fact:
    hosts_in_network: "{{ '192.168.1.0/24' | ipaddr('size') }}"
    first_host: "{{ '192.168.1.0/24' | ipaddr('1') | ipaddr('address') }}"
```

#### File and Math Filters
```yaml
# File size formatting
- name: Format file size
  ansible.builtin.debug:
    msg: "File size: {{ file_stat.stat.size | filesizeformat }}"

# Math operations
- name: Math operations
  ansible.builtin.set_fact:
    sum: "{{ [1, 2, 3] | sum }}"
    min: "{{ [5, 2, 8] | min }}"
    max: "{{ [5, 2, 8] | max }}"
    rounded: "{{ 3.14159 | round(2) }}"
    absolute: "{{ -42 | abs }}"
```

#### Default and Mandatory Values
```yaml
# Provide defaults
- name: Use default values
  ansible.builtin.set_fact:
    port: "{{ custom_port | default(8080) }}"
    config: "{{ app_config | default({}) }}"

# Nested defaults (Ansible 2.8+)
- name: Nested default
  ansible.builtin.set_fact:
    value: "{{ foo.bar.baz | default('fallback') }}"

# Mandatory values
- name: Require variable
  ansible.builtin.set_fact:
    required_value: "{{ must_be_defined | mandatory }}"
```

### Lookup Plugins

#### File and Environment Lookups
```yaml
# Read file content
- name: Read SSH public key
  ansible.builtin.authorized_key:
    user: deploy
    key: "{{ lookup('file', '/home/user/.ssh/id_rsa.pub') }}"

# Environment variables
- name: Get environment variable
  ansible.builtin.set_fact:
    home_dir: "{{ lookup('env', 'HOME') }}"
    path: "{{ lookup('env', 'PATH') }}"

# Pipe command output
- name: Get command output
  ansible.builtin.set_fact:
    current_date: "{{ lookup('pipe', 'date +%Y-%m-%d') }}"
    git_commit: "{{ lookup('pipe', 'git rev-parse HEAD') }}"
```

#### Template and URL Lookups
```yaml
# Template lookup
- name: Inline template
  ansible.builtin.set_fact:
    greeting: "{{ lookup('template', 'greeting.j2') }}"

# URL content
- name: Fetch URL content
  ansible.builtin.set_fact:
    remote_content: "{{ lookup('url', 'https://api.example.com/config') }}"
```

#### Password and Random Lookups
```yaml
# Generate random password
- name: Generate password
  ansible.builtin.set_fact:
    random_password: "{{ lookup('password', '/dev/null length=32 chars=ascii_letters,digits') }}"

# Random choice
- name: Pick random item
  ansible.builtin.set_fact:
    random_server: "{{ lookup('random_choice', ['server1', 'server2', 'server3']) }}"
```

#### Query vs Lookup
```yaml
# lookup returns comma-separated string
- name: Using lookup
  ansible.builtin.debug:
    msg: "{{ lookup('file', 'file1.txt', 'file2.txt') }}"
  # Returns: "content1,content2"

# query always returns list
- name: Using query
  ansible.builtin.debug:
    msg: "{{ query('file', 'file1.txt', 'file2.txt') }}"
  # Returns: ["content1", "content2"]

# Prefer query for loops
- name: Loop with query
  ansible.builtin.debug:
    msg: "{{ item }}"
  loop: "{{ query('inventory_hostnames', 'all') }}"
```

### Template Control Structures

#### Loops in Templates
```jinja2
{# templates/config.j2 #}
# User list
{% for user in users %}
user {{ user.name }}:
  uid: {{ user.uid }}
  groups: {{ user.groups | join(',') }}
{% endfor %}

# Conditional in loop
{% for item in items if item.enabled %}
  - {{ item.name }}: {{ item.value }}
{% endfor %}

# Loop with index
{% for server in servers %}
server_{{ loop.index }}: {{ server.hostname }}
{% endfor %}
```

#### Conditionals in Templates
```jinja2
{# templates/app_config.j2 #}
{% if environment == 'production' %}
log_level: warning
max_connections: 1000
{% elif environment == 'staging' %}
log_level: info
max_connections: 500
{% else %}
log_level: debug
max_connections: 100
{% endif %}

# Complex conditions
{% if ansible_os_family == 'Debian' and ansible_distribution_major_version|int >= 20 %}
use_modern_config: true
{% endif %}

# Check if defined
{% if custom_setting is defined %}
custom_setting: {{ custom_setting }}
{% endif %}

# Check if none
{% if database_host is none %}
database_host: localhost
{% else %}
database_host: {{ database_host }}
{% endif %}
```

#### Whitespace Control
```jinja2
{# Remove whitespace before #}
{%- if condition %}
content
{% endif %}

{# Remove whitespace after #}
{% if condition -%}
content
{% endif %}

{# Remove both #}
{%- if condition -%}
content
{%- endif -%}
```

#### Macros and Includes
```jinja2
{# Define macro #}
{% macro render_user(name, uid) -%}
user: {{ name }}
uid: {{ uid }}
{%- endmacro %}

{# Use macro #}
{{ render_user('alice', 1000) }}
{{ render_user('bob', 1001) }}

{# Include other template #}
{% include 'header.j2' %}

{# Import macros from other template #}
{% from 'macros.j2' import render_user %}
```

### Advanced Template Patterns

#### Multi-line Strings
```jinja2
server {
    listen 80;
    server_name {{ server_name }};

    {% if ssl_enabled %}
    listen 443 ssl;
    ssl_certificate {{ ssl_cert_path }};
    ssl_certificate_key {{ ssl_key_path }};
    {% endif %}

    location / {
        proxy_pass http://{{ backend_host }}:{{ backend_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

#### Complex Data Structures
```jinja2
{# Nested loops for complex config #}
{% for service in services %}
[{{ service.name }}]
{% for key, value in service.config.items() %}
{{ key }} = {{ value }}
{% endfor %}

{% endfor %}

{# Generate from dict #}
{% for key, value in app_settings.items() %}
export {{ key | upper }}="{{ value }}"
{% endfor %}
```

## Security Best Practices

### Sensitive Data
```yaml
# Use no_log for sensitive operations
- name: Set database password
  ansible.builtin.user:
    name: dbadmin
    password: "{{ db_password | password_hash('sha512') }}"
  no_log: true

# Use ansible-vault for secrets
# Encrypt with: ansible-vault encrypt secrets.yml
# Include encrypted vars
- name: Include vault variables
  ansible.builtin.include_vars:
    file: secrets.yml
```

### File Permissions
```yaml
- name: Copy sensitive file
  ansible.builtin.copy:
    src: private_key
    dest: /etc/ssl/private/app.key
    mode: '0600'
    owner: root
    group: root
```

## Tags

### Using Tags
```yaml
- name: Install packages
  ansible.builtin.package:
    name: nginx
    state: present
  tags:
    - packages
    - nginx
    - install

# Run with: ansible-playbook playbook.yml --tags "install"
# Skip with: ansible-playbook playbook.yml --skip-tags "install"
```

### Tag Categories
- `install` - Installation tasks
- `configure` - Configuration tasks
- `update` - Update tasks
- `backup` - Backup tasks
- `always` - Always run (special tag)
- `never` - Never run unless explicitly called (special tag)

## Playbook Structure

### Complete Playbook Example
```yaml
---
- name: Deploy web application
  hosts: webservers
  become: yes
  vars:
    app_version: "1.2.3"
    app_port: 8080

  pre_tasks:
    - name: Update package cache
      ansible.builtin.apt:
        update_cache: yes
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

  roles:
    - common
    - nginx
    - application

  post_tasks:
    - name: Verify application is running
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 5
      delay: 10

  handlers:
    - name: Restart application
      ansible.builtin.service:
        name: myapp
        state: restarted
```

## Testing and Validation

### Check Mode (Dry Run)
```yaml
# Run in check mode
ansible-playbook playbook.yml --check

# Task that always runs in check mode
- name: Get service status
  ansible.builtin.command: systemctl status nginx
  check_mode: no
  changed_when: false
```

### Diff Mode
```yaml
# Show differences
ansible-playbook playbook.yml --check --diff
```

### Assert and Validate
```yaml
- name: Verify configuration
  ansible.builtin.assert:
    that:
      - ansible_distribution in ['Ubuntu', 'Debian', 'CentOS', 'RedHat']
      - app_port | int > 0
      - app_port | int < 65536
    fail_msg: "Invalid configuration"
    success_msg: "Configuration validated"
```

## Performance Optimization

### Gathering Facts
```yaml
# Disable fact gathering when not needed
- name: Quick task
  hosts: all
  gather_facts: no
  tasks:
    - name: Ping hosts
      ansible.builtin.ping:

# Gather specific facts
- name: Gather minimal facts
  hosts: all
  gather_facts: yes
  gather_subset:
    - '!all'
    - '!min'
    - network
```

### Parallelism
```yaml
# Set forks in ansible.cfg or via CLI
# ansible-playbook playbook.yml --forks 20

# Control serial execution
- name: Rolling update
  hosts: webservers
  serial: 2  # Update 2 hosts at a time
```

### Async Tasks
```yaml
- name: Long running task
  ansible.builtin.command: /opt/long_running_script.sh
  async: 3600  # Maximum runtime
  poll: 0  # Fire and forget
  register: long_task

- name: Check on long task
  ansible.builtin.async_status:
    jid: "{{ long_task.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 30
  delay: 10
```

## Documentation

### Playbook Documentation
```yaml
---
# playbook.yml
# Description: Deploy and configure web application
# Requirements:
#   - Ansible 2.10+
#   - Target hosts: Ubuntu 20.04+ or RHEL 8+
# Variables:
#   - app_version: Application version to deploy (required)
#   - app_port: Port for application (default: 8080)
#   - enable_ssl: Enable SSL/TLS (default: false)
# Usage:
#   ansible-playbook -i inventory/production playbook.yml -e "app_version=1.2.3"
```

### Role Documentation (meta/main.yml)
```yaml
---
galaxy_info:
  role_name: nginx
  author: Your Name
  description: Install and configure nginx
  license: MIT
  min_ansible_version: 2.10
  platforms:
    - name: Ubuntu
      versions:
        - focal
        - jammy
    - name: EL
      versions:
        - 8
        - 9
  galaxy_tags:
    - web
    - nginx

dependencies: []
```

## Common Pitfalls to Avoid

1. **Not using FQCN** - Always use fully qualified collection names
2. **Hard-coded values** - Use variables for configuration
3. **Not handling different OS** - Check `ansible_os_family` or `ansible_distribution`
4. **Ignoring idempotency** - Tasks should be safe to run multiple times
5. **Not using handlers** - Restart services via handlers, not direct tasks
6. **Sensitive data in plain text** - Use ansible-vault for secrets
7. **Not using tags** - Tags enable selective execution
8. **Not validating** - Always run with `--check` first
9. **Complex logic in playbooks** - Move complex logic to roles
10. **Not documenting variables** - Document required and optional vars

## Module Selection Priority

1. **Builtin modules first**: Use `ansible.builtin.*` modules when available
2. **Collection modules**: Use official collection modules (e.g., `community.general.*`)
3. **Custom modules**: Only when no suitable module exists
4. **Avoid `command`/`shell`**: Use specific modules instead of raw commands
