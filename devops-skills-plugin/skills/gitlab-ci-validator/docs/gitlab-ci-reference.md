# GitLab CI/CD YAML Reference

## Overview

GitLab CI/CD pipelines are defined in `.gitlab-ci.yml` files using YAML syntax. The file must be located at the root of your repository. The order of keywords is not important unless otherwise specified.

## File Structure

```yaml
# Global configuration
default:
  # Default settings for all jobs

include:
  # Import external configurations

stages:
  # Define pipeline stages

variables:
  # Global variables

workflow:
  # Pipeline execution rules

# Job definitions
job_name:
  stage: stage_name
  script:
    - command1
    - command2
```

## Global Keywords

### `default`
Establishes custom default values that are copied to jobs lacking specific keyword definitions.

**Supported keywords:**
- `image`, `services`, `before_script`, `after_script`
- `cache`, `artifacts`, `retry`, `timeout`, `interruptible`
- `tags`, `hooks`

**Example:**
```yaml
default:
  image: ruby:3.0
  retry: 2
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - vendor/
```

### `include`
Imports configuration from external YAML files.

**Types:**
- `local`: Files in same repository
- `project`: Files from other GitLab projects
- `remote`: Files from external URLs
- `template`: GitLab-provided templates
- `component`: CI/CD catalog components

**Example:**
```yaml
include:
  - local: '/templates/.gitlab-ci-template.yml'
  - template: 'Auto-DevOps.gitlab-ci.yml'
  - project: 'my-group/my-project'
    file: '/templates/.gitlab-ci.yml'
  - remote: 'https://example.com/.gitlab-ci.yml'
  - component: $CI_SERVER_FQDN/my-org/security/secret-detection@1.0
```

### `stages`
Defines the names and order of pipeline stages. Jobs in the same stage run in parallel.

**Default stages (if not defined):**
1. `.pre`
2. `build`
3. `test`
4. `deploy`
5. `.post`

**Example:**
```yaml
stages:
  - build
  - test
  - deploy
  - cleanup
```

### `variables`
Sets CI/CD variables available to all jobs or specific jobs.

**Example:**
```yaml
variables:
  DATABASE_URL: "postgres://postgres@postgres/db"
  DEPLOY_NOTE:
    description: "The deployment note"
    value: "Default deployment"

job_name:
  variables:
    DEPLOY_ENV: "production"
```

### `workflow`
Controls pipeline behavior and creation rules.

**Example:**
```yaml
workflow:
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
```

## Job Keywords

### Required Keywords

#### `script`
The only required keyword. Defines shell commands executed by the runner.

**Syntax:**
```yaml
job_name:
  script: "single command"

# OR multi-line
job_name:
  script:
    - command1
    - command2
    - |
      multi-line
      command block
```

### Execution Control

#### `before_script`
Commands running before the `script` section.

**Example:**
```yaml
job_name:
  before_script:
    - echo "Preparing environment"
    - bundle install
  script:
    - bundle exec rspec
```

#### `after_script`
Commands running after `script` completion. Executes in a separate shell context.

**Example:**
```yaml
job_name:
  script:
    - ./deploy.sh
  after_script:
    - ./cleanup.sh
```

#### `stage`
Assigns the job to a specific pipeline stage.

**Example:**
```yaml
build_job:
  stage: build
  script:
    - make build
```

#### `when`
Controls when jobs run.

**Values:**
- `on_success` (default): Run when all previous jobs succeed
- `on_failure`: Run when at least one previous job fails
- `always`: Always run
- `manual`: Require manual action
- `delayed`: Delay job execution
- `never`: Never run

**Example:**
```yaml
cleanup_job:
  stage: cleanup
  script:
    - ./cleanup.sh
  when: always

deploy_job:
  stage: deploy
  script:
    - ./deploy.sh
  when: manual
```

### Artifact Management

#### `artifacts`
Specifies files and directories to save after job completion.

**Sub-keywords:**
- `paths`: File locations to include
- `exclude`: Patterns to exclude
- `expire_in`: Retention duration (default: 30 days)
- `name`: Archive name
- `when`: Upload condition (on_success, on_failure, always)
- `reports`: Collect test/coverage/security reports

**Example:**
```yaml
test_job:
  script:
    - npm test
  artifacts:
    paths:
      - coverage/
      - dist/
    exclude:
      - coverage/**/*.tmp
    expire_in: 1 week
    reports:
      junit: test-results.xml
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura.xml
```

#### `cache`
Defines files cached between job runs for faster execution.

**Sub-keywords:**
- `paths`: Items to cache
- `key`: Cache identifier
- `policy`: Download/upload behavior (pull, push, pull-push)
- `when`: Cache condition (on_success, on_failure, always)
- `untracked`: Cache untracked files

**Example:**
```yaml
build_job:
  script:
    - npm install
    - npm run build
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
      - .npm/
    policy: pull-push

test_job:
  script:
    - npm test
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/
    policy: pull
```

### Job Dependencies

#### `dependencies`
Restricts artifact downloads to specified jobs only.

**Example:**
```yaml
build_job:
  stage: build
  script:
    - make build
  artifacts:
    paths:
      - binaries/

test_job:
  stage: test
  script:
    - ./test.sh
  dependencies:
    - build_job
```

#### `needs`
Executes jobs earlier than stage ordering permits, creating a directed acyclic graph (DAG).

**Example:**
```yaml
build_job:
  stage: build
  script:
    - make build

test_job:
  stage: test
  script:
    - make test
  needs:
    - build_job

deploy_job:
  stage: deploy
  script:
    - make deploy
  needs:
    - test_job
```

### Conditional Execution

#### `rules`
Determines job creation based on conditions. Replaces `only`/`except`.

**Example:**
```yaml
deploy_job:
  script:
    - echo "Deploy to production"
  rules:
    - if: '$CI_COMMIT_BRANCH == "main"'
      when: manual
    - if: '$CI_COMMIT_BRANCH == "staging"'
      when: on_success
    - when: never

test_job:
  script:
    - npm test
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
    - changes:
        - src/**/*.js
        - test/**/*.js
```

#### `allow_failure`
Permits job failure without stopping the pipeline.

**Example:**
```yaml
experimental_test:
  script:
    - experimental_command
  allow_failure: true

# With exit codes
integration_test:
  script:
    - ./integration_tests.sh
  allow_failure:
    exit_codes: [137, 255]
```

### Environment & Deployment

#### `environment`
Specifies deployment target environment.

**Sub-keywords:**
- `name`: Environment name
- `url`: Environment URL
- `on_stop`: Job to stop environment
- `auto_stop_in`: Auto-stop duration
- `action`: Deployment action (start, prepare, stop)

**Example:**
```yaml
deploy_staging:
  stage: deploy
  script:
    - ./deploy.sh staging
  environment:
    name: staging
    url: https://staging.example.com
    on_stop: stop_staging
    auto_stop_in: 1 day

deploy_review:
  stage: deploy
  script:
    - ./deploy.sh review
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_ENVIRONMENT_SLUG.example.com
    on_stop: stop_review
    auto_stop_in: 1 week

stop_review:
  stage: deploy
  script:
    - ./stop_review.sh
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    action: stop
  when: manual
```

### Container Configuration

#### `image`
Specifies Docker container image for job execution.

**Example:**
```yaml
test_job:
  image: node:18-alpine
  script:
    - npm test

# With specific digest (recommended for security)
secure_job:
  image: node@sha256:abc123...
  script:
    - npm run secure-test
```

#### `services`
Defines Docker service images (databases, cache servers, etc.).

**Example:**
```yaml
integration_test:
  image: node:18
  services:
    - name: postgres:14
      alias: postgres
    - name: redis:7-alpine
      alias: cache
  variables:
    POSTGRES_DB: testdb
    POSTGRES_USER: test
    POSTGRES_PASSWORD: test
  script:
    - npm run integration-test
```

### Resource Management

#### `tags`
Selects runners by labels.

**Example:**
```yaml
build_job:
  tags:
    - docker
    - linux

deploy_job:
  tags:
    - kubernetes
    - production
```

#### `timeout`
Sets job-level timeout, overriding project settings.

**Example:**
```yaml
long_running_job:
  script:
    - ./long_process.sh
  timeout: 3h
```

#### `resource_group`
Limits job concurrency within a resource group.

**Example:**
```yaml
deploy_production:
  script:
    - ./deploy.sh
  resource_group: production
```

#### `parallel`
Runs multiple job instances in parallel.

**Example:**
```yaml
test_job:
  script:
    - npm test
  parallel: 5

# With matrix
test_matrix:
  script:
    - bundle exec rspec
  parallel:
    matrix:
      - RUBY_VERSION: ['2.7', '3.0', '3.1']
        DATABASE: ['postgres', 'mysql']
```

#### `interruptible`
Allows job cancellation when made redundant by newer runs.

**Example:**
```yaml
test_job:
  script:
    - npm test
  interruptible: true
```

### Advanced Features

#### `extends`
Inherits configuration from other jobs or templates.

**Example:**
```yaml
.default_retry:
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure

test_job:
  extends: .default_retry
  script:
    - npm test
```

#### `retry`
Auto-retry configuration on failure.

**Example:**
```yaml
test_job:
  script:
    - flaky_test.sh
  retry:
    max: 2
    when:
      - runner_system_failure
      - stuck_or_timeout_failure
      - unknown_failure
```

#### `coverage`
Extracts code coverage metrics via regex.

**Example:**
```yaml
test_job:
  script:
    - npm test
  coverage: '/Coverage: \d+\.\d+/'
```

#### `secrets`
Specifies required CI/CD secrets from external providers.

**Example:**
```yaml
deploy_job:
  script:
    - ./deploy.sh
  secrets:
    DATABASE_PASSWORD:
      vault: production/db/password@ops
      file: false
    API_KEY:
      vault: production/api/key@ops
```

#### `trigger`
Defines downstream pipeline triggers.

**Example:**
```yaml
trigger_downstream:
  stage: deploy
  trigger:
    project: my-group/downstream-project
    branch: main
```

#### `release`
Generates release objects.

**Example:**
```yaml
release_job:
  stage: release
  script:
    - echo "Creating release"
  release:
    tag_name: '$CI_COMMIT_TAG'
    name: 'Release $CI_COMMIT_TAG'
    description: 'Release notes here'
```

## Predefined Variables

Common CI/CD variables available in all pipelines:

- `CI_COMMIT_BRANCH`: Current branch name
- `CI_COMMIT_SHA`: Current commit SHA
- `CI_COMMIT_REF_NAME`: Branch or tag name
- `CI_COMMIT_REF_SLUG`: Lowercased, shortened to 63 bytes
- `CI_COMMIT_TAG`: Commit tag name
- `CI_DEFAULT_BRANCH`: Default branch name
- `CI_ENVIRONMENT_NAME`: Environment name
- `CI_ENVIRONMENT_SLUG`: Simplified environment name
- `CI_JOB_ID`: Job ID
- `CI_JOB_NAME`: Job name
- `CI_JOB_STAGE`: Job stage
- `CI_PIPELINE_ID`: Pipeline ID
- `CI_PIPELINE_SOURCE`: Pipeline trigger source
- `CI_PROJECT_DIR`: Repository clone directory
- `CI_PROJECT_ID`: Project ID
- `CI_PROJECT_NAME`: Project name
- `CI_PROJECT_PATH`: Project path
- `CI_PROJECT_URL`: Project URL
- `CI_REGISTRY`: GitLab container registry URL
- `CI_REGISTRY_IMAGE`: Container registry image path
- `CI_RUNNER_ID`: Runner ID
- `CI_SERVER_URL`: GitLab instance URL

## Reserved Keywords

The following keywords cannot be used as job names:
- `image`
- `services`
- `stages`
- `types`
- `before_script`
- `after_script`
- `variables`
- `cache`
- `include`
- `pages`
- `default`
- `workflow`

## Validation

Use the GitLab CI Lint tool to validate your configuration:
- Web UI: Navigate to Build > Pipeline editor > Validate tab
- API: POST to `/api/v4/ci/lint`
- VS Code: Use GitLab Workflow extension

## Common Patterns

### Anchors and References

```yaml
.default_cache: &default_cache
  cache:
    key: ${CI_COMMIT_REF_SLUG}
    paths:
      - node_modules/

build_job:
  <<: *default_cache
  script:
    - npm install
    - npm run build
```

### Hidden Jobs (Templates)

```yaml
.deploy_template:
  script:
    - ./deploy.sh
  only:
    - main

deploy_staging:
  extends: .deploy_template
  environment:
    name: staging

deploy_production:
  extends: .deploy_template
  environment:
    name: production
  when: manual
```

## Best Practices

1. **Use `rules` instead of `only`/`except`**: More flexible and powerful
2. **Leverage caching**: Cache dependencies between jobs
3. **Use `needs` for DAG pipelines**: Faster execution
4. **Pin Docker images**: Use specific versions or SHA digests
5. **Set artifact expiration**: Avoid storage bloat
6. **Use templates and extends**: DRY principle
7. **Define meaningful stage names**: Clear pipeline flow
8. **Use `interruptible`**: Save resources on redundant jobs
9. **Implement proper error handling**: Use `allow_failure` appropriately
10. **Document your pipeline**: Use comments in YAML