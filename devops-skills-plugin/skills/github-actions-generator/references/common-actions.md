# Common GitHub Actions Reference

**Last Updated:** November 2025
**Source:** Official GitHub Actions repositories and Context7 verified documentation

This document catalogs frequently used GitHub Actions with current versions, inputs, outputs, and usage examples.

**Important Notes for 2025:**
- All actions should be pinned to full 40-character SHA for security
- Node 24 runtime is now supported (Node 20 EOL: April 2026, default switch: March 4, 2026)
- actions/cache v4.3.0 recommended (v4.2.0+ required as of February 2025, legacy service sunset)
- Cache size limits: 10 GB free per repository, additional storage available (as of November 2025)

## Table of Contents
1. [Repository and Checkout](#repository-and-checkout)
2. [Language and Tool Setup](#language-and-tool-setup)
3. [Caching](#caching)
4. [Artifacts](#artifacts)
5. [Docker](#docker)
6. [Cloud Providers](#cloud-providers)
7. [Testing and Code Quality](#testing-and-code-quality)
8. [Notifications](#notifications)
9. [Release and Publishing](#release-and-publishing)
10. [Security](#security)

## Repository and Checkout

### actions/checkout

**Latest Version:** v5 (v5.0.0)
**SHA:** `08c6903cd8c0fde910a37f88322edcfb5dd907a8`
**Minimum Runner:** v2.327.1+

**Description:** Checkout repository code with improved performance and security

**Common Inputs:**
- `fetch-depth`: Number of commits to fetch (default: 1, use 0 for full history)
- `ref`: Branch, tag, or SHA to checkout
- `token`: PAT for private repos (default: `${{ github.token }}`)
- `submodules`: Whether to checkout submodules (`false`, `true`, `recursive`)
- `lfs`: Whether to download Git LFS files (default: `false`)
- `sparse-checkout`: Paths to checkout (cone mode or individual files) - **New in v5**
- `sparse-checkout-cone-mode`: Use cone mode for sparse checkout (default: `true`)

**Required Permissions:**
```yaml
permissions:
  contents: read
```

**Examples:**

**Basic checkout:**
```yaml
- name: Checkout code
  uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
  with:
    fetch-depth: 1
```

**Full history (for changelog/tags):**
```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
  with:
    fetch-depth: 0
```

**Sparse checkout (specific directories):**
```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
  with:
    sparse-checkout: |
      .github
      src
      tests
```

**Checkout PR HEAD commit:**
```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
  with:
    ref: ${{ github.event.pull_request.head.sha }}
```

**Checkout private repository:**
```yaml
- uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
  with:
    repository: my-org/my-private-repo
    token: ${{ secrets.GH_PAT }}
    path: my-repo
```

## Language and Tool Setup

### actions/setup-node

**Latest Version:** v6 (v6.0.0)
**SHA:** `2028fbc5c25fe9cf00d9f06a71cc4710d4507903`
**Minimum Runner:** v2.328.0+ (for Node 24 support)

**Description:** Setup Node.js environment with Node 24 support

**Important:** Node 24 runtime is now supported. Node 20 deprecation timeline: Default switch March 4, 2026 → EOL April 2026 → Complete removal Summer 2026.

**Common Inputs:**
- `node-version`: Version to use (e.g., `'24'`, `'20'`, `'18.x'`, `'lts/*'`)
- `cache`: Package manager to cache (`'npm'`, `'yarn'`, `'pnpm'`)
- `cache-dependency-path`: Path to lock file(s)
- `registry-url`: NPM registry URL for publishing
- `always-auth`: Set always-auth in npmrc (default: `false`)

**Examples:**

**Basic setup with caching:**
```yaml
- name: Setup Node.js 24
  uses: actions/setup-node@v6
  with:
    node-version: '24'
    cache: 'npm'
```

**Multi-lock-file caching:**
```yaml
- uses: actions/setup-node@v6
  with:
    node-version: '24'
    cache: 'npm'
    cache-dependency-path: |
      package-lock.json
      packages/*/package-lock.json
```

**Setup for package publishing:**
```yaml
- uses: actions/setup-node@v6
  with:
    node-version: '20'
    registry-url: 'https://registry.npmjs.org'

- run: npm publish
  env:
    NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### actions/setup-python

**Latest Version:** v5 (v5.0.0)
**SHA:** `0a5c61591373683505ea898e09a3ea4f39ef2b9c`

**Description:** Setup Python environment

**Common Inputs:**
- `python-version`: Version to use (e.g., `'3.11'`, `'3.x'`)
- `cache`: Package manager to cache (`'pip'`, `'pipenv'`, `'poetry'`)
- `cache-dependency-path`: Path to requirements file

**Example:**
```yaml
- name: Setup Python
  uses: actions/setup-python@0a5c61591373683505ea898e09a3ea4f39ef2b9c # v5.0.0
  with:
    python-version: '3.11'
    cache: 'pip'
    cache-dependency-path: 'requirements*.txt'
```

### actions/setup-java

**Latest Version:** v4 (v4.0.0)
**SHA:** `387ac29b308b003ca37ba93a6cab5eb57c8f5f93`

**Description:** Setup Java environment

**Common Inputs:**
- `distribution`: Java distribution (`'temurin'`, `'zulu'`, `'adopt'`, etc.)
- `java-version`: Version to use (e.g., `'17'`, `'11'`)
- `cache`: Build tool to cache (`'maven'`, `'gradle'`, `'sbt'`)

**Example:**
```yaml
- name: Setup Java
  uses: actions/setup-java@387ac29b308b003ca37ba93a6cab5eb57c8f5f93 # v4.0.0
  with:
    distribution: 'temurin'
    java-version: '17'
    cache: 'maven'
```

### actions/setup-go

**Latest Version:** v5 (v5.0.0)
**SHA:** `0c52d547c9bc32b1aa3301fd7a9cb496313a4491`

**Description:** Setup Go environment

**Common Inputs:**
- `go-version`: Version to use (e.g., `'1.21'`, `'stable'`)
- `cache`: Whether to cache dependencies (default: `true`)
- `cache-dependency-path`: Path to go.sum

**Example:**
```yaml
- name: Setup Go
  uses: actions/setup-go@0c52d547c9bc32b1aa3301fd7a9cb496313a4491 # v5.0.0
  with:
    go-version: '1.21'
    cache-dependency-path: go.sum
```

## Caching

### actions/cache

**Latest Version:** v4 (v4.3.0)
**SHA:** `0057852bfaa89a56745cba8c7296529d2fc39830`

**Description:** Cache dependencies and build outputs (v4.2.0+ required as of Feb 2025)

**Important:** Legacy cache service sunset February 1, 2025. Repositories get 10 GB free cache storage, with additional storage available.

**Required Inputs:**
- `path`: Directories to cache
- `key`: Cache key (must be unique)

**Optional Inputs:**
- `restore-keys`: Fallback keys if exact key not found

**Example:**
```yaml
- name: Cache dependencies
  uses: actions/cache@0057852bfaa89a56745cba8c7296529d2fc39830 # v4.3.0
  with:
    path: |
      ~/.npm
      ~/.cache
      node_modules
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

## Artifacts

### actions/upload-artifact

**Latest Version:** v4 (v4.3.1)
**SHA:** `5d5d22a31266ced268874388b861e4b58bb5c2f3`

**Description:** Upload build artifacts

**Required Inputs:**
- `name`: Artifact name
- `path`: Files to upload

**Optional Inputs:**
- `retention-days`: How long to keep artifact (1-90, default: 90)
- `if-no-files-found`: What to do if no files found (`warn`, `error`, `ignore`)

**Example:**
```yaml
- name: Upload build artifacts
  uses: actions/upload-artifact@5d5d22a31266ced268874388b861e4b58bb5c2f3 # v4.3.1
  with:
    name: build-${{ github.sha }}
    path: dist/
    retention-days: 7
    if-no-files-found: error
```

### actions/download-artifact

**Latest Version:** v4 (v4.1.4)
**SHA:** `c850b930e6ba138125429b7e5c93fc707a7f8427`

**Description:** Download artifacts from previous jobs

**Optional Inputs:**
- `name`: Artifact name (downloads all if not specified)
- `path`: Destination path

**Example:**
```yaml
- name: Download build artifacts
  uses: actions/download-artifact@c850b930e6ba138125429b7e5c93fc707a7f8427 # v4.1.4
  with:
    name: build-${{ github.sha }}
    path: dist/
```

## Docker

### docker/setup-buildx-action

**Latest Version:** v3 (v3.3.0)
**SHA:** `d70bba72b1f3fd22344832f00baa16ece964efeb`

**Description:** Setup Docker Buildx for advanced builds

**Example:**
```yaml
- name: Set up Docker Buildx
  uses: docker/setup-buildx-action@d70bba72b1f3fd22344832f00baa16ece964efeb # v3.3.0
```

### docker/login-action

**Latest Version:** v3 (v3.1.0)
**SHA:** `e92390c5fb421da1463c202d546fed0ec5c39f20`

**Description:** Login to Docker registry

**Common Inputs:**
- `registry`: Registry to login to (default: Docker Hub)
- `username`: Username
- `password`: Password or token

**Example:**
```yaml
# Docker Hub
- name: Login to Docker Hub
  uses: docker/login-action@e92390c5fb421da1463c202d546fed0ec5c39f20 # v3.1.0
  with:
    username: ${{ secrets.DOCKERHUB_USERNAME }}
    password: ${{ secrets.DOCKERHUB_TOKEN }}

# GitHub Container Registry
- name: Login to GHCR
  uses: docker/login-action@e92390c5fb421da1463c202d546fed0ec5c39f20 # v3.1.0
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

### docker/build-push-action

**Latest Version:** v5 (v5.3.0)
**SHA:** `2cdde995de11925a030ce8070c3d77a52ffcf1c0`

**Description:** Build and push Docker images

**Common Inputs:**
- `context`: Build context path
- `file`: Dockerfile path
- `push`: Whether to push image (default: `false`)
- `tags`: Image tags
- `platforms`: Target platforms (e.g., `linux/amd64,linux/arm64`)
- `cache-from`: Cache sources
- `cache-to`: Cache destinations
- `build-args`: Build arguments
- `secrets`: Build secrets

**Example:**
```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@2cdde995de11925a030ce8070c3d77a52ffcf1c0 # v5.3.0
  with:
    context: .
    platforms: linux/amd64,linux/arm64
    push: true
    tags: |
      user/app:latest
      user/app:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    build-args: |
      VERSION=${{ github.sha }}
      BUILD_DATE=${{ github.event.head_commit.timestamp }}
```

## Cloud Providers

### aws-actions/configure-aws-credentials

**Latest Version:** v4 (v4.0.2)
**SHA:** `e3dd6a429d7300a6a4c196c26e071d42e0343502`

**Description:** Configure AWS credentials for GitHub Actions

**Common Inputs:**
- `aws-access-key-id`: AWS access key ID
- `aws-secret-access-key`: AWS secret access key
- `aws-region`: AWS region
- `role-to-assume`: IAM role ARN for OIDC
- `role-session-name`: Session name

**Example (with secrets):**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
  with:
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-region: us-east-1
```

**Example (with OIDC - preferred):**
```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@e3dd6a429d7300a6a4c196c26e071d42e0343502 # v4.0.2
  with:
    role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsRole
    role-session-name: GitHubActions-${{ github.run_id }}
    aws-region: us-east-1
```

### azure/login

**Latest Version:** v2 (v2.0.0)
**SHA:** `6c251865b4e6290e7b78be643ea2d005a6c79ee5`

**Description:** Login to Azure

**Common Inputs:**
- `creds`: Azure credentials JSON
- `client-id`: Service principal client ID (for OIDC)
- `tenant-id`: Azure tenant ID (for OIDC)
- `subscription-id`: Azure subscription ID (for OIDC)

**Example:**
```yaml
- name: Azure Login
  uses: azure/login@6c251865b4e6290e7b78be643ea2d005a6c79ee5 # v2.0.0
  with:
    creds: ${{ secrets.AZURE_CREDENTIALS }}
```

## Testing and Code Quality

### codecov/codecov-action

**Latest Version:** v4 (v4.0.1)
**SHA:** `e0b68c6749509c5f83f984dd99a76a1c1a231044`

**Description:** Upload code coverage to Codecov

**Common Inputs:**
- `token`: Codecov token
- `files`: Coverage files to upload
- `fail_ci_if_error`: Fail CI if upload fails

**Example:**
```yaml
- name: Upload coverage to Codecov
  uses: codecov/codecov-action@e0b68c6749509c5f83f984dd99a76a1c1a231044 # v4.0.1
  with:
    token: ${{ secrets.CODECOV_TOKEN }}
    files: ./coverage/lcov.info
    fail_ci_if_error: true
```

### github/super-linter

**Latest Version:** v5 (v5.7.2)
**SHA:** `45fc0d88288beee4701c62761281edfee85655d7`

**Description:** Run multiple linters in one action

**Common Inputs:**
- `validate_all_codebase`: Lint entire codebase or just changes
- `default_branch`: Default branch name
- `disable_errors`: Don't fail on errors

**Example:**
```yaml
- name: Lint code
  uses: github/super-linter@45fc0d88288beee4701c62761281edfee85655d7 # v5.7.2
  env:
    VALIDATE_ALL_CODEBASE: false
    DEFAULT_BRANCH: main
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Notifications

### slackapi/slack-github-action

**Latest Version:** v1 (v1.25.0)
**SHA:** `6c661ce58804a1a20f6dc5fbee7f0381b469e001`

**Description:** Send Slack notifications

**Common Inputs:**
- `webhook-url`: Slack webhook URL
- `payload`: JSON payload to send

**Example:**
```yaml
- name: Notify Slack
  uses: slackapi/slack-github-action@6c661ce58804a1a20f6dc5fbee7f0381b469e001 # v1.25.0
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK_URL }}
    payload: |
      {
        "text": "Build completed: ${{ job.status }}",
        "blocks": [
          {
            "type": "section",
            "text": {
              "type": "mrkdwn",
              "text": "*Status:* ${{ job.status }}\n*Branch:* ${{ github.ref }}"
            }
          }
        ]
      }
```

## Release and Publishing

### actions/create-release

**Note:** Deprecated. Use `gh release create` or `softprops/action-gh-release` instead.

### softprops/action-gh-release

**Latest Version:** v2 (v2.0.2)
**SHA:** `9d7c94cfd0a1f3ed45544c887983e9fa900f0564`

**Description:** Create GitHub releases

**Common Inputs:**
- `tag_name`: Release tag (default: from tag trigger)
- `name`: Release name
- `body`: Release description
- `draft`: Create as draft
- `prerelease`: Mark as prerelease
- `files`: Files to upload

**Example:**
```yaml
- name: Create Release
  uses: softprops/action-gh-release@9d7c94cfd0a1f3ed45544c887983e9fa900f0564 # v2.0.2
  with:
    tag_name: ${{ github.ref }}
    name: Release ${{ github.ref_name }}
    body_path: CHANGELOG.md
    draft: false
    prerelease: false
    files: |
      dist/*.zip
      dist/*.tar.gz
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### actions/github-script

**Latest Version:** v7 (v7.0.1)
**SHA:** `60a0d83039c74a4aee543508d2ffcb1c3799cdea`

**Description:** Run JavaScript with GitHub API access

**Common Inputs:**
- `script`: JavaScript code to execute
- `github-token`: GitHub token (default: `${{ github.token }}`)

**Example:**
```yaml
- name: Create comment
  uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea # v7.0.1
  with:
    github-token: ${{ secrets.GITHUB_TOKEN }}
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: '👋 Thanks for reporting!'
      })
```

## Security

### actions/dependency-review-action

**Latest Version:** v4
**Description:** Scans pull requests for vulnerable dependency versions

**Required Permissions:**
```yaml
permissions:
  contents: read
```

**Common Inputs:**
- `fail-on-severity`: Severity level to fail on (`low`, `moderate`, `high`, `critical`)
- `allow-licenses`: Comma-separated list of allowed licenses
- `deny-licenses`: Comma-separated list of denied licenses

**Example:**
```yaml
- name: Dependency Review
  uses: actions/dependency-review-action@v4
  with:
    fail-on-severity: critical
    allow-licenses: MIT, Apache-2.0, BSD-3-Clause
```

### actions/attest-sbom

**Latest Version:** v2
**Description:** Generate SBOM attestations for artifacts

**Required Permissions:**
```yaml
permissions:
  id-token: write
  contents: read
  attestations: write
  packages: write  # For container registry
```

**Example:**
```yaml
- name: Generate SBOM attestation
  uses: actions/attest-sbom@v2
  with:
    subject-name: ${{ env.REGISTRY }}/myapp
    subject-digest: sha256:${{ steps.build.outputs.digest }}
    sbom-path: sbom.json
    push-to-registry: true
```

## Best Practices Summary (Updated November 2025)

1. **Always pin to full SHA**: Use 40-character SHA with version comment
2. **Node 24 migration**: Migrate to Node 24 before March 2026 (Node 20 EOL April 2026)
3. **Cache v4.3.0**: Use latest cache version (v4.2.0+ required, legacy service retired Feb 2025)
4. **Use official actions**: Prefer verified `actions/*`, `docker/*`, etc.
5. **Security scanning**: Implement dependency review and SBOM attestations
6. **Minimal permissions**: Use explicit `permissions:` blocks
7. **Keep up to date**: Monitor releases and security advisories
8. **Document versions**: Add comments explaining version choices

## Finding Action Documentation

**Search Pattern:**
```
"[owner/repo] [version] github action documentation"
```

**Example:**
```
"docker/build-push-action v5 github documentation"
"actions/checkout v5 sparse-checkout"
```

**Official Sources:**
- GitHub Marketplace: https://github.com/marketplace
- Action repository: https://github.com/[owner]/[repo]
- Release notes: https://github.com/[owner]/[repo]/releases
- Context7: Use for structured documentation lookup

**Version Verification:**
- Check releases page for latest version
- Find SHA from tags: `git ls-remote https://github.com/[owner]/[repo] [tag]`
- Verify minimum runner requirements

Always verify action inputs and outputs from official documentation before use.
