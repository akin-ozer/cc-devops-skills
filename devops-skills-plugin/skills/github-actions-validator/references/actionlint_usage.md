# Actionlint (rhysd/actionlint) - Usage Reference

Actionlint is a static checker for GitHub Actions workflow files that catches errors before they cause CI failures.

## Installation

```bash
# Download and install using the official script
bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)

# Or use the skill's installation script
bash scripts/install_tools.sh
```

## Core Usage

### Basic Validation

Validate a single workflow file:

```bash
actionlint .github/workflows/ci.yml
```

Validate all workflow files in a directory:

```bash
actionlint .github/workflows/*.yml
```

Validate all workflows in the default location:

```bash
actionlint
```

### Output Formats

#### Default Format (human-readable)

```bash
actionlint
```

Output example:
```
.github/workflows/ci.yml:5:7: unexpected key "job" for "workflow" section [syntax-check]
.github/workflows/ci.yml:10:15: invalid CRON format "0 0 * * 8" in schedule event [events]
```

#### JSON Format

```bash
actionlint -format '{{json .}}'
```

Useful for programmatic processing and integration with other tools.

#### Sarif Format

```bash
actionlint -format sarif
```

For integration with GitHub Code Scanning and other security tools.

## Validation Categories

### 1. Syntax Checking

Validates YAML syntax and GitHub Actions schema:

- Required fields
- Valid keys and values
- Proper nesting
- Type correctness

### 2. Expression Validation

Validates GitHub Actions expressions `${{ }}`:

- Syntax errors
- Type checking (string, number, boolean)
- Function calls
- Context access

Example caught errors:
```yaml
# Error: Boolean expression expected
if: ${{ 'true' }}  # String, not boolean

# Error: Unknown function
run: echo ${{ unknown() }}

# Error: Type mismatch
if: ${{ 42 }}  # Number, not boolean
```

### 3. Runner Label Validation

Validates runner labels against known GitHub-hosted runners:

**Ubuntu:**
- `ubuntu-latest` (currently ubuntu-24.04)
- `ubuntu-24.04`, `ubuntu-22.04`, `ubuntu-20.04`

**Windows:**
- `windows-latest` (currently windows-2022)
- `windows-2025` (NEW - recently added)
- `windows-2022`, `windows-2019`

**macOS:**
- `macos-latest` (currently macos-15)
- `macos-15` (Apple Silicon M1/M2/M3)
- `macos-14` (Apple Silicon M1)
- `macos-26` (preview)
- `macos-13` (Intel - RETIRED November 14, 2025)
- `macos-12` (Intel - RETIRED)

Example:
```yaml
runs-on: ubuntu-lastest  # Error: Did you mean "ubuntu-latest"?
```

### 4. Action Validation

Validates action references:

- Action exists
- Valid version/ref
- Required inputs provided
- No unknown inputs

Example:
```yaml
# Error: Missing required input "path"
- uses: actions/checkout@v5

# Error: Unknown input "invalid_input"
- uses: actions/checkout@v5
  with:
    invalid_input: value
```

### 5. Job Dependencies

Validates `needs:` dependencies:

- Referenced jobs exist
- No circular dependencies
- Valid job IDs

### 6. CRON Syntax

Validates schedule event CRON expressions:

```yaml
# Error: Day of week must be 0-6
schedule:
  - cron: '0 0 * * 8'
```

### 7. Shell Script Validation

Integrates with shellcheck to validate shell scripts in `run:` steps:

```yaml
# Warning: Quote to prevent word splitting
run: echo $VARIABLE
```

### 8. Glob Pattern Validation

Validates glob patterns in path filters:

```yaml
on:
  push:
    paths:
      - '**.js'  # Error: Should be '**/*.js'
```

### 9. Security Checks

Detects potential security issues:

- Injection vulnerabilities
- Insecure credential handling
- Dangerous patterns

Example:
```yaml
# Warning: Potential script injection
run: echo ${{ github.event.issue.title }}
```

## Configuration

Create `.github/actionlint.yaml` or `.github/actionlint.yml`:

```yaml
# Configure shellcheck
shellcheck:
  enable: true
  shell: bash

# Configure pyflakes for Python
pyflakes:
  enable: true
  executable: pyflakes

# Ignore specific rules
ignore:
  - 'SC2086'  # Ignore shellcheck rule
  - 'action-validation'  # Ignore action validation

# Custom runner labels
self-hosted-runner:
  labels:
    - my-custom-runner
    - gpu-runner
```

## Exit Codes

- `0`: Success - no errors found
- `1`: Validation errors found
- `2`: Fatal error (invalid file, config error, etc.)

## Integration

### Pre-commit Hook

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.9  # Check https://github.com/rhysd/actionlint/releases for latest version
    hooks:
      - id: actionlint
```

**Note:** Always use the latest version of actionlint. Check the [releases page](https://github.com/rhysd/actionlint/releases) for the most recent version.

### GitHub Actions Workflow

```yaml
name: Lint GitHub Actions workflows
on: [push, pull_request]
jobs:
  actionlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3 # v6.0.0
      - name: Download actionlint
        run: bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)
      - name: Run actionlint
        run: ./actionlint
```

### VS Code Integration

Install the "actionlint" extension for real-time validation in VS Code.

## Common Error Examples

### 1. Typo in Runner Label

```yaml
# Error
runs-on: ubuntu-lastest

# Fix
runs-on: ubuntu-latest
```

### 2. Invalid CRON Expression

```yaml
# Error
schedule:
  - cron: '0 0 * * 8'  # Day of week 8 doesn't exist

# Fix
schedule:
  - cron: '0 0 * * 0'  # Sunday = 0
```

### 3. Missing Required Input

```yaml
# Error
- uses: actions/checkout@v4

# Fix (if repository input is required)
- uses: actions/checkout@v4
  with:
    repository: owner/repo
```

### 4. Invalid Expression

```yaml
# Error
if: ${{ success() && 'true' }}  # Mixing boolean and string

# Fix
if: ${{ success() && true }}
```

### 5. Undefined Job in needs

```yaml
# Error
jobs:
  deploy:
    needs: biuld  # Typo

# Fix
jobs:
  deploy:
    needs: build
```

## Best Practices

1. **Run locally before pushing**: Catch errors early
2. **Use in CI/CD**: Add actionlint to your workflow
3. **Configure for custom runners**: Update config for self-hosted runners
4. **Enable shellcheck**: Catch shell script issues
5. **Review all warnings**: Even non-fatal warnings can indicate issues
6. **Keep actionlint updated**: New rules and features are added regularly

## Limitations

- Cannot validate runtime behavior (only static analysis)
- Cannot access private actions (must be public to validate)
- May not catch all possible issues (e.g., environment-specific problems)
- Custom actions may require manual verification
