# Azure Pipelines Best Practices

This document outlines best practices for creating maintainable, secure, and efficient Azure Pipelines.

## Security Best Practices

### 1. Never Hardcode Secrets

❌ **Bad**:
```yaml
variables:
  API_KEY: 'sk-1234567890abcdef'
  PASSWORD: 'MyP@ssw0rd'
```

✅ **Good**:
```yaml
variables:
- group: 'my-secrets'  # From variable group
- name: API_KEY
  value: $(SecretApiKey)  # From pipeline variables marked as secret
```

### 2. Pin Image and Task Versions

❌ **Bad**:
```yaml
pool:
  vmImage: 'ubuntu-latest'

- task: Docker@2
```

✅ **Good**:
```yaml
pool:
  vmImage: 'ubuntu-22.04'  # Specific version

- task: Docker@2  # Specific major version
```

### 3. Use Service Connections

Store credentials in service connections, not in pipeline variables.

```yaml
- task: Docker@2
  inputs:
    containerRegistry: 'myDockerRegistryServiceConnection'  # Service connection
    command: 'login'
```

### 4. Mark Sensitive Variables as Secret

```yaml
variables:
- name: API_TOKEN
  value: $(SecretToken)

# In Azure DevOps UI, mark variable as secret
```

### 5. Limit Permissions

Use the principle of least privilege for service connections and agent pools.

##  Performance Optimization

### 1. Use Caching

Cache dependencies to speed up builds.

```yaml
- task: Cache@2
  displayName: 'Cache npm packages'
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    restoreKeys: |
      npm | "$(Agent.OS)"
    path: $(Pipeline.Workspace)/.npm

- script: npm ci --cache $(Pipeline.Workspace)/.npm
  displayName: 'Install dependencies'
```

### 2. Optimize Dependencies with `dependsOn` and `condition`

Use explicit dependencies to run jobs in parallel when possible.

```yaml
stages:
- stage: Build
  jobs:
  - job: BuildFrontend
    steps:
    - script: npm run build:frontend

  - job: BuildBackend
    steps:
    - script: npm run build:backend

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestFrontend
    dependsOn: []  # Can start immediately after Build stage
    steps:
    - script: npm test:frontend

  - job: TestBackend
    dependsOn: []  # Can start immediately after Build stage
    steps:
    - script: npm test:backend
```

### 3. Use Shallow Clone

Reduce clone time by limiting git history.

```yaml
steps:
- checkout: self
  clean: true
  fetchDepth: 1  # Shallow clone
```

### 4. Use Artifacts Efficiently

Only publish what's needed and set expiration.

```yaml
- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(Build.ArtifactStagingDirectory)/dist'  # Only dist folder
    artifact: 'webapp'
    publishLocation: 'pipeline'

# Set retention in Azure DevOps project settings
```

### 5. Use Matrix for Parallel Execution

Test across multiple configurations in parallel.

```yaml
strategy:
  matrix:
    node18:
      nodeVersion: '18'
    node20:
      nodeVersion: '20'
    node22:
      nodeVersion: '22'
  maxParallel: 3  # Run 3 at a time
```

## Maintainability

### 1. Use displayName Everywhere

```yaml
- stage: Build
  displayName: 'Build Application'
  jobs:
  - job: BuildJob
    displayName: 'Build and Compile'
    steps:
    - script: npm run build
      displayName: 'Build with npm'
```

### 2. Organize with Stages

Separate concerns into stages for complex pipelines.

```yaml
stages:
- stage: Build
  displayName: 'Build Stage'
  jobs: [...]

- stage: Test
  displayName: 'Test Stage'
  dependsOn: Build
  jobs: [...]

- stage: Deploy
  displayName: 'Deploy Stage'
  dependsOn: Test
  jobs: [...]
```

### 3. Use Templates for Reusability

Extract common logic into templates.

```yaml
# templates/npm-build.yml
steps:
- task: NodeTool@0
  inputs:
    versionSpec: $(nodeVersion)

- task: Cache@2
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    path: $(Pipeline.Workspace)/.npm

- script: npm ci --cache $(Pipeline.Workspace)/.npm
- script: npm run build

# azure-pipelines.yml
steps:
- template: templates/npm-build.yml
  parameters:
    nodeVersion: '20'
```

### 4. Use Variable Groups

Organize variables in variable groups for different environments.

```yaml
variables:
- group: 'dev-variables'
- group: 'common-variables'
```

### 5. Document Your Pipeline

Add comments to explain complex logic.

```yaml
# This pipeline builds the frontend and backend separately,
# then runs integration tests before deploying to staging.

stages:
- stage: Build
  # We build frontend and backend in parallel to save time
  jobs:
  - job: BuildFrontend
    # Frontend uses React and requires Node 20
    steps: [...]
```

## Pipeline Structure

### 1. Naming Conventions

```yaml
# Stage names: PascalCase
- stage: BuildAndTest

# Job names: PascalCase
- job: BuildApplication

# Step displayNames: Sentence case
- script: echo "test"
  displayName: 'Run integration tests'

# Variables: camelCase or snake_case (be consistent)
variables:
  buildConfiguration: 'Release'
  node_version: '20'
```

### 2. Logical Stage Organization

```yaml
stages:
- stage: Build
  jobs: [...]

- stage: UnitTest
  dependsOn: Build
  jobs: [...]

- stage: IntegrationTest
  dependsOn: Build
  jobs: [...]

- stage: DeployStaging
  dependsOn:
  - UnitTest
  - IntegrationTest
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
  jobs: [...]

- stage: DeployProduction
  dependsOn:
  - UnitTest
  - IntegrationTest
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs: [...]
```

### 3. Conditions and Triggers

```yaml
trigger:
  branches:
    include:
    - main
    - develop
    - release/*
  paths:
    exclude:
    - docs/**
    - README.md

pr:
  branches:
    include:
    - main
  paths:
    exclude:
    - docs/**
```

## Deployment Best Practices

### 1. Use Deployment Jobs for Environments

```yaml
- deployment: DeployWeb
  displayName: 'Deploy to Production'
  pool:
    vmImage: 'ubuntu-22.04'
  environment:
    name: production
    resourceName: webapp
  strategy:
    runOnce:
      deploy:
        steps:
        - script: echo "Deploying"
```

### 2. Add Manual Approval for Production

Configure approvals in the environment settings in Azure DevOps.

### 3. Use Deployment Strategies

```yaml
# For zero-downtime deployments
strategy:
  canary:
    increments: [10, 25, 50, 100]
    preDeploy:
      steps:
      - script: echo "Pre-deploy checks"
    deploy:
      steps:
      - script: echo "Deploy to $(strategy.canary.increment)% of instances"
    postDeploy:
      steps:
      - script: echo "Monitor deployment"
```

### 4. Implement Rollback Strategy

```yaml
strategy:
  runOnce:
    deploy:
      steps:
      - script: ./deploy.sh

    on:
      failure:
        steps:
        - script: ./rollback.sh
          displayName: 'Rollback on failure'
```

## Testing

### 1. Publish Test Results

```yaml
- script: npm test -- --coverage --ci --reporters=default --reporters=jest-junit
  displayName: 'Run tests'

- task: PublishTestResults@2
  condition: succeededOrFailed()  # Always publish results
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/junit.xml'
    failTaskOnFailedTests: true
```

### 2. Publish Code Coverage

```yaml
- task: PublishCodeCoverageResults@1
  inputs:
    codeCoverageTool: 'Cobertura'
    summaryFileLocation: '$(System.DefaultWorkingDirectory)/**/coverage/cobertura-coverage.xml'
```

### 3. Run Linting and Security Scans

```yaml
- script: npm run lint
  displayName: 'Run ESLint'

- script: npm audit
  displayName: 'Security audit'
  continueOnError: true  # Don't fail build on audit issues
```

## Error Handling

### 1. Set Timeouts

```yaml
jobs:
- job: Build
  timeoutInMinutes: 30  # Prevent hung jobs
  cancelTimeoutInMinutes: 5
```

### 2. Use Conditions Appropriately

```yaml
# Always run cleanup
- script: ./cleanup.sh
  displayName: 'Cleanup'
  condition: always()

# Only on failure
- script: ./send-alert.sh
  displayName: 'Send failure notification'
  condition: failed()

# Only on success
- script: ./deploy.sh
  displayName: 'Deploy'
  condition: succeeded()
```

### 3. Use continueOnError for Non-Critical Steps

```yaml
- script: npm run lint
  displayName: 'Run linter'
  continueOnError: true  # Don't fail the pipeline if linting fails
```

## CI/CD Patterns

### 1. Multi-Environment Deployment

```yaml
parameters:
- name: deployToStaging
  type: boolean
  default: true
- name: deployToProduction
  type: boolean
  default: false

stages:
- stage: Build
  jobs: [...]

- stage: DeployStaging
  condition: eq(parameters.deployToStaging, true)
  jobs:
  - deployment: DeployStaging
    environment: staging

- stage: DeployProduction
  condition: and(succeeded(), eq(parameters.deployToProduction, true))
  dependsOn:
  - Build
  - DeployStaging
  jobs:
  - deployment: DeployProduction
    environment: production
```

### 2. Feature Branch Builds

```yaml
trigger:
  branches:
    include:
    - main
    - feature/*

# Only deploy from main
- stage: Deploy
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
  jobs: [...]
```

### 3. Pull Request Validation

```yaml
pr:
  branches:
    include:
    - main
  paths:
    include:
    - src/**

stages:
- stage: PRValidation
  jobs:
  - job: BuildAndTest
    steps:
    - script: npm install
    - script: npm run build
    - script: npm test
    - script: npm run lint
```

## Common Anti-Patterns to Avoid

### ❌ Avoid

1. **Using `latest` tags for images or tasks**
2. **Hardcoding secrets in pipeline files**
3. **Not using caching for dependencies**
4. **Not publishing test results**
5. **Long-running jobs without timeouts**
6. **Mixing stages/jobs/steps at root level**
7. **Using `@0` for task versions (deprecated)**
8. **Not using displayName**
9. **Creating monolithic single-stage pipelines for complex workflows**
10. **Not using templates for repeated logic**

## Summary Checklist

Before committing your pipeline:

- [ ] All secrets are in variables/service connections, not hardcoded
- [ ] All images and tasks are pinned to specific versions
- [ ] displayName is used for all stages, jobs, and complex steps
- [ ] Caching is implemented for package managers
- [ ] Test results and coverage are published
- [ ] Timeout values are set for long-running jobs
- [ ] Deployment jobs use environments for tracking
- [ ] Templates are used for repeated logic
- [ ] Conditions are used to control deployment to production
- [ ] Pipeline is validated before committing

## Further Reading

- [Azure Pipelines Best Practices - Microsoft Learn](https://learn.microsoft.com/en-us/azure/devops/pipelines/best-practices/)
- [Azure Pipelines Security](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/overview)
- [Pipeline caching](https://learn.microsoft.com/en-us/azure/devops/pipelines/release/caching)
- [Pipeline runs](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/runs)