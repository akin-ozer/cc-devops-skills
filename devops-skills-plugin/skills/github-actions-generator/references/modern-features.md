# Modern GitHub Actions Features

**Last Updated:** December 2025

This guide covers modern GitHub Actions capabilities for enhanced workflow output, deployment control, and containerized builds.

## Table of Contents
1. [Job Summaries](#job-summaries)
2. [Deployment Environments](#deployment-environments)
3. [Container Jobs](#container-jobs)
4. [Workflow Annotations](#workflow-annotations)
5. [Integration Examples](#integration-examples)

---

## Job Summaries

Create rich markdown summaries in the Actions UI using `$GITHUB_STEP_SUMMARY`.

### When to Use
- Display test results, coverage reports, benchmarks
- Show deployment status and URLs
- Present security scan findings
- Summarize workflow execution

### Basic Usage

```yaml
- name: Generate summary
  run: |
    echo "## Build Results :rocket:" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Metric | Value |" >> $GITHUB_STEP_SUMMARY
    echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
    echo "| Tests | ${{ steps.test.outputs.passed }} passed |" >> $GITHUB_STEP_SUMMARY
    echo "| Coverage | ${{ steps.test.outputs.coverage }}% |" >> $GITHUB_STEP_SUMMARY
```

### Advanced Patterns

**Test Results Table:**
```yaml
- name: Test summary
  if: always()
  run: |
    echo "## Test Results :test_tube:" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Suite | Status | Duration |" >> $GITHUB_STEP_SUMMARY
    echo "|-------|--------|----------|" >> $GITHUB_STEP_SUMMARY
    echo "| Unit Tests | :white_check_mark: | 45s |" >> $GITHUB_STEP_SUMMARY
    echo "| Integration | :white_check_mark: | 2m 30s |" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "### Deployment URLs" >> $GITHUB_STEP_SUMMARY
    echo "- [Staging](https://staging.example.com)" >> $GITHUB_STEP_SUMMARY
    echo "- [Production](https://example.com)" >> $GITHUB_STEP_SUMMARY
```

**Collapsible Details:**
```yaml
- name: Detailed summary
  run: |
    echo "## Summary" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "<details>" >> $GITHUB_STEP_SUMMARY
    echo "<summary>Click to expand test details</summary>" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo '```' >> $GITHUB_STEP_SUMMARY
    cat test-output.txt >> $GITHUB_STEP_SUMMARY
    echo '```' >> $GITHUB_STEP_SUMMARY
    echo "</details>" >> $GITHUB_STEP_SUMMARY
```

### Best Practices
- Use `if: always()` to show summaries even on failure
- Include emojis for visual scanning
- Use markdown tables for structured data
- Add links to deployed environments
- Clear summary at start if needed: `> $GITHUB_STEP_SUMMARY`

---

## Deployment Environments

Use GitHub environments with protection rules, approval gates, and environment-specific secrets.

### When to Use
- Multi-stage deployments (dev, staging, production)
- Deployments requiring manual approval
- Environment-specific configuration
- Deployment tracking and rollback

### Basic Usage

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - name: Deploy
        run: ./deploy.sh staging

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com
    steps:
      - name: Deploy
        run: ./deploy.sh production
```

### Protection Rules

Configure in repository Settings → Environments:

| Rule | Description |
|------|-------------|
| Required reviewers | Manual approval before deployment |
| Wait timer | Delay deployment by N minutes |
| Deployment branches | Restrict which branches can deploy |
| Environment secrets | Secrets available only in this environment |

### Multi-Environment Pattern

```yaml
name: Deploy

on:
  push:
    branches: [main, develop]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: ${{ github.ref_name == 'main' && 'production' || 'staging' }}
      url: ${{ github.ref_name == 'main' && 'https://example.com' || 'https://staging.example.com' }}
    steps:
      - uses: actions/checkout@v5
      - name: Deploy to ${{ github.ref_name == 'main' && 'production' || 'staging' }}
        env:
          API_KEY: ${{ secrets.API_KEY }}  # Environment-specific secret
        run: ./deploy.sh
```

### Best Practices
- Set environment URLs for easy access
- Use required reviewers for production
- Configure branch policies
- Leverage environment-specific secrets
- Use `needs` to enforce deployment order

---

## Container Jobs

Run jobs inside Docker containers for consistent, isolated build environments.

### When to Use
- Require specific OS/tool versions
- Need isolated build environment
- Want to match local dev environment
- Building for specific Linux distributions

### Basic Container Job

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: node:20-alpine
      env:
        NODE_ENV: production
      options: --cpus 2 --memory 4g
    steps:
      - uses: actions/checkout@v5
      - run: npm ci
      - run: npm run build
```

### With Service Containers

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:20

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v5
      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:postgres@postgres:5432/test
          REDIS_URL: redis://redis:6379
        run: npm test
```

### Best Practices
- Use specific image tags (avoid `latest`)
- Configure health checks for services
- Set resource limits with `options`
- Use volumes for persistent data
- Prefer official images

---

## Workflow Annotations

Create annotations (notices, warnings, errors) in the Actions UI and PR files.

### Annotation Commands

| Command | Level | Appearance |
|---------|-------|------------|
| `::notice::` | Info | Blue |
| `::warning::` | Warning | Yellow |
| `::error::` | Error | Red (doesn't fail step) |

### Basic Usage

```yaml
- name: Validate
  run: |
    # Simple annotations
    echo "::notice::Build completed successfully"
    echo "::warning::Deprecated API usage detected"
    echo "::error::Configuration issue found"
```

### File/Line Annotations

Annotations with file location appear in PR Files tab:

```yaml
- name: Lint results
  run: |
    # With file and line info
    echo "::error file=src/app.js,line=10,col=5::Type mismatch detected"
    echo "::warning file=config.js,line=23::Deprecated option used"
    echo "::notice file=utils.js,line=100,endLine=105::Consider refactoring"
```

### Log Groups

Collapse verbose output:

```yaml
- name: Build with groups
  run: |
    echo "::group::Installing dependencies"
    npm ci
    echo "::endgroup::"

    echo "::group::Running tests"
    npm test
    echo "::endgroup::"
```

### Masking Secrets

```yaml
- name: Process secret
  run: |
    SENSITIVE="$(./get-secret.sh)"
    echo "::add-mask::$SENSITIVE"
    echo "Using secret safely"
```

### All Workflow Commands

| Command | Purpose |
|---------|---------|
| `::notice::` | Info annotation |
| `::warning::` | Warning annotation |
| `::error::` | Error annotation |
| `::group::` | Start collapsed section |
| `::endgroup::` | End collapsed section |
| `::add-mask::` | Mask value in logs |
| `::stop-commands::TOKEN` | Disable command processing |
| `::TOKEN::` | Re-enable commands |
| `::debug::` | Debug message (requires debug logging) |

---

## Integration Examples

### Complete CI/CD with Modern Features

```yaml
name: Full-Featured CI/CD

on:
  push:
    branches: [main, develop]
  pull_request:

permissions:
  contents: read
  deployments: write

jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:20-alpine

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres

    steps:
      - uses: actions/checkout@v5

      - name: Run tests
        id: test
        env:
          DATABASE_URL: postgres://postgres:postgres@postgres:5432/test
        run: |
          npm ci
          npm test -- --coverage
          echo "coverage=85" >> $GITHUB_OUTPUT

      - name: Coverage check
        run: |
          COVERAGE=${{ steps.test.outputs.coverage }}
          if [ $COVERAGE -lt 80 ]; then
            echo "::warning::Coverage $COVERAGE% below 80% threshold"
          else
            echo "::notice::Coverage $COVERAGE% meets threshold"
          fi

      - name: Test summary
        if: always()
        run: |
          echo "## Test Results :test_tube:" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Metric | Value |" >> $GITHUB_STEP_SUMMARY
          echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
          echo "| Coverage | ${{ steps.test.outputs.coverage }}% |" >> $GITHUB_STEP_SUMMARY
          echo "| Status | :white_check_mark: Passed |" >> $GITHUB_STEP_SUMMARY

  deploy-staging:
    needs: test
    if: github.ref == 'refs/heads/develop'
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - uses: actions/checkout@v5

      - name: Deploy
        run: ./deploy.sh staging

      - name: Deployment summary
        run: |
          echo "## Deployment :rocket:" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: Staging" >> $GITHUB_STEP_SUMMARY
          echo "- **URL**: https://staging.example.com" >> $GITHUB_STEP_SUMMARY
          echo "- **Commit**: ${{ github.sha }}" >> $GITHUB_STEP_SUMMARY

  deploy-production:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    steps:
      - uses: actions/checkout@v5

      - name: Deploy
        run: ./deploy.sh production

      - name: Deployment summary
        run: |
          echo "## Production Deployment :rocket:" >> $GITHUB_STEP_SUMMARY
          echo "- **Environment**: Production" >> $GITHUB_STEP_SUMMARY
          echo "- **URL**: https://example.com" >> $GITHUB_STEP_SUMMARY
          echo "- **Note**: Required manual approval" >> $GITHUB_STEP_SUMMARY
```

---

## Summary

| Feature | Use Case | Key Benefits |
|---------|----------|--------------|
| Job Summaries | Rich output display | Markdown support, persists in UI |
| Environments | Deployment control | Approvals, secrets, tracking |
| Container Jobs | Consistent builds | Isolation, reproducibility |
| Annotations | Inline feedback | PR integration, visual alerts |