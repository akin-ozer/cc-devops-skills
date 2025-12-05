# Terraform Best Practices

## Project Structure

### Standard Project Layout

```
terraform-project/
├── main.tf              # Primary resource definitions
├── variables.tf         # Input variable declarations
├── outputs.tf           # Output value declarations
├── versions.tf          # Terraform and provider version constraints
├── terraform.tfvars     # Variable values (gitignored if sensitive)
├── backend.tf           # Backend configuration (optional)
├── locals.tf            # Local values (optional)
├── data.tf              # Data source definitions (optional)
└── modules/             # Local modules (optional)
    └── networking/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Multi-Environment Structure

```
terraform-project/
├── modules/             # Reusable modules
│   └── vpc/
├── environments/        # Environment-specific configurations
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   └── production/
└── shared/              # Shared resources
```

## Naming Conventions

### Resource Naming

- Use snake_case for all names
- Be descriptive but concise
- Include resource type when helpful
- Avoid redundant prefixes

```hcl
# Good
resource "aws_instance" "web_server" {}
resource "aws_security_group" "web_server_sg" {}

# Avoid
resource "aws_instance" "aws_instance_web" {}
resource "aws_security_group" "sg" {}
```

### Variable Naming

- Use descriptive names
- Include units in name when applicable
- Use consistent naming across modules

```hcl
# Good
variable "instance_count" {}
variable "backup_retention_days" {}
variable "enable_encryption" {}

# Avoid
variable "count" {}
variable "retention" {}
variable "encrypt" {}
```

## Version Pinning

### Terraform Version

```hcl
terraform {
  required_version = ">= 1.8, < 2.0"  # Use 1.8+ for modern features
}
```

### Provider Versions

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow patch versions
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"   # Pin exact version if needed
    }
  }
}
```

### Module Versions

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"  # Always pin module versions
  # ...
}
```

## State Management

### Remote Backend Configuration

```hcl
# Modern S3 backend with native locking (Terraform 1.11+)
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true  # S3-native locking (recommended for 1.11+)
    kms_key_id   = "alias/terraform-state"
  }
}

# Legacy S3 backend with DynamoDB locking (Terraform < 1.11)
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "project/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"  # Deprecated in 1.11+
    kms_key_id     = "alias/terraform-state"
  }
}
```

### State Locking

Always use state locking for remote backends:
- S3: Use `use_lockfile = true` (Terraform 1.11+) or DynamoDB table (legacy)
- Azure Storage: Built-in locking
- GCS: Built-in locking

## Variable Management

### Variable Definitions

```hcl
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be from t2 or t3 family."
  }
}

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "At least 2 availability zones required."
  }
}
```

### Sensitive Variables

```hcl
variable "database_password" {
  description = "Password for database admin user"
  type        = string
  sensitive   = true
}

output "connection_string" {
  value     = "postgresql://user:${var.database_password}@${aws_db_instance.main.endpoint}"
  sensitive = true
}
```

### Variable Precedence

1. Environment variables (`TF_VAR_name`)
2. `terraform.tfvars` file
3. `terraform.tfvars.json` file
4. `*.auto.tfvars` files (alphabetical order)
5. `-var` and `-var-file` command-line flags
6. Default values in variable declarations

## Resource Management

### Dependencies

```hcl
# Implicit dependency (preferred)
resource "aws_eip" "example" {
  instance = aws_instance.web.id  # Implicit dependency
}

# Explicit dependency (when needed)
resource "aws_instance" "web" {
  # ...

  depends_on = [
    aws_iam_role_policy.example
  ]
}
```

### Lifecycle Rules

```hcl
resource "aws_instance" "web" {
  # ...

  lifecycle {
    create_before_destroy = true  # Create replacement before destroying
    prevent_destroy       = true  # Prevent accidental deletion
    ignore_changes = [            # Ignore external changes
      tags["LastModified"],
      user_data,
    ]
  }
}
```

### Provisioners (Use Sparingly)

```hcl
resource "aws_instance" "web" {
  # ...

  provisioner "local-exec" {
    command = "echo ${self.private_ip} >> private_ips.txt"

    on_failure = continue  # Continue if provisioner fails
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }

    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y nginx",
    ]
  }
}
```

## Data Sources

### Using Data Sources

```hcl
# Fetch latest AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Reference in resource
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
}

# Fetch availability zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Use in resources
resource "aws_subnet" "private" {
  count             = length(data.aws_availability_zones.available.names)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  # ...
}
```

## Local Values

### Using Locals

```hcl
locals {
  # Common tags
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    CostCenter  = var.cost_center
  }

  # Computed values
  az_count        = length(data.aws_availability_zones.available.names)
  subnet_count    = var.subnet_count != null ? var.subnet_count : local.az_count

  # Complex expressions
  instance_name   = "${var.project_name}-${var.environment}-web"

  # Conditional values
  instance_type = var.environment == "production" ? "t3.large" : "t3.micro"

  # Map transformations
  subnet_cidrs = {
    for idx, az in data.aws_availability_zones.available.names :
    az => cidrsubnet(var.vpc_cidr, 8, idx)
  }
}
```

## Dynamic Blocks

### Dynamic Block Patterns

```hcl
# Dynamic ingress rules
resource "aws_security_group" "web" {
  name_prefix = "web-"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = var.ingress_rules

    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  tags = local.common_tags
}

# Variable definition
variable "ingress_rules" {
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))

  default = [
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "HTTPS"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

## Count and For_Each

### Using Count

```hcl
# Create multiple similar resources
resource "aws_instance" "web" {
  count = var.instance_count

  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  subnet_id     = element(aws_subnet.private[*].id, count.index)

  tags = merge(
    local.common_tags,
    {
      Name = "${local.instance_name}-${count.index + 1}"
    }
  )
}
```

### Using For_Each

```hcl
# Create resources from map
resource "aws_iam_user" "users" {
  for_each = toset(var.user_names)

  name = each.value

  tags = {
    Team = lookup(var.user_teams, each.value, "default")
  }
}

# Create resources with different configurations
variable "environments" {
  type = map(object({
    instance_type = string
    instance_count = number
  }))

  default = {
    dev = {
      instance_type  = "t3.micro"
      instance_count = 1
    }
    prod = {
      instance_type  = "t3.large"
      instance_count = 3
    }
  }
}

resource "aws_instance" "env_servers" {
  for_each = var.environments

  ami           = data.aws_ami.ubuntu.id
  instance_type = each.value.instance_type
  count         = each.value.instance_count

  tags = {
    Name        = "${each.key}-server"
    Environment = each.key
  }
}
```

## Module Best Practices

### Module Structure

```
module/
├── main.tf              # Main resources
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── versions.tf          # Version constraints
├── README.md            # Documentation
└── examples/            # Usage examples
    └── complete/
        ├── main.tf
        └── variables.tf
```

### Module Input Variables

```hcl
# modules/vpc/variables.tf
variable "name" {
  description = "Name to be used on all resources"
  type        = string
}

variable "cidr" {
  description = "CIDR block for VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr, 0))
    error_message = "Must be valid IPv4 CIDR."
  }
}

variable "enable_nat_gateway" {
  description = "Should be true to provision NAT Gateways"
  type        = bool
  default     = true
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}
```

### Module Outputs

```hcl
# modules/vpc/outputs.tf
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}
```

### Using Modules

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.0"

  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = data.aws_availability_zones.available.names
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = local.common_tags
}

# Reference module outputs
resource "aws_instance" "web" {
  subnet_id = module.vpc.private_subnet_ids[0]
  # ...
}
```

## Security Best Practices

### Secrets Management

```hcl
# NEVER hardcode secrets
# BAD
resource "aws_db_instance" "database" {
  password = "supersecretpassword"  # NEVER DO THIS
}

# GOOD - Use variables
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "database" {
  password = var.db_password
}

# BETTER - Use secrets management service
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/database/password"
}

resource "aws_db_instance" "database" {
  password = jsondecode(data.aws_secretsmanager_secret_version.db_password.secret_string)["password"]
}
```

### Encryption

```hcl
# Enable encryption by default
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.data.arn
    }
  }
}

# Encrypt EBS volumes
resource "aws_instance" "web" {
  # ...

  root_block_device {
    encrypted   = true
    kms_key_id  = aws_kms_key.data.arn
    volume_type = "gp3"
  }
}
```

### IAM Policies

```hcl
# Use least privilege principle
data "aws_iam_policy_document" "lambda_execution" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.function_name}:*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.data.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "lambda_execution" {
  name   = "${var.function_name}-execution"
  policy = data.aws_iam_policy_document.lambda_execution.json
}
```

## Testing and Validation

### Input Validation

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  type = number

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}
```

### Pre-commit Hooks

Use terraform fmt and terraform validate in pre-commit hooks:

```bash
#!/bin/bash
# .git/hooks/pre-commit

terraform fmt -check -recursive || exit 1
terraform validate || exit 1
```

## Documentation

### Code Comments

```hcl
# Create VPC for application infrastructure
# This VPC uses a /16 CIDR block to accommodate multiple subnets
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true  # Required for ECS task networking
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-vpc"
    }
  )
}
```

### README Documentation

Include in project README:
- Purpose of the infrastructure
- Prerequisites
- Required variables
- Usage examples
- Output descriptions
- How to run terraform commands
- Maintenance notes

## Performance Optimization

### Parallel Resource Creation

Terraform automatically parallelizes resource creation when possible. Help it by:
- Avoiding unnecessary dependencies
- Using data sources efficiently
- Structuring modules properly

### State File Optimization

- Use targeted operations when possible: `terraform apply -target=resource`
- Split large configurations into multiple state files
- Use workspaces for similar environments
- Consider using `-refresh=false` when appropriate

### Provider Plugin Caching

```bash
# ~/.terraformrc or terraform.rc
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
```

## Common Pitfalls to Avoid

1. **Hardcoding values** - Use variables and data sources
2. **Not pinning versions** - Always pin provider and module versions
3. **Ignoring state** - Never edit state files manually
4. **Circular dependencies** - Structure resources properly
5. **Overly complex modules** - Keep modules focused and simple
6. **Not using remote state** - Always use remote state for team collaboration
7. **Forgetting state locking** - Always use state locking mechanism
8. **Mixing concerns** - Separate infrastructure layers (network, compute, data)
9. **Not validating inputs** - Use validation blocks for variables
10. **Ignoring costs** - Tag resources appropriately for cost tracking
