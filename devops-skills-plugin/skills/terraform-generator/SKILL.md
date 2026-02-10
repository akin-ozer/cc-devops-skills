---
name: terraform-generator
description: Comprehensive toolkit for generating best practice Terraform configurations (HCL files) following current standards and conventions. Use this skill when creating new Terraform resources, or building Terraform projects.
---

# Terraform Generator

## Overview

This skill enables the generation of production-ready Terraform configurations following best practices and current standards. Automatically integrates validation and documentation lookup for custom providers and modules.

## Critical Requirements Checklist

**STOP: You MUST complete ALL steps in order. Do NOT skip any REQUIRED step.**

| Step | Action | Required |
|------|--------|----------|
| 1 | Understand requirements (providers, resources, modules) | ✅ REQUIRED |
| 2 | Check for custom providers/modules and lookup documentation | ✅ REQUIRED |
| 3 | Consult reference files before generation | ✅ REQUIRED |
| 4 | Generate Terraform files with ALL best practices | ✅ REQUIRED |
| 5 | Include data sources for dynamic values (region, account, AMIs) | ✅ REQUIRED |
| 6 | Add lifecycle rules on critical resources (KMS, databases) | ✅ REQUIRED |
| 7 | Invoke `Skill(devops-skills:terraform-validator)` | ✅ REQUIRED |
| 8 | **FIX all validation/security failures and RE-VALIDATE** | ✅ REQUIRED |
| 9 | Provide usage instructions (files, next steps, security) | ✅ REQUIRED |

> **IMPORTANT:** If validation fails (terraform validate OR security scan), you MUST fix the issues and re-run validation until ALL checks pass. Do NOT proceed to Step 9 with failing checks.

## Core Workflow

When generating Terraform configurations, follow this workflow:

### Step 1: Understand Requirements

Analyze the user's request to determine:
- What infrastructure resources need to be created
- Which Terraform providers are required (AWS, Azure, GCP, custom, etc.)
- Whether any modules are being used (official, community, or custom)
- Version constraints for providers and modules
- Variable inputs and outputs needed
- State backend configuration (local, S3, remote, etc.)

### Step 2: Check for Custom Providers/Modules

Before generating configurations, identify if custom or third-party providers/modules are involved:

**Standard providers** (no lookup needed):
- hashicorp/aws
- hashicorp/azurerm
- hashicorp/google
- hashicorp/kubernetes
- Other official HashiCorp providers

**Custom/third-party providers/modules** (require documentation lookup):
- Third-party providers (e.g., datadog/datadog, mongodb/mongodbatlas)
- Custom modules from Terraform Registry
- Private or company-specific modules
- Community modules

**When custom providers/modules are detected:**

1. Use WebSearch to find version-specific documentation:
   ```
   Search query format: "[provider/module name] terraform [version] documentation [specific resource]"
   Example: "datadog terraform provider v3.30 monitor resource documentation"
   Example: "terraform-aws-modules vpc version 5.0 documentation"
   ```

2. Focus searches on:
   - Official documentation (registry.terraform.io, provider websites)
   - Required and optional arguments
   - Attribute references
   - Example usage
   - Version compatibility notes

3. If Context7 MCP is available and the provider/module is supported, use it as an alternative:
   ```
   mcp__context7__resolve-library-id → mcp__context7__get-library-docs
   ```

### Step 2.5: Consult Reference Files (REQUIRED)

Before generating configuration, you MUST read the relevant reference files:

```
Read(file_path: ".claude/skills/terraform-generator/references/terraform_best_practices.md")
Read(file_path: ".claude/skills/terraform-generator/references/provider_examples.md")
```

**When to consult each reference:**
| Reference | Read When |
|-----------|-----------|
| `terraform_best_practices.md` | Always - contains required patterns |
| `common_patterns.md` | Multi-environment, workspace, or complex setups |
| `provider_examples.md` | Generating AWS, Azure, GCP, or K8s resources |

### Step 3: Generate Terraform Configuration

Generate HCL files following best practices:

**File Organization:**
```
terraform-project/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Provider version constraints
├── terraform.tfvars  # Variable values (optional, for examples)
└── backend.tf        # Backend configuration (optional)
```

**Best Practices to Follow:**

1. **Provider Configuration:**
   ```hcl
   terraform {
     required_version = ">= 1.10, < 2.0"

     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "~> 6.0"  # Latest: v6.23.0 (Dec 2025)
       }
     }
   }

   provider "aws" {
     region = var.aws_region
   }
   ```

2. **Resource Naming:**
   - Use descriptive resource names
   - Follow snake_case convention
   - Include resource type in name when helpful
   ```hcl
   resource "aws_instance" "web_server" {
     # ...
   }
   ```

3. **Variable Declarations:**
   ```hcl
   variable "instance_type" {
     description = "EC2 instance type for web servers"
     type        = string
     default     = "t3.micro"

     validation {
       condition     = contains(["t3.micro", "t3.small", "t3.medium"], var.instance_type)
       error_message = "Instance type must be t3.micro, t3.small, or t3.medium."
     }
   }
   ```

4. **Output Values:**
   ```hcl
   output "instance_public_ip" {
     description = "Public IP address of the web server"
     value       = aws_instance.web_server.public_ip
   }
   ```

5. **Use Data Sources for References:**
   ```hcl
   data "aws_ami" "ubuntu" {
     most_recent = true
     owners      = ["099720109477"] # Canonical

     filter {
       name   = "name"
       values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
     }
   }
   ```

6. **Module Usage:**
   ```hcl
   module "vpc" {
     source  = "terraform-aws-modules/vpc/aws"
     version = "5.0.0"

     name = "my-vpc"
     cidr = "10.0.0.0/16"

     azs             = ["us-east-1a", "us-east-1b"]
     private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
     public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
   }
   ```

7. **Use locals for Computed Values:**
   ```hcl
   locals {
     common_tags = {
       Environment = var.environment
       ManagedBy   = "Terraform"
       Project     = var.project_name
     }
   }
   ```

8. **Lifecycle Rules When Appropriate:**
   ```hcl
   resource "aws_instance" "example" {
     # ...

     lifecycle {
       create_before_destroy = true
       prevent_destroy       = true
       ignore_changes        = [tags]
     }
   }
   ```

9. **Dynamic Blocks for Repeated Configuration:**
   ```hcl
   resource "aws_security_group" "example" {
     # ...

     dynamic "ingress" {
       for_each = var.ingress_rules
       content {
         from_port   = ingress.value.from_port
         to_port     = ingress.value.to_port
         protocol    = ingress.value.protocol
         cidr_blocks = ingress.value.cidr_blocks
       }
     }
   }
   ```

10. **Comments and Documentation:**
    - Add comments explaining complex logic
    - Document why certain values are used
    - Include examples in variable descriptions

**Security Best Practices:**
- Never hardcode sensitive values (use variables)
- Use data sources for AMIs and other dynamic values
- Implement least-privilege IAM policies
- Enable encryption by default
- Use secure backend configurations

### Required: Data Sources for Dynamic Values

You MUST include data sources for dynamic infrastructure values. Do NOT hardcode these:

```hcl
# REQUIRED: Current AWS region and account info
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Use in resources
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}
```

**Common required data sources:**
| Use Case | Data Source |
|----------|-------------|
| Current region | `data "aws_region" "current" {}` |
| Current account | `data "aws_caller_identity" "current" {}` |
| Available AZs | `data "aws_availability_zones" "available" {}` |
| Latest AMI | `data "aws_ami" "..."` with filters |
| Existing VPC | `data "aws_vpc" "..."` |

### Required: Lifecycle Rules on Critical Resources

You MUST add lifecycle rules on resources that could cause data loss or service disruption if accidentally destroyed:

```hcl
# KMS Keys - ALWAYS protect from deletion
resource "aws_kms_key" "encryption" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}

# Databases - ALWAYS protect from deletion
resource "aws_db_instance" "main" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}

# S3 Buckets with data - protect from deletion
resource "aws_s3_bucket" "data" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

**Resources that MUST have `prevent_destroy = true`:**
- KMS keys (`aws_kms_key`)
- RDS databases (`aws_db_instance`, `aws_rds_cluster`)
- S3 buckets containing data
- DynamoDB tables with data
- ElastiCache clusters
- Secrets Manager secrets

### Required: S3 Lifecycle Best Practices

When creating S3 buckets with lifecycle configurations, ALWAYS include a rule to abort incomplete multipart uploads:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  # REQUIRED: Abort incomplete multipart uploads to prevent storage costs
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    # Filter applies to all objects (empty filter = all objects)
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # Other lifecycle rules (e.g., transition to IA)
  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {
      prefix = ""  # Apply to all objects
    }

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }
  }
}
```

> **Why?** Incomplete multipart uploads consume storage and incur costs. Checkov check `CKV_AWS_300` enforces this. Always include this rule.

### Step 4: Validate Generated Configuration (REQUIRED)

After generating Terraform files, ALWAYS validate them using the devops-skills:terraform-validator skill:

```
Invoke: Skill(devops-skills:terraform-validator)
```

The devops-skills:terraform-validator skill will:
1. Check HCL syntax with `terraform fmt -check`
2. Initialize the configuration with `terraform init`
3. Validate the configuration with `terraform validate`
4. Run security scan with Checkov
5. Perform dry-run testing (if requested) with `terraform plan`

**CRITICAL: Fix-and-Revalidate Loop**

If ANY validation or security check fails, you MUST:

1. **Review the error** - Understand what failed and why
2. **Fix the issue** - Edit the generated file to resolve the problem
3. **Re-run validation** - Invoke `Skill(devops-skills:terraform-validator)` again
4. **Repeat until ALL checks pass** - Do NOT proceed with failing checks

```
┌─────────────────────────────────────────────────────────┐
│  VALIDATION FAILED?                                      │
│                                                          │
│  ┌─────────┐    ┌─────────┐    ┌─────────────────────┐  │
│  │  Fix    │───▶│ Re-run  │───▶│ All checks pass?    │  │
│  │  Issue  │    │ Skill   │    │ YES → Step 5        │  │
│  └─────────┘    └─────────┘    │ NO  → Loop back     │  │
│       ▲                         └─────────────────────┘  │
│       │                                    │             │
│       └────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────┘
```

**Common validation failures to fix:**
| Check | Issue | Fix |
|-------|-------|-----|
| `CKV_AWS_300` | Missing abort multipart upload | Add `abort_incomplete_multipart_upload` rule |
| `CKV_AWS_24` | SSH open to 0.0.0.0/0 | Restrict to specific CIDR |
| `CKV_AWS_16` | RDS encryption disabled | Add `storage_encrypted = true` |
| `terraform validate` | Invalid resource argument | Check provider documentation |

**If custom providers are detected during validation:**
- The devops-skills:terraform-validator skill will automatically fetch documentation
- Use the fetched documentation to fix any issues

### Step 5: Provide Usage Instructions (REQUIRED)

After successful generation and validation with ALL checks passing, you MUST provide the user with:

**Required Output Format:**

```markdown
## Generated Files

| File | Description |
|------|-------------|
| `path/to/main.tf` | Main resource definitions |
| `path/to/variables.tf` | Input variables |
| `path/to/outputs.tf` | Output values |
| `path/to/versions.tf` | Provider version constraints |

## Next Steps

1. Review and customize `terraform.tfvars` with your values
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review the execution plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```

## Customization Notes

- [ ] Update `variable_name` in terraform.tfvars
- [ ] Configure backend in backend.tf for remote state
- [ ] Adjust resource names/tags as needed

## Security Reminders

⚠️ Before applying:
- Review IAM policies and permissions
- Ensure sensitive values are NOT committed to version control
- Configure state backend with encryption enabled
- Set up state locking for team collaboration
```

> **IMPORTANT:** Do NOT skip Step 5. The user needs actionable guidance on how to use the generated configuration.

## Common Generation Patterns

### Pattern 1: Simple Resource Creation

User request: "Create an AWS S3 bucket with versioning"

Generated files:
- `main.tf` - S3 bucket resource with versioning enabled
- `variables.tf` - Bucket name, tags variables
- `outputs.tf` - Bucket ARN and name outputs
- `versions.tf` - AWS provider version constraints

### Pattern 2: Module-Based Infrastructure

User request: "Set up a VPC using the official AWS VPC module"

Actions:
1. Identify module: terraform-aws-modules/vpc/aws
2. Web search for latest version and documentation
3. Generate configuration using module with appropriate inputs
4. Validate with devops-skills:terraform-validator

### Pattern 3: Multi-Provider Configuration

User request: "Create infrastructure across AWS and Datadog"

Actions:
1. Identify standard provider (AWS) and custom provider (Datadog)
2. Web search for Datadog provider documentation with version
3. Generate configuration with both providers properly configured
4. Ensure provider aliases if needed
5. Validate with devops-skills:terraform-validator

### Pattern 4: Complex Resource with Dependencies

User request: "Create an ECS cluster with ALB and auto-scaling"

Generated structure:
- Multiple resource blocks with proper dependencies
- Data sources for AMIs, availability zones, etc.
- Local values for computed configurations
- Comprehensive variables and outputs
- Proper dependency management using implicit references

## Error Handling

**Common Issues and Solutions:**

1. **Provider Not Found:**
   - Ensure provider is listed in `required_providers` block
   - Verify source address format: `namespace/name`
   - Check version constraint syntax

2. **Invalid Resource Arguments:**
   - Refer to web search results for custom providers
   - Check for required vs optional arguments
   - Verify attribute value types (string, number, bool, list, map)

3. **Circular Dependencies:**
   - Review resource references
   - Use `depends_on` explicit dependencies if needed
   - Consider breaking into separate modules

4. **Validation Failures:**
   - Run devops-skills:terraform-validator skill to get detailed errors
   - Fix issues one at a time
   - Re-validate after each fix

## Version Awareness

Always consider version compatibility:

1. **Terraform Version:**
   - Use `required_version` constraint with both lower and upper bounds
   - Default to `>= 1.10, < 2.0` for modern features (ephemeral resources, write-only)
   - Use `>= 1.14, < 2.0` for latest features (actions, query command)
   - Document any version-specific features used (see below)

2. **Provider Versions (as of December 2025):**
   - AWS: `~> 6.0` (latest: v6.23.0)
   - Azure: `~> 4.0` (latest: v4.54.0)
   - GCP: `~> 7.0` (latest: v7.12.0) - 7.0 includes ephemeral resources & write-only attributes
   - Kubernetes: `~> 2.23`
   - Use `~>` for minor version flexibility, pin major versions

3. **Module Versions:**
   - Always pin module versions
   - Review module documentation for version compatibility
   - Test module updates in non-production first

### Terraform Version Feature Matrix

| Feature | Minimum Version |
|---------|-----------------|
| `terraform_data` resource | 1.4+ |
| `import {}` blocks | 1.5+ |
| `check {}` blocks | 1.5+ |
| Native testing (`.tftest.hcl`) | 1.6+ |
| Test mocking | 1.7+ |
| `removed {}` blocks | 1.7+ |
| Provider-defined functions | 1.8+ |
| Cross-type refactoring | 1.8+ |
| Enhanced variable validations | 1.9+ |
| `templatestring` function | 1.9+ |
| Ephemeral resources | 1.10+ |
| Write-only arguments | 1.11+ |
| S3 native state locking | 1.11+ |
| Import blocks with `for_each` | 1.12+ |
| Actions block | 1.14+ |
| List resources (`tfquery.hcl`) | 1.14+ |
| `terraform query` command | 1.14+ |

## Modern Terraform Features (1.8+)

### Provider-Defined Functions (Terraform 1.8+)

Provider-defined functions extend Terraform's built-in functions with provider-specific logic.

**Syntax:** `provider::<provider_name>::<function_name>(arguments)`

```hcl
# AWS Provider Functions (v5.40+)
locals {
  # Parse an ARN into components
  parsed_arn = provider::aws::arn_parse(aws_instance.web.arn)
  account_id = local.parsed_arn.account
  region     = local.parsed_arn.region

  # Build an ARN from components
  custom_arn = provider::aws::arn_build({
    partition = "aws"
    service   = "s3"
    region    = ""
    account   = ""
    resource  = "my-bucket/my-key"
  })
}

# Google Cloud Provider Functions (v5.23+)
locals {
  # Extract region from zone
  region = provider::google::region_from_zone(var.zone)  # "us-west1-a" → "us-west1"
}

# Kubernetes Provider Functions (v2.28+)
locals {
  # Encode HCL to Kubernetes manifest YAML
  manifest_yaml = provider::kubernetes::manifest_encode(local.deployment_config)
}
```

### Ephemeral Resources (Terraform 1.10+)

Ephemeral resources provide temporary values that are **never persisted** in state or plan files. Critical for handling secrets securely.

```hcl
# Generate a password that never touches state
ephemeral "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Fetch secrets ephemerally from AWS Secrets Manager
ephemeral "aws_secretsmanager_secret_version" "api_key" {
  secret_id = aws_secretsmanager_secret.api_key.id
}

# Ephemeral variables (declare with ephemeral = true)
variable "temporary_token" {
  type      = string
  ephemeral = true  # Value won't be stored in state
}

# Ephemeral outputs
output "session_token" {
  value     = ephemeral.aws_secretsmanager_secret_version.api_key.secret_string
  ephemeral = true  # Won't be stored in state
}
```

### Write-Only Arguments (Terraform 1.11+)

Write-only arguments accept ephemeral values and are never persisted. They use `_wo` suffix and require a version attribute.

```hcl
# Secure database password handling
ephemeral "random_password" "db_password" {
  length = 16
}

resource "aws_db_instance" "main" {
  identifier        = "mydb"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  engine            = "postgres"
  username          = "admin"

  # Write-only password - never stored in state!
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1  # Increment to trigger password rotation

  skip_final_snapshot = true
}

# Secrets Manager with write-only
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  # Write-only secret string
  secret_string_wo         = ephemeral.random_password.db_password.result
  secret_string_wo_version = 1
}
```

### Enhanced Variable Validations (Terraform 1.9+)

Validation conditions can now reference other variables, data sources, and local values.

```hcl
# Reference data sources in validation
data "aws_ec2_instance_type_offerings" "available" {
  filter {
    name   = "location"
    values = [var.availability_zone]
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"

  validation {
    # NEW: Can reference data sources
    condition = contains(
      data.aws_ec2_instance_type_offerings.available.instance_types,
      var.instance_type
    )
    error_message = "Instance type ${var.instance_type} is not available in the selected AZ."
  }
}

# Cross-variable validation
variable "min_instances" {
  type    = number
  default = 1
}

variable "max_instances" {
  type    = number
  default = 10

  validation {
    # NEW: Can reference other variables
    condition     = var.max_instances >= var.min_instances
    error_message = "max_instances must be >= min_instances"
  }
}
```

### S3 Native State Locking (Terraform 1.11+)

S3 now supports native state locking without DynamoDB.

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true

    # NEW: S3-native locking (Terraform 1.11+)
    use_lockfile = true

    # DEPRECATED: DynamoDB locking (still works but no longer required)
    # dynamodb_table = "terraform-locks"
  }
}
```

### Import Blocks (Terraform 1.5+)

Declarative resource imports without command-line operations.

```hcl
# Import existing resources declaratively
import {
  to = aws_instance.web
  id = "i-1234567890abcdef0"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  # ... configuration must match existing resource
}

# Import with for_each
import {
  for_each = var.existing_bucket_names
  to       = aws_s3_bucket.imported[each.key]
  id       = each.value
}
```

### Moved and Removed Blocks

Safely refactor resources without destroying them.

```hcl
# Rename a resource
moved {
  from = aws_instance.old_name
  to   = aws_instance.new_name
}

# Move to a module
moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

# Cross-type refactoring (1.8+)
moved {
  from = null_resource.example
  to   = terraform_data.example
}

# Remove resource from state without destroying (1.7+)
removed {
  from = aws_instance.legacy

  lifecycle {
    destroy = false  # Keep the actual resource, just remove from state
  }
}
```

### Import Blocks with for_each (Terraform 1.12+)

Import multiple resources using `for_each` meta-argument.

```hcl
# Import multiple S3 buckets using a map
locals {
  buckets = {
    "staging" = "bucket1"
    "uat"     = "bucket2"
    "prod"    = "bucket3"
  }
}

import {
  for_each = local.buckets
  to       = aws_s3_bucket.this[each.key]
  id       = each.value
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets
}

# Import across module instances using list of objects
locals {
  module_buckets = [
    { group = "one", key = "bucket1", id = "one_1" },
    { group = "one", key = "bucket2", id = "one_2" },
    { group = "two", key = "bucket1", id = "two_1" },
  ]
}

import {
  for_each = local.module_buckets
  id       = each.value.id
  to       = module.group[each.value.group].aws_s3_bucket.this[each.value.key]
}
```

### Actions Block (Terraform 1.14+)

Actions enable provider-defined operations outside the standard CRUD model. Use for operations like Lambda invocations, cache invalidations, or database backups.

```hcl
# Invoke a Lambda function (example syntax)
action "aws_lambda_invoke" "process_data" {
  function_name = aws_lambda_function.processor.function_name
  payload       = jsonencode({ action = "process" })
}

# Create CloudFront invalidation
action "aws_cloudfront_create_invalidation" "invalidate_cache" {
  distribution_id = aws_cloudfront_distribution.main.id
  paths           = ["/*"]
}

# Actions support for_each
action "aws_lambda_invoke" "batch_process" {
  for_each = toset(["task1", "task2", "task3"])

  function_name = aws_lambda_function.processor.function_name
  payload       = jsonencode({ task = each.value })
}
```

**Triggering Actions via Lifecycle:**

Use `action_trigger` within a resource's lifecycle block to automatically invoke actions:

```hcl
resource "aws_lambda_function" "example" {
  function_name = "my-function"
  # ... other config ...

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aws_lambda_invoke.process_data]
    }
  }
}

action "aws_lambda_invoke" "process_data" {
  function_name = aws_lambda_function.example.function_name
  payload       = jsonencode({ action = "initialize" })
}
```

**Manual Invocation:**

Actions can also be invoked manually via CLI:

```bash
terraform apply -invoke action.aws_lambda_invoke.process_data
```

### List Resources and Query Command (Terraform 1.14+)

Query and filter existing infrastructure using `.tfquery.hcl` files and the `terraform query` command.

```hcl
# my-resources.tfquery.hcl
# Define list resources to query existing infrastructure

list "aws_instance" "web_servers" {
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

  include_resource = true  # Include full resource details
}

list "aws_s3_bucket" "data_buckets" {
  filter {
    name   = "tag:Purpose"
    values = ["data-storage"]
  }
}
```

```bash
# Query infrastructure and output results
terraform query

# Generate import configuration from query results
terraform query -generate-config-out="import_config.tf"

# Output in JSON format
terraform query -json

# Use with variables
terraform query -var 'environment=prod'
```

### Preconditions and Postconditions (Terraform 1.5+)

Add custom validation within resource lifecycle.

```hcl
resource "aws_instance" "example" {
  instance_type = "t3.micro"
  ami           = data.aws_ami.example.id

  lifecycle {
    # Check before creation
    precondition {
      condition     = data.aws_ami.example.architecture == "x86_64"
      error_message = "The selected AMI must be for the x86_64 architecture."
    }

    # Verify after creation
    postcondition {
      condition     = self.public_dns != ""
      error_message = "EC2 instance must be in a VPC that has public DNS hostnames enabled."
    }
  }
}

# Preconditions on outputs
output "web_url" {
  value = "https://${aws_instance.web.public_dns}"

  precondition {
    condition     = aws_instance.web.public_dns != ""
    error_message = "Instance must have a public DNS name."
  }
}
```

## Resources

### references/

The `references/` directory contains detailed documentation for reference:

- `terraform_best_practices.md` - Comprehensive best practices guide
- `common_patterns.md` - Common Terraform patterns and examples
- `provider_examples.md` - Example configurations for popular providers

To load a reference, use the Read tool:
```
Read(file_path: ".claude/skills/terraform-generator/references/[filename].md")
```

### assets/

The `assets/` directory contains template files:

- `minimal-project/` - Minimal Terraform project template
- `aws-web-app/` - AWS web application infrastructure template
- `multi-env/` - Multi-environment configuration template

Templates can be copied and customized for the user's specific needs.

## Notes

- Always run devops-skills:terraform-validator after generation
- Web search is essential for custom providers/modules
- Follow the principle of least surprise in configurations
- Make configurations readable and maintainable
- Include helpful comments and documentation
- Generate realistic examples in terraform.tfvars when helpful
