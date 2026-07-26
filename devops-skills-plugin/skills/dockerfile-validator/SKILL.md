---
name: dockerfile-validator
description: "Use when linting, security-scanning, reviewing, or troubleshooting a Dockerfile or container build definition."
---

# Dockerfile Validator

## Purpose

Produce a severity-ranked Dockerfile review using the repository's deterministic validator and available runtime tools.

## Workflow

1. Resolve and read the target Dockerfile plus relevant `.dockerignore`, manifests, and lockfiles.
2. Run `scripts/dockerfile-validate.sh <path>`.
3. Load `security_checklist.md`, `optimization_guide.md`, or `docker_best_practices.md` only when a related finding needs interpretation.
4. Separate correctness and security problems from optional optimizations and tool availability.
5. Apply fixes only when requested, then rerun the validator and any safe build test.

## Resources

- `scripts/dockerfile-validate.sh`: primary validator
- `references/security_checklist.md`: credential, privilege, and supply-chain checks
- `references/optimization_guide.md`: layer and caching guidance
- `references/extended-guide.md`: fallbacks and report examples

## Safety and gotchas

- Do not build untrusted Dockerfiles as a default validation step.
- Static checks cannot prove runtime health, image provenance, or vulnerability status.
- Avoid exposing build arguments, environment values, or registry credentials in output.
- Treat unavailable hadolint, Checkov, Docker, or network scans as reduced coverage.

## Validation

Run `scripts/dockerfile-validate.sh`, `scripts/test_validate.sh`, and `tests/test_regression.sh` when changing validator behavior. Record all fallbacks.

## Output

Report findings by severity with locations, remediation, tools run, and skipped runtime or vulnerability checks.
