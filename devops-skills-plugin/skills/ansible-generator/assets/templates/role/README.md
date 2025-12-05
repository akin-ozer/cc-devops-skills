# Ansible Role: [ROLE_NAME]

[Brief description of what this role does]

## Requirements

- Ansible 2.10 or higher
- Supported platforms:
  - Ubuntu 20.04, 22.04, 24.04
  - Debian 11, 12
  - RHEL/CentOS/Rocky 8, 9

## Role Variables

### Required Variables

```yaml
# [var_name]: [description]
```

### Optional Variables

```yaml
# Package and service
[role_name]_package_name: [package_name]  # Package to install
[role_name]_service_name: [service_name]  # Service name
[role_name]_version: latest                # Version to install

# Directories
[role_name]_config_dir: /etc/[service_name]
[role_name]_data_dir: /var/lib/[service_name]
[role_name]_log_dir: /var/log/[service_name]

# Configuration
[role_name]_port: [default_port]
[role_name]_bind_address: 0.0.0.0
[role_name]_max_connections: 100

# Features
[role_name]_enable_ssl: false
[role_name]_enable_monitoring: true
```

## Dependencies

None.

## Example Playbook

```yaml
- hosts: servers
  become: yes
  roles:
    - role: [role_name]
      vars:
        [role_name]_port: [custom_port]
        [role_name]_enable_ssl: true
```

## Example with Variables

```yaml
- hosts: production
  become: yes
  vars:
    [role_name]_port: [custom_port]
    [role_name]_max_connections: 200
    [role_name]_enable_ssl: true
    [role_name]_ssl_cert: /etc/ssl/certs/app.crt
    [role_name]_ssl_key: /etc/ssl/private/app.key
  roles:
    - [role_name]
```

## Tags

- `install` - Installation tasks
- `configure` - Configuration tasks
- `service` - Service management tasks
- `packages` - Package installation
- `directories` - Directory creation

## License

MIT

## Author Information

[Author Name]
[Contact Information]
