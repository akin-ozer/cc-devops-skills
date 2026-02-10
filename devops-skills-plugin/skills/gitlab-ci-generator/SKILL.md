---
name: gitlab-ci-generator
description: Comprehensive toolkit for generating best practice GitLab CI/CD pipelines and configurations following current standards and conventions. Use this skill when creating new GitLab CI/CD resources, implementing CI/CD pipelines, or building GitLab pipelines from scratch.
---

# GitLab CI/CD Pipeline Generator

## Overview

Generate production-ready GitLab CI/CD pipeline configurations following current best practices, security standards, and naming conventions. All generated resources are automatically validated using the devops-skills:gitlab-ci-validator skill to ensure syntax correctness and compliance with best practices.

---

## MANDATORY PRE-GENERATION STEPS

**CRITICAL:** Before generating ANY GitLab CI/CD pipeline, you MUST complete these steps:

### Step 1: Load Reference Files (REQUIRED)

You MUST use the **Read tool** to load reference files before generating. This is NOT optional.

```
ALWAYS read ALL FOUR reference files BEFORE generating:
1. references/best-practices.md - For security, performance, and naming patterns
2. references/common-patterns.md - For standard pipeline patterns to use as foundation
3. references/gitlab-ci-reference.md - For syntax reference and keyword details
4. references/security-guidelines.md - For security-sensitive configurations
```

**Additionally, read the appropriate template for the pipeline type:**
- Docker pipelines → `assets/templates/docker-build.yml`
- Kubernetes deployments → `assets/templates/kubernetes-deploy.yml`
- Multi-project pipelines → `assets/templates/multi-project.yml`
- Basic pipelines → `assets/templates/basic-pipeline.yml`

### Step 2: Confirm Understanding (EXPLICIT OUTPUT REQUIRED)

After reading references, you MUST output an explicit confirmation statement. This is NOT optional.

**Required confirmation format:**
```
## Reference Analysis Complete

**Pipeline Pattern Identified:** [Pattern name] from common-patterns.md
- [Brief description of why this pattern fits]

**Best Practices to Apply:**
- [List 3-5 key best practices relevant to this pipeline]

**Security Guidelines:**
- [List security measures to implement]

**Template Foundation:** [Template file name]
- [What will be customized from this template]
```

**Example confirmation statement:**
```
## Reference Analysis Complete

**Pipeline Pattern Identified:** Docker Build + Kubernetes Deployment from common-patterns.md
- User needs containerized deployment to K8s clusters with staging/production environments

**Best Practices to Apply:**
- Pin all Docker images to specific versions (not :latest)
- Use caching for pip dependencies
- Implement DAG optimization with `needs` keyword
- Set explicit timeout on all jobs (15-20 minutes)
- Use resource_group for deployment jobs

**Security Guidelines:**
- Use masked CI/CD variables for secrets (KUBE_CONTEXT, registry credentials)
- Include container scanning with Trivy
- Never expose secrets in logs

**Template Foundation:** docker-build.yml + kubernetes-deploy.yml
- Combining Docker build pattern with K8s kubectl deployment
- Adding Python-specific test jobs
```

**If you skip this confirmation step, the generated pipeline may miss critical patterns documented in reference files.**

---

## Core Capabilities

### 1. Generate Basic CI/CD Pipelines

Create complete, production-ready `.gitlab-ci.yml` files with proper structure, security best practices, and efficient CI/CD patterns.

**When to use:**
- User requests: "Create a GitLab pipeline for...", "Build a CI/CD pipeline...", "Generate GitLab CI config..."
- Scenarios: CI/CD pipelines, automated testing, build automation, deployment pipelines

**Process:**
1. Understand the user's requirements (what needs to be automated)
2. Identify stages, jobs, dependencies, and artifacts
3. Use `assets/templates/basic-pipeline.yml` as structural foundation
4. Reference `references/best-practices.md` for implementation patterns
5. Reference `references/common-patterns.md` for standard pipeline patterns
6. Generate the pipeline following these principles:
   - Use semantic stage and job names
   - Pin Docker images to specific versions (not :latest)
   - Implement proper secrets management with masked variables
   - Use caching for dependencies to improve performance
   - Implement proper artifact handling with expiration
   - Use `needs` keyword for DAG optimization when appropriate
   - Add proper error handling with retry and allow_failure
   - Use `rules` instead of deprecated only/except
   - **Set explicit `timeout` for all jobs** (10-30 minutes typically)
   - Add meaningful job descriptions in comments
7. **ALWAYS validate** the generated pipeline using the devops-skills:gitlab-ci-validator skill
8. If validation fails, fix the issues and re-validate

**Example structure:**
```yaml
# Basic CI/CD Pipeline
# Builds, tests, and deploys the application

stages:
  - build
  - test
  - deploy

# Global variables
variables:
  NODE_VERSION: "20"
  DOCKER_DRIVER: overlay2

# Default settings for all jobs
default:
  image: node:20-alpine
  timeout: 20 minutes  # Default timeout for all jobs
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - echo "Starting job ${CI_JOB_NAME}"
  tags:
    - docker
  interruptible: true

# Build stage - Compiles the application
build-application:
  stage: build
  timeout: 15 minutes
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
  rules:
    - changes:
        - src/**/*
        - package*.json
      when: always
    - when: on_success

# Test stage
test-unit:
  stage: test
  needs: [build-application]
  script:
    - npm run test:unit
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

test-lint:
  stage: test
  needs: []  # Can run immediately
  script:
    - npm run lint
  allow_failure: true

# Deploy stage
deploy-staging:
  stage: deploy
  needs: [build-application, test-unit]
  script:
    - npm run deploy:staging
  environment:
    name: staging
    url: https://staging.example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
  when: manual

deploy-production:
  stage: deploy
  needs: [build-application, test-unit]
  script:
    - npm run deploy:production
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  when: manual
  resource_group: production
```

### 2. Generate Docker Build Pipelines

Create pipelines for building, testing, and pushing Docker images to container registries.

**When to use:**
- User requests: "Create a Docker build pipeline...", "Build and push Docker images..."
- Scenarios: Container builds, multi-stage Docker builds, registry pushes

**Process:**
1. Understand the Docker build requirements (base images, registries, tags)
2. Use `assets/templates/docker-build.yml` as foundation
3. Implement Docker-in-Docker or Kaniko for builds
4. Configure registry authentication
5. Implement image tagging strategy
6. Add security scanning if needed
7. **ALWAYS validate** using devops-skills:gitlab-ci-validator skill

**Example:**
```yaml
stages:
  - build
  - scan
  - push

variables:
  DOCKER_DRIVER: overlay2
  IMAGE_NAME: $CI_REGISTRY_IMAGE
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA

# Build Docker image
docker-build:
  stage: build
  image: docker:24-dind
  timeout: 20 minutes
  services:
    - docker:24-dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build
        --cache-from $IMAGE_NAME:latest
        --tag $IMAGE_NAME:$IMAGE_TAG
        --tag $IMAGE_NAME:latest
        .
    - docker push $IMAGE_NAME:$IMAGE_TAG
    - docker push $IMAGE_NAME:latest
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
  retry:
    max: 2
    when:
      - runner_system_failure

# Scan for vulnerabilities
container-scan:
  stage: scan
  image: aquasec/trivy:0.49.0
  timeout: 15 minutes
  script:
    - trivy image --exit-code 0 --severity HIGH,CRITICAL $IMAGE_NAME:$IMAGE_TAG
  needs: [docker-build]
  allow_failure: true
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
```

### 3. Generate Kubernetes Deployment Pipelines

Create pipelines that deploy applications to Kubernetes clusters.

**When to use:**
- User requests: "Deploy to Kubernetes...", "Create K8s deployment pipeline..."
- Scenarios: Kubernetes deployments, Helm deployments, kubectl operations

**Process:**
1. Identify the Kubernetes deployment method (kubectl, Helm, Kustomize)
2. Use `assets/templates/kubernetes-deploy.yml` as foundation
3. Configure cluster authentication (service accounts, kubeconfig)
4. Implement proper environment management
5. Add rollback capabilities
6. **ALWAYS validate** using devops-skills:gitlab-ci-validator skill

**Example:**
```yaml
stages:
  - build
  - deploy

# Kubernetes deployment job
deploy-k8s:
  stage: deploy
  image: bitnami/kubectl:1.29
  timeout: 10 minutes
  before_script:
    - kubectl config use-context $KUBE_CONTEXT
  script:
    - kubectl set image deployment/myapp myapp=$CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA -n $KUBE_NAMESPACE
    - kubectl rollout status deployment/myapp -n $KUBE_NAMESPACE --timeout=5m
  environment:
    name: production
    url: https://example.com
    kubernetes:
      namespace: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
  resource_group: k8s-production
  retry:
    max: 2
    when:
      - runner_system_failure
```

### 4. Generate Multi-Project Pipelines

Create pipelines that trigger other projects or use parent-child pipeline patterns.

**When to use:**
- User requests: "Create multi-project pipeline...", "Trigger other pipelines..."
- Scenarios: Monorepos, microservices, orchestration pipelines

**Process:**
1. Identify the pipeline orchestration needs
2. Use `assets/templates/multi-project.yml` or parent-child templates
3. Configure proper artifact passing
4. Implement parallel execution where appropriate
5. **ALWAYS validate** using devops-skills:gitlab-ci-validator skill

**Example (Parent-Child):**
```yaml
# Parent pipeline
stages:
  - trigger

generate-child-pipeline:
  stage: trigger
  script:
    - echo "Generating child pipeline config"
    - |
      cat > child-pipeline.yml <<EOF
      stages:
        - build

      child-job:
        stage: build
        script:
          - echo "Running child job"
      EOF
  artifacts:
    paths:
      - child-pipeline.yml

trigger-child:
  stage: trigger
  trigger:
    include:
      - artifact: child-pipeline.yml
        job: generate-child-pipeline
    strategy: depend
  needs: [generate-child-pipeline]
```

### 5. Generate Template-Based Configurations

Create reusable templates using extends, YAML anchors, and includes.

**When to use:**
- User requests: "Create reusable templates...", "Build modular pipeline config..."
- Scenarios: Template libraries, DRY configurations, shared CI/CD logic

**Process:**
1. Identify common patterns to extract
2. Create hidden jobs (prefixed with .)
3. Use `extends` keyword for inheritance
4. Organize into separate files with `include`
5. **ALWAYS validate** using devops-skills:gitlab-ci-validator skill

**Example:**
```yaml
# Hidden template jobs (include timeout in templates)
.node-template:
  image: node:20-alpine
  timeout: 15 minutes  # Default timeout for jobs using this template
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - npm ci
  interruptible: true

.deploy-template:
  timeout: 10 minutes  # Deploy jobs should have explicit timeout
  before_script:
    - echo "Deploying to ${ENVIRONMENT}"
  after_script:
    - echo "Deployment complete"
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
  interruptible: false  # Deploys should not be interrupted

# Actual jobs using templates
build:
  extends: .node-template
  stage: build
  script:
    - npm run build

deploy-staging:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: staging
  script:
    - ./deploy.sh staging
  resource_group: staging
```

### 6. Handling GitLab CI/CD Documentation Lookup

When generating pipelines that use specific GitLab features, templates, or require latest documentation:

**Detection:**
- User mentions specific GitLab features (e.g., "Auto DevOps", "SAST", "dependency scanning")
- User requests integration with GitLab templates
- Pipeline requires specific GitLab runner features

**Process:**

1. **Identify the feature:**
   - Extract the GitLab feature or template name
   - Determine if version-specific information is needed

2. **Search for current documentation using WebSearch:**
   ```
   Search query pattern: "GitLab CI/CD [feature] documentation 2025"
   Examples:
   - "GitLab CI/CD SAST template documentation"
   - "GitLab Auto DevOps configuration"
   - "GitLab dependency scanning latest"
   ```

3. **Analyze search results for:**
   - Current recommended approach
   - Required variables and configuration
   - Template include syntax
   - Best practices and security recommendations
   - Example usage

4. **If Context7 MCP is available:**
   - Try to resolve library ID using `mcp__context7__resolve-library-id`
   - Fetch documentation using `mcp__context7__get-library-docs`
   - This provides structured documentation

5. **If specific documentation pages needed:**
   - Use WebFetch to retrieve from docs.gitlab.com
   - Extract relevant configuration examples

6. **Generate pipeline using discovered information:**
   - Use correct template include syntax
   - Configure required variables
   - Add security best practices
   - Include comments about versions and choices

**Example with GitLab templates:**
```yaml
# Include GitLab's security templates (use Jobs/ prefix for current templates)
include:
  - template: Jobs/SAST.gitlab-ci.yml
  - template: Jobs/Dependency-Scanning.gitlab-ci.yml

# Customize SAST behavior via global variables
# Note: Set variables globally rather than overriding template jobs
# to avoid validation issues with partial job definitions
variables:
  SAST_EXCLUDED_PATHS: "spec, test, tests, tmp, node_modules"
  DS_EXCLUDED_PATHS: "node_modules, vendor"
  SECURE_LOG_LEVEL: "info"
```

> **Important:** When using `include` with GitLab templates, the included jobs are
> fully defined in the template. If you need to customize them, prefer setting
> variables globally rather than creating partial job overrides (which will fail
> local validation because the validator cannot resolve the included template).
> GitLab merges the configuration at runtime, but local validators only see
> your `.gitlab-ci.yml` file.

## Validation Workflow

**CRITICAL:** Every generated GitLab CI/CD configuration MUST be validated before presenting to the user.

### Validation Process

1. **After generating any pipeline configuration**, immediately invoke the `devops-skills:gitlab-ci-validator` skill:
   ```
   Skill: devops-skills:gitlab-ci-validator
   ```

2. **The devops-skills:gitlab-ci-validator skill will:**
   - Validate YAML syntax
   - Check GitLab CI/CD schema compliance
   - Verify job references and dependencies
   - Check for best practices violations
   - Perform security scanning
   - Report any errors, warnings, or issues

3. **Analyze validation results and take action based on severity:**

   | Severity | Action Required |
   |----------|-----------------|
   | **CRITICAL** | MUST fix before presenting. Pipeline is broken or severely insecure. |
   | **HIGH** | MUST fix before presenting. Significant security or functionality issues. |
   | **MEDIUM** | SHOULD fix before presenting. Apply fixes or explain why not applicable. |
   | **LOW** | MAY fix or acknowledge. Inform user of recommendations. |
   | **SUGGESTIONS** | Review and apply if beneficial. No fix required. |

4. **Fix-and-Revalidate Loop (MANDATORY for Critical/High issues):**
   ```
   While validation has CRITICAL or HIGH issues:
     1. Edit the generated file to fix the issue
     2. Re-run validation
     3. Repeat until no CRITICAL or HIGH issues remain
   ```

5. **Before presenting to user, ensure:**
   - Zero CRITICAL issues
   - Zero HIGH issues
   - MEDIUM issues either fixed OR explained why they're acceptable
   - LOW issues and suggestions acknowledged

6. **When presenting the validated configuration:**
   - State validation status clearly
   - List any remaining MEDIUM/LOW issues with explanations
   - Provide usage instructions
   - Mention any trade-offs made

### Validation Pass Criteria

**Pipeline is READY to present when:**
- ✅ Syntax validation: PASSED
- ✅ Security scan: No CRITICAL or HIGH issues
- ✅ Best practices: Reviewed (warnings acceptable with explanation)

**Pipeline is NOT READY when:**
- ❌ Any syntax errors exist
- ❌ Any CRITICAL security issues exist
- ❌ Any HIGH security issues exist
- ❌ Job references are broken

### When to Skip Validation

Only skip validation when:
- Generating partial code snippets (not complete files)
- Creating examples for documentation purposes
- User explicitly requests to skip validation

### Handling MEDIUM Severity Issues (REQUIRED OUTPUT)

When the validator reports MEDIUM severity issues, you MUST either fix them OR explain why they're acceptable. This explanation is REQUIRED in your output.

**Required format for MEDIUM issue handling:**
```
## Validation Issues Addressed

### MEDIUM Severity Issues

| Issue | Status | Explanation |
|-------|--------|-------------|
| [Issue code] | Fixed/Acceptable | [Why it was fixed OR why it's acceptable] |
```

**Example MEDIUM issue explanations:**

```
## Validation Issues Addressed

### MEDIUM Severity Issues

| Issue | Status | Explanation |
|-------|--------|-------------|
| `image-variable-no-digest` | Acceptable | Using `python:${PYTHON_VERSION}-alpine` allows flexible version management via CI/CD variables. The PYTHON_VERSION variable is controlled internally and pinned to "3.12". SHA digest pinning would require updating the digest with every image update, adding maintenance burden without significant security benefit for this use case. |
| `pip-without-hashes` | Acceptable | This pipeline installs well-known packages (pytest, flake8) from PyPI. Using `--require-hashes` would require maintaining hash files for all transitive dependencies. For internal CI/CD, the security trade-off is acceptable. For higher security environments, consider using a private PyPI mirror with verified packages. |
| `git-strategy-none` | Acceptable | The `stop-staging` and `rollback-production` jobs use `GIT_STRATEGY: none` because they only run kubectl commands that don't require source code. The scripts are inline in the YAML (not from the repo), so there's no risk of executing untrusted code. |
```

**When to FIX vs ACCEPT:**

| Scenario | Action |
|----------|--------|
| Production/high-security environment | FIX the issue |
| Issue has simple fix with no downside | FIX the issue |
| Fix adds significant complexity | ACCEPT with explanation |
| Fix requires external changes (e.g., CI/CD variables) | ACCEPT with explanation |
| Issue is false positive for this context | ACCEPT with explanation |

### Reviewing Suggestions (REQUIRED OUTPUT)

When the validator provides suggestions, you MUST briefly acknowledge them and explain whether they should be applied.

**Required format:**
```
## Validator Suggestions Review

| Suggestion | Recommendation | Reason |
|------------|----------------|--------|
| [suggestion] | Apply/Skip | [Why] |
```

**Example suggestions review:**

```
## Validator Suggestions Review

| Suggestion | Recommendation | Reason |
|------------|----------------|--------|
| `missing-retry` on test jobs | Skip | Test jobs are deterministic and don't interact with external services. Retry would mask flaky tests rather than fail fast. |
| `parallel-opportunity` for test-unit | Apply if beneficial | Could be added if pytest supports sharding. Add `parallel: 3` with `pytest --shard=${CI_NODE_INDEX}/${CI_NODE_TOTAL}` if test suite is large enough to benefit. |
| `dag-optimization` for stop-staging | Skip | This job is manual and only runs on environment cleanup. DAG optimization wouldn't provide meaningful speedup. |
| `no-dependency-proxy` | Apply for production | Consider using `$CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX` to avoid Docker Hub rate limits. Requires GitLab Premium. |
| `environment-no-url` for rollback | Skip | Rollback jobs don't deploy new versions, so a URL would be misleading. |
| `missing-coverage` for lint job | Skip | Linting doesn't produce coverage data. This is a false positive. |
```

### Usage Instructions Template (REQUIRED OUTPUT)

After presenting the validated pipeline, you MUST provide usage instructions. This is NOT optional.

**Required format:**
```
## Usage Instructions

### Required CI/CD Variables

Configure these variables in **Settings → CI/CD → Variables**:

| Variable | Description | Masked | Protected |
|----------|-------------|--------|-----------|
| [VARIABLE_NAME] | [Description] | Yes/No | Yes/No |

### Setup Steps

1. [First setup step]
2. [Second setup step]
...

### Pipeline Behavior

- **On push to `develop`:** [What happens]
- **On push to `main`:** [What happens]
- **On tag `vX.Y.Z`:** [What happens]

### Customization

[Any customization notes]
```

**Example usage instructions:**

```
## Usage Instructions

### Required CI/CD Variables

Configure these variables in **Settings → CI/CD → Variables**:

| Variable | Description | Masked | Protected |
|----------|-------------|--------|-----------|
| `KUBE_CONTEXT` | Kubernetes cluster context name | No | Yes |
| `KUBE_NAMESPACE_STAGING` | Staging namespace (default: staging) | No | No |
| `KUBE_NAMESPACE_PRODUCTION` | Production namespace (default: production) | No | Yes |

**Note:** `CI_REGISTRY_USER`, `CI_REGISTRY_PASSWORD`, and `CI_REGISTRY` are automatically provided by GitLab.

### Kubernetes Integration Setup

1. **Enable Kubernetes integration** in **Settings → Infrastructure → Kubernetes clusters**
2. **Add your cluster** using the agent-based or certificate-based method
3. **Create namespaces** for staging and production if they don't exist:
   ```bash
   kubectl create namespace staging
   kubectl create namespace production
   ```
4. **Ensure deployment exists** in the target namespaces before running the pipeline

### Pipeline Behavior

- **On push to `develop`:** Runs tests → builds Docker image → deploys to staging automatically
- **On push to `main`:** Runs tests → builds Docker image → manual deployment to production
- **On tag `vX.Y.Z`:** Runs tests → builds Docker image → manual deployment to production

### Customization

- Update `APP_NAME` variable to match your Kubernetes deployment name
- Modify environment URLs in `deploy-staging` and `deploy-production` jobs
- Add Helm deployment by uncommenting the Helm jobs in the template
```

## Best Practices to Enforce

Reference `references/best-practices.md` for comprehensive guidelines. Key principles:

### Mandatory Standards

1. **Security First:**
   - Pin Docker images to specific versions (not :latest)
   - Use masked variables for secrets ($CI_REGISTRY_PASSWORD should be masked)
   - Never expose secrets in logs
   - Validate inputs and sanitize variables
   - Use protected variables for sensitive environments

2. **Performance:**
   - Implement caching for dependencies (ALWAYS for npm, pip, maven, etc.)
   - Use `needs` keyword for DAG optimization (ALWAYS when jobs have dependencies)
   - Set artifact expiration to avoid storage bloat (ALWAYS set `expire_in`)
   - Use `parallel` execution *when applicable* (only if test framework supports sharding)
   - Minimize unnecessary artifact passing (use `artifacts: false` in `needs` when not needed)

3. **Reliability:**
   - **Set explicit `timeout` for ALL jobs** (prevents hanging jobs, typically 10-30 minutes)
     - Even when using `default` or `extends` for timeout inheritance, add explicit `timeout` to each job
     - This improves readability and avoids validator warnings about missing timeout
     - Example: A job using `.deploy-template` should still have `timeout: 15 minutes` explicitly set
   - Add retry logic for flaky operations (network calls, external API interactions)
   - Use `allow_failure` appropriately for non-critical jobs (linting, optional scans)
   - Use `resource_group` for deployment jobs (prevents concurrent deployments)
   - Add `interruptible: true` for test jobs (allows cancellation when new commits push)

4. **Naming:**
   - Job names: Descriptive, kebab-case (e.g., "build-application", "test-unit")
   - Stage names: Short, clear (e.g., "build", "test", "deploy")
   - Variable names: UPPER_SNAKE_CASE for environment variables
   - Environment names: lowercase (e.g., "production", "staging")

5. **Configuration Organization:**
   - Use `extends` for reusable configuration (PREFERRED over YAML anchors for GitLab CI)
   - Use `include` for modular pipeline files (organize large pipelines into multiple files)
   - Use `rules` instead of deprecated only/except (ALWAYS)
   - Define `default` settings for common configurations (image, timeout, cache, tags)
   - Use YAML anchors *only when necessary* for complex repeated structures within a single file
     - Note: `extends` is preferred because it provides better visualization in GitLab UI

6. **Error Handling:**
   - Set appropriate timeout values (ALWAYS - prevents hanging jobs)
   - Configure retry behavior for flaky operations (network calls, external APIs)
   - Use `allow_failure: true` for non-blocking jobs (linting, optional scans)
   - Add cleanup steps with `after_script` *when needed* (e.g., stopping test containers, cleanup)
   - Implement notification mechanisms *when required* (e.g., Slack integration for deployment failures)

## Resources

### References (Load as Needed)

- `references/best-practices.md` - Comprehensive GitLab CI/CD best practices
  - Security patterns, performance optimization
  - Pipeline design, configuration organization
  - Common patterns and anti-patterns
  - **Use this:** When implementing any GitLab CI/CD resource

- `references/common-patterns.md` - Frequently used pipeline patterns
  - Basic CI pipeline patterns
  - Docker build and push patterns
  - Deployment patterns (K8s, cloud platforms)
  - Multi-project and parent-child patterns
  - **Use this:** When selecting which pattern to use

- `references/gitlab-ci-reference.md` - GitLab CI/CD YAML syntax reference
  - Complete keyword reference
  - Job configuration options
  - Rules and conditional execution
  - Variables and environments
  - **Use this:** For syntax and keyword details

- `references/security-guidelines.md` - Security best practices
  - Secrets management
  - Image security
  - Script security
  - Artifact security
  - **Use this:** For security-sensitive configurations

### Assets (Templates to Customize)

- `assets/templates/basic-pipeline.yml` - Complete basic pipeline template
- `assets/templates/docker-build.yml` - Docker build pipeline template
- `assets/templates/kubernetes-deploy.yml` - Kubernetes deployment template
- `assets/templates/multi-project.yml` - Multi-project orchestration template

**How to use templates:**
1. Copy the relevant template structure
2. Replace all `[PLACEHOLDERS]` with actual values
3. Customize logic based on user requirements
4. Remove unnecessary sections
5. Validate the result

## Typical Workflow Example

**User request:** "Create a CI/CD pipeline for a Node.js app with testing and Docker deployment"

**Process:**
1. ✅ Understand requirements:
   - Node.js application
   - Run tests (unit, lint)
   - Build Docker image
   - Deploy to container registry
   - Trigger on push and merge requests

2. ✅ Reference resources:
   - Check `references/best-practices.md` for pipeline structure
   - Check `references/common-patterns.md` for Node.js + Docker pattern
   - Use `assets/templates/docker-build.yml` as base

3. ✅ Generate pipeline:
   - Define stages (build, test, dockerize, deploy)
   - Create build job with caching
   - Create test jobs (unit, lint) with needs optimization
   - Create Docker build job
   - Add proper artifact management
   - Pin Docker images to versions
   - Include proper secrets handling

4. ✅ Validate:
   - Invoke `devops-skills:gitlab-ci-validator` skill
   - Fix any reported issues
   - Re-validate if needed

5. ✅ Present to user:
   - Show validated pipeline
   - Explain key sections
   - Provide usage instructions
   - Mention successful validation

## Common Pipeline Patterns

### Basic Three-Stage Pipeline
```yaml
stages:
  - build
  - test
  - deploy

build-job:
  stage: build
  script: make build

test-job:
  stage: test
  script: make test

deploy-job:
  stage: deploy
  script: make deploy
  when: manual
```

### DAG Pipeline with Needs
```yaml
stages:
  - build
  - test
  - deploy

build-frontend:
  stage: build
  script: npm run build:frontend

build-backend:
  stage: build
  script: npm run build:backend

test-frontend:
  stage: test
  needs: [build-frontend]
  script: npm test:frontend

test-backend:
  stage: test
  needs: [build-backend]
  script: npm test:backend

deploy:
  stage: deploy
  needs: [test-frontend, test-backend]
  script: make deploy
```

### Conditional Execution with Rules
```yaml
deploy-staging:
  script: deploy staging
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
      when: always
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      when: manual

deploy-production:
  script: deploy production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
    - when: never
```

### Matrix Parallel Jobs
```yaml
test:
  parallel:
    matrix:
      - NODE_VERSION: ['18', '20', '22']
        OS: ['ubuntu', 'alpine']
  image: node:${NODE_VERSION}-${OS}
  script:
    - npm test
```

## Error Messages and Troubleshooting

### If devops-skills:gitlab-ci-validator reports errors:

1. **Syntax errors:** Fix YAML formatting, indentation, or structure
2. **Job reference errors:** Ensure referenced jobs exist in needs/dependencies
3. **Stage errors:** Verify all job stages are defined in stages list
4. **Rule errors:** Check rules syntax and variable references
5. **Security warnings:** Address hardcoded secrets and image pinning

### If GitLab documentation is not found:

1. Try alternative search queries
2. Check docs.gitlab.com directly
3. Look for GitLab CI/CD templates in GitLab repository
4. Ask user if they have specific version requirements

---

## PRE-DELIVERY CHECKLIST

**MANDATORY:** Before presenting ANY generated pipeline to the user, verify ALL items:

### Reference Files Loaded (ALL FOUR REQUIRED)
- [ ] Read `references/best-practices.md` before generating
- [ ] Read `references/common-patterns.md` before generating
- [ ] Read `references/gitlab-ci-reference.md` for syntax reference
- [ ] Read `references/security-guidelines.md` for security patterns
- [ ] Read appropriate template from `assets/templates/` for the pipeline type
- [ ] **Output explicit confirmation statement** (Step 2 format)

### Generation Standards Applied
- [ ] All Docker images pinned to specific versions (no `:latest`)
- [ ] All jobs have explicit `timeout` (10-30 minutes typically)
- [ ] `default` block includes `timeout` if defined
- [ ] Hidden templates (`.template-name`) include `timeout`
- [ ] Caching configured for dependency installation
- [ ] `needs` keyword used for DAG optimization where appropriate
- [ ] `rules` used (not deprecated `only`/`except`)
- [ ] `resource_group` configured for deployment jobs
- [ ] Artifacts have `expire_in` set
- [ ] Secrets use masked CI/CD variables (not hardcoded)

### Validation Completed
- [ ] Invoked `devops-skills:gitlab-ci-validator` skill
- [ ] Zero CRITICAL issues
- [ ] Zero HIGH issues
- [ ] **MEDIUM issues addressed** (fixed OR explained in output using required format)
- [ ] **LOW issues acknowledged** (listed in output)
- [ ] **Suggestions reviewed** (using required format)
- [ ] Re-validated after any fixes

### Presentation Ready
- [ ] Validation status stated clearly
- [ ] **MEDIUM/LOW issues explained** (with table format)
- [ ] **Suggestions review provided** (with table format)
- [ ] **Usage instructions provided** (with required sections)
- [ ] Key sections explained

**If any checkbox is unchecked, DO NOT present the pipeline. Complete the missing steps first.**

### Required Output Sections

Your final response MUST include these sections in order:

1. **Reference Analysis Complete** (from Step 2)
2. **Generated Pipeline** (the `.gitlab-ci.yml` content)
3. **Validation Results Summary** (pass/fail status)
4. **Validation Issues Addressed** (MEDIUM issues table)
5. **Validator Suggestions Review** (suggestions table)
6. **Usage Instructions** (variables, setup, behavior)

---

## Summary

Always follow this sequence when generating GitLab CI/CD pipelines:

1. **Load References** - MUST read ALL FOUR reference files first:
   - `references/best-practices.md`
   - `references/common-patterns.md`
   - `references/gitlab-ci-reference.md`
   - `references/security-guidelines.md`
   - Plus the appropriate template from `assets/templates/`
2. **Understand** - Clarify user requirements, stages, and jobs needed
3. **Generate** - Use templates and follow standards (security, caching, naming, explicit timeout on ALL jobs)
4. **Search** - For specific features, use WebSearch or Context7 for current docs
5. **Validate** - ALWAYS use devops-skills:gitlab-ci-validator skill
6. **Fix** - Resolve ALL Critical/High issues, address Medium issues
7. **Verify Checklist** - Confirm all pre-delivery checklist items
8. **Present** - Deliver validated, production-ready pipeline with usage instructions

Generate GitLab CI/CD pipelines that are:
- ✅ Secure with pinned images and proper secrets handling
- ✅ Following current best practices and conventions
- ✅ Using proper configuration organization (extends, includes)
- ✅ Optimized for performance (caching, needs, DAG)
- ✅ Properly documented with usage instructions
- ✅ Validated with zero Critical/High issues
- ✅ Production-ready and maintainable
