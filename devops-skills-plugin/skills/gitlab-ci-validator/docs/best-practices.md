# GitLab CI/CD Best Practices

## Pipeline Design

### Use Stages Effectively

Organize jobs into logical stages that represent your development workflow:

```yaml
stages:
  - .pre          # Setup and validation
  - build         # Compilation and asset generation
  - test          # Testing and quality checks
  - scan          # Security scanning
  - deploy        # Deployment
  - .post         # Cleanup and notifications
```

### Leverage DAG with `needs`

Create directed acyclic graphs to run jobs as soon as their dependencies complete:

```yaml
stages:
  - build
  - test
  - deploy

build_frontend:
  stage: build
  script: npm run build:frontend

build_backend:
  stage: build
  script: go build ./cmd/server

test_frontend:
  stage: test
  needs: [build_frontend]  # Starts immediately after build_frontend
  script: npm test

test_backend:
  stage: test
  needs: [build_backend]   # Runs in parallel with test_frontend
  script: go test ./...

deploy:
  stage: deploy
  needs:
    - test_frontend
    - test_backend
  script: ./deploy.sh
```

**Benefits:**
- Faster pipeline execution
- Parallel job execution
- Reduced waiting time

### Use `rules` Instead of `only`/`except`

The `rules` keyword is more powerful and flexible:

```yaml
# ❌ Deprecated approach
deploy_job:
  script: ./deploy.sh
  only:
    - main
    - tags
  except:
    - schedules

# ✅ Modern approach
deploy_job:
  script: ./deploy.sh
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_TAG'
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
      when: never
```

## Performance Optimization

### Implement Effective Caching

Cache dependencies to avoid repeated downloads:

```yaml
variables:
  CACHE_VERSION: "v1"

.npm_cache:
  cache:
    key: ${CACHE_VERSION}-${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
    policy: pull-push

install_deps:
  extends: .npm_cache
  script:
    - npm ci --cache .npm

test_job:
  extends: .npm_cache
  cache:
    policy: pull  # Only download, don't upload
  needs: [install_deps]
  script:
    - npm test
```

**Best practices:**
- Use version prefixes in cache keys for invalidation
- Use `pull` policy for read-only jobs
- Cache package manager files (.npm, .pip, .gem)
- Don't cache artifacts (use `artifacts` instead)

### Optimize Artifact Usage

Only save what you need and set appropriate expiration:

```yaml
build_job:
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
      - public/
    exclude:
      - dist/**/*.map  # Exclude source maps if not needed
    expire_in: 1 week  # Clean up old artifacts

test_job:
  script:
    - npm test
  artifacts:
    paths:
      - coverage/
    expire_in: 2 days
    when: always       # Save even on failure
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

### Use Parallel Execution

Speed up testing with parallel jobs:

```yaml
test_job:
  script:
    - npm test -- --shard=$CI_NODE_INDEX/$CI_NODE_TOTAL
  parallel: 5

# Or with matrix for multiple configurations
test_matrix:
  script:
    - npm test
  parallel:
    matrix:
      - NODE_VERSION: ['16', '18', '20']
        OS: ['ubuntu-latest', 'macos-latest']
```

### Make Jobs Interruptible

Allow automatic cancellation of redundant jobs:

```yaml
test_job:
  script:
    - npm test
  interruptible: true  # Cancel if newer pipeline starts

deploy_production:
  script:
    - ./deploy.sh
  interruptible: false  # Never cancel production deployments
```

## Security Best Practices

### Never Hardcode Secrets

```yaml
# ❌ NEVER do this
deploy_job:
  script:
    - export AWS_SECRET_KEY="AKIAIOSFODNN7EXAMPLE"
    - ./deploy.sh

# ✅ Use CI/CD variables or secrets managers
deploy_job:
  script:
    - ./deploy.sh
  variables:
    AWS_REGION: "us-east-1"
  secrets:
    AWS_SECRET_KEY:
      vault: production/aws/credentials@ops
```

### Pin Docker Image Versions

Always use specific versions or SHA digests:

```yaml
# ❌ Avoid using latest tags
build_job:
  image: node:latest
  script: npm build

# ✅ Pin to specific versions
build_job:
  image: node:18.17.0-alpine
  script: npm build

# ✅ Even better: Use SHA digest
build_job:
  image: node@sha256:a6385a6bb2fdcb7c48fc871e35e32af8daaa82c518f934fcd0e5a42c0dd6ed71
  script: npm build
```

### Mask Sensitive Variables

Protect sensitive information in logs:

```yaml
variables:
  PUBLIC_API_URL: "https://api.example.com"

# In GitLab UI, mark these as:
# - Protected (only available on protected branches)
# - Masked (hidden in logs)
# - Hidden (not visible in settings)
```

### Validate External Inputs

When using pipeline variables or inputs, validate them:

```yaml
validate_input:
  stage: .pre
  script:
    - |
      if [[ ! "$DEPLOY_ENV" =~ ^(staging|production)$ ]]; then
        echo "Invalid DEPLOY_ENV: $DEPLOY_ENV"
        exit 1
      fi
```

### Lock Dependencies

Pin exact versions to avoid supply chain attacks:

```yaml
# For npm
install_deps:
  script:
    - npm ci  # Uses package-lock.json

# For Python with hash verification
install_deps:
  script:
    - pip install -r requirements.txt --require-hashes

# For Go
verify_deps:
  script:
    - go mod verify
```

### Pin Include References

Reference specific commits or protected tags:

```yaml
# ❌ Avoid branch references
include:
  - project: 'my-group/templates'
    file: '/templates/.gitlab-ci.yml'
    ref: main

# ✅ Use specific commit SHAs
include:
  - project: 'my-group/templates'
    file: '/templates/.gitlab-ci.yml'
    ref: 'a1b2c3d4e5f6'

# ✅ Or protected tags
include:
  - project: 'my-group/templates'
    file: '/templates/.gitlab-ci.yml'
    ref: 'v1.2.3'
```

## Code Organization

### Use Templates and Extends

Create reusable job templates:

```yaml
.base_deploy:
  stage: deploy
  script:
    - ./deploy.sh
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
  before_script:
    - echo "Deploying to $ENVIRONMENT"

deploy_staging:
  extends: .base_deploy
  variables:
    ENVIRONMENT: staging
  environment:
    name: staging
    url: https://staging.example.com

deploy_production:
  extends: .base_deploy
  variables:
    ENVIRONMENT: production
  environment:
    name: production
    url: https://example.com
  when: manual
  only:
    - main
```

### Use YAML Anchors

Reduce repetition with YAML anchors:

```yaml
.default_retry: &default_retry
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

.node_cache: &node_cache
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/

build_job:
  <<: *default_retry
  <<: *node_cache
  script:
    - npm run build
```

### Organize with Include

Split large configurations into multiple files:

```yaml
# .gitlab-ci.yml
include:
  - local: '.gitlab/ci/build.yml'
  - local: '.gitlab/ci/test.yml'
  - local: '.gitlab/ci/deploy.yml'
  - local: '.gitlab/ci/security.yml'

stages:
  - build
  - test
  - deploy
```

## Resource Management

### Set Appropriate Timeouts

Prevent jobs from hanging indefinitely:

```yaml
# Project default: Set in UI under Settings > CI/CD

# Job-specific timeout
long_running_job:
  script:
    - ./long_process.sh
  timeout: 3h

quick_job:
  script:
    - ./quick_check.sh
  timeout: 5m
```

### Use Resource Groups

Prevent concurrent deployments:

```yaml
deploy_production:
  stage: deploy
  script:
    - ./deploy.sh
  resource_group: production
  environment:
    name: production
```

### Control Runner Selection

Use tags to select appropriate runners:

```yaml
build_job:
  tags:
    - docker
    - high-cpu
  script:
    - make build

deploy_job:
  tags:
    - deployment
    - protected
  script:
    - ./deploy.sh
```

## Error Handling

### Use allow_failure Strategically

```yaml
# Experimental features that shouldn't block pipeline
experimental_test:
  script:
    - ./experimental_feature_test.sh
  allow_failure: true

# Allow specific exit codes
integration_test:
  script:
    - ./integration_tests.sh
  allow_failure:
    exit_codes:
      - 137  # OOM killed
      - 143  # SIGTERM
```

### Implement Retry Logic

Retry on transient failures:

```yaml
flaky_test:
  script:
    - npm run e2e
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
      - unknown_failure
```

### Use after_script for Cleanup

Ensure cleanup happens regardless of job status:

```yaml
integration_test:
  services:
    - postgres:14
  script:
    - ./run_tests.sh
  after_script:
    - ./cleanup_test_data.sh
```

## Environment Management

### Use Dynamic Environments

Create review apps for merge requests:

```yaml
deploy_review:
  stage: deploy
  script:
    - ./deploy_review_app.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.example.com
    on_stop: stop_review
    auto_stop_in: 3 days
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'

stop_review:
  stage: deploy
  script:
    - ./stop_review_app.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

### Use Environment-Specific Variables

```yaml
variables:
  GLOBAL_VAR: "value"

deploy_staging:
  stage: deploy
  variables:
    DEPLOY_URL: "https://staging.example.com"
    DEBUG_MODE: "true"
  script:
    - ./deploy.sh
  environment:
    name: staging

deploy_production:
  stage: deploy
  variables:
    DEPLOY_URL: "https://example.com"
    DEBUG_MODE: "false"
  script:
    - ./deploy.sh
  environment:
    name: production
```

## Testing Best Practices

### Separate Test Types

Organize tests by scope and speed:

```yaml
unit_test:
  stage: test
  script:
    - npm run test:unit
  artifacts:
    reports:
      junit: junit.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml

integration_test:
  stage: test
  script:
    - npm run test:integration
  needs: [build_job]

e2e_test:
  stage: test
  script:
    - npm run test:e2e
  needs: [deploy_staging]
  allow_failure: true  # E2E tests can be flaky
```

### Use Test Reports

Leverage GitLab's test report features:

```yaml
test_job:
  script:
    - npm test
  artifacts:
    when: always
    reports:
      junit: test-results.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

## Documentation

### Comment Your Pipeline

Add clear comments explaining complex logic:

```yaml
# This job deploys to production only on the main branch
# and requires manual approval for safety
deploy_production:
  stage: deploy
  script:
    - ./deploy.sh
  environment:
    name: production
  when: manual
  rules:
    # Only run on main branch
    - if: '$CI_COMMIT_BRANCH == "main"'
    # Skip on scheduled pipelines
    - if: '$CI_PIPELINE_SOURCE == "schedule"'
      when: never
```

### Use Meaningful Job Names

Choose descriptive names that explain purpose:

```yaml
# ❌ Unclear names
job1:
  script: npm test

job2:
  script: ./script.sh

# ✅ Clear names
unit_tests:
  script: npm run test:unit

deploy_to_staging:
  script: ./deploy.sh staging
```

## Workflow Optimization

### Control Pipeline Creation

Prevent unnecessary pipelines:

```yaml
workflow:
  rules:
    # Run for merge requests
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    # Run for main branch
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
    # Run for tags
    - if: '$CI_COMMIT_TAG'
    # Don't run otherwise
    - when: never
```

### Use Changes Detection

Run jobs only when relevant files change:

```yaml
frontend_test:
  script:
    - npm run test:frontend
  rules:
    - changes:
        - frontend/**/*
        - package.json
        - package-lock.json

backend_test:
  script:
    - go test ./...
  rules:
    - changes:
        - backend/**/*.go
        - go.mod
        - go.sum
```

## Maintenance

### Version Your Pipeline

Track pipeline configuration changes:

```yaml
# Add version comments
# Pipeline version: 2.1.0
# Last updated: 2025-01-15
# Changelog: Added security scanning job

variables:
  PIPELINE_VERSION: "2.1.0"
```

### Regular Audits

Periodically review and optimize:

1. Remove unused jobs and stages
2. Update Docker image versions
3. Review cache effectiveness
4. Check artifact storage usage
5. Update deprecated keywords
6. Review and update security practices

### Monitor Pipeline Performance

Track key metrics:

- Pipeline duration
- Success rate
- Cache hit rate
- Artifact storage usage
- Runner queue times
- Job failure rates

Use GitLab's analytics features to identify bottlenecks and optimization opportunities.
