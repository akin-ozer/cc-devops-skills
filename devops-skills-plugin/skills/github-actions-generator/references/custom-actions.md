# Custom GitHub Actions Guide

**Last Updated:** December 2025

This guide covers creating custom GitHub Actions: composite, Docker, and JavaScript actions with proper metadata, directory structure, and versioning.

## Table of Contents
1. [Action Types](#action-types)
2. [Action Metadata](#action-metadata)
3. [Directory Structure](#directory-structure)
4. [Versioning](#versioning)
5. [Publishing to Marketplace](#publishing-to-marketplace)

---

## Action Types

| Type | Runtime | Use Case | Performance |
|------|---------|----------|-------------|
| Composite | Shell/Actions | Combine multiple steps | Fast startup |
| Docker | Container | Custom environment/tools | Slower startup |
| JavaScript | Node.js | API interactions, complex logic | Fastest |

---

## Action Metadata

### Branding

Add branding to make your action visually distinctive in GitHub Marketplace:

```yaml
name: 'Setup Node.js with Cache'
description: 'Setup Node.js with automatic dependency caching'
author: 'Your Name or Organization'

branding:
  icon: 'package'  # Feather icon name
  color: 'blue'    # Available: white, yellow, blue, green, orange, red, purple, gray-dark

inputs:
  node-version:
    description: 'Node.js version to use'
    required: true
```

**Available Icons:** See [Feather Icons](https://feathericons.com/) - e.g., `package`, `box`, `server`, `code`, `git-branch`, `shield`, `check-circle`

**Best Practices:**
- Choose icons that represent the action's purpose
- Use consistent branding across related actions
- Branding is required for GitHub Marketplace publishing

---

## Directory Structure

### Local Repository Actions

Use `.github/actions/` for actions within the same repository:

```
repository-root/
├── .github/
│   ├── actions/                    # Local custom actions
│   │   ├── setup-node-cached/      # Composite action
│   │   │   ├── action.yml
│   │   │   └── README.md
│   │   ├── terraform-validator/    # Docker action
│   │   │   ├── action.yml
│   │   │   ├── Dockerfile
│   │   │   ├── entrypoint.sh
│   │   │   └── README.md
│   │   └── label-pr/               # JavaScript action
│   │       ├── action.yml
│   │       ├── dist/
│   │       │   └── index.js        # Compiled/bundled JS
│   │       ├── src/
│   │       │   └── index.ts        # Source TypeScript
│   │       ├── package.json
│   │       └── README.md
│   └── workflows/
│       └── ci.yml
```

**Usage in Workflows:**
```yaml
steps:
  # Local action (same repository)
  - uses: ./.github/actions/setup-node-cached
    with:
      node-version: '20'

  # Action from another repository
  - uses: owner/repo/.github/actions/action-name@v1
```

### Standalone Action Repositories

For actions intended for GitHub Marketplace or cross-repo reuse:

```
action-repository-root/
├── action.yml          # Action definition (MUST be in root)
├── README.md           # Usage documentation
├── LICENSE             # License file
├── CHANGELOG.md        # Version history
├── dist/               # Compiled code (JS actions)
│   └── index.js
├── src/                # Source code (JS actions)
│   └── index.ts
└── Dockerfile          # For Docker actions
```

**Best Practices:**
- Use `.github/actions/` for repository-local actions
- Create separate repos for reusable/Marketplace actions
- Always include README.md with usage examples
- For JS actions, commit compiled `dist/` (don't gitignore)

---

## Versioning

### Semantic Versioning

Use MAJOR.MINOR.PATCH format:
- **MAJOR:** Breaking changes
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes

### Git Tags

```bash
# Create version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# Update major version tag (v1 → latest v1.x.x)
git tag -fa v1 -m "Update v1 to v1.0.0"
git push origin v1 --force
```

### Tag Strategy

Maintain multiple tag levels:
- **Specific:** `v1.0.0`, `v1.0.1`, `v1.1.0`
- **Major:** `v1`, `v2` (points to latest minor/patch)

**User options:**
```yaml
- uses: owner/action@v1.0.0    # Pinned to exact version
- uses: owner/action@v1        # Latest v1.x.x
- uses: owner/action@abc123    # Pinned to SHA (most secure)
```

### Release Workflow

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

permissions:
  contents: write

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v5

      - name: Create GitHub Release
        run: gh release create ${{ github.ref_name }} --generate-notes
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Update major version tag
        run: |
          MAJOR=$(echo ${{ github.ref_name }} | cut -d. -f1)
          git tag -fa $MAJOR -m "Update $MAJOR tag"
          git push origin $MAJOR --force
```

### Breaking Changes

When introducing breaking changes:
1. Document in CHANGELOG.md and release notes
2. Increment MAJOR version
3. Provide migration guide
4. Consider maintaining previous major version branch

---

## Publishing to Marketplace

### Requirements

1. **Repository must be public**
2. **action.yml in repository root**
3. **Branding metadata** (icon and color)
4. **README.md** with usage examples
5. **Semantic version tags**

### Marketplace Listing

1. Go to repository Settings → Actions → "Create Action"
2. Or visit: `https://github.com/marketplace/actions/your-action`
3. Fill in marketplace details
4. Submit for review

### Pre-release Testing

Use pre-release versions for testing:
```bash
git tag -a v1.0.0-beta.1 -m "Beta release"
git push origin v1.0.0-beta.1
```

---

## Action Templates

### Composite Action Template

```yaml
name: '[Action Name]'
description: '[Brief description]'
author: '[Author]'

branding:
  icon: 'check-circle'
  color: 'green'

inputs:
  input-name:
    description: '[Description]'
    required: true
    default: '[default value]'

outputs:
  output-name:
    description: '[Description]'
    value: ${{ steps.step-id.outputs.value }}

runs:
  using: 'composite'
  steps:
    - name: Step name
      id: step-id
      shell: bash
      run: echo "value=result" >> $GITHUB_OUTPUT
```

### Docker Action Template

```yaml
name: '[Action Name]'
description: '[Brief description]'
author: '[Author]'

branding:
  icon: 'box'
  color: 'blue'

inputs:
  input-name:
    description: '[Description]'
    required: true

outputs:
  output-name:
    description: '[Description]'

runs:
  using: 'docker'
  image: 'Dockerfile'
  args:
    - ${{ inputs.input-name }}
```

### JavaScript Action Template

```yaml
name: '[Action Name]'
description: '[Brief description]'
author: '[Author]'

branding:
  icon: 'code'
  color: 'purple'

inputs:
  github-token:
    description: 'GitHub token for API access'
    required: true

outputs:
  result:
    description: 'Action result'

runs:
  using: 'node20'
  main: 'dist/index.js'
```

---

## Summary

| Aspect | Recommendation |
|--------|---------------|
| Location | `.github/actions/` for local, separate repo for shared |
| Branding | Required for Marketplace, recommended for all |
| Versioning | Semantic versions with major tag updates |
| Documentation | README.md with examples, CHANGELOG.md |
| Security | Pin to SHA, minimal permissions |