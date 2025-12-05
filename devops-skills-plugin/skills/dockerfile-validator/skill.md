---
name: dockerfile-validator
description: Comprehensive toolkit for validating, linting, and securing Dockerfiles. Use this skill when validating Dockerfile syntax, checking security best practices, optimizing image builds. Applies to all Dockerfile variants (Dockerfile, Dockerfile.prod, Dockerfile.dev, etc.).
---

# Dockerfile Validator

## Overview

Comprehensive toolkit for validating Dockerfiles with syntax checking, security scanning, best practices enforcement, and build optimization analysis. This skill uses a **single self-contained script** (`dockerfile-validate.sh`) that handles everything: tool installation, validation, and cleanup.

**Key Features:**
- ✅ Single script execution - no dependencies on other scripts
- ✅ Auto-installs hadolint and Checkov in Python venvs if not found
- ✅ Runs all 4 validation stages (syntax, security, best practices, optimization)
- ✅ Auto-cleanup on exit using bash trap (success or failure)
- ✅ Zero configuration required

## When to Use This Skill

Invoke this skill when:
- Validating Dockerfile syntax and structure
- Checking Dockerfiles for security vulnerabilities
- Optimizing Docker image build performance
- Ensuring adherence to official Docker best practices
- Debugging Dockerfile errors or build issues
- Performing security audits of container images
- The user asks to "validate", "lint", "check", or "optimize" a Dockerfile
- Reviewing Dockerfiles before committing to version control
- Analyzing existing Dockerfiles for improvements

## Do NOT Use This Skill For

- Generating new Dockerfiles (use dockerfile-generator instead)
- Building or running containers (use docker build/run commands)
- Debugging running containers (use docker logs, docker exec)
- Managing Docker images or registries

## Quick Start

**Single command to validate any Dockerfile:**

```bash
bash scripts/dockerfile-validate.sh Dockerfile
```

That's it! The script automatically:
1. Checks if hadolint and Checkov are installed
2. Installs them temporarily in Python venvs if needed
3. Runs all 4 validation stages (syntax, security, best practices, optimization)
4. Cleans up temporary installations on exit

## Validation Workflow

The `dockerfile-validate.sh` script runs a comprehensive 4-stage validation:

```
┌─────────────────────────────────────────────────────────┐
│  Auto-Install (if needed)                               │
│  ├─> Check for hadolint and Checkov                     │
│  ├─> Install in Python venvs if not found               │
│  └─> Set TEMP_INSTALL=true (triggers cleanup on exit)   │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│  [1/4] Syntax Validation (hadolint)                     │
│  ├─> Dockerfile syntax checking                         │
│  ├─> Instruction validation                             │
│  ├─> Shell script validation (via ShellCheck)           │
│  └─> 100+ built-in linting rules                        │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│  [2/4] Security Scan (Checkov)                          │
│  ├─> Security policy validation                         │
│  ├─> Hardcoded secret detection                         │
│  ├─> Port exposure checks                               │
│  ├─> USER directive validation                          │
│  └─> 50+ security policies                              │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│  [3/4] Best Practices Validation (custom)               │
│  ├─> Base image tag validation (:latest check)          │
│  ├─> USER directive enforcement (non-root)              │
│  ├─> HEALTHCHECK presence                               │
│  ├─> Layer efficiency (RUN command count)               │
│  ├─> Package cache cleanup verification                 │
│  ├─> Hardcoded secrets detection                        │
│  └─> COPY ordering for build cache efficiency           │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│  [4/4] Optimization Analysis (custom)                   │
│  ├─> Base image size analysis (Alpine suggestions)      │
│  ├─> Multi-stage build opportunities                    │
│  ├─> Layer count optimization                           │
│  ├─> .dockerignore file check                           │
│  └─> Build structure recommendations                    │
└─────────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────────┐
│  Auto-Cleanup (bash trap - always runs)                 │
│  └─> Remove temp venvs if TEMP_INSTALL=true             │
└─────────────────────────────────────────────────────────┘
```

**Cleanup Guarantee:**
Uses `trap cleanup EXIT INT TERM` to ensure cleanup runs on:
- ✅ Normal exit
- ✅ Validation failure
- ✅ Ctrl+C (interrupt)
- ✅ Script error

## Core Capabilities

### 1. Syntax Validation with hadolint

**Purpose:** Lint Dockerfile syntax and catch common mistakes before building.

**Tool:** hadolint - A Dockerfile linter that validates instructions and embedded bash commands using ShellCheck.

**Installation:**

Tools are automatically installed by the validation script if not found. For permanent installation:

```bash
# macOS
brew install hadolint

# Linux
wget -O ~/.local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64
chmod +x ~/.local/bin/hadolint

# Docker (fallback option)
docker pull hadolint/hadolint
```

**Workflow:**

```bash
# Run hadolint on Dockerfile
hadolint Dockerfile

# Run with JSON output for parsing
hadolint --format json Dockerfile

# Run with specific rules ignored
hadolint --ignore DL3006 --ignore DL3008 Dockerfile

# Using Docker if not installed
docker run --rm -i hadolint/hadolint < Dockerfile
```

**Common Issues Detected:**

**DL-prefixed rules (hadolint-specific):**
- `DL3000` - Use absolute WORKDIR paths
- `DL3001` - For some bash commands make no sense in a Docker container
- `DL3002` - Last USER should not be root
- `DL3003` - Use WORKDIR to switch directories
- `DL3004` - Do not use sudo
- `DL3006` - Always tag image versions (avoid :latest)
- `DL3007` - Using latest is not recommended
- `DL3008` - Pin versions in apt-get install
- `DL3009` - Delete apt-cache after installing
- `DL3013` - Pin versions in pip install
- `DL3014` - Use -y switch for apt-get
- `DL3015` - Avoid additional packages with apt-get
- `DL3016` - Pin versions in npm install
- `DL3018` - Pin versions in apk add
- `DL3019` - Use --no-cache with apk add
- `DL3020` - Use COPY instead of ADD for files
- `DL3021` - COPY from previous stages should reference by name
- `DL3022` - COPY --from should reference a previously defined FROM alias
- `DL3025` - Use JSON notation for CMD and ENTRYPOINT
- `DL3059` - Multiple consecutive RUN instructions (combine for layer efficiency)

**SC-prefixed rules (ShellCheck for RUN commands):**
- `SC1091` - Not following sourced files
- `SC2046` - Quote to prevent word splitting
- `SC2086` - Double quote to prevent globbing
- `SC2164` - Use cd ... || exit for error handling

**Rule Severity Levels:**
- **error** - Will likely cause build failure or runtime issues
- **warning** - Violates best practices, should be fixed
- **info** - Suggestions for improvement
- **style** - Code style preferences

**Best Practices:**
- Run hadolint before every docker build
- Integrate into CI/CD pipelines
- Configure .hadolint.yaml for project-specific rules
- Address errors before warnings
- Use inline ignore comments sparingly with justification

### 2. Security Scanning with Checkov

**Purpose:** Detect security misconfigurations and vulnerabilities before image deployment.

**Tool:** Checkov - Policy-as-code security scanner with 50+ built-in Dockerfile policies.

**Installation:**

The validation script automatically installs Checkov in an isolated Python venv if not found. For permanent installation:

```bash
# Install directly
pip3 install checkov

# macOS Homebrew
brew install checkov

# Verify installation
checkov --version
```

**Workflow:**

```bash
# Scan a Dockerfile
checkov -f Dockerfile --framework dockerfile

# Scan a directory (finds all Dockerfiles)
checkov -d . --framework dockerfile

# Scan with compact output (only failures)
checkov -f Dockerfile --framework dockerfile --compact

# Scan with JSON output
checkov -f Dockerfile --framework dockerfile -o json

# Skip specific checks
checkov -f Dockerfile --framework dockerfile --skip-check CKV_DOCKER_2
```

**Common Security Checks:**

**General Security:**
- `CKV_DOCKER_1` - Ensure port 22 (SSH) is not exposed
- `CKV_DOCKER_2` - Ensure HEALTHCHECK instruction exists
- `CKV_DOCKER_3` - Ensure user is created and used (not root)
- `CKV_DOCKER_4` - Ensure ADD is not used (prefer COPY)
- `CKV_DOCKER_5` - Ensure update without install is not used alone
- `CKV_DOCKER_6` - Ensure SHELL instruction uses -o pipefail
- `CKV_DOCKER_7` - Ensure base image uses specific version tag
- `CKV_DOCKER_8` - Ensure last USER is not root
- `CKV_DOCKER_9` - Ensure apt-get dist-upgrade is not used
- `CKV_DOCKER_10` - Ensure yum update is not used alone

**Package Management:**
- Check for missing package manager cache cleanup
- Verify version pinning for installed packages
- Detect use of --no-install-recommends for apt-get

**Secrets Detection:**
- Scan for potential secrets in ENV or ARG
- Detect hardcoded credentials
- Identify exposed API keys or tokens

**Output Formats:**
- `cli` - Human-readable console output (default)
- `json` - JSON format for programmatic parsing
- `sarif` - SARIF format for IDE integration
- `gitlab_sast` - GitLab security dashboard format
- `junitxml` - JUnit XML for CI integration

**Understanding Results:**

```
Check: "Ensure that HEALTHCHECK instructions have been added to container images"
    FAILED for resource: Dockerfile.
    File: /Dockerfile:1-20
    Guide: https://docs.bridgecrew.io/docs/ensure-that-healthcheck-instructions-have-been-added-to-container-images

    1  | FROM node:18
    20 | CMD ["node", "server.js"]
```

**Suppressing False Positives:**

Add inline comments to suppress specific checks:

```dockerfile
# checkov:skip=CKV_DOCKER_2:Health check not applicable for this init container
FROM alpine:3.21
...
```

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**Best Practices:**
- Run Checkov after hadolint (syntax first, then security)
- Address high-severity findings first
- Document all suppressions with clear justification
- Integrate into CI/CD pipelines
- Review new policies regularly
- Combine with image vulnerability scanning (e.g., trivy, snyk)

### 3. Best Practices Validation

**Purpose:** Ensure Dockerfiles follow official Docker best practices and current recommendations.

**Custom Validation Checks:**

**1. Base Image Validation:**
```bash
# Check for :latest tag usage
grep -E "^FROM.*:latest" Dockerfile

# Recommend specific tags or digest pinning
# Good: FROM alpine:3.21
# Better: FROM alpine:3.21@sha256:digest
```

**2. Multi-Stage Build Detection:**
```bash
# Count FROM statements
grep -c "^FROM" Dockerfile

# Single FROM suggests potential for multi-stage optimization
```

**3. USER Directive Check:**
```bash
# Ensure USER is set before CMD/ENTRYPOINT
# Check that last USER is not root
grep "^USER" Dockerfile
```

**4. HEALTHCHECK Presence:**
```bash
# Verify HEALTHCHECK is defined for services
grep "^HEALTHCHECK" Dockerfile
```

**5. Layer Efficiency:**
```bash
# Count RUN commands (>5 suggests combination opportunity)
grep -c "^RUN" Dockerfile

# Check for apt-get update separated from install
grep -A1 "^RUN.*apt-get update" Dockerfile
```

**6. Package Manager Cache Cleanup:**
```bash
# Verify cache cleanup in same RUN layer
grep "rm -rf /var/lib/apt/lists" Dockerfile
grep "--no-cache" Dockerfile  # for apk
```

**Best Practices Checklist:**

**Base Images:**
- ✓ Use specific version tags, not :latest
- ✓ Consider Alpine variants for smaller size
- ✓ Pin to digest for reproducibility
- ✓ Use official images from verified publishers
- ✓ Scan base images for vulnerabilities

**Layer Optimization:**
- ✓ Combine related RUN commands with &&
- ✓ Order instructions from least to most frequently changing
- ✓ COPY package files before source code
- ✓ Clean up package manager caches in same layer
- ✓ Use .dockerignore to exclude unnecessary files

**Security:**
- ✓ Run as non-root user (USER directive)
- ✓ Don't install unnecessary packages (--no-install-recommends)
- ✓ Don't hardcode secrets (use build secrets or runtime configs)
- ✓ Use COPY instead of ADD (unless extracting archives)
- ✓ Avoid curl | bash installations

**Multi-Stage Builds:**
- ✓ Separate build dependencies from runtime
- ✓ Name stages explicitly (FROM ... AS stagename)
- ✓ Copy only necessary artifacts between stages
- ✓ Use minimal runtime base images

**Runtime Configuration:**
- ✓ Define HEALTHCHECK for services
- ✓ Use exec form for ENTRYPOINT and CMD
- ✓ Set WORKDIR to absolute paths
- ✓ Document exposed ports with EXPOSE
- ✓ Add metadata with LABEL

**Build Performance:**
- ✓ Leverage build cache by proper instruction ordering
- ✓ Use BuildKit features (--mount=type=cache)
- ✓ Minimize context size with .dockerignore
- ✓ Parallelize multi-stage builds when possible

### 4. Optimization Analysis

**Purpose:** Identify opportunities to reduce image size, build time, and layer count.

**Optimization Categories:**

**1. Image Size Reduction:**
```dockerfile
# Bad: Full distro
FROM ubuntu:22.04
RUN apt-get update && apt-get install -y curl

# Good: Minimal distro
FROM alpine:3.21
RUN apk add --no-cache curl

# Better: Multi-stage with distroless
FROM golang:1.21 AS build
WORKDIR /app
COPY . .
RUN go build -o myapp

FROM gcr.io/distroless/base-debian11
COPY --from=build /app/myapp /
ENTRYPOINT ["/myapp"]
```

**2. Layer Optimization:**
```dockerfile
# Bad: Separate RUN commands (creates many layers)
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get install -y vim

# Good: Combined RUN (single layer)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*
```

**3. Build Cache Efficiency:**
```dockerfile
# Bad: Copy all, then install dependencies
COPY . /app
RUN pip install -r requirements.txt

# Good: Copy dependency file first
COPY requirements.txt /app/
RUN pip install -r requirements.txt
COPY . /app
```

**4. Multi-Stage Build Opportunities:**
```dockerfile
# Detects single-stage builds that could benefit from separation
# Look for:
# - Build tools installed but not needed at runtime
# - Source code copied but only binary needed
# - Development dependencies mixed with runtime
```

**Optimization Metrics:**
- **Layer count:** Fewer layers = smaller image
- **Image size:** Minimal base + cleanup = smaller download
- **Build time:** Cache hits + parallel stages = faster builds
- **Attack surface:** Fewer packages = fewer vulnerabilities

**Reference Documentation:**

Load detailed best practices:
```
references/docker_best_practices.md - Official Docker recommendations
references/optimization_guide.md - Layer and size optimization techniques
```

### 5. .dockerignore Validation

**Purpose:** Ensure build context is optimized by excluding unnecessary files.

**Validation Checks:**

```bash
# Check if .dockerignore exists
if [ ! -f .dockerignore ]; then
    echo "WARNING: .dockerignore file not found"
fi

# Common patterns that should be included
.git
.gitignore
README.md
.env
*.log
node_modules
*.md
.dockerignore
Dockerfile*
docker-compose*.yml
```

**Benefits of .dockerignore:**
- Reduces build context size
- Faster builds (less data to transfer)
- Prevents accidental secret leaks
- Excludes development-only files

**Best Practices:**
- Always create .dockerignore for non-trivial projects
- Include .git directory
- Exclude local configuration files (.env, *.local)
- Exclude documentation unless needed in image
- Exclude test files and test data
- Pattern syntax similar to .gitignore

## Tool Prerequisites

The validation script automatically installs tools if not found. No manual installation required.

**For permanent installations:**

```bash
# Install hadolint
brew install hadolint  # macOS

# Install Checkov
pip3 install checkov
```

**Minimum Versions:**
- hadolint: >= 2.12.0
- Checkov: Latest (for newest policies)
- Python: >= 3.8 (for temporary installations)
- Docker: >= 20.10 (optional, for testing builds)

**Testing Auto-Install and Cleanup:**

To test the temporary installation and cleanup functionality even when tools are already installed:

```bash
# Force temporary installation for testing
FORCE_TEMP_INSTALL=true bash scripts/dockerfile-validate.sh Dockerfile
```

This will:
1. Install hadolint and Checkov in temporary Python venvs
2. Run all validations using the temporary installations
3. Clean up temporary venvs on exit (success or failure)

## Handling Missing Tools

When validation tools are not installed:

### Workflow for Missing Tools

1. **Detect Missing Tool:**
   - Attempt to run hadolint or Checkov
   - If command fails, note which tool is missing

2. **Complete Available Validations:**
   - Continue with custom best practices checks
   - Provide partial validation results
   - Clearly indicate which checks were skipped

3. **Prompt User for Installation:**

   **For hadolint:**
   ```
   hadolint is not installed. The script will automatically install it temporarily.

   For permanent installation:
   - macOS: brew install hadolint
   - Linux: wget -O ~/.local/bin/hadolint https://github.com/hadolint/hadolint/releases/latest/download/hadolint-Linux-x86_64 && chmod +x ~/.local/bin/hadolint
   - Docker: docker pull hadolint/hadolint

   hadolint provides comprehensive Dockerfile linting and best practice checking.
   ```

   **For Checkov:**
   ```
   Checkov is not installed. Would you like to install it?

   Installation options:
   - Recommended: pip3 install checkov
   - macOS: brew install checkov

   Checkov provides security scanning with 50+ Dockerfile policies.
   Install and rerun validation? (y/N)
   ```

4. **If User Chooses to Install:**
   - Provide installation command
   - Wait for completion
   - Verify: `hadolint --version` or `checkov --version`
   - Rerun complete validation

5. **If User Declines:**
   - Continue with partial results
   - Document skipped checks
   - Suggest installing for future validations

### Tool Priority

**Required (always run):**
- Custom best practices validation
- File existence checks

**Recommended (offer installation if missing):**
- hadolint - Syntax and best practices linting
- Checkov - Security scanning

**Optional:**
- docker - For test builds
- trivy - For vulnerability scanning (complementary)

## Error Troubleshooting

### Common Issues and Solutions

**Error: FROM instruction must be first non-comment**
```
Solution: Move ARG that defines base image tag before FROM
ARG VERSION=18
FROM node:${VERSION}
```

**Error: Unknown instruction (typo)**
```
Solution: Check instruction spelling (RUN, COPY, FROM, etc.)
Common typos: RUNS, COPIES, FRUM
```

**Error: Chained RUN command fails**
```
Solution: Add set -e or check individual command success
RUN apt-get update && apt-get install -y package || exit 1
```

**Error: COPY failed: file not found**
```
Solution: Check file path is relative to build context
Verify file exists and not excluded by .dockerignore
```

**Security: Hardcoded secrets detected**
```
Solution: Use build secrets (BuildKit)
# Instead of: ENV API_KEY=secret123
# Use: docker build --secret id=api_key,src=api_key.txt
```

**Performance: Slow builds**
```
Solution:
1. Optimize layer caching (COPY package files first)
2. Use .dockerignore to reduce context
3. Enable BuildKit: export DOCKER_BUILDKIT=1
4. Use multi-stage builds
```

## Resources

### scripts/

**dockerfile-validate.sh**
- Single self-contained validation script
- Auto-installs hadolint and Checkov if needed
- Runs all 4 validation stages (syntax, security, best practices, optimization)
- Auto-cleanup on exit
- Usage: `bash scripts/dockerfile-validate.sh [Dockerfile]`

### examples/

**good-example.Dockerfile** - Demonstrates best practices and optimal structure

**bad-example.Dockerfile** - Common mistakes and anti-patterns

**security-issues.Dockerfile** - Intentional security vulnerabilities for testing

**python-optimized.Dockerfile** - Python-specific optimizations and multi-stage build

**golang-distroless.Dockerfile** - Minimal Go application using distroless base image

**.dockerignore.example** - Example .dockerignore for build context optimization

### references/

**docker_best_practices.md** - Official Docker best practices and recommendations

**optimization_guide.md** - Layer optimization and image size reduction techniques

**security_checklist.md** - Container security best practices

## Mandatory Workflow Requirements

**IMPORTANT:** When using this skill, you MUST follow these steps in order:

### Pre-Validation (Required)
1. **Read the Dockerfile first** - Always use the Read tool to examine the Dockerfile before running validation. This helps you understand the context and provide better recommendations.

### Validation (Required)
2. **Run the validation script** - Execute `bash scripts/dockerfile-validate.sh <Dockerfile>` to run all 4 validation stages.

### Post-Validation (Required)
3. **Summarize findings by severity** - After validation completes, provide a clear summary organized by:
   - Critical issues (security vulnerabilities, hardcoded secrets)
   - High priority (missing USER, HEALTHCHECK, :latest tags)
   - Medium priority (layer optimization, version pinning)
   - Low priority (style, informational)

4. **Propose specific fixes** - For each issue found, provide concrete code examples showing how to fix it. **You MUST use the Read tool** to load the appropriate reference files before proposing fixes:
   - `references/security_checklist.md` - For security-related fixes
   - `references/optimization_guide.md` - For performance/size improvements
   - `references/docker_best_practices.md` - For general best practices

   **Note:** Always explicitly read reference files during the post-validation phase to ensure fix recommendations follow authoritative patterns, even if you have prior knowledge of the content.

5. **Offer to apply fixes** - Ask the user if they want you to apply the proposed fixes to their Dockerfile.

### Reference File Usage

**IMPORTANT:** After running validation, you MUST use the **Read tool** to explicitly load the appropriate reference files before proposing fixes. This ensures fix recommendations are accurate and follow authoritative patterns.

**Workflow:**
1. Identify issue types from validation output (security, optimization, best practices)
2. Use the Read tool to load the matching reference file(s)
3. Apply patterns from the reference files when proposing fixes

| Issue Type | Reference File | Action |
|------------|----------------|--------|
| Security issues (secrets, USER, ports) | `references/security_checklist.md` | Read before proposing security fixes |
| Size/performance optimization | `references/optimization_guide.md` | Read before proposing optimization fixes |
| General best practices | `references/docker_best_practices.md` | Read before proposing best practice fixes |

**Example:**
```
# After validation finds security issues:
1. Use Read tool: Read references/security_checklist.md
2. Apply fix patterns from the file to the specific issues found
3. Propose fixes with code examples based on reference content
```

## Workflow Examples

### Example 1: Validate a Single Dockerfile

```
User: "Validate my Dockerfile"

Steps:
1. Read the Dockerfile using Read tool to understand structure
2. Run validation script: bash scripts/dockerfile-validate.sh Dockerfile
3. Review output from all 4 stages (hadolint, Checkov, best practices, optimization)
4. Summarize findings organized by severity (critical → low)
5. Use Read tool to load relevant reference files:
   - Read references/security_checklist.md (if security issues found)
   - Read references/optimization_guide.md (if optimization issues found)
   - Read references/docker_best_practices.md (if best practice issues found)
6. Propose specific fixes with code examples based on reference content
7. Ask user: "Would you like me to apply these fixes?"
8. Apply fixes if user approves
```

### Example 2: Comprehensive Multi-Dockerfile Validation

```
User: "Check all Dockerfiles in my project"

Steps:
1. Find all Dockerfile* files
2. Validate each sequentially
3. Aggregate results
4. Identify common issues across files
5. Provide unified report
6. Suggest project-wide improvements
```

### Example 3: Security Audit

```
User: "Security audit my Dockerfile"

Steps:
1. Run Checkov security scan
2. Run hadolint for security rules (DL3* series)
3. Check for hardcoded secrets
4. Verify USER directive
5. Check base image vulnerabilities
6. Provide security-focused report
7. Prioritize critical findings
```

### Example 4: Optimization Review

```
User: "How can I optimize my Dockerfile?"

Steps:
1. Analyze current layer structure
2. Identify multi-stage opportunities
3. Check build cache efficiency
4. Suggest base image alternatives
5. Calculate potential size savings
6. Provide before/after comparison
7. Implement optimizations if approved
```

## Integration with Other Skills

This skill works well in combination with:
- **dockerfile-generator** - Generate optimized Dockerfiles
- **k8s-yaml-validator** - Validate Kubernetes deployments that reference Docker images
- **helm-validator** - Validate Helm charts with container configurations

## Notes

- Always validate before building images
- Address security issues before optimizations
- Test builds after applying fixes
- Version pin base images for reproducibility
- Use multi-stage builds for compiled languages
- Keep production images minimal (distroless, Alpine)
- Never commit Dockerfiles with hardcoded secrets
- Document inline suppressions with clear justification
- Regularly update base images for security patches
- Integrate validation into CI/CD pipelines

## Sources

This skill is based on comprehensive research from authoritative sources:

**Official Docker Documentation:**
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)

**Security Guidelines:**
- [Checkov Dockerfile Scanning](https://www.checkov.io/7.Scan%20Examples/Dockerfile.html)
- [hadolint Rules](https://github.com/hadolint/hadolint)

**Best Practices Resources:**
- [Dockerfile Best Practices 2025](https://blog.bytescrum.com/dockerfile-best-practices-2025-secure-fast-and-modern)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)