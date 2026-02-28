---
name: fluentbit-validator
description: Comprehensive toolkit for validating, linting, and testing Fluent Bit configurations. Use this skill when working with Fluent Bit config files, validating syntax, checking for best practices, identifying security issues, or performing dry-run testing.
---

# Fluent Bit Validator

Use this skill to run deterministic, repeatable validation for Fluent Bit classic-mode configs.

## Trigger Phrases

Use this skill when prompts look like:
- "Validate this `fluent-bit.conf` before deploy"
- "Lint my Fluent Bit config and report issues"
- "Check tag routing and output matches in Fluent Bit"
- "Run security checks for Fluent Bit config"
- "Dry-run Fluent Bit config and tell me what failed"

## Execution Model

Run steps in order. Do not skip Stage 0.

### Stage 0: Precheck (Required)

Run from skill directory:

```bash
cd devops-skills-plugin/skills/fluentbit-validator
```

Check required and optional binaries:

```bash
command -v python3 >/dev/null 2>&1 && echo "python3: available" || echo "python3: missing"
command -v fluent-bit >/dev/null 2>&1 && echo "fluent-bit: available" || echo "fluent-bit: missing (dry-run will be skipped)"
```

Precheck protocol:
- If `python3` is missing: stop script-based validation, report blocker, and switch to manual config review only.
- If `fluent-bit` is missing: continue static checks, skip dry-run, and record a `Recommendation` explaining skip reason and next step.

### Stage 1: Static Validation (Required)

Default command:

```bash
python3 scripts/validate_config.py --file <config-file> --check all
```

Use targeted checks only when requested:

```bash
python3 scripts/validate_config.py --file <config-file> --check structure
python3 scripts/validate_config.py --file <config-file> --check sections
python3 scripts/validate_config.py --file <config-file> --check tags
python3 scripts/validate_config.py --file <config-file> --check security
python3 scripts/validate_config.py --file <config-file> --check performance
python3 scripts/validate_config.py --file <config-file> --check best-practices
python3 scripts/validate_config.py --file <config-file> --check dry-run
```

Strict CI gate (optional):

```bash
python3 scripts/validate_config.py --file <config-file> --check all --fail-on-warning
```

### Stage 2: Dry-Run Handling (Conditional)

Dry-run command:

```bash
fluent-bit -c <config-file> --dry-run
```

Skip protocol:
- If `fluent-bit` is unavailable, do not fail static validation by default.
- Emit one explicit finding:
  - `Recommendation: Dry-run skipped because fluent-bit binary is not available in PATH; run dry-run in CI or a Fluent Bit runtime image.`
- If user explicitly requires dry-run as a release gate, run:

```bash
python3 scripts/validate_config.py --file <config-file> --check dry-run --require-dry-run
```

- In release-gate mode, missing `fluent-bit` must be reported as `Error`.

### Stage 3: Reference Lookup (Optional)

Use only when plugin/parameter behavior is unclear after local checks.

Lookup order:
1. Context7 Fluent Bit docs.
2. Official docs at `docs.fluentbit.io`.
3. Broader web search limited to official/plugin sources.

Capture only:
- required fields,
- allowed values and defaults,
- version caveats relevant to the user config.

### Stage 4: Report and Remediation (Required)

Use exactly these severity labels:
- `Error`
- `Warning`
- `Recommendation`

Do not introduce alternate labels (`Info`, `Best Practice`, `Critical`, etc.).

Report format:

```text
Validation Report: <config-file>

Error:
- <blocking issue>

Warning:
- <non-blocking risk>

Recommendation:
- <improvement or skipped-step guidance>
```

Remediation flow:
1. Present findings with file/line context when available.
2. Ask for approval before changing user files.
3. Apply approved changes.
4. Re-run the same validation command(s).
5. Return delta: what changed, what remains, and final status.

No-issue fast path:
- If no findings exist, return a short pass summary and note whether dry-run was executed or skipped.

## Fallback Matrix

| Constraint | Behavior |
|---|---|
| `python3` missing | Stop scripted validator, report blocker as `Error`, provide manual review-only output. |
| `fluent-bit` missing | Continue static checks, skip dry-run, emit one `Recommendation` with next step. |
| No network/docs access | Continue local validation, report unknown plugin details as `Warning` with explicit "doc lookup deferred". |
| User requests report-only | Do not edit files; return findings and rerun command suggestion. |

## Canonical Flows

### Full validation flow

```bash
bash scripts/validate.sh --precheck
python3 scripts/validate_config.py --file tests/valid-basic.conf --check all
```

### Constrained environment flow (`fluent-bit` unavailable)

```bash
bash scripts/validate.sh --precheck
python3 scripts/validate_config.py --file tests/invalid-security-issues.conf --check all --json
```

Expected outcome:
- Static findings still produced.
- Dry-run skipped and reported under `Recommendation`.

## Done Criteria

Work is done only when all are true:
- Precheck was executed and binary availability was stated explicitly.
- Validation command(s) and scope are clear and reproducible.
- All findings use only `Error`, `Warning`, `Recommendation`.
- Dry-run path is explicit: executed or skipped with reason.
- Fallback behavior for tool/runtime constraints is documented in output.
- If fixes were applied, validation was re-run and post-fix status was reported.

## Local Assets

- `scripts/validate_config.py`: main validator.
- `scripts/validate.sh`: wrapper and environment precheck helper.
- `tests/*.conf`: sample valid/invalid configs.
- `tests/test_validate_config.py`: regression coverage for parser and severity behavior.
