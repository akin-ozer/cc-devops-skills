# Terraform Advanced Features

Modern Terraform features for enhanced infrastructure management. This reference covers features introduced in Terraform 1.10+.

> **Official Documentation:** [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/docs)

## Ephemeral Values and Write-Only Arguments (1.10+)

**Purpose:** Securely manage sensitive data like passwords and tokens without storing them in Terraform state or plan files.

### Overview

Ephemeral values are temporary values that exist only during a Terraform operation. They are never persisted to state, plan files, or logs. This is a major security improvement for secrets management.

### Ephemeral Resources

Ephemeral resources generate temporary values that don't persist:

```hcl
# Generate a temporary password - NOT stored in state
ephemeral "random_password" "db_password" {
  length           = 16
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Use with AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "db_password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id                = aws_secretsmanager_secret.db_password.id
  secret_string_wo         = ephemeral.random_password.db_password.result
  secret_string_wo_version = 1
}
```

### Write-Only Arguments (1.11+)

Write-only arguments accept values but never persist them:

```hcl
# Use ephemeral password with write-only argument
ephemeral "random_password" "db_password" {
  length = 16
}

resource "aws_db_instance" "example" {
  instance_class       = "db.t3.micro"
  allocated_storage    = "5"
  engine               = "postgres"
  username             = "admin"
  skip_final_snapshot  = true

  # Write-only argument - password is NOT stored in state
  password_wo          = ephemeral.random_password.db_password.result
  password_wo_version  = 1  # Increment to trigger password update
}
```

### Key Concepts

| Concept | Version | Description |
|---------|---------|-------------|
| `ephemeral` block | 1.10+ | Defines resources that are never stored in state |
| Ephemeral variables | 1.10+ | Variables marked `ephemeral = true` |
| Ephemeral outputs | 1.10+ | Outputs marked `ephemeral = true` |
| Write-only arguments | 1.11+ | Resource arguments ending in `_wo` that accept ephemeral values |
| `_wo_version` arguments | 1.11+ | Version tracking to prevent updates on every run |
| `ephemeralasnull` function | 1.10+ | Convert ephemeral to null for conditional logic |

### Ephemeral Input Variables

```hcl
variable "api_token" {
  type      = string
  sensitive = true
  ephemeral = true  # Value is not stored in state
}
```

### Ephemeral Outputs

```hcl
output "generated_password" {
  value     = ephemeral.random_password.main.result
  ephemeral = true  # Value is not stored in state
}
```

### Provider Support

Ephemeral resources are available in:
- AWS Provider (secrets, passwords)
- Azure Provider
- Kubernetes Provider
- Random Provider (`random_password`)
- Google Cloud Provider

### Security Best Practices

1. **Always use ephemeral for secrets** - passwords, API keys, tokens
2. **Use write-only arguments** - for database passwords, secret values
3. **Increment version** - when you need to update write-only values
4. **Combine with Secrets Manager** - store ephemeral values in vault
5. **Never log ephemeral values** - they won't appear in plan output

### Validation Considerations

When validating Terraform configurations with ephemeral values:
- Ephemeral resources don't appear in state
- Write-only arguments show as `(sensitive value)` in plans
- `terraform plan` will show ephemeral resource creation each run
- Checkov may not detect issues in ephemeral resources (no state)

---

## Actions Blocks (1.14+)

**Purpose:** Execute provider-defined imperative operations outside the normal CRUD model.

### Overview

Actions are a concept in Terraform 1.14 (GA - November 2025) that allow providers to define operations that don't fit the standard create/read/update/delete lifecycle. This is useful for one-time operations like invoking Lambda functions or invalidating CDN caches.

### Basic Example

```hcl
# Define an action to invoke a Lambda function
action "aws_lambda_invoke" "process_data" {
  config {
    function_name = aws_lambda_function.processor.function_name
    payload       = jsonencode({ action = "process" })
  }
}

# CloudFront cache invalidation action
action "aws_cloudfront_create_invalidation" "invalidate_cache" {
  config {
    distribution_id = aws_cloudfront_distribution.cdn.id
    paths           = ["/*"]
  }
}
```

### Advanced Example with Dependencies

```hcl
# Resource with action trigger on lifecycle events
resource "aws_s3_object" "data_file" {
  bucket       = aws_s3_bucket.data.id
  key          = "data/input.json"
  source       = "local/input.json"
  content_type = "application/json"

  # Trigger action when S3 object is updated
  lifecycle {
    action_trigger {
      events  = [after_update]
      actions = [action.aws_lambda_invoke.process_data]
    }
  }
}

# Lambda invocation action - triggered by resource lifecycle
action "aws_lambda_invoke" "process_data" {
  config {
    function_name = aws_lambda_function.processor.function_name
    payload = jsonencode({
      bucket = aws_s3_bucket.data.id
      key    = aws_s3_object.data_file.key
      action = "process"
    })
  }
}

# CloudFront cache invalidation - triggered after S3 update
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"
  source       = "html/index.html"

  lifecycle {
    action_trigger {
      events  = [after_update]
      actions = [action.aws_cloudfront_create_invalidation.invalidate_cache]
    }
  }
}

action "aws_cloudfront_create_invalidation" "invalidate_cache" {
  config {
    distribution_id = aws_cloudfront_distribution.cdn.id
    paths           = ["/*"]
  }
}
```

### Key Features

1. **Imperative Operations** - Actions perform side effects, not resource management
2. **Lifecycle Integration** - Can trigger on resource create/update/destroy
3. **CLI Invocation** - Run with `terraform apply -invoke` to trigger actions directly
4. **Provider-Defined** - Actions are defined by providers (AWS, Azure, etc.)
5. **Chainable** - Actions can depend on other actions

### CLI Commands

```bash
# Plan with specific action invocation
terraform plan -invoke=action.aws_lambda_invoke.process_data

# Apply with specific action invocation
terraform apply -invoke=action.aws_lambda_invoke.process_data

# Apply with auto-approve and action invocation
terraform apply -auto-approve -invoke=action.aws_cloudfront_create_invalidation.invalidate_cache

# Normal apply (actions triggered by lifecycle events still run)
terraform apply
```

### When to Use Actions

- Invoking Lambda/Cloud Functions
- Cache invalidation (CloudFront, CDN)
- Stopping/starting EC2 instances
- Database migrations
- API calls that don't create resources
- Post-deployment scripts
- Integration testing triggers

### Provider Support (as of November 2025)

| Provider | Available Actions |
|----------|-------------------|
| AWS | `aws_lambda_invoke`, `aws_cloudfront_create_invalidation`, `aws_ec2_stop_instance` |
| Azure | Coming soon |
| GCP | Coming soon |

### Validation Considerations

- Actions don't create resources in state
- `terraform plan` shows action effects separately
- Actions run in dependency order
- Failed actions don't roll back completed actions

---

## List Resources and Query Command (1.14+)

**Purpose:** Query and filter existing infrastructure resources directly from Terraform, with optional configuration generation for importing.

### Overview

Terraform 1.14 introduces List Resources, defined in `*.tfquery.hcl` files, that allow you to query existing infrastructure and optionally generate Terraform configuration for discovered resources.

### Basic Query File

```hcl
# my_query.tfquery.hcl

# List all S3 buckets with specific tags
list "aws_s3_bucket" "production_buckets" {
  filter {
    tags = {
      Environment = "production"
    }
  }
}

# List EC2 instances by type
list "aws_instance" "large_instances" {
  filter {
    instance_type = "t3.large"
  }
}

# List all VPCs
list "aws_vpc" "all_vpcs" {}
```

### CLI Commands

```bash
# Execute query and display results
terraform query

# Execute query with specific query file
terraform query -query=my_query.tfquery.hcl

# Generate configuration for discovered resources
terraform query -generate-config-out=discovered.tf

# Validate query files offline
terraform validate -query
```

### Advanced Query Example

```hcl
# infrastructure_audit.tfquery.hcl

# Find untagged resources
list "aws_s3_bucket" "untagged_buckets" {
  filter {
    tags = null
  }
}

# Find publicly accessible resources
list "aws_security_group" "public_ingress" {
  filter {
    ingress {
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

# Find resources by name pattern
list "aws_instance" "web_servers" {
  filter {
    tags = {
      Name = "web-*"
    }
  }
}
```

### Use Cases

1. **Infrastructure Auditing** - Discover resources not managed by Terraform
2. **Compliance Checking** - Find resources missing required tags
3. **Cost Optimization** - Identify oversized or unused resources
4. **Import Generation** - Generate configuration for manual imports
5. **Drift Detection** - Compare query results with state

### Output Example

```
$ terraform query

List: aws_s3_bucket.production_buckets
  Found 3 resources:

  - arn:aws:s3:::prod-logs-bucket
    tags.Environment = "production"
    tags.Team = "ops"

  - arn:aws:s3:::prod-assets-bucket
    tags.Environment = "production"
    tags.Team = "web"

  - arn:aws:s3:::prod-backups-bucket
    tags.Environment = "production"
    tags.Team = "dba"
```

### Validation Considerations

- Query files are validated with `terraform validate -query`
- Queries require valid provider authentication
- Results depend on IAM permissions
- Large queries may be rate-limited by cloud providers

---

## Feature Version Matrix

| Feature | Terraform Version | Status |
|---------|-------------------|--------|
| Ephemeral resources | 1.10+ | GA |
| Ephemeral variables/outputs | 1.10+ | GA |
| Write-only arguments | 1.11+ | GA |
| S3 native state locking | 1.11+ | GA |
| Actions blocks | 1.14+ | GA (Nov 2025) |
| List resources / Query | 1.14+ | GA (Nov 2025) |

## Related Documentation

- [Terraform Ephemeral Values](https://developer.hashicorp.com/terraform/language/values/ephemeral)
- [Terraform State Management](https://developer.hashicorp.com/terraform/language/state)
- [Import Block](https://developer.hashicorp.com/terraform/language/import)
- [Moved Block](https://developer.hashicorp.com/terraform/language/moved)
- [Removed Block](https://developer.hashicorp.com/terraform/language/removed)
