---
name: github-actions-validator
description: Comprehensive toolkit for validating, linting, and testing GitHub Actions workflow files, custom local actions, and public actions. Use this skill when working with GitHub Actions YAML files (.github/workflows/*.yml), validating workflow syntax, testing workflow execution with act, or debugging workflow issues.
---

# GitHub Actions Validator

## Overview

Validate and test GitHub Actions workflows, custom actions, and public actions using industry-standard tools (actionlint and act). This skill provides comprehensive validation including syntax checking, static analysis, local workflow execution testing, and action verification with version-aware documentation lookup.

## When to Use This Skill

Use this skill when:
- **Validating workflow files**: Checking `.github/workflows/*.yml` for syntax errors and best practices
- **Testing workflows locally**: Running workflows with `act` before pushing to GitHub
- **Debugging workflow failures**: Identifying issues in workflow configuration
- **Validating custom actions**: Checking composite, Docker, or JavaScript actions
- **Verifying public actions**: Validating usage of actions from GitHub Marketplace
- **Pre-commit validation**: Ensuring workflows are valid before committing

## CRITICAL: Assistant Workflow (MUST FOLLOW)

**Every validation MUST follow these steps. Skipping any step is non-compliant.**

### Step 1: Run Validation Script

```bash
cd .claude/skills/github-actions-validator
bash scripts/validate_workflow.sh <workflow-file-or-directory>
```

### Step 2: For EACH Error - Consult Reference File

When actionlint or act reports ANY error, you MUST:

1. **Read the appropriate reference file** (see mapping below)
2. **Find the matching error pattern**
3. **Extract the fix/solution**

### Step 3: Quote the Fix to User

For each error, provide:

1. **Error message** (from script output)
2. **Explanation** (from reference file)
3. **Fix code** (quoted from reference file)
4. **Corrected code** (applied to user's workflow)

### Step 4: Verify Public Actions (if present)

For any public actions (`uses: owner/action@version`):

1. **First check `references/action_versions.md`** for known actions and versions
2. **Use web search** for unknown actions: `"[action-name] [version] github action documentation"`
3. **Verify required inputs match**
4. **Check for deprecation warnings**

### Step 5: Provide Complete Summary

After all errors are addressed:
- List all fixes applied
- Note any warnings
- Recommend best practices from `references/`

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

### Initial Setup

```bash
cd .claude/skills/github-actions-validator
bash scripts/install_tools.sh
```

This installs **act** (local workflow execution) and **actionlint** (static analysis) to `scripts/.tools/`.

### Basic Validation

```bash
# Validate a single workflow
bash scripts/validate_workflow.sh .github/workflows/ci.yml

# Validate all workflows
bash scripts/validate_workflow.sh .github/workflows/

# Lint-only (fastest)
bash scripts/validate_workflow.sh --lint-only .github/workflows/ci.yml

# Test-only with act (requires Docker)
bash scripts/validate_workflow.sh --test-only .github/workflows/
```

## Core Validation Workflow

### 1. Static Analysis with actionlint

Start with static analysis to catch syntax errors and common issues:

```bash
bash scripts/validate_workflow.sh --lint-only .github/workflows/ci.yml
```

**What actionlint checks:** YAML syntax, schema compliance, expression syntax, runner labels, action inputs/outputs, job dependencies, CRON syntax, glob patterns, shell scripts, security vulnerabilities.

### 2. Local Testing with act

After passing static analysis, test workflow execution:

```bash
bash scripts/validate_workflow.sh --test-only .github/workflows/
```

**Note:** act has limitations - see `references/act_usage.md`.

### 3. Full Validation

```bash
bash scripts/validate_workflow.sh .github/workflows/ci.yml
```

## Validating Resource Types

### Workflows

```bash
# Single workflow
bash scripts/validate_workflow.sh .github/workflows/ci.yml

# All workflows
bash scripts/validate_workflow.sh .github/workflows/
```

**Key validation points:** triggers, job configurations, runner labels, environment variables, secrets, conditionals, matrix strategies.

### Custom Local Actions

Create a test workflow that uses the custom action, then validate:

```bash
bash scripts/validate_workflow.sh .github/workflows/test-custom-action.yml
```

### Public Actions

When workflows use public actions (e.g., `actions/checkout@v6`):

1. Use web search to find action documentation
2. Verify required inputs and version
3. Check for deprecation warnings
4. Run validation script

**Search format:** `"[action-name] [version] github action documentation"`

## Reference File Consultation Guide

### MANDATORY Reference Consultation

| Situation | Reference File | Action |
|-----------|---------------|--------|
| actionlint reports ANY error | `references/common_errors.md` | Find matching error, quote solution |
| act fails with Docker error | `references/act_usage.md` | Check Troubleshooting section |
| act fails but workflow works on GitHub | `references/act_usage.md` | Read Limitations section |
| User asks about actionlint config | `references/actionlint_usage.md` | Provide examples |
| User asks about act options | `references/act_usage.md` | Read Advanced Options |
| Security vulnerability detected | `references/common_errors.md` | Quote fix |
| Validating action versions | `references/action_versions.md` | Check version table |
| Using modern features | `references/modern_features.md` | Check syntax examples |
| Runner questions/errors | `references/runners.md` | Check labels and availability |

### Script Output to Reference Mapping

| Output Category | Reference File |
|-----------------|----------------|
| `[SYNTAX]` | `common_errors.md` - Syntax Errors |
| `[EXPRESSION]` | `common_errors.md` - Expression Errors |
| `[ACTION]` | `common_errors.md` - Action Errors |
| `[SCHEDULE]` | `common_errors.md` - Schedule Errors |
| `[SECURITY]` | `common_errors.md` - Security section |
| `[DOCKER]` | `act_usage.md` - Troubleshooting |
| `[ACT-LIMIT]` | `act_usage.md` - Limitations |

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
| "Tools not found" | Run `bash scripts/install_tools.sh` |
| "Docker daemon not running" | Start Docker or use `--lint-only` |
| "Permission denied" | Run `chmod +x scripts/*.sh` |
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
5. **Use web search for unknown actions** - Verify usage with documentation
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
cd .claude/skills/github-actions-validator
bash scripts/validate_workflow.sh .github/workflows/
git add .github/workflows/ && git commit -m "Update workflows"
```

### Example 2: Debug Failing Workflow

```bash
bash scripts/validate_workflow.sh --lint-only .github/workflows/failing.yml
# Fix issues
bash scripts/validate_workflow.sh .github/workflows/failing.yml
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
bash scripts/validate_workflow.sh --lint-only workflow.yml
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

### Step 5: Summary

| Error | Type | Fix Applied |
|-------|------|-------------|
| CRON `0 0 * * 8` | Schedule | Changed to `0 0 * * 0` |
| `ubuntu-lastest` | Runner | Changed to `ubuntu-latest` |
| `checkout@v3` | Outdated Action | Updated to `@v6.0.0` (SHA-pinned) |
| Direct `${{ }}` in run | Security | Wrapped in environment variable |
| `needs: biuld` | Job Dependency | Changed to `needs: build` |

**Recommendations:**
- Run `bash scripts/validate_workflow.sh --check-versions` regularly
- Use SHA pinning for all actions in production workflows
- Always pass untrusted input through environment variables

## Summary

1. **Setup**: Install tools with `install_tools.sh`
2. **Validate**: Run `validate_workflow.sh` on workflow files
3. **Fix**: Address issues using reference documentation
4. **Test**: Verify locally with act (when possible)
5. **Search**: Use web search to verify unknown actions
6. **Commit**: Push validated workflows with confidence

For detailed information, consult the appropriate reference file in `references/`.