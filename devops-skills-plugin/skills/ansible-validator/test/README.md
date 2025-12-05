# Ansible Testing

This directory contains test materials for validating the ansible-validator skill, including both playbooks and roles.

## Directory Structure

```
test/
├── README.md              # This file
├── playbooks/             # Example playbooks for testing
│   ├── good-playbook.yml  # Well-written playbook
│   └── bad-playbook.yml   # Playbook with issues
└── roles/                 # Test roles
    └── geerlingguy.mysql/ # Production-quality MySQL role
```

## Test Playbooks

### good-playbook.yml

A well-written Ansible playbook that follows best practices:
- All tasks are named
- Uses appropriate modules instead of shell/command
- Proper file permissions
- No hardcoded secrets
- Uses handlers correctly
- Implements tags for granular execution
- OS-specific tasks have conditionals

**Expected validation results:** Should pass all checks (yamllint, ansible-lint, syntax check)

### bad-playbook.yml

A poorly-written playbook with multiple issues:
- Hardcoded password (security issue)
- Tasks without names
- Using shell instead of modules
- Missing changed_when for commands
- Command injection risk (unquoted variables)
- Missing file permissions
- Deprecated with_items
- Handler name mismatch
- Overly permissive file permissions (777)
- Disabled SSL verification
- Missing OS conditionals

**Expected validation results:** Should fail multiple checks and report numerous issues

## Test Role: geerlingguy.mysql

This is a well-maintained, production-quality Ansible role by Jeff Geerling for installing and configuring MySQL.

**Source:** https://github.com/geerlingguy/ansible-role-mysql

**Features:**
- Complete role structure (tasks, defaults, handlers, meta, templates, vars)
- Molecule testing configured
- Multi-platform support (Debian, RedHat, Ubuntu, etc.)
- Comprehensive variable management
- Well-documented

This role serves as an excellent example for:
- Proper role structure
- Best practices implementation
- Molecule testing setup
- Multi-OS compatibility patterns

## Testing Commands

### Playbook Testing

```bash
# Validate good playbook (should pass)
bash ../scripts/validate_playbook.sh playbooks/good-playbook.yml

# Validate bad playbook (should fail with multiple errors)
bash ../scripts/validate_playbook.sh playbooks/bad-playbook.yml

# Extract modules from playbook
bash ../scripts/extract_ansible_info_wrapper.sh playbooks/good-playbook.yml
bash ../scripts/extract_ansible_info_wrapper.sh playbooks/bad-playbook.yml

# Individual validation steps
yamllint -c ../assets/.yamllint playbooks/good-playbook.yml
ansible-playbook --syntax-check playbooks/good-playbook.yml  # if ansible installed
ansible-lint -c ../assets/.ansible-lint playbooks/good-playbook.yml  # if ansible-lint installed
```

### Role Testing

```bash
# Comprehensive role validation
bash ../scripts/validate_role.sh roles/geerlingguy.mysql

# This checks:
# - Role directory structure
# - YAML syntax (yamllint)
# - Ansible syntax (if ansible is installed)
# - Ansible lint (if ansible-lint is installed)
# - Molecule configuration
```

### Extract Module Information

```bash
# Extract modules from role
bash ../scripts/extract_ansible_info_wrapper.sh roles/geerlingguy.mysql

# Extract modules from playbook
bash ../scripts/extract_ansible_info_wrapper.sh playbooks/good-playbook.yml
```

### Run Molecule Tests

```bash
# Run full molecule test suite
# Note: Molecule will be automatically installed in a temporary venv if not already installed
bash ../scripts/test_role.sh roles/geerlingguy.mysql

# Or run molecule directly (if installed)
cd roles/geerlingguy.mysql
molecule test
```

**Note:** The `test_role.sh` script automatically handles molecule installation. If molecule is not found on your system, the script will:
1. Create a temporary Python virtual environment
2. Install molecule, ansible-core, ansible-lint, and yamllint
3. Run the full test suite
4. Clean up the temporary environment automatically

No permanent installation required!

## Expected Validation Results

### Structure Check
- ✅ All required directories present (tasks/)
- ✅ All recommended directories present (defaults/, handlers/, meta/, templates/, vars/)
- ✅ Molecule directory configured
- ✅ Main YAML files exist

### YAML Syntax
- ✅ All YAML files are syntactically correct
- ⚠️ Some warnings about line length (acceptable)
- ⚠️ Minor trailing spaces in CI workflow files

### Ansible Lint
- Should pass most checks (role follows best practices)
- May have minor warnings about formatting

### Molecule
- Configured with default scenario
- Tests across multiple platforms (Ubuntu, Debian, Rocky Linux)
- Includes idempotency checks

## Adding More Test Roles

To add additional test roles for validation:

```bash
# Download from Ansible Galaxy
cd test/roles
ansible-galaxy role install namespace.rolename -p .

# Or clone from GitHub
git clone https://github.com/author/ansible-role-name.git author.rolename
```

### Recommended Test Roles

Popular, well-maintained roles for testing:

```bash
# Web servers
git clone https://github.com/geerlingguy/ansible-role-apache.git geerlingguy.apache
git clone https://github.com/geerlingguy/ansible-role-nginx.git geerlingguy.nginx

# Databases
git clone https://github.com/geerlingguy/ansible-role-postgresql.git geerlingguy.postgresql
git clone https://github.com/geerlingguy/ansible-role-redis.git geerlingguy.redis

# Languages/Runtimes
git clone https://github.com/geerlingguy/ansible-role-php.git geerlingguy.php
git clone https://github.com/geerlingguy/ansible-role-nodejs.git geerlingguy.nodejs

# DevOps tools
git clone https://github.com/geerlingguy/ansible-role-docker.git geerlingguy.docker
git clone https://github.com/geerlingguy/ansible-role-kubernetes.git geerlingguy.kubernetes
```

## Integration Testing

### Test the Full Validation Pipeline

```bash
#!/bin/bash
# test_all_roles.sh - Validate all roles in test directory

for role in roles/*; do
    if [ -d "$role" ]; then
        echo "Validating $(basename $role)..."
        bash ../scripts/validate_role.sh "$role"
        echo ""
    fi
done
```

### Test Module Extraction

```bash
#!/bin/bash
# extract_all_modules.sh - Extract modules from all roles

for role in roles/*; do
    if [ -d "$role" ]; then
        echo "=== $(basename $role) ==="
        bash ../scripts/extract_ansible_info_wrapper.sh "$role"
        echo ""
    fi
done
```

## Common Role Issues to Test

The validation scripts can detect:

1. **Structure Issues:**
   - Missing required directories (tasks/)
   - Missing main.yml files
   - Incorrect file naming

2. **Syntax Issues:**
   - Invalid YAML syntax
   - Indentation problems
   - Missing colons or quotes

3. **Best Practice Violations:**
   - Tasks without names
   - Hard-coded values instead of variables
   - Missing handlers
   - Improper use of command vs. shell

4. **Security Issues:**
   - Hard-coded secrets
   - Overly permissive file modes
   - Missing no_log on sensitive tasks

5. **Documentation Issues:**
   - Missing README.md
   - Missing role metadata (meta/main.yml)
   - Missing variable documentation

## Molecule Testing Details

The geerlingguy.mysql role includes molecule configuration:

```
molecule/
└── default/
    ├── molecule.yml       # Molecule configuration
    ├── converge.yml       # Playbook to test the role
    └── verify.yml         # Verification tests
```

### Running Molecule Tests

```bash
cd roles/geerlingguy.mysql

# Full test sequence
molecule test

# Individual stages
molecule create       # Create test instances
molecule converge     # Run the role
molecule verify       # Run verification tests
molecule destroy      # Clean up

# Debug mode
molecule converge
molecule login        # SSH into test instance
```

## Creating Your Own Test Role

To create a minimal test role:

```bash
mkdir -p test/roles/mytest/tasks
cat > test/roles/mytest/tasks/main.yml <<EOF
---
- name: Install package
  apt:
    name: vim
    state: present
  when: ansible_os_family == "Debian"
EOF

# Validate it
bash scripts/validate_role.sh test/roles/mytest
```

## CI/CD Integration

These test roles can be used in CI/CD pipelines:

```yaml
# .github/workflows/validate-roles.yml
name: Validate Ansible Roles

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Install dependencies
        run: |
          pip install ansible ansible-lint yamllint

      - name: Validate all roles
        run: |
          for role in test/roles/*; do
            bash scripts/validate_role.sh "$role"
          done
```

## Troubleshooting

### Role validation fails with "ansible-playbook not found"

Install Ansible:
```bash
pip install ansible
```

### Molecule tests fail with "docker not found"

The test_role.sh script will automatically install molecule in a temporary venv, but you still need Docker installed for molecule to create test containers:

```bash
# macOS
brew install docker

# Start Docker Desktop
open -a Docker

# Linux
sudo apt-get install docker.io    # Debian/Ubuntu
sudo yum install docker           # RHEL/CentOS
```

Note: Molecule itself doesn't need to be installed - the script handles that automatically.

### YAML lint warnings about line length

This is acceptable for readability. Adjust `.yamllint` if needed:
```yaml
rules:
  line-length:
    max: 200  # Increase limit
    level: warning
```

## Resources

- [Ansible Galaxy](https://galaxy.ansible.com/) - Find more roles to test
- [Molecule Documentation](https://molecule.readthedocs.io/) - Learn about role testing
- [Jeff Geerling's Roles](https://github.com/geerlingguy?tab=repositories&q=ansible-role) - High-quality example roles
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
