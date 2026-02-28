---
name: bash-script-validator
description: Comprehensive toolkit for validating, linting, and optimizing bash and shell scripts. Use this skill when working with shell scripts (.sh, .bash), validating script syntax, checking for best practices, identifying security issues, or debugging shell script problems.
---

# Bash Script Validator

## Overview

This skill validates Bash and POSIX shell scripts with layered checks:

1. Syntax validation (`bash -n` or `sh -n`)
2. ShellCheck static analysis (system binary or wrapper fallback)
3. Custom security, portability, and optimization checks

Use the default flow below, then branch to fallbacks only when the environment is constrained.

## Trigger Guidance

Use this skill when the request includes script quality, linting, syntax checking, or shell portability work.

### Trigger Phrases

- "Validate this bash script"
- "Lint this `.sh` file"
- "Find security issues in this shell script"
- "Why does this script fail ShellCheck?"
- "Make this script POSIX compliant"
- "Review this shell script before CI"

### Non-Trigger Examples

- General Linux command questions with no script file
- Kubernetes, Terraform, or pipeline validation tasks that do not involve shell scripts
- Pure prose editing tasks

## Deterministic Execution Model

Run commands from this skill directory:

```bash
cd devops-skills-plugin/skills/bash-script-validator
```

### Step 1: Preflight

1. Confirm target path exists and is readable.
2. Confirm `bash` is available.
3. Determine whether fixes can be applied directly (write access) or only suggested (read-only).

### Step 2: Run Baseline Validation (Default Path)

```bash
bash scripts/validate.sh <script-path>
```

Record:

- Detected shell type
- Exit code (`0` clean, `1` warnings, `2` errors)
- All reported issue lines and ShellCheck codes (`SC####`) when present

### Step 3: Load Only Needed References

Progressive disclosure by issue type:

- ShellCheck code explanations: `docs/shellcheck-reference.md`
- General fix patterns and security mistakes: `docs/common-mistakes.md`
- Bash-only behavior: `docs/bash-reference.md`
- POSIX portability or bashism fixes: `docs/shell-reference.md`
- Text-processing optimization issues: `docs/grep-reference.md`, `docs/awk-reference.md`, `docs/sed-reference.md`, `docs/regex-reference.md` (only when directly relevant)

### Step 4: Provide or Apply Fixes

For each issue, include:

1. Exact location from validator output (line number and snippet)
2. Root cause
3. Corrected code
4. Why the change is safer or more portable
5. Subsection-level citation (format below)

If the request includes patching files and write access is available, apply fixes in small batches grouped by issue type.

### Step 5: Rerun Policy (Mandatory After Changes)

After each batch of edits, rerun the validator:

```bash
bash scripts/validate.sh <script-path>
```

Rerun loop rules:

1. Continue until no new errors are introduced.
2. If warnings remain by design, document why they are intentionally accepted.
3. If constraints prevent full resolution, report unresolved items with a clear next action.
4. Always report the latest rerun exit code and remaining issue count.

## Fallback Behavior

Use these branches only when the default flow cannot run as-is.

| Constraint | Fallback action | Reporting requirement |
| --- | --- | --- |
| `shellcheck` missing, wrapper available | Let `scripts/validate.sh` use `scripts/shellcheck_wrapper.sh --cache` automatically | State that wrapper mode was used |
| `shellcheck` and wrapper unavailable | Run syntax + custom checks only (validator does this) | Explicitly call out reduced coverage and missing ShellCheck analysis |
| Python unavailable for wrapper | Skip wrapper path, keep syntax + custom checks | State why ShellCheck could not run |
| Target file is read-only | Provide precise patch suggestions without editing | Mark response as "advisory only" |
| Target file missing or unreadable | Stop and request a valid file path | Do not fabricate results |
| Binary/non-text input | Stop validation | Report unsupported input type |

## Citation Guidance for Fixes

Use subsection-level citations for every non-trivial fix.

Required citation format:

```text
Reference: docs/<file>.md -> <Section> -> <Subsection>
```

Examples:

- `Reference: docs/common-mistakes.md -> 1. Unquoted Variables -> Solution`
- `Reference: docs/shellcheck-reference.md -> SC2164: Use || exit After cd`
- `Reference: docs/shell-reference.md -> POSIX Best Practices -> 5. Avoid Bashisms`

Citation rules:

1. Cite the most specific section that justifies the fix.
2. For ShellCheck findings, include both the `SC####` code and the matching section.
3. If no exact subsection exists, cite the closest section and state that the fix is inferred from that guidance.

## Response Template

Use this structure for deterministic output:

- `Validation Results`
- `Command`: `bash scripts/validate.sh <script-path>`
- `Detected shell`: `<shell>`
- `Exit code`: `<code>`
- `Summary`: `<errors> errors, <warnings> warnings, <info> info`
- `Issue`: `<short label> (Line <n>)`
- `Problem`:
  ```bash
  <problematic snippet>
  ```
- `Fix`:
  ```bash
  <corrected snippet>
  ```
- `Why`: `<short explanation>`
- `Reference`: `docs/<file>.md -> <Section> -> <Subsection>`
- `Rerun command`: `bash scripts/validate.sh <script-path>`
- `Exit code after fixes`: `<code>`
- `Remaining issues`: `<count or none>`

## Example Flows

### Fully Automated Environment

```bash
# 1) Baseline validation
bash scripts/validate.sh examples/bad-bash.sh

# 2) Apply fixes to target script
# 3) Rerun validation
bash scripts/validate.sh examples/bad-bash.sh
```

Expected behavior: full syntax + ShellCheck + custom-check coverage, with iterative reruns until stable.

### Constrained Environment (No ShellCheck Runtime)

```bash
# shellcheck unavailable and wrapper cannot run
bash scripts/validate.sh examples/bad-shell.sh
```

Expected behavior: syntax + custom checks still run. Report reduced coverage and list what must be revalidated once ShellCheck is available.

## Validator Script Details

### Scripts

- `scripts/validate.sh`: primary validator entrypoint
- `scripts/shellcheck_wrapper.sh`: optional ShellCheck fallback using a cached Python virtual environment

### Detection and Ordering

Validation order in `scripts/validate.sh`:

1. File checks (exists/readable/text)
2. Shebang-based shell detection
3. Syntax check
4. ShellCheck (or fallback/skip behavior)
5. Custom checks
6. Summary with exit code

### Exit Codes

- `0`: no issues found
- `1`: warnings found
- `2`: errors found

## References

Load only what is needed:

- `docs/bash-reference.md`
- `docs/shell-reference.md`
- `docs/shellcheck-reference.md`
- `docs/common-mistakes.md`
- `docs/grep-reference.md`
- `docs/awk-reference.md`
- `docs/sed-reference.md`
- `docs/regex-reference.md`

## Done Criteria

This skill update is complete when all are true:

1. Trigger guidance is explicit (positive and non-trigger examples).
2. Default workflow is deterministic and ordered.
3. Fallback behavior is explicit for missing tooling and constrained environments.
4. Fix explanations include subsection-level citations.
5. Post-fix rerun policy is mandatory and reported with exit codes.
6. Documentation supports both fully automated and constrained execution paths.
