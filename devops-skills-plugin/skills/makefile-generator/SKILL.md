---
name: makefile-generator
description: "Use when creating or restructuring Makefiles, reusable .mk fragments, project targets, variables, and build/development automation."
---

# Makefile Generator

## Purpose

Create a discoverable Make interface over the repository's real build, test, lint, run, and release commands. Use `makefile-validator` for review-only work.

## Workflow

1. Inspect project manifests, scripts, CI commands, existing Make fragments, and supported platforms.
2. Identify required targets, inputs, generated outputs, default behavior, and whether commands need Bash or portable `/bin/sh`.
3. Use `scripts/generate_makefile_template.sh` and `add_standard_targets.sh` when useful. Read only the relevant file in `docs/`; open `references/extended-guide.md` for larger patterns.
4. Generate a small Makefile with a safe default/help target, `.PHONY` declarations, overridable variables, and genuine file dependencies where appropriate.
5. Run `makefile-validator`, exercise dry-run output for important targets, and fix generator-owned findings.

## Resources

- `scripts/`: template and standard-target helpers
- `docs/`: structure, variables, targets, patterns, optimization, and security
- `references/extended-guide.md`: detailed examples and integrations

## Safety and gotchas

- Recipes require tabs; generated prerequisites and recipes must remain distinct.
- Escape Make `$` as `$$` when the shell should receive it.
- Avoid parse-time `$(shell ...)` side effects and destructive default targets.
- Validate user-controlled variables before using them in removal, deployment, or publish commands.

## Validation

Run `makefile-validator` and `test/test_helper_scripts.sh`. Use `make -n` on representative non-destructive targets and report missing optional linters.

## Output

List targets and variables, prerequisites, invocation examples, safety assumptions, and validation results.
