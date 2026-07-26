---
name: terragrunt-validator
description: "Use when formatting, validating, linting, security-reviewing, or troubleshooting Terragrunt HCL, dependencies, units, stacks, and module wiring."
---

# Terragrunt Validator

## Purpose

Validate Terragrunt syntax, layout, dependencies, source/provider usage, security, and supported CLI conventions without mutating infrastructure.

## Workflow

1. Resolve the target tree and inspect Terragrunt/Terraform versions, root includes, sources, units/stacks, dependencies, and backend configuration.
2. Detect custom resources/modules with `scripts/detect_custom_resources.py`; consult authoritative version-matched docs only where behavior is unfamiliar or failing.
3. Run `scripts/validate_terragrunt.sh <path>` with the least invasive mode that covers the request.
4. Read `references/best_practices.md` for related findings and `references/extended-guide.md` only for detailed CLI, stack, or recovery cases.
5. Apply fixes only when requested and rerun formatting, validation, dependency, and security checks. Plan only with explicit authorization.

## Resources

- `scripts/validate_terragrunt.sh`: primary validation entry point
- `scripts/detect_custom_resources.py`: provider/module discovery
- `scripts/run_ci_checks.sh`: deterministic helper/test gate
- `references/best_practices.md`, `extended-guide.md`: focused and deep guidance

## Safety and gotchas

- Confirm Terragrunt version before choosing redesigned or legacy CLI forms.
- Avoid backend initialization, state locking, generated-stack cleanup, or broad `run --all` operations by default.
- Redact inputs, rendered configs, state paths, and provider credentials.
- Missing providers/credentials reduce validation depth; do not call an unplanned tree valid.
- Never run apply, destroy, or state mutations in this skill.

## Validation

Run `scripts/run_ci_checks.sh`, `test/test_validate_terragrunt.sh`, and `test/test_detect_custom_resources.py` when changing this skill. Report tool versions, skips, and plan/backend coverage.

## Output

Report scope, findings by severity/location, dependency/provider evidence, commands run, blocked checks, remediation, and post-fix results.
