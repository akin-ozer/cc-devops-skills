# GitHub Actions Generator Examples

This directory contains example workflows and actions generated using the github-actions-generator skill.

## Workflows

### Language-Specific CI Pipelines

#### nodejs-ci.yml
Complete CI pipeline for Node.js applications demonstrating:
- Matrix testing across multiple Node.js versions and operating systems
- Dependency caching with `actions/setup-node`
- Parallel linting and testing
- Artifact uploading for test results
- Code coverage reporting with Codecov
- Concurrency controls

**Use case:** Standard CI/CD for Node.js projects

#### python-ci.yml
Python CI pipeline demonstrating:
- Matrix testing across Python versions
- Virtual environment management
- Dependency caching with pip
- Testing with pytest
- Code quality checks

**Use case:** Python application CI/CD

#### go-ci.yml
Go CI pipeline demonstrating:
- Go module caching
- Cross-platform builds
- Go testing and benchmarking
- Static code analysis

**Use case:** Go application CI/CD

### Container & Deployment Workflows

#### docker-build-push.yml
Docker image build and push workflow demonstrating:
- Multi-platform builds (amd64, arm64)
- GitHub Container Registry integration
- Docker layer caching with GitHub Actions cache
- Automatic tagging based on git events
- Secure authentication with `GITHUB_TOKEN`

**Use case:** Containerized application deployment

#### multi-environment-deploy.yml
Multi-environment deployment workflow demonstrating:
- Environment protection rules and approval gates
- Dynamic environment selection (dev, staging, production)
- AWS deployment with OIDC authentication
- Blue-green deployment strategy
- Automatic rollback on failure
- Smoke tests and health checks
- Deployment verification

**Use case:** Production-grade multi-stage deployments

### Advanced Workflow Patterns

#### monorepo-ci.yml
Monorepo CI pipeline demonstrating:
- Path-based change detection
- Conditional job execution based on affected packages
- Cross-package dependency management
- Parallel builds for independent packages
- Artifact sharing between jobs
- Package-specific test strategies

**Use case:** Monorepo projects with multiple packages

#### scheduled-tasks.yml
Scheduled maintenance workflow demonstrating:
- Cron schedule configuration
- Dependency security audits
- Stale branch cleanup
- Cache management
- External service health checks
- Automated issue creation
- Weekly metrics reporting

**Use case:** Repository maintenance and monitoring

### Security Workflows

#### security/dependency-review.yml
Dependency review workflow demonstrating:
- Pull request dependency scanning
- Vulnerability severity thresholds
- License policy enforcement
- Automatic build failure on policy violations

**Use case:** Supply chain security for PRs

#### security/sbom-attestation.yml
SBOM and attestation workflow demonstrating:
- Software Bill of Materials generation
- SBOM attestation with GitHub's signing infrastructure
- Build provenance attestation
- Container vulnerability scanning with Trivy
- Multi-platform container builds
- Security scan results upload to GitHub Security tab

**Use case:** Supply chain security compliance

## Actions

### setup-node-cached/action.yml
Composite action for Node.js setup demonstrating:
- Smart dependency caching for npm, yarn, and pnpm
- Input validation
- Multiple package manager support
- Cache hit detection
- Grouped output for better logging

**Use case:** Reusable Node.js setup across multiple workflows

## Usage

These examples can be used as:
1. **Templates** - Copy and modify for your own projects
2. **Learning Resources** - Study best practices and patterns
3. **Testing** - Validate with github-actions-validator skill

## Testing Examples

To validate any of these examples:

```bash
cd .claude/skills/github-actions-validator
bash scripts/validate_workflow.sh ../../github-actions-generator/examples/workflows/nodejs-ci.yml
```

## Best Practices Demonstrated

All examples follow these best practices:
- ✅ Actions pinned to SHAs with version comments
- ✅ Minimal permissions with explicit `permissions:` blocks
- ✅ Concurrency controls to prevent duplicate runs
- ✅ Proper timeout settings
- ✅ Semantic naming conventions
- ✅ Comprehensive error handling
- ✅ Security-first approach
