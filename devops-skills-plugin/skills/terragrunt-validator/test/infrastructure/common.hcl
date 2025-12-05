# Common variables shared across all environments

locals {
  # AWS Region
  region = "us-east-1"

  # Availability zones
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # VPC CIDR blocks per environment
  vpc_cidrs = {
    dev     = "10.0.0.0/16"
    staging = "10.1.0.0/16"
    prod    = "10.2.0.0/16"
  }

  # Common resource naming convention
  name_prefix = "myapp"

  # Backup retention periods
  backup_retention = {
    dev     = 7
    staging = 14
    prod    = 30
  }

  # Instance sizes per environment
  instance_sizes = {
    dev = {
      database = "db.t3.micro"
      cache    = "cache.t3.micro"
      app      = "t3.small"
    }
    staging = {
      database = "db.t3.small"
      cache    = "cache.t3.small"
      app      = "t3.medium"
    }
    prod = {
      database = "db.r6g.large"
      cache    = "cache.r6g.large"
      app      = "t3.large"
    }
  }

  # Multi-AZ configuration
  multi_az = {
    dev     = false
    staging = false
    prod    = true
  }

  # High availability configuration
  ha_config = {
    dev = {
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
    staging = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
    prod = {
      min_size     = 2
      max_size     = 10
      desired_size = 3
    }
  }
}
