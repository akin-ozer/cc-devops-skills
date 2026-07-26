---
name: bash-script-validator
description: "Use when checking, linting, security-reviewing, fixing, or assessing portability of Bash, POSIX shell, and .sh scripts."
---

# Bash Script Validator

## Purpose

Run layered syntax, ShellCheck, security, and portability checks against existing shell code.

## Workflow

1. Identify the target interpreter from its shebang and repository conventions.
2. Run `scripts/validate.sh <path>`; select a ShellCheck mode only when the environment requires it.
3. Read only the reference matching a finding, such as `docs/common-mistakes.md`, `shellcheck-reference.md`, or a command-specific guide.
4. Explain findings with locations and impact. Apply minimal fixes only when requested.
5. Rerun the baseline validator after changes and distinguish fixed, remaining, and skipped checks.

## Resources

- `scripts/validate.sh`: default layered validation
- `scripts/run_ci_checks.sh`: deterministic CI gate
- `scripts/shellcheck_wrapper.sh`: ShellCheck fallback
- `docs/`: focused shell and text-processing references
- `references/extended-guide.md`: modes, exit codes, and examples

## Safety and gotchas

- Match syntax checks to the declared interpreter; `bash -n` is not a POSIX portability test.
- Do not execute an untrusted script merely to validate it.
- Flag dangerous expansion, injection, unsafe temporary files, and unchecked destructive paths before style issues.
- A missing ShellCheck binary lowers coverage; it does not make a script clean.

## Validation

Run `scripts/validate.sh`, then `scripts/test_validate.sh` when modifying this skill. Capture the chosen ShellCheck path and all skipped tooling.

## Output

Report interpreter, checks run, findings by severity and location, proposed fixes, and final rerun status.
