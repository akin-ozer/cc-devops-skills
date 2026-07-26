---
name: gitlab-ci-validator
description: "Use when validating, linting, security-reviewing, fixing, or troubleshooting .gitlab-ci.yml pipelines and includes."
---

# GitLab CI Validator

## Purpose

Validate GitLab CI YAML locally, surface security and rule-flow problems, and identify checks that require the GitLab API.

## Workflow

1. Resolve the root pipeline and inspect local include files and project conventions.
2. Run `scripts/validate_gitlab_ci.sh <path>`.
3. Use focused syntax, security, or best-practice scripts only to isolate a failure.
4. Consult `docs/` or authoritative GitLab documentation for unclear version-sensitive behavior; use `references/extended-guide.md` for modes and examples.
5. Apply fixes only when requested, then rerun the primary validator.

## Resources

- `scripts/validate_gitlab_ci.sh`: primary validator
- `scripts/validate_syntax.py`, `check_security.py`, `check_best_practices.py`: focused checks
- `docs/`: GitLab CI reference and validation guidance
- `references/extended-guide.md`: detailed command and fallback behavior

## Safety and gotchas

- Do not send private pipeline content to a remote lint API without authorization.
- Local parsing cannot fully expand remote/project includes or evaluate protected variables and runner policy.
- Flag unsafe variable interpolation, privileged containers, and deploy jobs before style issues.
- Do not run a pipeline as part of validation.

## Validation

Run `python3 tests/test_validators.py` and the primary wrapper when changing this skill. Report missing YAML tooling or GitLab API coverage.

## Output

Report findings by severity and location, include-resolution limits, commands run, remediation, and final rerun status.
