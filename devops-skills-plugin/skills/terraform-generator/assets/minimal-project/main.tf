# Main Terraform configuration file
# Add your resources here

# Stable terraform_data example (Terraform 1.4+) without perpetual drift
resource "terraform_data" "example" {
  input = {
    environment  = var.environment
    project_name = var.project_name
  }
}
