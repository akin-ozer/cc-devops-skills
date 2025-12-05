# Azure Pipelines YAML Schema Reference

This document provides a comprehensive reference for Azure Pipelines YAML syntax and structure.

## Pipeline Structure

Azure Pipelines follow a hierarchical structure:

```
Pipeline
└── Stages
    └── Jobs
        └── Steps
```

### Basic Pipeline

```yaml
# Minimal pipeline with implicit stage
trigger:
  - main

pool:
  vmImage: 'ubuntu-22.04'

steps:
- script: echo "Hello World"
  displayName: 'Run a one-line script'
```

### Multi-Stage Pipeline

```yaml
stages:
- stage: Build
  displayName: 'Build Stage'
  jobs:
  - job: BuildJob
    displayName: 'Build Job'
    pool:
      vmImage: 'ubuntu-22.04'
    steps:
    - script: npm run build
      displayName: 'Build Application'

- stage: Deploy
  displayName: 'Deploy Stage'
  dependsOn: Build
  jobs:
  - deployment: DeployJob
    displayName: 'Deploy to Production'
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploying..."
            displayName: 'Deploy'
```

## Root-Level Keywords

### trigger

Defines CI triggers (when the pipeline should run automatically).

```yaml
# Simple trigger
trigger:
  - main
  - develop

# Advanced trigger with path filters
trigger:
  branches:
    include:
    - main
    - release/*
    exclude:
    - feature/*
  paths:
    include:
    - src/**
    exclude:
    - docs/**
  tags:
    include:
    - v*
```

### pr

Defines pull request triggers.

```yaml
pr:
  branches:
    include:
    - main
  paths:
    exclude:
    - docs/**
```

### schedules

Defines scheduled triggers (cron syntax).

```yaml
schedules:
- cron: "0 0 * * *"
  displayName: Daily midnight build
  branches:
    include:
    - main
  always: true
```

### resources

Defines external resources used by the pipeline.

```yaml
resources:
  repositories:
  - repository: templates
    type: github
    name: org/repo
    ref: refs/heads/main

  pipelines:
  - pipeline: upstream
    source: 'Upstream Pipeline'
    trigger:
      branches:
      - main

  containers:
  - container: linux
    image: ubuntu:22.04

  packages:
  - package: mypackage
    type: npm
    connection: npmConnection
    name: '@scope/package'
    version: '1.0.0'
```

### pool

Defines the default agent pool for all jobs.

```yaml
# Microsoft-hosted agent
pool:
  vmImage: 'ubuntu-22.04'

# Self-hosted agent pool
pool:
  name: 'MyAgentPool'
  demands:
  - agent.os -equals Linux
```

### variables

Defines pipeline-level variables.

```yaml
variables:
  buildConfiguration: 'Release'
  vmImage: 'ubuntu-22.04'

# Variable groups
variables:
- group: 'my-variable-group'
- name: customVar
  value: 'customValue'

# Template variables
variables:
- template: variables-template.yml
```

### parameters

Defines runtime parameters (user input when pipeline runs).

```yaml
parameters:
- name: environment
  displayName: 'Target Environment'
  type: string
  default: 'staging'
  values:
  - dev
  - staging
  - production

- name: runTests
  displayName: 'Run Tests'
  type: boolean
  default: true

- name: regions
  displayName: 'Deployment Regions'
  type: object
  default:
    - westus
    - eastus
```

## Stages

Stages represent major divisions in your pipeline (e.g., Build, Test, Deploy).

```yaml
stages:
- stage: Build
  displayName: 'Build Stage'

  # Stage condition
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')

  # Stage dependencies
  dependsOn: []  # No dependencies, can run immediately

  # Stage variables
  variables:
    stageVar: 'value'

  jobs:
  - job: BuildJob
    steps:
    - script: npm run build
```

### Stage Properties

- `stage`: Unique identifier
- `displayName`: Human-readable name
- `dependsOn`: List of stages to wait for
- `condition`: Condition to run the stage
- `variables`: Stage-specific variables
- `jobs`: Jobs to run in this stage

## Jobs

Jobs represent a series of steps that run sequentially on the same agent.

### Regular Job

```yaml
jobs:
- job: BuildJob
  displayName: 'Build Application'

  # Job timeout (default: 60 minutes)
  timeoutInMinutes: 30

  # Job cancellation timeout
  cancelTimeoutInMinutes: 5

  # Pool for this job
  pool:
    vmImage: 'ubuntu-22.04'

  # Job dependencies
  dependsOn: []

  # Job condition
  condition: succeeded()

  # Continue on error
  continueOnError: false

  # Job variables
  variables:
    jobVar: 'value'

  # Job strategy (matrix, parallel)
  strategy:
    matrix:
      linux:
        imageName: 'ubuntu-22.04'
      mac:
        imageName: 'macOS-12'
      windows:
        imageName: 'windows-2022'

  steps:
  - script: npm run build
```

### Deployment Job

Deployment jobs are special jobs for deploying to environments with deployment history and approvals.

```yaml
jobs:
- deployment: DeployWeb
  displayName: 'Deploy Web App'

  # Target environment
  environment:
    name: production
    resourceName: web-app
    resourceType: Kubernetes

  # Deployment strategy
  strategy:
    runOnce:
      preDeploy:
        steps:
        - script: echo "Pre-deploy"

      deploy:
        steps:
        - script: echo "Deploying"

      routeTraffic:
        steps:
        - script: echo "Routing traffic"

      postRouteTraffic:
        steps:
        - script: echo "Post routing"

      on:
        failure:
          steps:
          - script: echo "Deployment failed"

        success:
          steps:
          - script: echo "Deployment succeeded"
```

### Deployment Strategies

#### runOnce

```yaml
strategy:
  runOnce:
    deploy:
      steps:
      - script: echo "Deploying"
```

#### rolling

```yaml
strategy:
  rolling:
    maxParallel: 2
    preDeploy:
      steps:
      - script: echo "Pre-deploy"
    deploy:
      steps:
      - script: echo "Deploy"
    postDeploy:
      steps:
      - script: echo "Post-deploy"
```

#### canary

```yaml
strategy:
  canary:
    increments: [10, 20, 50]
    preDeploy:
      steps:
      - script: echo "Pre-deploy"
    deploy:
      steps:
      - script: echo "Deploy $(strategy.canary.increment)%"
    postDeploy:
      steps:
      - script: echo "Post-deploy"
```

## Steps

Steps are the individual tasks that run in a job.

### Script Step

```yaml
steps:
- script: echo "Hello World"
  displayName: 'Run Script'
  workingDirectory: $(Build.SourcesDirectory)
  failOnStderr: false
  condition: succeeded()
  env:
    MY_VAR: value
```

### Bash Step

```yaml
steps:
- bash: |
    echo "Multi-line bash script"
    npm install
    npm test
  displayName: 'Run Bash Script'
```

### PowerShell Step

```yaml
steps:
- powershell: |
    Write-Host "PowerShell script"
    Get-ChildItem
  displayName: 'Run PowerShell'
```

### Task Step

```yaml
steps:
- task: TaskName@version
  displayName: 'Task Display Name'
  inputs:
    inputName: value
  condition: succeeded()
  continueOnError: false
  enabled: true
  env:
    VARIABLE: value
  timeoutInMinutes: 0
```

### Checkout Step

```yaml
steps:
- checkout: self
  clean: true
  fetchDepth: 1
  lfs: false
  submodules: false
  persistCredentials: false
```

### Download Step

```yaml
steps:
- download: current
  artifact: artifactName
  patterns: '**/*.zip'

- download: upstream
  artifact: artifactName
```

### Publish Step

```yaml
steps:
- publish: $(Build.ArtifactStagingDirectory)
  artifact: drop
  displayName: 'Publish Artifact'
```

## Conditions

Conditions control when stages, jobs, or steps run.

### Built-in Conditions

```yaml
condition: succeeded()           # Previous succeeded (default)
condition: failed()              # Previous failed
condition: succeededOrFailed()   # Previous completed
condition: always()              # Always run
condition: canceled()            # Pipeline was canceled
```

### Custom Conditions

```yaml
# Variable equality
condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')

# Contains check
condition: contains(variables['Build.SourceBranch'], 'release')

# And/Or/Not
condition: and(succeeded(), eq(variables['environment'], 'prod'))
condition: or(eq(variables['Build.Reason'], 'PullRequest'), eq(variables['Build.Reason'], 'Manual'))
condition: not(eq(variables['Skip'], 'true'))

# StartsWith/EndsWith
condition: startsWith(variables['Build.SourceBranch'], 'refs/heads/feature/')
condition: endsWith(variables['artifactName'], '.zip')
```

## Expressions and Variables

### Predefined Variables

```yaml
# Build variables
$(Build.BuildId)
$(Build.BuildNumber)
$(Build.SourceBranch)
$(Build.SourceVersion)
$(Build.Reason)
$(Build.ArtifactStagingDirectory)
$(Build.SourcesDirectory)

# Agent variables
$(Agent.OS)
$(Agent.MachineName)
$(Agent.WorkFolder)

# System variables
$(System.TeamProject)
$(System.StageName)
$(System.JobName)
$(System.HostType)

# Pipeline variables
$(Pipeline.Workspace)
```

### Variable Syntax

```yaml
# Macro syntax (processed at queue time)
$(variableName)

# Template expression syntax (processed at compile time)
${{ variables.variableName }}

# Runtime expression syntax (processed at runtime)
$[variables.variableName]
```

### Accessing Job Outputs

```yaml
# In the same stage
dependencies.jobName.outputs['stepName.variableName']

# Across stages
stageDependencies.stageName.jobName.outputs['stepName.variableName']
```

## Template Syntax

### Template Reference

```yaml
# Include template
- template: path/to/template.yml
  parameters:
    paramName: value

# Extends template
extends:
  template: path/to/template.yml
  parameters:
    paramName: value
```

### Template Parameters

```yaml
# In template file
parameters:
- name: paramName
  type: string
  default: defaultValue
- name: paramList
  type: object
  default: []

# Use parameters
steps:
- script: echo ${{ parameters.paramName }}
```

### Template Iteration

```yaml
# Iterate over parameters
parameters:
- name: environments
  type: object
  default:
  - dev
  - staging
  - prod

stages:
- ${{ each env in parameters.environments }}:
  - stage: Deploy_${{ env }}
    jobs:
    - job: DeployTo${{ env }}
      steps:
      - script: echo "Deploying to ${{ env }}"
```

## Container Jobs

Run jobs in Docker containers.

```yaml
resources:
  containers:
  - container: node
    image: node:20-alpine

jobs:
- job: BuildInContainer
  container: node
  steps:
  - script: npm install
  - script: npm test
```

## Service Containers

Run sidecar containers alongside your job.

```yaml
resources:
  containers:
  - container: postgres
    image: postgres:15
    env:
      POSTGRES_PASSWORD: password
    ports:
    - 5432:5432

jobs:
- job: Test
  services:
    postgres: postgres
  steps:
  - script: npm test
    env:
      DATABASE_URL: postgres://postgres:password@postgres:5432/test
```

## Matrix Strategy

Run the same job with different variable combinations.

```yaml
strategy:
  matrix:
    linux_node18:
      imageName: 'ubuntu-22.04'
      nodeVersion: '18'
    linux_node20:
      imageName: 'ubuntu-22.04'
      nodeVersion: '20'
    mac_node18:
      imageName: 'macOS-12'
      nodeVersion: '18'
  maxParallel: 3

pool:
  vmImage: $(imageName)

steps:
- task: NodeTool@0
  inputs:
    versionSpec: $(nodeVersion)
- script: npm test
```

## Environment and Approvals

Environments provide deployment history, approvals, and checks.

```yaml
jobs:
- deployment: DeployProd
  environment:
    name: production
    resourceName: web-app
  strategy:
    runOnce:
      deploy:
        steps:
        - script: echo "Deploying"
```

## Best Practices Summary

1. **Use specific versions**: Pin `vmImage` and task versions
2. **Use displayName**: Add clear display names for readability
3. **Use stages**: Organize complex pipelines with stages
4. **Use templates**: Create reusable templates for common patterns
5. **Use conditions**: Control execution flow with conditions
6. **Use dependsOn**: Optimize with explicit dependencies
7. **Use environments**: Track deployments with environments
8. **Use parameters**: Make pipelines configurable with runtime parameters
9. **Cache dependencies**: Use Cache task for package managers
10. **Set timeouts**: Prevent hung jobs with timeout settings

## Official Documentation

- [YAML Schema Reference](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [Pipeline Definition](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/pipeline)
- [Stages](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/stages)
- [Jobs](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/phases)
- [Steps](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/steps)
- [Templates](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates)
- [Expressions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/expressions)
- [Predefined Variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables)