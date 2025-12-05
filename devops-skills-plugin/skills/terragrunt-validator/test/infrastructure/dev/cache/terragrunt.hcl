# ElastiCache Redis Configuration for Development

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  # Using a Git module source to test custom module detection
  source = "git::https://github.com/cloudposse/terraform-aws-elasticache-redis.git?ref=0.52.0"
}

# Dependency on VPC
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock-123456"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2", "subnet-mock-3"]
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  name      = "${local.common.locals.name_prefix}-dev-redis"
  namespace = "myapp"
  stage     = "dev"

  vpc_id  = dependency.vpc.outputs.vpc_id
  subnets = dependency.vpc.outputs.private_subnet_ids

  cluster_size               = 1
  instance_type              = "cache.t3.micro"
  engine_version             = "7.0"
  family                     = "redis7"
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true

  automatic_failover_enabled = false
  multi_az_enabled           = false

  parameter = [
    {
      name  = "maxmemory-policy"
      value = "allkeys-lru"
    }
  ]

  tags = {
    Module = "cache"
  }
}
