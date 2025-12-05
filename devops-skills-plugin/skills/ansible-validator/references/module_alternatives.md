# Ansible Module Alternatives

## Overview

This guide provides replacement alternatives for deprecated or legacy Ansible modules. Use this reference when ansible-lint reports deprecated module warnings or when updating older playbooks to modern best practices.

## Quick Detection

Use the FQCN checker script to automatically detect non-FQCN module usage:

```bash
# Scan a playbook
bash scripts/check_fqcn.sh playbook.yml

# Scan a role
bash scripts/check_fqcn.sh roles/webserver/

# Scan entire directory
bash scripts/check_fqcn.sh .
```

The script identifies modules using short names and provides specific FQCN migration recommendations.

## Deprecated Modules and Replacements

### Package Management

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `apt` (short name) | `ansible.builtin.apt` | Use FQCN for clarity |
| `yum` (short name) | `ansible.builtin.yum` or `ansible.builtin.dnf` | dnf preferred for RHEL 8+ |
| `pip` (short name) | `ansible.builtin.pip` | Use FQCN |
| `easy_install` | `ansible.builtin.pip` | easy_install is deprecated in Python |
| `homebrew` | `community.general.homebrew` | Moved to community.general |
| `zypper` | `community.general.zypper` | Moved to community.general |
| `apk` | `community.general.apk` | Moved to community.general |

### File Operations

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `copy` (short name) | `ansible.builtin.copy` | Use FQCN |
| `file` (short name) | `ansible.builtin.file` | Use FQCN |
| `template` (short name) | `ansible.builtin.template` | Use FQCN |
| `lineinfile` (short name) | `ansible.builtin.lineinfile` | Use FQCN |
| `blockinfile` (short name) | `ansible.builtin.blockinfile` | Use FQCN |
| `synchronize` | `ansible.posix.synchronize` | Moved to ansible.posix |
| `acl` | `ansible.posix.acl` | Moved to ansible.posix |

### Service Management

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `service` (short name) | `ansible.builtin.service` or `ansible.builtin.systemd` | Use systemd for systemd-based systems |
| `systemd` (short name) | `ansible.builtin.systemd` | Use FQCN |
| `sysvinit` | `ansible.builtin.service` | service module handles sysvinit |

### User and Group Management

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `user` (short name) | `ansible.builtin.user` | Use FQCN |
| `group` (short name) | `ansible.builtin.group` | Use FQCN |
| `authorized_key` (short name) | `ansible.posix.authorized_key` | Moved to ansible.posix |

### Networking

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `get_url` (short name) | `ansible.builtin.get_url` | Use FQCN |
| `uri` (short name) | `ansible.builtin.uri` | Use FQCN |
| `iptables` | `ansible.builtin.iptables` | Use FQCN |
| `ufw` | `community.general.ufw` | Moved to community.general |
| `firewalld` | `ansible.posix.firewalld` | Moved to ansible.posix |

### Command Execution

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `command` (short name) | `ansible.builtin.command` | Use FQCN; prefer specific modules |
| `shell` (short name) | `ansible.builtin.shell` | Use FQCN; prefer specific modules |
| `raw` (short name) | `ansible.builtin.raw` | Use FQCN; use only when necessary |
| `script` (short name) | `ansible.builtin.script` | Use FQCN |

### Cloud Providers

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `ec2` | `amazon.aws.ec2_instance` | Use amazon.aws collection |
| `ec2_ami` | `amazon.aws.ec2_ami` | Use amazon.aws collection |
| `ec2_vpc` | `amazon.aws.ec2_vpc_net` | Use amazon.aws collection |
| `azure_rm_*` | `azure.azcollection.*` | Use azure.azcollection |
| `gcp_*` | `google.cloud.*` | Use google.cloud collection |
| `docker_container` | `community.docker.docker_container` | Use community.docker collection |
| `docker_image` | `community.docker.docker_image` | Use community.docker collection |

### Database

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `mysql_db` | `community.mysql.mysql_db` | Use community.mysql collection |
| `mysql_user` | `community.mysql.mysql_user` | Use community.mysql collection |
| `postgresql_db` | `community.postgresql.postgresql_db` | Use community.postgresql collection |
| `postgresql_user` | `community.postgresql.postgresql_user` | Use community.postgresql collection |
| `mongodb_*` | `community.mongodb.*` | Use community.mongodb collection |

### Monitoring and Logging

| Deprecated Module | Replacement | Notes |
|-------------------|-------------|-------|
| `nagios` | `community.general.nagios` | Use community.general collection |
| `zabbix_*` | `community.zabbix.*` | Use community.zabbix collection |

## FQCN Migration

### Why Use Fully Qualified Collection Names (FQCN)?

1. **Clarity**: Explicitly shows which collection provides the module
2. **Conflict Prevention**: Avoids naming conflicts between collections
3. **Future-Proofing**: Prevents breakage when modules move between collections
4. **Best Practice**: Recommended by Ansible for all new playbooks

### Migration Examples

```yaml
# Old style (deprecated)
- name: Install nginx
  apt:
    name: nginx
    state: present

# New style (recommended)
- name: Install nginx
  ansible.builtin.apt:
    name: nginx
    state: present
```

```yaml
# Old style (deprecated)
- name: Configure firewall
  ufw:
    rule: allow
    port: '443'

# New style (recommended)
- name: Configure firewall
  community.general.ufw:
    rule: allow
    port: '443'
```

## Installing Required Collections

When migrating to FQCN modules, ensure the required collections are installed:

```bash
# Install common collections
ansible-galaxy collection install ansible.posix
ansible-galaxy collection install community.general
ansible-galaxy collection install community.docker
ansible-galaxy collection install community.mysql
ansible-galaxy collection install community.postgresql
ansible-galaxy collection install amazon.aws
ansible-galaxy collection install azure.azcollection
ansible-galaxy collection install google.cloud
```

Or create a `requirements.yml`:

```yaml
---
collections:
  - name: ansible.posix
    version: ">=1.5.0"
  - name: community.general
    version: ">=6.0.0"
  - name: community.docker
    version: ">=3.0.0"
  - name: community.mysql
    version: ">=3.0.0"
  - name: community.postgresql
    version: ">=2.0.0"
```

Then install with:

```bash
ansible-galaxy collection install -r requirements.yml
```

## Checking for Deprecated Modules

Use ansible-lint to identify deprecated modules in your playbooks:

```bash
# Check for deprecated module usage
ansible-lint --profile production playbook.yml

# Show rule documentation for deprecated modules
ansible-lint -L | grep deprecated
```

## Version Compatibility Notes

- **Ansible 2.9**: Last version with many modules in ansible.builtin
- **Ansible 2.10+**: Collections separated from core
- **Ansible 2.12+**: Many deprecated modules removed from core
- **Ansible 2.14+**: FQCN strongly recommended for all modules

## Resources

- [Ansible Collections Index](https://docs.ansible.com/ansible/latest/collections/index.html)
- [Ansible Changelog](https://docs.ansible.com/ansible/latest/porting_guides/porting_guides.html)
- [Community Collections](https://galaxy.ansible.com/)
- [ansible-lint Rules](https://ansible.readthedocs.io/projects/lint/rules/)