# Common Terraform Errors

Database of frequently encountered Terraform errors with detailed solutions and prevention strategies.

## Initialization Errors

### Error: Failed to query available provider packages

```
Error: Failed to query available provider packages

Could not retrieve the list of available versions for provider
hashicorp/aws: no available releases match the given constraints
```

**Causes:**
- Invalid version constraint in `required_providers`
- Network connectivity issues
- Provider source incorrect or doesn't exist

**Solutions:**
```hcl
# Check provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"  # Verify source is correct
      version = "~> 5.0"         # Check version exists
    }
  }
}
```

```bash
# Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

### Error: Module not found

```
Error: Module not installed

This configuration requires module "vpc" but it is not installed.
```

**Causes:**
- Forgot to run `terraform init`
- Module source path incorrect
- Network issues downloading remote modules

**Solutions:**
```bash
# Initialize to download modules
terraform init

# Update modules
terraform init -upgrade

# Check module source
module "vpc" {
  source = "./modules/vpc"  # Verify path exists
  # or
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.1.2"
}
```

## Validation Errors

### Error: Unsupported argument

```
Error: Unsupported argument

An argument named "instance_class" is not expected here.
```

**Causes:**
- Typo in argument name
- Argument not supported in this resource type
- Wrong provider version

**Solutions:**
1. Check official documentation for correct argument names
2. Verify provider version supports the argument
3. Use `terraform console` to explore resource schema

```bash
# Check resource schema
terraform console
> provider::aws::schema::aws_instance
```

### Error: Missing required argument

```
Error: Missing required argument

The argument "ami" is required, but no definition was found.
```

**Solutions:**
```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id  # Add missing argument
  instance_type = var.instance_type
}
```

### Error: Incorrect attribute value type

```
Error: Incorrect attribute value type

Inappropriate value for attribute "instance_count": a number is required.
```

**Solutions:**
```hcl
# Ensure variable has correct type
variable "instance_count" {
  type    = number
  default = 1  # Not "1"
}

# Convert if needed
resource "aws_instance" "web" {
  count = tonumber(var.instance_count)
}
```

## Resource Errors

### Error: Error creating resource: already exists

```
Error: Error creating VPC: VpcLimitExceeded: The maximum number of VPCs has been reached.
```

**Causes:**
- Resource already exists in AWS
- Service quota exceeded
- Import needed for existing resource

**Solutions:**
```bash
# Import existing resource
terraform import aws_vpc.main vpc-12345678

# Request quota increase
aws service-quotas request-service-quota-increase \
  --service-code vpc \
  --quota-code L-F678F1CE \
  --desired-value 10
```

### Error: Resource not found

```
Error: Error reading VPC: VPCNotFound: The vpc ID 'vpc-12345' does not exist
```

**Causes:**
- Resource was manually deleted
- Wrong AWS region
- State file out of sync

**Solutions:**
```bash
# Refresh state
terraform refresh

# Remove from state if truly deleted
terraform state rm aws_vpc.main

# Check AWS region configuration
provider "aws" {
  region = "us-east-1"  # Verify correct region
}
```

### Error: Resource dependency violation

```
Error: Error deleting VPC: DependencyViolation: The vpc 'vpc-12345' has dependencies and cannot be deleted.
```

**Causes:**
- Resources still attached to VPC
- Manual deletion required first
- Incorrect destroy order

**Solutions:**
```bash
# Use targeted destroy
terraform destroy -target=aws_subnet.private
terraform destroy -target=aws_vpc.main

# Or recreate dependencies
terraform apply
terraform destroy  # Destroy in correct order
```

## State Management Errors

### Error: State lock acquisition failed

```
Error: Error acquiring the state lock

Lock Info:
  ID:        abc123
  Path:      terraform.tfstate
  Operation: OperationTypeApply
```

**Causes:**
- Another terraform process running
- Previous operation crashed without releasing lock
- DynamoDB table issues (S3 backend)

**Solutions:**
```bash
# Wait for other process to complete, or force unlock (use carefully)
terraform force-unlock abc123

# Verify no other terraform processes
ps aux | grep terraform

# Check DynamoDB lock table
aws dynamodb scan --table-name terraform-state-locks
```

### Error: State file version mismatch

```
Error: state snapshot was created by Terraform v1.5.0, which is newer than current v1.4.0
```

**Solutions:**
```bash
# Upgrade Terraform to required version
brew upgrade terraform

# Or use tfenv for version management
tfenv install 1.5.0
tfenv use 1.5.0
```

### Error: Backend configuration changed

```
Error: Backend configuration changed

A change in the backend configuration has been detected.
```

**Solutions:**
```bash
# Reconfigure backend
terraform init -reconfigure

# Migrate state to new backend
terraform init -migrate-state
```

## Plan/Apply Errors

### Error: Provider authentication failed

```
Error: error configuring Terraform AWS Provider: no valid credential sources for Terraform AWS Provider found.
```

**Causes:**
- AWS credentials not configured
- Expired credentials
- Wrong profile or role

**Solutions:**
```bash
# Set environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"

# Or use AWS CLI profile
export AWS_PROFILE="your-profile"

# Or configure in provider
provider "aws" {
  profile = "your-profile"
  region  = "us-east-1"
}

# Verify credentials
aws sts get-caller-identity
```

### Error: Cycle dependency

```
Error: Cycle: aws_security_group.web, aws_security_group.db
```

**Causes:**
- Security groups reference each other
- Circular module dependencies

**Solutions:**
```hcl
# Break cycle with security group rules
resource "aws_security_group" "web" {
  name = "web-sg"
  # Remove inline rules causing cycle
}

resource "aws_security_group" "db" {
  name = "db-sg"
}

# Create rules separately
resource "aws_security_group_rule" "web_to_db" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.web.id
  source_security_group_id = aws_security_group.db.id
}
```

### Error: Invalid count argument

```
Error: Invalid count argument

The "count" value depends on resource attributes that cannot be determined until apply.
```

**Solutions:**
```hcl
# Use two-step apply or redesign

# Bad
resource "aws_instance" "web" {
  count = length(aws_subnet.private)  # Unknown until apply
}

# Good - use for_each instead
resource "aws_instance" "web" {
  for_each = toset(var.subnet_ids)  # Known at plan time

  subnet_id = each.value
}
```

### Error: Invalid for_each argument

```
Error: Invalid for_each argument

The "for_each" value depends on resource attributes that cannot be determined until apply.
```

**Solutions:**
```hcl
# Use data sources or variables instead of resource attributes

# Bad
resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private  # Unknown until apply
}

# Good
locals {
  subnets = {
    private_a = { cidr = "10.0.1.0/24" }
    private_b = { cidr = "10.0.2.0/24" }
  }
}

resource "aws_subnet" "private" {
  for_each   = local.subnets
  cidr_block = each.value.cidr
}
```

## Variable Errors

### Error: No value for required variable

```
Error: No value for required variable

The root module input variable "db_password" is not set.
```

**Solutions:**
```bash
# Set via command line
terraform apply -var="db_password=secretpass"

# Set via tfvars file
echo 'db_password = "secretpass"' > terraform.tfvars

# Set via environment variable
export TF_VAR_db_password="secretpass"
```

### Error: Invalid variable type

```
Error: Invalid value for input variable

The given value is not suitable for var.instance_count: number required.
```

**Solutions:**
```hcl
# In terraform.tfvars, use correct type
instance_count = 3  # Not "3"

# Or convert in code
variable "instance_count" {
  type = string
}

resource "aws_instance" "web" {
  count = tonumber(var.instance_count)
}
```

## Module Errors

### Error: Unsuitable value for module variable

```
Error: Unsuitable value for var.vpc_cidr

This value does not have any of the required types: string.
```

**Solutions:**
```hcl
# Check module call
module "vpc" {
  source = "./modules/vpc"

  vpc_cidr = "10.0.0.0/16"  # Ensure string, not object
}
```

### Error: Unsupported attribute in module output

```
Error: Unsupported attribute

This object does not have an attribute named "vpc_id".
```

**Causes:**
- Output not defined in module
- Typo in output name
- Module version mismatch

**Solutions:**
```hcl
# Check module outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

# Reference correctly
resource "aws_instance" "web" {
  subnet_id = module.vpc.vpc_id  # Use exact output name
}
```

## Provider-Specific Errors

### AWS: Error creating Security Group: InvalidGroup.Duplicate

```
Error: Error creating Security Group: InvalidGroup.Duplicate: The security group 'web-sg' already exists
```

**Solutions:**
```bash
# Import existing security group
terraform import aws_security_group.web sg-12345678

# Or use data source
data "aws_security_group" "existing" {
  name = "web-sg"
}
```

### AWS: Error: Timeout while waiting for state

```
Error: timeout while waiting for resource to be created
```

**Causes:**
- Resource taking longer than expected
- Resource creation actually failed
- API throttling

**Solutions:**
```hcl
# Increase timeout
resource "aws_db_instance" "main" {
  # ... config ...

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }
}
```

### AWS: Error: UnauthorizedOperation

```
Error: UnauthorizedOperation: You are not authorized to perform this operation.
```

**Solutions:**
```bash
# Check IAM permissions
aws iam get-user-policy --user-name your-user --policy-name your-policy

# Verify required permissions for resource
# Example: EC2 instance requires:
# - ec2:RunInstances
# - ec2:DescribeInstances
# - ec2:DescribeImages
# etc.
```

## Workspace Errors

### Error: Workspace already exists

```
Error: Workspace "production" already exists
```

**Solutions:**
```bash
# Select existing workspace
terraform workspace select production

# List workspaces
terraform workspace list

# Delete workspace (if empty)
terraform workspace delete production
```

## Formatting Errors

### Error: Terraform fmt found issues

```
main.tf
  - Line 5: Incorrect indentation
```

**Solutions:**
```bash
# Auto-fix formatting
terraform fmt

# Check formatting (CI/CD)
terraform fmt -check

# Recursive formatting
terraform fmt -recursive
```

## Import Errors

### Error: Import resource does not exist

```
Error: Cannot import non-existent remote object
```

**Solutions:**
```bash
# Verify resource ID
aws ec2 describe-instances --instance-ids i-12345

# Use correct resource address
terraform import aws_instance.web i-1234567890abcdef0

# Check provider configuration matches resource region
```

## Prevention Strategies

### Pre-Commit Checks

```bash
# Run these before every commit
terraform fmt -check -recursive
terraform validate
terraform plan
```

### Use Validation Rules

```hcl
variable "environment" {
  type = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

### Enable Detailed Logging

```bash
# Debug mode
export TF_LOG=DEBUG
terraform apply

# Log to file
export TF_LOG_PATH="./terraform.log"
```

### Version Pinning

```hcl
terraform {
  required_version = "~> 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```
