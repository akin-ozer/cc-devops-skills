---
name: terraform-validator
description: "Use when formatting, validating, linting, security-scanning, planning, or troubleshooting Terraform HCL and modules."
---

# Terraform Validator

## Purpose

Validate Terraform structure, provider/module usage, formatting, semantics, and security with the deepest safe checks available.

## Workflow

1. Resolve the target and inspect versions, lockfile, backend, providers, modules, variables, and repository config.
2. Run `scripts/extract_tf_info_wrapper.sh <path>`, then use authoritative version-matched docs only for unfamiliar or failing provider/module behavior.
3. Run formatting check, TFLint when configured, `terraform init -backend=false` where safe, `terraform validate`, and `scripts/run_checkov.sh <path>` as available.
4. Load only the reference associated with a finding: security, practices, errors, or advanced features. Use `references/extended-guide.md` for detailed recovery and report formats.
5. Apply fixes only when requested and rerun affected checks. Run a plan only with explicit scope, safe credentials, and no backend surprises.

## Resources

- `scripts/extract_tf_info_wrapper.sh`: provider/module inventory
- `scripts/run_checkov.sh`: security wrapper
- `references/`: focused security, practice, error, and feature guidance
- `references/extended-guide.md`: full validation matrix and fallbacks

## Safety and gotchas

- Do not expose state, plan output secrets, variable values, or provider credentials.
- Avoid backend initialization or state locking during ordinary static validation.
- `terraform validate` may require provider downloads; offline failure is blocked coverage, not invalid HCL.
- Security scanners produce contextual findings; verify impact before recommending broad suppressions.
- Never run `apply`, destroy, import, or state mutations in this skill.

## Validation

Run `tests/test_regression.sh` and syntax-check local shell/Python helpers when changing this skill. Report tool versions, commands, skips, and plan/backend coverage.

## Output

Report findings by severity and location, provider/module documentation consulted, commands run, blocked checks, remediation, and post-fix results.
