# VPC Configuration for Production

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  name = "${local.common.locals.name_prefix}-prod-vpc"
  cidr = "10.2.0.0/16"

  azs              = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets  = ["10.2.1.0/24", "10.2.2.0/24", "10.2.3.0/24"]
  public_subnets   = ["10.2.101.0/24", "10.2.102.0/24", "10.2.103.0/24"]
  database_subnets = ["10.2.201.0/24", "10.2.202.0/24", "10.2.203.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false # Multiple NAT gateways for HA
  one_nat_gateway_per_az = true  # One per AZ for production
  enable_dns_hostnames   = true
  enable_dns_support     = true

  enable_flow_log                      = true
  create_flow_log_cloudwatch_iam_role  = true
  create_flow_log_cloudwatch_log_group = true

  tags = {
    Module     = "vpc"
    Compliance = "required"
  }
}
