---
name: bash-script-generator
description: Comprehensive toolkit for generating best practice bash scripts following current standards and conventions. Use this skill when creating new bash scripts, implementing shell automation, text processing workflows, or building production-ready command-line tools.
---

# Bash Script Generator

## Overview

Generate production-ready Bash scripts with clear requirements capture, deterministic generation flow, and validation-first iteration.

## Trigger Phrases

Use this skill when the user asks to:
- Create, generate, write, or build a Bash/shell script
- Convert manual CLI steps into an automation script
- Build a text-processing script using `grep`, `awk`, or `sed`
- Create an operations helper script, cron script, or CI utility script

Do not use this skill for validating an existing script only. Use `devops-skills:bash-script-validator` for validation-only requests.

## Execution Model

Follow stages in order. Do not skip a stage; use the documented fallback when blocked.

### Stage 0: Preflight

1. Confirm scope and target output path.
2. Confirm shell target:
- Default: `bash`
- If portability is requested: POSIX `sh`
3. Check capabilities and pick fallback path:

| Capability | Default Path | Fallback Path |
|---|---|---|
| Requirement clarification | AskUserQuestion tool | Ask same questions in normal chat; mark unresolved items as assumptions |
| Script scaffold | `bash scripts/generate_script_template.sh ...` | Copy `assets/templates/standard-template.sh` manually or hand-craft minimal scaffold |
| Validation | `devops-skills:bash-script-validator` | Local checks: `bash -n`, `shellcheck` if available, `sh -n` for POSIX mode |

If a fallback path is used, state it explicitly in the final summary.

### Stage 1: Capture Requirements

Collect only what is needed to generate the script correctly:
- Input source and format
- Output destination and format
- Error handling behavior (fail-fast/retry/continue)
- Security constraints (sensitive data, privilege level)
- Performance constraints (large files, parallelism)
- Portability requirement (Bash-only vs POSIX)

Then create a `Captured Requirements` table with stable IDs.

```markdown
## Captured Requirements

| Requirement ID | Description | Source | Implementation Plan |
|---|---|---|---|
| REQ-001 | Parse nginx logs from file input | User | `parse_args()` + `validate_file()` + `awk` parser |
| REQ-002 | Output top 10 errors | User | `analyze_errors()` + `sort | uniq -c | head -10` |
| REQ-003 | Handle large files efficiently | Assumption | Single-pass `awk`; avoid multi-pass loops |
```

Rules:
- Every major design decision maps to at least one `REQ-*`.
- Keep assumptions explicit and minimal.

### Stage 2: Choose Generation Path

Use this deterministic decision tree:

```text
Need multi-command architecture, unusual control flow, or strict non-template conventions?
├─ Yes -> Custom generation
└─ No
   Need standard CLI skeleton (usage/logging/arg parsing/cleanup)?
   ├─ Yes -> Template-first generation
   └─ No -> Custom generation
```

Template-first is the default for single-purpose CLI utilities.

### Stage 3: Load Only Relevant References

Use progressive disclosure. Read only docs needed for the current request.

| Need | Reference |
|---|---|
| Tool choice (`grep` vs `awk` vs `sed`) | `docs/text-processing-guide.md` |
| Script structure and argument patterns | `docs/script-patterns.md` |
| Strict mode, shell differences, safety | `docs/bash-scripting-guide.md` |
| Naming, organization, and quality baseline | `docs/generation-best-practices.md` |

Citation format (required):
- `[Ref: docs/<file>.md -> <section>]`

### Stage 4: Generate Script

#### Path A: Template-first (default)

1. Generate scaffold:
```bash
bash scripts/generate_script_template.sh standard output-script.sh
```
2. Replace placeholders and add business logic.
3. Keep logging to stderr and data output to stdout unless requirements say otherwise.
4. Add comments only where logic is non-obvious.

#### Path B: Custom generation

Build a script with at least:
- Shebang and strict mode
- `usage()`
- `parse_args()`
- Input validation and dependency checks
- Main workflow function(s)
- Predictable exit codes

### Stage 5: Validate and Iterate

Default validation path:
1. Invoke `devops-skills:bash-script-validator`
2. Apply fixes
3. Re-run validation
4. Repeat until checks pass or blocker is identified

Fallback validation path (when validator skill is unavailable):
```bash
bash -n path/to/script.sh
command -v shellcheck >/dev/null 2>&1 && shellcheck path/to/script.sh || echo "shellcheck unavailable; skipped"
# If POSIX compatibility requested:
sh -n path/to/script.sh
```

If any check is skipped, include `Skipped check`, `Reason`, and `Risk` in the output.

### Stage 6: Final Response Contract

Always return:
1. Generated script path
2. Requirements traceability (`REQ-*` -> implementation)
3. Validation results with rerun status
4. Citations in standard format
5. Any assumptions/fallbacks used

## Canonical Example Flows

### Example A: Full Flow (Template-first)

1. Clarify missing data format and output expectations.
2. Capture `REQ-*` table.
3. Choose template-first path.
4. Generate scaffold with `scripts/generate_script_template.sh`.
5. Implement logic and map functions to `REQ-*`.
6. Validate with `devops-skills:bash-script-validator` and rerun until clean.
7. Return final summary with citations.

### Example B: Constrained Environment Flow

Use this when AskUserQuestion, validator skill, or `shellcheck` is unavailable:
1. Ask clarifying questions in chat.
2. Mark unresolved items as assumptions in `Captured Requirements`.
3. Generate from template script or template file copy fallback.
4. Run `bash -n` (and `sh -n` if relevant).
5. If `shellcheck` is missing, report skip with risk and mitigation.

## Done Criteria

The task is complete only when all items are true:
- Trigger matched and scope confirmed
- `Captured Requirements` table exists with `REQ-*` IDs
- Template-first vs custom decision is documented
- Script is generated with deterministic structure
- Validation executed and rerun policy applied
- Any skipped checks include explicit reason and risk
- Final response includes traceability, citations, and assumptions

## Helper Scripts and Assets

- Script generator: `scripts/generate_script_template.sh`
- Standard scaffold: `assets/templates/standard-template.sh`
- Example output style: `examples/log-analyzer.sh`

## Reference Docs

- `docs/bash-scripting-guide.md`
- `docs/script-patterns.md`
- `docs/generation-best-practices.md`
- `docs/text-processing-guide.md`

## External References

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/)
- [ShellCheck](https://www.shellcheck.net/)
