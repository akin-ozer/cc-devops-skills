---
name: terraform-generator
description: "Use when creating or extending Terraform resources, modules, providers, variables, outputs, imports, or project scaffolding."
---

# Terraform Generator

## Purpose

Create Terraform configuration consistent with the repository, provider versions, and requested lifecycle. Use `terraform-validator` for review-only work.

## Workflow

1. Inspect existing Terraform, lockfiles, module structure, state/backend conventions, provider constraints, naming, and tests.
2. Clarify material infrastructure, lifecycle, state, and compatibility choices; never invent account IDs, network IDs, credentials, or destructive policy.
3. Read only the relevant provider/pattern/best-practice reference. Use `assets/minimal-project/` for a new project and `references/extended-guide.md` for version-gated advanced features.
4. Generate the smallest cohesive module or resource set with typed inputs, useful outputs, explicit constraints, and provider-appropriate safeguards.
5. Run `terraform-validator`, fix generator-owned findings, and rerun. Plan only with authorization and suitable credentials.

## Resources

- `assets/minimal-project/`: starter module layout
- `references/provider_examples.md`, `common_patterns.md`, `terraform_best_practices.md`: focused guidance
- `references/extended-guide.md`: detailed patterns and version feature matrix
- `scripts/run_ci_checks.sh`: generator contract checks

## Safety and gotchas

- Never commit credentials, populated secret tfvars, state, or plan files.
- Prefer data sources only when lookup stability is appropriate; allow explicit IDs when reproducibility requires them.
- Add lifecycle protection deliberately, not universally; explain operational tradeoffs.
- Gate features by both Terraform and provider versions.
- Do not run `apply`, import state, or change a backend while generating configuration.

## Validation

Run `terraform-validator` and `scripts/run_ci_checks.sh`. Separate fmt/validate/security results from initialization, plan, credentials, and live-provider coverage.

## Output

List files, provider/version assumptions, required inputs, state/lifecycle decisions, safe next commands, and validation evidence.
