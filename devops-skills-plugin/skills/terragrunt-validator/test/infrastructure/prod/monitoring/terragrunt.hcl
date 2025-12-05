# Monitoring Configuration for Production with Datadog and New Relic

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/cloudwatch/aws//modules/log-group?version=4.3.0"
}

# Generate Datadog provider configuration
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
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.25.0"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = "https://api.datadoghq.com/"
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_api_key
  region     = "US"
}

variable "datadog_api_key" {
  type      = string
  sensitive = true
}

variable "datadog_app_key" {
  type      = string
  sensitive = true
}

variable "newrelic_account_id" {
  type = string
}

variable "newrelic_api_key" {
  type      = string
  sensitive = true
}
EOF
}

# Dependencies
dependency "database" {
  config_path = "../database"

  mock_outputs = {
    db_instance_identifier = "myapp-prod-db"
    db_instance_endpoint   = "mock-db-endpoint.rds.amazonaws.com:5432"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  name              = "/aws/ecs/${local.common.locals.name_prefix}-prod"
  retention_in_days = 90 # Longer retention for production

  tags = {
    Module      = "monitoring"
    Environment = "production"
    Compliance  = "required"
  }
}

# Additional monitoring resources would be configured using datadog and newrelic providers
# Examples:
# - Datadog monitors for database metrics
# - Datadog APM configuration
# - New Relic alert policies
# - New Relic dashboards
