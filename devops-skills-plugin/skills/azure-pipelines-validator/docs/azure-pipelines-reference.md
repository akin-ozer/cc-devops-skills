# Azure Pipelines YAML Reference

Comprehensive reference for Azure Pipelines YAML syntax and structure.

## Pipeline Structure

Azure Pipelines supports three main structures:

### 1. Multi-Stage Pipeline

```yaml
stages:
- stage: Build
  jobs:
  - job: BuildJob
    steps:
    - script: echo "Building"
```

### 2. Multi-Job Pipeline

```yaml
jobs:
- job: Job1
  steps:
  - script: echo "Job 1"
- job: Job2
  steps:
  - script: echo "Job 2"
```

### 3. Single-Job Pipeline

```yaml
steps:
- script: echo "Single job"
```

## Top-Level Keywords

### trigger
Defines CI triggers (push events):

```yaml
trigger:
  branches:
    include:
    - main
    - develop
  paths:
    exclude:
    - docs/*
```

### pr
Defines PR triggers:

```yaml
pr:
  branches:
    include:
    - main
  paths:
    include:
    - src/*
```

### schedules
Defines scheduled triggers:

```yaml
schedules:
- cron: "0 0 * * *"
  displayName: Daily midnight build
  branches:
    include:
    - main
```

### pool
Defines agent pool:

```yaml
pool:
  vmImage: 'ubuntu-22.04'
  demands:
  - npm
```

Or use specific pool:

```yaml
pool:
  name: 'My Agent Pool'
```

### variables
Defines variables:

```yaml
variables:
  configuration: 'Release'
  platform: 'x64'
```

Or variable groups:

```yaml
variables:
- group: 'my-variable-group'
- name: myVar
  value: myValue
```

### resources
Defines external resources:

```yaml
resources:
  repositories:
  - repository: templates
    type: git
    name: MyProject/Templates

  pipelines:
  - pipeline: upstream
    source: UpstreamPipeline
    trigger: true

  containers:
  - container: linux
    image: ubuntu:22.04
```

## Stage Definition

```yaml
stages:
- stage: StageName
  displayName: 'Stage Display Name'
  dependsOn: PreviousStage
  condition: succeeded()
  variables:
    stageVar: value
  jobs:
  - job: JobName
    steps:
    - script: echo "Hello"
```

## Job Definition

### Regular Job

```yaml
jobs:
- job: JobName
  displayName: 'Job Display Name'
  dependsOn: PreviousJob
  condition: succeeded()
  timeoutInMinutes: 60
  cancelTimeoutInMinutes: 5
  pool:
    vmImage: 'ubuntu-22.04'
  variables:
    jobVar: value
  steps:
  - script: echo "Job step"
```

### Deployment Job

```yaml
jobs:
- deployment: DeploymentName
  displayName: 'Deploy to Environment'
  environment: 'production'
  pool:
    vmImage: 'ubuntu-22.04'
  strategy:
    runOnce:
      deploy:
        steps:
        - script: echo "Deploying"
```

## Deployment Strategies

### runOnce

```yaml
strategy:
  runOnce:
    preDeploy:
      steps:
      - script: echo "Pre-deploy"
    deploy:
      steps:
      - script: echo "Deploy"
    routeTraffic:
      steps:
      - script: echo "Route traffic"
    postRouteTraffic:
      steps:
      - script: echo "Post-route"
    on:
      failure:
        steps:
        - script: echo "Rollback"
      success:
        steps:
        - script: echo "Success"
```

### rolling

```yaml
strategy:
  rolling:
    maxParallel: 2
    deploy:
      steps:
      - script: echo "Deploy to rolling targets"
```

### canary

```yaml
strategy:
  canary:
    increments: [10, 20, 50]
    deploy:
      steps:
      - script: echo "Deploy canary"
```

## Step Types

### task
Executes a pipeline task:

```yaml
- task: TaskName@MajorVersion
  displayName: 'Task Display Name'
  inputs:
    input1: value1
    input2: value2
  env:
    ENV_VAR: value
  condition: succeeded()
  continueOnError: false
  timeoutInMinutes: 10
```

### script
Runs a shell script:

```yaml
- script: |
    echo "Multi-line"
    echo "script"
  displayName: 'Run Script'
  workingDirectory: $(Build.SourcesDirectory)
  failOnStderr: false
```

### bash
Runs a bash script:

```yaml
- bash: |
    #!/bin/bash
    echo "Bash script"
  displayName: 'Bash Script'
```

### pwsh / powershell
Runs PowerShell:

```yaml
- pwsh: |
    Write-Host "PowerShell Core"
  displayName: 'PowerShell Script'

- powershell: |
    Write-Host "Windows PowerShell"
  displayName: 'Windows PowerShell'
```

### checkout
Checks out repositories:

```yaml
- checkout: self
  clean: true
  fetchDepth: 1
  lfs: false
  submodules: false
  persistCredentials: false
```

### download
Downloads artifacts:

```yaml
- download: current
  artifact: artifactName
```

### publish
Publishes artifacts:

```yaml
- publish: $(Build.ArtifactStagingDirectory)
  artifact: drop
```

### template
References a template:

```yaml
- template: templates/build-steps.yml
  parameters:
    param1: value1
```

## Common Tasks

### Npm@1

```yaml
- task: Npm@1
  inputs:
    command: 'install' # or 'ci', 'custom'
    workingDir: '$(System.DefaultWorkingDirectory)'
    customCommand: 'run build'
```

### DotNetCoreCLI@2

```yaml
- task: DotNetCoreCLI@2
  inputs:
    command: 'build' # or 'restore', 'test', 'publish'
    projects: '**/*.csproj'
    arguments: '--configuration Release'
```

### Docker@2

```yaml
- task: Docker@2
  inputs:
    command: 'build' # or 'push', 'login'
    repository: 'myrepo/myimage'
    dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
    tags: |
      $(Build.BuildId)
      latest
```

### PublishPipelineArtifact@1

```yaml
- task: PublishPipelineArtifact@1
  inputs:
    targetPath: '$(Build.ArtifactStagingDirectory)'
    artifact: 'drop'
    publishLocation: 'pipeline'
```

### AzureWebApp@1

```yaml
- task: AzureWebApp@1
  inputs:
    azureSubscription: 'Azure-Connection'
    appName: 'mywebapp'
    package: '$(System.DefaultWorkingDirectory)/**/*.zip'
```

## Conditions

```yaml
# Always run
condition: always()

# Run on success
condition: succeeded()

# Run on failure
condition: failed()

# Run on success or failure
condition: succeededOrFailed()

# Custom condition
condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
```

## Variable Syntax

```yaml
# Pipeline variable
$(variableName)

# Environment variable (bash)
$VARIABLE_NAME

# Environment variable (PowerShell)
$env:VARIABLE_NAME

# Runtime expression
${{ variables.variableName }}

# Predefined variables
$(Build.BuildId)
$(Build.SourceBranch)
$(Agent.OS)
$(System.DefaultWorkingDirectory)
```

## Templates

### Variable Template

```yaml
# variables/common.yml
variables:
  configuration: 'Release'
  platform: 'x64'
```

### Step Template

```yaml
# templates/build-steps.yml
parameters:
- name: buildConfiguration
  type: string
  default: 'Release'

steps:
- script: echo "Building with ${{ parameters.buildConfiguration }}"
```

### Job Template

```yaml
# templates/test-job.yml
parameters:
- name: jobName
  type: string
- name: pool
  type: string

jobs:
- job: ${{ parameters.jobName }}
  pool:
    vmImage: ${{ parameters.pool }}
  steps:
  - script: echo "Testing"
```

## Best Practices

1. **Always pin task versions**: Use `TaskName@2` not `TaskName@*`
2. **Use specific VM images**: Use `ubuntu-22.04` not `ubuntu-latest`
3. **Use displayName**: Add descriptive names for stages, jobs, and steps
4. **Use caching**: Cache dependencies to speed up builds
5. **Use templates**: Reuse common configurations
6. **Use variable groups**: Organize variables for different environments
7. **Set timeouts**: Prevent hung jobs with `timeoutInMinutes`
8. **Use conditions**: Control when stages/jobs run
9. **Clean checkout**: Use `clean: true` for consistent builds
10. **Use deployment jobs**: For deployments to environments

## References

- [Azure Pipelines YAML Schema](https://learn.microsoft.com/en-us/azure/devops/pipelines/yaml-schema/)
- [Pipeline Task Reference](https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/)
- [Predefined Variables](https://learn.microsoft.com/en-us/azure/devops/pipelines/build/variables)
- [Templates](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates)