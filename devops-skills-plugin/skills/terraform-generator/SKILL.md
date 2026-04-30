---
name: terraform-generator
description: Generate production-ready Terraform HCL — resources, modules, providers, variables, outputs. Use when the user asks to create, scaffold, write, or build Terraform configuration / .tf files / IaC for AWS, Azure, GCP, Kubernetes, or third-party providers. Triggers "write terraform for…", "scaffold a TF module", "create infra as code", "generate .tf", "set up a VPC in Terraform". Not for reviewing or debugging existing Terraform — see terraform-validator.
---

# Terraform Generator

## Overview

Generate production-ready Terraform configurations following current standards. Integrates validation and documentation lookup for custom providers and modules.

## When to Use This Skill

| Use terraform-generator | Use OTHER skill |
|-------------------------|-----------------|
| Create new .tf files / modules | **terraform-validator**: Validate, lint, or scan existing Terraform |
| Scaffold IaC for AWS/Azure/GCP/Kubernetes | **terragrunt-generator**: Generate Terragrunt wrappers |
| Add resources, variables, outputs to a fresh project | **k8s-yaml-generator**: Raw Kubernetes manifests (no Terraform) |
| Convert architecture into HCL | **helm-generator**: Helm charts |

### Trigger Phrases

- "write terraform for …"
- "scaffold a TF module"
- "create infra as code"
- "generate .tf for …"
- "set up a VPC in Terraform"
- "build IaC for …"

### Non-triggers

- "validate this terraform" / "lint .tf" / "fix terraform errors" — invoke `Skill(devops-skills:terraform-validator)`.
- "review my terraform plan output" — invoke `Skill(devops-skills:terraform-validator)`.

## Prerequisites

For the generation workflow itself, no tooling is required. The CI checks and validation loop need:

- `terraform` 1.8+ on PATH (used by `scripts/run_ci_checks.sh` for `terraform fmt -check`; install from https://developer.hashicorp.com/terraform/install)
- `shellcheck` (optional; the CI script gates on it when `STRICT_SHELLCHECK=true`; install via `apt install shellcheck` / `brew install shellcheck`)
- `bash` 4+ (for the CI script)

If `terraform` is missing, `scripts/run_ci_checks.sh` skips the fmt step and emits `SKIP (terraform not installed)` — install before running CI gates.

## Generation Workflow

| Step | Action |
|------|--------|
| 1 | Understand requirements (providers, resources, modules, version constraints) |
| 2 | If custom/third-party providers or modules are involved, look up version-specific docs |
| 3 | Consult reference files (see matrix below) |
| 4 | Generate `.tf` files following the patterns in this doc and `references/` |
| 5 | Include data sources for dynamic values (region, account, AMIs) |
| 6 | Add lifecycle rules on critical/stateful resources |
| 7 | Invoke `Skill(devops-skills:terraform-validator)` |
| 8 | Fix any validation/security failures and re-validate until clean |
| 9 | Provide usage instructions (files generated, init/plan/apply, security reminders) |

If validation fails (terraform validate or security scan), fix the issues and re-run validation until all checks pass before moving to Step 9.

### Step 1: Understand Requirements

Determine:
- Which infrastructure resources to create
- Which providers are required (AWS, Azure, GCP, Kubernetes, custom)
- Whether modules are involved (official, community, private)
- Version constraints
- Variable inputs and outputs
- Backend configuration (local, S3, remote)

### Step 2: Check for Custom Providers/Modules

**Standard providers** (no lookup needed): hashicorp/aws, hashicorp/azurerm, hashicorp/google, hashicorp/kubernetes, other official HashiCorp providers.

**Custom/third-party** (require documentation lookup): datadog/datadog, mongodb/mongodbatlas, terraform-aws-modules/*, private/company modules, community modules.

When custom providers or modules are detected:

1. Use WebSearch with the format: `"<provider/module> terraform <version> documentation <resource>"` (e.g. `"datadog terraform provider v3.30 monitor resource documentation"`).
2. Focus on registry.terraform.io, official provider docs, required/optional arguments, attribute references, examples, and version compatibility notes.
3. If Context7 MCP is available, prefer `Context7:resolve-library-id` -> `Context7:query-docs`.

### Step 3: Consult Reference Files

| Reference | When to read |
|-----------|--------------|
| `references/terraform_best_practices.md` | Always — baseline patterns |
| `references/provider_examples.md` | Any AWS, Azure, GCP, or Kubernetes resource |
| `references/common_patterns.md` | Multi-environment, workspace, composition, DR, conditional patterns |
| `references/modern_features.md` | Provider-defined functions, ephemeral, write-only, actions, query, version decisions |

Open by path:

```
devops-skills-plugin/skills/terraform-generator/references/terraform_best_practices.md
devops-skills-plugin/skills/terraform-generator/references/provider_examples.md
devops-skills-plugin/skills/terraform-generator/references/common_patterns.md
devops-skills-plugin/skills/terraform-generator/references/modern_features.md
```

### Step 4: Generate Terraform Configuration

**File organization:**

```
terraform-project/
├── main.tf           # Primary resource definitions
├── variables.tf      # Input variable declarations
├── outputs.tf        # Output value declarations
├── versions.tf       # Provider version constraints
├── terraform.tfvars  # Variable values (optional, for examples)
└── backend.tf        # Backend configuration (optional)
```

**Provider configuration:**

```hcl
terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"  # Major pin; verify exact current version when needed
    }
  }
}

provider "aws" {
  region = var.aws_region
}
```

**Resource naming:** descriptive, snake_case, include resource type when helpful.

```hcl
resource "aws_instance" "web_server" {
  # ...
}
```

**Variables with validation:**

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

**Outputs:**

```hcl
output "instance_public_ip" {
  description = "Public IP address of the web server"
  value       = aws_instance.web_server.public_ip
}
```

**Locals for computed values:**

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
  }
}
```

**Module usage** (always pin versions):

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

**Dynamic blocks for repeated configuration:**

```hcl
resource "aws_security_group" "example" {
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

**Security baseline:** never hardcode sensitive values, use data sources for AMIs and dynamic IDs, implement least-privilege IAM, enable encryption by default, use secure backends.

### Data Sources for Dynamic Values (provider-aware)

Include provider-appropriate data lookups for dynamic infrastructure values. Do not hardcode cloud/account/region/image IDs (why: prevents env drift and makes modules reusable across accounts/regions).

| Provider | Required Dynamic Context | Typical Data Sources |
|----------|--------------------------|----------------------|
| AWS | Region/account/AZ/image IDs | `aws_region`, `aws_caller_identity`, `aws_availability_zones`, `aws_ami` |
| Azure | Tenant/subscription/client context | `azurerm_client_config`, `azurerm_subscription` |
| GCP | Project/client context/zone discovery | `google_client_config`, `google_compute_zones`, `google_compute_image` |
| Kubernetes | Cluster endpoint/auth from trusted source | Module outputs or cloud data sources; avoid hardcoded tokens/endpoints |

```hcl
# AWS dynamic context
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Azure dynamic context
data "azurerm_client_config" "current" {}
data "azurerm_subscription" "current" {}

# GCP dynamic context
data "google_client_config" "current" {}
```

### Lifecycle and Deletion Safeguards (provider-aware)

For stateful and critical resources, you MUST set `lifecycle { prevent_destroy = true }` and the provider-native deletion-protection attribute (why: a stray `terraform destroy` against the wrong workspace can permanently delete production data; both gates are needed because `prevent_destroy` blocks Terraform deletion only, while service-level flags block out-of-band deletion).

| Provider | Critical Resource Classes | Required Protection Mechanism |
|----------|---------------------------|-------------------------------|
| AWS | KMS, RDS, S3 data buckets, DynamoDB, ElastiCache, secrets | `lifecycle { prevent_destroy = true }` + service-specific deletion protection |
| Azure | Key Vaults, SQL, Storage, stateful compute | `prevent_destroy` + provider feature flags / resource deletion protection |
| GCP | Cloud SQL, GKE, storage, stateful compute | `prevent_destroy` + `deletion_protection = true` where supported |
| Kubernetes | Stateful workloads and persistent data | Avoid destructive replacement patterns; protect backing cloud resources |

```hcl
resource "aws_db_instance" "main" {
  # ...
  deletion_protection = true
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_sql_database_instance" "main" {
  # ...
  deletion_protection = true
}
```

Before removing `prevent_destroy` or bumping `password_wo_version` (which rotates a database/secret), STOP and confirm with the user — both are destructive operations whose blast radius is not visible in the plan diff alone.

### Object Storage Lifecycle Safeguards

For AWS S3 lifecycle configuration you MUST include a rule to abort incomplete multipart uploads (why: orphaned parts accrue storage cost indefinitely and Checkov `CKV_AWS_300` enforces this).

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    filter {
      prefix = ""
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

For Azure / GCP object storage, add equivalent lifecycle/retention rules for stale objects and old versions.

### Step 5: Validate Generated Configuration

After generating files, invoke:

```
Skill(devops-skills:terraform-validator)
```

The validator runs `terraform fmt -check`, `terraform init`, `terraform validate`, and Checkov; on request it also runs `terraform plan`.

**Fix-and-revalidate loop:** if any check fails, review the error, edit the file to resolve it, re-invoke the validator, and repeat until all checks pass. Do not move to Step 6 with failing checks.

Common validation failures:

| Check | Issue | Fix |
|-------|-------|-----|
| `CKV_AWS_300` | Missing abort multipart upload | Add `abort_incomplete_multipart_upload` rule |
| `CKV_AWS_24` | SSH open to 0.0.0.0/0 | Restrict to specific CIDR |
| `CKV_AWS_16` | RDS encryption disabled | Add `storage_encrypted = true` |
| `terraform validate` | Invalid resource argument | Check provider docs (Context7 / WebSearch) |

If custom providers are detected during validation, the validator skill fetches docs automatically — use those to fix issues.

### Step 6: Provide Usage Instructions

After all checks pass, deliver:

```markdown
## Generated Files

| File | Description |
|------|-------------|
| `<actual-file-path>` | What was generated in that file |

(List only files actually generated; no placeholders.)

## Next Steps

1. Review and customize `terraform.tfvars` with your values
2. Initialize Terraform: `terraform init`
3. Review the execution plan: `terraform plan`
4. Apply the configuration: `terraform apply`

## Customization Notes

- [ ] Update `variable_name` in terraform.tfvars
- [ ] Configure backend in backend.tf for remote state
- [ ] Adjust resource names/tags as needed

## Security Reminders

Before applying:
- Review IAM policies and permissions
- Ensure sensitive values are NOT committed to version control
- Configure state backend with encryption enabled
- Set up state locking for team collaboration
```

## Common Generation Patterns

See `references/common_patterns.md` for worked examples (multi-environment, workspace, blue-green, data layer, module composition, conditional, service mesh, tagging, secret injection, auto-scaling, DR, cost optimization).

## Error Handling

1. **Provider not found:** ensure provider is in `required_providers`, verify `namespace/name`, check version constraint syntax.
2. **Invalid resource arguments:** consult provider docs (Context7 / WebSearch); check required vs optional; verify value types.
3. **Circular dependencies:** review references; use `depends_on` only when implicit refs cannot express the relation; consider splitting into modules.
4. **Validation failures:** invoke terraform-validator for detailed errors; fix one at a time; re-validate after each fix.

## Version Awareness

### Required Version Decision Rule

Apply this rule whenever emitting a `terraform { required_version = ... }` block:

- If generated configuration includes write-only arguments (`*_wo`): use `required_version = ">= 1.11, < 2.0"`.
- Else if it uses ephemeral constructs (`ephemeral` blocks, ephemeral variables/outputs) without write-only arguments: use `required_version = ">= 1.10, < 2.0"`.
- Otherwise: project baseline (default `>= 1.8, < 2.0`); for latest features (actions, query): `>= 1.14, < 2.0`.

### Version Feature Matrix (excerpt)

| Feature | Minimum Version |
|---------|-----------------|
| Ephemeral resources | 1.10+ |
| Write-only arguments | 1.11+ |

See `references/modern_features.md` for the complete feature matrix.

### Write-Only Arguments

Write-only arguments (`*_wo`) accept ephemeral values and are never persisted to state. They require Terraform 1.11+ and a `*_wo_version` companion to trigger rotation.

```hcl
terraform {
  required_version = ">= 1.11, < 2.0"
}

resource "aws_db_instance" "main" {
  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1
}
```

```hcl
# Negative: reject this pattern (write-only with Terraform 1.10)
terraform {
  required_version = ">= 1.10, < 2.0"
}

resource "aws_db_instance" "invalid" {
  password_wo = "do-not-generate-this"
}
```

For full positive examples, see `references/modern_features.md` ("Write-Only Arguments" section).

### Provider and Module Versions

- **Provider versions:** pin majors with `~>` (e.g. `~> 6.0` for AWS, `~> 4.0` for AzureRM, `~> 7.0` for Google). Do not claim "latest" without verifying online during the current run. Keep cross-provider language consistent across SKILL.md, `references/terraform_best_practices.md`, and `assets/minimal-project/versions.tf`.
- **Module versions:** always pin; review compatibility; test updates in non-production first.

## Resources

### references/

- `terraform_best_practices.md` — baseline patterns and required output shape
- `provider_examples.md` — AWS / Azure / GCP / Kubernetes example configs
- `common_patterns.md` — multi-env, workspace, composition, DR, conditional patterns
- `modern_features.md` — Terraform 1.8+ feature reference + version decision table

Open directly:

```
devops-skills-plugin/skills/terraform-generator/references/<filename>.md
```

### assets/

- `minimal-project/` — minimal Terraform project template; copy and customize.

## Notes

- Always invoke `Skill(devops-skills:terraform-validator)` after generation.
- For feature/version drift checks in CI, run `bash scripts/run_ci_checks.sh` (requires `terraform` for the fmt step; honors `STRICT_SHELLCHECK=true` to require shellcheck).
- WebSearch / Context7 is essential for custom providers/modules.
- Favor readability and least surprise; comment only where the WHY is non-obvious.
- Generate realistic example values in `terraform.tfvars` when helpful.
