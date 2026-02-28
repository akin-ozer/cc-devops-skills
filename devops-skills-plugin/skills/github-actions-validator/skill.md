---
name: github-actions-validator
description: Comprehensive toolkit for validating, linting, and testing GitHub Actions workflow files, custom local actions, and public actions. Use this skill when working with GitHub Actions YAML files (.github/workflows/*.yml), validating workflow syntax, testing workflow execution with act, or debugging workflow issues.
---

# GitHub Actions Validator

## Overview

Validate and test GitHub Actions workflows, custom actions, and public actions using industry-standard tools (actionlint and act). This skill provides comprehensive validation including syntax checking, static analysis, local workflow execution testing, and action verification with version-aware documentation lookup.

## Trigger Phrases

Use this skill when the request includes phrases like:
- "validate this GitHub Actions workflow"
- "check my `.github/workflows/*.yml` file"
- "debug actionlint errors"
- "test this workflow locally with act"
- "verify GitHub Action versions or deprecations"

## When to Use This Skill

Use this skill when:
- **Validating workflow files**: Checking `.github/workflows/*.yml` for syntax errors and best practices
- **Testing workflows locally**: Running workflows with `act` before pushing to GitHub
- **Debugging workflow failures**: Identifying issues in workflow configuration
- **Validating custom actions**: Checking composite, Docker, or JavaScript actions
- **Verifying public actions**: Validating usage of actions from GitHub Marketplace
- **Pre-commit validation**: Ensuring workflows are valid before committing

## Required Execution Flow

Every validation run should follow these steps in order.

### Step 1: Set Skill Path and Run Validation

Run commands from the repository root that contains `.github/workflows/`.

```bash
SKILL_DIR="devops-skills-plugin/skills/github-actions-validator"
bash "$SKILL_DIR/scripts/validate_workflow.sh" <workflow-file-or-directory>
```

### Step 2: Map Each Error to a Reference

For each actionlint/act error, consult the mapping table below, then extract the matching fix pattern.

### Step 3: Apply Minimal-Quote Policy

For each issue:
1. Include the exact error line from tool output.
2. Quote only the smallest useful snippet from `references/` (prefer <=8 lines).
3. Paraphrase the rest and cite the source file/section.
4. Show corrected workflow code.

### Step 4: Handle Unmapped Errors Explicitly

If an error does not match any mapping:
1. Label it as `UNMAPPED`.
2. Capture exact tool output, workflow file, and line number (if available).
3. Check `references/common_errors.md` general sections first.
4. If still unresolved, search official docs with the exact error string.
5. Mark the fix as `provisional` until post-fix rerun passes.

### Step 5: Verify Public Action Versions

For each `uses: owner/action@version`:
1. Check `references/action_versions.md`.
2. For unknown actions, verify against official docs.
3. Confirm required inputs and deprecations.

Offline mode behavior:
- If network/doc lookup is unavailable, rely on `references/action_versions.md` only.
- Mark unknown actions as `UNVERIFIED-OFFLINE`.
- Do not claim "latest" version without an online verification pass.

### Step 6: Mandatory Post-Fix Rerun

After applying fixes, rerun validation before finalizing:

```bash
SKILL_DIR="devops-skills-plugin/skills/github-actions-validator"
bash "$SKILL_DIR/scripts/validate_workflow.sh" <workflow-file-or-directory>
```

### Step 7: Provide Final Summary

Final output should include:
- Issues found and fixes applied
- Any `UNMAPPED` or `UNVERIFIED-OFFLINE` items
- Post-fix rerun command and result
- Remaining warnings/risk notes

### Error Type to Reference File Mapping

| Error Pattern in Output | Reference File to Read | Section to Quote |
|------------------------|----------------------|------------------|
| `runs-on:`, `runner`, `ubuntu`, `macos`, `windows` | `references/runners.md` | Runner labels |
| `cron`, `schedule` | `references/common_errors.md` | Schedule Errors |
| `${{`, `expression`, `if:` | `references/common_errors.md` | Expression Errors |
| `needs:`, `job`, `dependency` | `references/common_errors.md` | Job Configuration Errors |
| `uses:`, `action`, `input` | `references/common_errors.md` | Action Errors |
| `untrusted`, `injection`, `security` | `references/common_errors.md` | Script Injection section |
| `syntax`, `yaml`, `unexpected` | `references/common_errors.md` | Syntax Errors |
| `docker`, `container` | `references/act_usage.md` | Troubleshooting |
| `@v3`, `@v4`, `deprecated`, `outdated` | `references/action_versions.md` | Version table |
| `workflow_call`, `reusable`, `oidc` | `references/modern_features.md` | Relevant section |
| `glob`, `path`, `paths:`, `pattern` | `references/common_errors.md` | Path Filter Errors |

### Example: Complete Error Handling Workflow

**User's workflow has this error:**
```
runs-on: ubuntu-lastest
```

**Step 1 - Script output:**
```
label "ubuntu-lastest" is unknown
```

**Step 2 - Read `references/runners.md` or `references/common_errors.md`:**
Find the "Invalid Runner Label" section.

**Step 3 - Quote the fix to user:**

> **Error:** `label "ubuntu-lastest" is unknown`
>
> **Cause:** Typo in runner label (from `references/common_errors.md`):
> ```yaml
> # Bad
> runs-on: ubuntu-lastest  # Typo
> ```
>
> **Fix** (from `references/common_errors.md`):
> ```yaml
> # Good
> runs-on: ubuntu-latest
> ```
>
> **Valid runner labels** (from `references/runners.md`):
> - `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-22.04`
> - `windows-latest`, `windows-2025`, `windows-2022`
> - `macos-latest`, `macos-15`, `macos-14`

**Step 4 - Provide corrected code:**
```yaml
runs-on: ubuntu-latest
```

## Quick Start

Set once per shell session:

```bash
SKILL_DIR="devops-skills-plugin/skills/github-actions-validator"
```

### Initial Setup

```bash
bash "$SKILL_DIR/scripts/install_tools.sh"
```

This installs **act** (local workflow execution) and **actionlint** (static analysis) to `scripts/.tools/`.

### Basic Validation

```bash
# Validate a single workflow
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/ci.yml

# Validate all workflows
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/

# Lint-only (fastest)
bash "$SKILL_DIR/scripts/validate_workflow.sh" --lint-only .github/workflows/ci.yml

# Test-only with act (requires Docker)
bash "$SKILL_DIR/scripts/validate_workflow.sh" --test-only .github/workflows/
```

## Core Validation Workflow

### 1. Static Analysis with actionlint

Start with static analysis to catch syntax errors and common issues:

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" --lint-only .github/workflows/ci.yml
```

**What actionlint checks:** YAML syntax, schema compliance, expression syntax, runner labels, action inputs/outputs, job dependencies, CRON syntax, glob patterns, shell scripts, security vulnerabilities.

### 2. Local Testing with act

After passing static analysis, test workflow execution:

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" --test-only .github/workflows/
```

**Note:** act has limitations - see `references/act_usage.md`.

### 3. Full Validation

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/ci.yml
```

Default behavior if tools/runtime are unavailable:
- If `act` is missing, full validation falls back to actionlint-only.
- If Docker is unavailable, full validation skips act and continues with actionlint.
- `--check-versions` works in offline/local mode using `references/action_versions.md`.

## Validating Resource Types

### Workflows

```bash
# Single workflow
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/ci.yml

# All workflows
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/
```

**Key validation points:** triggers, job configurations, runner labels, environment variables, secrets, conditionals, matrix strategies.

### Custom Local Actions

Create a test workflow that uses the custom action, then validate:

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/test-custom-action.yml
```

### Public Actions

When workflows use public actions (e.g., `actions/checkout@v6`):

1. Check `references/action_versions.md` first
2. Use official docs (or web search) for unknown actions
3. Verify required inputs and version
4. Check for deprecation warnings
5. Run validation script

If offline:
- Mark unknown versions as `UNVERIFIED-OFFLINE`
- Avoid "latest/current" claims until online verification is possible

**Search format:** `"[action-name] [version] github action documentation"`

## Reference File Consultation Guide

### Mandatory Reference Consultation

| Situation | Reference File | Action |
|-----------|---------------|--------|
| actionlint reports any mapped error | `references/common_errors.md` | Find matching error and apply minimal quote policy |
| actionlint reports unmapped error | `references/common_errors.md` + official docs | Label as `UNMAPPED`, capture exact output and verify by rerun |
| act fails with Docker/runtime error | `references/act_usage.md` | Check Troubleshooting section |
| act fails but workflow works on GitHub | `references/act_usage.md` | Read Limitations section |
| User asks about actionlint config | `references/actionlint_usage.md` | Provide examples |
| User asks about act options | `references/act_usage.md` | Read Advanced Options |
| Security vulnerability detected | `references/common_errors.md` | Quote minimal safe fix snippet |
| Validating action versions | `references/action_versions.md` | Check version table and offline note |
| Using modern features | `references/modern_features.md` | Check syntax examples |
| Runner questions/errors | `references/runners.md` | Check labels and availability |

### Script Output to Reference Mapping

| Output Pattern | Reference File |
|----------------|----------------|
| `[syntax-check]`, parse, YAML errors | `common_errors.md` - Syntax Errors |
| `[expression]`, `${{`, condition parsing | `common_errors.md` - Expression Errors |
| `[action]`, `uses:`, input/output mismatch | `common_errors.md` - Action Errors |
| `[events]` with CRON/schedule text | `common_errors.md` - Schedule Errors |
| `potentially untrusted`, injection warnings | `common_errors.md` - Security section |
| `[runner-label]` or unknown `runs-on` label | `runners.md` |
| `[job-needs]` dependency errors | `common_errors.md` - Job Configuration Errors |
| `[glob]`, `paths`, pattern errors | `common_errors.md` - Path Filter Errors |
| Docker/pull/image errors from act | `act_usage.md` - Troubleshooting |
| No pattern match | `common_errors.md` + official docs (label `UNMAPPED`) |

## Reference Files Summary

| File | Content |
|------|---------|
| `references/act_usage.md` | Act tool usage, commands, options, limitations, troubleshooting |
| `references/actionlint_usage.md` | Actionlint validation categories, configuration, integration |
| `references/common_errors.md` | Common errors catalog with fixes |
| `references/action_versions.md` | Current action versions, deprecation timeline, SHA pinning |
| `references/modern_features.md` | Reusable workflows, SBOM, OIDC, environments, containers |
| `references/runners.md` | GitHub-hosted runners (ARM64, GPU, M2 Pro, deprecations) |

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Tools not found" | Run `bash "$SKILL_DIR/scripts/install_tools.sh"` |
| "Docker daemon not running" | Start Docker or use `--lint-only` |
| "Permission denied" | Run `chmod +x "$SKILL_DIR"/scripts/*.sh` |
| act fails but GitHub works | See `references/act_usage.md` Limitations |

### Debug Mode

```bash
actionlint -verbose .github/workflows/ci.yml  # Verbose actionlint
act -v                                         # Verbose act
act -n                                         # Dry-run (no execution)
```

## Best Practices

1. **Always validate locally first** - Catch errors before pushing
2. **Use actionlint in CI/CD** - Automate validation in pipelines
3. **Pin action versions** - Use `@v6` not `@main` for stability; SHA pinning for security
4. **Keep tools updated** - Regularly update actionlint and act
5. **Use official docs for unknown actions** - Verify usage and versions
6. **Check version compatibility** - See `references/action_versions.md`
7. **Enable shellcheck** - Catch shell script issues early
8. **Review security warnings** - Address script injection issues

## Limitations

- **act limitations**: Not all GitHub Actions features work locally
- **Docker requirement**: act requires Docker to be running
- **Network actions**: Some GitHub API actions may fail locally
- **Private actions**: Cannot validate without access
- **Runtime behavior**: Static analysis cannot catch all issues
- **File location**: act can only validate workflows in `.github/workflows/` directory; files outside (like `examples/`) can only be validated with actionlint

## Quick Examples

### Example 1: Pre-commit Validation

```bash
SKILL_DIR="devops-skills-plugin/skills/github-actions-validator"
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/
git add .github/workflows/ && git commit -m "Update workflows"
```

### Example 2: Debug Failing Workflow

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" --lint-only .github/workflows/failing.yml
# Fix issues
bash "$SKILL_DIR/scripts/validate_workflow.sh" .github/workflows/failing.yml
```

## Complete Worked Example: Multi-Error Workflow

This example demonstrates the **full assistant workflow** for handling multiple errors.

### User's Problematic Workflow

```yaml
name: Broken CI
on:
  schedule:
    - cron: '0 0 * * 8'  # ERROR 1
jobs:
  build:
    runs-on: ubuntu-lastest  # ERROR 2
    steps:
      - uses: actions/checkout@v3  # ERROR 3 (outdated)
      - run: echo ${{ github.event.issue.title }}  # ERROR 4 (security)
  deploy:
    needs: biuld  # ERROR 5 (typo)
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying"
```

### Step 1: Run Validation

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" --lint-only workflow.yml
```

**Output:**
```
[ERROR] invalid CRON format "0 0 * * 8"
[ERROR] label "ubuntu-lastest" is unknown
[WARN] "github.event.issue.title" is potentially untrusted
[ERROR] job "deploy" needs job "biuld" which does not exist
```

### Step 2-3: Consult References and Quote Fixes

---

**Error 1: Invalid CRON Expression**

*From `references/common_errors.md` - Schedule Errors:*

> **Cause:** Day of week 8 doesn't exist (valid: 0-6, where 0 = Sunday)
>
> ```yaml
> # Bad
> schedule:
>   - cron: '0 0 * * 8'  # Day 8 doesn't exist
>
> # Good
> schedule:
>   - cron: '0 0 * * 0'  # Sunday
> ```
>
> **CRON format:** `minute hour day month weekday`
> - Weekday: 0-6 (0 = Sunday)

**Fix:** Change `8` to `0` (Sunday) or `1-6` for Monday-Saturday.

---

**Error 2: Invalid Runner Label**

*From `references/common_errors.md` - Job Configuration Errors and `references/runners.md`:*

> **Cause:** Typo in runner label
>
> ```yaml
> # Bad
> runs-on: ubuntu-lastest  # Typo
>
> # Good
> runs-on: ubuntu-latest
> ```
>
> **Valid labels (from `references/runners.md`):**
> - `ubuntu-latest` (Ubuntu 24.04)
> - `ubuntu-24.04`, `ubuntu-22.04`
> - `macos-latest` (macOS 15)
> - `windows-latest` (Windows Server 2022)

**Fix:** Change `ubuntu-lastest` to `ubuntu-latest`.

---

**Error 3: Outdated Action Version**

*From `references/action_versions.md`:*

> | Action | Current Version | Minimum Supported |
> |--------|----------------|-------------------|
> | `actions/checkout` | **v6** | v4 |
>
> **SHA Pinning Best Practice:**
> ```yaml
> # Recommended: SHA pinning with version comment
> - uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3  # v6.0.0
> ```

**Fix:** Update from `@v3` to `@v6` (or SHA-pinned version).

---

**Error 4: Security Vulnerability (Script Injection)**

*From `references/common_errors.md` - Expression Errors:*

> **Warning:** Potential script injection via untrusted input
>
> ```yaml
> # Bad - vulnerable to injection
> run: echo ${{ github.event.issue.title }}
>
> # Good - use environment variables
> env:
>   TITLE: ${{ github.event.issue.title }}
> run: echo "$TITLE"
> ```
>
> **Why:** Untrusted input (issue titles, PR bodies, commit messages) can contain malicious commands. Using environment variables sanitizes the input.

**Fix:** Pass untrusted input through environment variable.

---

**Error 5: Undefined Job Dependency**

*From `references/common_errors.md` - Job Configuration Errors:*

> **Error:** Job 'deploy' depends on job 'biuld' which does not exist
>
> ```yaml
> # Bad
> jobs:
>   build:
>     runs-on: ubuntu-latest
>   deploy:
>     needs: biuld  # Typo
>
> # Good
> jobs:
>   build:
>     runs-on: ubuntu-latest
>   deploy:
>     needs: build
> ```

**Fix:** Change `biuld` to `build`.

---

### Step 4: Provide Corrected Workflow

```yaml
name: Fixed CI
on:
  schedule:
    - cron: '0 0 * * 0'  # Fixed: Sunday (0-6 valid)
jobs:
  build:
    runs-on: ubuntu-latest  # Fixed: typo corrected
    steps:
      - uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3  # v6.0.0 - Fixed: updated version
      - name: Process issue
        env:
          TITLE: ${{ github.event.issue.title }}  # Fixed: use env var
        run: echo "$TITLE"
  deploy:
    needs: build  # Fixed: typo corrected
    runs-on: ubuntu-latest
    steps:
      - run: echo "Deploying"
```

### Step 5: Mandatory Rerun

```bash
bash "$SKILL_DIR/scripts/validate_workflow.sh" --lint-only workflow.yml
```

Expected rerun result:
- No previous errors reproduced
- Remaining warnings, if any, are documented explicitly

### Step 6: Summary

| Error | Type | Fix Applied |
|-------|------|-------------|
| CRON `0 0 * * 8` | Schedule | Changed to `0 0 * * 0` |
| `ubuntu-lastest` | Runner | Changed to `ubuntu-latest` |
| `checkout@v3` | Outdated Action | Updated to `@v6.0.0` (SHA-pinned) |
| Direct `${{ }}` in run | Security | Wrapped in environment variable |
| `needs: biuld` | Job Dependency | Changed to `needs: build` |

**Recommendations:**
- Run `bash "$SKILL_DIR/scripts/validate_workflow.sh" --check-versions` regularly
- Use SHA pinning for all actions in production workflows
- Always pass untrusted input through environment variables

## Done Criteria

Validation work is complete when all are true:
- Trigger matched and correct validation mode selected.
- Each mapped error includes source reference and minimal quote.
- Each unmapped error is labeled `UNMAPPED` with exact output captured.
- Public action versions are verified, or marked `UNVERIFIED-OFFLINE`.
- Post-fix rerun executed and result reported.

## Summary

1. **Setup**: Install tools with `install_tools.sh`
2. **Validate**: Run `validate_workflow.sh` on workflow files
3. **Fix**: Address issues using reference documentation
4. **Rerun**: Verify fixes with a mandatory post-fix validation run
5. **Search**: Use official docs to verify unknown actions
6. **Commit**: Push validated workflows with confidence

For detailed information, consult the appropriate reference file in `references/`.
