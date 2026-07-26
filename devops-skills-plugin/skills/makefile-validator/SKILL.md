---
name: makefile-validator
description: "Use when linting, security-reviewing, fixing, or troubleshooting Makefiles and included .mk fragments."
---

# Makefile Validator

## Purpose

Validate Make syntax, target behavior, portability, security, and maintainability without running real recipes by default.

## Workflow

1. Resolve the Makefile and included fragments; inspect the declared default target.
2. Run `scripts/validate_makefile.sh <path>`.
3. Use `make -n` or `make --dry-run` only for selected safe targets and with required variables supplied.
4. Read `docs/common-mistakes.md`, `best-practices.md`, or `bake-tool.md` only for related findings; open `references/extended-guide.md` for modes and exit semantics.
5. Apply fixes only when requested and rerun the primary validator.

## Resources

- `scripts/validate_makefile.sh`: primary validator
- `scripts/test_validate.sh`: regression suite
- `docs/`: focused Make and mbake guidance
- `references/extended-guide.md`: detailed fallbacks and reporting

## Safety and gotchas

- `make -n` can still evaluate parse-time `$(shell ...)`; inspect first.
- Never invoke an unknown default, deploy, publish, clean, or destroy target during validation.
- Check included files and recursive Make calls before concluding a target is safe.
- Missing optional tools reduces coverage; distinguish warnings from validation errors.

## Validation

Run `scripts/test_validate.sh` plus the validator against good and bad examples. Record Make, mbake, checkmake, and unmake availability.

## Output

Report findings by severity and location, commands run, dry-run scope, skipped checks, and post-fix results.
