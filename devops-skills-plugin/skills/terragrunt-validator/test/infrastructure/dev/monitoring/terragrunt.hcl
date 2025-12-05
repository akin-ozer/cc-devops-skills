# Monitoring Configuration for Development with Datadog

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/cloudwatch/aws//modules/log-group?version=4.3.0"
}

# Generate Datadog provider configuration (custom provider)
generate "datadog_provider" {
  path      = "datadog_provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_providers {
    datadog = {
      source  = "datadog/datadog"
      version = "~> 3.30.0"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}
EOF
}

# Dependencies
dependency "app" {
  config_path = "../app"

  mock_outputs = {
    cluster_name = "myapp-dev-cluster"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  name              = "/aws/ecs/${local.common.locals.name_prefix}-dev"
  retention_in_days = 7

  tags = {
    Module      = "monitoring"
    Application = dependency.app.outputs.cluster_name
  }
}

# Datadog monitors and dashboards would be configured here as well
# using the datadog provider resources
