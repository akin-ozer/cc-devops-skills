# Common Terraform Patterns

## Multi-Environment Pattern

### Directory Structure
```
terraform/
├── modules/
│   └── app/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    ├── staging/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars
    │   └── backend.tf
    └── production/
        ├── main.tf
        ├── variables.tf
        ├── terraform.tfvars
        └── backend.tf
```

### Implementation

```hcl
# environments/dev/main.tf
module "app" {
  source = "../../modules/app"

  environment     = "dev"
  instance_type   = "t3.micro"
  instance_count  = 1
  enable_backups  = false
}

# environments/production/main.tf
module "app" {
  source = "../../modules/app"

  environment     = "production"
  instance_type   = "t3.large"
  instance_count  = 3
  enable_backups  = true
}
```

## Workspace Pattern

### Using Workspaces for Environments

```hcl
# main.tf
locals {
  environment = terraform.workspace

  environment_config = {
    dev = {
      instance_type  = "t3.micro"
      instance_count = 1
      enable_backups = false
    }
    staging = {
      instance_type  = "t3.small"
      instance_count = 2
      enable_backups = true
    }
    prod = {
      instance_type  = "t3.large"
      instance_count = 3
      enable_backups = true
    }
  }

  config = local.environment_config[local.environment]
}

resource "aws_instance" "app" {
  count         = local.config.instance_count
  instance_type = local.config.instance_type
  # ...
}

# Usage:
# terraform workspace new dev
# terraform workspace select dev
# terraform apply
```

## Blue-Green Deployment Pattern

### Infrastructure for Blue-Green Deployments

```hcl
variable "active_environment" {
  description = "Active environment (blue or green)"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "Active environment must be blue or green."
  }
}

# Blue environment
module "blue_environment" {
  source = "./modules/environment"

  name            = "blue"
  instance_count  = var.active_environment == "blue" ? var.desired_capacity : 1
  min_size        = var.active_environment == "blue" ? var.min_capacity : 0
  max_size        = var.active_environment == "blue" ? var.max_capacity : 1
  ami_id          = var.blue_ami_id
  # ...
}

# Green environment
module "green_environment" {
  source = "./modules/environment"

  name            = "green"
  instance_count  = var.active_environment == "green" ? var.desired_capacity : 1
  min_size        = var.active_environment == "green" ? var.min_capacity : 0
  max_size        = var.active_environment == "green" ? var.max_capacity : 1
  ami_id          = var.green_ami_id
  # ...
}

# Load balancer with weighted routing
resource "aws_lb_target_group" "blue" {
  name     = "blue-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group" "green" {
  name     = "green-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_listener_rule" "weighted" {
  listener_arn = aws_lb_listener.main.arn

  action {
    type = "forward"

    forward {
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = var.active_environment == "blue" ? 100 : 0
      }

      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = var.active_environment == "green" ? 100 : 0
      }
    }
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
```

## Data Layer Separation Pattern

### Separating Stateful and Stateless Infrastructure

```
terraform/
├── data-layer/          # Stateful resources (databases, storage)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── backend.tf
└── app-layer/           # Stateless resources (compute, networking)
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    └── backend.tf
```

```hcl
# data-layer/main.tf
resource "aws_db_instance" "main" {
  allocated_storage    = 100
  engine              = "postgres"
  engine_version      = "14.7"
  instance_class      = "db.t3.large"
  name                = "appdb"
  username            = var.db_username
  password            = var.db_password

  # Prevent accidental deletion
  deletion_protection = true
  skip_final_snapshot = false

  lifecycle {
    prevent_destroy = true
  }
}

# data-layer/outputs.tf
output "database_endpoint" {
  value = aws_db_instance.main.endpoint
}

# app-layer/main.tf
data "terraform_remote_state" "data_layer" {
  backend = "s3"

  config = {
    bucket = "terraform-state"
    key    = "data-layer/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app" {
  # ...

  user_data = templatefile("${path.module}/user_data.sh", {
    database_endpoint = data.terraform_remote_state.data_layer.outputs.database_endpoint
  })
}
```

## Module Composition Pattern

### Building Complex Infrastructure from Simple Modules

```hcl
# Root configuration
module "network" {
  source = "./modules/network"

  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  tags = local.common_tags
}

module "security" {
  source = "./modules/security"

  vpc_id = module.network.vpc_id

  allowed_cidr_blocks = var.allowed_cidr_blocks

  tags = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnet_ids
  security_group_ids = [module.security.app_security_group_id]

  instance_type  = var.instance_type
  instance_count = var.instance_count

  tags = local.common_tags
}

module "load_balancer" {
  source = "./modules/load_balancer"

  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.public_subnet_ids
  security_group_ids = [module.security.lb_security_group_id]

  target_instances = module.compute.instance_ids

  tags = local.common_tags
}

module "database" {
  source = "./modules/database"

  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.database_subnet_ids
  security_group_ids = [module.security.db_security_group_id]

  database_name = var.database_name
  master_username = var.db_username
  master_password = var.db_password

  tags = local.common_tags
}
```

## Conditional Resource Creation Pattern

### Creating Resources Based on Conditions

```hcl
# Using count for conditional creation
resource "aws_instance" "bastion" {
  count = var.create_bastion ? 1 : 0

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "bastion-host"
  }
}

# Using for_each with conditional map
resource "aws_cloudwatch_log_group" "optional" {
  for_each = var.enable_logging ? toset(var.log_group_names) : toset([])

  name              = each.value
  retention_in_days = var.log_retention_days
}

# Conditional module inclusion
module "cdn" {
  count  = var.enable_cdn ? 1 : 0
  source = "./modules/cdn"

  origin_domain_name = aws_lb.main.dns_name
  # ...
}

# Accessing conditionally created resources
output "bastion_public_ip" {
  value = var.create_bastion ? aws_instance.bastion[0].public_ip : null
}
```

## Service Mesh Pattern

### Implementing Service Discovery and Mesh

```hcl
# Service registry
resource "aws_service_discovery_private_dns_namespace" "main" {
  name = "internal.example.com"
  vpc  = aws_vpc.main.id
}

# Service definitions
resource "aws_service_discovery_service" "backend" {
  name = "backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# ECS service with service discovery
resource "aws_ecs_service" "backend" {
  name            = "backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 3

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.backend.id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }
}
```

## Tagging Strategy Pattern

### Comprehensive Tagging Implementation

```hcl
locals {
  # Mandatory tags
  mandatory_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
    CostCenter  = var.cost_center
  }

  # Optional tags
  optional_tags = var.additional_tags

  # Combined tags
  common_tags = merge(local.mandatory_tags, local.optional_tags)

  # Resource-specific tags
  database_tags = merge(
    local.common_tags,
    {
      Type      = "Database"
      Backup    = "Required"
      Retention = "30days"
    }
  )

  compute_tags = merge(
    local.common_tags,
    {
      Type           = "Compute"
      AutoScaling    = var.enable_autoscaling
      PatchSchedule  = "Sundays-2AM"
    }
  )
}

# Apply tags to resources
resource "aws_instance" "web" {
  # ...
  tags = merge(
    local.compute_tags,
    {
      Name = "${var.project_name}-web-${count.index + 1}"
      Role = "WebServer"
    }
  )
}

resource "aws_db_instance" "main" {
  # ...
  tags = merge(
    local.database_tags,
    {
      Name = "${var.project_name}-db"
    }
  )
}
```

## Secret Injection Pattern

### Securely Managing Secrets

```hcl
# Using AWS Secrets Manager
data "aws_secretsmanager_secret" "app_secrets" {
  name = "${var.environment}/app/secrets"
}

data "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = data.aws_secretsmanager_secret.app_secrets.id
}

locals {
  app_secrets = jsondecode(data.aws_secretsmanager_secret_version.app_secrets.secret_string)
}

# ECS task definition with secrets
resource "aws_ecs_task_definition" "app" {
  family = "app"

  container_definitions = jsonencode([
    {
      name  = "app"
      image = var.app_image

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "${data.aws_secretsmanager_secret.app_secrets.arn}:password::"
        },
        {
          name      = "API_KEY"
          valueFrom = "${data.aws_secretsmanager_secret.app_secrets.arn}:api_key::"
        }
      ]

      environment = [
        {
          name  = "DB_HOST"
          value = aws_db_instance.main.endpoint
        }
      ]
    }
  ])
}

# Lambda function with secrets
resource "aws_lambda_function" "processor" {
  # ...

  environment {
    variables = {
      DB_HOST        = aws_db_instance.main.endpoint
      SECRETS_ARN    = data.aws_secretsmanager_secret.app_secrets.arn
    }
  }
}
```

## Auto-Scaling Pattern

### Comprehensive Auto-Scaling Configuration

```hcl
# Launch template
resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.app.id
  instance_type = var.instance_type

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups            = [aws_security_group.app.id]
    delete_on_termination      = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    environment = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = local.compute_tags
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  min_size         = var.min_capacity
  max_size         = var.max_capacity
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  enabled_metrics = [
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupMaxSize",
    "GroupMinSize",
    "GroupPendingInstances",
    "GroupStandbyInstances",
    "GroupTerminatingInstances",
    "GroupTotalInstances"
  ]

  dynamic "tag" {
    for_each = local.compute_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

# Target tracking scaling policy - CPU
resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Target tracking scaling policy - Request count
resource "aws_autoscaling_policy" "request_count_target" {
  name                   = "${var.project_name}-request-count-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label        = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 1000.0
  }
}

# Scheduled scaling
resource "aws_autoscaling_schedule" "scale_up_morning" {
  scheduled_action_name  = "scale-up-morning"
  min_size               = var.min_capacity
  max_size               = var.max_capacity
  desired_capacity       = var.desired_capacity * 2
  recurrence             = "0 8 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_schedule" "scale_down_evening" {
  scheduled_action_name  = "scale-down-evening"
  min_size               = var.min_capacity
  max_size               = var.max_capacity
  desired_capacity       = var.desired_capacity
  recurrence             = "0 18 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.app.name
}
```

## Disaster Recovery Pattern

### Multi-Region DR Setup

```hcl
# Primary region provider
provider "aws" {
  alias  = "primary"
  region = var.primary_region
}

# DR region provider
provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

# Primary region resources
module "primary_infrastructure" {
  source = "./modules/infrastructure"

  providers = {
    aws = aws.primary
  }

  environment = var.environment
  is_primary  = true
  # ...
}

# DR region resources
module "dr_infrastructure" {
  source = "./modules/infrastructure"

  providers = {
    aws = aws.dr
  }

  environment = var.environment
  is_primary  = false
  # ...
}

# Route53 health check and failover
resource "aws_route53_health_check" "primary" {
  fqdn              = module.primary_infrastructure.load_balancer_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = "/health"
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  set_identifier = "primary"
  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = module.primary_infrastructure.load_balancer_dns
    zone_id               = module.primary_infrastructure.load_balancer_zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "dr" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "app.example.com"
  type    = "A"

  set_identifier = "dr"
  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = module.dr_infrastructure.load_balancer_dns
    zone_id               = module.dr_infrastructure.load_balancer_zone_id
    evaluate_target_health = true
  }
}

# Cross-region replication for S3
resource "aws_s3_bucket_replication_configuration" "replication" {
  provider = aws.primary

  bucket = module.primary_infrastructure.data_bucket_id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = module.dr_infrastructure.data_bucket_arn
      storage_class = "STANDARD_IA"

      replication_time {
        status = "Enabled"
        time {
          minutes = 15
        }
      }

      metrics {
        status = "Enabled"
        event_threshold {
          minutes = 15
        }
      }
    }
  }
}

# RDS read replica in DR region
resource "aws_db_instance" "read_replica" {
  provider = aws.dr

  replicate_source_db = module.primary_infrastructure.database_arn

  instance_class      = var.db_instance_class
  publicly_accessible = false
  skip_final_snapshot = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-db-replica"
      Role = "DR"
    }
  )
}
```

## Cost Optimization Pattern

### Implementing Cost Controls

```hcl
# Use Spot Instances for non-critical workloads
resource "aws_autoscaling_group" "batch_processing" {
  # ...

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1
      on_demand_percentage_above_base_capacity = 20
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.batch.id
        version            = "$Latest"
      }

      override {
        instance_type     = "t3.medium"
        weighted_capacity = 1
      }

      override {
        instance_type     = "t3.large"
        weighted_capacity = 2
      }
    }
  }
}

# Schedule shutdown for non-production environments
resource "aws_autoscaling_schedule" "shutdown_evening" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "shutdown-evening"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = "0 20 * * *"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

resource "aws_autoscaling_schedule" "startup_morning" {
  count = var.environment != "production" ? 1 : 0

  scheduled_action_name  = "startup-morning"
  min_size               = var.min_capacity
  max_size               = var.max_capacity
  desired_capacity       = var.desired_capacity
  recurrence             = "0 8 * * MON-FRI"
  autoscaling_group_name = aws_autoscaling_group.app.name
}

# Use lifecycle policies for S3
resource "aws_s3_bucket_lifecycle_configuration" "data" {
  bucket = aws_s3_bucket.data.id

  rule {
    id     = "transition-old-data"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Budget alerts
resource "aws_budgets_budget" "monthly" {
  name              = "${var.project_name}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  cost_filter {
    name = "TagKeyValue"
    values = [
      "Project$${var.project_name}",
    ]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
```
