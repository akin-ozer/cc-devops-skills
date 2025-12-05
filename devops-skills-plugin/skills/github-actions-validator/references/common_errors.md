# Common GitHub Actions Errors and Solutions

This reference lists common errors encountered when working with GitHub Actions and how to fix them.

## Syntax Errors

### 1. Invalid YAML Syntax

**Error:**
```
Error: Unable to process file command 'workflow' successfully.
```

**Common Causes:**
- Incorrect indentation (YAML is whitespace-sensitive)
- Missing colons
- Unquoted strings containing special characters
- Tabs instead of spaces

**Fix:**
```yaml
# Bad
name:My Workflow
jobs:
build:
  runs-on: ubuntu-latest

# Good
name: My Workflow
jobs:
  build:
    runs-on: ubuntu-latest
```

### 2. Missing Required Fields

**Error:**
```
Required property is missing: name
```

**Fix:**
```yaml
# Every workflow needs a name
name: CI Pipeline

on: [push]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3  # v6.0.0
```

### 3. Invalid Workflow Triggers

**Error:**
```
The workflow is not valid. Unexpected value 'on'
```

**Fix:**
```yaml
# Bad - wrong event name
on:
  pull-request:  # Should be pull_request

# Good
on:
  pull_request:
  push:
```

## Expression Errors

### 1. Incorrect Expression Syntax

**Error:**
```
Unrecognized named-value: 'github'. Located at position 1 within expression: github.ref
```

**Fix:**
```yaml
# Bad - missing ${{ }}
if: github.ref == 'refs/heads/main'

# Good
if: ${{ github.ref == 'refs/heads/main' }}

# Even better (GitHub Actions auto-evaluates if conditions)
if: github.ref == 'refs/heads/main'
```

### 2. Type Mismatches

**Error:**
```
Expected boolean value, got string
```

**Fix:**
```yaml
# Bad
if: ${{ 'true' }}  # String, not boolean

# Good
if: ${{ true }}
if: ${{ success() }}
if: ${{ github.event_name == 'push' }}
```

### 3. Script Injection Vulnerabilities

**Warning:**
```
Potential script injection via untrusted input
```

**Fix:**
```yaml
# Bad - vulnerable to injection
run: echo ${{ github.event.issue.title }}

# Good - use environment variables
env:
  TITLE: ${{ github.event.issue.title }}
run: echo "$TITLE"
```

## Action Errors

### 1. Action Not Found

**Error:**
```
Can't find 'action.yml', 'action.yaml' or 'Dockerfile' under '/home/runner/work/_actions/actions/chekout/v4'
```

**Common Causes:**
- Typo in action name
- Invalid action reference
- Action doesn't exist or was removed

**Fix:**
```yaml
# Bad
- uses: actions/chekout@v4  # Typo

# Good
- uses: actions/checkout@v4
```

### 2. Missing Required Inputs

**Error:**
```
Input required and not supplied: path
```

**Fix:**
```yaml
# Bad
- uses: some-action@v1

# Good
- uses: some-action@v1
  with:
    path: ./my-path
```

### 3. Unknown Action Inputs

**Error:**
```
Unexpected input 'invalid_input'
```

**Fix:**
```yaml
# Check the action's documentation for valid inputs
- uses: actions/checkout@v4
  with:
    # Only use documented inputs
    ref: main
    # Remove undocumented inputs
```

### 4. Deprecated Action Versions

**Warning:**
```
Node.js 12/16 actions are deprecated
```

**Fix:**
```yaml
# Deprecated - Node.js 12 (EOL April 2022)
- uses: actions/checkout@v2

# Deprecated - Node.js 16 (EOL September 2023)
- uses: actions/checkout@v3

# Older - Node.js 20 (EOL April 2026)
- uses: actions/checkout@v4
- uses: actions/checkout@v5

# Current - Node.js 20+/24 (v6)
- uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3  # v6.0.0
- uses: actions/setup-node@2028fbc5c25fe9cf00d9f06a71cc4710d4507903  # v6.0.0

# Note: Node.js 20 EOL is April 2026, Node.js 22 and 24 are current
```

## Job Configuration Errors

### 1. Invalid Runner Label

**Error:**
```
Unable to locate executable file: ubuntu-lastest
```

**Fix:**
```yaml
# Bad
runs-on: ubuntu-lastest  # Typo

# Good
runs-on: ubuntu-latest
```

Valid runner labels:
- `ubuntu-latest`, `ubuntu-22.04`, `ubuntu-20.04`
- `windows-latest`, `windows-2025`, `windows-2022`, `windows-2019`
- `macos-latest` (now macOS 15), `macos-15`, `macos-14`, `macos-26` (preview)
- `macos-13` (RETIRED November 14, 2025 - no longer available)
- `macos-15-intel`, `macos-15-large` (Intel x86_64, long-term deprecated)
- `macos-15-xlarge`, `macos-14-xlarge` (M2 Pro with GPU)
- `gpu-t4-4-core` (GPU runners for ML/AI)
- ARM64 runners (free for public repos)

### 2. Undefined Job Dependency

**Error:**
```
Job 'deploy' depends on job 'biuld' which does not exist
```

**Fix:**
```yaml
# Bad
jobs:
  build:
    runs-on: ubuntu-latest
  deploy:
    needs: biuld  # Typo

# Good
jobs:
  build:
    runs-on: ubuntu-latest
  deploy:
    needs: build
```

### 3. Circular Job Dependencies

**Error:**
```
Circular dependency detected
```

**Fix:**
```yaml
# Bad
jobs:
  job1:
    needs: job2
  job2:
    needs: job1  # Circular!

# Good
jobs:
  job1:
    runs-on: ubuntu-latest
  job2:
    needs: job1
```

## Schedule Errors

### 1. Invalid CRON Syntax

**Error:**
```
Invalid CRON expression: '0 0 * * 8'
```

**Fix:**
```yaml
# Bad
schedule:
  - cron: '0 0 * * 8'  # Day 8 doesn't exist

# Good
schedule:
  - cron: '0 0 * * 0'  # Sunday

# CRON format: minute hour day month weekday
# Minute: 0-59
# Hour: 0-23
# Day: 1-31
# Month: 1-12
# Weekday: 0-6 (0 = Sunday)
```

### 2. Multiple Schedule Entries

```yaml
# Correct way to define multiple schedules
on:
  schedule:
    - cron: '0 0 * * 1'  # Monday at midnight
    - cron: '0 12 * * 5'  # Friday at noon
```

## Path Filter Errors

### 1. Invalid Glob Pattern

**Error:**
```
Invalid glob pattern: '**.js'
```

**Fix:**
```yaml
# Bad
on:
  push:
    paths:
      - '**.js'  # Missing directory separator

# Good
on:
  push:
    paths:
      - '**/*.js'
      - 'src/**'
```

## Environment and Secrets

### 1. Secret Not Found

**Error:**
```
Secret MY_SECRET not found
```

**Fix:**
- Ensure the secret is defined in repository settings
- Check secret name spelling (case-sensitive)
- Verify secret scope (repository vs organization vs environment)

```yaml
# Use secrets correctly
env:
  API_KEY: ${{ secrets.MY_SECRET }}  # Must match name in settings
```

### 2. Environment Variables in run

**Common Issue:**
```yaml
# Bad - environment variable not accessible
steps:
  - run: echo $MY_VAR  # May not work on Windows

# Good - use env
steps:
  - name: Print variable
    env:
      MY_VAR: ${{ secrets.MY_SECRET }}
    run: echo "$MY_VAR"  # Unix
    # or
    run: echo $env:MY_VAR  # Windows PowerShell
```

## Matrix Strategy Errors

### 1. Invalid Matrix Configuration

**Error:**
```
Matrix configuration is invalid
```

**Fix:**
```yaml
# Bad
strategy:
  matrix:
    os: ubuntu-latest  # Should be an array

# Good
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node: [20, 22, 24]  # Node 16 EOL Sep 2023, Node 20 EOL Apr 2026
```

### 2. Matrix Variable Reference

```yaml
# Correct way to reference matrix variables
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
jobs:
  test:
    runs-on: ${{ matrix.os }}
```

## Conditional Execution Errors

### 1. Always/Cancelled/Failure Conditions

```yaml
# Understanding conditions
steps:
  - name: Run on success (default)
    run: echo "Runs only if previous steps succeeded"

  - name: Run always
    if: always()
    run: echo "Runs whether previous steps succeeded or failed"

  - name: Run on failure
    if: failure()
    run: echo "Runs only if a previous step failed"

  - name: Run on success
    if: success()
    run: echo "Runs only if all previous steps succeeded"
```

## Debugging Tips

### 1. Enable Debug Logging

Set secrets in repository settings:
- `ACTIONS_STEP_DEBUG` = `true` (detailed step logs)
- `ACTIONS_RUNNER_DEBUG` = `true` (runner diagnostic logs)

### 2. Use tmate for Interactive Debugging

```yaml
steps:
  - name: Setup tmate session
    if: failure()
    uses: mxschmitt/action-tmate@v3
```

### 3. Print Context Information

```yaml
steps:
  - name: Dump GitHub context
    run: echo '${{ toJSON(github) }}'

  - name: Dump job context
    run: echo '${{ toJSON(job) }}'

  - name: Dump runner context
    run: echo '${{ toJSON(runner) }}'
```

## Best Practices

1. **Always use specific action versions**: `actions/checkout@v6` not `actions/checkout@main`
2. **Quote strings with special characters**: `name: "My: Workflow"`
3. **Use shellcheck**: Enable shell script linting
4. **Validate locally**: Use act and actionlint before pushing
5. **Use env for secrets**: Never put secrets directly in run commands
6. **Keep workflows DRY**: Use reusable workflows and composite actions
7. **Set timeouts**: Prevent runaway jobs with `timeout-minutes`
8. **Use concurrency**: Cancel redundant runs with concurrency groups

```yaml
# Example of good practices
name: Production Deployment

on:
  push:
    branches: [main]

concurrency:
  group: production
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@1af3b93b6815bc44a9784bd300feb67ff0d1eeb3  # v6.0.0

      - name: Deploy
        env:
          API_KEY: ${{ secrets.API_KEY }}
        run: |
          ./deploy.sh
```
