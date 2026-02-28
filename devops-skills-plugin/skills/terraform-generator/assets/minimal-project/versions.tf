# Terraform and provider version constraints

terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    # Add your required providers here.
    # Use major-version pinning (~>) and verify exact "latest" versions online when needed.
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 6.0"
    # }
    # azurerm = {
    #   source  = "hashicorp/azurerm"
    #   version = "~> 4.0"
    # }
    # google = {
    #   source  = "hashicorp/google"
    #   version = "~> 7.0"
    # }
  }
}

# Provider configuration
# Add your provider configurations here
