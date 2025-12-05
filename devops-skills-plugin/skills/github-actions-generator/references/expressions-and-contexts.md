# GitHub Actions Expressions and Contexts

**Last Updated:** November 2025
**Source:** Official GitHub Actions documentation and Context7 verified examples

## Table of Contents
1. [Expression Syntax](#expression-syntax)
2. [Contexts](#contexts)
3. [Functions](#functions)
4. [Operators](#operators)
5. [Common Patterns](#common-patterns)
6. [Debugging and Troubleshooting](#debugging-and-troubleshooting)

## Expression Syntax

GitHub Actions expressions use `${{ }}` syntax to evaluate values dynamically.

**Basic Usage:**
```yaml
- name: Print environment
  run: echo "Running on ${{ runner.os }}"

- name: Conditional step
  if: ${{ github.ref == 'refs/heads/main' }}
  run: echo "On main branch"

# Note: 'if' doesn't require ${{ }}, it's implicit
- name: Conditional step (preferred)
  if: github.ref == 'refs/heads/main'
  run: echo "On main branch"
```

**Where Expressions Can Be Used:**
- `if` conditionals (implicit `${{ }}`, can omit)
- `env` values (must use `${{ }}`)
- `with` inputs (must use `${{ }}`)
- Step `name` values (must use `${{ }}`)
- Job `outputs` (must use `${{ }}`)
- `environment.name` (can use expressions for dynamic environments)

**Important Notes:**
- Expressions are interpolated **before** the job is sent to the runner
- Use environment variables via `env` context for safer variable handling
- Avoid direct interpolation of untrusted input (use `env` context instead)

## Contexts

Contexts are objects containing information about workflow runs, variables, environments, and more.

### github context

Contains information about the workflow run and triggering event.

**Common Properties:**
```yaml
# Event information
${{ github.event_name }}          # Event that triggered workflow (push, pull_request, etc.)
${{ github.event.action }}        # Action that triggered event (opened, synchronize, etc.)

# Repository information
${{ github.repository }}          # owner/repo
${{ github.repository_owner }}    # Repository owner
${{ github.ref }}                 # Full ref (refs/heads/main, refs/tags/v1.0.0)
${{ github.ref_name }}            # Short ref (main, v1.0.0)
${{ github.sha }}                 # Commit SHA that triggered workflow

# Actor information
${{ github.actor }}               # Username that triggered workflow
${{ github.triggering_actor }}    # User that initiated the workflow run

# Workflow information
${{ github.workflow }}            # Workflow name
${{ github.run_id }}              # Unique workflow run ID
${{ github.run_number }}          # Workflow run number
${{ github.job }}                 # Current job ID

# Pull request information (when event is pull_request)
${{ github.event.pull_request.number }}
${{ github.event.pull_request.title }}
${{ github.event.pull_request.head.ref }}    # Source branch
${{ github.event.pull_request.base.ref }}    # Target branch
${{ github.event.pull_request.head.sha }}

# Push information (when event is push)
${{ github.event.head_commit.message }}
${{ github.event.head_commit.author.name }}
```

**Examples:**
```yaml
# Build image tagged with commit SHA
- name: Build Docker image
  run: docker build -t myapp:${{ github.sha }} .

# Deploy only on main branch
- name: Deploy
  if: github.ref == 'refs/heads/main'
  run: ./deploy.sh

# Different behavior for PR vs push
- name: Set environment
  run: |
    if [ "${{ github.event_name }}" == "pull_request" ]; then
      echo "ENV=preview" >> $GITHUB_ENV
    else
      echo "ENV=production" >> $GITHUB_ENV
    fi
```

### env context

Access environment variables defined in workflow, job, or step.

```yaml
env:
  NODE_VERSION: '20'
  BUILD_TYPE: 'production'

jobs:
  build:
    env:
      API_URL: 'https://api.example.com'
    steps:
      - name: Print variables
        run: |
          echo "Node: ${{ env.NODE_VERSION }}"
          echo "API: ${{ env.API_URL }}"
```

### runner context

Information about the runner executing the job.

**Common Properties:**
```yaml
${{ runner.os }}              # OS (Linux, Windows, macOS)
${{ runner.arch }}            # Architecture (X64, ARM64)
${{ runner.name }}            # Runner name
${{ runner.temp }}            # Temp directory path
${{ runner.tool_cache }}      # Tool cache directory path
```

**Examples:**
```yaml
# OS-specific commands
- name: Install dependencies
  run: |
    if [ "${{ runner.os }}" == "Linux" ]; then
      sudo apt-get update
    elif [ "${{ runner.os }}" == "macOS" ]; then
      brew update
    fi

# Cache key with OS
- uses: actions/cache@v4
  with:
    path: ~/.cache
    key: ${{ runner.os }}-cache-${{ hashFiles('**/lock.file') }}
```

### secrets context

Access encrypted secrets defined in repository or organization settings.

```yaml
- name: Deploy to production
  env:
    API_KEY: ${{ secrets.API_KEY }}
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
  run: ./deploy.sh
```

**Security Notes:**
- Secrets are automatically masked in logs
- Use `echo "::add-mask::$VALUE"` to mask additional values
- Pass secrets via environment variables, not command arguments

### matrix context

Access matrix configuration values when using matrix strategy.

```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20, 22]
    include:
      - os: ubuntu-latest
        node: 20
        experimental: true

steps:
  - name: Setup Node.js ${{ matrix.node }}
    uses: actions/setup-node@v4
    with:
      node-version: ${{ matrix.node }}

  - name: Mark experimental
    if: matrix.experimental
    run: echo "Experimental build"
```

### steps context

Access information about steps that have already run.

```yaml
steps:
  - name: Run tests
    id: tests
    run: npm test

  - name: Upload results
    if: steps.tests.outcome == 'success'
    run: ./upload-results.sh

  - name: Use step output
    run: echo "Test result: ${{ steps.tests.outputs.result }}"
```

**Step Properties:**
- `steps.<step_id>.outputs.<output_name>`: Output value
- `steps.<step_id>.outcome`: Result before `continue-on-error` (`success`, `failure`, `cancelled`, `skipped`)
- `steps.<step_id>.conclusion`: Final result after `continue-on-error`

### job context

Access information about currently running job.

```yaml
jobs:
  build:
    outputs:
      build-id: ${{ steps.build.outputs.id }}
    steps:
      - name: Build
        id: build
        run: echo "id=build-123" >> $GITHUB_OUTPUT

  deploy:
    needs: build
    steps:
      - name: Deploy build
        run: ./deploy.sh ${{ needs.build.outputs.build-id }}
```

### inputs context

Access workflow or reusable workflow inputs.

```yaml
on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        type: choice
        options: [dev, staging, production]
      debug:
        description: 'Enable debug mode'
        required: false
        type: boolean
        default: false

jobs:
  deploy:
    steps:
      - name: Deploy to ${{ inputs.environment }}
        run: ./deploy.sh ${{ inputs.environment }}

      - name: Enable debug
        if: inputs.debug
        run: echo "Debug mode enabled"
```

## Functions

### String Functions

**contains()**
```yaml
# Check if string contains substring
if: contains(github.ref, 'refs/tags/')
if: contains(github.event.head_commit.message, '[skip ci]')
if: contains(fromJSON('["main", "develop"]'), github.ref_name)
```

**startsWith()**
```yaml
# Check if string starts with prefix
if: startsWith(github.ref, 'refs/tags/v')
if: startsWith(github.event.pull_request.title, 'feat:')
```

**endsWith()**
```yaml
# Check if string ends with suffix
if: endsWith(github.ref, '/main')
if: endsWith(github.event.pull_request.head.ref, '-hotfix')
```

**format()**
```yaml
# Format string with placeholders
- name: Print message
  run: echo "${{ format('Building {0} on {1}', github.ref_name, runner.os) }}"
```

### Type Conversion Functions

**toJSON()**
```yaml
# Convert object to JSON string
- name: Print context
  run: echo '${{ toJSON(github) }}'

- name: Print matrix
  run: echo '${{ toJSON(matrix) }}'
```

**fromJSON()**
```yaml
# Parse JSON string to object
strategy:
  matrix:
    config: ${{ fromJSON('{"versions":[18,20,22]}') }}

# Use with dynamic matrix
jobs:
  setup:
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - id: set-matrix
        run: echo 'matrix={"version":["18","20"]}' >> $GITHUB_OUTPUT

  build:
    needs: setup
    strategy:
      matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
```

### Hash Functions

**hashFiles()**
```yaml
# Generate hash of file contents (for cache keys)
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}

# Multiple patterns
key: ${{ hashFiles('**/*.go', '**/go.sum') }}
```

### Status Check Functions

**success()**
```yaml
# Run only if all previous steps succeeded
- name: Deploy
  if: success()
  run: ./deploy.sh
```

**failure()**
```yaml
# Run only if any previous step failed
- name: Notify on failure
  if: failure()
  run: ./notify-failure.sh
```

**always()**
```yaml
# Run regardless of previous step status
- name: Cleanup
  if: always()
  run: ./cleanup.sh
```

**cancelled()**
```yaml
# Run if workflow was cancelled
- name: Cleanup on cancel
  if: cancelled()
  run: ./cancel-cleanup.sh
```

## Operators

### Comparison Operators

```yaml
# Equality
if: github.ref == 'refs/heads/main'
if: runner.os != 'Windows'

# Logical
if: github.event_name == 'push' && github.ref == 'refs/heads/main'
if: github.event_name == 'pull_request' || github.event_name == 'push'
if: "!(github.event_name == 'pull_request')"

# Comparison
if: github.event.pull_request.changed_files < 10
if: matrix.node-version >= 20
```

### Operator Precedence

1. `()`
2. `!`
3. `<`, `<=`, `>`, `>=`
4. `==`, `!=`
5. `&&`
6. `||`

## Common Patterns

### Branch-Based Conditions

```yaml
# Main branch only
if: github.ref == 'refs/heads/main'

# Any branch except main
if: github.ref != 'refs/heads/main'

# Specific branches
if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'

# Tag pushes only
if: startsWith(github.ref, 'refs/tags/')

# Version tags only (v1.0.0 format)
if: startsWith(github.ref, 'refs/tags/v')
```

### Event-Based Conditions

```yaml
# Push event only
if: github.event_name == 'push'

# PR opened or synchronized
if: |
  github.event_name == 'pull_request' &&
  (github.event.action == 'opened' || github.event.action == 'synchronize')

# Manual dispatch only
if: github.event_name == 'workflow_dispatch'

# Scheduled run only
if: github.event_name == 'schedule'
```

### Step Status Patterns

```yaml
# Run if specific step succeeded
if: steps.tests.outcome == 'success'

# Run if step failed but continue
if: steps.tests.outcome == 'failure'

# Run cleanup always
if: always()

# Run only on failure
if: failure()
```

### Matrix Patterns

```yaml
# Specific matrix combination
if: matrix.os == 'ubuntu-latest' && matrix.node == 20

# Exclude certain combinations
strategy:
  matrix:
    os: [ubuntu, windows, macos]
    node: [18, 20, 22]
    exclude:
      - os: windows
        node: 18
```

### Dynamic Values

```yaml
# Build tags with multiple values
tags: |
  myapp:latest
  myapp:${{ github.sha }}
  myapp:${{ github.ref_name }}

# Conditional environment
environment: ${{ github.ref == 'refs/heads/main' && 'production' || 'staging' }}

# Dynamic timeout
timeout-minutes: ${{ github.event_name == 'schedule' && 120 || 30 }}
```

### Combining Contexts

```yaml
# Artifact name with context values
- uses: actions/upload-artifact@v4
  with:
    name: build-${{ runner.os }}-${{ github.sha }}
    path: dist/

# Cache key with multiple factors
- uses: actions/cache@v4
  with:
    path: ~/.cache
    key: ${{ runner.os }}-${{ hashFiles('**/*.lock') }}-${{ github.ref_name }}
```

### Safe String Interpolation

```yaml
# ❌ UNSAFE: Direct interpolation of user input
- run: echo "Title: ${{ github.event.pull_request.title }}"

# ✅ SAFE: Use environment variables
- name: Print PR title
  env:
    PR_TITLE: ${{ github.event.pull_request.title }}
  run: echo "Title: $PR_TITLE"
```

### JSON Manipulation

```yaml
# Create dynamic matrix
- id: set-matrix
  run: |
    if [ "${{ github.event_name }}" == "push" ]; then
      echo 'matrix={"os":["ubuntu","windows","macos"]}' >> $GITHUB_OUTPUT
    else
      echo 'matrix={"os":["ubuntu"]}' >> $GITHUB_OUTPUT
    fi

# Use matrix
strategy:
  matrix: ${{ fromJSON(steps.set-matrix.outputs.matrix) }}
```

## Debugging and Troubleshooting

### Dumping Contexts to Logs

The most effective way to debug workflow issues is to dump context information to logs:

**Dump All Contexts:**
```yaml
name: Context Debugging
on: push

jobs:
  dump_contexts:
    runs-on: ubuntu-latest
    steps:
      - name: Dump GitHub context
        env:
          GITHUB_CONTEXT: ${{ toJson(github) }}
        run: echo "$GITHUB_CONTEXT"

      - name: Dump job context
        env:
          JOB_CONTEXT: ${{ toJson(job) }}
        run: echo "$JOB_CONTEXT"

      - name: Dump steps context
        env:
          STEPS_CONTEXT: ${{ toJson(steps) }}
        run: echo "$STEPS_CONTEXT"

      - name: Dump runner context
        env:
          RUNNER_CONTEXT: ${{ toJson(runner) }}
        run: echo "$RUNNER_CONTEXT"

      - name: Dump strategy context
        env:
          STRATEGY_CONTEXT: ${{ toJson(strategy) }}
        run: echo "$STRATEGY_CONTEXT"

      - name: Dump matrix context
        env:
          MATRIX_CONTEXT: ${{ toJson(matrix) }}
        run: echo "$MATRIX_CONTEXT"
```

**Example Runner Context Output:**
```json
{
  "os": "Linux",
  "arch": "X64",
  "name": "GitHub Actions 2",
  "tool_cache": "/opt/hostedtoolcache",
  "temp": "/home/runner/work/_temp"
}
```

### Safe Variable Interpolation

**Best Practice - Use env context:**
```yaml
# ✅ SAFE: Interpolate before runner execution
- name: Greet user
  env:
    GREETING: ${{ env.Greeting }}
    FIRST_NAME: ${{ env.First_Name }}
    DAY: ${{ env.DAY_OF_WEEK }}
  run: echo "$GREETING $FIRST_NAME. Today is $DAY!"
```

This approach ensures variables are resolved by GitHub Actions before execution, providing consistent behavior.

## Tips and Best Practices

1. **Implicit vs Explicit `${{ }}`:**
   - `if` conditions don't need `${{ }}` (implicit)
   - Other contexts require explicit `${{ }}`

2. **String Comparisons:**
   - Always use quotes for string literals
   - Case-sensitive by default

3. **Boolean Values:**
   - Use `true` and `false` without quotes
   - Empty strings evaluate to `false`

4. **Default Values:**
   ```yaml
   # Use || for default values
   environment: ${{ inputs.environment || 'dev' }}
   ```

5. **Multi-line Expressions:**
   ```yaml
   if: |
     github.event_name == 'push' &&
     github.ref == 'refs/heads/main' &&
     !contains(github.event.head_commit.message, '[skip ci]')
   ```

6. **Security Best Practices:**
   - Always use `env` context for untrusted input
   - Never directly interpolate user-controlled values
   - Use `::add-mask::` for sensitive values

7. **Dynamic Environment Names:**
   ```yaml
   environment:
     name: ${{ github.ref_name }}  # Dynamic based on branch
   ```

8. **Debugging Expressions:**
   ```yaml
   # Print entire context with pretty formatting
   - run: echo '${{ toJson(github) }}'

   # Print specific values
   - run: |
       echo "Event: ${{ github.event_name }}"
       echo "Ref: ${{ github.ref }}"
       echo "SHA: ${{ github.sha }}"
       echo "Actor: ${{ github.actor }}"
   ```

## Summary

- Use `${{ }}` for dynamic values
- Access contexts like `github`, `env`, `secrets`, `matrix`, `runner`, etc.
- Use functions for string manipulation, hashing, and type conversion (`toJSON`, `hashFiles`, `contains`, etc.)
- Combine operators for complex conditions
- **Always validate and sanitize user inputs for security**
- Use `env` context for untrusted input instead of direct interpolation
- Debug with `toJSON()` to dump context information
- Expressions are evaluated before job execution on the runner

**Security Warning:** Never directly interpolate untrusted input (PR titles, issue bodies, user input) in `run` commands. Always use environment variables via the `env` context.
