# Root Terragrunt Configuration
# Description: [DESCRIPTION]
# This file defines shared configuration for all child modules
# Location: Should be placed at the root of your infrastructure directory

# Configure Terragrunt to automatically store tfstate files in an S3 bucket
remote_state {
  backend = "s3"

  config = {
    bucket         = "[BUCKET_NAME]"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "[AWS_REGION]"
    encrypt        = true
    dynamodb_table = "[DYNAMODB_TABLE]"

    # Optional: Configure S3 bucket tags
    s3_bucket_tags = {
      name        = "Terraform state storage"
      environment = "[ENVIRONMENT]"
      managed_by  = "Terragrunt"
    }

    # Optional: Configure DynamoDB table tags
    dynamodb_table_tags = {
      name       = "Terraform lock table"
      managed_by = "Terragrunt"
    }
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Generate provider configuration
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
terraform {
  required_version = ">= [TERRAFORM_VERSION]"

  required_providers {
    [PROVIDER_NAME] = {
      source  = "[PROVIDER_SOURCE]"
      version = "~> [PROVIDER_VERSION]"
    }
  }
}

provider "[PROVIDER_NAME]" {
  region = "[REGION]"

  # Optional: Default tags applied to all resources
  default_tags {
    tags = {
      Environment = "[ENVIRONMENT]"
      ManagedBy   = "Terragrunt"
      Project     = "[PROJECT_NAME]"
    }
  }
}
EOF
}

# Configure common input variables for all child modules
inputs = {
  # Environment configuration
  environment = "[ENVIRONMENT]"
  region      = "[REGION]"
  project     = "[PROJECT_NAME]"

  # Tagging strategy
  common_tags = {
    Environment = "[ENVIRONMENT]"
    ManagedBy   = "Terragrunt"
    Project     = "[PROJECT_NAME]"
  }

  # Add other common variables here
}

# Optional: Configure error handling with retry and ignore logic
# This replaces the deprecated retryable_errors, retry_max_attempts, and retry_sleep_interval_sec
errors {
  # Retry block for transient errors (network issues, rate limiting, etc.)
  retry "transient_errors" {
    retryable_errors = [
      "(?s).*Failed to load state.*tcp.*timeout.*",
      "(?s).*Failed to load backend.*TLS handshake timeout.*",
      "(?s).*Error installing provider.*TLS handshake timeout.*",
      "(?s).*Error installing provider.*tcp.*timeout.*",
      "(?s).*Error installing provider.*tcp.*connection reset by peer.*",
      "(?s).*Error configuring the backend.*TLS handshake timeout.*",
      "(?s).*Provider produced inconsistent final plan.*",
      "(?s).*Error creating SSM parameter: TooManyUpdates:.*",
      "(?s).*app.terraform.io.*: 429 Too Many Requests.*",
      "(?s).*Client.Timeout exceeded while awaiting headers.*",
      "(?s).*Could not download module.*The requested URL returned error: 429.*",
    ]
    max_attempts       = 3
    sleep_interval_sec = 5
  }

  # Optional: Ignore block for known safe-to-ignore errors
  # ignore "known_safe_errors" {
  #   ignorable_errors = [
  #     ".*Warning:.*",
  #   ]
  #   message = "Ignoring known safe warnings"
  #   signals = {
  #     alert_team = false
  #   }
  # }
}

# Optional: Configure Terraform binary path
# terraform_binary = "/usr/local/bin/terraform"

# Optional: Configure Terragrunt to download Terraform modules into a shared cache
# terraform_version_constraint = ">= [TERRAFORM_VERSION]"
# download_dir                 = ".terragrunt-cache"

# Optional: Prevent destruction of critical resources
# prevent_destroy = true
