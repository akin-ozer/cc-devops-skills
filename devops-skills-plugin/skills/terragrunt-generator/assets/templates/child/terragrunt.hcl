# Child Module Terragrunt Configuration
# Module: [MODULE_NAME]
# Description: [MODULE_DESCRIPTION]
# Dependencies: [LIST_DEPENDENCIES or "None"]

# Include root configuration
# RECOMMENDED: Use explicit root file reference for new projects
include "root" {
  path = find_in_parent_folders("root.hcl")
}

# LEGACY: For existing projects using terragrunt.hcl as root
# include "root" {
#   path = find_in_parent_folders()
# }

# Terraform module source
terraform {
  source = "[MODULE_SOURCE]"

  # Examples:
  # Local module:
  #   source = "../../modules/vpc"
  # Git repository:
  #   source = "git::https://github.com/[ORG]/[REPO].git//[PATH]?ref=[VERSION]"
  # Terraform Registry:
  #   source = "tfr:///[NAMESPACE]/[NAME]/[PROVIDER]?version=[VERSION]"
}

# Optional dependencies on other Terragrunt modules
# Uncomment only when this module has real upstream dependencies.
#
# dependencies {
#   paths = [
#     "../vpc",
#     "../security-groups",
#   ]
# }
#
# dependency "vpc" {
#   config_path = "../vpc"
#
#   # Mock outputs for terragrunt validate and plan
#   mock_outputs = {
#     vpc_id = "vpc-mock123"
#   }
#
#   # Allow destroy even if dependencies exist
#   mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
# }

# Module-specific inputs
inputs = {
  # Basic configuration
  name = "[RESOURCE_NAME]"

  # Reference dependency outputs
  # [input_name] = dependency.[DEPENDENCY_NAME].outputs.[output_name]

  # Override root variables if needed
  # environment = "production"

  # Module-specific variables
  # [variable_name] = "[value]"
}

# Optional: Hooks for running commands before/after Terraform operations
# terraform {
#   before_hook "before_init" {
#     commands = ["init"]
#     execute  = ["echo", "Running init..."]
#   }
#
#   after_hook "after_apply" {
#     commands     = ["apply"]
#     execute      = ["echo", "Resources deployed successfully"]
#     run_on_error = false
#   }
# }

# Optional: Exclude this module from certain operations (replaces deprecated 'skip')
# The exclude block provides fine-grained control over when this unit should be skipped
# exclude {
#   if      = false                    # Condition to evaluate (use locals or feature flags)
#   actions = ["plan", "apply"]        # Actions to exclude: "plan", "apply", "destroy", "all", "all_except_output"
#   exclude_dependencies = false       # Whether to also exclude dependencies
# }

# Example: Exclude based on environment using feature flags
# feature "skip_in_dev" {
#   default = false
# }
# exclude {
#   if      = feature.skip_in_dev.value
#   actions = ["apply", "destroy"]
#   exclude_dependencies = false
# }

# Example: Exclude apply/destroy on weekends
# locals {
#   day_of_week = formatdate("EEE", timestamp())
#   is_weekend  = contains(["Fri", "Sat", "Sun"], local.day_of_week)
# }
# exclude {
#   if      = local.is_weekend
#   actions = ["apply", "destroy"]
# }

# Optional: Prevent destruction of this module
# prevent_destroy = false

# Optional: Module-specific error handling (overrides root errors block)
# errors {
#   retry "module_specific_errors" {
#     retryable_errors = [
#       "(?s).*Module specific error pattern.*",
#     ]
#     max_attempts       = 3
#     sleep_interval_sec = 5
#   }
# }
