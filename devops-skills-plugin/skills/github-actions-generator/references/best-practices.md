# GitHub Actions Best Practices

**Last Updated:** November 2025
**Based on:** Official GitHub Actions documentation and Context7 verified sources

## Table of Contents
1. [Security Best Practices](#security-best-practices)
2. [Performance Optimization](#performance-optimization)
3. [Workflow Design](#workflow-design)
4. [Action Selection and Versioning](#action-selection-and-versioning)
5. [Error Handling](#error-handling)
6. [Maintainability](#maintainability)
7. [Common Patterns](#common-patterns)
8. [Anti-Patterns to Avoid](#anti-patterns-to-avoid)

## Security Best Practices

### 1. Pin Actions to Full SHA (Critical Security Practice)

**Best Practice:**
```yaml
# ✅ BEST: Pinned to specific full SHA (40 characters) with version comment
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
```

**Why:**
- Immutable: SHA cannot be changed, preventing supply chain attacks
- Reproducible: Same code runs every time
- Verifiable: Can audit exact code being executed

**Acceptable Alternative:**
```yaml
# ✅ ACCEPTABLE: Major version tag (for official GitHub actions)
- uses: actions/checkout@v4
```

**Avoid:**
```yaml
# ❌ BAD: Mutable references
- uses: actions/checkout@main
- uses: actions/checkout@master
- uses: actions/checkout@latest
```

### 2. Minimal Permissions

**Best Practice:**
```yaml
# Top-level: Set default to read-only
permissions:
  contents: read

jobs:
  build:
    # Job-level: Grant only necessary permissions
    permissions:
      contents: read
      packages: write
      pull-requests: write
```

**Common Permission Scopes:**
- `contents`: Repository contents (read/write)
- `packages`: GitHub Packages (read/write)
- `pull-requests`: PR comments and labels (read/write)
- `issues`: Issue management (read/write)
- `statuses`: Commit statuses (write)
- `checks`: Check runs (write)
- `deployments`: Deployment status (write)

### 3. Secrets Management

**Best Practice:**
```yaml
# ✅ GOOD: Use secrets properly
- name: Deploy to production
  env:
    API_KEY: ${{ secrets.API_KEY }}
  run: |
    echo "::add-mask::$API_KEY"
    ./deploy.sh

# ✅ GOOD: Pass secrets to actions
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

**Avoid:**
```yaml
# ❌ BAD: Exposing secrets
- run: echo "API_KEY=${{ secrets.API_KEY }}"

# ❌ BAD: Using secrets in URLs
- run: git clone https://${{ secrets.GITHUB_TOKEN }}@github.com/user/repo.git
```

### 4. Input Validation and Injection Prevention

**Critical Security Issue:** Script injection through untrusted input is one of the most common security vulnerabilities in GitHub Actions.

**Best Practice - Use Environment Variables:**
```yaml
# ✅ BEST: Always use environment variables for untrusted input (Bash)
- name: Check PR title
  env:
    TITLE: ${{ github.event.pull_request.title }}
  run: |
    if [[ "$TITLE" =~ ^octocat ]]; then
      echo "PR title starts with 'octocat'"
      exit 0
    else
      echo "PR title did not start with 'octocat'"
      exit 1
    fi

# ✅ BEST: Validate inputs with strict patterns
- name: Build image
  env:
    IMAGE_NAME: ${{ github.event.inputs.image-name }}
  run: |
    if [[ ! "$IMAGE_NAME" =~ ^[a-z0-9-]+$ ]]; then
      echo "::error::Invalid image name"
      exit 1
    fi
    docker build -t "$IMAGE_NAME" .
```

**Alternative - Use JavaScript Action:**
```yaml
# ✅ GOOD: Create a JavaScript action to process context values
- uses: fakeaction/checktitle@v3
  with:
    title: ${{ github.event.pull_request.title }}
```

**Avoid:**
```yaml
# ❌ BAD: Direct interpolation of user input (vulnerable to injection)
- run: echo "PR: ${{ github.event.pull_request.title }}"
- run: docker build -t ${{ github.event.inputs.tag }} .
- run: echo "${{ github.event.pull_request.title }}" | grep "fix"
```

### 5. Dependency Review and SBOM Attestations (New in 2025)

**Dependency Review Action:**
```yaml
name: Dependency Review
on:
  pull_request:
    paths-ignore:
      - "README.md"

permissions:
  contents: read

jobs:
  dependency-review:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v5

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          # Fail on critical vulnerabilities
          fail-on-severity: critical
          # Allow specific dependencies
          allow-licenses: MIT, Apache-2.0, BSD-3-Clause
```

**SBOM Attestations for Container Images:**
```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
  packages: write

steps:
  - name: Build container image
    run: docker build -t ${{ env.REGISTRY }}/myapp:${{ github.sha }} .

  - name: Generate SBOM
    uses: anchore/sbom-action@v0
    with:
      image: ${{ env.REGISTRY }}/myapp:${{ github.sha }}
      format: spdx-json
      output-file: sbom.json

  - name: Generate SBOM attestation
    uses: actions/attest-sbom@v2
    with:
      subject-name: ${{ env.REGISTRY }}/myapp
      subject-digest: sha256:${{ steps.build.outputs.digest }}
      sbom-path: sbom.json
      push-to-registry: true
```

## Performance Optimization

### 1. Dependency Caching (Updated November 2025)

**Important:** As of February 2025, actions/cache v4.2.0+ is required (v4.3.0 latest). The cache service was rewritten for improved performance. Legacy cache service was sunset on February 1, 2025.

**Cache Size Limits (New):** As of November 2025, repositories can exceed the previous 10 GB cache limit using a pay-as-you-go model. All repositories receive 10 GB free, with additional storage available.

**NPM/Node.js with Built-in Caching:**
```yaml
- uses: actions/setup-node@v6
  with:
    node-version: '24'
    cache: 'npm'
    cache-dependency-path: '**/package-lock.json'
```

**Manual Caching with actions/cache@v4:**
```yaml
- name: Cache node modules
  id: cache-npm
  uses: actions/cache@v4
  env:
    cache-name: cache-node-modules
  with:
    path: ~/.npm
    key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-build-${{ env.cache-name }}-
      ${{ runner.os }}-build-
      ${{ runner.os }}-

- name: Check cache hit
  if: ${{ steps.cache-npm.outputs.cache-hit != 'true' }}
  run: echo "Cache miss - installing dependencies"

- name: Install dependencies
  run: npm ci
```

**Maven with Built-in Caching:**
```yaml
- uses: actions/setup-java@v4
  with:
    java-version: '17'
    distribution: 'temurin'
    cache: 'maven'
```

**Ruby Gems with Matrix Strategy:**
```yaml
- uses: actions/cache@v4
  with:
    path: vendor/bundle
    key: bundle-${{ matrix.os }}-${{ matrix.ruby-version }}-${{ hashFiles('**/Gemfile.lock') }}
    restore-keys: |
      bundle-${{ matrix.os }}-${{ matrix.ruby-version }}-
```

**.NET Dependencies:**
```yaml
- uses: actions/setup-dotnet@v4
  with:
    dotnet-version: '8.x'
    cache: true  # Caches NuGet global-packages folder
```

### 2. Concurrency Control

**Best Practice:**
```yaml
# Cancel in-progress runs when new commit pushed
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

**Per-PR Concurrency:**
```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

### 3. Shallow Checkout

**Best Practice:**
```yaml
# ✅ GOOD: Shallow clone when full history not needed
- uses: actions/checkout@v4
  with:
    fetch-depth: 1

# ✅ GOOD: Fetch specific depth for changelog generation
- uses: actions/checkout@v4
  with:
    fetch-depth: 50
```

### 4. Matrix Strategy Optimization

**Best Practice:**
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
    node: [18, 20, 22]
    exclude:
      # Exclude expensive combinations
      - os: macos-latest
        node: 18
  fail-fast: false  # Continue other jobs even if one fails
  max-parallel: 3   # Limit concurrent jobs
```

## Workflow Design

### 1. Job Dependencies

**Best Practice:**
```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint

  test:
    runs-on: ubuntu-latest
    steps:
      - run: npm test

  build:
    needs: [lint, test]  # Wait for both
    runs-on: ubuntu-latest
    steps:
      - run: npm run build

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - run: ./deploy.sh
```

### 2. Conditional Execution

**Best Practice:**
```yaml
# Job-level condition
jobs:
  deploy:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

# Step-level condition
steps:
  - name: Deploy to staging
    if: github.ref == 'refs/heads/develop'
    run: ./deploy-staging.sh

  - name: Notify on failure
    if: failure()
    run: ./notify.sh
```

**Common Conditions:**
- `success()`: Previous steps succeeded
- `failure()`: Any previous step failed
- `always()`: Run regardless of status
- `cancelled()`: Workflow was cancelled

### 3. Reusable Workflows

**Caller Workflow:**
```yaml
# .github/workflows/ci.yml
jobs:
  call-workflow:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: production
    secrets:
      token: ${{ secrets.DEPLOY_TOKEN }}
```

**Reusable Workflow:**
```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      node-version:
        required: false
        type: string
        default: '20'
    secrets:
      token:
        required: true
    outputs:
      build-id:
        description: "Build identifier"
        value: ${{ jobs.build.outputs.id }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      id: ${{ steps.build.outputs.id }}
    steps:
      - name: Build
        id: build
        run: echo "id=build-${{ github.sha }}" >> $GITHUB_OUTPUT
```

## Action Selection and Versioning

### 1. Prefer Official GitHub Actions

**Priority Order:**
1. Official GitHub actions (`actions/*`)
2. Official organization actions (`docker/*`, `aws-actions/*`)
3. Verified creators
4. Community actions (with careful review)

### 2. Version Pinning Strategy

**Recommended Approach:**
```yaml
# Format: @<SHA> # <version-tag>
- uses: actions/checkout@b4ffde65f46336ab88eb53be808477a3936bae11 # v4.1.1
```

**Finding SHAs:**
```bash
# Get SHA for specific tag
git ls-remote https://github.com/actions/checkout v4.1.1
```

### 3. Regular Updates

**Process:**
1. Monitor action releases and security advisories
2. Update SHAs with new versions
3. Test in PR before merging
4. Document version changes in commit message

**Automated Updates:**
Use Dependabot for automatic action updates:
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
```

## Error Handling

### 1. Timeouts

**Best Practice:**
```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Prevent hung jobs
    steps:
      - name: Run tests
        timeout-minutes: 15  # Step-level timeout
        run: npm test
```

### 2. Failure Handling

**Best Practice:**
```yaml
jobs:
  test:
    steps:
      - name: Run tests
        id: tests
        continue-on-error: true
        run: npm test

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: test-results/

      - name: Check test results
        if: steps.tests.outcome == 'failure'
        run: exit 1
```

### 3. Cleanup Steps

**Best Practice:**
```yaml
steps:
  - name: Start test environment
    run: docker-compose up -d

  - name: Run tests
    run: npm test

  - name: Cleanup
    if: always()
    run: docker-compose down
```

## Maintainability

### 1. Naming Conventions

**Best Practice:**
```yaml
# Workflow file: lowercase with hyphens
# File: .github/workflows/ci-pipeline.yml

name: CI Pipeline  # Descriptive workflow name

jobs:
  test-node:  # Descriptive job ID
    name: Test on Node ${{ matrix.version }}  # Human-readable job name
    steps:
      - name: Install dependencies  # Action-oriented step name
        run: npm ci
```

### 2. Documentation

**Best Practice:**
```yaml
# CI Pipeline
#
# This workflow runs on every push and pull request to validate code quality.
# It performs linting, testing, and builds the application.
#
# Required secrets:
#   - CODECOV_TOKEN: For uploading coverage reports
#
# Required permissions:
#   - contents: read
#   - checks: write

name: CI Pipeline
```

### 3. Environment Variables

**Best Practice:**
```yaml
# Top-level environment variables
env:
  NODE_VERSION: '20'
  CACHE_VERSION: 'v1'

jobs:
  build:
    env:
      BUILD_ENV: production
    steps:
      - name: Build
        env:
          API_URL: ${{ secrets.API_URL }}
        run: npm run build
```

## Common Patterns

### 1. Multi-Environment Deployment

```yaml
jobs:
  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Deploy to staging
        run: ./deploy.sh staging

  deploy-production:
    if: github.ref == 'refs/heads/main'
    environment:
      name: production
      url: https://example.com
    steps:
      - name: Deploy to production
        run: ./deploy.sh production
```

### 2. Manual Approval

```yaml
jobs:
  deploy:
    environment:
      name: production
      # Requires manual approval from configured reviewers
    steps:
      - name: Deploy
        run: ./deploy.sh
```

### 3. Artifact Sharing Between Jobs

```yaml
jobs:
  build:
    steps:
      - name: Build application
        run: npm run build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/
          retention-days: 7

  test:
    needs: build
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: dist/

      - name: Test build
        run: npm run test:integration
```

### 4. Dynamic Matrix from JSON

```yaml
jobs:
  setup:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - name: Set matrix
        id: set-matrix
        run: |
          echo 'matrix={"version":["18","20","22"]}' >> $GITHUB_OUTPUT

  test:
    needs: setup
    strategy:
      matrix: ${{ fromJSON(needs.setup.outputs.matrix) }}
```

## Anti-Patterns to Avoid

### 1. Storing Secrets in Code

```yaml
# ❌ NEVER DO THIS
env:
  API_KEY: "hardcoded-secret-123"
  PASSWORD: ${{ github.event.inputs.password }}
```

### 2. Using Deprecated Actions

```yaml
# ❌ BAD: Deprecated actions
- uses: actions/setup-node@v1  # Use v6 instead (Node 24 runtime)
- uses: actions/cache@v1       # Use v4.3.0+ instead (v4.2.0+ required as of Feb 2025)
```

### 3. Overly Broad Permissions

```yaml
# ❌ BAD: Unnecessary permissions
permissions: write-all

# ✅ GOOD: Minimal permissions
permissions:
  contents: read
  pull-requests: write
```

### 4. Long-Running Jobs Without Timeout

```yaml
# ❌ BAD: No timeout
jobs:
  build:
    runs-on: ubuntu-latest
    # Could run forever, consuming minutes

# ✅ GOOD: With timeout
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
```

### 5. Hardcoded Values

```yaml
# ❌ BAD: Hardcoded
- name: Deploy
  run: kubectl set image deployment/myapp myapp=myapp:1.0.0

# ✅ GOOD: Using variables
- name: Deploy
  env:
    IMAGE_TAG: ${{ github.sha }}
  run: kubectl set image deployment/myapp myapp=myapp:$IMAGE_TAG
```

### 6. Unnecessary Checkouts

```yaml
# ❌ BAD: Checkout when not needed
jobs:
  notify:
    steps:
      - uses: actions/checkout@v4  # Not needed for notification
      - run: ./notify.sh

# ✅ GOOD: Only checkout when needed
jobs:
  notify:
    steps:
      - run: curl -X POST ${{ secrets.WEBHOOK_URL }}
```

## Summary

**Key Takeaways:**
1. Security first: Pin actions, use minimal permissions, protect secrets
2. Optimize performance: Cache dependencies, use concurrency controls
3. Design for maintainability: Clear naming, documentation, reusable components
4. Handle errors gracefully: Timeouts, cleanup, notifications
5. Follow conventions: Standard naming, proper versioning, community practices

Always validate workflows with the github-actions-validator skill before deploying.
