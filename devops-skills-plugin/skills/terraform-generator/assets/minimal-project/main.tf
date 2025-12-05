# Main Terraform configuration file
# Add your resources here

# Using terraform_data instead of deprecated null_resource (Terraform 1.4+)
resource "terraform_data" "example" {
  triggers_replace = {
    timestamp = timestamp()
  }
}
