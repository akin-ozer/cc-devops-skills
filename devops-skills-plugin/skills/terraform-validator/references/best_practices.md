# Terraform Best Practices

Coding standards and best practices for writing maintainable, scalable, and reliable Terraform configurations.

## Project Structure

### Recommended Directory Layout

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── production/
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/
│   └── database/
├── global/
│   ├── iam/
│   └── route53/
└── README.md
```

### File Organization

**Standard Files:**
- `main.tf` - Primary resource definitions
- `variables.tf` - Input variable declarations
- `outputs.tf` - Output value declarations
- `versions.tf` - Terraform and provider version constraints
- `backend.tf` - Backend configuration
- `locals.tf` - Local value definitions (if many)
- `data.tf` - Data source definitions (if many)
- `terraform.tfvars` - Variable values (not committed for secrets)

**When to Split Files:**
- More than 200 lines in a single file
- Logical grouping of resources (e.g., `networking.tf`, `compute.tf`)
- Complex modules with many resource types

## Naming Conventions

### Resources

**Pattern:** `<resource-type>_<descriptive-name>`

```hcl
# Good
resource "aws_instance" "web_server" {}
resource "aws_s3_bucket" "application_logs" {}
resource "aws_security_group" "database_access" {}

# Avoid
resource "aws_instance" "instance1" {}
resource "aws_s3_bucket" "bucket" {}
```

### Variables

**Pattern:** `snake_case` with descriptive names

```hcl
# Good
variable "vpc_cidr_block" {}
variable "instance_type" {}
variable "environment_name" {}

# Avoid
variable "VPCCIDR" {}
variable "type" {}
variable "env" {}
```

### Modules

**Pattern:** `kebab-case` for directories, `snake_case` for module calls

```hcl
# Directory: modules/vpc-networking/

module "vpc_networking" {
  source = "./modules/vpc-networking"
}
```

### Tags

**Consistent Tagging Strategy:**

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = var.project_name
    Owner       = var.owner_email
    CostCenter  = var.cost_center
  }
}

resource "aws_instance" "web" {
  # ... other config ...

  tags = merge(local.common_tags, {
    Name = "${var.environment}-web-server"
    Role = "webserver"
  })
}
```

## Variable Management

### Variable Declarations

**Always Include:**
- Type constraints
- Descriptions
- Validation rules (when applicable)
- Default values (for non-sensitive, non-environment-specific values)

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

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "db_password" {
  description = "Database master password"
  type        = string
  sensitive   = true  # Prevents display in logs
}
```

### Variable Types

**Use Specific Types:**

```hcl
# Primitive types
variable "instance_count" {
  type = number
}

variable "enable_monitoring" {
  type = bool
}

# Collection types
variable "availability_zones" {
  type = list(string)
}

variable "tags" {
  type = map(string)
}

# Object types
variable "database_config" {
  type = object({
    engine         = string
    engine_version = string
    instance_class = string
    allocated_storage = number
  })
}
```

### Environment-Specific Variables

**Use .tfvars Files:**

```hcl
# environments/dev/terraform.tfvars
environment     = "dev"
instance_type   = "t3.micro"
instance_count  = 1
enable_backup   = false

# environments/production/terraform.tfvars
environment     = "production"
instance_type   = "t3.large"
instance_count  = 3
enable_backup   = true
```

## Module Design

### Module Best Practices

**Single Responsibility:**
Each module should have one clear purpose.

```hcl
# Good: Focused module
module "vpc" {
  source = "./modules/vpc"
  # VPC-specific config
}

# Avoid: Kitchen-sink module
module "infrastructure" {
  source = "./modules/everything"
  # VPC, databases, compute, monitoring, etc.
}
```

**Required vs Optional Variables:**

```hcl
# modules/database/variables.tf

# Required - no default
variable "database_name" {
  description = "Name of the database"
  type        = string
}

# Optional - has sensible default
variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}
```

**Output Everything Useful:**

```hcl
# modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}
```

### Module Documentation

**README.md Template:**

```markdown
# VPC Module

Creates a VPC with public and private subnets across multiple availability zones.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr             = "10.0.0.0/16"
  availability_zones   = ["us-east-1a", "us-east-1b"]
  environment          = "production"
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| aws | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vpc_cidr | CIDR block for VPC | `string` | n/a | yes |
| availability_zones | List of AZs | `list(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | ID of the VPC |
| private_subnet_ids | List of private subnet IDs |
```

## State Management

### Remote State

**Always Use Remote State for Teams:**

```hcl
terraform {
  backend "s3" {
    bucket         = "company-terraform-state"
    key            = "production/vpc/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-locks"

    # Workspace-specific state
    workspace_key_prefix = "workspaces"
  }
}
```

### State Locking

**DynamoDB Table for S3 Backend:**

```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name      = "Terraform State Locks"
    ManagedBy = "Terraform"
  }
}
```

### State Isolation

**Separate State Files by Environment and Component:**

```
s3://terraform-state/
├── production/
│   ├── vpc/terraform.tfstate
│   ├── database/terraform.tfstate
│   └── compute/terraform.tfstate
├── staging/
│   ├── vpc/terraform.tfstate
│   └── compute/terraform.tfstate
└── dev/
    └── all/terraform.tfstate
```

## Resource Management

### Use Data Sources for Existing Resources

```hcl
# Instead of hardcoding
resource "aws_instance" "web" {
  subnet_id = "subnet-12345"  # Avoid
}

# Use data sources
data "aws_subnet" "private" {
  filter {
    name   = "tag:Name"
    values = ["${var.environment}-private-subnet"]
  }
}

resource "aws_instance" "web" {
  subnet_id = data.aws_subnet.private.id
}
```

### Resource Dependencies

**Implicit Dependencies (Preferred):**

```hcl
resource "aws_instance" "web" {
  subnet_id         = aws_subnet.private.id  # Implicit dependency
  security_groups   = [aws_security_group.web.id]
}
```

**Explicit Dependencies (When Needed):**

```hcl
resource "aws_iam_role_policy" "example" {
  # ... config ...

  # Ensure role exists before attaching policy
  depends_on = [aws_iam_role.example]
}
```

### Count vs For_Each

**Use for_each for Map-Like Resources:**

```hcl
# Good: for_each with maps
locals {
  subnets = {
    public_a  = { cidr = "10.0.1.0/24", az = "us-east-1a" }
    public_b  = { cidr = "10.0.2.0/24", az = "us-east-1b" }
    private_a = { cidr = "10.0.3.0/24", az = "us-east-1a" }
    private_b = { cidr = "10.0.4.0/24", az = "us-east-1b" }
  }
}

resource "aws_subnet" "main" {
  for_each = local.subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.key
  }
}
```

**Use count for Simple Conditionals:**

```hcl
resource "aws_cloudwatch_log_group" "app" {
  count = var.enable_logging ? 1 : 0

  name = "/aws/app/logs"
}
```

## Version Constraints

### Terraform Version

```hcl
terraform {
  required_version = ">= 1.0, < 2.0"
}
```

### Provider Versions

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow patch updates, lock minor version
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}
```

**Version Constraint Operators:**
- `=` - Exact version
- `!=` - Exclude version
- `>`, `>=`, `<`, `<=` - Comparison
- `~>` - Pessimistic constraint (allow rightmost version component to increment)

## State Management Blocks

Terraform 1.1+ introduced declarative blocks for managing state without manual `terraform state` commands.

### Import Block (Terraform 1.5+)

The `import` block allows config-driven import of existing resources into Terraform state.

**Basic Usage:**
```hcl
# Import an existing VPC
import {
  to = aws_vpc.main
  id = "vpc-0123456789abcdef0"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}
```

**Dynamic Import (Terraform 1.6+):**
```hcl
# Import with expressions
variable "vpc_id" {
  type = string
}

import {
  to = aws_vpc.main
  id = var.vpc_id
}

# Import with string interpolation
import {
  to = aws_s3_bucket.logs
  id = "${var.environment}-logs-bucket"
}
```

**Generate Configuration:**
```bash
# Generate config for imported resources
terraform plan -generate-config-out=generated.tf
```

**Workflow:**
1. Add `import` block with target resource address and ID
2. Run `terraform plan` to see what will be imported
3. Add or generate the corresponding resource block
4. Run `terraform apply` to import
5. Remove the `import` block after successful import

### Moved Block (Terraform 1.1+)

The `moved` block enables refactoring without manual state manipulation.

**Rename a Resource:**
```hcl
# Old: aws_instance.web
# New: aws_instance.web_server

moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}

resource "aws_instance" "web_server" {
  ami           = "ami-12345678"
  instance_type = "t3.micro"
}
```

**Move to a Module:**
```hcl
# Move resource into a module
moved {
  from = aws_vpc.main
  to   = module.networking.aws_vpc.main
}

module "networking" {
  source = "./modules/networking"
}
```

**Move from count to for_each:**
```hcl
# Old: aws_instance.web[0], aws_instance.web[1]
# New: aws_instance.web["web-1"], aws_instance.web["web-2"]

moved {
  from = aws_instance.web[0]
  to   = aws_instance.web["web-1"]
}

moved {
  from = aws_instance.web[1]
  to   = aws_instance.web["web-2"]
}

resource "aws_instance" "web" {
  for_each = toset(["web-1", "web-2"])

  ami           = "ami-12345678"
  instance_type = "t3.micro"

  tags = {
    Name = each.key
  }
}
```

**Rename a Module:**
```hcl
moved {
  from = module.old_name
  to   = module.new_name
}

module "new_name" {
  source = "./modules/compute"
}
```

**Best Practices for moved:**
- Keep `moved` blocks until all team members have applied the changes
- Remove `moved` blocks after state migration is complete across all environments
- Use descriptive commit messages explaining the refactoring

### Removed Block (Terraform 1.7+)

The `removed` block allows declarative removal of resources from Terraform management.

**Remove Without Destroying:**
```hcl
# Stop managing resource but keep it in cloud
removed {
  from = aws_instance.legacy_server

  lifecycle {
    destroy = false
  }
}
```

**Remove and Destroy:**
```hcl
# Remove from state and destroy the resource
removed {
  from = aws_s3_bucket.old_logs

  lifecycle {
    destroy = true
  }
}
```

**Remove Module:**
```hcl
# Remove entire module from management
removed {
  from = module.deprecated_service

  lifecycle {
    destroy = false
  }
}
```

**Use Cases:**
- Migrating resource ownership to another team/state
- Removing resources that should persist but not be managed
- Cleaning up after manual resource creation
- Deprecating modules without destroying infrastructure

### State Block Comparison

| Block | Version | Purpose | Use Case |
|-------|---------|---------|----------|
| `import` | 1.5+ | Bring existing resources into Terraform | Adopting existing infrastructure |
| `moved` | 1.1+ | Refactor without state surgery | Renaming, restructuring modules |
| `removed` | 1.7+ | Stop managing resources declaratively | Ownership transfer, cleanup |

### Migration from CLI Commands

**Old Way (CLI):**
```bash
# Import
terraform import aws_vpc.main vpc-12345

# Move
terraform state mv aws_instance.web aws_instance.web_server

# Remove
terraform state rm aws_instance.legacy
```

**New Way (Config-Driven):**
```hcl
# All operations are declarative and version-controlled
import {
  to = aws_vpc.main
  id = "vpc-12345"
}

moved {
  from = aws_instance.web
  to   = aws_instance.web_server
}

removed {
  from = aws_instance.legacy
  lifecycle {
    destroy = false
  }
}
```

**Benefits of Config-Driven Approach:**
- Changes are code-reviewed and version-controlled
- Operations are repeatable and documented
- Team collaboration without state file conflicts
- Rollback capability through git history

## Code Quality

### Use Locals for Computed Values

```hcl
locals {
  name_prefix = "${var.environment}-${var.project}"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  # Computed values
  is_production = var.environment == "production"
  instance_type = local.is_production ? "t3.large" : "t3.micro"
}
```

### Dynamic Blocks

**Use Sparingly and Only When Necessary:**

```hcl
resource "aws_security_group" "example" {
  name = "example"

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

### Conditional Resources

```hcl
# Use count for conditional creation
resource "aws_kms_key" "encryption" {
  count = var.enable_encryption ? 1 : 0

  description = "Encryption key"
}

# Reference with [0] and handle with try()
resource "aws_s3_bucket" "example" {
  # ...

  kms_master_key_id = try(aws_kms_key.encryption[0].arn, null)
}
```

## Testing

### Validation

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Plan review
terraform plan

# Compliance testing
terraform-compliance -p terraform.plan -f compliance/
```

### Pre-Commit Hooks

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.83.0
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_docs
      - id: terraform_tflint
```

## Performance

### Reduce Plan Time

- Use targeted plans for large infrastructures: `terraform plan -target=module.vpc`
- Split large configurations into smaller state files
- Use `-parallelism` flag: `terraform apply -parallelism=20`

### Optimize Resource Queries

```hcl
# Cache data source results in locals
data "aws_ami" "ubuntu" {
  most_recent = true
  # ... filters ...
}

locals {
  ami_id = data.aws_ami.ubuntu.id
}

# Reuse local value
resource "aws_instance" "web" {
  count         = 10
  ami           = local.ami_id  # Don't repeat data source
  instance_type = var.instance_type
}
```

## Documentation

### Inline Comments

```hcl
# Create VPC with DNS support enabled for private hosted zones
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required for Route53 private zones
  enable_dns_support   = true

  tags = merge(local.common_tags, {
    Name = "${var.environment}-vpc"
  })
}
```

### Module Documentation

Use [terraform-docs](https://github.com/terraform-docs/terraform-docs) to auto-generate documentation:

```bash
terraform-docs markdown table . > README.md
```

## Security Best Practices

- Never commit `.tfstate` files
- Never commit `.tfvars` files with secrets
- Use `.gitignore`:
  ```
  .terraform/
  *.tfstate
  *.tfstate.backup
  *.tfvars
  .terraform.lock.hcl
  ```
- Use `sensitive = true` for sensitive variables and outputs
- Encrypt remote state
- Use least-privilege IAM policies
- Enable MFA for state bucket access

## Workflow

### Recommended Git Workflow

1. Create feature branch
2. Make changes
3. Run `terraform fmt`
4. Run `terraform validate`
5. Run `terraform plan` and review
6. Commit changes
7. Create pull request
8. Peer review
9. Merge to main
10. Apply in environment

### CI/CD Integration

```yaml
# .github/workflows/terraform.yml
name: Terraform

on: [pull_request]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2

      - name: Terraform Format
        run: terraform fmt -check -recursive

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        run: terraform plan
```
