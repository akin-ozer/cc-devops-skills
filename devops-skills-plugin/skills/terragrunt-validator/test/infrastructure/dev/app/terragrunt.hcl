# Application ECS Configuration for Development

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/ecs/aws?version=5.7.0"
}

# Dependencies
dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock-123456"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "database" {
  config_path = "../database"

  mock_outputs = {
    db_instance_endpoint = "mock-db-endpoint.rds.amazonaws.com:5432"
    db_instance_name     = "myappdb"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "cache" {
  config_path = "../cache"

  mock_outputs = {
    endpoint = "mock-redis-endpoint.cache.amazonaws.com:6379"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  common = read_terragrunt_config(find_in_parent_folders("common.hcl"))
}

inputs = {
  cluster_name = "${local.common.locals.name_prefix}-dev-cluster"

  cluster_configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${local.common.locals.name_prefix}-dev"
      }
    }
  }

  # Fargate capacity providers
  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 50
        base   = 20
      }
    }
    FARGATE_SPOT = {
      default_capacity_provider_strategy = {
        weight = 50
      }
    }
  }

  # Service configuration
  services = {
    myapp = {
      cpu    = 512
      memory = 1024

      container_definitions = {
        app = {
          cpu       = 512
          memory    = 1024
          essential = true
          image     = "nginx:latest"

          port_mappings = [
            {
              name          = "http"
              containerPort = 80
              hostPort      = 80
              protocol      = "tcp"
            }
          ]

          environment = [
            {
              name  = "DATABASE_ENDPOINT"
              value = dependency.database.outputs.db_instance_endpoint
            },
            {
              name  = "REDIS_ENDPOINT"
              value = dependency.cache.outputs.endpoint
            },
            {
              name  = "ENVIRONMENT"
              value = "dev"
            }
          ]

          readonly_root_filesystem = false
        }
      }

      subnet_ids = dependency.vpc.outputs.private_subnet_ids

      security_group_rules = {
        ingress_http = {
          type        = "ingress"
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["10.0.0.0/16"]
        }
      }
    }
  }

  tags = {
    Module = "app"
  }
}
