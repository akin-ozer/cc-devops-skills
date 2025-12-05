# Terragrunt Common Generation Patterns

## Overview

This reference provides common patterns and code examples for generating Terragrunt configurations. Use these patterns as building blocks when creating new Terragrunt resources.

## Root Configuration Patterns

### Pattern 1: Basic Root with S3 Backend

**Use when:** Starting a new Terragrunt project with AWS S3 backend

```hcl
# Root terragrunt.hcl
remote_state {
  backend = "s3"
  config = {
    bucket         = "company-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = var.region
}
EOF
}

inputs = {
  region = "us-east-1"
  common_tags = {
    ManagedBy = "Terragrunt"
  }
}
```

### Pattern 2: Multi-Account Root Configuration

**Use when:** Managing multiple AWS accounts with role assumption

```hcl
# Root terragrunt.hcl
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_id  = local.account_vars.locals.account_id
  region      = local.region_vars.locals.region
  environment = local.env_vars.locals.environment
}

remote_state {
  backend = "s3"
  config = {
    bucket         = "terraform-state-${local.account_id}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = local.region
    encrypt        = true
    dynamodb_table = "terraform-locks-${local.environment}"

    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformRole"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.region}"

  assume_role {
    role_arn = "arn:aws:iam::${local.account_id}:role/TerraformRole"
  }

  default_tags {
    tags = {
      Environment = "${local.environment}"
      ManagedBy   = "Terragrunt"
    }
  }
}
EOF
}

inputs = {
  account_id  = local.account_id
  region      = local.region
  environment = local.environment
}
```

### Pattern 3: Multi-Cloud Root Configuration

**Use when:** Managing resources across multiple cloud providers

```hcl
# Root terragrunt.hcl
generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}
EOF
}
```

## Child Module Patterns

### Pattern 1: Simple Module with No Dependencies

**Use when:** Creating standalone infrastructure component

```hcl
# modules/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

inputs = {
  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Name = "my-vpc"
  }
}
```

### Pattern 2: Module with Single Dependency

**Use when:** Creating a resource that depends on another module's outputs

```hcl
# modules/rds/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.1.0"
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock123"
    database_subnet_ids = ["subnet-mock1", "subnet-mock2"]
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
}

dependency "security_group" {
  config_path = "../security-groups/database"

  mock_outputs = {
    security_group_id = "sg-mock123"
  }

  mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy"]
}

inputs = {
  identifier = "mydb"
  engine     = "postgres"

  vpc_security_group_ids = [dependency.security_group.outputs.security_group_id]
  db_subnet_group_name   = dependency.vpc.outputs.database_subnet_group_name

  allocated_storage = 20
  instance_class    = "db.t3.micro"
}
```

### Pattern 3: Module with Multiple Dependencies

**Use when:** Creating complex infrastructure with multiple upstream dependencies

```hcl
# modules/eks/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/eks/aws?version=19.15.0"
}

dependencies {
  paths = ["../vpc", "../security-groups", "../iam-roles"]
}

dependency "vpc" {
  config_path = "../vpc"

  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-1", "subnet-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "security_groups" {
  config_path = "../security-groups"

  mock_outputs = {
    cluster_security_group_id = "sg-mock"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "iam" {
  config_path = "../iam-roles"

  mock_outputs = {
    cluster_role_arn = "arn:aws:iam::123456789012:role/mock-role"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  cluster_name    = "my-eks-cluster"
  cluster_version = "1.28"

  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_ids

  cluster_security_group_id = dependency.security_groups.outputs.cluster_security_group_id
  iam_role_arn              = dependency.iam.outputs.cluster_role_arn

  enable_irsa = true
}
```

### Pattern 4: Module with Conditional Logic

**Use when:** Generating configurations with environment-specific variations

```hcl
# modules/app/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env = get_env("ENVIRONMENT", "dev")

  instance_counts = {
    dev  = 1
    staging = 2
    prod = 3
  }

  instance_types = {
    dev  = "t3.micro"
    staging = "t3.small"
    prod = "t3.medium"
  }
}

terraform {
  source = "../../terraform-modules/app"
}

inputs = {
  environment    = local.env
  instance_count = local.instance_counts[local.env]
  instance_type  = local.instance_types[local.env]

  enable_monitoring = local.env == "prod" ? true : false
  enable_backups    = local.env == "prod" ? true : false

  tags = merge(
    {
      Environment = local.env
      ManagedBy   = "Terragrunt"
    },
    local.env == "prod" ? { CriticalResource = "true" } : {}
  )
}
```

## Environment-Specific Patterns

### Pattern 1: Environment Configuration Files

**Use when:** Managing multiple environments with shared structure

```
infrastructure/
├── terragrunt.hcl           # Root config
├── _env/
│   ├── prod.hcl            # Production variables
│   ├── staging.hcl         # Staging variables
│   └── dev.hcl             # Development variables
├── prod/
│   ├── env.hcl -> ../_env/prod.hcl
│   └── vpc/
│       └── terragrunt.hcl
└── staging/
    ├── env.hcl -> ../_env/staging.hcl
    └── vpc/
        └── terragrunt.hcl
```

**_env/prod.hcl:**
```hcl
locals {
  environment = "prod"
  region      = "us-east-1"

  vpc_cidr = "10.0.0.0/16"

  instance_type = "t3.medium"
  min_size      = 3
  max_size      = 10
}
```

**prod/vpc/terragrunt.hcl:**
```hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

inputs = {
  name = "${local.env.locals.environment}-vpc"
  cidr = local.env.locals.vpc_cidr

  azs = ["${local.env.locals.region}a", "${local.env.locals.region}b"]
}
```

## Advanced Patterns

### Pattern 1: Dynamic Provider Configuration

**Use when:** Provider configuration varies by module or environment

```hcl
# modules/cross-account-resource/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  target_account_id = "987654321098"
}

generate "provider_override" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "aws" {
  alias  = "target_account"
  region = var.region

  assume_role {
    role_arn = "arn:aws:iam::${local.target_account_id}:role/CrossAccountRole"
  }
}
EOF
}

terraform {
  source = "../../terraform-modules/cross-account-resource"
}
```

### Pattern 2: Module Composition

**Use when:** Combining multiple modules in a single configuration

```hcl
# modules/application-stack/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../terraform-modules/application-stack"
}

dependency "vpc" {
  config_path = "../networking/vpc"
  mock_outputs = {
    vpc_id     = "vpc-mock"
    subnet_ids = ["subnet-1", "subnet-2"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "database" {
  config_path = "../data/rds"
  mock_outputs = {
    endpoint = "mock.endpoint.rds.amazonaws.com"
    port     = 5432
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "cache" {
  config_path = "../data/elasticache"
  mock_outputs = {
    endpoint = "mock.cache.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  name = "my-application"

  # Networking
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_ids

  # Database
  database_endpoint = dependency.database.outputs.endpoint
  database_port     = dependency.database.outputs.port

  # Cache
  cache_endpoint = dependency.cache.outputs.endpoint

  # Application configuration
  image_tag      = "latest"
  desired_count  = 2
  cpu            = 256
  memory         = 512
}
```

### Pattern 3: Hooks for Pre/Post Operations

**Use when:** Need to run commands before or after Terraform operations

```hcl
# modules/database/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "tfr:///terraform-aws-modules/rds/aws?version=6.1.0"

  before_hook "backup_check" {
    commands = ["apply"]
    execute  = ["bash", "-c", "echo 'Starting database deployment...'"]
  }

  after_hook "notify_deployment" {
    commands     = ["apply"]
    execute      = ["bash", "-c", "curl -X POST https://slack.webhook.url -d '{\"text\":\"Database deployed\"}'"]
    run_on_error = false
  }

  error_hook "notify_error" {
    commands = ["apply", "plan"]
    execute  = ["bash", "-c", "echo 'Error occurred during Terraform operation'"]
  }
}
```

### Pattern 4: External Data Integration

**Use when:** Need to fetch dynamic values from external sources

```hcl
# modules/app/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

locals {
  # Fetch current git branch
  git_branch = run_cmd("--terragrunt-quiet", "git", "rev-parse", "--abbrev-ref", "HEAD")

  # Fetch AWS account ID
  account_id = run_cmd("--terragrunt-quiet", "aws", "sts", "get-caller-identity", "--query", "Account", "--output", "text")

  # Read JSON configuration
  config = jsondecode(file("${get_terragrunt_dir()}/config.json"))
}

terraform {
  source = "../../terraform-modules/app"
}

inputs = {
  git_branch = local.git_branch
  account_id = local.account_id

  app_config = local.config

  name = "${local.config.app_name}-${local.git_branch}"
}
```

## Custom Provider Patterns

### Pattern 1: Kubernetes Provider with EKS

**Use when:** Managing Kubernetes resources with Terragrunt

```hcl
# modules/k8s-app/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

dependency "eks" {
  config_path = "../eks-cluster"

  mock_outputs = {
    cluster_endpoint          = "https://mock-endpoint"
    cluster_certificate       = "mock-cert"
    cluster_name              = "mock-cluster"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

generate "kubernetes_provider" {
  path      = "kubernetes_provider.tf"
  if_exists = "overwrite"
  contents  = <<EOF
provider "kubernetes" {
  host                   = "${dependency.eks.outputs.cluster_endpoint}"
  cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate}")

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      "${dependency.eks.outputs.cluster_name}"
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = "${dependency.eks.outputs.cluster_endpoint}"
    cluster_ca_certificate = base64decode("${dependency.eks.outputs.cluster_certificate}")

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        "${dependency.eks.outputs.cluster_name}"
      ]
    }
  }
}
EOF
}

terraform {
  source = "../../terraform-modules/k8s-app"
}
```

### Pattern 2: Multiple Provider Versions

**Use when:** Different modules require different provider versions

```hcl
# modules/legacy-resource/terragrunt.hcl
include "root" {
  path = find_in_parent_folders()
}

generate "provider_version_override" {
  path      = "versions.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"  # Legacy version for compatibility
    }
  }
}
EOF
}

terraform {
  source = "../../terraform-modules/legacy-resource"
}
```

## Stacks Patterns (2025)

Terragrunt Stacks allow you to define infrastructure blueprints that generate unit configurations programmatically. GA since v0.78.0 (May 2025).

### Pattern 1: Basic Stack with Units

**Use when:** Creating a reusable infrastructure blueprint

```hcl
# terragrunt.stack.hcl
locals {
  environment = "prod"
  aws_region  = "us-east-1"
  units_path  = find_in_parent_folders("catalog/units")
}

unit "vpc" {
  source = "${local.units_path}/vpc"
  path   = "vpc"
  values = {
    vpc_name    = "${local.environment}-vpc"
    cidr        = "10.0.0.0/16"
    environment = local.environment
  }
}

unit "database" {
  source = "${local.units_path}/database"
  path   = "database"
  values = {
    db_name     = "${local.environment}-db"
    engine      = "postgres"
    vpc_path    = "../vpc"
    environment = local.environment
  }
}
```

### Pattern 2: Stack with Git-Based Unit Sources

**Use when:** Using versioned unit definitions from a remote repository

```hcl
# terragrunt.stack.hcl
unit "vpc" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//units/vpc?ref=v1.0.0"
  path   = "vpc"
  values = {
    vpc_name = "main"
    cidr     = "10.0.0.0/16"
  }
}

unit "database" {
  source = "git::git@github.com:acme/infrastructure-catalog.git//units/database?ref=v1.0.0"
  path   = "database"
  values = {
    engine   = "postgres"
    version  = "15"
    vpc_path = "../vpc"
  }
}
```

### Pattern 3: Catalog Unit with Values

**Use when:** Creating reusable unit templates for stacks

```hcl
# catalog/units/vpc/terragrunt.hcl
include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0"
}

inputs = {
  name = values.vpc_name
  cidr = values.cidr

  azs             = ["${values.aws_region}a", "${values.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = try(values.enable_nat, true)

  tags = {
    Environment = values.environment
    ManagedBy   = "Terragrunt"
  }
}
```

### Pattern 4: Stack Commands

```bash
# Generate unit configurations from stack
terragrunt stack generate

# Plan all units in the stack
terragrunt stack run plan

# Apply all units in the stack
terragrunt stack run apply

# Get aggregated outputs from all units
terragrunt stack output

# Clean generated directories
terragrunt stack clean
```

## Feature Flags Patterns (2025)

Feature flags provide runtime control over Terragrunt behavior.

### Pattern 1: Basic Feature Flag

**Use when:** Enabling/disabling features at runtime

```hcl
# terragrunt.hcl
feature "enable_monitoring" {
  default = false
}

inputs = {
  enable_monitoring = feature.enable_monitoring.value
}
```

**Usage:**
```bash
# Override via CLI
terragrunt apply --feature enable_monitoring=true

# Override via environment variable
export TG_FEATURE="enable_monitoring=true"
terragrunt apply
```

### Pattern 2: Feature Flag for Module Versioning

**Use when:** Controlling module versions at runtime

```hcl
# terragrunt.hcl
feature "module_version" {
  default = "v1.0.0"
}

terraform {
  source = "git::git@github.com:acme/modules.git//vpc?ref=${feature.module_version.value}"
}
```

### Pattern 3: Feature Flag with Conditional Logic

**Use when:** Complex conditional behavior based on flags

```hcl
# terragrunt.hcl
feature "enable_ha" {
  default = false
}

locals {
  instance_count = feature.enable_ha.value ? 3 : 1
  instance_type  = feature.enable_ha.value ? "t3.medium" : "t3.micro"
}

inputs = {
  instance_count = local.instance_count
  instance_type  = local.instance_type
}
```

### Pattern 4: Environment-Based Feature Flags

**Use when:** Controlling deployments per environment

```hcl
# prod/root.hcl
feature "prod" {
  default = false
}

exclude {
  if      = !feature.prod.value
  actions = ["all_except_output"]
}
```

**Usage:**
```bash
# Enable production deployment
terragrunt run --all apply --feature prod=true
```

## Exclude Block Patterns (2025)

The `exclude` block replaces the deprecated `skip` attribute with more fine-grained control.

### Pattern 1: Basic Exclusion

**Use when:** Excluding a unit from all operations

```hcl
# terragrunt.hcl
exclude {
  if                   = true
  actions              = ["all"]
  exclude_dependencies = false
}
```

### Pattern 2: Exclude Specific Actions

**Use when:** Excluding only certain operations

```hcl
# terragrunt.hcl
exclude {
  if      = true
  actions = ["apply", "destroy"]  # Still allows plan and output
}
```

### Pattern 3: Conditional Exclusion with Feature Flags

**Use when:** Dynamic exclusion based on runtime flags

```hcl
# terragrunt.hcl
feature "skip_in_dev" {
  default = false
}

exclude {
  if      = feature.skip_in_dev.value
  actions = ["apply", "destroy"]
  exclude_dependencies = false
}
```

### Pattern 4: Time-Based Exclusion

**Use when:** Preventing deployments during certain periods

```hcl
# terragrunt.hcl
locals {
  day_of_week = formatdate("EEE", timestamp())
  is_weekend  = contains(["Fri", "Sat", "Sun"], local.day_of_week)
}

exclude {
  if      = local.is_weekend
  actions = ["apply", "destroy"]
}
```

### Pattern 5: All Except Output

**Use when:** Allowing only output retrieval

```hcl
# terragrunt.hcl
exclude {
  if      = true
  actions = ["all_except_output"]
}
```

## Errors Block Patterns (2025)

The `errors` block replaces deprecated `retryable_errors`, `retry_max_attempts`, and `retry_sleep_interval_sec`.

### Pattern 1: Basic Retry Configuration

**Use when:** Handling transient errors with retries

```hcl
# terragrunt.hcl
errors {
  retry "transient_errors" {
    retryable_errors = [
      "(?s).*Failed to load state.*tcp.*timeout.*",
      "(?s).*Error installing provider.*TLS handshake timeout.*",
      "(?s).*429 Too Many Requests.*",
    ]
    max_attempts       = 3
    sleep_interval_sec = 5
  }
}
```

### Pattern 2: Ignore Safe Errors

**Use when:** Ignoring known safe-to-ignore errors

```hcl
# terragrunt.hcl
errors {
  ignore "known_warnings" {
    ignorable_errors = [
      ".*Warning: Resource already exists.*",
      "!.*Error: critical.*"  # Negation: don't ignore critical errors
    ]
    message = "Ignoring known safe warnings"
    signals = {
      alert_team = false
    }
  }
}
```

### Pattern 3: Combined Retry and Ignore

**Use when:** Comprehensive error handling

```hcl
# terragrunt.hcl
errors {
  retry "network_errors" {
    retryable_errors = [
      "(?s).*connection reset by peer.*",
      "(?s).*timeout.*",
    ]
    max_attempts       = 3
    sleep_interval_sec = 10
  }

  ignore "deprecation_warnings" {
    ignorable_errors = [
      ".*Deprecation Warning.*",
    ]
    message = "Ignoring deprecation warnings"
  }
}
```

### Pattern 4: Feature Flag Controlled Error Handling

**Use when:** Dynamic error handling based on flags

```hcl
# terragrunt.hcl
feature "enable_flaky_module" {
  default = false
}

errors {
  ignore "flaky_module_errors" {
    ignorable_errors = feature.enable_flaky_module.value ? [
      ".*Error: flaky module error.*"
    ] : []
    message = "Ignoring flaky module error"
    signals = {
      send_notification = true
    }
  }
}
```

## OpenTofu Engine Patterns (2025)

Configure Terragrunt to use OpenTofu as the IaC engine.

### Pattern 1: GitHub-Based Engine

**Use when:** Using the official OpenTofu engine

```hcl
# terragrunt.hcl
engine {
  source  = "github.com/gruntwork-io/terragrunt-engine-opentofu"
  version = "v0.0.15"
}
```

### Pattern 2: Auto-Install OpenTofu Version

**Use when:** Automatically installing a specific OpenTofu version

```hcl
# terragrunt.hcl
engine {
  source = "github.com/gruntwork-io/terragrunt-engine-opentofu"
  meta = {
    tofu_version     = "v1.9.1"      # Or "latest" for stable version
    tofu_install_dir = "/opt/tofu"   # Optional custom install directory
  }
}
```

### Pattern 3: Local Engine Binary

**Use when:** Using a locally built or installed engine

```hcl
# terragrunt.hcl
engine {
  source = "/usr/local/bin/terragrunt-iac-engine-opentofu"
}
```

### Pattern 4: HTTPS Engine Source

**Use when:** Downloading engine from a specific URL

```hcl
# terragrunt.hcl
engine {
  source = "https://github.com/gruntwork-io/terragrunt-engine-opentofu/releases/download/v0.0.15/terragrunt-iac-engine-opentofu_rpc_v0.0.15_linux_amd64.zip"
}
```

## Provider Cache Patterns (2025)

Optimize provider downloads with caching.

### Pattern 1: Enable Provider Cache Server

**Use when:** Running multiple terragrunt operations

```bash
# Enable provider cache for run --all operations
terragrunt run --all plan --provider-cache

# Via environment variable
TG_PROVIDER_CACHE=1 terragrunt run --all apply
```

### Pattern 2: Custom Cache Directory

**Use when:** Specifying a custom cache location

```bash
TG_PROVIDER_CACHE=1 \
TG_PROVIDER_CACHE_DIR=/custom/cache/path \
terragrunt plan
```

### Pattern 3: Auto Provider Cache (OpenTofu 1.10+)

**Use when:** Using OpenTofu's native provider caching

```bash
# Enable auto-provider-cache-dir experiment
terragrunt run --all apply --experiment auto-provider-cache-dir

# Via environment variable
TG_EXPERIMENT='auto-provider-cache-dir' terragrunt run --all apply
```

### Pattern 4: Remote Cache Server

**Use when:** Sharing cache across team/CI

```bash
TG_PROVIDER_CACHE=1 \
TG_PROVIDER_CACHE_HOST=192.168.0.100 \
TG_PROVIDER_CACHE_PORT=5758 \
TG_PROVIDER_CACHE_TOKEN=my-secret \
terragrunt apply
```

## Summary

These patterns cover the most common Terragrunt generation scenarios:

1. **Root configurations** - Project setup with state management
2. **Child modules** - Resource creation with dependency management
3. **Environment handling** - Multi-environment infrastructure
4. **Advanced patterns** - Complex scenarios and integrations
5. **Stacks** - Infrastructure blueprints for maximum reusability (2025)
6. **Feature Flags** - Runtime control over behavior (2025)
7. **Exclude blocks** - Fine-grained execution control (2025)
8. **Errors blocks** - Advanced error handling (2025)
9. **OpenTofu engine** - Alternative IaC engine support (2025)
10. **Provider cache** - Performance optimization (2025)

When generating Terragrunt configurations, select the appropriate pattern based on:
- Project structure (single vs multi-account/environment)
- Module dependencies (none, single, multiple)
- Provider requirements (single vs multi-cloud)
- Operational needs (hooks, external data, etc.)
- Reusability requirements (stacks vs traditional modules)
- Runtime control needs (feature flags, exclusions)

Always validate generated configurations using the terragrunt-validator or terraform-validator skills.
