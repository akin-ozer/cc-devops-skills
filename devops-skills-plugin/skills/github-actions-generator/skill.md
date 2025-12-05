---
name: github-actions-generator
description: Comprehensive toolkit for generating best practice GitHub Actions workflows, custom local actions, and configurations following current standards and conventions. Use this skill when creating new GitHub Actions resources, implementing CI/CD workflows, or building reusable actions.
---

# GitHub Actions Generator

Generate production-ready GitHub Actions workflows and custom actions following current best practices, security standards, and naming conventions. All generated resources are automatically validated using the devops-skills:github-actions-validator skill.

## Quick Reference

| Capability | When to Use | Reference |
|------------|-------------|-----------|
| Workflows | CI/CD, automation, testing | `references/best-practices.md` |
| Composite Actions | Reusable step combinations | `references/custom-actions.md` |
| Docker Actions | Custom environments/tools | `references/custom-actions.md` |
| JavaScript Actions | API interactions, complex logic | `references/custom-actions.md` |
| Reusable Workflows | Shared patterns across repos | `references/advanced-triggers.md` |
| Security Scanning | Dependency review, SBOM | `references/best-practices.md` |
| Modern Features | Summaries, environments | `references/modern-features.md` |

---

## Core Capabilities

### 1. Generate Workflows

**Triggers:** "Create a workflow for...", "Build a CI/CD pipeline..."

**Process:**
1. Understand requirements (triggers, runners, dependencies)
2. Reference `references/best-practices.md` for patterns
3. Reference `references/common-actions.md` for action versions
4. Generate workflow with:
   - Semantic names, pinned actions (SHA), proper permissions
   - Concurrency controls, caching, matrix strategies
5. **Validate** with devops-skills:github-actions-validator skill
6. Fix issues and re-validate if needed

**Minimal Example:**
```yaml
name: CI Pipeline

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
      - uses: actions/setup-node@2028fbc5c25fe9cf00d9f06a71cc4710d4507903 # v6.0.0
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
```

### 2. Generate Custom Actions

**Triggers:** "Create a composite action...", "Build a Docker action...", "Create a JavaScript action..."

**Types:**
- **Composite:** Combine multiple steps → Fast startup
- **Docker:** Custom environment/tools → Isolated
- **JavaScript:** API access, complex logic → Fastest

**Process:**
1. Use templates from `assets/templates/action/`
2. Follow structure in `references/custom-actions.md`
3. Include branding, inputs/outputs, documentation
4. **Validate** with devops-skills:github-actions-validator skill

See `references/custom-actions.md` for:
- Action metadata and branding
- Directory structure patterns
- Versioning and release workflows

### 3. Generate Reusable Workflows

**Triggers:** "Create a reusable workflow...", "Make this workflow callable..."

**Key Elements:**
- `workflow_call` trigger with typed inputs
- Explicit secrets (avoid `secrets: inherit`)
- Outputs mapped from job outputs
- Minimal permissions

```yaml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy-token:
        required: true
    outputs:
      result:
        value: ${{ jobs.build.outputs.result }}
```

See `references/advanced-triggers.md` for complete patterns.

### 4. Generate Security Workflows

**Triggers:** "Add security scanning...", "Add dependency review...", "Generate SBOM..."

**Components:**
- **Dependency Review:** `actions/dependency-review-action@v4`
- **SBOM Attestations:** `actions/attest-sbom@v2`
- **CodeQL Analysis:** `github/codeql-action`

**Required Permissions:**
```yaml
permissions:
  contents: read
  security-events: write  # For CodeQL
  id-token: write         # For attestations
  attestations: write     # For attestations
```

See `references/best-practices.md` section on security.

### 5. Modern Features

**Triggers:** "Add job summaries...", "Use environments...", "Run in container..."

See `references/modern-features.md` for:
- Job summaries (`$GITHUB_STEP_SUMMARY`)
- Deployment environments with approvals
- Container jobs with services
- Workflow annotations

### 6. Public Action Documentation

When using public actions:

1. **Search for documentation:**
   ```
   "[owner/repo] [version] github action documentation"
   ```

2. **Or use Context7 MCP:**
   - `mcp__context7__resolve-library-id` to find action
   - `mcp__context7__get-library-docs` for documentation

3. **Pin to SHA with version comment:**
   ```yaml
   - uses: actions/checkout@08c6903cd8c0fde910a37f88322edcfb5dd907a8 # v5.0.0
   ```

See `references/common-actions.md` for pre-verified action versions.

---

## Validation Workflow

**CRITICAL:** Every generated resource MUST be validated.

1. Generate workflow/action file
2. Invoke `devops-skills:github-actions-validator` skill
3. If errors: fix and re-validate
4. If success: present with usage instructions

**Skip validation only for:**
- Partial code snippets
- Documentation examples
- User explicitly requests skip

---

## Mandatory Standards

All generated resources must follow:

| Standard | Implementation |
|----------|---------------|
| **Security** | Pin to SHA, minimal permissions, mask secrets |
| **Performance** | Caching, concurrency, shallow checkout |
| **Naming** | Descriptive names, lowercase-hyphen files |
| **Error Handling** | Timeouts, cleanup with `if: always()` |

See `references/best-practices.md` for complete guidelines.

---

## Resources

### Reference Documents

| Document | Content | When to Use |
|----------|---------|-------------|
| `references/best-practices.md` | Security, performance, patterns | Every workflow |
| `references/common-actions.md` | Action versions, inputs, outputs | Public action usage |
| `references/expressions-and-contexts.md` | `${{ }}` syntax, contexts, functions | Complex conditionals |
| `references/advanced-triggers.md` | workflow_run, dispatch, ChatOps | Workflow orchestration |
| `references/custom-actions.md` | Metadata, structure, versioning | Custom action creation |
| `references/modern-features.md` | Summaries, environments, containers | Enhanced workflows |

### Templates

| Template | Location |
|----------|----------|
| Basic Workflow | `assets/templates/workflow/basic_workflow.yml` |
| Composite Action | `assets/templates/action/composite/action.yml` |
| Docker Action | `assets/templates/action/docker/` |
| JavaScript Action | `assets/templates/action/javascript/` |

---

## Common Patterns

### Matrix Testing
```yaml
strategy:
  matrix:
    os: [ubuntu-latest, windows-latest]
    node: [18, 20, 22]
  fail-fast: false
```

### Conditional Deployment
```yaml
deploy:
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
```

### Artifact Sharing
```yaml
# Upload
- uses: actions/upload-artifact@v4
  with:
    name: build-${{ github.sha }}
    path: dist/

# Download (in dependent job)
- uses: actions/download-artifact@v4
  with:
    name: build-${{ github.sha }}
```

---

## Workflow Summary

1. **Understand** requirements
2. **Reference** appropriate docs
3. **Generate** with standards
4. **Search** for public action docs (if needed)
5. **Validate** with devops-skills:github-actions-validator
6. **Fix** any errors
7. **Present** validated result