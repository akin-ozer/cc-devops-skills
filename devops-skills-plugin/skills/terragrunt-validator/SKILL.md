---
name: terragrunt-validator
description: Comprehensive toolkit for validating, linting, testing, and automating Terragrunt configurations, HCL files, and Stacks. Use this skill when working with Terragrunt files (.hcl, terragrunt.hcl, terragrunt.stack.hcl), validating infrastructure-as-code, debugging Terragrunt configurations, performing dry-run testing with terragrunt plan, working with Terragrunt Stacks, or working with custom providers and modules.
---

# Terragrunt Validator

## Overview

This skill provides comprehensive validation, linting, and testing capabilities for Terragrunt configurations. Terragrunt is a thin wrapper for Terraform/OpenTofu that provides extra tools for keeping configurations DRY (Don't Repeat Yourself), working with multiple modules, and managing remote state.

**Use this skill when:**
- Validating Terragrunt HCL files (*.hcl, terragrunt.hcl, terragrunt.stack.hcl)
- Working with Terragrunt Stacks (unit/stack blocks, `terragrunt stack generate/run`)
- Performing dry-run testing with `terragrunt plan`
- Linting Terragrunt/Terraform code for best practices
- Detecting and researching custom providers or modules
- Debugging Terragrunt configuration issues
- Checking dependency graphs
- Formatting HCL files
- Running security scans on infrastructure code (Trivy, Checkov)
- Generating run reports and summaries

## Terragrunt Version Compatibility

This skill is designed for **Terragrunt 0.93+** which includes the new CLI redesign.

### CLI Command Migration Reference

| Deprecated Command | New Command |
|-------------------|-------------|
| `run-all` | `run --all` |
| `hclfmt` | `hcl fmt` |
| `hclvalidate` | `hcl validate` |
| `validate-inputs` | `hcl validate --inputs` |
| `graph-dependencies` | `dag graph` |
| `render-json` | `render --json -w` |
| `terragrunt-info` | `info print` |
| `plan-all`, `apply-all` | `run --all plan`, `run --all apply` |

### Key Changes in 0.93+:
- `terragrunt run --all` replaces `terragrunt run-all` for multi-module operations
- `terragrunt dag graph` replaces `terragrunt graph-dependencies` for dependency visualization
- `terragrunt hcl validate --inputs` replaces `validate-inputs` for input validation
- HCL syntax validation via `terragrunt hcl fmt --check` or `terragrunt hcl validate`
- Full validation requires `terragrunt init && terragrunt validate`

If using an older Terragrunt version, some commands may need adjustment.

## Core Capabilities

### 1. Comprehensive Validation Suite

Run the comprehensive validation script to perform all checks at once:

```bash
bash scripts/validate_terragrunt.sh [TARGET_DIR]
```

**What it validates:**
- HCL formatting (`terragrunt hcl fmt --check`)
- HCL input validation (`terragrunt hcl validate --inputs`)
- Terragrunt configuration syntax
- Terraform configuration validation
- Linting with tflint
- Security scanning with Trivy (or legacy tfsec)
- Dependency graph validation
- Dry-run planning

**Environment variables:**
- `SKIP_PLAN=true` - Skip terragrunt plan step
- `SKIP_SECURITY=true` - Skip security scanning (Trivy/tfsec)
- `SKIP_LINT=true` - Skip tflint linting
- `TG_STRICT_MODE=true` - Enable strict mode (errors on deprecated features)

**Example usage:**
```bash
# Full validation
bash scripts/validate_terragrunt.sh ./infrastructure/prod

# Skip plan generation (faster)
SKIP_PLAN=true bash scripts/validate_terragrunt.sh ./infrastructure

# Only validate, skip linting and security
SKIP_LINT=true SKIP_SECURITY=true bash scripts/validate_terragrunt.sh
```

### 2. Custom Provider and Module Detection

Use the detection script to identify custom providers and modules that may require documentation lookup:

```bash
python3 scripts/detect_custom_resources.py [DIRECTORY] [--format text|json]
```

**What it detects:**
- Custom Terraform providers (non-HashiCorp)
- Remote modules (Git, Terraform Registry, HTTP)
- Provider versions
- Module versions and sources

**Output formats:**
- `text` - Human-readable report with search recommendations
- `json` - Machine-readable format for automation

**When custom resources are detected:**

> **CRITICAL: You MUST look up documentation for EVERY detected custom resource (both providers AND modules). Do NOT skip any. This is mandatory, not optional.**

1. **For custom providers:**
   - **Option A - WebSearch:** Search for provider documentation
     - Query format: `"{provider_source} terraform provider documentation version {version}"`
     - Example: `"mongodb/mongodbatlas terraform provider documentation version 1.14.0"`
   - **Option B - Context7 MCP (Preferred):** Use Context7 for structured documentation lookup
     - Step 1: Resolve library ID: `mcp__context7__resolve-library-id` with provider name (e.g., "datadog terraform provider")
     - Step 2: **REQUIRED** - Fetch documentation: `mcp__context7__get-library-docs` with the resolved library ID
     - Use `topic: "authentication"` or `topic: "configuration"` for targeted docs

2. **For custom modules (EQUALLY IMPORTANT - DO NOT SKIP):**
   - **Terraform Registry modules:**
     - Use Context7: `mcp__context7__resolve-library-id` with module name (e.g., "terraform-aws-modules vpc")
     - Then fetch docs with `mcp__context7__get-library-docs`
     - Or visit `https://registry.terraform.io/modules/{source}/{version}`
   - **Git modules:** Use WebSearch with the repository URL to find README or documentation
   - **HTTP modules:** Investigate the source URL for documentation
   - Pay attention to version compatibility with your Terraform/Terragrunt version

3. **Documentation lookup workflow (MANDATORY for ALL detected resources):**
   ```
   a) Run detect_custom_resources.py
   b) For EACH custom provider/module:
      - Note the exact version
      - Use Context7 MCP:
        1. mcp__context7__resolve-library-id with libraryName: "{provider/module name}"
        2. mcp__context7__get-library-docs with:
           - context7CompatibleLibraryID: "{resolved ID}"
           - topic: "authentication" (for auth requirements)
           - topic: "configuration" (for setup requirements)
      - OR use WebSearch with version-specific queries
      - Review documentation for:
        * Required configuration blocks
        * Authentication requirements (API keys, credentials)
        * Available resources/data sources
        * Known issues or breaking changes in the version
   c) Apply learnings to validation/troubleshooting
   d) Document findings if issues are encountered
   ```

**Example using Context7 MCP:**
```
# 1. Detect custom resources
python3 scripts/detect_custom_resources.py ./infrastructure
# Output: Provider: datadog/datadog, Version: 3.30.0

# 2. Resolve library ID
mcp__context7__resolve-library-id with libraryName: "datadog terraform provider"
# Result: /datadog/terraform-provider-datadog

# 3. Fetch authentication docs (REQUIRED)
mcp__context7__get-library-docs with:
  context7CompatibleLibraryID: "/datadog/terraform-provider-datadog"
  topic: "authentication"

# 4. Fetch configuration docs
mcp__context7__get-library-docs with:
  context7CompatibleLibraryID: "/datadog/terraform-provider-datadog"
  topic: "configuration"
```

**Example using WebSearch:**
```bash
# Detect custom resources
python3 scripts/detect_custom_resources.py ./infrastructure

# Then search for documentation:
# WebSearch: "datadog terraform provider 3.30.0 authentication configuration"
# WebSearch: "datadog terraform provider api_key app_key setup"
```

### 3. Step-by-Step Validation

For manual or granular validation, use these individual commands:

#### Format Validation
```bash
cd <target-directory>
terragrunt hcl fmt --check

# To auto-fix formatting
terragrunt hcl fmt
```

#### Configuration Validation
```bash
# Check HCL syntax and formatting
terragrunt hcl fmt --check

# Note: In Terragrunt 0.93+, for deeper configuration validation,
# initialize and validate (requires actual resources/credentials):
# terragrunt init && terragrunt validate
```

#### Terraform Validation
```bash
# Initialize if needed
terragrunt init

# Validate
terragrunt validate
```

#### Linting with tflint
```bash
# Initialize tflint (if .tflint.hcl exists)
tflint --init

# Run linting
tflint --recursive
```

#### Security Scanning with Trivy (Recommended)

> **Note:** tfsec has been merged into Trivy and is no longer actively maintained.
> Use Trivy for all new projects.

```bash
# Using Trivy (recommended)
trivy config . --severity HIGH,CRITICAL

# With tfvars file
trivy config --tf-vars terraform.tfvars .

# Exclude downloaded modules
trivy config --tf-exclude-downloaded-modules .

# Legacy: Using tfsec (deprecated)
tfsec . --soft-fail
```

#### Alternative: Security Scanning with Checkov
```bash
# Scan directory
checkov -d . --framework terraform

# Scan with specific checks
checkov -d . --check CKV_AWS_21

# Output as JSON
checkov -d . --output json
```

#### Dependency Graph Validation
```bash
# Note: graph-dependencies command replaced with 'dag graph' in Terragrunt 0.93+
# Validate and display dependency graph
terragrunt dag graph

# Visualize dependencies (requires graphviz)
terragrunt dag graph | dot -Tpng > dependencies.png
```

#### Dry-Run Planning
```bash
# Single module
terragrunt plan

# All modules (new syntax - Terragrunt 0.93+)
terragrunt run --all plan

# Legacy syntax (deprecated)
# terragrunt run-all plan
```

### 4. Multi-Module Operations

For projects with multiple Terragrunt modules, use `run --all` (replaces deprecated `run-all`):

```bash
# Validate all modules
terragrunt run --all validate

# Plan all modules
terragrunt run --all plan

# Apply all modules
terragrunt run --all apply

# Destroy all modules
terragrunt run --all destroy

# Format all HCL files
terragrunt hcl fmt

# With parallelism
terragrunt run --all plan --parallelism 4

# With strict mode (errors on deprecated features)
terragrunt --strict-mode run --all plan

# Or via environment variable
TG_STRICT_MODE=true terragrunt run --all plan
```

### 5. HCL Input Validation (New in 0.93+)

Validate that all required inputs are set and no unused inputs exist:

```bash
# Validate inputs
terragrunt hcl validate --inputs

# Show paths of invalid files
terragrunt hcl validate --show-config-path

# Combine with run --all to exclude invalid files
terragrunt run --all plan --queue-excludes-file <(terragrunt hcl validate --show-config-path || true)
```

### 6. Strict Mode

Enable strict mode to catch deprecated features early:

```bash
# Via CLI flag
terragrunt --strict-mode run --all plan

# Via environment variable (recommended for CI/CD)
export TG_STRICT_MODE=true
terragrunt run --all plan

# Check available strict controls
terragrunt info strict
```

**Specific Strict Controls:**

For finer-grained control, use `--strict-control` to enable specific controls:

```bash
# Enable specific strict controls
terragrunt run --all plan --strict-control cli-redesign --strict-control deprecated-commands

# Via environment variable (comma-separated)
TG_STRICT_CONTROL='cli-redesign,deprecated-commands' terragrunt run --all plan

# Available strict controls:
# - cli-redesign: Errors on deprecated CLI syntax
# - deprecated-commands: Errors on deprecated commands (run-all, hclfmt, etc.)
# - root-terragrunt-hcl: Errors when using root terragrunt.hcl (use root.hcl instead)
# - skip-dependencies-inputs: Improves performance by not reading dependency inputs
# - bare-include: Errors on bare include blocks (use named includes)
```

### 7. New CLI Commands (0.93+)

#### Render Configuration
```bash
# Render configuration to JSON
terragrunt render --json

# Render and write to file
terragrunt render --json --write

# Output goes to terragrunt.rendered.json
```

#### Info Print (replaces terragrunt-info)
```bash
# Get contextual information about current configuration
terragrunt info print

# Output includes:
# - config_path
# - download_dir
# - terraform_binary
# - working_dir
```

#### Find and List Units
```bash
# Find all units/stacks in directory
terragrunt find

# Output as JSON
terragrunt find --json

# Include dependency information
terragrunt find --json --dag

# List units (simpler output)
terragrunt list
```

#### Run Summary and Reports
```bash
# Run with summary output (default in newer versions)
terragrunt run --all plan

# Disable summary output
terragrunt run --all plan --summary-disable

# Generate detailed report file
terragrunt run --all plan --report-file=report.json

# CSV format report
terragrunt run --all plan --report-file=report.csv
```

### 8. Terragrunt Stacks (GA in v0.78.0+)

Terragrunt Stacks provide declarative infrastructure generation using `terragrunt.stack.hcl` files.

#### Stack File Structure
```hcl
# terragrunt.stack.hcl
locals {
  environment = "dev"
  aws_region  = "us-east-1"
}

# Define a unit (generates a single terragrunt.hcl)
unit "vpc" {
  source = "git::git@github.com:acme/infra-catalog.git//units/vpc?ref=v0.0.1"
  path   = "vpc"

  values = {
    environment = local.environment
    cidr        = "10.0.0.0/16"
  }
}

unit "database" {
  source = "git::git@github.com:acme/infra-catalog.git//units/database?ref=v0.0.1"
  path   = "database"

  values = {
    environment = local.environment
    vpc_path    = "../vpc"
  }
}

# Include reusable stacks
stack "monitoring" {
  source = "git::git@github.com:acme/infra-catalog.git//stacks/monitoring?ref=v0.0.1"
  path   = "monitoring"

  values = {
    environment = local.environment
  }
}
```

#### Stack Commands
```bash
# Generate stack (creates .terragrunt-stack directory)
terragrunt stack generate

# Generate stack without validation
terragrunt stack generate --no-stack-validate

# Run command on all stack units
terragrunt stack run plan
terragrunt stack run apply

# Clean generated stack directories
terragrunt stack clean

# Get stack outputs
terragrunt stack output
```

#### Stack Validation Control

Use `no_validation` attribute to skip validation for specific units:

```hcl
unit "experimental" {
  source = "git::git@github.com:acme/infra-catalog.git//units/experimental?ref=v0.0.1"
  path   = "experimental"

  # Skip validation for this unit (useful for incomplete/experimental units)
  no_validation = true

  values = {
    environment = local.environment
  }
}
```

#### Benefits of Stacks
- **Clean working directory**: Generated code in hidden `.terragrunt-stack` directory
- **Reusable patterns**: Define infrastructure patterns once, deploy many times
- **Version pinning**: Different environments can pin different versions
- **Atomic updates**: Easy rollbacks of both modules and configurations

### 9. Exec Command (Run Arbitrary Programs)

The `exec` command allows you to run arbitrary programs against units with Terragrunt context. This is useful for integrating other tools like tflint, checkov, or AWS CLI with Terragrunt's configuration.

```bash
# Run tflint with unit context (TF_VAR_ env vars available)
terragrunt exec -- tflint

# Run checkov against specific unit
terragrunt exec -- checkov -d .

# Run AWS CLI with unit's configuration
terragrunt exec -- aws s3 ls s3://my-bucket

# Run custom scripts with Terragrunt context
terragrunt exec -- ./scripts/validate.sh

# Run across all units
terragrunt run --all exec -- tflint
```

**Key Features:**
- Terragrunt loads the inputs for the unit and makes them available as `TF_VAR_` prefixed environment variables
- Works with any program that can use environment variables
- Integrates with Terragrunt's authentication context (e.g., AWS profiles)
- Can be combined with `run --all` for multi-unit operations

**Use Cases:**
- Running security scanners (checkov, trivy) with unit context
- Executing linters (tflint) per unit
- Running operational commands (AWS CLI) with correct credentials
- Custom validation scripts that need Terragrunt inputs

### 10. Feature Flags (Production Feature)

Terragrunt supports first-class Feature Flags for safe infrastructure changes. Feature flags allow you to integrate incomplete work without risk, decouple release from deployment, and codify IaC evolution.

#### Defining Feature Flags

```hcl
# terragrunt.hcl
feature "enable_monitoring" {
  default = false
}

feature "use_new_vpc" {
  default = true
}

inputs = {
  monitoring_enabled = feature.enable_monitoring.value
  vpc_version       = feature.use_new_vpc.value ? "v2" : "v1"
}
```

#### Using Feature Flags via CLI

```bash
# Enable a feature flag
terragrunt plan --feature enable_monitoring=true

# Enable multiple feature flags
terragrunt plan --feature enable_monitoring=true --feature use_new_vpc=false

# Via environment variable
TG_FEATURE='enable_monitoring=true' terragrunt plan
```

#### Feature Flags with run --all

```bash
# Apply feature flag across all units
terragrunt run --all plan --feature enable_monitoring=true
```

**Benefits:**
- **Safe rollouts**: Test changes on subset of infrastructure
- **Gradual migrations**: Enable new features incrementally
- **A/B testing**: Compare infrastructure configurations
- **Emergency rollbacks**: Quickly disable problematic features

### 11. Experiments (Opt-in Unstable Features)

Terragrunt provides an experiments system for trying unstable features before they're GA:

```bash
# Enable all experiments (not recommended for production)
terragrunt --experiment-mode run --all plan

# Enable specific experiment
terragrunt --experiment symlinks run --all plan

# Enable CAS (Content Addressable Storage) for faster cloning
terragrunt --experiment cas run --all plan
```

**Available Experiments:**
- `symlinks` - Support symlink resolution for Terragrunt units
- `cas` - Content Addressable Storage for faster Git/module cloning
- `filter-flag` - Advanced filtering capabilities (coming in 1.0)

## Validation Workflow

Follow this workflow when validating Terragrunt configurations:

### Step 0: Read Best Practices Reference (MANDATORY FIRST STEP)

> **You MUST read the best practices reference file BEFORE starting validation. This is not optional.**

```bash
# Read the best practices reference file first
cat references/best_practices.md
```

This ensures you understand the patterns, anti-patterns, and checklists you will verify.

### Initial Assessment

1. **Understand the structure:**
   ```bash
   tree -L 3 <infrastructure-directory>
   ```

2. **Identify Terragrunt files:**
   ```bash
   find . -name "*.hcl" -o -name "terragrunt.hcl"
   ```

3. **Detect custom resources:**
   ```bash
   python3 scripts/detect_custom_resources.py .
   ```

### Documentation Lookup (MANDATORY for ALL detected custom resources)

> **CRITICAL: If ANY custom providers or modules are detected, you MUST look up documentation for EACH ONE. Do not skip any.**

4. **For EACH detected custom provider - look up documentation:**
   - Use Context7 MCP (preferred):
     1. `mcp__context7__resolve-library-id` with provider name
     2. `mcp__context7__get-library-docs` with topic: "authentication"
     3. `mcp__context7__get-library-docs` with topic: "configuration"
   - OR use WebSearch: `"{provider} terraform provider {version} documentation"`

5. **For EACH detected custom module - look up documentation:**
   - Use Context7 MCP for Terraform Registry modules:
     1. `mcp__context7__resolve-library-id` with module name (e.g., "terraform-aws-modules vpc")
     2. `mcp__context7__get-library-docs` with relevant topic
   - For Git modules: Use WebSearch with repository URL
   - For HTTP modules: Investigate source URL for documentation

6. **Document findings for each resource:**
   - Required configuration blocks
   - Authentication requirements
   - Known issues or breaking changes in the version

### Validation Execution

7. **Run comprehensive validation:**
   ```bash
   bash scripts/validate_terragrunt.sh <target-directory>
   ```

8. **Review output for errors:**
   - Format errors → Fix with `terragrunt hcl fmt`
   - Configuration errors → Check terragrunt.hcl syntax and inputs
   - Terraform validation errors → Check .tf files or generated configs
   - Linting issues → Review tflint output and fix
   - Security issues → Review tfsec output and address
   - Dependency errors → Check dependency blocks and paths
   - Plan errors → Review Terraform configuration and provider setup

### Best Practices Check (REQUIRED - Must Complete All Checklists)

> **You MUST verify each checklist item below and document the result (✅ pass or ❌ fail). Incomplete verification is not acceptable.**

9. **Perform explicit best practices verification using `references/best_practices.md`:**

   **Configuration Pattern Checklist - verify each item:**
   ```
   [ ] Include blocks: Child modules use `include "root" { path = find_in_parent_folders("root.hcl") }`
   [ ] Named includes: All include blocks have names (not bare `include {}`)
   [ ] Root file naming: Root config is named `root.hcl` (not `terragrunt.hcl`)
   [ ] Environment configs: Environment-level configs named `env.hcl` (not `terragrunt.hcl`)
   [ ] Common variables: Shared variables in `common.hcl` read via `read_terragrunt_config()`
   ```

   **Dependency Management Checklist:**
   ```
   [ ] Mock outputs: ALL dependency blocks have mock_outputs for validation
   [ ] Mock allowed commands: mock_outputs_allowed_terraform_commands includes ["validate", "plan", "init"]
   [ ] Explicit paths: Dependency config_path uses relative paths ("../vpc" not absolute)
   [ ] No circular deps: Run `terragrunt dag graph` to verify no cycles
   ```

   **Security Checklist:**
   ```
   [ ] State encryption: remote_state config has `encrypt = true`
   [ ] State locking: DynamoDB table configured for S3 backend
   [ ] No hardcoded credentials: Search for patterns like "AKIA", "password =", account IDs
   [ ] Sensitive variables: Passwords/keys use `sensitive = true` in variable blocks
   [ ] IAM roles: Provider uses assume_role instead of static credentials
   ```

   **DRY Principle Checklist:**
   ```
   [ ] Generate blocks: Provider and backend configs use `generate` blocks
   [ ] Version constraints: terragrunt_version_constraint and terraform_version_constraint set
   [ ] Reusable locals: Common values in shared files, not duplicated
   [ ] if_exists: Generate blocks use appropriate if_exists strategy
   ```

   **Quick grep checks to run:**
   ```bash
   # Check for hardcoded AWS account IDs
   grep -r "[0-9]\{12\}" --include="*.hcl" . | grep -v mock

   # Check for potential credentials
   grep -ri "password\s*=" --include="*.hcl" .
   grep -ri "api_key\s*=" --include="*.hcl" .

   # Check for dependencies without mock_outputs
   grep -l "dependency\s" --include="*.hcl" -r . | xargs grep -L "mock_outputs"

   # Check for terragrunt.hcl files in non-module directories (anti-pattern)
   find . -name "terragrunt.hcl" -not -path "*/.terragrunt-cache/*" | head -20
   ```

### Troubleshooting

10. **Common issues and resolutions:**

   **Issue: Module not found**
   ```bash
   rm -rf .terragrunt-cache
   terragrunt init
   ```

   **Issue: Provider authentication errors**
   - Check provider configuration in generated files
   - Verify environment variables or credentials
   - Review provider documentation from WebSearch

   **Issue: Dependency errors**
   - Check dependency paths are correct
   - Ensure mock_outputs are provided for validation
   - Review dependency graph with `terragrunt dag graph`

   **Issue: State locking errors**
   ```bash
   terragrunt force-unlock <LOCK_ID>
   ```

   **Issue: Unknown provider or module parameters**
   - Re-run custom resource detection
   - Use WebSearch to look up current documentation
   - Check version compatibility

   **Issue: Generate block conflicts (file already exists)**
   ```
   ERROR: The file path ./versions.tf already exists and was not generated by terragrunt.
   Can not generate terraform file: ./versions.tf already exists
   ```
   **Solution:** This occurs when static `.tf` files exist that conflict with Terragrunt's `generate` blocks. Either:
   - Remove the conflicting static files (`versions.tf`, `provider.tf`, `backend.tf`)
   - Or use `if_exists = "skip"` in the generate block to not overwrite existing files
   ```bash
   # Remove conflicting files
   rm -f versions.tf provider.tf backend.tf
   rm -rf .terragrunt-cache
   ```

   **Issue: Root terragrunt.hcl anti-pattern warning**
   ```
   WARN: Using `terragrunt.hcl` as the root of Terragrunt configurations is an anti-pattern
   ```
   **Solution:** In Terragrunt 0.93+, the root configuration file should be named `root.hcl` instead of `terragrunt.hcl`. Rename the file:
   ```bash
   mv terragrunt.hcl root.hcl
   # Update include blocks in child modules to reference root.hcl
   ```

## Best Practices Integration

Reference the comprehensive best practices guide for detailed recommendations:

```bash
# Read the best practices reference
cat references/best_practices.md
```

**Key best practices to check:**
- ✅ Use `include` for shared configuration
- ✅ Provide mock_outputs for dependencies
- ✅ Use `generate` blocks for provider config
- ✅ Enable state encryption and locking
- ✅ Use environment variables for dynamic values
- ✅ Specify version constraints
- ✅ Avoid hardcoded values
- ✅ Use meaningful directory structure
- ✅ Enable security features (encryption, IAM roles)

**When validating, check for anti-patterns:**
- ❌ Hardcoded credentials or account IDs
- ❌ Missing mock outputs
- ❌ Overly deep directory nesting
- ❌ Duplicated configuration across modules
- ❌ Missing version constraints
- ❌ Unencrypted state

Refer to `references/best_practices.md` for complete examples and detailed guidance.

## Tool Requirements

**Required:**
- terragrunt (>= 0.93.0 recommended for new CLI)
- terraform or opentofu (>= 1.6.0 recommended)

**Optional but recommended:**
- tflint - HCL linting
- trivy - Security scanning (replaces tfsec)
- checkov - Alternative security scanner (750+ built-in policies)
- graphviz (dot) - Dependency visualization
- jq - JSON parsing
- python3 - For custom resource detection script

**Deprecated tools:**
- tfsec - Merged into Trivy, no longer actively maintained

**Installation commands:**
```bash
# macOS
brew install terragrunt terraform tflint trivy graphviz jq

# Install Trivy (recommended security scanner)
brew install trivy

# Install Checkov (alternative security scanner)
pip3 install checkov

# Legacy tfsec (deprecated - use trivy instead)
# brew install tfsec

# Linux - Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Linux - Checkov
pip3 install checkov

# Verify installations
terragrunt --version
trivy --version
checkov --version
```

## Integration with Context7 MCP

If Context7 MCP is available, use it for provider/module documentation lookup:

1. **Resolve library ID:**
   ```
   mcp__context7__resolve-library-id with libraryName: "mongodb/mongodbatlas"
   ```

2. **Get documentation:**
   ```
   mcp__context7__get-library-docs with context7CompatibleLibraryID: "/mongodb/mongodbatlas"
   ```

This provides version-aware documentation directly, as an alternative to WebSearch.

## Automated Workflows

### CI/CD Integration

Example validation in CI/CD pipeline:

```bash
#!/bin/bash
# ci-validate.sh

set -e

echo "Installing dependencies..."
# Install terragrunt, terraform, tflint, tfsec

echo "Detecting custom resources..."
python3 scripts/detect_custom_resources.py . --format json > custom_resources.json

# Could integrate with automated documentation lookup here

echo "Running validation suite..."
SKIP_PLAN=true bash scripts/validate_terragrunt.sh .

echo "Validation complete!"
```

### Pre-commit Hook

Example pre-commit hook for local development:

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Format check
terragrunt hcl fmt --check || {
    echo "HCL formatting issues found. Run: terragrunt hcl fmt"
    exit 1
}

# Quick HCL syntax validation (Terragrunt 0.93+)
# Note: For full validation, use: terragrunt init && terragrunt validate
# But that requires credentials. HCL format check catches syntax errors.

echo "Pre-commit validation passed!"
```

## Troubleshooting Guide

### Debug Mode

Enable debug output for troubleshooting:

```bash
# Terragrunt debug
TERRAGRUNT_DEBUG=1 terragrunt plan

# Terraform trace
TF_LOG=TRACE terragrunt plan
```

### Common Error Patterns

**"Error: Module not found"**
- Clear cache: `rm -rf .terragrunt-cache`
- Re-initialize: `terragrunt init`

**"Error: Provider not found"**
- Check provider configuration
- Run custom resource detection
- Use WebSearch to find correct provider source and version
- Verify required_providers block

**"Error: Invalid function call"**
- Check Terragrunt version compatibility
- Review function syntax in documentation

**"Cycle detected in dependency graph"**
- Review dependency chains
- Consider refactoring into single module
- Use data sources instead of dependencies

**"Error acquiring state lock"**
- Check if another process is running
- Verify DynamoDB table (for S3 backend)
- Force unlock if safe: `terragrunt force-unlock <LOCK_ID>`

**"Error: unknown command" (Terragrunt 0.93+)**
- Terragrunt 0.93+ has a new CLI with breaking changes
- Commands like `render-json`, `validate-inputs` are deprecated
- Use `terragrunt run -- <command>` for custom/unsupported commands
- Replace `graph-dependencies` with `dag graph`
- See: https://terragrunt.gruntwork.io/docs/migrate/cli-redesign/

## Output Interpretation

### Success Indicators

✅ **All checks passing:**
- All HCL files properly formatted
- Inputs are valid
- Terraform configuration is valid
- No linting issues
- No critical security issues
- Valid dependency graph
- Plan generated successfully

### Warning Indicators

⚠️ **Review needed:**
- Security warnings from tfsec (non-critical)
- Linting suggestions (best practices)
- Deprecated provider features
- Missing recommended configurations

### Error Indicators

✗ **Must fix:**
- Format errors
- Invalid inputs
- Terraform validation failures
- Circular dependencies
- Provider authentication failures
- State locking errors

## Advanced Usage

### Custom Validation Rules

Create custom tflint rules by adding `.tflint.hcl`:

```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
}
```

### Custom Security Policies

Create custom tfsec policies by adding `.tfsec/config.yml`:

```yaml
minimum_severity: MEDIUM
exclude:
  - AWS001  # Example: exclude specific rules
```

### Dependency Graph Analysis

Analyze complex dependency chains:

```bash
# Generate detailed graph (Terragrunt 0.93+ syntax)
terragrunt dag graph > graph.dot

# Convert to visual format
dot -Tpng graph.dot > graph.png
dot -Tsvg graph.dot > graph.svg

# Analyze for circular dependencies
grep -A5 "cycle" <(terragrunt dag graph 2>&1)
```

## Resources

### Scripts

- `scripts/validate_terragrunt.sh` - Comprehensive validation suite
- `scripts/detect_custom_resources.py` - Custom provider/module detector

### References

- `references/best_practices.md` - Comprehensive best practices guide covering:
  - Directory structure patterns
  - DRY principles and configuration sharing
  - Dependency management
  - Security best practices
  - Testing and validation workflows
  - Common anti-patterns to avoid
  - Troubleshooting guides

### External Documentation

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terraform Registry](https://registry.terraform.io/)
