# Terragrunt Best Practices and Common Patterns

## Overview

This reference document provides best practices, common patterns, and anti-patterns for Terragrunt configurations. Use this as a guide when validating or creating Terragrunt code.

## Directory Structure

### Recommended Structure

```
infrastructure/
├── terragrunt.hcl              # Root Terragrunt config
├── common.hcl                  # Shared configuration
├── prod/
│   ├── terragrunt.hcl         # Environment-level config
│   ├── vpc/
│   │   └── terragrunt.hcl     # Module-specific config
│   ├── database/
│   │   └── terragrunt.hcl
│   └── app/
│       └── terragrunt.hcl
├── staging/
│   └── ... (similar structure)
└── dev/
    └── ... (similar structure)
```

### Anti-Pattern: Flat Structure

❌ Avoid flat structures without environment separation:
```
infrastructure/
├── vpc.hcl
├── database.hcl
├── app.hcl
```

## DRY Principles

### Use `include` for Shared Configuration

✅ **Good Practice:**
```hcl
# Root terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "my-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

# Child terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}
```

### Use `read_terragrunt_config` for Shared Variables

✅ **Good Practice:**
```hcl
# common.hcl
locals {
  region = "us-east-1"
  environment = "prod"
  tags = {
    Terraform   = "true"
    Environment = local.environment
  }
}

# terragrunt.hcl
locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  region = local.common.locals.region
  tags   = local.common.locals.tags
}
```

## Dependencies

### Explicit Dependencies

✅ **Good Practice:**
```hcl
dependency "vpc" {
  config_path = "../vpc"
}

dependency "database" {
  config_path = "../database"

  # Mock outputs for validation
  mock_outputs = {
    endpoint = "mock-db-endpoint"
    port     = 5432
  }

  # Allow mock outputs during plan
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  vpc_id          = dependency.vpc.outputs.vpc_id
  database_endpoint = dependency.database.outputs.endpoint
}
```

### Anti-Pattern: Implicit Dependencies via Remote State

❌ Avoid accessing remote state directly:
```hcl
# This makes dependencies unclear
inputs = {
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id
}
```

## Mock Outputs for Testing

### Provide Mock Outputs

✅ **Good Practice:**
```hcl
dependency "network" {
  config_path = "../network"

  mock_outputs = {
    vpc_id     = "vpc-mock123"
    subnet_ids = ["subnet-mock1", "subnet-mock2"]
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}
```

This allows running `terragrunt plan` without deploying dependencies first.

## Generate Blocks

### Use `generate` for Provider Configuration

✅ **Good Practice:**
```hcl
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"

  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformRole"
  }

  default_tags {
    tags = ${jsonencode(local.tags)}
  }
}
EOF
}
```

### Use `generate` for Backend Configuration

✅ **Good Practice:**
```hcl
generate "backend" {
  path      = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  backend "s3" {}
}
EOF
}
```

## Input Variables

### Use `inputs` Block

✅ **Good Practice:**
```hcl
inputs = {
  environment = local.environment
  region      = local.region

  # Use dependency outputs
  vpc_id = dependency.vpc.outputs.vpc_id

  # Use functions
  instance_count = get_env("INSTANCE_COUNT", 3)

  # Merge tags
  tags = merge(
    local.common_tags,
    {
      Module = "app"
    }
  )
}
```

### Anti-Pattern: Duplicating Inputs

❌ Avoid repeating the same inputs:
```hcl
# Don't do this across multiple modules
inputs = {
  region = "us-east-1"  # Repeated everywhere
  tags = {              # Repeated everywhere
    Terraform = "true"
  }
}
```

## terraform Block

### Specify Terraform and Provider Versions

✅ **Good Practice:**
```hcl
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

generate "versions" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF
}
```

## Error Handling

### Use `get_env` with Defaults

✅ **Good Practice:**
```hcl
locals {
  account_id = get_env("AWS_ACCOUNT_ID", "")
}

# Validate required environment variables
inputs = {
  account_id = local.account_id != "" ? local.account_id : run_cmd("--terragrunt-quiet", "aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")
}
```

### Use `try` for Optional Values

✅ **Good Practice:**
```hcl
locals {
  env_config = read_terragrunt_config(find_in_parent_folders("env.hcl", "empty.hcl"))

  # Safely access potentially missing values
  instance_type = try(local.env_config.locals.instance_type, "t3.micro")
}
```

## Common Anti-Patterns

### 1. Hardcoding Values

❌ **Bad:**
```hcl
inputs = {
  region = "us-east-1"  # Hardcoded
  account_id = "123456789012"  # Hardcoded
}
```

✅ **Good:**
```hcl
locals {
  region     = get_env("AWS_REGION", "us-east-1")
  account_id = get_aws_account_id()
}

inputs = {
  region     = local.region
  account_id = local.account_id
}
```

### 2. Not Using Mock Outputs

❌ **Bad:**
```hcl
dependency "vpc" {
  config_path = "../vpc"
  # No mock outputs - can't validate without deploying vpc
}
```

### 3. Deep Nesting

❌ **Bad:**
```
infrastructure/
└── prod/
    └── us-east-1/
        └── vpc/
            └── public/
                └── subnet-1/
                    └── terragrunt.hcl
```

✅ **Good:**
```
infrastructure/
└── prod/
    └── vpc/
        └── terragrunt.hcl  # Configure all subnets here
```

### 4. Not Using Functions

❌ **Bad:**
```hcl
# Manually maintaining paths
remote_state {
  config = {
    key = "prod/vpc/terraform.tfstate"
  }
}
```

✅ **Good:**
```hcl
remote_state {
  config = {
    key = "${path_relative_to_include()}/terraform.tfstate"
  }
}
```

## Security Best Practices

### 1. Enable State Encryption

```hcl
remote_state {
  backend = "s3"
  config = {
    encrypt = true
    kms_key_id = "arn:aws:kms:us-east-1:123456789012:key/..."
  }
}
```

### 2. Use IAM Roles for Authentication

```hcl
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformRole"
  }
}
EOF
}
```

### 3. Enable State Locking

```hcl
remote_state {
  backend = "s3"
  config = {
    dynamodb_table = "terraform-locks"
  }
}
```

### 4. Use Sensitive Variables

```hcl
inputs = {
  # Mark sensitive inputs
  database_password = get_env("DB_PASSWORD")  # Never hardcode
}
```

## Testing and Validation

### 1. Modern Terragrunt CLI (v0.93+)

Note: Terragrunt 0.93+ uses a redesigned CLI with significant changes:
- `run-all` is deprecated → use `run --all`
- `hclfmt` is deprecated → use `hcl fmt`
- `validate-inputs` is deprecated → use `hcl validate --inputs`
- `graph-dependencies` is deprecated → use `dag graph`
- The `--terragrunt-non-interactive` flag is no longer needed or supported

### 2. Validate Before Apply

```bash
# Format check (new syntax)
terragrunt hcl fmt --check

# Input validation (new in 0.93+)
terragrunt hcl validate --inputs

# Initialize (required for validation)
terragrunt init

# Validate Terraform configuration
terragrunt validate

# Generate plan
terragrunt plan
```

### 3. Use `run --all` for Multi-Module Operations

> **Note:** `run-all` is deprecated. Use `run --all` instead.

```bash
# Validate all modules
terragrunt run --all validate

# Plan all modules
terragrunt run --all plan

# Apply all modules
terragrunt run --all apply

# With strict mode (errors on deprecated features)
terragrunt --strict-mode run --all plan

# Or via environment variable
TG_STRICT_MODE=true terragrunt run --all plan
```

## Performance Optimization

### 1. Use Shallow Dependencies

```hcl
dependency "vpc" {
  config_path = "../vpc"

  # Only fetch specific outputs
  mock_outputs_merge_strategy_with_state = "shallow"
}
```

### 2. Parallelize Operations

```bash
# Run operations in parallel (new syntax)
terragrunt run --all apply --parallelism 4

# Legacy syntax (deprecated)
# terragrunt run-all apply --terragrunt-parallelism=4
```

### 3. Use Caching

```hcl
# Cache downloaded modules
terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}
```

## Troubleshooting Common Issues

### Issue: Circular Dependencies

**Symptom:** "Cycle detected in dependency graph"

**Solution:**
- Review dependency chain
- Separate tightly coupled resources into single module
- Use data sources instead of dependencies where appropriate

### Issue: State Locking Errors

**Symptom:** "Error acquiring the state lock"

**Solution:**
```bash
# Force unlock (use with caution)
terragrunt force-unlock <LOCK_ID>
```

### Issue: Module Not Found

**Symptom:** "Module not found"

**Solution:**
```bash
# Clear cache and reinitialize
rm -rf .terragrunt-cache
terragrunt init
```

## Version Compatibility

### Terragrunt Version Constraints

Specify minimum Terragrunt version:
```hcl
# For new CLI features (recommended)
terragrunt_version_constraint = ">= 0.93.0"

# For backwards compatibility with older features
# terragrunt_version_constraint = ">= 0.48.0"
```

### Terraform Version Constraints

```hcl
terraform_version_constraint = ">= 1.6.0, < 2.0.0"
```

## References

- [Terragrunt Documentation](https://terragrunt.gruntwork.io/docs/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Gruntwork Production Framework](https://gruntwork.io/devops-checklist/)
