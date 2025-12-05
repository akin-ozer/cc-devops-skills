# GitLab CI/CD Best Practices

This document outlines comprehensive best practices for creating production-ready, secure, and efficient GitLab CI/CD pipelines.

## Table of Contents

1. [Security Best Practices](#security-best-practices)
2. [Performance Optimization](#performance-optimization)
3. [Configuration Organization](#configuration-organization)
4. [Reliability and Error Handling](#reliability-and-error-handling)
5. [Naming Conventions](#naming-conventions)
6. [Pipeline Architecture](#pipeline-architecture)
7. [Common Anti-Patterns](#common-anti-patterns)

---

## Security Best Practices

### 1. Docker Image Pinning

**Always pin Docker images to specific versions** to ensure reproducibility and security.

```yaml
# ❌ BAD: Using :latest tag
test-job:
  image: node:latest
  script: npm test

# ✅ GOOD: Pinned to specific version
test-job:
  image: node:20.11-alpine3.19
  script: npm test
```

**Best practices:**
- Pin to major.minor.patch versions
- Use official images from trusted registries
- Regularly update pinned versions
- Document why specific versions are chosen

### 2. Secrets and Variables Management

**Never hardcode secrets** in your `.gitlab-ci.yml` file. Use GitLab CI/CD variables instead.

```yaml
# ❌ BAD: Hardcoded credentials
deploy:
  script:
    - deploy --token abc123xyz

# ✅ GOOD: Using masked variables
deploy:
  script:
    - deploy --token $DEPLOY_TOKEN
```

**Best practices:**
- Mark sensitive variables as **Masked** and **Protected**
- Use project/group CI/CD variables for secrets
- Rotate secrets regularly
- Use `$CI_JOB_TOKEN` for GitLab API operations
- Limit variable scope to specific environments

### 3. Artifact Security

**Be careful with artifact paths** to avoid exposing sensitive files.

```yaml
# ❌ BAD: Overly broad artifact paths
build:
  artifacts:
    paths:
      - ./**  # Exposes everything including .env files

# ✅ GOOD: Specific artifact paths
build:
  artifacts:
    paths:
      - dist/
      - build/
    exclude:
      - "**/*.env"
      - "**/*.pem"
      - "**/credentials.*"
    expire_in: 1 hour
```

**Best practices:**
- Be explicit about artifact paths
- Use `exclude` to prevent sensitive files
- Set appropriate expiration times
- Use `artifacts:reports` for test/coverage reports
- Don't include node_modules or vendor directories

### 4. Script Security

**Avoid dangerous script patterns** that can introduce security vulnerabilities.

```yaml
# ❌ BAD: Dangerous patterns
install:
  script:
    - curl https://install.sh | bash  # Pipe to bash
    - eval "$COMMAND"  # Code injection risk
    - chmod 777 /app  # Overly permissive

# ✅ GOOD: Secure patterns
install:
  script:
    - curl -o install.sh https://install.sh
    - sha256sum -c install.sh.sha256  # Verify integrity
    - bash install.sh
```

**Best practices:**
- Never pipe curl directly to bash
- Validate downloaded scripts
- Use minimal file permissions
- Sanitize user inputs
- Avoid `eval` and similar dynamic execution

### 5. Protected Branches and Environments

Configure protected branches and environments for critical deployments.

```yaml
deploy-production:
  stage: deploy
  script:
    - deploy production
  environment:
    name: production
    url: https://example.com
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_COMMIT_TAG == null
  when: manual
  resource_group: production
```

**Best practices:**
- Require manual approval for production deployments
- Use protected environments
- Restrict who can deploy to production
- Use resource_group to prevent concurrent deployments
- Implement approval rules in GitLab

---

## Performance Optimization

### 1. Caching Strategies

**Use cache to speed up repeated operations** like dependency installation.

```yaml
# ✅ GOOD: Comprehensive caching
variables:
  CACHE_VERSION: "v1"  # Bump to invalidate cache

default:
  cache:
    key: ${CACHE_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
    policy: pull

build:
  stage: build
  script:
    - npm ci
    - npm run build
  cache:
    key: ${CACHE_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
    policy: pull-push  # Push after installing

test:
  stage: test
  script:
    - npm test
  cache:
    key: ${CACHE_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull  # Only pull, don't push
```

**Cache best practices:**
- Use appropriate cache keys (branch, commit, files)
- Set `policy: pull` for jobs that only read cache
- Set `policy: pull-push` for jobs that update cache
- Cache language-specific directories (node_modules/, vendor/, .gradle/)
- Use `CACHE_VERSION` variable for cache invalidation
- Don't cache build artifacts (use artifacts instead)

### 2. DAG Optimization with `needs`

**Use the `needs` keyword** to create Directed Acyclic Graphs for faster pipelines.

```yaml
stages:
  - build
  - test
  - deploy

# Without needs: runs sequentially (slow)
build-frontend:
  stage: build
  script: build frontend

build-backend:
  stage: build
  script: build backend

test-frontend:
  stage: test
  script: test frontend

test-backend:
  stage: test
  script: test backend

# ✅ With needs: runs in parallel (fast)
build-frontend:
  stage: build
  script: build frontend

build-backend:
  stage: build
  script: build backend

test-frontend:
  stage: test
  needs: [build-frontend]  # Can start as soon as build-frontend finishes
  script: test frontend

test-backend:
  stage: test
  needs: [build-backend]  # Can start as soon as build-backend finishes
  script: test backend

deploy:
  stage: deploy
  needs: [test-frontend, test-backend]  # Only depends on tests
  script: deploy
```

**Benefits:**
- Pipelines run faster by parallelizing independent jobs
- Reduces waiting time between stages
- Clear dependency visualization

### 3. Parallel Execution

**Use parallel jobs** for matrix testing or splitting workloads.

```yaml
# Parallel with matrix
test:
  parallel:
    matrix:
      - NODE_VERSION: ['18', '20', '22']
        OS: ['ubuntu', 'alpine']
  image: node:${NODE_VERSION}-${OS}
  script:
    - npm test

# Parallel with index
test-split:
  parallel: 4
  script:
    - npm test -- --shard=${CI_NODE_INDEX}/${CI_NODE_TOTAL}
```

### 4. Artifact Optimization

**Minimize artifact size** and set appropriate expiration.

```yaml
build:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    exclude:
      - dist/**/*.map  # Exclude source maps if not needed
    expire_in: 1 hour  # Short expiration for intermediate artifacts

deploy:
  stage: deploy
  needs: [build]
  script:
    - deploy dist/
```

**Best practices:**
- Set short expiration for intermediate artifacts (1 hour - 1 day)
- Set longer expiration for release artifacts (1 week - 1 month)
- Use `artifacts:reports` for test/coverage reports
- Exclude unnecessary files
- Compress large artifacts

---

## Configuration Organization

### 1. Using `extends` for Reusability

**Use `extends` to reduce duplication** and create maintainable configurations.

```yaml
# Hidden template jobs (prefixed with .)
.node-base:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - npm ci

.deploy-base:
  before_script:
    - echo "Deploying to ${ENVIRONMENT}"
  retry:
    max: 2
    when:
      - runner_system_failure
  resource_group: ${ENVIRONMENT}

# Actual jobs extending templates
build:
  extends: .node-base
  stage: build
  script:
    - npm run build

test:
  extends: .node-base
  stage: test
  script:
    - npm test

deploy-staging:
  extends: .deploy-base
  stage: deploy
  variables:
    ENVIRONMENT: staging
  script:
    - ./deploy.sh staging

deploy-production:
  extends: .deploy-base
  stage: deploy
  variables:
    ENVIRONMENT: production
  script:
    - ./deploy.sh production
  when: manual
```

### 2. Using `include` for Modular Configuration

**Split large configurations** into multiple files using `include`.

```yaml
# .gitlab-ci.yml (main file)
include:
  - local: '.gitlab/ci/templates.yml'
  - local: '.gitlab/ci/build-jobs.yml'
  - local: '.gitlab/ci/test-jobs.yml'
  - local: '.gitlab/ci/deploy-jobs.yml'

stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "20"
```

```yaml
# .gitlab/ci/templates.yml
.node-base:
  image: node:${NODE_VERSION}-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - npm ci
```

### 3. Using YAML Anchors

**Use YAML anchors** for complex repeated structures within a file.

```yaml
# Define anchor
.retry-config: &retry-config
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

# Use anchor
deploy-staging:
  stage: deploy
  <<: *retry-config
  script:
    - deploy staging

deploy-production:
  stage: deploy
  <<: *retry-config
  script:
    - deploy production
```

### 4. Using `default` for Common Settings

**Set default values** for all jobs using the `default` keyword.

```yaml
default:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - echo "Starting job ${CI_JOB_NAME}"
  retry:
    max: 1
    when:
      - runner_system_failure
  tags:
    - docker
  interruptible: true

# Jobs inherit default settings
build:
  stage: build
  script: npm run build

test:
  stage: test
  script: npm test
```

---

## Reliability and Error Handling

### 1. Retry Configuration

**Configure retry for flaky operations** to improve reliability.

```yaml
# Retry on specific failures
test-integration:
  script:
    - npm run test:integration
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
      - api_failure

# Conditional retry
deploy:
  script:
    - deploy.sh
  retry:
    max: 2
    when: always
```

**Retry scenarios:**
- Network-dependent operations
- External API calls
- Integration tests
- Deployment operations
- Runner system failures

### 2. Timeout Settings

**Set appropriate timeouts** to prevent jobs from hanging.

```yaml
# Global default timeout (project settings)
# Job-specific timeout
test-quick:
  script: npm run test:unit
  timeout: 10 minutes

test-e2e:
  script: npm run test:e2e
  timeout: 30 minutes

deploy:
  script: deploy.sh
  timeout: 15 minutes
```

### 3. Allow Failure

**Use `allow_failure` strategically** for non-critical jobs.

```yaml
# Job can fail without blocking pipeline
lint:
  script: npm run lint
  allow_failure: true

# Conditional allow_failure
test-experimental:
  script: npm run test:experimental
  allow_failure:
    exit_codes: [1, 137]
```

### 4. Interruptible Jobs

**Mark test jobs as interruptible** to save resources.

```yaml
test:
  script: npm test
  interruptible: true  # Can be canceled if new pipeline starts

deploy:
  script: deploy.sh
  interruptible: false  # Should not be canceled
```

### 5. After Script for Cleanup

**Use `after_script` for cleanup operations** that always run.

```yaml
test:
  script:
    - npm test
  after_script:
    - echo "Cleaning up..."
    - docker stop test-container || true
    - rm -rf temp/
```

---

## Naming Conventions

### Job Names

**Use descriptive, action-oriented names** in kebab-case.

```yaml
# ✅ GOOD: Clear, descriptive names
build-frontend:
  script: npm run build:frontend

test-unit:
  script: npm run test:unit

test-integration:
  script: npm run test:integration

deploy-staging:
  script: deploy staging

# ❌ BAD: Vague names
job1:
  script: npm build

job2:
  script: npm test
```

### Stage Names

**Use short, standard stage names**.

```yaml
stages:
  - build      # ✅ Standard, clear
  - test       # ✅ Standard, clear
  - deploy     # ✅ Standard, clear
  - .pre       # ✅ GitLab special stage
  - .post      # ✅ GitLab special stage
```

### Variable Names

**Use UPPER_SNAKE_CASE for variables**.

```yaml
variables:
  NODE_VERSION: "20"
  DOCKER_DRIVER: overlay2
  CACHE_VERSION: "v1"
  DEPLOY_ENVIRONMENT: staging
```

### Environment Names

**Use lowercase for environment names**.

```yaml
deploy-staging:
  environment:
    name: staging  # ✅ lowercase
    url: https://staging.example.com

deploy-production:
  environment:
    name: production  # ✅ lowercase
    url: https://example.com
```

---

## Pipeline Architecture

### 1. Basic Three-Stage Pipeline

**Simple, linear pipeline** for straightforward projects.

```yaml
stages:
  - build
  - test
  - deploy

build:
  stage: build
  script: make build

test:
  stage: test
  script: make test

deploy:
  stage: deploy
  script: make deploy
  when: manual
```

**Use when:**
- Simple projects with linear workflows
- Few dependencies between jobs
- Quick prototyping

### 2. DAG Pipeline with Needs

**Optimized pipeline** for complex projects with independent components.

```yaml
stages:
  - build
  - test
  - security
  - deploy

build-frontend:
  stage: build
  script: build frontend

build-backend:
  stage: build
  script: build backend

test-frontend:
  stage: test
  needs: [build-frontend]
  script: test frontend

test-backend:
  stage: test
  needs: [build-backend]
  script: test backend

security-scan:
  stage: security
  needs: []  # Runs immediately
  script: security scan

deploy:
  stage: deploy
  needs: [test-frontend, test-backend, security-scan]
  script: deploy
```

**Use when:**
- Large projects with multiple components
- Need faster pipeline execution
- Clear dependencies between jobs

### 3. Parent-Child Pipelines

**Hierarchical pipelines** for monorepos or complex orchestration.

```yaml
# Parent pipeline
stages:
  - trigger

trigger-frontend:
  stage: trigger
  trigger:
    include: frontend/.gitlab-ci.yml
    strategy: depend

trigger-backend:
  stage: trigger
  trigger:
    include: backend/.gitlab-ci.yml
    strategy: depend
```

**Use when:**
- Monorepo with multiple projects
- Need isolated pipeline configurations
- Complex orchestration scenarios

### 4. Multi-Project Pipelines

**Cross-project orchestration** triggering other projects.

```yaml
trigger-downstream:
  stage: deploy
  trigger:
    project: group/downstream-project
    branch: main
    strategy: depend
```

**Use when:**
- Microservices deployment
- Library updates triggering dependent projects
- Complex multi-project workflows

---

## Common Anti-Patterns

### 1. Using `:latest` Tag

```yaml
# ❌ ANTI-PATTERN
test:
  image: node:latest
  script: npm test

# ✅ CORRECT
test:
  image: node:20.11-alpine3.19
  script: npm test
```

### 2. Hardcoding Secrets

```yaml
# ❌ ANTI-PATTERN
deploy:
  script:
    - deploy --api-key abc123xyz

# ✅ CORRECT
deploy:
  script:
    - deploy --api-key $API_KEY
```

### 3. Using Deprecated `only`/`except`

```yaml
# ❌ ANTI-PATTERN
deploy:
  only:
    - main
  except:
    - tags

# ✅ CORRECT
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_COMMIT_TAG == null
```

### 4. Not Using Cache

```yaml
# ❌ ANTI-PATTERN (installs dependencies every time)
test:
  script:
    - npm install
    - npm test

# ✅ CORRECT (caches node_modules)
test:
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  script:
    - npm ci
    - npm test
```

### 5. No Artifact Expiration

```yaml
# ❌ ANTI-PATTERN (artifacts stored forever)
build:
  artifacts:
    paths:
      - dist/

# ✅ CORRECT (artifacts expire)
build:
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour
```

### 6. Missing Resource Groups for Deployments

```yaml
# ❌ ANTI-PATTERN (concurrent deployments possible)
deploy-production:
  script: deploy production

# ✅ CORRECT (prevents concurrent deployments)
deploy-production:
  script: deploy production
  resource_group: production
```

### 7. Overly Broad Artifact Paths

```yaml
# ❌ ANTI-PATTERN
build:
  artifacts:
    paths:
      - ./**  # Includes everything

# ✅ CORRECT
build:
  artifacts:
    paths:
      - dist/
      - build/
    exclude:
      - "**/*.env"
```

### 8. Not Using Needs for DAG Optimization

```yaml
# ❌ ANTI-PATTERN (waits for all stage jobs)
stages:
  - build
  - test

build-frontend:
  stage: build
  script: build frontend

build-backend:
  stage: build
  script: build backend

test-frontend:
  stage: test
  script: test frontend  # Waits for build-backend too

# ✅ CORRECT (starts as soon as build-frontend completes)
test-frontend:
  stage: test
  needs: [build-frontend]
  script: test frontend
```

---

## Summary Checklist

When creating GitLab CI/CD pipelines, ensure:

- [ ] Docker images pinned to specific versions
- [ ] Secrets stored in masked CI/CD variables
- [ ] Cache configured for dependencies
- [ ] Artifacts have appropriate expiration times
- [ ] `needs` keyword used for DAG optimization
- [ ] `rules` used instead of deprecated `only`/`except`
- [ ] `resource_group` used for deployment jobs
- [ ] `interruptible: true` for test jobs
- [ ] Retry configured for flaky operations
- [ ] Timeout set for long-running jobs
- [ ] `extends` or `include` used to reduce duplication
- [ ] Descriptive job and stage names
- [ ] Cleanup operations in `after_script`
- [ ] Manual approval for production deployments
- [ ] Security scanning included in pipeline

---

**Reference this document when generating or reviewing GitLab CI/CD pipelines to ensure best practices are followed.**
