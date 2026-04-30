# Modern Terraform Features and Version Decisions

Version-gating tables and feature reference for Terraform 1.4+ through 1.14+. SKILL.md links here when generated output uses any feature listed below.

## Contents

- [Required Version Decision Table](#required-version-decision-table)
- [Feature-Gating Examples](#feature-gating-examples)
- [Terraform Version Feature Matrix](#terraform-version-feature-matrix)
- [Provider-Defined Functions (Terraform 1.8+)](#provider-defined-functions-terraform-18)
- [Ephemeral Resources (Terraform 1.10+)](#ephemeral-resources-terraform-110)
- [Write-Only Arguments (Terraform 1.11+)](#write-only-arguments-terraform-111)
- [Enhanced Variable Validations (Terraform 1.9+)](#enhanced-variable-validations-terraform-19)
- [S3 Native State Locking (Terraform 1.11+)](#s3-native-state-locking-terraform-111)
- [Import Blocks (Terraform 1.5+)](#import-blocks-terraform-15)
- [Moved and Removed Blocks](#moved-and-removed-blocks)
- [Import Blocks with for_each (Terraform 1.12+)](#import-blocks-with-for_each-terraform-112)
- [Actions Block (Terraform 1.14+)](#actions-block-terraform-114)
- [List Resources and Query Command (Terraform 1.14+)](#list-resources-and-query-command-terraform-114)
- [Preconditions and Postconditions (Terraform 1.5+)](#preconditions-and-postconditions-terraform-15)

## Required Version Decision Table

| Generated Output Contains | Required Version to Emit |
|---------------------------|--------------------------|
| Any write-only argument (`*_wo`) | `>= 1.11, < 2.0` |
| Ephemeral constructs only (no write-only) | `>= 1.10, < 2.0` |
| Neither write-only nor ephemeral | Project baseline (default `>= 1.8, < 2.0`) |

## Feature-Gating Examples

```hcl
# Positive: write-only usage requires Terraform 1.11+
terraform {
  required_version = ">= 1.11, < 2.0"
}

ephemeral "random_password" "db_password" {
  length = 16
}

resource "aws_db_instance" "main" {
  identifier          = "mydb"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  engine              = "postgres"
  username            = "admin"
  skip_final_snapshot = true

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

## Terraform Version Feature Matrix

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

## Provider-Defined Functions (Terraform 1.8+)

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
  region = provider::google::region_from_zone(var.zone)  # "us-west1-a" -> "us-west1"
}

# Kubernetes Provider Functions (v2.28+)
locals {
  # Encode HCL to Kubernetes manifest YAML
  manifest_yaml = provider::kubernetes::manifest_encode(local.deployment_config)
}
```

## Ephemeral Resources (Terraform 1.10+)

Ephemeral resources provide temporary values that are never persisted in state or plan files. Critical for handling secrets securely.

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

## Write-Only Arguments (Terraform 1.11+)

Write-only arguments accept ephemeral values and are never persisted. They use `_wo` suffix and require a version attribute.

```hcl
terraform {
  required_version = ">= 1.11, < 2.0"
}

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

  password_wo         = ephemeral.random_password.db_password.result
  password_wo_version = 1  # MUST increment to trigger password rotation

  skip_final_snapshot = true
}

# Secrets Manager with write-only
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id

  secret_string_wo         = ephemeral.random_password.db_password.result
  secret_string_wo_version = 1
}
```

## Enhanced Variable Validations (Terraform 1.9+)

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
    condition     = var.max_instances >= var.min_instances
    error_message = "max_instances must be >= min_instances"
  }
}
```

## S3 Native State Locking (Terraform 1.11+)

S3 supports native state locking without DynamoDB.

```hcl
terraform {
  backend "s3" {
    bucket       = "my-terraform-state"
    key          = "project/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true

    use_lockfile = true

    # DEPRECATED: DynamoDB locking (still works but no longer required)
    # dynamodb_table = "terraform-locks"
  }
}
```

## Import Blocks (Terraform 1.5+)

Declarative resource imports without command-line operations.

```hcl
import {
  to = aws_instance.web
  id = "i-1234567890abcdef0"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
  # ... configuration must match existing resource
}

import {
  for_each = var.existing_bucket_names
  to       = aws_s3_bucket.imported[each.key]
  id       = each.value
}
```

## Moved and Removed Blocks

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

## Import Blocks with for_each (Terraform 1.12+)

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

## Actions Block (Terraform 1.14+)

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

```bash
terraform apply -invoke action.aws_lambda_invoke.process_data
```

## List Resources and Query Command (Terraform 1.14+)

Query and filter existing infrastructure using `.tfquery.hcl` files and the `terraform query` command.

```hcl
# my-resources.tfquery.hcl
list "aws_instance" "web_servers" {
  filter {
    name   = "tag:Environment"
    values = [var.environment]
  }

  include_resource = true
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

## Preconditions and Postconditions (Terraform 1.5+)

Add custom validation within resource lifecycle.

```hcl
resource "aws_instance" "example" {
  instance_type = "t3.micro"
  ami           = data.aws_ami.example.id

  lifecycle {
    precondition {
      condition     = data.aws_ami.example.architecture == "x86_64"
      error_message = "The selected AMI must be for the x86_64 architecture."
    }

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
