# Terragrunt Stack Configuration
# Stack: [STACK_NAME]
# Description: [STACK_DESCRIPTION]
# Environment: [ENVIRONMENT]
#
# This file defines a blueprint for generating Terragrunt unit configurations.
# Run `terragrunt stack generate` to create the unit directories and configurations.
#
# Commands:
#   terragrunt stack generate           - Generate unit configurations
#   terragrunt stack run plan           - Plan all units in the stack
#   terragrunt stack run apply          - Apply all units in the stack
#   terragrunt stack output             - Get aggregated outputs from all units
#   terragrunt stack clean              - Remove generated directories

# Local variables for stack-wide configuration
locals {
  # Stack identification
  stack_name  = "[STACK_NAME]"
  environment = "[ENVIRONMENT]"
  aws_region  = "[AWS_REGION]"

  # Path to the unit catalog (reusable unit definitions)
  # Options:
  #   - Local path: find_in_parent_folders("catalog/units")
  #   - Git repository: "git::git@github.com:[ORG]/infrastructure-catalog.git//units"
  units_path = find_in_parent_folders("catalog/units")

  # Common values passed to all units
  common_values = {
    environment = local.environment
    aws_region  = local.aws_region
    stack_name  = local.stack_name
  }

  # Keep this mode consistent across all dependent units.
  # Mixing true/false values across units breaks relative dependency paths.
  use_direct_paths = true
}

# Unit: VPC (Networking Foundation)
# This unit creates the VPC and networking infrastructure
unit "vpc" {
  # Source can be:
  #   - Local: "${local.units_path}/vpc"
  #   - Git: "git::git@github.com:[ORG]/infrastructure-catalog.git//units/vpc?ref=v1.0.0"
  source = "${local.units_path}/vpc"

  # Path where the unit configuration will be generated
  # If local.use_direct_paths = false: .terragrunt-stack/vpc/terragrunt.hcl
  # If local.use_direct_paths = true:  vpc/terragrunt.hcl
  path = "vpc"

  # Values passed to the unit (accessible via `values` object in the unit's terragrunt.hcl)
  # These are written to terragrunt.values.hcl alongside the generated terragrunt.hcl
  values = merge(local.common_values, {
    name = "${local.stack_name}-vpc"
    cidr = "[VPC_CIDR]"  # e.g., "10.0.0.0/16"
  })

  # Generate directly in path/ instead of .terragrunt-stack/path/
  no_dot_terragrunt_stack = local.use_direct_paths
}

# Unit: Database (Data Layer)
# This unit creates the database infrastructure
unit "database" {
  source = "${local.units_path}/database"
  path   = "database"

  # Keep generation mode aligned with other units.
  no_dot_terragrunt_stack = local.use_direct_paths

  values = merge(local.common_values, {
    name    = "${local.stack_name}-db"
    engine  = "[DB_ENGINE]"   # e.g., "postgres", "mysql"
    version = "[DB_VERSION]"  # e.g., "15", "8.0"

    # Reference to VPC unit for dependency resolution.
    # Keep all units on the same no_dot_terragrunt_stack mode so ../vpc resolves.
    vpc_path = "../vpc"
  })
}

# Unit: Application (Compute Layer)
# This unit creates the application infrastructure
unit "app" {
  source                  = "${local.units_path}/app"
  path                    = "app"
  no_dot_terragrunt_stack = local.use_direct_paths

  values = merge(local.common_values, {
    name          = "${local.stack_name}-app"
    instance_type = "[INSTANCE_TYPE]"  # e.g., "t3.medium"
    desired_count = 2                  # Replace with actual desired count

    # Dependencies on other units
    vpc_path      = "../vpc"
    database_path = "../database"
  })
}

# ==============================================================================
# Additional Unit Examples (uncomment and customize as needed)
# ==============================================================================

# Unit: Security Groups
# unit "security_groups" {
#   source = "${local.units_path}/security-groups"
#   path   = "security-groups"
#
#   values = merge(local.common_values, {
#     vpc_path = "../vpc"
#   })
# }

# Unit: IAM Roles
# unit "iam" {
#   source = "${local.units_path}/iam"
#   path   = "iam"
#
#   values = merge(local.common_values, {
#     role_name = "${local.stack_name}-role"
#   })
# }

# Unit: Monitoring (CloudWatch, etc.)
# unit "monitoring" {
#   source = "${local.units_path}/monitoring"
#   path   = "monitoring"
#
#   values = merge(local.common_values, {
#     app_path = "../app"
#     db_path  = "../database"
#   })
# }

# ==============================================================================
# Nested Stack Example
# You can include other stacks to compose complex infrastructure
# ==============================================================================

# stack "shared_services" {
#   source = "git::git@github.com:[ORG]/infrastructure-catalog.git//stacks/shared-services?ref=v1.0.0"
#   path   = "shared"
#
#   values = {
#     environment = local.environment
#   }
# }
