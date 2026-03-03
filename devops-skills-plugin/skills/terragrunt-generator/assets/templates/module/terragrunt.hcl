# Standalone Module Configuration (No Root Dependency)
# Module: [MODULE_NAME]
# Description: [MODULE_DESCRIPTION]
# Use Case: Standalone modules that don't need root configuration

# Terraform module source
terraform {
  source = "[MODULE_SOURCE]"
}

# Remote state configuration (when not using root config)
remote_state {
  backend = "s3"

  config = {
    bucket         = "[BUCKET_NAME]"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "[AWS_REGION]"
    encrypt        = true
    dynamodb_table = "[DYNAMODB_TABLE]"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Provider configuration (when not using root config)
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= [TERRAFORM_VERSION]"

  required_providers {
    # Replace 'aws' with your provider name (e.g., azurerm, google).
    aws = {
      source  = "[PROVIDER_SOURCE]"
      version = "~> [PROVIDER_VERSION]"
    }
  }
}

# Replace 'aws' with your provider name to match the required_providers block above.
provider "aws" {
  region = "[AWS_REGION]"
}
EOF
}

# Optional: Locals block for computed values
# Place locals above inputs so values are defined before they are referenced.
locals {
  # Common configuration
  environment = "[ENVIRONMENT]"
  region      = "[AWS_REGION]"

  # Computed values
  # name_prefix = "${local.environment}-${local.region}"
}

# Module inputs
inputs = {
  # Replace the commented examples below with your actual variable names and values.
  # variable_name   = "value"
  # another_var     = "[PLACEHOLDER]"

  # Tags
  tags = {
    Name        = "[RESOURCE_NAME]"
    Environment = local.environment
    ManagedBy   = "Terragrunt"
  }
}
