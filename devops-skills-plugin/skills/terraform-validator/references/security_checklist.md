# Terraform Security Checklist

Comprehensive security validation checklist for Terraform configurations. Use this reference when performing security reviews or auditing infrastructure-as-code.

## Secrets Management

### Hardcoded Credentials

**Risk:** Secrets committed to version control can be exposed.

**Detection:**
```bash
# Search for common secret patterns
grep -rE "(password|secret|api_key|access_key)\s*=\s*\"[^$]" *.tf
grep -rE "private_key\s*=\s*\"" *.tf
grep -rE "token\s*=\s*\"[^$]" *.tf
```

**Remediation:**
- Use Terraform variables with `sensitive = true`
- Use environment variables (TF_VAR_*)
- Use HashiCorp Vault or AWS Secrets Manager
- Use AWS Systems Manager Parameter Store
- Never commit `.tfvars` files with secrets

**Example - Insecure:**
```hcl
resource "aws_db_instance" "example" {
  username = "admin"
  password = "hardcoded_password123"  # SECURITY ISSUE
}
```

**Example - Secure:**
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

resource "aws_db_instance" "example" {
  username = "admin"
  password = var.db_password
}
```

### Sensitive Output Exposure

**Risk:** Sensitive data exposed in terraform state or plan output.

**Detection:**
- Review output blocks for sensitive data
- Check state files for plaintext secrets

**Remediation:**
```hcl
output "db_password" {
  value     = aws_db_instance.example.password
  sensitive = true  # Prevents display in console
}
```

## Network Security

### Overly Permissive Security Groups

**Risk:** Unrestricted access to resources from the internet.

**Detection Patterns:**
```hcl
# SECURITY ISSUE: SSH open to world
ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

# SECURITY ISSUE: All ports open
ingress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
}
```

**Best Practices:**
- Restrict SSH/RDP to specific IP ranges or VPN
- Use security group references instead of CIDR blocks
- Implement least-privilege access
- Document exceptions with comments

**Example - Secure:**
```hcl
variable "admin_cidr" {
  description = "CIDR block for admin access"
  type        = string
}

resource "aws_security_group" "app" {
  ingress {
    description = "SSH from admin network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
}
```

### Public S3 Buckets

**Risk:** Data exposure through public S3 access.

**Detection:**
```hcl
# SECURITY ISSUE: Public bucket
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false  # Should be true
  block_public_policy     = false  # Should be true
  ignore_public_acls      = false  # Should be true
  restrict_public_buckets = false  # Should be true
}
```

**Best Practices:**
```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Encryption

### Encryption at Rest

**Resources to Check:**
- RDS databases
- S3 buckets
- EBS volumes
- DynamoDB tables
- Elasticsearch domains
- Kinesis streams
- SQS queues

**Example - RDS Encryption:**
```hcl
resource "aws_db_instance" "example" {
  storage_encrypted = true  # Required
  kms_key_id       = aws_kms_key.db.arn  # Use customer-managed keys
}
```

**Example - S3 Encryption:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}
```

### Encryption in Transit

**Risk:** Data intercepted during transmission.

**Best Practices:**
- Enforce HTTPS/TLS for all endpoints
- Use SSL/TLS for database connections
- Enable encryption for load balancers

**Example - ALB HTTPS:**
```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.example.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

## IAM Security

### Overly Permissive Policies

**Risk:** Privilege escalation and unauthorized access.

**Detection Patterns:**
```hcl
# SECURITY ISSUE: Admin access
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}

# SECURITY ISSUE: Too broad
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*"
}
```

**Best Practices:**
- Follow least-privilege principle
- Use specific actions instead of wildcards
- Scope resources narrowly
- Use conditions to restrict access

**Example - Least Privilege:**
```hcl
data "aws_iam_policy_document" "s3_read_only" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.app_data.arn,
      "${aws_s3_bucket.app_data.arn}/*"
    ]
  }
}
```

### Missing MFA Requirements

**Best Practice:**
```hcl
data "aws_iam_policy_document" "require_mfa" {
  statement {
    effect = "Deny"
    actions = ["*"]
    resources = ["*"]

    condition {
      test     = "BoolIfExists"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["false"]
    }
  }
}
```

### Cross-Account Access

**Risk:** Unauthorized access from other AWS accounts.

**Best Practices:**
- Explicitly specify trusted accounts
- Require external ID for third-party access
- Use conditions to restrict access

```hcl
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::123456789012:root"]
    }
    actions = ["sts:AssumeRole"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.external_id]
    }
  }
}
```

## Logging and Monitoring

### Missing CloudTrail

**Risk:** No audit trail for API calls.

**Best Practice:**
```hcl
resource "aws_cloudtrail" "main" {
  name                          = "main-trail"
  s3_bucket_name               = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail        = true
  enable_logging               = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }
}
```

### Missing VPC Flow Logs

**Best Practice:**
```hcl
resource "aws_flow_log" "vpc" {
  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
}
```

### Unencrypted Logs

**Best Practice:**
```hcl
resource "aws_cloudwatch_log_group" "app" {
  name              = "/aws/app/logs"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn  # Encrypt logs
}
```

## Resource-Specific Checks

### RDS Databases

- [ ] `storage_encrypted = true`
- [ ] `publicly_accessible = false`
- [ ] Backup retention enabled
- [ ] Multi-AZ for production
- [ ] IAM authentication enabled
- [ ] Enhanced monitoring enabled
- [ ] SSL/TLS required for connections

### ElastiCache

- [ ] `at_rest_encryption_enabled = true`
- [ ] `transit_encryption_enabled = true`
- [ ] Auth token enabled for Redis
- [ ] Subnet group in private subnets

### Lambda Functions

- [ ] Environment variables encrypted with KMS
- [ ] VPC configuration if accessing private resources
- [ ] IAM role with least-privilege
- [ ] Dead letter queue configured
- [ ] Reserved concurrency to prevent cost overruns

### ECS/EKS

- [ ] Secrets managed via Secrets Manager
- [ ] Container images scanned
- [ ] Network policy enforcement
- [ ] Pod security policies
- [ ] RBAC configured

## State File Security

### Remote State

**Risk:** State files contain sensitive data in plaintext.

**Best Practices:**

**Terraform 1.11+ (S3 Native Locking - Recommended):**
```hcl
terraform {
  backend "s3" {
    bucket       = "terraform-state-bucket"
    key          = "prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true  # Required
    kms_key_id   = "arn:aws:kms:..."
    use_lockfile = true  # S3 native locking (1.11+)
  }
}
```

> **Note:** Terraform 1.11 introduced S3 native state locking via the `use_lockfile` argument. This uses S3's conditional writes to implement locking without requiring DynamoDB. The DynamoDB-based locking (`dynamodb_table`) is now deprecated but still supported for backward compatibility.

**Legacy (Terraform < 1.11 or backward compatibility):**
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-bucket"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true  # Required
    kms_key_id     = "arn:aws:kms:..."
    dynamodb_table = "terraform-locks"  # State locking (deprecated in 1.11+)
  }
}
```

**Checklist:**
- [ ] Encryption enabled for state storage
- [ ] State locking configured (`use_lockfile = true` for 1.11+ or DynamoDB for older versions)
- [ ] Versioning enabled on state bucket
- [ ] Access restricted via IAM policies
- [ ] MFA delete enabled on state bucket
- [ ] State files never committed to version control

## Compliance Checks

### Tagging

**Best Practice:**
```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.owner
    CostCenter  = var.cost_center
    Compliance  = "HIPAA"  # If applicable
  }
}

resource "aws_instance" "example" {
  # ... other config ...
  tags = merge(local.common_tags, {
    Name = "app-server"
  })
}
```

### Data Residency

- Ensure resources in correct regions
- Check for cross-region replication
- Verify data sovereignty requirements

## Terraform-Specific Security

### Provider Version Pinning

**Risk:** Unexpected behavior from provider updates.

**Best Practice:**
```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Pin major version
    }
  }
}
```

### Module Sources

**Risk:** Malicious code from untrusted modules.

**Best Practices:**
- Use verified modules from Terraform Registry
- Pin module versions
- Review module code before use
- Use private module registry for internal modules

```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"  # Pin specific version
}
```

## Automated Security Scanning

Tools to integrate:
- **trivy** - Unified security scanner (successor to tfsec, includes IaC scanning)
- **checkov** - Policy-as-code security scanner (3000+ built-in policies)
- **terraform-compliance** - BDD-style testing

> **Note:** Terrascan was archived by Tenable on November 20, 2025 and is no longer maintained. Use Checkov or Trivy instead for OPA/Rego-style policy enforcement.

### Trivy (Recommended)

Trivy is Aqua Security's unified scanner that absorbed tfsec. It scans Terraform, CloudFormation, Kubernetes, Helm, and more.

**Version Note:**
> **Warning:** Trivy v0.60.0 has known regression issues that can cause panics when scanning Terraform configurations. If you experience crashes or unexpected behavior, downgrade to v0.59.x until v0.61.0+ is released with fixes.
>
> To install a specific version:
> ```bash
> # macOS
> brew install trivy@0.59.1
>
> # Linux - specify version in install script
> curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.59.1
> ```

**Installation:**
```bash
# macOS
brew install trivy

# Linux
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Docker
docker pull aquasec/trivy
```

**Usage:**
```bash
# Scan Terraform directory
trivy config ./terraform

# Scan with specific severity
trivy config --severity HIGH,CRITICAL ./terraform

# Scan with JSON output
trivy config -f json -o results.json ./terraform

# Scan specific file
trivy config main.tf

# Skip specific checks
trivy config --skip-dirs .terraform ./terraform

# Scan Terraform plan JSON (more accurate)
terraform show -json tfplan > tfplan.json
trivy config tfplan.json

# Use tfvars files for accurate variable resolution
trivy config --tf-vars prod.terraform.tfvars ./terraform

# Exclude downloaded modules from scanning
trivy config --tf-exclude-downloaded-modules ./terraform
```

**Common Trivy Checks for Terraform:**
- `AVD-AWS-0086` - S3 bucket encryption
- `AVD-AWS-0089` - S3 bucket versioning
- `AVD-AWS-0132` - Security group unrestricted ingress
- `AVD-AWS-0107` - RDS encryption at rest
- `AVD-AWS-0078` - EBS encryption

**Output Formats:**
- `table` - Human-readable table (default)
- `json` - JSON format for CI/CD integration
- `sarif` - SARIF format for IDE integration
- `template` - Custom template output

**Ignore Findings:**
```hcl
# trivy:ignore:AVD-AWS-0086
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
```

**Advanced Trivy Configuration (trivy.yaml):**
```yaml
# trivy.yaml
exit-code: 1
severity:
  - HIGH
  - CRITICAL
scan:
  scanners:
    - vuln
    - secret
    - misconfig
misconfiguration:
  terraform:
    tfvars-files:
      - prod.tfvars
```

### Checkov 3.0

Checkov 3.0 introduces major improvements for Terraform scanning with enhanced graph policies and deeper analysis.

**Key 3.0 Features:**

1. **Deep Analysis Mode:**
   Fully resolve for_each, dynamic blocks, and complex configurations:
   ```bash
   # Enable deep analysis with plan file
   checkov -f tfplan.json --deep-analysis --repo-root-for-plan-enrichment .
   ```

2. **Baseline Feature:**
   Track only new misconfigurations (ignore existing):
   ```bash
   # Create baseline from current state
   checkov -d . --create-baseline

   # Run subsequent scans against baseline
   checkov -d . --baseline .checkov.baseline
   ```

3. **Enhanced Policy Language:**
   36 new operators including:
   - `SUBSET` - Check if values are subset of allowed values
   - `jsonpath_*` operators - Deep JSON path queries
   - Enhanced graph traversal for complex dependencies

4. **Improved Dynamic Block Support:**
   ```bash
   # Scan with full dynamic block resolution
   checkov -d . --download-external-modules true
   ```

**Checkov 3.0 Commands:**
```bash
# Basic scan
checkov -d .

# Deep analysis with Terraform plan
terraform plan -out=tf.plan
terraform show -json tf.plan > tfplan.json
checkov -f tfplan.json --deep-analysis

# Create and use baseline
checkov -d . --create-baseline
checkov -d . --baseline .checkov.baseline

# Compact output (failures only)
checkov -d . --compact

# Skip specific checks
checkov -d . --skip-check CKV_AWS_20,CKV_AWS_21

# Run only specific frameworks
checkov -d . --framework terraform
```

### Tool Comparison

| Tool | Focus | Policy Language | Built-in Policies | Best For |
|------|-------|-----------------|-------------------|----------|
| **trivy** | Security | Rego | 1000+ | All-in-one scanning, container + IaC |
| **checkov** | Security/Compliance | Python/YAML | 3000+ | Multi-framework, compliance, deep analysis |

**Note:** tfsec has been deprecated and merged into Trivy. Terrascan was archived in November 2025. New users should use Trivy or Checkov.

## Quick Security Audit Commands

```bash
# Check for hardcoded secrets
grep -r "password\s*=\s*\"" . --include="*.tf"
grep -r "secret\s*=\s*\"" . --include="*.tf"

# Find public security groups
grep -r "0.0.0.0/0" . --include="*.tf"

# Find unencrypted resources
grep -r "encrypted\s*=\s*false" . --include="*.tf"

# Check for missing backup configurations
grep -r "backup_retention_period\s*=\s*0" . --include="*.tf"
```
