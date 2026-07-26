---
name: bash-script-generator
description: "Use when creating or scaffolding Bash or POSIX shell scripts, CLI helpers, cron jobs, text-processing tools, or automation."
---

# Bash Script Generator

## Purpose

Turn an automation goal into a small, readable shell script. Use `bash-script-validator` when only reviewing existing scripts.

## Workflow

1. Inspect surrounding scripts and determine the target shell, inputs, outputs, exit behavior, dependencies, and platform constraints.
2. Ask about ambiguity only when it affects safety or portability; otherwise state reasonable defaults.
3. Start from `assets/templates/standard-template.sh` or `scripts/generate_script_template.sh` when it fits. Read only the relevant document in `docs/`.
4. Implement the simplest robust flow with quoted expansions, explicit errors, cleanup traps where needed, and useful `--help`.
5. Validate with `bash-script-validator`, exercise important branches, fix findings, and rerun.

## Resources

- `assets/templates/standard-template.sh`: baseline script structure
- `docs/script-patterns.md`, `text-processing-guide.md`: task-specific patterns
- `docs/generation-best-practices.md`, `bash-scripting-guide.md`: deeper guidance
- `references/extended-guide.md`: detailed fallback and response examples

## Safety and gotchas

- Never interpolate untrusted data into `eval`, shell fragments, or broad destructive commands.
- Validate destructive targets and provide a dry-run or confirmation boundary where appropriate.
- Use POSIX syntax only when POSIX `sh` was selected; do not label Bash-specific code portable.
- Avoid hiding failures in pipelines or command substitutions.

## Validation

Run `scripts/run_ci_checks.sh <script>` or `bash-script-validator`; test the success path plus important invalid-input and failure paths. Report unavailable ShellCheck coverage.

## Output

Provide the file path, invocation examples, dependencies, safety assumptions, and validation evidence.
