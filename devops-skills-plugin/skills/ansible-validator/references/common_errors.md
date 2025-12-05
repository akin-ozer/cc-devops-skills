# Common Ansible Errors and Solutions

## Overview

This document provides solutions to common Ansible errors, including syntax errors, module errors, connection issues, and runtime problems.

## Syntax Errors

### Error: mapping values are not allowed here

```
ERROR! Syntax Error while loading YAML.
  mapping values are not allowed here
```

**Cause:** YAML indentation error or missing quote

**Example Problem:**
```yaml
- name: Configure app
  template:
    src: config.j2
    dest: /etc/app/config.yml
    vars:
      db_host: localhost:5432  # WRONG: colon not quoted
```

**Solution:**
```yaml
- name: Configure app
  template:
    src: config.j2
    dest: /etc/app/config.yml
    vars:
      db_host: "localhost:5432"  # Quoted
```

### Error: found undefined alias

```
ERROR! Syntax Error while loading YAML.
  found undefined alias 'anchor'
```

**Cause:** Using YAML anchor/alias incorrectly

**Solution:** Ensure anchors are defined before use
```yaml
# Define anchor
common_packages: &common_packages
  - git
  - curl
  - vim

# Use alias
- name: Install common packages
  apt:
    name: *common_packages
```

### Error: could not find expected ':'

```
ERROR! could not find expected ':'
```

**Cause:** Missing colon or improper YAML structure

**Example Problem:**
```yaml
- name Install package  # Missing colon after name
  apt:
    name nginx  # Missing colon after name
```

**Solution:**
```yaml
- name: Install package
  apt:
    name: nginx
```

## Module Errors

### Error: Unsupported parameters for module

```
ERROR! Unsupported parameters for (module) module: parameter_name
```

**Cause:** Using wrong parameter name or typo

**Example Problem:**
```yaml
- name: Create file
  file:
    path: /tmp/test
    state: present
    mod: '0644'  # WRONG: should be 'mode'
```

**Solution:**
```yaml
- name: Create file
  file:
    path: /tmp/test
    state: present
    mode: '0644'  # Correct parameter name
```

**How to check:** Use `ansible-doc module_name` to see correct parameters

### Error: MODULE FAILURE

```
fatal: [host]: FAILED! => {"changed": false, "module_stderr": "..."}
```

**Common Causes:**
1. Python not installed on target
2. Wrong Python interpreter
3. SELinux blocking module execution

**Solutions:**
```yaml
# Specify Python interpreter in inventory
[webservers]
server1 ansible_python_interpreter=/usr/bin/python3

# Or in playbook
- hosts: all
  vars:
    ansible_python_interpreter: /usr/bin/python3
```

### Error: Missing required arguments

```
fatal: [host]: FAILED! => {"changed": false, "msg": "missing required arguments: name"}
```

**Cause:** Required module parameter not provided

**Solution:** Add the required parameter
```yaml
# Wrong
- name: Install package
  apt:
    state: present

# Correct
- name: Install package
  apt:
    name: nginx
    state: present
```

## Template Errors

### Error: template error while templating string

```
fatal: [host]: FAILED! => {"msg": "An unhandled exception occurred while templating..."}
```

**Common Causes:**
1. Undefined variable
2. Wrong filter syntax
3. Jinja2 syntax error

**Example Problem:**
```yaml
- name: Configure app
  template:
    src: config.j2
    dest: /etc/app/config.yml
  vars:
    port: "{{ app_port }}"  # app_port undefined
```

**Solutions:**
```yaml
# Use default filter
vars:
  port: "{{ app_port | default(8080) }}"

# Or use required filter
vars:
  port: "{{ app_port | required('app_port must be defined') }}"

# Or check if defined
- name: Configure app
  template:
    src: config.j2
    dest: /etc/app/config.yml
  when: app_port is defined
```

### Error: Unexpected templating type error

```
fatal: [host]: FAILED! => {"msg": "Unexpected templating type error occurred on (...)"}
```

**Cause:** Wrong variable type (e.g., trying to use int as string)

**Solution:** Use type conversion filters
```yaml
# Convert to string
port: "{{ app_port | string }}"

# Convert to int
replicas: "{{ replica_count | int }}"

# Convert to bool
enabled: "{{ feature_enabled | bool }}"
```

## Connection Errors

### Error: Failed to connect to the host via ssh

```
fatal: [host]: UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}
```

**Common Causes:**
1. Host not accessible
2. Wrong SSH key
3. Wrong username
4. SSH not running on host

**Solutions:**
```bash
# Test SSH connectivity
ssh user@host

# Check Ansible can ping
ansible host -m ping

# Use correct SSH key
ansible-playbook -i inventory playbook.yml --private-key=~/.ssh/id_rsa

# Specify user in inventory
[webservers]
server1 ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/id_rsa
```

### Error: Permission denied (publickey)

```
fatal: [host]: UNREACHABLE! => {"msg": "Failed to connect to the host via ssh: Permission denied (publickey)."}
```

**Solutions:**
```bash
# Ensure SSH key is added to target
ssh-copy-id user@host

# Or specify key in inventory
[webservers]
server1 ansible_ssh_private_key_file=~/.ssh/custom_key

# Check SSH agent
ssh-add -l
ssh-add ~/.ssh/id_rsa
```

### Error: Authentication or permission failure

```
fatal: [host]: UNREACHABLE! => {"msg": "Authentication or permission failure."}
```

**Solutions:**
```yaml
# Use password authentication (less secure)
- hosts: all
  vars:
    ansible_ssh_pass: password  # Better to use vault
    ansible_become_pass: password

# Or use ask-pass
ansible-playbook -i inventory playbook.yml --ask-pass --ask-become-pass
```

## Privilege Escalation Errors

### Error: Missing sudo password

```
fatal: [host]: FAILED! => {"msg": "Missing sudo password"}
```

**Solutions:**
```bash
# Provide sudo password at runtime
ansible-playbook -i inventory playbook.yml --ask-become-pass

# Or configure passwordless sudo on target
# /etc/sudoers.d/ansible
ansible_user ALL=(ALL) NOPASSWD: ALL
```

### Error: you must be root

```
fatal: [host]: FAILED! => {"msg": "Could not create file: Permission denied"}
```

**Solution:** Add `become: yes` to task or play
```yaml
- name: Install package
  apt:
    name: nginx
    state: present
  become: yes

# Or for entire play
- hosts: all
  become: yes
  tasks:
    - name: Install package
      apt:
        name: nginx
```

## Variable Errors

### Error: The task includes an option with an undefined variable

```
fatal: [host]: FAILED! => {"msg": "The task includes an option with an undefined variable. The error was: 'variable' is undefined"}
```

**Solutions:**
```yaml
# Use default filter
- name: Use variable with default
  debug:
    msg: "{{ my_var | default('default_value') }}"

# Check if defined before use
- name: Use variable conditionally
  debug:
    msg: "{{ my_var }}"
  when: my_var is defined

# Use required filter to make it explicit
- name: Require variable
  debug:
    msg: "{{ my_var | required('my_var must be defined') }}"
```

### Error: Conflicting variable name

```
[WARNING]: Invalid characters were found in group names but not replaced, use -vvvv to see details
```

**Cause:** Variable or group name contains invalid characters (hyphens, spaces)

**Solution:** Use underscores instead
```ini
# Wrong
[web-servers]

# Correct
[web_servers]
```

## Inventory Errors

### Error: Could not match supplied host pattern

```
[WARNING]: Could not match supplied host pattern, ignoring: webservers
```

**Cause:** Host group not defined in inventory

**Solution:** Check inventory file
```ini
# inventory/hosts
[webservers]
web1.example.com
web2.example.com

[databases]
db1.example.com
```

### Error: Unable to parse inventory

```
[WARNING]: Unable to parse /path/to/inventory as an inventory source
```

**Cause:** Invalid inventory format

**Solution:** Fix inventory syntax
```ini
# Wrong - mixing styles
[webservers]
web1 ansible_host=192.168.1.10
web2
  ansible_host: 192.168.1.11  # YAML syntax in INI file

# Correct - consistent INI format
[webservers]
web1 ansible_host=192.168.1.10
web2 ansible_host=192.168.1.11
```

## Loop Errors

### Error: Invalid data passed to 'loop'

```
fatal: [host]: FAILED! => {"msg": "Invalid data passed to 'loop', it requires a list"}
```

**Cause:** Loop variable is not a list

**Solution:** Ensure loop variable is a list
```yaml
# Wrong
- name: Install packages
  apt:
    name: "{{ item }}"
  loop: nginx  # String, not list

# Correct
- name: Install packages
  apt:
    name: "{{ item }}"
  loop:
    - nginx
    - python3
```

### Error: with_items is deprecated

```
[DEPRECATION WARNING]: with_items is deprecated, use loop instead
```

**Solution:** Replace `with_items` with `loop`
```yaml
# Old style (deprecated)
- name: Install packages
  apt:
    name: "{{ item }}"
  with_items:
    - nginx
    - python3

# New style
- name: Install packages
  apt:
    name: "{{ item }}"
  loop:
    - nginx
    - python3
```

## Handler Errors

### Error: Handler not found

```
ERROR! The requested handler 'restart nginx' was not found
```

**Cause:** Handler name mismatch or handler not defined

**Solution:** Ensure handler name matches exactly
```yaml
# tasks/main.yml
- name: Configure nginx
  template:
    src: nginx.conf.j2
    dest: /etc/nginx/nginx.conf
  notify: restart nginx  # Must match handler name exactly

# handlers/main.yml
- name: restart nginx  # Must match notification exactly
  systemd:
    name: nginx
    state: restarted
```

## Include/Import Errors

### Error: Unable to retrieve file contents

```
fatal: [host]: FAILED! => {"msg": "Unable to retrieve file contents. Could not find or access 'file.yml'"}
```

**Cause:** File path incorrect or file doesn't exist

**Solution:** Check file path (relative to playbook location)
```yaml
# Wrong
- include_tasks: tasks/install.yml  # If tasks/ doesn't exist

# Correct
- include_tasks: install.yml  # File in same directory
# Or
- include_tasks: roles/common/tasks/install.yml  # Full path
```

### Error: Include/Import loop detected

```
ERROR! Recursively included/imported file is causing infinite loop
```

**Cause:** Circular dependency (file A includes file B, file B includes file A)

**Solution:** Restructure includes to avoid circular dependencies

## Collection Errors

### Error: couldn't resolve module/action

```
ERROR! couldn't resolve module/action 'community.general.docker_container'
```

**Cause:** Collection not installed

**Solution:** Install required collection
```bash
# Install single collection
ansible-galaxy collection install community.general

# Install from requirements.yml
# requirements.yml
collections:
  - name: community.general
    version: ">=5.0.0"

ansible-galaxy collection install -r requirements.yml
```

### Error: Collection version conflict

```
ERROR! Requirement already satisfied by a different version
```

**Solution:** Update or downgrade collection
```bash
# Force reinstall
ansible-galaxy collection install community.general --force

# Install specific version
ansible-galaxy collection install community.general:5.0.0
```

## Dry-Run / Check Mode Errors

### Error: This module does not support check mode

```
fatal: [host]: FAILED! => {"msg": "This module does not support check mode"}
```

**Cause:** Module doesn't support check mode

**Solution:** Skip check mode for this task
```yaml
- name: Command that doesn't support check mode
  command: /usr/local/bin/custom-script.sh
  check_mode: no  # Always run, even in check mode
```

## Debugging Tips

### Enable Verbose Output

```bash
# Basic verbosity
ansible-playbook playbook.yml -v

# More details
ansible-playbook playbook.yml -vv

# Very verbose (shows module arguments)
ansible-playbook playbook.yml -vvv

# Connection debugging
ansible-playbook playbook.yml -vvvv
```

### Use Debug Module

```yaml
# Print variable
- name: Debug variable
  debug:
    var: my_variable

# Print message
- name: Debug message
  debug:
    msg: "Value is {{ my_variable }}"

# Print all facts
- name: Print all facts
  debug:
    var: ansible_facts

# Conditional debug
- name: Debug when condition met
  debug:
    msg: "Debug message"
  when: ansible_distribution == "Ubuntu"
```

### Use assert Module

```yaml
# Validate conditions
- name: Assert variables are defined
  assert:
    that:
      - app_version is defined
      - app_version | length > 0
      - app_port | int > 0
      - app_port | int < 65536
    fail_msg: "Invalid configuration"
    success_msg: "Configuration validated"
```

## Performance Issues

### Slow Playbook Execution

**Solutions:**
1. Enable SSH pipelining
```ini
# ansible.cfg
[ssh_connection]
pipelining = True
```

2. Use fact caching
```ini
# ansible.cfg
[defaults]
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 86400
```

3. Disable fact gathering if not needed
```yaml
- hosts: all
  gather_facts: no
```

4. Use async for long tasks
```yaml
- name: Long running task
  command: /usr/bin/long-task
  async: 3600
  poll: 0
```

### High Memory Usage

**Solutions:**
1. Process hosts in batches
```yaml
- hosts: all
  serial: 10  # Process 10 hosts at a time
```

2. Use free strategy
```yaml
- hosts: all
  strategy: free  # Don't wait for all hosts to complete task
```

## Error Prevention Checklist

- [ ] Run yamllint before ansible-playbook
- [ ] Run ansible-lint on all playbooks
- [ ] Use --syntax-check before execution
- [ ] Test with --check mode first
- [ ] Start with limited host scope (--limit)
- [ ] Use tags for incremental testing
- [ ] Enable verbose mode for debugging (-vvv)
- [ ] Validate variables with assert
- [ ] Use molecule for role testing
- [ ] Test in staging before production
- [ ] Keep collections up to date
- [ ] Document custom variables
- [ ] Use version control for all playbooks

## Quick Reference Commands

```bash
# Syntax check
ansible-playbook playbook.yml --syntax-check

# Dry run
ansible-playbook playbook.yml --check --diff

# Run with tags
ansible-playbook playbook.yml --tags webserver

# Limit to specific hosts
ansible-playbook playbook.yml --limit webserver1

# Verbose output
ansible-playbook playbook.yml -vvv

# List tasks
ansible-playbook playbook.yml --list-tasks

# List hosts
ansible-playbook playbook.yml --list-hosts

# Step through tasks
ansible-playbook playbook.yml --step

# Start at specific task
ansible-playbook playbook.yml --start-at-task="Install nginx"
```
