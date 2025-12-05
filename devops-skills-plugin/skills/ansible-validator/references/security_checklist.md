# Ansible Security Checklist

## Overview

This checklist provides comprehensive security validation guidelines for Ansible playbooks, roles, and collections. Use this as a reference when reviewing Ansible code for security vulnerabilities.

## Secrets Management

### ❌ Bad Practices

```yaml
# Hardcoded passwords
- name: Create user
  user:
    name: admin
    password: "P@ssw0rd123"  # NEVER DO THIS

# Hardcoded API keys
- name: Configure API
  template:
    src: config.j2
    dest: /etc/app/config.yml
  vars:
    api_key: "sk-1234567890abcdef"  # NEVER DO THIS

# Credentials in variables
vars:
  db_password: "secret123"  # NEVER DO THIS
  aws_secret_key: "AKIAIOSFODNN7EXAMPLE"  # NEVER DO THIS
```

### ✅ Good Practices

```yaml
# Use Ansible Vault for sensitive data
- name: Create user
  user:
    name: admin
    password: "{{ admin_password | password_hash('sha512') }}"
  no_log: true

# Load vaulted variables
- name: Include vaulted vars
  include_vars:
    file: secrets.yml  # This file is encrypted with ansible-vault

# Use environment variables
- name: Configure API
  template:
    src: config.j2
    dest: /etc/app/config.yml
  environment:
    API_KEY: "{{ lookup('env', 'API_KEY') }}"
  no_log: true

# Use external secret management
- name: Fetch secret from HashiCorp Vault
  set_fact:
    db_password: "{{ lookup('hashi_vault', 'secret=secret/data/db:password') }}"
  no_log: true
```

### Best Practices

1. **Always use Ansible Vault** for sensitive data
   ```bash
   ansible-vault create secrets.yml
   ansible-vault encrypt existing_file.yml
   ```

2. **Never commit unencrypted secrets** to version control

3. **Use `no_log: true`** for tasks handling sensitive data
   ```yaml
   - name: Set database password
     set_fact:
       db_password: "{{ vault_db_password }}"
     no_log: true
   ```

4. **Rotate secrets regularly** and use version control for vault IDs

5. **Use different vault passwords** for different environments

## Privilege Escalation

### ❌ Bad Practices

```yaml
# Running entire playbook as root unnecessarily
- hosts: all
  become: yes
  become_user: root
  tasks:
    - name: Check application status
      command: systemctl status myapp

    - name: Read configuration
      slurp:
        src: /etc/myapp/config.yml

# No privilege escalation when needed
- name: Install package
  apt:
    name: nginx
    state: present
  # This will fail without become
```

### ✅ Good Practices

```yaml
# Only use become when necessary
- hosts: all
  tasks:
    - name: Check application status
      command: systemctl status myapp
      # No become needed for read-only systemctl

    - name: Install package
      apt:
        name: nginx
        state: present
      become: yes
      # Only escalate for this task

    - name: Configure application
      template:
        src: config.j2
        dest: /etc/myapp/config.yml
        owner: myapp
        group: myapp
        mode: '0640'
      become: yes
```

### Best Practices

1. **Principle of least privilege** - only escalate when necessary
2. **Use specific become_user** instead of always root
3. **Limit sudo access** to specific commands in sudoers
4. **Audit all become usage** in playbooks
5. **Use become_flags** carefully and document why

## File Permissions

### ❌ Bad Practices

```yaml
# World-readable sensitive files
- name: Create SSH key
  copy:
    src: id_rsa
    dest: /home/user/.ssh/id_rsa
    mode: '0644'  # WRONG: Private key readable by all

# No mode specified
- name: Create config file
  template:
    src: database.conf.j2
    dest: /etc/app/database.conf
  # Missing mode - depends on umask

# Overly permissive
- name: Create script
  copy:
    src: deploy.sh
    dest: /usr/local/bin/deploy.sh
    mode: '0777'  # WRONG: World writable
```

### ✅ Good Practices

```yaml
# Appropriate permissions for private keys
- name: Create SSH key
  copy:
    src: id_rsa
    dest: /home/user/.ssh/id_rsa
    owner: user
    group: user
    mode: '0600'

# Explicit permissions for config files
- name: Create config file
  template:
    src: database.conf.j2
    dest: /etc/app/database.conf
    owner: appuser
    group: appgroup
    mode: '0640'

# Minimal necessary permissions
- name: Create script
  copy:
    src: deploy.sh
    dest: /usr/local/bin/deploy.sh
    owner: root
    group: root
    mode: '0755'

# Set directory permissions properly
- name: Create secure directory
  file:
    path: /etc/app/secrets
    state: directory
    owner: appuser
    group: appgroup
    mode: '0750'
```

### Permission Guidelines

| File Type | Recommended Mode | Owner | Group |
|-----------|-----------------|-------|-------|
| Private keys | 0600 | user | user |
| Public keys | 0644 | user | user |
| Config files (sensitive) | 0640 | app | app |
| Config files (public) | 0644 | app | app |
| Executables | 0755 | root | root |
| Directories (sensitive) | 0750 | app | app |
| Directories (public) | 0755 | app | app |
| Log files | 0640 | app | app |

## Command Injection Prevention

### ❌ Bad Practices

```yaml
# Unvalidated user input in commands
- name: Process user file
  shell: "cat {{ user_provided_filename }}"
  # VULNERABLE: User could provide "; rm -rf /"

# Direct variable interpolation
- name: Search logs
  command: "grep {{ search_term }} /var/log/app.log"
  # VULNERABLE: User could inject commands

# Using shell when not needed
- name: Create directory
  shell: "mkdir -p {{ directory_name }}"
  # RISKY: Use file module instead
```

### ✅ Good Practices

```yaml
# Use quote filter for variables in shell
- name: Process user file
  shell: "cat {{ user_provided_filename | quote }}"
  when: user_provided_filename is match('^[a-zA-Z0-9._-]+$')

# Better: Use modules instead of shell/command
- name: Create directory
  file:
    path: "{{ directory_name }}"
    state: directory
    mode: '0755'

# Validate input before use
- name: Search logs
  command: "grep {{ search_term }} /var/log/app.log"
  when:
    - search_term is defined
    - search_term | length > 0
    - search_term is match('^[a-zA-Z0-9 ]+$')
  args:
    warn: false

# Use args for command parameters
- name: Run script with arguments
  command: /usr/local/bin/script.sh
  args:
    stdin: "{{ user_input }}"
```

### Best Practices

1. **Prefer modules over command/shell** whenever possible
2. **Always use quote filter** for variables in shell commands
3. **Validate input** with regex patterns
4. **Use whitelist validation** not blacklist
5. **Never trust user input** without validation

## Network Security

### ❌ Bad Practices

```yaml
# Unencrypted protocols
- name: Download file
  get_url:
    url: http://example.com/file.tar.gz  # WRONG: HTTP not HTTPS
    dest: /tmp/file.tar.gz

# Disabled SSL verification
- name: Call API
  uri:
    url: https://api.example.com/data
    validate_certs: no  # WRONG: Disables security

# Exposing on all interfaces unnecessarily
- name: Configure service
  template:
    src: config.j2
    dest: /etc/app/config.yml
  vars:
    bind_address: "0.0.0.0"  # RISKY: Expose to all
```

### ✅ Good Practices

```yaml
# Use HTTPS
- name: Download file
  get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    checksum: sha256:abc123...

# Validate SSL certificates
- name: Call API
  uri:
    url: https://api.example.com/data
    validate_certs: yes
    client_cert: /path/to/cert.pem
    client_key: /path/to/key.pem

# Bind to specific interface
- name: Configure service
  template:
    src: config.j2
    dest: /etc/app/config.yml
  vars:
    bind_address: "127.0.0.1"  # Localhost only

# Use firewall rules
- name: Configure firewall
  ufw:
    rule: allow
    port: '443'
    proto: tcp
    src: '10.0.0.0/8'  # Only from internal network
```

### Best Practices

1. **Always use HTTPS** for external communications
2. **Validate SSL certificates** - only disable for testing
3. **Bind services to specific interfaces** when possible
4. **Use firewall rules** to restrict access
5. **Encrypt sensitive data in transit** (TLS/SSL)

## SELinux and AppArmor

### Best Practices

```yaml
# Don't disable SELinux
- name: Configure SELinux
  selinux:
    policy: targeted
    state: enforcing  # Not permissive or disabled

# Set proper SELinux contexts
- name: Set SELinux context for web content
  sefcontext:
    target: '/web/content(/.*)?'
    setype: httpd_sys_content_t
    state: present

- name: Apply SELinux context
  command: restorecon -Rv /web/content

# Manage AppArmor profiles
- name: Load AppArmor profile
  command: apparmor_parser -r /etc/apparmor.d/usr.bin.myapp
```

## Audit and Logging

### Best Practices

```yaml
# Log security-relevant actions
- name: Create admin user
  user:
    name: admin
    groups: sudo
    state: present
  register: admin_user_result

- name: Log user creation
  lineinfile:
    path: /var/log/ansible-changes.log
    line: "{{ ansible_date_time.iso8601 }} - Admin user created by {{ ansible_user_id }}"
    create: yes
  when: admin_user_result.changed

# Use tags for security-related tasks
- name: Configure SSH
  template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
  tags:
    - security
    - ssh
```

## Security Validation Checklist

Before running playbooks in production, verify:

- [ ] No hardcoded secrets (passwords, API keys, tokens)
- [ ] All sensitive data encrypted with Ansible Vault
- [ ] `no_log: true` used for tasks handling secrets
- [ ] Privilege escalation only where necessary
- [ ] File permissions explicitly set (not relying on umask)
- [ ] Private keys have mode 0600
- [ ] No world-writable files or directories
- [ ] Input validation for user-provided variables
- [ ] Using modules instead of shell/command where possible
- [ ] Quote filter used for variables in shell commands
- [ ] HTTPS used instead of HTTP
- [ ] SSL certificate validation enabled
- [ ] Services bound to specific interfaces, not 0.0.0.0
- [ ] Firewall rules configured appropriately
- [ ] SELinux/AppArmor not disabled
- [ ] Security contexts set correctly
- [ ] Security-relevant actions logged
- [ ] Regular security updates applied
- [ ] Unused packages removed
- [ ] Default credentials changed
- [ ] Unnecessary services disabled

## Tools for Security Scanning

1. **ansible-lint** - Includes security-focused rules
   ```bash
   ansible-lint --profile security playbook.yml
   ```

2. **Ansible Galaxy Security Scan**
   ```bash
   ansible-galaxy collection scan namespace.collection
   ```

3. **Git-secrets** - Prevent committing secrets
   ```bash
   git secrets --scan
   ```

4. **Trivy** - Scan for vulnerabilities
   ```bash
   trivy config .
   ```

## Additional Resources

- [Ansible Security Automation](https://www.ansible.com/use-cases/security-automation)
- [Ansible Best Practices - Security](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#best-practices-for-variables-and-vaults)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
