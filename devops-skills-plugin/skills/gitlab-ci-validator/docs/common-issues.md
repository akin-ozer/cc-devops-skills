# Common GitLab CI/CD Issues and Solutions

## Syntax Errors

### Invalid YAML Syntax

**Problem:** YAML formatting errors prevent pipeline execution.

**Common causes:**
- Inconsistent indentation (mixing tabs and spaces)
- Missing colons after keys
- Incorrect list formatting
- Unquoted special characters

**Examples:**

```yaml
# ❌ Wrong indentation
job_name:
script:
  - echo "test"

# ✅ Correct indentation
job_name:
  script:
    - echo "test"

# ❌ Missing colon
job_name
  script:
    - echo "test"

# ✅ Correct syntax
job_name:
  script:
    - echo "test"

# ❌ Unquoted special characters
job_name:
  script:
    - echo $VAR: value

# ✅ Quoted special characters
job_name:
  script:
    - echo "$VAR: value"
```

**Solution:** Use a YAML linter or GitLab's CI Lint tool to validate syntax.

### Reserved Keyword as Job Name

**Problem:** Using reserved keywords as job names causes validation errors.

**Reserved keywords:**
- `image`, `services`, `stages`, `types`
- `before_script`, `after_script`, `variables`
- `cache`, `include`, `pages`, `default`, `workflow`

```yaml
# ❌ Using reserved keyword
image:
  stage: build
  script:
    - echo "build"

# ✅ Use a different name
build_image:
  stage: build
  script:
    - echo "build"
```

## Job Configuration Issues

### Missing `script` Keyword

**Problem:** Every job must have a `script` section (except some special jobs like `trigger`).

```yaml
# ❌ Missing script
test_job:
  stage: test

# ✅ With script
test_job:
  stage: test
  script:
    - npm test
```

### Undefined Stage Reference

**Problem:** Job references a stage that doesn't exist in `stages` definition.

```yaml
# ❌ Undefined stage
stages:
  - build
  - test

deploy_job:
  stage: deploy  # 'deploy' stage not defined
  script:
    - ./deploy.sh

# ✅ Stage defined
stages:
  - build
  - test
  - deploy

deploy_job:
  stage: deploy
  script:
    - ./deploy.sh
```

### Invalid Job Dependencies

**Problem:** Referencing non-existent jobs in `dependencies` or `needs`.

```yaml
# ❌ References non-existent job
test_job:
  stage: test
  dependencies:
    - build_job  # This job doesn't exist
  script:
    - npm test

# ✅ Valid dependency
build_job:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/

test_job:
  stage: test
  dependencies:
    - build_job
  script:
    - npm test
```

### Circular Dependencies with `needs`

**Problem:** Creating circular dependencies with `needs` keyword.

```yaml
# ❌ Circular dependency
job_a:
  needs: [job_b]
  script: echo "A"

job_b:
  needs: [job_a]
  script: echo "B"

# ✅ Valid DAG
job_a:
  script: echo "A"

job_b:
  needs: [job_a]
  script: echo "B"
```

## Variable Issues

### Undefined Variable Reference

**Problem:** Referencing variables that don't exist.

```yaml
# ❌ Undefined variable
deploy_job:
  script:
    - echo "Deploying to $UNDEFINED_ENV"

# ✅ Define variable
variables:
  DEPLOY_ENV: "staging"

deploy_job:
  script:
    - echo "Deploying to $DEPLOY_ENV"
```

### Variable Scope Issues

**Problem:** Variables not available in expected scope.

```yaml
# ❌ Job variable not available globally
job_a:
  variables:
    MY_VAR: "value"
  script:
    - echo $MY_VAR

job_b:
  script:
    - echo $MY_VAR  # Not available here

# ✅ Use global variable
variables:
  MY_VAR: "value"

job_a:
  script:
    - echo $MY_VAR

job_b:
  script:
    - echo $MY_VAR
```

### Hardcoded Secrets

**Problem:** Sensitive data exposed in pipeline configuration.

```yaml
# ❌ Hardcoded credentials
deploy_job:
  script:
    - export API_KEY="sk_live_1234567890"
    - ./deploy.sh

# ✅ Use CI/CD variables or secrets
deploy_job:
  script:
    - ./deploy.sh  # API_KEY from CI/CD variables
  secrets:
    API_KEY:
      vault: production/api/key@ops
```

## Artifact and Cache Issues

### Artifacts Not Passed Between Jobs

**Problem:** Jobs can't access files from previous jobs.

```yaml
# ❌ No artifacts defined
build_job:
  stage: build
  script:
    - npm run build

test_job:
  stage: test
  script:
    - ls dist/  # Directory doesn't exist

# ✅ With artifacts
build_job:
  stage: build
  script:
    - npm run build
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour

test_job:
  stage: test
  needs: [build_job]
  script:
    - ls dist/  # Now available
```

### Cache Not Working

**Problem:** Dependencies downloaded on every job run.

**Common causes:**
- Wrong cache paths
- Incorrect cache key
- Cache policy misconfiguration
- Runner doesn't support caching

```yaml
# ❌ Wrong cache configuration
test_job:
  cache:
    paths:
      - node_modules/  # Wrong path or not created
  script:
    - npm ci
    - npm test

# ✅ Correct cache configuration
variables:
  npm_config_cache: "$CI_PROJECT_DIR/.npm"

test_job:
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - .npm/
      - node_modules/
  script:
    - npm ci --cache .npm --prefer-offline
    - npm test
```

### Cache vs Artifacts Confusion

**Problem:** Using cache for job outputs instead of artifacts.

```yaml
# ❌ Using cache for build outputs
build_job:
  cache:
    paths:
      - dist/  # Should be artifacts
  script:
    - npm run build

# ✅ Correct usage
build_job:
  cache:
    paths:
      - node_modules/  # Dependencies (cache)
  artifacts:
    paths:
      - dist/  # Build outputs (artifacts)
  script:
    - npm ci
    - npm run build
```

## Rules and Conditions Issues

### Conflicting Rules

**Problem:** Multiple rules that contradict each other.

```yaml
# ❌ Conflicting rules
deploy_job:
  script:
    - ./deploy.sh
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: always
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: never  # Conflicts with above

# ✅ Clear rules
deploy_job:
  script:
    - ./deploy.sh
  rules:
    - if: '$CI_COMMIT_BRANCH == "main" && $CI_PIPELINE_SOURCE != "schedule"'
      when: on_success
    - when: never
```

### Mixing `rules` with `only`/`except`

**Problem:** Cannot use `rules` with `only`/`except` in the same job.

```yaml
# ❌ Mixing rules and only/except
deploy_job:
  script:
    - ./deploy.sh
  only:
    - main
  rules:
    - if: '$CI_COMMIT_TAG'

# ✅ Use rules only
deploy_job:
  script:
    - ./deploy.sh
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
    - if: '$CI_COMMIT_TAG'
```

### Incorrect `changes` Usage

**Problem:** `changes` not working as expected.

```yaml
# ❌ Changes with wrong pipeline source
test_job:
  script:
    - npm test
  rules:
    - changes:
        - src/**/*.js
  # Won't work on branch pipelines without if condition

# ✅ Correct changes usage
test_job:
  script:
    - npm test
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
      changes:
        - src/**/*.js
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
```

## Docker and Service Issues

### Image Pull Failures

**Problem:** Cannot pull Docker images.

**Common causes:**
- Image doesn't exist
- Authentication required
- Network issues
- Using `:latest` without recent pull

```yaml
# ❌ Non-existent or inaccessible image
test_job:
  image: mycompany/nonexistent:latest
  script:
    - npm test

# ✅ Valid, accessible image
test_job:
  image: node:18-alpine
  script:
    - npm test

# ✅ Private registry with authentication
test_job:
  image: registry.gitlab.com/mygroup/myimage:v1.0
  before_script:
    - echo $CI_REGISTRY_PASSWORD | docker login -u $CI_REGISTRY_USER --password-stdin $CI_REGISTRY
  script:
    - npm test
```

### Service Connection Issues

**Problem:** Cannot connect to services (databases, etc.).

```yaml
# ❌ Wrong service alias or missing variables
test_job:
  image: node:18
  services:
    - postgres:14
  script:
    - npm run test:integration  # Connection fails

# ✅ Proper service configuration
test_job:
  image: node:18
  services:
    - name: postgres:14
      alias: postgres
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
    DATABASE_URL: "postgres://test:test@postgres:5432/testdb"
  script:
    - npm run test:integration
```

### Using `:latest` Tag

**Problem:** Unpredictable behavior with `:latest` tags.

```yaml
# ❌ Using latest tag
build_job:
  image: node:latest  # Could change unexpectedly
  script:
    - npm run build

# ✅ Pin specific version
build_job:
  image: node:18.17.0-alpine
  script:
    - npm run build

# ✅ Even better: Use SHA digest
build_job:
  image: node@sha256:a6385a6bb2fdcb7c48fc871e35e32af8daaa82c518f934fcd0e5a42c0dd6ed71
  script:
    - npm run build
```

## Performance Issues

### Slow Pipeline Execution

**Problem:** Pipelines take too long to complete.

**Solutions:**

1. **Use caching:**
```yaml
.node_cache:
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/

build_job:
  extends: .node_cache
  script:
    - npm ci --cache .npm
    - npm run build
```

2. **Use `needs` for parallel execution:**
```yaml
# Instead of sequential stages
build_a:
  stage: build
  script: make build_a

build_b:
  stage: build  # Runs in parallel with build_a
  script: make build_b

test_a:
  stage: test
  needs: [build_a]  # Starts immediately after build_a
  script: make test_a
```

3. **Use parallel jobs:**
```yaml
test_job:
  script:
    - npm test -- --shard=$CI_NODE_INDEX/$CI_NODE_TOTAL
  parallel: 5
```

### Cache Miss Rate High

**Problem:** Cache frequently invalidated or not used.

```yaml
# ❌ Cache key changes too often
test_job:
  cache:
    key: $CI_COMMIT_SHA  # Different for every commit
    paths:
      - node_modules/

# ✅ Stable cache key
test_job:
  cache:
    key: ${CI_COMMIT_REF_SLUG}-${CI_PROJECT_DIR}/package-lock.json
    paths:
      - node_modules/
```

### Downloading Same Artifacts Multiple Times

**Problem:** Multiple jobs downloading same artifacts unnecessarily.

```yaml
# ❌ All artifacts downloaded
build_a:
  artifacts:
    paths:
      - dist_a/

build_b:
  artifacts:
    paths:
      - dist_b/

test_job:
  needs: [build_a, build_b]
  script:
    - test dist_a/  # Only needs dist_a

# ✅ Use dependencies to control downloads
test_job:
  needs:
    - build_a
    - build_b
  dependencies:
    - build_a  # Only download from build_a
  script:
    - test dist_a/
```

## Security Issues

### Secrets in Logs

**Problem:** Sensitive data visible in job logs.

```yaml
# ❌ Secrets printed to logs
deploy_job:
  script:
    - echo "API Key: $API_KEY"  # Visible in logs
    - ./deploy.sh

# ✅ Mask variables and avoid printing
deploy_job:
  script:
    - ./deploy.sh
  # Mark API_KEY as masked in CI/CD settings
```

### Unpinned Dependencies

**Problem:** Vulnerable or malicious dependencies could be installed.

```yaml
# ❌ Unpinned dependencies
install_job:
  script:
    - npm install  # Could install different versions

# ✅ Locked dependencies
install_job:
  script:
    - npm ci  # Uses package-lock.json

# ✅ With hash verification (Python)
install_job:
  script:
    - pip install -r requirements.txt --require-hashes
```

### Insecure Script Patterns

**Problem:** Scripts vulnerable to injection or other attacks.

```yaml
# ❌ Command injection risk
deploy_job:
  script:
    - curl $EXTERNAL_URL | bash  # Dangerous

# ✅ Verify and validate
deploy_job:
  script:
    - curl -o script.sh $EXTERNAL_URL
    - sha256sum -c script.sh.sha256
    - bash script.sh
```

## Environment and Deployment Issues

### Environment Not Created

**Problem:** Deployment environments not showing in GitLab UI.

```yaml
# ❌ Missing environment keyword
deploy_job:
  script:
    - ./deploy.sh staging

# ✅ With environment
deploy_job:
  script:
    - ./deploy.sh staging
  environment:
    name: staging
    url: https://staging.example.com
```

### Manual Jobs Not Stopping Pipeline

**Problem:** Pipeline continues without waiting for manual job.

```yaml
# ❌ Pipeline continues
deploy_staging:
  script:
    - ./deploy.sh
  when: manual

deploy_production:
  needs: [deploy_staging]  # Starts immediately
  script:
    - ./deploy.sh

# ✅ Use allow_failure: false
deploy_staging:
  script:
    - ./deploy.sh
  when: manual
  allow_failure: false  # Pipeline waits

deploy_production:
  needs: [deploy_staging]
  script:
    - ./deploy.sh
```

### Review App Cleanup Issues

**Problem:** Review apps not automatically stopped.

```yaml
# ❌ No cleanup
deploy_review:
  script:
    - ./deploy_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.example.com

# ✅ With auto-stop and stop job
deploy_review:
  script:
    - ./deploy_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.example.com
    on_stop: stop_review
    auto_stop_in: 3 days

stop_review:
  script:
    - ./stop_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual
```

## Runner Issues

### No Runners Available

**Problem:** Jobs stuck in "pending" state.

**Solutions:**
- Check runner tags match job tags
- Verify runners are online and not paused
- Check runner capacity and queue
- Review runner permissions for project

```yaml
# If job requires specific tags
build_job:
  tags:
    - docker
    - linux
  script:
    - make build

# Ensure runners with these tags are available and active
```

### Runner Timeout

**Problem:** Jobs fail due to timeout.

```yaml
# ❌ Default timeout too short
long_running_job:
  script:
    - ./long_process.sh  # Takes > 1 hour

# ✅ Increase timeout
long_running_job:
  script:
    - ./long_process.sh
  timeout: 3h
```

## Include and Template Issues

### Include File Not Found

**Problem:** Cannot find included file.

```yaml
# ❌ Wrong path
include:
  - local: 'templates/ci.yml'  # Missing leading slash

# ✅ Correct path
include:
  - local: '/templates/ci.yml'  # Absolute path from repo root
```

### Circular Includes

**Problem:** Files include each other creating a loop.

```yaml
# File A includes File B
# File B includes File A
# Results in: "Maximum includes depth reached"

# Solution: Restructure includes to avoid circular references
```

### Include with Wrong Project Path

**Problem:** Cannot access files from other projects.

```yaml
# ❌ Wrong project path or no access
include:
  - project: 'wrong-group/wrong-project'
    file: '/templates/ci.yml'

# ✅ Correct project path with access
include:
  - project: 'my-group/templates'
    ref: 'v1.2.3'
    file: '/templates/ci.yml'
```

## Debugging Tips

### Enable Debug Logging

Add debug variables to get more information:

```yaml
variables:
  CI_DEBUG_TRACE: "true"  # Enable debug mode
  CI_DEBUG_SERVICES: "true"  # Debug service connections
```

### Use `echo` for Debugging

Print variable values and script execution:

```yaml
debug_job:
  script:
    - echo "Branch: $CI_COMMIT_BRANCH"
    - echo "Ref: $CI_COMMIT_REF_NAME"
    - env | sort  # Print all environment variables
    - set -x  # Enable command tracing
    - ./my_script.sh
```

### Test Locally

Use tools to test pipelines locally:

```bash
# Using gitlab-ci-local
npm install -g gitlab-ci-local
gitlab-ci-local

# Using gitlab-ci-validate
pip install gitlab-ci-validate
gitlab-ci-validate .gitlab-ci.yml
```

### Use CI Lint Tool

Validate configuration before committing:

1. Navigate to: CI/CD > Pipeline editor > Validate tab
2. Paste your `.gitlab-ci.yml` content
3. Review validation results and errors
4. Or use API: `POST /api/v4/ci/lint`
