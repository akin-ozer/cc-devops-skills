# Modern GitHub Actions Features Reference

This reference covers validation of modern GitHub Actions features including reusable workflows, attestations, OIDC authentication, and more.

## Reusable Workflows

### Validation Points
- `workflow_call` trigger configuration
- Required and optional inputs with correct types
- Secrets declaration and usage
- Outputs definition

### Example

```yaml
# Reusable workflow (.github/workflows/reusable-deploy.yml)
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      deploy-version:
        required: false
        type: string
        default: 'latest'
    secrets:
      deploy-token:
        required: true
    outputs:
      deployment-url:
        description: "The URL of the deployment"
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - name: Deploy
        id: deploy
        run: echo "url=https://example.com" >> $GITHUB_OUTPUT
```

### Common Errors
- Incorrect input types (string, number, boolean)
- Missing required secrets
- Invalid output references

### Workflow Limits (November 2025)

GitHub Actions increased reusable workflow limits:
- **Nested workflows**: Up to 10 levels (previously 4)
- **Total workflows per run**: Up to 50 workflows (previously 20)

This enables complex workflow compositions and better code reuse.

---

## SBOM and Build Provenance Attestations

### Validation Points
- Correct permissions (`id-token: write`, `attestations: write`)
- Valid artifact paths
- Proper attestation action usage

### Example

```yaml
permissions:
  id-token: write
  contents: read
  attestations: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Build artifact
        run: |
          mkdir -p dist
          tar -czvf dist/app.tar.gz ./src

      - name: Generate SBOM
        run: |
          # Generate SPDX SBOM
          syft ./src -o spdx-json > sbom.spdx.json

      - uses: actions/attest-sbom@v3
        with:
          subject-path: '${{ github.workspace }}/dist/*.tar.gz'
          sbom-path: '${{ github.workspace }}/sbom.spdx.json'

      - uses: actions/attest-build-provenance@v3
        with:
          subject-path: '${{ github.workspace }}/dist/*.tar.gz'
```

### Common Errors
- Missing required permissions
- Invalid subject-path glob patterns
- Incorrect SBOM format

---

## OIDC Authentication

### Validation Points
- Correct permissions (`id-token: write`)
- Valid audience claims
- Proper OIDC provider configuration
- Token claim validation in receiving systems

### Available Token Claims (November 2025)

| Claim | Description |
|-------|-------------|
| `repository` | Repository name |
| `ref` | Git ref (branch/tag) |
| `sha` | Commit SHA |
| `workflow` | Workflow name |
| `run_id` | Workflow run ID |
| `run_attempt` | Attempt number |
| `check_run_id` | **NEW** - Specific check run ID for the job |
| `actor` | User who triggered the workflow |
| `environment` | Deployment environment (if applicable) |

### Example: AWS OIDC

```yaml
permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
          aws-region: us-east-1
          # Token now includes check_run_id for granular tracking

      - name: Deploy to AWS
        run: aws s3 sync ./build s3://my-bucket/
```

### AWS IAM Policy with check_run_id

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:sub": "repo:org/repo:ref:refs/heads/main",
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:check_run_id": "*"
      }
    }
  }]
}
```

### Benefits of check_run_id
- **Fine-grained access control**: Trace tokens to exact job and compute
- **Improved auditability**: Track which specific check run made API calls
- **Least-privilege policies**: Attribute-based access control without enumerating repositories
- **Faster revocation**: Reduce secret exposure risk

---

## Deployment Environments

### Validation Points
- Environment name configuration
- Protection rules compatibility
- Required reviewers setup
- Environment variables and secrets scope

### Example

```yaml
jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com
    steps:
      - uses: actions/checkout@v6
      - run: ./deploy.sh staging

  deploy-production:
    runs-on: ubuntu-latest
    needs: deploy-staging
    environment:
      name: production
      url: https://prod.example.com
    steps:
      - uses: actions/checkout@v6
      - run: ./deploy.sh production
```

### Common Errors
- Undefined environment names
- Missing URL for environment tracking
- Incorrect environment variable scope

---

## Job Summaries

### Validation Points
- Correct usage of `$GITHUB_STEP_SUMMARY`
- Valid Markdown formatting
- Proper escaping of dynamic content

### Example

```yaml
steps:
  - name: Run tests
    id: tests
    run: |
      # Run tests and capture results
      npm test 2>&1 | tee test-output.txt
      PASSED=$(grep -c "PASS" test-output.txt || echo 0)
      FAILED=$(grep -c "FAIL" test-output.txt || echo 0)
      echo "passed=$PASSED" >> $GITHUB_OUTPUT
      echo "failed=$FAILED" >> $GITHUB_OUTPUT

  - name: Generate summary
    run: |
      echo "## Test Results" >> $GITHUB_STEP_SUMMARY
      echo "" >> $GITHUB_STEP_SUMMARY
      echo "| Status | Count |" >> $GITHUB_STEP_SUMMARY
      echo "|--------|-------|" >> $GITHUB_STEP_SUMMARY
      echo "| Passed | ${{ steps.tests.outputs.passed }} |" >> $GITHUB_STEP_SUMMARY
      echo "| Failed | ${{ steps.tests.outputs.failed }} |" >> $GITHUB_STEP_SUMMARY
```

**Note:** Job summaries are runtime features - actionlint validates script syntax but not summary content.

---

## Container Jobs

### Validation Points
- Valid container image references
- Correct volume mounts
- Environment variable configuration
- Service container networking

### Example

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    container:
      image: node:24
      env:
        NODE_ENV: test
      volumes:
        - /data:/data

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v6

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        env:
          DATABASE_URL: postgres://postgres:postgres@postgres:5432/testdb
          REDIS_URL: redis://redis:6379
        run: npm test
```

### Common Errors
- Invalid image tags
- Incorrect volume mount syntax
- Service container networking issues
- Missing health checks for services

---

## Matrix Strategies

### Validation Points
- Matrix values must be arrays
- Valid matrix variable references
- Proper include/exclude syntax

### Example

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [20, 22, 24]
        exclude:
          - os: macos-latest
            node: 20
        include:
          - os: ubuntu-latest
            node: 24
            experimental: true

    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-node@v6
        with:
          node-version: ${{ matrix.node }}
      - run: npm test
```

---

## Concurrency Control

### Validation Points
- Valid concurrency group names
- Proper cancel-in-progress usage

### Example

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - run: npm ci && npm run build
```

This prevents redundant runs while protecting main branch runs from cancellation.