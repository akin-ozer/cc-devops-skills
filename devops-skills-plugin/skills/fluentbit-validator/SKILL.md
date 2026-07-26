---
name: fluentbit-validator
description: "Use when validating, linting, security-reviewing, or troubleshooting Fluent Bit classic-mode configuration and tag routing."
---

# Fluent Bit Validator

## Purpose

Validate Fluent Bit configuration structure, required keys, routing, security signals, and runtime parseability where the binary is available.

## Workflow

1. Resolve the main config and any included parser or fragment files.
2. Run `scripts/validate.sh <path>` for the default layered check.
3. Use `scripts/validate_config.py` directly only to isolate static findings.
4. Consult official plugin documentation for unclear or version-sensitive fields; use `references/extended-guide.md` for fallback and reporting detail.
5. Apply fixes only when requested and rerun static plus runtime checks.

## Resources

- `scripts/validate.sh`: primary static and optional runtime entry point
- `scripts/validate_config.py`: deterministic static validator
- `tests/`: valid and invalid routing/security fixtures
- `references/extended-guide.md`: detailed flows and fallback matrix

## Safety and gotchas

- Never print credentials embedded in config values.
- Static validation cannot confirm endpoint reachability, authentication, backpressure, or data delivery.
- Missing `fluent-bit` means runtime parsing is skipped, not passed.
- Follow `@INCLUDE` paths before declaring a required parser or section absent.

## Validation

Run `python3 -m unittest tests/test_validate_config.py` and the primary wrapper when changing this skill. Report the Fluent Bit version and skipped runtime coverage.

## Output

Report structural, routing, security, and runtime findings separately, with locations, remediation, and coverage gaps.
