# Environment Configuration
# File: env.hcl
# Location: <environment>/env.hcl — one per environment directory (e.g., dev/env.hcl, prod/env.hcl)
#
# Pattern A: child modules read this file via:
#   locals {
#     env = read_terragrunt_config(find_in_parent_folders("env.hcl"))
#   }
#   # Access values as: local.env.locals.environment, local.env.locals.aws_region, etc.
#
# DO NOT reference this file from root.hcl — root.hcl must remain environment-agnostic.

locals {
  # ── Core identifiers ──────────────────────────────────────────────────────
  environment = "[ENVIRONMENT]"   # e.g., "dev", "staging", "prod"
  aws_region  = "[AWS_REGION]"    # e.g., "us-east-1"
  project     = "[PROJECT_NAME]"  # e.g., "payments-platform"

  # ── Networking ────────────────────────────────────────────────────────────
  vpc_cidr = "[VPC_CIDR]"         # e.g., "10.0.0.0/16"

  # ── Compute sizing — adjust thresholds per environment ───────────────────
  instance_type = "[INSTANCE_TYPE]"  # e.g., "t3.micro" (dev) / "t3.medium" (prod)
  min_size      = 1                  # Replace: e.g., 1 (dev) / 3 (prod)
  max_size      = 3                  # Replace: e.g., 3 (dev) / 10 (prod)

  # ── Feature toggles ───────────────────────────────────────────────────────
  # IMPORTANT: values must be static booleans, not references to other locals.
  # Feature flags in Terragrunt require static defaults — see Feature Flags docs.
  enable_monitoring = false  # true for prod, false for dev/staging
  enable_backups    = false  # true for prod, false for dev/staging

  # ── Common tags ───────────────────────────────────────────────────────────
  common_tags = {
    Environment = local.environment
    Project     = local.project
    ManagedBy   = "Terragrunt"
  }
}
