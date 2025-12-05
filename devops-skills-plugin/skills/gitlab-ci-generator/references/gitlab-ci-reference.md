# GitLab CI/CD YAML Syntax Reference

Comprehensive reference for GitLab CI/CD `.gitlab-ci.yml` configuration syntax.

## Table of Contents

1. [Global Keywords](#global-keywords)
2. [Job Keywords](#job-keywords)
3. [Script Execution](#script-execution)
4. [Artifacts and Cache](#artifacts-and-cache)
5. [Rules and Conditions](#rules-and-conditions)
6. [Dependencies and Needs](#dependencies-and-needs)
7. [Docker Configuration](#docker-configuration)
8. [Environment and Deployment](#environment-and-deployment)
9. [Advanced Features](#advanced-features)

---

## Global Keywords

Global keywords control pipeline-wide behavior and configuration.

### `stages`

Defines the order of pipeline stages. Jobs in the same stage run in parallel.

```yaml
stages:
  - build
  - test
  - deploy
```

**Default stages:**
```yaml
stages:
  - .pre       # Special stage, runs before everything
  - build
  - test
  - deploy
  - .post      # Special stage, runs after everything
```

### `default`

Sets default values for all jobs. Job-level configurations override defaults completely (no merging).

```yaml
default:
  image: node:20-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  before_script:
    - echo "Starting job"
  tags:
    - docker
  interruptible: true
  retry:
    max: 1
    when:
      - runner_system_failure
```

### `include`

Imports external YAML configuration files.

```yaml
# Local file from same repository
include:
  - local: '.gitlab/ci/build-jobs.yml'

# File from another project
include:
  - project: 'group/ci-templates'
    ref: main
    file: 'templates/build.yml'

# Remote file via HTTP
include:
  - remote: 'https://example.com/ci-template.yml'

# GitLab CI/CD template
include:
  - template: 'Security/SAST.gitlab-ci.yml'

# CI/CD component
include:
  - component: gitlab.com/my-org/components/build@1.0.0
```

### `variables`

Defines CI/CD variables available to all jobs.

```yaml
variables:
  NODE_VERSION: "20"
  DOCKER_DRIVER: overlay2
  CACHE_VERSION: "v1"
```

**Variable types:**
- `$VARIABLE` - Simple substitution
- `${VARIABLE}` - Explicit variable reference
- `$$VARIABLE` - Escaped variable (passed to script)

### `workflow`

Controls when pipelines run and their auto-cancellation behavior.

```yaml
workflow:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
    - if: $CI_MERGE_REQUEST_ID
    - if: $CI_COMMIT_TAG
  auto_cancel:
    on_new_commit: interruptible
```

---

## Job Keywords

Jobs are the basic building blocks that define what to execute.

### Job Structure

```yaml
job-name:
  stage: build
  image: node:20-alpine
  script:
    - npm ci
    - npm run build
```

**Reserved job names:**
- `image`, `services`, `stages`, `before_script`, `after_script`, `variables`, `cache`, `include`

### `stage`

Assigns the job to a pipeline stage.

```yaml
build-job:
  stage: build  # Default: test
  script: make build
```

### `script` (required)

Shell commands to execute. At least one of `script`, `trigger`, or `extends` is required.

```yaml
build:
  script:
    - echo "Building..."
    - make build
    - make package

# Multi-line script
test:
  script:
    - |
      echo "Running tests"
      npm test
      echo "Tests complete"
```

### `before_script`

Commands executed before `script`. Runs in the same shell context as `script`.

```yaml
test:
  before_script:
    - echo "Setting up..."
    - npm ci
  script:
    - npm test
```

### `after_script`

Commands executed after `script`, runs in a separate shell. Cannot affect job exit code.

```yaml
deploy:
  script:
    - deploy.sh
  after_script:
    - echo "Cleaning up..."
    - rm -rf temp/
```

**Note:** `after_script` has a separate 5-minute timeout by default.

### `image`

Docker image for job execution.

```yaml
# Simple image
build:
  image: node:20-alpine

# Image with entrypoint override
test:
  image:
    name: my-image:latest
    entrypoint: [""]
```

### `services`

Docker service containers (databases, caches, etc.).

```yaml
test:
  image: node:20-alpine
  services:
    - postgres:15-alpine
    - redis:7-alpine
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: testuser
    POSTGRES_PASSWORD: testpass
```

### `tags`

Selects runners with matching tags.

```yaml
deploy:
  tags:
    - docker
    - production
  script: deploy.sh
```

### `when`

Controls when jobs run.

**Values:**
- `on_success` (default) - Run when all previous stage jobs succeed
- `on_failure` - Run when at least one previous stage job fails
- `always` - Always run regardless of status
- `manual` - Requires manual trigger
- `delayed` - Run after delay
- `never` - Don't run

```yaml
cleanup:
  when: always
  script: cleanup.sh

deploy:
  when: manual
  script: deploy.sh

delayed-job:
  when: delayed
  start_in: 30 minutes
  script: echo "Running after delay"
```

### `allow_failure`

Allows job to fail without blocking pipeline.

```yaml
lint:
  script: npm run lint
  allow_failure: true

# Conditional allow_failure
test-experimental:
  script: npm test
  allow_failure:
    exit_codes: [1, 137]
```

### `retry`

Configures automatic retry on failure.

```yaml
# Simple retry
deploy:
  retry: 2

# Advanced retry configuration
integration-test:
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
      - api_failure
```

**Retry conditions:**
- `always` - Retry on any failure
- `runner_system_failure` - Runner system failed
- `stuck_or_timeout_failure` - Job stuck or timed out
- `script_failure` - Script failed
- `api_failure` - API failure
- `unknown_failure` - Unknown failure

### `timeout`

Job-specific timeout override.

```yaml
test-quick:
  timeout: 10 minutes
  script: npm run test:unit

test-e2e:
  timeout: 1 hour
  script: npm run test:e2e
```

### `interruptible`

Marks job as cancellable when superseded by newer pipelines.

```yaml
test:
  interruptible: true  # Can be canceled
  script: npm test

deploy:
  interruptible: false  # Cannot be canceled
  script: deploy.sh
```

### `resource_group`

Limits job concurrency for resource-sensitive operations.

```yaml
deploy-production:
  resource_group: production
  script: deploy.sh

deploy-staging:
  resource_group: staging
  script: deploy.sh
```

### `parallel`

Runs multiple job instances in parallel.

```yaml
# Parallel with count
test:
  parallel: 5
  script: npm test -- --shard=${CI_NODE_INDEX}/${CI_NODE_TOTAL}

# Parallel with matrix
test-matrix:
  parallel:
    matrix:
      - NODE_VERSION: ['18', '20', '22']
        OS: ['alpine', 'bookworm-slim']
  image: node:${NODE_VERSION}-${OS}
  script: npm test
```

---

## Script Execution

### Multiline Scripts

```yaml
# Using |
test:
  script:
    - |
      echo "Line 1"
      echo "Line 2"
      echo "Line 3"

# Using >
deploy:
  script:
    - >
      kubectl apply -f deployment.yaml
      --namespace production
      --timeout 5m
```

### Error Handling in Scripts

```yaml
# Stop on first error (default)
build:
  script:
    - command1
    - command2  # Won't run if command1 fails

# Continue on error
test:
  script:
    - command1 || true
    - command2  # Runs even if command1 fails
```

---

## Artifacts and Cache

### `artifacts`

Files/directories to preserve after job completion.

```yaml
build:
  script: make build
  artifacts:
    paths:
      - dist/
      - build/
    exclude:
      - "**/*.map"
      - dist/temp/
    expire_in: 1 hour
    when: on_success  # on_success, on_failure, always
    name: "build-${CI_COMMIT_SHORT_SHA}"
```

**Artifact types:**
```yaml
test:
  script: npm test
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml
      dotenv: build.env
```

**Expiration values:**
- `30 minutes`, `1 hour`, `2 hours`
- `1 day`, `2 days`, `1 week`, `1 month`
- `never` - Keep forever

### `cache`

Preserves files between pipeline runs.

```yaml
build:
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
    policy: pull-push
    when: on_success
```

**Cache policies:**
- `pull-push` (default) - Download and upload cache
- `pull` - Only download cache
- `push` - Only upload cache

**Cache keys:**
```yaml
# Branch-based key
cache:
  key: ${CI_COMMIT_REF_SLUG}

# File-based key
cache:
  key:
    files:
      - package-lock.json
    prefix: npm

# Multiple caches
cache:
  - key: npm-cache
    paths:
      - node_modules/
  - key: build-cache
    paths:
      - dist/
```

---

## Rules and Conditions

### `rules`

Determines when to create jobs and which attributes to apply.

```yaml
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: always
    - if: $CI_MERGE_REQUEST_ID
      when: manual
    - when: never  # Default: don't run
```

**Rule clauses:**
- `if` - Variable expressions
- `changes` - File modifications
- `exists` - File existence
- `when` - Execution timing
- `variables` - Dynamic variables
- `allow_failure` - Failure behavior

### Examples

```yaml
# Run on specific branch
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# Run on file changes
test-frontend:
  rules:
    - changes:
        - frontend/**/*

# Run if file exists
docs-build:
  rules:
    - exists:
        - docs/mkdocs.yml

# Complex rules
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_COMMIT_TAG == null
      when: manual
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
      when: on_success
    - when: never
```

### `only` / `except` (Deprecated)

**Note:** Use `rules` instead. `only` and `except` are deprecated.

```yaml
# ❌ Deprecated
deploy:
  only:
    - main
  except:
    - tags

# ✅ Use rules instead
deploy:
  rules:
    - if: $CI_COMMIT_BRANCH == "main" && $CI_COMMIT_TAG == null
```

---

## Dependencies and Needs

### `dependencies`

Restricts artifact downloads from specific jobs.

```yaml
build:
  stage: build
  script: make build
  artifacts:
    paths:
      - dist/

test:
  stage: test
  dependencies: [build]  # Only download artifacts from build
  script: test dist/

deploy:
  stage: deploy
  dependencies: []  # Don't download any artifacts
  script: deploy
```

### `needs`

Creates Directed Acyclic Graph (DAG) for faster pipelines.

```yaml
build-frontend:
  stage: build
  script: build frontend

build-backend:
  stage: build
  script: build backend

test-frontend:
  stage: test
  needs: [build-frontend]  # Starts as soon as build-frontend completes
  script: test frontend

test-backend:
  stage: test
  needs: [build-backend]
  script: test backend

deploy:
  stage: deploy
  needs: [test-frontend, test-backend]
  script: deploy
```

**Needs with artifacts:**
```yaml
deploy:
  needs:
    - job: build
      artifacts: true  # Default
    - job: test
      artifacts: false  # Don't download artifacts
```

---

## Docker Configuration

### Docker-in-Docker (dind)

```yaml
build-docker:
  image: docker:24-dind
  services:
    - docker:24-dind
  variables:
    DOCKER_DRIVER: overlay2
    DOCKER_TLS_CERTDIR: "/certs"
  script:
    - docker build -t myimage .
```

### Kaniko (Rootless)

```yaml
build-kaniko:
  image:
    name: gcr.io/kaniko-project/executor:v1.21.0-debug
    entrypoint: [""]
  script:
    - /kaniko/executor
        --context "${CI_PROJECT_DIR}"
        --dockerfile "${CI_PROJECT_DIR}/Dockerfile"
        --destination "${CI_REGISTRY_IMAGE}:latest"
```

---

## Environment and Deployment

### `environment`

Marks jobs that deploy to environments.

```yaml
deploy-staging:
  environment:
    name: staging
    url: https://staging.example.com
    on_stop: stop-staging
    auto_stop_in: 1 day
    action: start  # start, prepare, stop
  script: deploy staging

stop-staging:
  environment:
    name: staging
    action: stop
  when: manual
  script: stop staging
```

**Kubernetes integration:**
```yaml
deploy-k8s:
  environment:
    name: production
    url: https://example.com
    kubernetes:
      namespace: production
  script: kubectl apply -f deployment.yaml
```

**Dynamic environments:**
```yaml
review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop-review
    auto_stop_in: 1 week
  script: deploy review
  rules:
    - if: $CI_MERGE_REQUEST_ID
```

---

## Advanced Features

### `extends`

Inherits configuration from other jobs.

```yaml
.deploy-template:
  image: alpine:3.19
  before_script:
    - apk add --no-cache curl
  retry:
    max: 2

deploy-staging:
  extends: .deploy-template
  script: deploy staging

deploy-production:
  extends: .deploy-template
  script: deploy production
```

**Multiple inheritance:**
```yaml
.base:
  image: alpine:3.19

.retry:
  retry: 2

deploy:
  extends:
    - .base
    - .retry
  script: deploy
```

### `trigger`

Triggers downstream pipelines.

```yaml
# Trigger another project
trigger-downstream:
  trigger:
    project: group/downstream-project
    branch: main
    strategy: depend  # Wait for downstream pipeline

# Trigger child pipeline
trigger-child:
  trigger:
    include: child-pipeline.yml
    strategy: depend

# Trigger with variables
trigger-deploy:
  trigger:
    project: group/deploy-project
  variables:
    VERSION: $CI_COMMIT_SHORT_SHA
    ENVIRONMENT: production
```

### `coverage`

Extracts code coverage percentage from job output.

```yaml
test:
  script: npm test
  coverage: '/Coverage: \d+\.\d+%/'
```

### `release`

Creates GitLab releases.

```yaml
release:
  stage: deploy
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  rules:
    - if: $CI_COMMIT_TAG
  script:
    - echo "Creating release"
  release:
    tag_name: $CI_COMMIT_TAG
    name: 'Release $CI_COMMIT_TAG'
    description: 'Release notes for $CI_COMMIT_TAG'
```

### `secrets`

Retrieves secrets from external sources.

```yaml
deploy:
  secrets:
    DATABASE_PASSWORD:
      vault: production/db/password@secret
      file: false
```

### `inherit`

Controls inheritance of global defaults.

```yaml
job:
  inherit:
    default: false  # Don't inherit default settings
    variables: [VAR1, VAR2]  # Only inherit specific variables
```

---

## Predefined CI/CD Variables

Common GitLab CI/CD variables:

### Pipeline Variables
- `$CI_PIPELINE_ID` - Pipeline ID
- `$CI_PIPELINE_IID` - Pipeline IID (internal ID)
- `$CI_PIPELINE_SOURCE` - Pipeline source (push, merge_request_event, etc.)
- `$CI_PIPELINE_URL` - Pipeline URL

### Commit Variables
- `$CI_COMMIT_SHA` - Full commit SHA
- `$CI_COMMIT_SHORT_SHA` - Short commit SHA (8 chars)
- `$CI_COMMIT_BRANCH` - Branch name
- `$CI_COMMIT_TAG` - Tag name (if pipeline for tag)
- `$CI_COMMIT_REF_NAME` - Branch or tag name
- `$CI_COMMIT_REF_SLUG` - Slugified branch/tag name
- `$CI_COMMIT_MESSAGE` - Commit message
- `$CI_COMMIT_AUTHOR` - Commit author

### Job Variables
- `$CI_JOB_ID` - Job ID
- `$CI_JOB_NAME` - Job name
- `$CI_JOB_STAGE` - Job stage
- `$CI_JOB_URL` - Job URL
- `$CI_JOB_TOKEN` - Job token for API access
- `$CI_NODE_INDEX` - Job index in parallel jobs (1-based)
- `$CI_NODE_TOTAL` - Total number of parallel jobs

### Project Variables
- `$CI_PROJECT_ID` - Project ID
- `$CI_PROJECT_NAME` - Project name
- `$CI_PROJECT_PATH` - Project path (group/project)
- `$CI_PROJECT_DIR` - Working directory
- `$CI_PROJECT_URL` - Project URL

### Registry Variables
- `$CI_REGISTRY` - GitLab Container Registry URL
- `$CI_REGISTRY_IMAGE` - Full image path
- `$CI_REGISTRY_USER` - Registry username
- `$CI_REGISTRY_PASSWORD` - Registry password

### Merge Request Variables
- `$CI_MERGE_REQUEST_ID` - MR ID
- `$CI_MERGE_REQUEST_IID` - MR IID
- `$CI_MERGE_REQUEST_SOURCE_BRANCH_NAME` - Source branch
- `$CI_MERGE_REQUEST_TARGET_BRANCH_NAME` - Target branch

---

## YAML Anchors and Aliases

YAML anchors for reusing configuration within a file.

```yaml
# Define anchor
.retry-config: &retry-config
  retry:
    max: 2
    when:
      - runner_system_failure

# Use anchor
job1:
  <<: *retry-config
  script: command1

job2:
  <<: *retry-config
  script: command2
```

**Merge multiple anchors:**
```yaml
.cache: &cache
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

.image: &image
  image: node:20-alpine

build:
  <<: [*cache, *image]
  script: npm run build
```

---

## Complete Example

```yaml
# Global configuration
stages:
  - build
  - test
  - security
  - deploy

variables:
  NODE_VERSION: "20"
  DOCKER_DRIVER: overlay2

default:
  image: node:${NODE_VERSION}-alpine
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
  tags:
    - docker
  interruptible: true

# Hidden template
.deploy-template:
  before_script:
    - echo "Deploying to ${ENVIRONMENT}"
  retry:
    max: 2
    when:
      - runner_system_failure
  resource_group: ${ENVIRONMENT}

# Build job
build:
  stage: build
  script:
    - npm ci
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

# Test jobs
test-unit:
  stage: test
  needs: []
  script:
    - npm ci
    - npm test
  coverage: '/Coverage: \d+\.\d+%/'
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

test-lint:
  stage: test
  needs: []
  script:
    - npm ci
    - npm run lint
  allow_failure: true

# Security scanning
include:
  - template: Security/SAST.gitlab-ci.yml

# Deployment jobs
deploy-staging:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: staging
  needs: [build, test-unit]
  environment:
    name: staging
    url: https://staging.example.com
  script:
    - ./deploy.sh staging
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy-production:
  extends: .deploy-template
  stage: deploy
  variables:
    ENVIRONMENT: production
  needs: [build, test-unit]
  environment:
    name: production
    url: https://example.com
  script:
    - ./deploy.sh production
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/
  when: manual
```

---

## Additional Resources

- Official GitLab CI/CD YAML reference: https://docs.gitlab.com/ci/yaml/
- GitLab CI/CD examples: https://docs.gitlab.com/ci/examples/
- GitLab CI/CD templates: https://gitlab.com/gitlab-org/gitlab/-/tree/master/lib/gitlab/ci/templates

---

**Use this reference when generating or troubleshooting GitLab CI/CD configurations.**