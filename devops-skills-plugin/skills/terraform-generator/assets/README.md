# Terraform Generator Asset Templates

This directory contains reusable Terraform project templates that can be copied and customized for different use cases.

## Available Templates

### minimal-project/
A minimal Terraform project structure with:
- Basic file organization (main.tf, variables.tf, outputs.tf, versions.tf)
- Example variable declarations
- README with usage instructions

**Use when:** Starting a new Terraform project from scratch

**How to use:** Copy the entire `minimal-project/` directory to your desired location and customize the files as needed.

## Using Templates

To use a template, copy its directory to your project location:

```bash
# Run from repository root
SKILL_DIR="devops-skills-plugin/skills/terraform-generator"
cp -r "${SKILL_DIR}/assets/minimal-project/" ./my-terraform-project/
cd my-terraform-project
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
```

## Customization

All templates are designed to be starting points. You should:
1. Update the provider configuration in `versions.tf`
   - Use major-version pinning (`~>`) and verify exact current versions when required.
2. Add your resources to `main.tf`
3. Update variables in `variables.tf` as needed
4. Configure outputs in `outputs.tf`
5. Set values in `terraform.tfvars`
