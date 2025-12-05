# Terraform and provider version constraints

terraform {
  required_version = ">= 1.10, < 2.0"

  required_providers {
    # Add your required providers here
    # Examples (as of December 2025):
    # aws = {
    #   source  = "hashicorp/aws"
    #   version = "~> 6.0"  # Latest: v6.23.0
    # }
    # azurerm = {
    #   source  = "hashicorp/azurerm"
    #   version = "~> 4.0"  # Latest: v4.54.0
    # }
    # google = {
    #   source  = "hashicorp/google"
    #   version = "~> 7.0"  # Latest: v7.12.0 - includes ephemeral resources & write-only attributes
    # }
  }
}

# Provider configuration
# Add your provider configurations here
