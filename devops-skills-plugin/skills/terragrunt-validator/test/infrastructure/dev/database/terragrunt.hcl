# RDS Database Configuration for Development

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.3.0"
}

# Dependency on VPC
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
  identifier = "${local.common.locals.name_prefix}-dev-db"

  engine               = "postgres"
  engine_version       = "15.4"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = local.common.locals.instance_sizes["dev"]["database"]

  allocated_storage     = 20
  max_allocated_storage = 100

  db_name  = local.db_name
  username = "dbadmin"
  port     = 5432

  # Use VPC outputs
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name
  vpc_security_group_ids = [] # Should create security group

  multi_az                = false
  deletion_protection     = false
  backup_retention_period = 7
  skip_final_snapshot     = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  create_cloudwatch_log_group     = true

  parameters = [
    {
      name  = "autovacuum"
      value = 1
    },
    {
      name  = "client_encoding"
      value = "utf8"
    }
  ]

  tags = {
    Module = "database"
  }
}
