# Root Terragrunt Configuration
# This file contains shared configuration for all modules

# Require Terragrunt 0.93+ for new CLI features
terragrunt_version_constraint = ">= 0.93.0"

# Require Terraform/OpenTofu 1.6+
terraform_version_constraint = ">= 1.6.0"

locals {
  # Automatically load account and region variables
  account_id = get_env("AWS_ACCOUNT_ID", "123456789012")
  aws_region = "us-east-1"

  # Common tags applied to all resources
  common_tags = {
    Terraform  = "true"
    ManagedBy  = "Terragrunt"
    Repository = "infrastructure"
    Team       = "platform"
  }
}

# Generate AWS provider configuration
# Note: Using "skip" to avoid conflicts with modules that have their own provider.tf
generate "provider" {
  path      = "provider.tf"
  if_exists = "skip"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = ${jsonencode(local.common_tags)}
  }
}
EOF
}

# Configure Terraform version and required providers
# Note: Using "skip" to avoid conflicts with registry modules that have their own versions.tf
generate "versions" {
  path      = "versions.tf"
  if_exists = "skip"
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

# Configure remote state
remote_state {
  backend = "s3"

  config = {
    bucket         = "terraform-state-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.aws_region
    encrypt        = true
    dynamodb_table = "terraform-locks"

    s3_bucket_tags = {
      Name = "Terraform State Storage"
    }

    dynamodb_table_tags = {
      Name = "Terraform Lock Table"
    }
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Configure Terragrunt behavior
terraform {
  # Log level for Terraform
  extra_arguments "common_vars" {
    commands = get_terraform_commands_that_need_vars()
  }

  # Retry on transient errors
  extra_arguments "retry_lock" {
    commands = get_terraform_commands_that_need_locking()

    arguments = [
      "-lock-timeout=5m"
    ]
  }
}
