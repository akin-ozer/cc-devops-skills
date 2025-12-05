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
    [PROVIDER_NAME] = {
      source  = "[PROVIDER_SOURCE]"
      version = "~> [PROVIDER_VERSION]"
    }
  }
}

provider "[PROVIDER_NAME]" {
  region = "[REGION]"
}
EOF
}

# Module inputs
inputs = {
  # Configuration variables
  [VARIABLE_NAME] = "[VALUE]"

  # Tags
  tags = {
    Name        = "[RESOURCE_NAME]"
    Environment = "[ENVIRONMENT]"
    ManagedBy   = "Terragrunt"
  }
}

# Optional: Locals block for computed values
locals {
  # Common configuration
  environment = "[ENVIRONMENT]"
  region      = "[REGION]"

  # Computed values
  # name_prefix = "${local.environment}-${local.region}"
}
