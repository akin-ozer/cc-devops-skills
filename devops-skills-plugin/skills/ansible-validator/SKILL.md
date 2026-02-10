---
name: ansible-validator
description: Comprehensive toolkit for validating, linting, testing, and automating Ansible playbooks, roles, and collections. Use this skill when working with Ansible files (.yml, .yaml playbooks, roles, inventories), validating automation code, debugging playbook execution, performing dry-run testing with check mode, or working with custom modules and collections.
---

# Ansible Validator

## Overview

Comprehensive toolkit for validating, linting, and testing Ansible playbooks, roles, and collections. This skill provides automated workflows for ensuring Ansible code quality, syntax validation, dry-run testing with check mode and molecule, and intelligent documentation lookup for custom modules and collections with version awareness.

**IMPORTANT BEHAVIOR:** When validating any Ansible role, this skill AUTOMATICALLY runs molecule tests if a `molecule/` directory is detected in the role. This is non-negotiable and happens without asking for user permission. If molecule tests cannot run due to environmental issues (Docker, version compatibility), the skill documents the blocker but continues with other validation steps.

## When to Use This Skill

Apply this skill when encountering any of these scenarios:

- Working with Ansible files (`.yml`, `.yaml` playbooks, roles, inventories, vars)
- Validating Ansible playbook syntax and structure
- Linting and formatting Ansible code
- Performing dry-run testing with `ansible-playbook --check`
- Testing roles and playbooks with Molecule
- Debugging Ansible errors or misconfigurations
- Understanding custom Ansible modules, collections, or roles
- Ensuring infrastructure-as-code best practices
- Security validation of Ansible playbooks
- Version compatibility checks for collections and modules

## Validation Workflow

Follow this decision tree for comprehensive Ansible validation:

```
0. Tool Prerequisites Check (RECOMMENDED for first-time validation)
   ├─> Run bash scripts/setup_tools.sh for diagnostics
   ├─> Verify required tools are available
   ├─> Get installation instructions if tools are missing
   └─> NOTE: Validation scripts auto-install tools in temp venv if missing,
       but running setup_tools.sh first helps identify system issues early

1. Identify Ansible files in scope
   ├─> Single playbook validation
   ├─> Role validation
   ├─> Collection validation
   └─> Multi-playbook/inventory validation

2. Syntax Validation
   ├─> Run ansible-playbook --syntax-check
   ├─> Run yamllint for YAML syntax
   └─> Report syntax errors

3. Lint and Best Practices
   ├─> Run ansible-lint (comprehensive linting)
   ├─> Check for deprecated modules (see references/module_alternatives.md)
   ├─> **DETECT NON-FQCN MODULE USAGE** (apt vs ansible.builtin.apt)
   │   └─> Run bash scripts/check_fqcn.sh to identify short module names
   │   └─> Recommend FQCN alternatives from references/module_alternatives.md
   ├─> Verify role structure
   └─> Report linting issues

4. Dry-Run Testing (check mode)
   ├─> Run ansible-playbook --check (if inventory available)
   ├─> Analyze what would change
   └─> Report potential issues

5. Molecule Testing (for roles) - AUTOMATIC
   ├─> Check if molecule/ directory exists in role
   ├─> If present, ALWAYS run molecule test automatically
   ├─> Test against multiple scenarios
   ├─> Report test results (pass/fail/blocked)
   └─> Report any environmental issues if tests cannot run

6. Custom Module/Collection Analysis (if detected)
   ├─> Extract module/collection information
   ├─> Identify versions
   ├─> Lookup documentation (WebSearch or Context7)
   └─> Provide version-specific guidance

7. Security and Best Practices Review - DUAL SCANNING REQUIRED
   ├─> Run bash scripts/validate_playbook_security.sh or validate_role_security.sh (Checkov)
   ├─> **ALSO run bash scripts/scan_secrets.sh** for hardcoded secret detection
   │   └─> This catches secrets Checkov may miss (passwords, API keys, tokens)
   ├─> Validate privilege escalation
   ├─> Review file permissions
   └─> Identify common anti-patterns

8. Reference Documentation - MANDATORY CONSULTATION
   ├─> **MUST READ** references/common_errors.md when ANY errors are detected
   │   └─> Extract specific remediation steps for the error type
   │   └─> Include relevant guidance in validation report
   ├─> **MUST READ** references/best_practices.md when warnings are detected
   │   └─> Cite specific best practice recommendations
   ├─> **MUST READ** references/module_alternatives.md when:
   │   └─> Deprecated modules are detected
   │   └─> Non-FQCN module names are used (apt, service, etc.)
   │   └─> Provide specific FQCN migration recommendations
   └─> **MUST READ** references/security_checklist.md when security issues found
       └─> Include specific remediation guidance from checklist
```

**CRITICAL: Reference files are NOT optional.** When issues are detected, the corresponding reference file MUST be read and its guidance applied to provide actionable remediation steps to the user. Simply mentioning the reference file path is insufficient - the content must be consulted and relevant guidance extracted.

## Core Capabilities

### 1. YAML Syntax Validation

**Purpose:** Ensure YAML files are syntactically correct before Ansible parsing.

**Tools:**
- `yamllint` - YAML linter for syntax and formatting
- `ansible-playbook --syntax-check` - Ansible-specific syntax validation

**Workflow:**

```bash
# Check YAML syntax with yamllint
yamllint playbook.yml

# Or for entire directory
yamllint -c .yamllint .

# Check Ansible playbook syntax
ansible-playbook playbook.yml --syntax-check
```

**Common Issues Detected:**
- Indentation errors
- Invalid YAML syntax
- Duplicate keys
- Trailing whitespace
- Line length violations
- Missing colons or quotes

**Best Practices:**
- Always run yamllint before ansible-lint
- Use 2-space indentation consistently
- Configure yamllint rules in `.yamllint`
- Fix YAML syntax errors first, then Ansible-specific issues

### 2. Ansible Lint

**Purpose:** Enforce Ansible best practices and catch common errors.

**Workflow:**

```bash
# Lint a single playbook
ansible-lint playbook.yml

# Lint all playbooks in directory
ansible-lint .

# Lint with specific rules
ansible-lint -t yaml,syntax playbook.yml

# Skip specific rules
ansible-lint -x yaml[line-length] playbook.yml

# Output parseable format
ansible-lint -f pep8 playbook.yml

# Show rule details
ansible-lint -L
```

**Common Issues Detected:**
- Deprecated modules or syntax
- Missing task names
- Improper use of `command` vs `shell`
- Unquoted template expressions
- Hard-coded values that should be variables
- Missing `become` directives
- Inefficient task patterns
- Jinja2 template errors
- Incorrect variable usage
- Role dependencies issues

**Severity Levels:**
- **Error:** Must fix - will cause failures
- **Warning:** Should fix - potential issues
- **Info:** Consider fixing - best practice violations

**Auto-fix approach:**
- ansible-lint supports `--fix` for auto-fixable issues
- Always review changes before applying
- Some issues require manual intervention

### 3. Security Scanning (Checkov)

**Purpose:** Identify security vulnerabilities and compliance violations in Ansible code using Checkov, a static code analysis tool for infrastructure-as-code.

**What Checkov Provides Beyond ansible-lint:**

While ansible-lint focuses on code quality and best practices, Checkov specifically targets security policies and compliance:

- **SSL/TLS Security:** Certificate validation enforcement
- **HTTPS Enforcement:** Ensures secure protocols for downloads
- **Package Security:** GPG signature verification for packages
- **Cloud Security:** AWS, Azure, GCP misconfiguration detection
- **Compliance Frameworks:** Maps to security standards
- **Network Security:** Firewall and network policy validation

**Workflow:**

```bash
# Scan playbook for security issues
bash scripts/validate_playbook_security.sh playbook.yml

# Scan entire directory
bash scripts/validate_playbook_security.sh /path/to/playbooks/

# Scan role for security issues
bash scripts/validate_role_security.sh roles/webserver/

# Direct checkov usage
checkov -d . --framework ansible

# Scan with specific output format
checkov -d . --framework ansible --output json

# Scan and skip specific checks
checkov -d . --framework ansible --skip-check CKV_ANSIBLE_1
```

**Common Security Issues Detected:**

**Certificate Validation:**
- **CKV_ANSIBLE_1:** URI module disabling certificate validation
- **CKV_ANSIBLE_2:** get_url disabling certificate validation
- **CKV_ANSIBLE_3:** yum disabling certificate validation
- **CKV_ANSIBLE_4:** yum disabling SSL verification

**HTTPS Enforcement:**
- **CKV2_ANSIBLE_1:** URI module using HTTP instead of HTTPS
- **CKV2_ANSIBLE_2:** get_url using HTTP instead of HTTPS

**Package Security:**
- **CKV_ANSIBLE_5:** apt installing packages without GPG signature
- **CKV_ANSIBLE_6:** apt using force parameter bypassing signatures
- *
- *CKV2_ANSIBLE_4:** dnf installing packages without GPG signature
- **CKV2_ANSIBLE_5:** dnf disabling SSL verification
- **CKV2_ANSIBLE_6:** dnf disabling certificate validation

**Error Handling:**
- **CKV2_ANSIBLE_3:** Block missing error handling

**Cloud Security (when managing cloud resources):**
- **CKV_AWS_88:** EC2 instances with public IPs
- **CKV_AWS_135:** EC2 instances without EBS optimization

**Example Violation:**

```yaml
# BAD - Disables certificate validation
- name: Download file
  get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    validate_certs: false  # Security issue!

# GOOD - Certificate validation enabled
- name: Download file
  get_url:
    url: https://example.com/file.tar.gz
    dest: /tmp/file.tar.gz
    validate_certs: true  # Or omit (true by default)
```
**Integration with Validation Workflow:**

Checkov complements ansible-lint:
1. **ansible-lint** catches code quality issues, deprecated modules, best practices
2. **Checkov** catches security vulnerabilities, compliance violations, cryptographic issues

**Best Practice:** Run both tools for comprehensive validation:
```bash
# Complete validation workflow
bash scripts/validate_playbook.sh playbook.yml         # Syntax + Lint
bash scripts/validate_playbook_security.sh playbook.yml  # Security
```

**Output Format:**

Checkov provides clear security scan results:
```
Security Scan Results:
  Passed:  15 checks
  Failed:  2 checks
  Skipped: 0 checks

Failed Checks:
  Check: CKV_ANSIBLE_2 - "Ensure that certificate validation isn't disabled with get_url"
    FAILED for resource: tasks/main.yml:download_file
    File: /roles/webserver/tasks/main.yml:10-15
```

**Remediation Resources:**
- Checkov Policy Index: https://www.checkov.io/5.Policy%20Index/ansible.html
- Ansible Security Checklist: `references/security_checklist.md`
- Ansible Best Practices: `references/best_practices.md`

**Installation:**

Checkov is automatically installed in a temporary environment if not available system-wide. For permanent installation:

```bash
pip3 install checkov
```

**When to Use:**
- Before deploying to production
- In CI/CD pipelines for automated security checks
- When working with sensitive infrastructure
- For compliance audits and security reviews
- When downloading files or installing packages
- When managing cloud resources with Ansible

### 4. Playbook Syntax Check

**Purpose:** Validate playbook syntax without executing tasks.

**Workflow:**

```bash
# Basic syntax check
ansible-playbook playbook.yml --syntax-check

# Syntax check with inventory
ansible-playbook -i inventory playbook.yml --syntax-check

# Syntax check with extra vars
ansible-playbook playbook.yml --syntax-check -e @vars.yml

# Check all playbooks
for file in *.yml; do
  ansible-playbook "$file" --syntax-check
done
```

**Validation Checks:**
- YAML parsing
- Playbook structure
- Task definitions
- Variable references
- Module parameter syntax
- Jinja2 template syntax
- Include/import statements

**Error Handling:**
- Parse error messages for specific issues
- Check for typos in module names
- Verify variable definitions
- Ensure proper indentation
- Check file paths for includes/imports

### 5. Dry-Run Testing (Check Mode)

**Purpose:** Preview changes that would be made without actually applying them.

**Workflow:**

```bash
# Run in check mode (dry-run)
ansible-playbook -i inventory playbook.yml --check

# Check mode with diff
ansible-playbook -i inventory playbook.yml --check --diff

# Check mode with verbose output
ansible-playbook -i inventory playbook.yml --check -v

# Check mode for specific hosts
ansible-playbook -i inventory playbook.yml --check --limit webservers

# Check mode with tags
ansible-playbook -i inventory playbook.yml --check --tags deploy

# Step through tasks
ansible-playbook -i inventory playbook.yml --check --step
```

**Check Mode Analysis:**

When reviewing check mode output, focus on:

1. **Task Changes:**
   - `ok`: No changes needed
   - `changed`: Would make changes
   - `failed`: Would fail (check for check_mode support)
   - `skipped`: Conditional skip

2. **Diff Output:**
   - Shows exact changes to files
   - Helps identify unintended modifications
   - Useful for reviewing template changes

3. **Handlers:**
   - Which handlers would be notified
   - Service restarts that would occur
   - Potential downtime

4. **Failed Tasks:**
   - Some modules don't support check mode
   - May need `check_mode: no` override
   - Identify tasks that would fail

**Limitations:**
- Not all modules support check mode
- Some tasks depend on previous changes
- May not accurately reflect all changes
- Stateful operations may show unexpected results

**Safety Considerations:**
- Always run check mode before real execution
- Review diff output carefully
- Test in non-production first
- Validate changes make sense
- Check for unintended side effects

### 6. Molecule Testing

**Purpose:** Test Ansible roles in isolated environments with multiple scenarios.

**AUTOMATIC EXECUTION:** When validating any Ansible role with a `molecule/` directory, this skill AUTOMATICALLY runs molecule tests using `bash scripts/test_role.sh <role-path>`. This is mandatory and happens without asking the user.

**When to Use:**
- Automatically triggered when validating roles with molecule/ directory
- Testing roles before deployment
- Validating role compatibility across different OS versions
- Integration testing for complex roles
- CI/CD pipeline validation

**Workflow:**

```bash
# Initialize molecule for a role
cd roles/myrole
molecule init scenario --driver-name docker

# List scenarios
molecule list

# Run full test sequence
molecule test

# Individual test stages
molecule create      # Create test instances
molecule converge    # Run Ansible against instances
molecule verify      # Run verification tests
molecule destroy     # Destroy test instances

# Test with specific scenario
molecule test -s alternative

# Debug mode
molecule --debug test

# Keep instances for debugging
molecule converge
molecule login       # SSH into test instance
```

**Test Sequence:**
1. `dependency` - Install role dependencies
2. `lint` - Run yamllint and ansible-lint
3. `cleanup` - Clean up before testing
4. `destroy` - Destroy existing instances
5. `syntax` - Run syntax check
6. `create` - Create test instances
7. `prepare` - Prepare instances (install requirements)
8. `converge` - Run the role
9. `idempotence` - Run again, verify no changes
10. `side_effect` - Optional side effect playbook
11. `verify` - Run verification tests (Testinfra, etc.)
12. `cleanup` - Final cleanup
13. `destroy` - Destroy test instances

**Molecule Configuration:**

Check `molecule/default/molecule.yml`:
```yaml
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: ubuntu:22.04
provisioner:
  name: ansible
verifier:
  name: ansible
```

**Verification Tests:**

Molecule supports multiple verifiers:
- **Ansible** (built-in): Use Ansible tasks to verify
- **Testinfra**: Python-based infrastructure tests
- **Goss**: YAML-based server validation

Example Ansible verifier (`molecule/default/verify.yml`):
```yaml
---
- name: Verify
  hosts: all
  tasks:
    - name: Check service is running
      service:
        name: nginx
        state: started
      check_mode: true
      register: result
      failed_when: result.changed
```

**Common Molecule Errors:**
- Driver not installed (docker, podman, vagrant)
- Missing Python dependencies
- Platform image not available
- Network connectivity issues
- Insufficient permissions for driver

### 7. Custom Module and Collection Documentation Lookup

**Purpose:** Automatically discover and retrieve version-specific documentation for custom modules and collections using web search and Context7 MCP.

**When to Trigger:**
- Encountering unfamiliar module usage
- Working with custom/private collections
- Debugging module-specific errors
- Understanding new module parameters
- Checking version compatibility
- Deprecated module alternatives

**Detection Workflow:**

1. **Extract Module Information:**
   - Use `scripts/extract_ansible_info_wrapper.sh` to parse playbooks and roles
   - Identify module usage and collections
   - Extract version constraints from `requirements.yml`

2. **Extract Collection Information:**
   - Identify collection namespaces (e.g., `community.general`, `ansible.posix`)
   - Determine collection versions from `requirements.yml` or `galaxy.yml`
   - Detect custom/private vs. public collections

**Documentation Lookup Strategy:**

For **Public Ansible Collections** (e.g., community.general, ansible.posix, cisco.ios):

```bash
# Use Context7 MCP to get version-specific documentation
# Example: community.general collection version 5.0
```

Steps:
1. Use `mcp__context7__resolve-library-id` with collection name
2. Get documentation with `mcp__context7__get-library-docs`
3. Focus on specific modules or plugins as needed

For **Custom/Private Modules or Collections:**

```bash
# Use WebSearch to find documentation
# Include version in search query
```

Steps:
1. Construct search query with module/collection name + version
2. Use `WebSearch` tool with targeted queries
3. Prioritize official documentation sources
4. Extract relevant examples and usage patterns

**Search Query Templates:**

```
# For custom modules
"[module-name] ansible module version [version] documentation"
"[module-name] ansible [module-type] example"
"ansible [collection-name].[module-name] parameters"

# For custom collections
"ansible collection [collection-name] version [version]"
"[collection-namespace].[collection-name] ansible documentation"
"ansible galaxy [collection-name] modules"

# For specific errors
"ansible [module-name] error: [error-message]"
"ansible [collection-name] module failed"
```

**Example Workflow:**

```
User working with: community.docker.docker_container version 3.0.0

1. Extract module info from playbook:
   tasks:
     - name: Start container
       community.docker.docker_container:
         name: myapp
         image: nginx:latest

2. Detect collection: community.docker

3. Search for documentation:
   - Try Context7: mcp__context7__resolve-library-id("ansible community.docker")
   - Fallback to WebSearch("ansible community.docker collection version 3.0 docker_container module documentation")

4. If official docs found:
   - Parse module parameters (required vs optional)
   - Identify return values
   - Find usage examples
   - Check version compatibility

5. Provide version-specific guidance to user
```

**Version Compatibility Checks:**

- Compare required collection versions with available versions
- Identify deprecated modules or parameters
- Suggest upgrade paths if using outdated versions
- Warn about breaking changes between versions
- Check Ansible core version compatibility

**Common Collection Sources:**
- **Ansible Galaxy**: Official community collections
- **Red Hat Automation Hub**: Certified collections
- **GitHub**: Custom/private collections
- **Internal repositories**: Company-specific collections

### 8. Security and Best Practices Validation

**Purpose:** Identify security vulnerabilities and anti-patterns in Ansible playbooks.

**Security Checks:**

1. **Secrets Detection:**
   ```bash
   # Check for hardcoded credentials
   grep -r "password:" *.yml
   grep -r "secret:" *.yml
   grep -r "api_key:" *.yml
   grep -r "token:" *.yml
   ```

   **Remediation:** Use Ansible Vault, environment variables, or external secret management

2. **Privilege Escalation:**
   - Unnecessary use of `become: yes`
   - Missing `become_user` specification
   - Over-permissive sudo rules
   - Running entire playbooks as root

3. **File Permissions:**
   - World-readable sensitive files
   - Missing mode parameter on file/template tasks
   - Incorrect ownership settings
   - Sensitive files not encrypted with vault

4. **Command Injection:**
   - Unvalidated variables in shell/command modules
   - Missing `quote` filter for user input
   - Direct use of {{ var }} in command strings

5. **Network Security:**
   - Unencrypted protocols (HTTP instead of HTTPS)
   - Missing SSL/TLS validation
   - Exposing services on 0.0.0.0
   - Insecure default ports

**Best Practices:**

1. **Playbook Organization:**
   - Logical task separation
   - Reusable roles for common patterns
   - Clear directory structure
   - Meaningful playbook names

2. **Variable Management:**
   - Vault encryption for sensitive data
   - Clear variable naming conventions
   - Variable precedence awareness
   - Group/host vars organization
   - Default values using `default()` filter

3. **Task Naming:**
   - Descriptive task names
   - Consistent naming convention
   - Action-oriented descriptions
   - Include changed resource in name

4. **Idempotency:**
   - All tasks should be idempotent
   - Use proper modules instead of command/shell
   - Check mode compatibility
   - Proper use of `creates`, `removes` for command tasks
   - Avoid `changed_when: false` unless necessary

5. **Error Handling:**
   - Use `failed_when` for custom failure conditions
   - Implement `block/rescue/always` for error recovery
   - Set appropriate `any_errors_fatal`
   - Use `ignore_errors` sparingly

6. **Documentation:**
   - README for each role
   - Variable documentation in defaults/main.yml
   - Role metadata in meta/main.yml
   - Playbook header comments

**Reference Documentation:**

For detailed security guidelines and best practices, refer to:
- `references/security_checklist.md` - Common security vulnerabilities
- `references/best_practices.md` - Ansible coding standards
- `references/common_errors.md` - Common errors and solutions

## Tool Prerequisites

Check for required tools before validation:

```bash
# Check Ansible installation
ansible --version
ansible-playbook --version

# Check ansible-lint installation
ansible-lint --version

# Check yamllint installation
yamllint --version

# Check molecule installation (for role testing)
molecule --version

# Install missing tools (example for pip)
pip install ansible ansible-lint yamllint ansible-compat

# Install molecule with docker driver
pip install molecule molecule-docker
```

**Minimum Versions:**
- Ansible: >= 2.9 (recommend >= 2.12)
- ansible-lint: >= 6.0.0
- yamllint: >= 1.26.0
- molecule: >= 3.4.0 (if testing roles)

**Optional Tools:**
- `ansible-inventory` - Inventory validation and graphing
- `ansible-doc` - Module documentation lookup
- `jq` - JSON parsing for structured output

## Error Troubleshooting

### Common Errors and Solutions

**Error: Module Not Found**
```
Solution: Install required collection with ansible-galaxy
Check collections/requirements.yml
Verify collection namespace and name
```

**Error: Undefined Variable**
```
Solution: Define variable in vars, defaults, or group_vars
Check variable precedence
Use default() filter for optional variables
Verify variable file is included
```

**Error: Template Syntax Error**
```
Solution: Check Jinja2 template syntax
Verify variable types match filters
Ensure proper quote escaping
Test template rendering separately
```

**Error: Connection Failed**
```
Solution: Verify inventory host accessibility
Check SSH configuration and keys
Verify ansible_host and ansible_port
Test with ansible -m ping
```

**Error: Permission Denied**
```
Solution: Add become: yes for privilege escalation
Verify sudo/su configuration
Check file permissions
Verify user has necessary privileges
```

**Error: Deprecated Module**
```
Solution: Check ansible-lint output for replacement
Consult module documentation for alternatives
Update to recommended module
Test functionality with new module
```

## Resources

### scripts/

**setup_tools.sh** - Check for required Ansible validation tools and provide installation instructions.

Usage:
```bash
bash scripts/setup_tools.sh
```

**extract_ansible_info_wrapper.sh** - Bash wrapper for extract_ansible_info.py that automatically handles PyYAML dependencies. Creates a temporary venv if PyYAML is not available in system Python.

Usage:
```bash
bash scripts/extract_ansible_info_wrapper.sh <path-to-playbook-or-role>
```

Output: JSON structure with modules, collections, and versions

**extract_ansible_info.py** - Python script (called by wrapper) to parse Ansible playbooks and roles to extract module usage, collection dependencies, and version information. The wrapper script handles dependency management automatically.

**validate_playbook.sh** - Comprehensive validation script that runs syntax check, yamllint, and ansible-lint on playbooks. Automatically installs ansible and ansible-lint in a temporary venv if not available on the system (prefers system versions when available).

Usage:
```bash
bash scripts/validate_playbook.sh <playbook.yml>
```

**validate_playbook_security.sh** - Security validation script that scans playbooks for security vulnerabilities using Checkov. Automatically installs checkov in a temporary venv if not available. Complements validate_playbook.sh by focusing on security-specific checks like SSL/TLS validation, HTTPS enforcement, and package signature verification.

Usage:
```bash
bash scripts/validate_playbook_security.sh <playbook.yml>
# Or scan entire directory
bash scripts/validate_playbook_security.sh /path/to/playbooks/
```

**validate_role.sh** - Comprehensive role validation script that checks role structure, YAML syntax, Ansible syntax, linting, and molecule configuration.

Usage:
```bash
bash scripts/validate_role.sh <role-directory>
```

Validates:
- Role directory structure (required and recommended directories)
- Presence of main.yml files in each directory
- YAML syntax across all role files
- Ansible syntax using a test playbook
- Best practices with ansible-lint
- Molecule test configuration

**validate_role_security.sh** - Security validation script for Ansible roles using Checkov. Scans entire role directory for security issues. Automatically installs checkov in a temporary venv if not available. Complements validate_role.sh with security-focused checks.

Usage:
```bash
bash scripts/validate_role_security.sh <role-directory>
```

**test_role.sh** - Wrapper script for molecule testing with automatic dependency installation. If molecule is not installed, automatically creates a temporary venv, installs molecule and dependencies, runs tests, and cleans up.

Usage:
```bash
bash scripts/test_role.sh <role-directory> [scenario]
```

**scan_secrets.sh** - Comprehensive secret scanner that uses grep-based pattern matching to detect hardcoded secrets in Ansible files. Complements Checkov security scanning by catching secrets that static analysis may miss, including passwords, API keys, tokens, AWS credentials, and private keys.

Usage:
```bash
bash scripts/scan_secrets.sh <playbook.yml|role-directory|directory>
```

Detects:
- Hardcoded passwords and credentials
- API keys and tokens
- AWS access keys and secret keys
- Database connection strings with embedded credentials
- Private key content (RSA, OpenSSH, EC, DSA)

**IMPORTANT:** This script should ALWAYS be run alongside Checkov (`validate_*_security.sh`) for comprehensive security scanning. Checkov catches SSL/TLS and protocol issues; this script catches hardcoded secrets.

**check_fqcn.sh** - Scans Ansible files to identify modules using short names instead of Fully Qualified Collection Names (FQCN). Recommends migration to `ansible.builtin.*` or appropriate collection namespace for better clarity and future compatibility.

Usage:
```bash
bash scripts/check_fqcn.sh <playbook.yml|role-directory|directory>
```

Detects:
- ansible.builtin modules (apt, yum, copy, file, template, service, etc.)
- community.general modules (ufw, docker_container, timezone, etc.)
- ansible.posix modules (synchronize, acl, firewalld, etc.)

Provides specific migration recommendations with FQCN alternatives.

### references/

**security_checklist.md** - Comprehensive security validation checklist for Ansible playbooks covering secrets management, privilege escalation, file permissions, and command injection.

**best_practices.md** - Ansible coding standards and best practices for playbook organization, variable handling, task naming, idempotency, and documentation.

**common_errors.md** - Database of common Ansible errors with detailed solutions and prevention strategies.

**module_alternatives.md** - Guide for replacing deprecated modules with current alternatives.

### assets/

**.yamllint** - Pre-configured yamllint rules for Ansible YAML files.

**.ansible-lint** - Pre-configured ansible-lint configuration with reasonable rule settings.

**molecule.yml.template** - Template molecule configuration for role testing.

## Workflow Examples

### Example 1: Validate a Single Playbook

```
User: "Check if this playbook.yml file is valid"

Steps:
1. Read the file to understand contents
2. Run yamllint on the file
3. Run ansible-playbook --syntax-check
4. Run ansible-lint
5. Report any issues found
6. If custom modules detected, lookup documentation
7. Propose fixes if needed
```

### Example 2: Validate an Ansible Role

```
User: "Validate my ansible role in ./roles/webserver/"

Steps:
1. Run bash scripts/validate_role.sh ./roles/webserver/
2. This automatically checks:
   - Role directory structure (tasks/, defaults/, handlers/, meta/, etc.)
   - Required main.yml files
   - YAML syntax with yamllint
   - Ansible syntax with ansible-playbook
   - Best practices with ansible-lint
   - Molecule configuration (if present)
3. Report any issues found (errors and warnings)
4. If custom modules detected, lookup documentation
5. Provide specific recommendations for fixes
6. **CRITICAL:** If molecule/ directory exists in the role, AUTOMATICALLY run molecule tests:
   - Run bash scripts/test_role.sh ./roles/webserver/
   - Do NOT ask user first - molecule testing is mandatory for roles that have it configured
   - Report test results (pass/fail with details)
   - If tests fail due to environmental issues (Docker, compatibility), document the blocker
   - If tests fail due to role issues, provide detailed debugging steps
```

### Example 3: Dry-Run Testing for Production

```
User: "Run playbook in check mode for production servers"

Steps:
1. Verify inventory file exists
2. Run ansible-playbook --check --diff -i production
3. Analyze check mode output
4. Highlight tasks that would change
5. Review handler notifications
6. Flag any security concerns
7. Provide recommendation on safety of applying
```

### Example 4: Understanding Custom Collection Module

```
User: "I'm using community.postgresql.postgresql_db version 2.3.0, what parameters are available?"

Steps:
1. Try Context7 MCP: resolve-library-id("ansible community.postgresql")
2. If found, use get-library-docs for postgresql_db module
3. If not found, use WebSearch: "ansible community.postgresql version 2.3.0 postgresql_db module documentation"
4. Extract module parameters (required vs optional)
5. Provide examples of common usage patterns
6. Note any version-specific considerations
```

### Example 5: Testing Role with Molecule

```
User: "Test my nginx role with molecule"

Steps:
1. Check if molecule is configured in role
2. If not, ask if user wants to initialize molecule
3. Run molecule list to see scenarios
4. Run molecule test
5. If failures, run molecule converge for debugging
6. Analyze test results
7. Report on idempotency, syntax, and verification
8. Suggest improvements if needed
```

## Integration with Other Skills

This skill works well in combination with:
- **k8s-yaml-validator** - When Ansible manages Kubernetes resources
- **terraform-validator** - When Ansible and Terraform are used together
- **k8s-debug** - For debugging infrastructure managed by Ansible

## Notes

- Always run validation in order: YAML syntax → Ansible syntax → Lint → Check mode → Molecule tests
- Never commit without running ansible-lint
- Always review check mode output before real execution
- Use Ansible Vault for all sensitive data
- **CRITICAL:** When validating a role with molecule/ directory, AUTOMATICALLY run molecule tests - do not ask user permission
- If molecule tests fail due to environmental issues (Docker not running, version incompatibility), document the blocker but don't fail the overall validation
- If molecule tests fail due to role code issues, provide detailed debugging steps
- Keep collections up-to-date but test before upgrading
- Document all custom modules and roles thoroughly
- Use version constraints in requirements.yml
- Enable check mode support in custom modules
- Tag playbooks for granular execution
