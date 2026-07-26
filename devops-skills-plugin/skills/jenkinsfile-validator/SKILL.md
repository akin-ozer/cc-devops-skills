---
name: jenkinsfile-validator
description: "Use when validating, linting, security-reviewing, or troubleshooting declarative/scripted Jenkinsfiles and shared-library pipeline code."
---

# Jenkinsfile Validator

## Purpose

Validate Jenkins pipeline structure and common security/practice issues, with syntax routing for declarative, scripted, and shared-library code.

## Workflow

1. Resolve the Jenkinsfile or library path and determine its pipeline style.
2. Run `scripts/validate_jenkinsfile.sh <path>`; let it route to the focused validator.
3. Read `declarative_syntax.md`, `scripted_syntax.md`, `common_plugins.md`, or `best_practices.md` only for related findings.
4. Verify unfamiliar steps against the target plugin and controller versions when known.
5. Apply fixes only when requested, then rerun the primary validator.

## Resources

- `scripts/validate_jenkinsfile.sh`: primary entry point
- `scripts/validate_{declarative,scripted,shared_library}.sh`: focused checks
- `references/`: syntax, plugin, and practice guidance
- `references/extended-guide.md`: fallback paths and examples

## Safety and gotchas

- Do not submit untrusted pipeline content to a remote Jenkins linter without authorization.
- Static checks cannot prove plugin availability, sandbox approval, credentials scope, or agent labels.
- Redact credential IDs only if they encode sensitive details; never expose credential values.
- Do not trigger a Jenkins build during validation unless explicitly requested.

## Validation

Run `tests/run_local_ci.sh` and `tests/test_validate_jenkinsfile.sh`. Report controller/API-dependent checks separately.

## Output

Report pipeline type, findings by severity and location, plugin/version uncertainties, commands run, and post-fix status.
