---
name: ansible-generator
description: Comprehensive toolkit for generating best practice Ansible playbooks, roles, tasks, and inventory files.
---

# Ansible Generator

## Overview

Generate production-ready Ansible resources (playbooks, roles, tasks, inventory files) following current best practices, naming conventions, and security standards. All generated resources are automatically validated using the devops-skills:ansible-validator skill to ensure syntax correctness and lint compliance.

## Core Capabilities

### 1. Generate Ansible Playbooks

Create complete, production-ready playbooks with proper structure, error handling, and idempotency.

**When to use:**
- User requests: "Create a playbook to...", "Build a playbook for...", "Generate playbook that..."
- Scenarios: Application deployment, system configuration, backup automation, service management

**Process:**
1. Understand the user's requirements (what needs to be automated)
2. Identify target hosts, required privileges, and operating systems
3. Use `assets/templates/playbook/basic_playbook.yml` as structural foundation
4. Reference `references/best-practices.md` for implementation patterns
5. Reference `references/module-patterns.md` for correct module usage
6. Generate the playbook following these principles:
   - Use Fully Qualified Collection Names (FQCN) for all modules
   - Ensure idempotency (all tasks safe to run multiple times)
   - Include proper error handling and conditionals
   - Add meaningful task names starting with verbs
   - Use appropriate tags for task categorization
   - Include documentation header with usage instructions
   - Add health checks in post_tasks when applicable
7. **ALWAYS validate** the generated playbook using the devops-skills:ansible-validator skill
8. If validation fails, fix the issues and re-validate

**Example structure:**
```yaml
---
# Playbook: Deploy Web Application
# Description: Deploy nginx web server with SSL
# Requirements:
#   - Ansible 2.10+
#   - Target hosts: Ubuntu 20.04+
# Variables:
#   - app_port: Application port (default: 8080)
# Usage:
#   ansible-playbook -i inventory/production deploy_web.yml

- name: Deploy and configure web server
  hosts: webservers
  become: true
  gather_facts: true

  vars:
    app_port: 8080
    nginx_version: latest

  pre_tasks:
    - name: Update package cache
      ansible.builtin.apt:
        update_cache: true
        cache_valid_time: 3600
      when: ansible_os_family == "Debian"

  tasks:
    - name: Ensure nginx is installed
      ansible.builtin.package:
        name: nginx
        state: present
      tags:
        - install
        - nginx

    - name: Deploy nginx configuration
      ansible.builtin.template:
        src: templates/nginx.conf.j2
        dest: /etc/nginx/nginx.conf
        mode: '0644'
        backup: true
        validate: 'nginx -t -c %s'
      notify: Reload nginx
      tags:
        - configure

  post_tasks:
    - name: Verify nginx is responding
      ansible.builtin.uri:
        url: "http://localhost:{{ app_port }}/health"
        status_code: 200
      register: health_check
      until: health_check.status == 200
      retries: 5
      delay: 10

  handlers:
    - name: Reload nginx
      ansible.builtin.service:
        name: nginx
        state: reloaded
```

### 2. Generate Ansible Roles

Create complete role structures with all required components organized following Ansible Galaxy conventions.

**When to use:**
- User requests: "Create a role for...", "Generate a role to...", "Build role that..."
- Scenarios: Reusable component creation, complex service setup, multi-environment deployments

**Process:**
1. Understand the role's purpose and scope
2. Copy and customize the complete role structure from `assets/templates/role/`:
   - `tasks/main.yml` - Main task execution logic
   - `handlers/main.yml` - Event handlers (service restarts, reloads)
   - `templates/` - Jinja2 configuration templates
   - `files/` - Static files to copy
   - `vars/main.yml` - Role-specific variables (high priority)
   - `vars/Debian.yml` and `vars/RedHat.yml` - OS-specific variables
   - `defaults/main.yml` - Default variables (easily overridable)
   - `meta/main.yml` - Role metadata and dependencies
   - `README.md` - Role documentation
3. Replace all `[PLACEHOLDERS]` with actual values:
   - `[ROLE_NAME]` - The role name (lowercase with underscores)
   - `[role_name]` - Variable prefix for role variables
   - `[PLAYBOOK_DESCRIPTION]` - Description of what the role does
   - `[package_name]`, `[service_name]` - Actual package/service names
   - `[default_port]` - Default port numbers
   - All other placeholders as needed
4. Implement role-specific logic following best practices:
   - Use OS-specific variables via `include_vars`
   - Prefix all role variables with role name
   - Create handlers for all service changes
   - Include validation in template tasks
   - Add comprehensive tags
5. Create proper role documentation in README.md
6. **ALWAYS validate** the role using the devops-skills:ansible-validator skill
7. Fix any validation errors and re-validate

**Role variable naming convention:**
- Prefix: `{{ role_name }}_`
- Examples: `nginx_port`, `nginx_worker_processes`, `postgres_max_connections`

### 3. Generate Task Files

Create focused task files for specific operations that can be included in playbooks or roles.

**When to use:**
- User requests: "Create tasks to...", "Generate task file for..."
- Scenarios: Reusable task sequences, complex operations, conditional includes

**Process:**
1. Define the specific operation to automate
2. Reference `references/module-patterns.md` for correct module usage
3. Generate task file with:
   - Descriptive task names (verb-first)
   - FQCN for all modules
   - Proper error handling
   - Idempotency checks
   - Appropriate tags
   - Conditional execution where needed
4. **ALWAYS validate** using the devops-skills:ansible-validator skill

**Example:**
```yaml
---
# Tasks: Database backup operations

- name: Create backup directory
  ansible.builtin.file:
    path: "{{ backup_dir }}"
    state: directory
    mode: '0755'
    owner: postgres
    group: postgres

- name: Dump PostgreSQL database
  ansible.builtin.command: >
    pg_dump -h {{ db_host }} -U {{ db_user }} -d {{ db_name }}
    -f {{ backup_dir }}/{{ db_name }}_{{ ansible_date_time.date }}.sql
  environment:
    PGPASSWORD: "{{ db_password }}"
  no_log: true
  changed_when: true

- name: Compress backup file
  ansible.builtin.archive:
    path: "{{ backup_dir }}/{{ db_name }}_{{ ansible_date_time.date }}.sql"
    dest: "{{ backup_dir }}/{{ db_name }}_{{ ansible_date_time.date }}.sql.gz"
    format: gz
    remove: true

- name: Remove old backups
  ansible.builtin.find:
    paths: "{{ backup_dir }}"
    patterns: "*.sql.gz"
    age: "{{ backup_retention_days }}d"
  register: old_backups

- name: Delete old backup files
  ansible.builtin.file:
    path: "{{ item.path }}"
    state: absent
  loop: "{{ old_backups.files }}"
```

### 4. Generate Inventory Files

Create inventory configurations with proper host organization, group hierarchies, and variable management.

**When to use:**
- User requests: "Create inventory for...", "Generate inventory file..."
- Scenarios: Environment setup, host organization, multi-tier architectures

**Process:**
1. Understand the infrastructure topology
2. Use `assets/templates/inventory/` as foundation:
   - `hosts` - Main inventory file (INI or YAML format)
   - `group_vars/all.yml` - Global variables for all hosts
   - `group_vars/[groupname].yml` - Group-specific variables
   - `host_vars/[hostname].yml` - Host-specific variables
3. Organize hosts into logical groups:
   - Functional groups: `webservers`, `databases`, `loadbalancers`
   - Environment groups: `production`, `staging`, `development`
   - Geographic groups: `us-east`, `eu-west`
4. Create group hierarchies with `[group:children]`
5. Define variables at appropriate levels (all → group → host)
6. Document connection settings and requirements

**Inventory format preference:**
- Use INI format for simple, flat inventories
- Use YAML format for complex, hierarchical inventories

**Dynamic Inventory (Cloud Environments):**
For AWS, Azure, GCP, and other cloud providers, use dynamic inventory plugins:
- AWS EC2: `plugin: amazon.aws.aws_ec2` with filters and keyed_groups
- Azure: `plugin: azure.azcollection.azure_rm` with resource group filters
- Enables automatic host discovery based on tags, regions, and resource groups
- See `references/module-patterns.md` for detailed examples

### 5. Generate Project Configuration Files

**When to use:**
- User requests: "Set up Ansible project", "Initialize Ansible configuration"
- Scenarios: New project initialization, standardizing project structure

**Process:**
1. Use templates from `assets/templates/project/`:
   - `ansible.cfg` - Project configuration (forks, timeout, paths)
   - `requirements.yml` - Collections and roles dependencies
   - `.ansible-lint` - Lint rules for code quality
2. Customize based on project requirements
3. Document usage instructions

### 6. Role Argument Specifications (Ansible 2.11+)

When generating roles, include `meta/argument_specs.yml` for automatic variable validation:
- Define required and optional variables
- Specify types (str, int, bool, list, dict, path)
- Set default values and choices
- Enable automatic validation before role execution
- Template available at `assets/templates/role/meta/argument_specs.yml`

### 7. Handling Custom Modules and Collections

When generating Ansible resources that require custom modules, collections, or providers that are not part of ansible.builtin:

**Detection:**
- User mentions specific collections (e.g., "kubernetes.core", "amazon.aws", "community.docker")
- User requests integration with external tools/platforms
- Task requires modules not in ansible.builtin namespace

**Process:**
1. **Identify the collection/module:**
   - Extract collection name and module name
   - Determine if version-specific information is needed

2. **Search for current documentation using WebSearch:**
   ```
   Search query pattern: "ansible [collection.name] [module] [version] documentation examples"
   Examples:
   - "ansible kubernetes.core k8s module latest documentation"
   - "ansible amazon.aws ec2_instance 2024 examples"
   - "ansible community.docker docker_container latest documentation"
   ```

3. **Analyze search results for:**
   - Current module parameters and their types
   - Required vs optional parameters
   - Version compatibility and deprecation notices
   - Working examples and best practices
   - Collection installation requirements

4. **If Context7 MCP is available:**
   - First try to resolve library ID using `mcp__context7__resolve-library-id`
   - Then fetch documentation using `mcp__context7__get-library-docs`
   - This provides more structured and reliable documentation

5. **Generate resource using discovered information:**
   - Use correct FQCN (e.g., `kubernetes.core.k8s`, not just `k8s`)
   - Apply current parameter names and values
   - Include collection installation instructions in comments
   - Add version compatibility notes

6. **Include installation instructions:**
   ```yaml
   # Requirements:
   #   - ansible-galaxy collection install kubernetes.core:2.4.0
   # or in requirements.yml:
   # ---
   # collections:
   #   - name: kubernetes.core
   #     version: "2.4.0"
   ```

**Example with custom collection:**
```yaml
---
# Playbook: Deploy Kubernetes Resources
# Requirements:
#   - Ansible 2.10+
#   - Collection: kubernetes.core >= 2.4.0
#   - Install: ansible-galaxy collection install kubernetes.core
# Variables:
#   - k8s_namespace: Target namespace (default: default)
#   - k8s_kubeconfig: Path to kubeconfig (default: ~/.kube/config)

- name: Deploy application to Kubernetes
  hosts: localhost
  gather_facts: false
  vars:
    k8s_namespace: production
    k8s_kubeconfig: ~/.kube/config

  tasks:
    - name: Create namespace
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        definition:
          apiVersion: v1
          kind: Namespace
          metadata:
            name: "{{ k8s_namespace }}"
      tags:
        - namespace

    - name: Deploy application
      kubernetes.core.k8s:
        kubeconfig: "{{ k8s_kubeconfig }}"
        state: present
        namespace: "{{ k8s_namespace }}"
        definition:
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: myapp
          spec:
            replicas: 3
            selector:
              matchLabels:
                app: myapp
            template:
              metadata:
                labels:
                  app: myapp
              spec:
                containers:
                  - name: myapp
                    image: myapp:1.0.0
                    ports:
                      - containerPort: 8080
      tags:
        - deployment
```

## Validation Workflow

**CRITICAL:** Every generated Ansible resource MUST be validated before presenting to the user.

### Validation Process

1. **After generating any Ansible file**, immediately invoke the `devops-skills:ansible-validator` skill:
   ```
   Skill: devops-skills:ansible-validator
   ```

2. **The devops-skills:ansible-validator skill will:**
   - Validate YAML syntax
   - Run ansible-lint for best practices
   - Perform ansible-playbook --syntax-check
   - Execute in check mode (dry-run) when applicable
   - Report any errors, warnings, or issues

3. **If validation fails:**
   - Analyze the reported errors
   - Fix the issues in the generated file
   - Re-validate until all checks pass

4. **If validation succeeds, present the result formally:**

   **Required Presentation Format:**
   ```
   ## Generated [Resource Type]: [Name]

   **Validation Status:** ✅ All checks passed
   - YAML syntax: Passed
   - Ansible syntax: Passed
   - Ansible lint: Passed

   **Summary:**
   - [Brief description of what was generated]
   - [Key features/sections included]
   - [Any notable implementation decisions]

   **Usage:**
   ```bash
   [Exact command to run the playbook/role]
   ```

   **Prerequisites:**
   - [Any required collections or dependencies]
   - [Target system requirements]
   ```

   This formal presentation ensures the user clearly understands:
   - That validation was successful
   - What was generated and why
   - How to use the generated resource
   - Any prerequisites or dependencies

### When to Skip Validation

Only skip validation when:
- Generating partial code snippets (not complete files)
- Creating examples for documentation purposes
- User explicitly requests to skip validation

## Best Practices to Enforce

Reference `references/best-practices.md` for comprehensive guidelines. Key principles:

### Mandatory Standards

1. **FQCN (Fully Qualified Collection Names):**
   - ✅ Correct: `ansible.builtin.copy`, `community.general.ufw`
   - ❌ Wrong: `copy`, `ufw`

2. **Idempotency:**
   - All tasks must be safe to run multiple times
   - Use `state: present/absent` declarations
   - Avoid `command`/`shell` when builtin modules exist
   - When using `command`/`shell`, use `creates`, `removes`, or `changed_when`

3. **Naming:**
   - Task names: Descriptive, start with verb ("Ensure", "Create", "Deploy")
   - Variables: snake_case with descriptive names
   - Role variables: Prefixed with role name
   - Files: lowercase with underscores

4. **Security:**
   - Use `no_log: true` for sensitive operations
   - Set restrictive file permissions (600 for secrets, 644 for configs)
   - Never commit passwords/secrets in plain text
   - Reference ansible-vault for secrets management

5. **Error Handling:**
   - Include `when` conditionals for OS-specific tasks
   - Use `register` to capture task results
   - Add `failed_when` and `changed_when` for command modules
   - Include `validate` parameter for configuration files

6. **Performance:**
   - Disable fact gathering when not needed: `gather_facts: false`
   - Use `update_cache` with `cache_valid_time` for package managers
   - Implement async tasks for long-running operations

7. **Documentation:**
   - Add header comments to playbooks with requirements and usage
   - Document all variables with descriptions and defaults
   - Include examples in role README files

### Module Selection Priority

**IMPORTANT:** Always prefer builtin modules over collection modules when possible. This ensures:
- Better validation compatibility (validation environments may not have collections installed)
- Fewer external dependencies
- More reliable playbook execution across environments

**Priority Order:**
1. **Builtin modules (`ansible.builtin.*`)** - ALWAYS first choice
   - Check `references/module-patterns.md` for builtin alternatives before using collections
   - Example: Use `ansible.builtin.command` with `psql` instead of `community.postgresql.postgresql_db` if collection isn't essential
2. **Official collection modules** (verified collections) - Second choice, only when builtin doesn't exist
3. **Community modules** (`community.*`) - Third choice
4. **Custom modules** - Last resort
5. **Avoid `command`/`shell`** - Only when no module alternative exists

### Handling Collection Dependencies in Validation

When validation fails due to missing collections (e.g., "couldn't resolve module/action"):

1. **First, check if a builtin alternative exists:**
   - Many collection modules have `ansible.builtin.*` equivalents
   - Example: Instead of `community.postgresql.postgresql_db`, use `ansible.builtin.command` with `psql` commands
   - Example: Instead of `community.docker.docker_container`, use `ansible.builtin.command` with `docker` CLI

2. **If collection is required (no builtin alternative):**
   - Document the collection requirement clearly in the playbook header
   - Add installation instructions in comments
   - Consider providing both approaches (collection-based and builtin fallback)

3. **If validation environment lacks collections:**
   - Rewrite tasks using `ansible.builtin.*` modules with equivalent CLI commands
   - Use `changed_when` and `creates`/`removes` for idempotency with command modules
   - Document that the collection-based approach is preferred in production

**Example - Builtin fallback for PostgreSQL:**
```yaml
# Preferred (requires community.postgresql collection):
# - name: Create database
#   community.postgresql.postgresql_db:
#     name: mydb
#     state: present

# Builtin fallback (works without collection):
- name: Check if database exists
  ansible.builtin.command:
    cmd: psql -tAc "SELECT 1 FROM pg_database WHERE datname='mydb'"
  become: true
  become_user: postgres
  register: db_check
  changed_when: false

- name: Create database
  ansible.builtin.command:
    cmd: psql -c "CREATE DATABASE mydb"
  become: true
  become_user: postgres
  when: db_check.stdout != "1"
  changed_when: true
```

## Resources

### References (Load on Skill Invocation)

**IMPORTANT:** These reference files should be **read at the start of generation** to inform implementation decisions. Do not just rely on general knowledge - explicitly read the references to ensure current best practices are applied.

- `references/best-practices.md` - Comprehensive Ansible best practices guide
  - Directory structures, naming conventions, task writing
  - Variables, handlers, templates, security
  - Testing, performance optimization, common pitfalls
  - **When to read:** At the start of generating any Ansible resource
  - **How to use:** Extract relevant patterns for the specific resource type being generated

- `references/module-patterns.md` - Common module usage patterns and examples
  - Complete examples for all common ansible.builtin modules
  - Collection module examples (docker, postgresql, etc.)
  - Copy-paste ready code snippets
  - **When to read:** When selecting modules for tasks
  - **How to use:** Find the correct module and parameter syntax for the operation needed

### Assets (Templates as Reference Structures)

Templates serve as **structural references** showing the expected format and organization. You do NOT need to literally copy and paste them - use them as guides for the correct structure, sections, and patterns.

- `assets/templates/playbook/basic_playbook.yml` - Reference playbook structure
  - Shows: pre_tasks, tasks, post_tasks, handlers organization
  - Shows: Header documentation format
  - Shows: Variable declaration patterns
- `assets/templates/role/*` - Reference role directory structure
  - Shows: Required files and their organization
  - Shows: Variable naming conventions
  - `meta/argument_specs.yml` - Role variable validation (Ansible 2.11+)
- `assets/templates/inventory/*` - Reference inventory organization
  - Shows: Host grouping patterns
  - Shows: group_vars/host_vars structure
- `assets/templates/project/*` - Reference project configuration
  - `ansible.cfg` - Project-level Ansible configuration
  - `requirements.yml` - Collections and roles dependencies
  - `.ansible-lint` - Linting rules configuration

**How to use templates:**
1. **Review** the relevant template to understand the expected structure
2. **Generate** content following the same organizational pattern
3. **Replace** all `[PLACEHOLDERS]` with actual values appropriate for the task
4. **Customize** logic based on user requirements
5. **Remove** unnecessary sections that don't apply
6. **Validate** the result using devops-skills:ansible-validator skill

## Typical Workflow Example

**User request:** "Create a playbook to deploy nginx with SSL"

**Process:**
1. ✅ Understand requirements:
   - Deploy nginx web server
   - Configure SSL/TLS
   - Ensure service is running
   - Target: Linux servers (Ubuntu/RHEL)

2. ✅ Reference resources:
   - Check `references/best-practices.md` for playbook structure
   - Check `references/module-patterns.md` for nginx-related modules
   - Use `assets/templates/playbook/basic_playbook.yml` as base

3. ✅ Generate playbook:
   - Use FQCN for all modules
   - Include OS-specific conditionals
   - Add SSL configuration tasks
   - Include validation and health checks
   - Add proper tags and handlers

4. ✅ Validate:
   - Invoke `devops-skills:ansible-validator` skill
   - Fix any reported issues
   - Re-validate if needed

5. ✅ Present to user:
   - Show validated playbook
   - Explain key sections
   - Provide usage instructions
   - Mention successful validation

## Common Patterns

### Multi-OS Support
```yaml
- name: Install nginx (Debian/Ubuntu)
  ansible.builtin.apt:
    name: nginx
    state: present
  when: ansible_os_family == "Debian"

# NOTE: For RHEL 8+, use ansible.builtin.dnf instead of yum
# ansible.builtin.yum is deprecated in favor of dnf for modern RHEL/CentOS
- name: Install nginx (RHEL 8+/CentOS 8+)
  ansible.builtin.dnf:
    name: nginx
    state: present
  when: ansible_os_family == "RedHat"
```

### Template Deployment with Validation
```yaml
- name: Deploy configuration
  ansible.builtin.template:
    src: app_config.j2
    dest: /etc/app/config.yml
    mode: '0644'
    backup: true
    validate: '/usr/bin/app validate %s'
  notify: Restart application
```

### Async Long-Running Tasks
```yaml
- name: Run database migration
  ansible.builtin.command: /opt/app/migrate.sh
  async: 3600
  poll: 0
  register: migration

- name: Check migration status
  ansible.builtin.async_status:
    jid: "{{ migration.ansible_job_id }}"
  register: job_result
  until: job_result.finished
  retries: 360
  delay: 10
```

### Conditional Execution
```yaml
- name: Configure production settings
  ansible.builtin.template:
    src: production.j2
    dest: /etc/app/config.yml
  when:
    - env == "production"
    - ansible_distribution == "Ubuntu"
```

## Error Messages and Troubleshooting

### If devops-skills:ansible-validator reports errors:

1. **Syntax errors:** Fix YAML formatting, indentation, or structure
2. **Lint warnings:** Address best practice violations (FQCN, naming, etc.)
3. **Undefined variables:** Add variable definitions or defaults
4. **Module not found:** Check FQCN or add collection requirements
5. **Task failures in check mode:** Add `check_mode: no` for tasks that must run

### If custom module/collection documentation is not found:

1. Try alternative search queries with different versions
2. Check official Ansible Galaxy for collection
3. Look for module in ansible-collections GitHub org
4. Consider using alternative builtin modules
5. Ask user if they have specific version requirements

## Final Checklist (MANDATORY)

Before presenting any generated Ansible resource to the user, verify all items:

- [ ] **Reference files read** - Consulted `references/best-practices.md` and `references/module-patterns.md`
- [ ] **FQCN used** - All modules use fully qualified names (`ansible.builtin.*`, not bare names)
- [ ] **Booleans correct** - Use `true`/`false` (NOT `yes`/`no`) to pass ansible-lint
- [ ] **RHEL 8+** - Use `ansible.builtin.dnf` (NOT `ansible.builtin.yum`) for modern RHEL/CentOS
- [ ] **Idempotent** - All tasks safe to run multiple times
- [ ] **Security** - `no_log: true` on sensitive tasks, proper file permissions
- [ ] **Validated** - devops-skills:ansible-validator skill invoked and passed
- [ ] **Formal presentation** - Output formatted per template below

### Required Output Format

After validation passes, ALWAYS present results in this exact format:

```markdown
## Generated [Resource Type]: [Name]

**Validation Status:** ✅ All checks passed
- YAML syntax: Passed
- Ansible syntax: Passed
- Ansible lint: Passed

**Summary:**
- [Brief description of what was generated]
- [Key features/sections included]
- [Any notable implementation decisions]

**Usage:**
```bash
[Exact command to run the playbook/role]
```

**Prerequisites:**
- [Any required collections or dependencies]
- [Target system requirements]
```

---

## Summary

Always follow this sequence when generating Ansible resources:

1. **Understand** - Clarify user requirements
2. **Reference** - Check best-practices.md and module-patterns.md
3. **Generate** - Use templates and follow standards (FQCN, idempotency, naming)
4. **Search** - For custom modules/collections, use WebSearch to get current docs
5. **Validate** - ALWAYS use devops-skills:ansible-validator skill
6. **Fix** - Resolve any validation errors
7. **Present** - Deliver validated, production-ready Ansible code

Generate Ansible resources that are:
- ✅ Idempotent and safe to run multiple times
- ✅ Following current best practices and naming conventions
- ✅ Using FQCN for all modules
- ✅ Properly documented with usage instructions
- ✅ Validated and lint-clean
- ✅ Production-ready and maintainable
