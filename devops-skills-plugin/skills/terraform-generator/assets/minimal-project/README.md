# Minimal Terraform Project

This is a minimal Terraform project template.

## Structure

- `main.tf` - Main resource definitions
- `variables.tf` - Input variable declarations
- `outputs.tf` - Output value declarations
- `versions.tf` - Terraform and provider version constraints
- `terraform.tfvars.example` - Example variable values

## Usage

1. Copy `terraform.tfvars.example` to `terraform.tfvars` and update with your values
2. Initialize Terraform:
   ```bash
   terraform init
   ```
3. Review the plan:
   ```bash
   terraform plan
   ```
4. Apply the configuration:
   ```bash
   terraform apply
   ```

## Adding Resources

Add your resource definitions to `main.tf` or create additional `.tf` files as needed.
