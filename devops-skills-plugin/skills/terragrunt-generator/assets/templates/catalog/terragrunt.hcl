# Catalog Unit Configuration
# Unit: [UNIT_NAME]
# Description: [UNIT_DESCRIPTION]
#
# This is a reusable unit template for use with Terragrunt Stacks.
# Units are referenced in terragrunt.stack.hcl files and parameterized via the `values` object.
#
# Location: catalog/units/[UNIT_NAME]/terragrunt.hcl
# Usage: Reference this unit from a terragrunt.stack.hcl file
#
# Example stack reference:
#   unit "[UNIT_NAME]" {
#     source = "${local.units_path}/[UNIT_NAME]"
#     path   = "[UNIT_NAME]"
#     values = {
#       name        = "my-resource"
#       environment = "prod"
#     }
#   }

# Include root configuration for shared settings (state backend, providers, etc.)
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# Terraform/OpenTofu module source
terraform {
  source = "[MODULE_SOURCE]"

  # Examples:
  # Local module:
  #   source = "${get_repo_root()}/modules/[MODULE_NAME]"
  # Git repository:
  #   source = "git::https://github.com/[ORG]/[REPO].git//modules/[MODULE_NAME]?ref=v1.0.0"
  # Terraform Registry:
  #   source = "tfr:///terraform-aws-modules/[MODULE_NAME]/aws?version=5.0.0"
}

# ==============================================================================
# Dependencies (if this unit depends on other units)
# ==============================================================================

# Declare execution order dependencies
# The paths here should match the values.xxx_path passed from the stack
dependencies {
  paths = [
    # Example: Use values passed from stack to determine dependency paths
    # try(values.vpc_path, ""),
  ]
}

# Dependency with mock outputs for validation and planning
# Uncomment and customize based on your unit's dependencies
#
# dependency "vpc" {
#   # Use the path passed from the stack's values object
#   config_path = values.vpc_path
#
#   # Mock outputs for terragrunt validate and plan (when dependency hasn't been applied yet)
#   mock_outputs = {
#     vpc_id             = "vpc-mock123"
#     private_subnet_ids = ["subnet-mock1", "subnet-mock2"]
#     public_subnet_ids  = ["subnet-mock3", "subnet-mock4"]
#   }
#
#   mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
# }

# ==============================================================================
# Inputs (parameterized via the `values` object from stack)
# ==============================================================================

inputs = {
  # Access values passed from terragrunt.stack.hcl using the `values` object
  # The `values` object contains all key-value pairs from the stack's unit definition

  # Basic configuration from stack values
  name        = values.name
  environment = try(values.environment, "dev")
  aws_region  = try(values.aws_region, "us-east-1")

  # Example: Reference dependency outputs (uncomment when using dependencies)
  # vpc_id     = dependency.vpc.outputs.vpc_id
  # subnet_ids = dependency.vpc.outputs.private_subnet_ids

  # Common tags (merge stack values with unit-specific tags)
  tags = merge(
    try(values.common_tags, {}),
    {
      Name        = values.name
      Environment = try(values.environment, "dev")
      ManagedBy   = "Terragrunt"
      Unit        = "[UNIT_NAME]"
    }
  )

  # Add module-specific inputs here
  # [VARIABLE_NAME] = values.[VALUE_KEY]
}

# ==============================================================================
# Optional: Feature Flags for runtime control
# ==============================================================================

# Define feature flags that can be overridden at runtime
# feature "enable_feature" {
#   default = try(values.enable_feature, false)
# }

# ==============================================================================
# Optional: Exclude block for conditional execution
# ==============================================================================

# Exclude this unit from certain operations based on conditions
# exclude {
#   if      = try(values.skip_unit, false)
#   actions = ["all"]
#   exclude_dependencies = false
# }

# ==============================================================================
# Optional: Error handling
# ==============================================================================

# errors {
#   retry "transient_errors" {
#     retryable_errors = [
#       "(?s).*Error.*timeout.*",
#     ]
#     max_attempts       = 3
#     sleep_interval_sec = 5
#   }
# }

# ==============================================================================
# Optional: Hooks for pre/post operations
# ==============================================================================

# terraform {
#   before_hook "validate_inputs" {
#     commands = ["apply", "plan"]
#     execute  = ["bash", "-c", "echo 'Validating inputs for [UNIT_NAME]...'"]
#   }
#
#   after_hook "notify_completion" {
#     commands     = ["apply"]
#     execute      = ["bash", "-c", "echo '[UNIT_NAME] deployment completed'"]
#     run_on_error = false
#   }
# }