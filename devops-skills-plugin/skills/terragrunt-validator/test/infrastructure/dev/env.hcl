# Development Environment Configuration

include "root" {
  path = find_in_parent_folders("root.hcl")
}

locals {
  environment = "dev"
  common      = read_terragrunt_config(find_in_parent_folders("common.hcl"))

  env_tags = {
    Environment = "development"
    CostCenter  = "engineering"
  }
}

inputs = {
  environment        = local.environment
  vpc_cidr           = local.common.locals.vpc_cidrs[local.environment]
  availability_zones = local.common.locals.availability_zones
  backup_retention   = local.common.locals.backup_retention[local.environment]
  multi_az           = local.common.locals.multi_az[local.environment]

  tags = merge(
    local.env_tags,
    {
      Environment = local.environment
    }
  )
}
