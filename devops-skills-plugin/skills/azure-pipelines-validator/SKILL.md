---
name: azure-pipelines-validator
description: "Use when validating, linting, security-reviewing, or troubleshooting Azure Pipelines YAML and reusable templates."
---

# Azure Pipelines Validator

## Purpose

Validate existing Azure Pipelines configuration locally and explain what still requires Azure DevOps server evaluation.

## Workflow

1. Resolve the explicit pipeline path; do not guess when multiple candidates exist.
2. Run `scripts/validate_azure_pipelines.sh <path>` from the skill directory or with an absolute script path.
3. Use the focused Python checks only to isolate syntax, security, or best-practice failures.
4. Consult `docs/azure-pipelines-reference.md` or authoritative Microsoft documentation only for an unclear or version-sensitive finding.
5. If fixes are requested, change only the failing construct and rerun the same command.

## Resources

- `scripts/validate_azure_pipelines.sh`: primary validation entry point
- `scripts/check_security.py`, `check_best_practices.py`, `validate_syntax.py`: focused diagnostics
- `examples/`: valid and regression fixtures
- `references/extended-guide.md`: rule buckets and fallback details

## Safety and gotchas

- Static YAML parsing cannot fully evaluate templates, service connections, permissions, or organization policy.
- Do not reveal variable values or tokens while reporting findings.
- Do not trigger or queue a pipeline as part of validation unless explicitly requested.
- Treat skipped Azure-side checks as unknown, not success.

## Validation

Run the primary script and its regression check (`scripts/test_regressions.py`) where Python is available. Report missing tools and unverified server behavior.

## Output

Group findings by severity with file locations, fixes, commands run, and a separate skipped/blocked section.
