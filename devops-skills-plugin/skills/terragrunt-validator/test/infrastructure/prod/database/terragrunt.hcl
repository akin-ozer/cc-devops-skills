# RDS Database Configuration for Production

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.3.0"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id                     = "vpc-mock-123456"
    database_subnet_ids        = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
    database_subnet_group_name = "mock-subnet-group"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
  mock_outputs_merge_strategy_with_state  = "shallow"
}

locals {
  common  = read_terragrunt_config(find_in_parent_folders("common.hcl"))
  db_name = "myappdb"
}

inputs = {
  identifier = "${local.common.locals.name_prefix}-prod-db"

  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = local.common.locals.instance_sizes["prod"]["database"]

  allocated_storage     = 100
  max_allocated_storage = 500
  storage_encrypted     = true

  db_name  = local.db_name
  username = "dbadmin"
  port     = 5432

  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = []

  # Production settings
  multi_az                  = true
  deletion_protection       = true
  backup_retention_period   = 30
  skip_final_snapshot       = false
  final_snapshot_identifier = "${local.common.locals.name_prefix}-prod-db-final-snapshot"

  # Performance Insights
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]
  create_cloudwatch_log_group           = true

  # Automated backups
  backup_window      = "03:00-06:00"
  maintenance_window = "Mon:00:00-Mon:03:00"

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    },
    {
      name  = "log_min_duration_statement"
      value = "1000"
    }
  ]

  tags = {
    Module     = "database"
    Compliance = "required"
  }
}
