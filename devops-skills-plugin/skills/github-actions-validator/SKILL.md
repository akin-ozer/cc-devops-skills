---
name: github-actions-validator
description: "Use when linting, testing, security-reviewing, fixing, or troubleshooting GitHub Actions workflows and custom actions."
---

# GitHub Actions Validator

## Purpose

Validate GitHub Actions syntax and semantics with actionlint-style checks and optional local execution, while making coverage limits explicit.

## Workflow

1. Resolve the workflow or action path and inspect referenced local actions, reusable workflows, and repository configuration.
2. Run `scripts/validate_workflow.sh <path>` in its default lint mode.
3. Load only the reference mapped to a finding: common errors, action versions, runners, modern features, actionlint, or `act`.
4. Verify unfamiliar public action versions against authoritative release metadata when network access is available.
5. If fixes are requested, patch minimally and rerun the same validation; use `act` only when safe and relevant.

## Resources

- `scripts/validate_workflow.sh`: primary validation entry point
- `references/`: error, runner, version, tool, and feature guidance
- `examples/`: known-good and failing fixtures
- `references/extended-guide.md`: detailed command modes and worked examples

## Safety and gotchas

- Do not run workflows that publish, deploy, mutate infrastructure, or consume real secrets.
- `pull_request_target` and interpolated untrusted context require special scrutiny.
- Local `act` behavior is not identical to GitHub-hosted runners.
- Missing Docker or network access reduces runtime/version coverage; it does not invalidate static results.

## Validation

Run `tests/test_validate_workflow.sh` plus the primary validator. Record actionlint, `act`, Docker, and network availability.

## Output

Report findings by severity and location, action-version evidence, commands run, fixes, rerun results, and skipped checks.
