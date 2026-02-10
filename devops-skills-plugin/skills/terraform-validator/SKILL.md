---
name: terraform-validator
description: Comprehensive toolkit for validating, linting, testing, and automating Terraform configurations and HCL files. Use this skill when working with Terraform files (.tf, .tfvars), validating infrastructure-as-code, debugging Terraform configurations, performing dry-run testing with terraform plan, or working with custom providers and modules.
---

# Terraform Validator

Comprehensive toolkit for validating, linting, and testing Terraform configurations with automated workflows for syntax validation, security scanning, and intelligent documentation lookup.

## ⚠️ Critical Requirements Checklist

**STOP: You MUST complete these steps in order. Do NOT skip any REQUIRED step.**

| Step | Action | Required |
|------|--------|----------|
| 1 | Run `bash scripts/extract_tf_info_wrapper.sh <path>` | ✅ REQUIRED |
| 2 | Context7 lookup for **ALL** providers (explicit AND implicit); **WebSearch fallback if not found** | ✅ REQUIRED |
| 3 | **READ** `references/security_checklist.md` | ✅ REQUIRED |
| 4 | **READ** `references/best_practices.md` | ✅ REQUIRED |
| 5 | Run `terraform fmt` | ✅ REQUIRED |
| 6 | Run `tflint` (or note as skipped if unavailable) | Recommended |
| 7 | Run `terraform init` (if not initialized) | ✅ REQUIRED |
| 8 | Run `terraform validate` | ✅ REQUIRED |
| 9 | Run `bash scripts/run_checkov.sh <path>` | ✅ REQUIRED |
| 10 | Cross-reference findings with `security_checklist.md` sections | ✅ REQUIRED |
| 11 | Generate report citing reference files | ✅ REQUIRED |

> **IMPORTANT:** Steps 3-4 (reading reference files) must be completed BEFORE running security scans. The reference files contain remediation patterns that MUST be cited in your report.

> **Context7 Fallback:** If Context7 does not have a provider (common for: random, null, local, time, tls), use WebSearch: `"terraform-provider-{name} hashicorp documentation"`

## When to Use This Skill

- Working with Terraform files (`.tf`, `.tfvars`, `.tfstate`)
- Validating Terraform configuration syntax and structure
- Linting and formatting HCL code
- Performing dry-run testing with `terraform plan`
- Debugging Terraform errors or misconfigurations
- Understanding custom Terraform providers or modules
- Security validation of Terraform configurations

## External Documentation

| Tool | Documentation |
|------|---------------|
| **Terraform** | [developer.hashicorp.com/terraform](https://developer.hashicorp.com/terraform/docs) |
| **TFLint** | [github.com/terraform-linters/tflint](https://github.com/terraform-linters/tflint) |
| **Checkov** | [checkov.io](https://www.checkov.io/1.Welcome/Quick%20Start.html) |
| **Trivy** | [aquasecurity.github.io/trivy](https://aquasecurity.github.io/trivy) |

## Validation Workflow

**IMPORTANT:** Follow this workflow in order. Each step is REQUIRED unless explicitly marked optional.

```
1. Identify Terraform files in scope
   ├─> Single file, directory, or multi-environment

2. Extract Provider/Module Info (REQUIRED)
   ├─> MUST run: bash scripts/extract_tf_info_wrapper.sh <path>
   ├─> Parse output for providers and modules
   └─> Use for Context7 documentation lookup

3. Lookup Provider Documentation (REQUIRED)
   ├─> For EACH provider detected:
   │   ├─> mcp__context7__resolve-library-id with "terraform-provider-{name}"
   │   ├─> mcp__context7__get-library-docs for version-specific guidance
   │   └─> If NOT found in Context7: WebSearch fallback (see below)
   └─> Note any custom/private providers for WebSearch

4. Read Reference Files (REQUIRED before validation)
   ├─> MUST READ: references/security_checklist.md (before security scan)
   ├─> MUST READ: references/best_practices.md (for structure validation)
   └─> Reference common_errors.md if errors occur

5. Format and Lint (REQUIRED)
   ├─> MUST run: terraform fmt -recursive (auto-fix formatting)
   ├─> RUN: tflint (or note as skipped if unavailable)
   └─> Report formatting issues

6. Syntax Validation (REQUIRED)
   ├─> MUST run: terraform init (if not initialized)
   ├─> MUST run: terraform validate
   └─> Report syntax errors (consult common_errors.md)

7. Security Scanning (REQUIRED)
   ├─> MUST run: bash scripts/run_checkov.sh <path>
   ├─> Analyze policy violations against security_checklist.md
   └─> Suggest remediations from reference

8. Dry-Run Testing (if credentials available)
   ├─> terraform plan
   ├─> Analyze planned changes
   └─> Report potential issues

9. Generate Comprehensive Report
   ├─> Include all findings with severity
   ├─> Reference best_practices.md for recommendations
   └─> Offer to fix issues if appropriate
```

## Required Reference File Reading

**You MUST read these reference files during validation:**

| When | Reference File | Action |
|------|----------------|--------|
| **Before security scan** | `references/security_checklist.md` | Read to understand security checks and remediation patterns |
| **During validation** | `references/best_practices.md` | Read to validate project structure, naming, and patterns |
| **If errors occur** | `references/common_errors.md` | Read to find solutions for specific error messages |
| **If using Terraform 1.10+** | `references/advanced_features.md` | Read to understand ephemeral values, actions, list resources |

## Required Script Usage

**You MUST use these wrapper scripts instead of calling tools directly:**

| Task | Script | Command |
|------|--------|---------|
| **Extract provider/module info** | `extract_tf_info_wrapper.sh` | `bash scripts/extract_tf_info_wrapper.sh <path>` |
| **Run security scan** | `run_checkov.sh` | `bash scripts/run_checkov.sh <path>` |
| **Install checkov (if missing)** | `install_checkov.sh` | `bash scripts/install_checkov.sh install` |

> **Note:** `extract_tf_info_wrapper.sh` automatically handles the python-hcl2 dependency by creating a temporary virtual environment if needed. The venv is automatically cleaned up on exit.

## Context7 Provider Documentation Lookup (REQUIRED)

**For EVERY provider detected, you MUST lookup documentation via Context7:**

```
1. Run extract_tf_info_wrapper.sh to get provider list
2. For each provider (e.g., "aws", "google", "azurerm"):
   a. Call: mcp__context7__resolve-library-id with "terraform-provider-{name}"
   b. Call: mcp__context7__get-library-docs with the resolved ID
   c. Note version-specific features and constraints
3. Include relevant provider guidance in validation report
```

**Example for AWS provider:**
```
mcp__context7__resolve-library-id("terraform-provider-aws")
mcp__context7__get-library-docs(context7CompatibleLibraryID, topic="best practices")
```

### Context7 Fallback to WebSearch (REQUIRED)

**If Context7 does not find a provider, you MUST fall back to WebSearch:**

```
1. If mcp__context7__resolve-library-id returns no results or provider not found:
   a. Use WebSearch with query: "terraform-provider-{name} hashicorp documentation"
   b. For specific version: "terraform-provider-{name} {version} documentation site:registry.terraform.io"
2. Common providers NOT in Context7 (use WebSearch directly):
   - random (hashicorp/random)
   - null (hashicorp/null)
   - local (hashicorp/local)
   - time (hashicorp/time)
   - tls (hashicorp/tls)
3. Document in report: "Provider docs via WebSearch (not in Context7)"
```

**WebSearch Fallback Example:**
```
# If Context7 fails for random provider:
WebSearch("terraform-provider-random hashicorp documentation site:registry.terraform.io")
```

> **Note:** HashiCorp utility providers (random, null, local, time, tls, archive, external, http) may not be indexed in Context7. Always fall back to WebSearch for these.

## Detecting Implicit Providers (REQUIRED)

**IMPORTANT:** Providers can be used without being declared in `required_providers`. You MUST detect ALL providers:

### Detection Methods

1. **Explicit Providers:** Listed in `required_providers` block (from extract_tf_info_wrapper.sh output)
2. **Implicit Providers:** Inferred from resource type prefixes

### Common Implicit Provider Patterns

| Resource Type Prefix | Provider Name | Context7 Lookup |
|---------------------|---------------|-----------------|
| `random_*` | `random` | `terraform-provider-random` |
| `null_*` | `null` | `terraform-provider-null` |
| `local_*` | `local` | `terraform-provider-local` |
| `tls_*` | `tls` | `terraform-provider-tls` |
| `time_*` | `time` | `terraform-provider-time` |
| `archive_*` | `archive` | `terraform-provider-archive` |
| `http` (data source) | `http` | `terraform-provider-http` |
| `external` (data source) | `external` | `terraform-provider-external` |

### Workflow for Complete Provider Detection

```
1. Parse extract_tf_info_wrapper.sh output
2. Get providers from "providers" array (explicit)
3. Get resources from "resources" array
4. For EACH resource type:
   a. Extract prefix (e.g., "random" from "random_id")
   b. Check if already in providers list
   c. If NOT in providers: add as implicit provider
5. Perform Context7 lookup for ALL providers (explicit + implicit)
```

### Example

If `extract_tf_info_wrapper.sh` returns:
```json
{
  "providers": [{"name": "aws", ...}],
  "resources": [
    {"type": "aws_instance", ...},
    {"type": "random_id", ...}
  ]
}
```

You MUST lookup BOTH:
- `terraform-provider-aws` (explicit)
- `terraform-provider-random` (implicit - detected from `random_id` resource)

## Quick Reference Commands

### Format and Lint

```bash
# Check formatting (dry-run)
terraform fmt -check -recursive .

# Apply formatting
terraform fmt -recursive .

# Run tflint (requires .tflint.hcl config)
tflint --init              # Install plugins
tflint --recursive         # Lint all modules
tflint --format compact    # Compact output
```

> **TFLint Configuration:** See [TFLint Ruleset documentation](https://github.com/terraform-linters/tflint/blob/master/docs/user-guide/plugins.md) for plugin setup.

### Validate Configuration

```bash
# Initialize (downloads providers and modules)
terraform init

# Validate syntax
terraform validate

# Validate with JSON output
terraform validate -json
```

### Security Scanning

**MUST use wrapper script:**
```bash
# Use the wrapper script (REQUIRED)
bash scripts/run_checkov.sh ./terraform

# With specific options
bash scripts/run_checkov.sh -f json ./terraform
bash scripts/run_checkov.sh --compact ./terraform
```

> **Detailed Security Scanning:** You MUST read `references/security_checklist.md` before running security scans to understand the checks and remediation patterns.

## Security Finding Cross-Reference (REQUIRED)

**When reporting security findings, you MUST cite specific sections from `security_checklist.md`:**

### Cross-Reference Mapping

| Checkov Check Pattern | security_checklist.md Section | Line Reference |
|-----------------------|------------------------------|----------------|
| `CKV_AWS_24` (SSH open) | "Overly Permissive Security Groups" | Lines 66-110 |
| `CKV_AWS_260` (HTTP open) | "Overly Permissive Security Groups" | Lines 66-110 |
| `CKV_AWS_16` (RDS encryption) | "Encryption at Rest" | Lines 141-175 |
| `CKV_AWS_17` (RDS public) | "RDS Databases" | Lines 356-366 |
| `CKV_AWS_130` (public subnet) | "Network Security" | Lines 62-140 |
| `CKV_AWS_53-56` (S3 public access) | "Public S3 Buckets" | Lines 112-139 |
| `CKV_AWS_*` (IAM) | "IAM Security" | Lines 217-308 |
| `CKV_AWS_79` (IMDSv1) | "EC2/EKS Security" | Lines 382-389 |
| Hardcoded passwords | "Hardcoded Credentials" | Lines 8-45 |
| Sensitive outputs | "Sensitive Output Exposure" | Lines 47-61 |

### Report Template for Security Findings

```markdown
### Security Issue: [Check ID]

**Finding:** [Description from checkov]
**Resource:** [Resource name and file:line]
**Severity:** [HIGH/MEDIUM/LOW]

**Reference:** security_checklist.md - "[Section Name]" (lines X-Y)

**Remediation Pattern:**
[Copy relevant code example from security_checklist.md]

**Recommended Fix:**
[Specific fix for this configuration]
```

### Example Cross-Referenced Report

```markdown
### Security Issue: CKV_AWS_24

**Finding:** Security group allows SSH from 0.0.0.0/0
**Resource:** aws_security_group.web (main.tf:47-79)
**Severity:** HIGH

**Reference:** security_checklist.md - "Overly Permissive Security Groups" (lines 66-110)

**Remediation Pattern (from reference):**
```hcl
variable "admin_cidr" {
  description = "CIDR block for admin access"
  type        = string
}

resource "aws_security_group" "app" {
  ingress {
    description = "SSH from admin network only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
}
```

**Recommended Fix:** Replace `cidr_blocks = ["0.0.0.0/0"]` with a variable or specific CIDR range.
```

### Dry-Run Testing

```bash
# Generate execution plan
terraform plan

# Save plan to file
terraform plan -out=tfplan

# Plan with specific var file
terraform plan -var-file="production.tfvars"

# Plan with target resource
terraform plan -target=aws_instance.example
```

**Plan Output Symbols:**
- `+` Resources to be created
- `-` Resources to be destroyed
- `~` Resources to be modified
- `-/+` Resources to be replaced

## Handling Missing Tools

When validation tools are not installed, follow this recovery workflow:

### Recovery Workflow (REQUIRED)

```
1. Detect missing tool
2. Inform user what is missing and why it's needed
3. Provide installation command
4. ASK user: "Would you like me to install [tool] and continue?"
5. If yes: Run installation and RERUN the validation step
6. If no: Note as skipped in report, continue with available tools
```

### Tool-Specific Recovery

**If checkov is missing:**
```
1. Inform: "Checkov is not installed. It's required for security scanning."
2. Ask: "Would you like me to install it? I'll use: bash scripts/install_checkov.sh install"
3. If yes: Run install script, then rerun security scan
```

**If tflint is missing:**
```
1. Inform: "TFLint is not installed. It provides advanced linting beyond terraform validate."
2. Ask: "Would you like me to install it?"
3. Provide: brew install tflint (macOS) or installation script (Linux)
```

**If python-hcl2 is missing:**
```
The extract_tf_info_wrapper.sh script handles this automatically by creating
a temporary venv. No user action required.
```

**Required tools:** `terraform fmt`, `terraform validate`
**Optional but recommended:** `tflint`, `checkov`

## Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `extract_tf_info_wrapper.sh` | Parse Terraform files for providers/modules (auto-handles dependencies) | `bash scripts/extract_tf_info_wrapper.sh <path>` |
| `extract_tf_info.py` | Core parser (requires python-hcl2) | Use wrapper instead |
| `run_checkov.sh` | Wrapper for Checkov scans with enhanced output | `bash scripts/run_checkov.sh <path>` |
| `install_checkov.sh` | Install Checkov in isolated venv | `bash scripts/install_checkov.sh install` |

## Reference Documentation

**MUST READ during validation workflow:**

| Reference | When to Read | Content |
|-----------|--------------|---------|
| `references/security_checklist.md` | Before security scan | Security validation, Checkov/Trivy usage, common policies, remediation patterns |
| `references/best_practices.md` | During validation | Project structure, naming conventions, module design, state management |
| `references/common_errors.md` | When errors occur | Error database with causes and solutions |
| `references/advanced_features.md` | If Terraform >= 1.10 | Ephemeral values (1.10+), Actions (1.14+), List Resources (1.14+) |

## Workflow Examples

### Example 1: Validate Single File

```
1. MUST: bash scripts/extract_tf_info_wrapper.sh main.tf
2. MUST: Context7 lookup for each provider detected
3. MUST: Read references/security_checklist.md
4. MUST: Read references/best_practices.md
5. RUN: terraform fmt -check main.tf
6. RUN: terraform init (if needed) && terraform validate
7. MUST: bash scripts/run_checkov.sh -f main.tf
8. Report issues with remediation from references
9. If custom providers: WebSearch for documentation
```

### Example 2: Full Module Validation

```
1. Identify all .tf files in directory
2. MUST: bash scripts/extract_tf_info_wrapper.sh ./modules/vpc/
3. MUST: Context7 lookup for ALL providers
4. MUST: Read references/security_checklist.md
5. MUST: Read references/best_practices.md
6. RUN: terraform fmt -recursive
7. RUN: tflint --recursive (or note as skipped if unavailable)
8. RUN: terraform init && terraform validate
9. MUST: bash scripts/run_checkov.sh ./modules/vpc/
10. Analyze findings against security_checklist.md
11. Validate structure against best_practices.md
12. Provide comprehensive report with references
```

### Example 3: Production Dry-Run

```
1. Verify terraform initialized
2. MUST: Read references/security_checklist.md (production focus)
3. RUN: terraform plan -var-file="production.tfvars"
4. Analyze for unexpected changes
5. Highlight create/modify/destroy operations
6. Flag security concerns (compare with security_checklist.md)
7. Recommend whether safe to apply
```

## Advanced Features

Terraform 1.10+ introduces ephemeral values for secure secrets management. Terraform 1.14+ adds Actions for imperative operations and List Resources for querying infrastructure.

**MUST READ:** `references/advanced_features.md` when:
- Terraform version >= 1.10 is detected
- Configuration uses `ephemeral` blocks
- Configuration uses `action` blocks
- Configuration uses `.tfquery.hcl` files

## Integration with Other Skills

- **k8s-yaml-validator** - For Terraform Kubernetes provider validation
- **helm-validator** - When Terraform manages Helm releases
- **k8s-debug** - For debugging infrastructure provisioned by Terraform

## Notes

- Always run validation in order: extract info → lookup docs → read refs → format → lint → validate → security → plan
- MUST use wrapper scripts for extract_tf_info and checkov
- MUST read reference files before relevant validation steps
- MUST lookup provider docs via Context7 for ALL providers
- MUST offer recovery/rerun when tools are missing
- Never commit without running terraform fmt
- Always review plan output before applying
- Use version constraints for all providers and modules
- Use remote state for team collaboration
- Enable state locking to prevent concurrent modifications