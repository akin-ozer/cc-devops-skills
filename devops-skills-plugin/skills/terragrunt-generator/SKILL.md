---
name: terragrunt-generator
description: Comprehensive toolkit for generating best practice Terragrunt configurations (HCL files) following current standards and conventions. Use this skill when creating new Terragrunt resources (root configs, child modules, stacks, environment setups), or building multi-environment Terragrunt projects.
---

# Terragrunt Generator

## Overview

Generate production-ready Terragrunt configurations following current best practices, naming conventions, and security standards. All generated configurations are automatically validated.

**Terragrunt 2025 Features Supported:**
- [Stacks](https://terragrunt.gruntwork.io/docs/features/stacks/) - Infrastructure blueprints with `terragrunt.stack.hcl` (GA since v0.78.0)
- [Feature Flags](https://terragrunt.gruntwork.io/docs/features/feature-flags/) - Runtime control via `feature` blocks
- [Exclude Blocks](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#exclude) - Fine-grained execution control (replaces deprecated `skip`)
- [Errors Blocks](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#errors) - Advanced error handling (replaces deprecated `retryable_errors`)
- [OpenTofu Engine](https://terragrunt.gruntwork.io/docs/features/engine/) - Alternative IaC engine support

## Root Configuration Naming

> **RECOMMENDED**: Use `root.hcl` instead of `terragrunt.hcl` for root files per [migration guide](https://terragrunt.gruntwork.io/docs/migrate/migrating-from-root-terragrunt-hcl).

| Approach | Root File | Include Syntax |
|----------|-----------|----------------|
| **Modern** | `root.hcl` | `find_in_parent_folders("root.hcl")` |
| **Legacy** | `terragrunt.hcl` | `find_in_parent_folders()` |

## Architecture Patterns

> **CRITICAL:** Before generating ANY configuration, you MUST determine the architecture pattern and understand its constraints.

### Pattern A: Multi-Environment with Environment-Agnostic Root

**Use when:** Managing multiple environments (dev/staging/prod) with shared root configuration.

**Key principle:** `root.hcl` is **environment-agnostic** - it does NOT read environment-specific files.

```
infrastructure/
├── root.hcl              # Environment-AGNOSTIC (no env.hcl references)
├── dev/
│   ├── env.hcl           # Environment variables (locals block)
│   ├── vpc/terragrunt.hcl
│   └── rds/terragrunt.hcl
└── prod/
    ├── env.hcl           # Environment variables (locals block)
    ├── vpc/terragrunt.hcl
    └── rds/terragrunt.hcl
```

**Root.hcl constraints:**
- ❌ CANNOT use `read_terragrunt_config(find_in_parent_folders("env.hcl"))` - env.hcl doesn't exist at root level
- ❌ CANNOT reference `local.environment` or `local.aws_region` that come from env.hcl
- ✅ CAN use static values or `get_env()` for runtime configuration
- ✅ CAN use `${path_relative_to_include()}` for state keys (this works dynamically)

**Child modules read env.hcl:**
```hcl
# dev/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

inputs = {
  name = "${local.env.locals.environment}-vpc"  # Works: env.hcl exists in dev/
}
```

### Pattern B: Single Environment or Environment-Aware Root

**Use when:** Single environment OR all environments share the same root with environment detection.

```
infrastructure/
├── root.hcl              # Can be environment-aware via get_env() or directory parsing
├── account.hcl           # Account-level config (optional)
├── region.hcl            # Region-level config (optional)
└── vpc/
    └── terragrunt.hcl
```

**Root.hcl can detect environment:**
```hcl
# root.hcl - environment detection via directory path
locals {
  # Parse environment from path (e.g., "prod/vpc" -> "prod")
  path_parts  = split("/", path_relative_to_include())
  environment = local.path_parts[0]

  # OR use environment variable
  environment = get_env("TG_ENVIRONMENT", "dev")
}
```

### Pattern C: Shared Environment Variables (_env directory)

**Use when:** Centralizing environment variables with symlinks or direct references.

```
infrastructure/
├── root.hcl              # Environment-AGNOSTIC
├── _env/                 # Centralized environment definitions
│   ├── prod.hcl
│   ├── staging.hcl
│   └── dev.hcl
├── prod/
│   ├── env.hcl           # Reads from _env/prod.hcl
│   └── vpc/terragrunt.hcl
└── dev/
    ├── env.hcl           # Reads from _env/dev.hcl
    └── vpc/terragrunt.hcl
```

**env.hcl reads from _env:**
```hcl
# prod/env.hcl
locals {
  env_vars = read_terragrunt_config("${get_repo_root()}/_env/prod.hcl")

  # Re-export for child modules
  environment        = local.env_vars.locals.environment
  aws_region         = local.env_vars.locals.aws_region
  vpc_cidr           = local.env_vars.locals.vpc_cidr
  # ... other variables
}
```

### Pre-Generation Pattern Checklist

> **MANDATORY:** Before writing any files, you MUST complete this checklist and OUTPUT it to the user with checkmarks filled in. This is not optional.

**Output this completed checklist before generating any files:**
```
## Architecture Pattern Selection

[x] Identified architecture pattern: Pattern ___ (A/B/C)
[x] Root.hcl scope: [ ] environment-agnostic  OR  [ ] environment-aware
[x] env.hcl location: ___________________
[x] Child modules access env via: ___________________
[x] Verified: No file references a path that doesn't exist from its location
```

**Example completed checklist:**
```
## Architecture Pattern Selection

[x] Identified architecture pattern: Pattern A (Multi-Environment with Environment-Agnostic Root)
[x] Root.hcl scope: [x] environment-agnostic  OR  [ ] environment-aware
[x] env.hcl location: dev/env.hcl, prod/env.hcl (one per environment)
[x] Child modules access env via: read_terragrunt_config(find_in_parent_folders("env.hcl"))
[x] Verified: No file references a path that doesn't exist from its location
```

## When to Use

- Creating new Terragrunt projects or configurations
- Setting up multi-environment infrastructure (dev/staging/prod)
- Implementing DRY Terraform configurations
- Managing complex infrastructure with dependencies
- Working with custom Terraform providers or modules

## Core Capabilities

### 1. Generate Root Configuration
Create root-level `root.hcl` or `terragrunt.hcl` with remote state, provider config, and common variables.

> **MANDATORY:** Before generating, READ the template file:
> ```
> Read: assets/templates/root/terragrunt.hcl
> ```

**Template:** `assets/templates/root/terragrunt.hcl`
**Patterns:** `references/common-patterns.md` → Root Configuration Patterns

**Key placeholders to replace:**
- `[BUCKET_NAME]`, `[AWS_REGION]`, `[DYNAMODB_TABLE]`
- `[TERRAFORM_VERSION]`, `[PROVIDER_NAME]`, `[PROVIDER_VERSION]`
- `[ENVIRONMENT]`, `[PROJECT_NAME]`

**Root.hcl Design Principles:**
1. **Environment-agnostic by default** - Don't assume env.hcl exists at root level
2. **Use static values for provider/backend region** - Or use `get_env()` for runtime config
3. **State key uses `path_relative_to_include()`** - This automatically includes environment path
4. **Provider tags can be static** - Environment-specific tags go in child modules

### 2. Generate Child Module Configuration
Create child modules with dependencies, mock outputs, and proper includes.

> **MANDATORY:** Before generating, READ the template file:
> ```
> Read: assets/templates/child/terragrunt.hcl
> ```

**Template:** `assets/templates/child/terragrunt.hcl`
**Patterns:** `references/common-patterns.md` → Child Module Patterns

**Module source options:**
- Local: `"../../modules/vpc"`
- Git: `"git::https://github.com/org/repo.git//path?ref=v1.0.0"`
- Registry: `"tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"`

### 3. Generate Standalone Module
Self-contained modules without root dependency.

> **MANDATORY:** Before generating, READ the template file:
> ```
> Read: assets/templates/module/terragrunt.hcl
> ```

**Template:** `assets/templates/module/terragrunt.hcl`

### 4. Generate Multi-Environment Infrastructure
Complete directory structures for dev/staging/prod.

> **MANDATORY:** Before generating:
> 1. Determine architecture pattern (see Architecture Patterns section)
> 2. Read relevant templates for root and child modules
> 3. Verify env.hcl placement and access patterns

**Patterns:** `references/common-patterns.md` → Environment-Specific Patterns

**Typical structure (Pattern A - Environment-Agnostic Root):**
```
infrastructure/
├── root.hcl              # Environment-AGNOSTIC root config
├── dev/
│   ├── env.hcl           # Dev environment variables
│   └── vpc/terragrunt.hcl
└── prod/
    ├── env.hcl           # Prod environment variables
    └── vpc/terragrunt.hcl
```

### 5. Generate Terragrunt Stacks (2025)
Infrastructure blueprints using `terragrunt.stack.hcl`.

> **MANDATORY:** Before generating, READ the template files:
> ```
> Read: assets/templates/stack/terragrunt.stack.hcl
> Read: assets/templates/catalog/terragrunt.hcl
> ```

**Docs:** [Stacks Documentation](https://terragrunt.gruntwork.io/docs/features/stacks/)
**Template:** `assets/templates/stack/terragrunt.stack.hcl`
**Catalog Template:** `assets/templates/catalog/terragrunt.hcl`
**Patterns:** `references/common-patterns.md` → Stacks Patterns

**Commands:**
```bash
terragrunt stack generate    # Generate unit configurations
terragrunt stack run plan    # Plan all units
terragrunt stack run apply   # Apply all units
terragrunt stack output      # Get aggregated outputs
terragrunt stack clean       # Clean generated directories
```

### 6. Generate Feature Flags (2025)
Runtime control without code changes.

**Docs:** [Feature Flags Documentation](https://terragrunt.gruntwork.io/docs/features/feature-flags/)
**Patterns:** `references/common-patterns.md` → Feature Flags Patterns

> **CRITICAL:** Feature flag `default` values MUST be static (boolean, string, number).
> They CANNOT reference `local.*` values. Use static defaults and override via CLI/env vars.

**Correct:**
```hcl
feature "enable_monitoring" {
  default = false  # Static value - OK
}
```

**Incorrect:**
```hcl
feature "enable_monitoring" {
  default = local.env.locals.enable_monitoring  # Dynamic reference - FAILS
}
```

**Usage:**
```bash
terragrunt apply --feature enable_monitoring=true
# or
export TG_FEATURE="enable_monitoring=true"
```

**Environment-specific defaults:** Use different static defaults per environment file, not dynamic references.

### 7. Generate Exclude Blocks (2025)
Fine-grained execution control (replaces deprecated `skip`).

**Docs:** [Exclude Block Reference](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#exclude)
**Patterns:** `references/common-patterns.md` → Exclude Block Patterns

**Actions:** `"plan"`, `"apply"`, `"destroy"`, `"all"`, `"all_except_output"`

**Production Recommendation:** For critical production resources, add exclude blocks to prevent accidental destruction:
```hcl
# Protect production databases from accidental destroy
exclude {
  if      = true
  actions = ["destroy"]
  exclude_dependencies = false
}

# Also use prevent_destroy for critical resources
prevent_destroy = true
```

### 8. Generate Errors Blocks (2025)
Advanced error handling (replaces deprecated `retryable_errors`).

**Docs:** [Errors Block Reference](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#errors)
**Patterns:** `references/common-patterns.md` → Errors Block Patterns

### 9. Generate OpenTofu Engine Configuration (2025)
Use OpenTofu as the IaC engine.

**Docs:** [Engine Documentation](https://terragrunt.gruntwork.io/docs/features/engine/)
**Patterns:** `references/common-patterns.md` → OpenTofu Engine Patterns

### 10. Handling Custom Providers/Modules
When generating configs with custom providers:

1. **Identify** the provider name, source, and version
2. **Search** using WebSearch: `"[provider] terraform provider [version] documentation"`
3. **Or use Context7 MCP** if available for structured docs
4. **Generate** with proper `required_providers` block
5. **Document** authentication requirements in comments

## Generation Workflow

> **CRITICAL:** Follow this workflow for EVERY generation task. Skipping steps leads to validation errors.

### Step 1: Understand Requirements
- What type of configuration? (root, child, standalone, stack)
- Single or multi-environment?
- What dependencies exist between modules?
- What providers/modules will be used?

### Step 2: Determine Architecture Pattern
> **MANDATORY:** Select and document the pattern BEFORE writing any files.

| Scenario | Pattern | Root.hcl Scope |
|----------|---------|----------------|
| Multi-env with shared root | Pattern A | Environment-agnostic |
| Single environment | Pattern B | Environment-aware |
| Centralized env vars | Pattern C | Environment-agnostic |

**Verify:**
```
[ ] Pattern identified: ____
[ ] Root.hcl will be: [ ] environment-agnostic  [ ] environment-aware
[ ] env.hcl will be located in: ____
[ ] Child modules will read env.hcl via: ____
```

### Step 3: Read Required Templates
> **MANDATORY:** Read the relevant template file(s) BEFORE generating each configuration type.

| Configuration Type | Template to Read |
|-------------------|------------------|
| Root configuration | `assets/templates/root/terragrunt.hcl` |
| Child module | `assets/templates/child/terragrunt.hcl` |
| Standalone module | `assets/templates/module/terragrunt.hcl` |
| Stack file | `assets/templates/stack/terragrunt.stack.hcl` |
| Catalog unit | `assets/templates/catalog/terragrunt.hcl` |

**Also read:**
- `references/common-patterns.md` - Primary source for generation patterns

### Step 4: Generate with Validation

> **Validation Strategy:** Use a combination of inline checks during generation and batch validation at the end.

**Generation order for multi-environment projects:**

1. **Generate root.hcl first**
   - **Inline checks (during generation):**
     - [ ] No `read_terragrunt_config(find_in_parent_folders("env.hcl"))` if environment-agnostic
     - [ ] `remote_state` block has `encrypt = true`
     - [ ] `errors` block used (not deprecated `retryable_errors`)

2. **Generate env.hcl files for each environment**
   - **Inline checks (during generation):**
     - [ ] `locals` block contains environment, aws_region, and module-specific vars
     - [ ] No references to files that don't exist at that directory level

3. **Generate child modules (VPC, etc.) - modules with NO dependencies first**
   - **Inline checks (during generation):**
     - [ ] `include` block uses `find_in_parent_folders("root.hcl")`
     - [ ] `read_terragrunt_config(find_in_parent_folders("env.hcl"))` present
     - [ ] `terraform.source` uses valid syntax (tfr:///, git::, or relative path)

4. **Generate dependent modules (RDS, EKS, etc.)**
   - **Inline checks (during generation):**
     - [ ] `dependency` blocks have `mock_outputs`
     - [ ] `mock_outputs_allowed_terraform_commands` includes `["validate", "plan", "destroy"]`
     - [ ] Production modules have `prevent_destroy = true` and/or `exclude` block

5. **Run batch validation after ALL files are generated**
   > **Note:** Full CLI validation (`terragrunt hcl fmt`, `terragrunt dag graph`) requires all files to exist, so these are batched at the end.

   ```bash
   # Batch validation commands (run after all files exist):
   terragrunt hcl fmt --check          # Format validation
   terragrunt dag graph                 # Dependency graph validation
   ```

   - Invoke `devops-skills:terragrunt-validator` skill for comprehensive validation

### Step 5: Fix and Re-Validate
If validation fails:
1. Analyze errors (path resolution, missing variables, syntax errors)
2. Fix issues in the specific file(s)
3. Re-validate the fixed file(s)
4. Repeat until ALL errors are resolved

### Step 6: Present Results
Follow "Presentation Requirements" section below.

## Validation Workflow

**CRITICAL:** Every generated configuration MUST be validated.

### Incremental Validation Checks

**After generating root.hcl:**
```bash
cd <infrastructure-directory>
terragrunt hcl fmt --check
```

**After generating each child module:**
```bash
cd <module-directory>
terragrunt hcl fmt --check
# If no dependencies on other modules:
terragrunt hcl validate --inputs
```

### Full Validation

After all files are generated:

1. **Invoke validation skill:**
   ```
   Invoke: devops-skills:terragrunt-validator skill
   ```

2. **If validation fails:**
   - Analyze errors (missing placeholders, invalid syntax, wrong paths)
   - Fix issues
   - **Re-validate** (repeat until ALL errors are resolved)

3. **If validation succeeds:** Present configurations with usage instructions

**Skip validation only for:** Partial snippets, documentation examples, or explicit user request

## Presentation Requirements

> **MANDATORY:** After successful validation, you MUST present ALL of the following sections. Incomplete presentation is not acceptable. Copy and fill in the templates below.

### 1. Directory Structure Summary (MANDATORY)
```bash
# Show the generated structure
tree <infrastructure-directory>
```

### 2. Files Generated (MANDATORY)

**Output this table with all generated files:**
```markdown
| File | Purpose |
|------|---------|
| root.hcl | Shared configuration for all child modules (state backend, provider) |
| dev/env.hcl | Development environment variables |
| prod/env.hcl | Production environment variables |
| dev/vpc/terragrunt.hcl | VPC module for development |
| ... | ... |
```

### 3. Usage Instructions (MANDATORY)

> **You MUST include this section.** Copy the template below and fill in the actual values:

```markdown
## Usage Instructions

### Prerequisites
Before running Terragrunt commands, ensure:
1. AWS credentials are configured (`aws configure` or environment variables)
2. S3 bucket `<BUCKET_NAME>` exists for state storage
3. DynamoDB table `<TABLE_NAME>` exists for state locking

### Commands

# Navigate to infrastructure directory
cd <INFRASTRUCTURE_DIR>

# Initialize all modules
terragrunt run --all init

# Preview changes for a specific environment
cd <ENV>/vpc && terragrunt plan

# Preview all changes
terragrunt run --all plan

# Apply changes (requires approval)
terragrunt run --all apply

# Destroy (use with extreme caution)
terragrunt run --all destroy
```

### 4. Environment-Specific Notes (MANDATORY)

> **You MUST include this section.** Copy the template below and fill in the actual values:

```markdown
## Environment Notes

### Required Environment Variables
| Variable | Description | Example |
|----------|-------------|---------|
| AWS_PROFILE | AWS CLI profile to use | `my-profile` |
| AWS_REGION | AWS region (or set in provider) | `us-east-1` |

### Prerequisites
- [ ] S3 bucket `<BUCKET_NAME>` must exist before first run
- [ ] DynamoDB table `<TABLE_NAME>` must exist for state locking
- [ ] IAM permissions for Terraform state management

### Production-Specific Protections
| Module | Protection | Description |
|--------|------------|-------------|
| prod/rds | `prevent_destroy = true` | Prevents accidental database deletion |
| prod/rds | `exclude { actions = ["destroy"] }` | Blocks destroy commands |
```

### 5. Next Steps (Optional)
Suggest what the user might want to do next (add more modules, customize configurations, etc.)

## Best Practices

Reference `../devops-skills:terragrunt-validator/references/best_practices.md` for comprehensive guidelines.

**Key principles:**
- Use `include` blocks to inherit root configuration (DRY)
- Always provide mock outputs for dependencies
- Enable state encryption (`encrypt = true`)
- Use `generate` blocks for provider configuration
- Specify bounded version constraints (`~> 5.0`, not `>= 5.0`) for local/Git modules
- Never hardcode credentials or secrets
- Configure retry logic for transient errors

> **Note on Version Constraints with Registry Modules:** When using Terraform Registry modules (e.g., `tfr:///terraform-aws-modules/vpc/aws?version=5.1.0`), they typically define their own `required_providers`. In this case, you may omit generating `required_providers` in `root.hcl` to avoid conflicts. The module's pinned version (`?version=X.X.X`) provides the version constraint. See "Common Issues → Provider Conflict with Registry Modules" for details.

**Anti-patterns to avoid:**
- Hardcoded account IDs, regions, or environment names
- Missing mock outputs for dependencies
- Duplicated configuration across modules
- Unencrypted state storage
- Missing or loose version constraints (except when using registry modules that define their own)
- Root.hcl trying to read env.hcl that doesn't exist at root level

## Deprecated Attributes

| Deprecated | Replacement | Reference |
|------------|-------------|-----------|
| `skip` | `exclude` block | [Docs](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#exclude) |
| `retryable_errors` | `errors.retry` block | [Docs](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/#errors) |
| `run-all` | `run --all` | [Migration](https://terragrunt.gruntwork.io/docs/migrate/migrating-from-run-all/) |
| `--terragrunt-*` flags | Unprefixed flags | [CLI Reference](https://terragrunt.gruntwork.io/docs/reference/cli-options/) |
| `TERRAGRUNT_*` env vars | `TG_*` env vars | [CLI Reference](https://terragrunt.gruntwork.io/docs/reference/cli-options/) |

## Resources

### Templates - MUST Read Before Generating

| Configuration Type | Template File | When to Read |
|-------------------|---------------|--------------|
| Root configuration | `assets/templates/root/terragrunt.hcl` | Before generating any root.hcl |
| Child module | `assets/templates/child/terragrunt.hcl` | Before generating any child module |
| Standalone module | `assets/templates/module/terragrunt.hcl` | Before generating standalone modules |
| Stack file | `assets/templates/stack/terragrunt.stack.hcl` | Before generating stacks |
| Catalog unit | `assets/templates/catalog/terragrunt.hcl` | Before generating catalog units |

### References

| Reference | Content | When to Read |
|-----------|---------|--------------|
| `references/common-patterns.md` | All generation patterns with examples | Always, before generating |
| `../devops-skills:terragrunt-validator/references/best_practices.md` | Comprehensive best practices | Always, before generating |

### Official Documentation
- [Terragrunt Docs](https://terragrunt.gruntwork.io/docs/)
- [Configuration Reference](https://terragrunt.gruntwork.io/docs/reference/config-blocks-and-attributes/)
- [CLI Reference](https://terragrunt.gruntwork.io/docs/reference/cli-options/)
- [Stacks](https://terragrunt.gruntwork.io/docs/features/stacks/)
- [Feature Flags](https://terragrunt.gruntwork.io/docs/features/feature-flags/)
- [Engine](https://terragrunt.gruntwork.io/docs/features/engine/)
- [Migration Guides](https://terragrunt.gruntwork.io/docs/migrate/)

## Common Issues

### Root.hcl Cannot Find env.hcl

**Symptom:**
```
Error: Attempt to get attribute from null value
  on ./root.hcl line X:
  This value is null, so it does not have any attributes.
```

**Cause:** Root.hcl is trying to read `env.hcl` via `find_in_parent_folders("env.hcl")`, but env.hcl doesn't exist at the root level.

**Solution:** Make root.hcl environment-agnostic:
```hcl
# DON'T do this in root.hcl for multi-environment setups:
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))  # FAILS
}

# DO use static values or get_env():
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "us-east-1"  # Static value, or use get_env("AWS_REGION", "us-east-1")
}
EOF
}
```

### Provider Conflict with Registry Modules

When using Terraform Registry modules (e.g., `tfr:///terraform-aws-modules/vpc/aws`), they may define their own `required_providers` block. This can conflict with provider configuration generated by `root.hcl`.

**Symptoms:**
```
Error: Duplicate required providers configuration
```

**Solutions:**
1. **Remove conflicting generate block** - If using registry modules that manage their own providers, avoid generating duplicate `required_providers`:
   ```hcl
   # In root.hcl - only generate provider config, not required_providers
   generate "provider" {
     path      = "provider.tf"
     if_exists = "overwrite_terragrunt"
     contents  = <<EOF
   provider "aws" {
     region = "us-east-1"
   }
   EOF
   }
   ```

2. **Use if_exists = "skip"** - Skip generation if file already exists:
   ```hcl
   generate "versions" {
     path      = "versions.tf"
     if_exists = "skip"  # Don't overwrite module's versions.tf
     contents  = "..."
   }
   ```

3. **Clear cache** - If conflicts persist after fixes:
   ```bash
   rm -rf .terragrunt-cache
   terragrunt init
   ```

### Feature Flag Validation Errors

If you see `Unknown variable; There is no variable named "local"` in feature blocks, ensure defaults are static values (see Feature Flags section above).

### Child Module Cannot Find env.hcl

**Symptom:**
```
Error: Attempt to get attribute from null value
  on ./dev/vpc/terragrunt.hcl line X:
```

**Cause:** Child module's `find_in_parent_folders("env.hcl")` cannot find env.hcl.

**Solution:** Ensure env.hcl exists in the environment directory:
```
dev/
├── env.hcl           # This file MUST exist
└── vpc/
    └── terragrunt.hcl  # Calls find_in_parent_folders("env.hcl")
```

## Quick Reference Card

### File Reading Checklist

Before generating, READ these files in order:

1. [ ] `references/common-patterns.md` - Understand available patterns
2. [ ] `../devops-skills:terragrunt-validator/references/best_practices.md` - Know the rules
3. [ ] Relevant template(s) from `assets/templates/` - Structural reference

### Architecture Decision Tree

```
Q: Multiple environments (dev/staging/prod)?
├─ YES → Q: Shared root configuration?
│   ├─ YES → Pattern A: Environment-Agnostic Root
│   └─ NO  → Separate root.hcl per environment
└─ NO  → Q: Environment detection needed?
    ├─ YES → Pattern B: Environment-Aware Root
    └─ NO  → Pattern B: Simple single-environment
```

### Validation Sequence

1. Format check: `terragrunt hcl fmt --check`
2. Input validation: `terragrunt hcl validate --inputs`
3. Full validation: Invoke `devops-skills:terragrunt-validator` skill
4. Fix errors → Re-validate → Repeat until clean