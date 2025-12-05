# Azure Pipelines Templates Guide

This guide covers how to create and use templates in Azure Pipelines for reusable and maintainable pipeline configurations.

## What Are Templates?

Templates allow you to define reusable content, logic, and parameters in YAML pipelines. They promote DRY (Don't Repeat Yourself) principles and make pipelines more maintainable.

## Template Types

### 1. Step Templates

Reusable sets of steps.

**template: templates/build-steps.yml**
```yaml
steps:
- task: NodeTool@0
  displayName: 'Install Node.js'
  inputs:
    versionSpec: '20.x'

- script: npm ci
  displayName: 'Install dependencies'

- script: npm run build
  displayName: 'Build application'

- script: npm test
  displayName: 'Run tests'
```

**Usage:**
```yaml
jobs:
- job: Build
  steps:
  - template: templates/build-steps.yml
```

### 2. Job Templates

Reusable job definitions.

**templates/test-job.yml**
```yaml
parameters:
- name: nodeVersion
  type: string
  default: '20'

- name: osImage
  type: string
  default: 'ubuntu-22.04'

jobs:
- job: Test_Node_${{ parameters.nodeVersion }}
  displayName: 'Test on Node ${{ parameters.nodeVersion }}'
  pool:
    vmImage: ${{ parameters.osImage }}
  steps:
  - task: NodeTool@0
    inputs:
      versionSpec: ${{ parameters.nodeVersion }}

  - script: npm ci
    displayName: 'Install dependencies'

  - script: npm test
    displayName: 'Run tests'
```

**Usage:**
```yaml
stages:
- stage: Test
  jobs:
  - template: templates/test-job.yml
    parameters:
      nodeVersion: '18'
      osImage: 'ubuntu-22.04'

  - template: templates/test-job.yml
    parameters:
      nodeVersion: '20'
      osImage: 'ubuntu-22.04'
```

### 3. Stage Templates

Reusable stage definitions.

**templates/deploy-stage.yml**
```yaml
parameters:
- name: environment
  type: string

- name: dependsOn
  type: object
  default: []

stages:
- stage: Deploy_${{ parameters.environment }}
  displayName: 'Deploy to ${{ parameters.environment }}'
  dependsOn: ${{ parameters.dependsOn }}
  jobs:
  - deployment: Deploy
    displayName: 'Deploy Application'
    environment: ${{ parameters.environment }}
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploying to ${{ parameters.environment }}"
            displayName: 'Deploy'
```

**Usage:**
```yaml
stages:
- stage: Build
  jobs: [...]

- template: templates/deploy-stage.yml
  parameters:
    environment: 'staging'
    dependsOn: Build

- template: templates/deploy-stage.yml
  parameters:
    environment: 'production'
    dependsOn: Build
```

### 4. Variable Templates

Reusable variable definitions.

**templates/variables-common.yml**
```yaml
variables:
  nodeVersion: '20'
  buildConfiguration: 'Release'
  artifactName: 'drop'
```

**Usage:**
```yaml
variables:
- template: templates/variables-common.yml
- name: customVariable
  value: 'customValue'
```

## Template Parameters

### Parameter Types

```yaml
parameters:
# String
- name: environmentName
  type: string
  default: 'dev'

# Number
- name: timeout
  type: number
  default: 30

# Boolean
- name: runTests
  type: boolean
  default: true

# Object (list)
- name: environments
  type: object
  default:
  - dev
  - staging
  - prod

# Object (dictionary)
- name: settings
  type: object
  default:
    debug: true
    verbose: false

# Step list
- name: buildSteps
  type: stepList
  default: []

# Job list
- name: testJobs
  type: jobList
  default: []

# Stage list
- name: deployStages
  type: stageList
  default: []
```

### Parameter Validation

```yaml
parameters:
- name: environment
  type: string
  values:  # Restrict to specific values
  - dev
  - staging
  - production

- name: version
  type: string
  default: '1.0.0'
```

### Using Parameters

```yaml
# String interpolation
steps:
- script: echo "Deploying to ${{ parameters.environment }}"
  displayName: 'Deploy to ${{ parameters.environment }}'

# Conditional logic
- ${{ if eq(parameters.runTests, true) }}:
  - script: npm test
    displayName: 'Run tests'

# Object iteration
- ${{ each env in parameters.environments }}:
  - script: echo "Deploying to ${{ env }}"
    displayName: 'Deploy to ${{ env }}'
```

## Template Expressions

### Conditional Insertion

```yaml
parameters:
- name: runTests
  type: boolean
  default: true

steps:
- script: npm run build
  displayName: 'Build'

- ${{ if eq(parameters.runTests, true) }}:
  - script: npm test
    displayName: 'Run tests'

- ${{ if ne(parameters.runTests, true) }}:
  - script: echo "Skipping tests"
    displayName: 'Skip tests'
```

### Iteration

```yaml
parameters:
- name: nodeVersions
  type: object
  default:
  - '18'
  - '20'
  - '22'

strategy:
  matrix:
    ${{ each version in parameters.nodeVersions }}:
      Node_${{ version }}:
        nodeVersion: ${{ version }}
```

### Each with Key-Value Pairs

```yaml
parameters:
- name: environments
  type: object
  default:
    dev:
      url: https://dev.example.com
    staging:
      url: https://staging.example.com
    prod:
      url: https://prod.example.com

stages:
- ${{ each env in parameters.environments }}:
  - stage: Deploy_${{ env.key }}
    jobs:
    - job: Deploy
      variables:
        targetUrl: ${{ env.value.url }}
      steps:
      - script: echo "Deploying to ${{ env.value.url }}"
```

## Extends Template

The `extends` keyword allows you to extend an entire pipeline template.

**templates/secure-pipeline.yml**
```yaml
parameters:
- name: buildSteps
  type: stepList
  default: []

stages:
- stage: Build
  jobs:
  - job: SecurityScan
    steps:
    - script: echo "Running security scan"

  - job: Build
    steps:
    - script: echo "Pre-build checks"

    - ${{ each step in parameters.buildSteps }}:
      - ${{ step }}

    - script: echo "Post-build checks"
```

**azure-pipelines.yml**
```yaml
extends:
  template: templates/secure-pipeline.yml
  parameters:
    buildSteps:
    - script: npm ci
      displayName: 'Install dependencies'

    - script: npm run build
      displayName: 'Build application'
```

## Template Inclusion

### Local Templates

```yaml
# Relative path from current file
- template: templates/build-steps.yml

# Relative path with parameters
- template: ../shared/deploy.yml
  parameters:
    environment: production
```

### Templates from Other Repositories

```yaml
resources:
  repositories:
  - repository: templates
    type: github
    name: myorg/pipeline-templates
    ref: refs/heads/main

stages:
- template: build-stage.yml@templates
  parameters:
    projectName: myapp
```

### Templates from Different Branches

```yaml
resources:
  repositories:
  - repository: templates
    type: git
    name: MyProject/Templates
    ref: refs/heads/v2

jobs:
- template: ci-job.yml@templates
```

## Advanced Template Patterns

### Matrix Build Template

**templates/matrix-test.yml**
```yaml
parameters:
- name: operatingSystems
  type: object
  default:
  - ubuntu-22.04
  - windows-2022
  - macOS-12

- name: nodeVersions
  type: object
  default:
  - '18'
  - '20'

jobs:
- job: Test
  strategy:
    matrix:
      ${{ each os in parameters.operatingSystems }}:
        ${{ each version in parameters.nodeVersions }}:
          ${{ os }}_Node_${{ version }}:
            imageName: ${{ os }}
            nodeVersion: ${{ version }}
  pool:
    vmImage: $(imageName)
  steps:
  - task: NodeTool@0
    inputs:
      versionSpec: $(nodeVersion)
  - script: npm test
```

### Conditional Stage Template

**templates/optional-deploy.yml**
```yaml
parameters:
- name: shouldDeploy
  type: boolean
  default: false

- name: environment
  type: string

stages:
- ${{ if eq(parameters.shouldDeploy, true) }}:
  - stage: Deploy_${{ parameters.environment }}
    jobs:
    - deployment: Deploy
      environment: ${{ parameters.environment }}
      strategy:
        runOnce:
          deploy:
            steps:
            - script: echo "Deploying"
```

### Nested Templates

**templates/full-pipeline.yml**
```yaml
parameters:
- name: runTests
  type: boolean
  default: true

stages:
- stage: Build
  jobs:
  - template: build-job.yml  # Nested template

- ${{ if eq(parameters.runTests, true) }}:
  - template: test-stage.yml  # Nested template

- template: deploy-stage.yml  # Nested template
  parameters:
    environment: production
```

## Template Best Practices

### 1. Parameter Documentation

```yaml
# templates/deploy.yml
# Deploys application to specified environment
# Parameters:
#   environment: Target environment (dev, staging, prod)
#   version: Application version to deploy
#   approvalRequired: Whether manual approval is needed

parameters:
- name: environment
  type: string
  displayName: 'Target Environment'

- name: version
  type: string
  default: 'latest'
  displayName: 'Application Version'

- name: approvalRequired
  type: boolean
  default: true
  displayName: 'Require Manual Approval'
```

### 2. Default Values

Always provide sensible defaults for parameters.

```yaml
parameters:
- name: buildConfiguration
  type: string
  default: 'Release'

- name: runTests
  type: boolean
  default: true
```

### 3. Template Validation

Use parameter restrictions to validate inputs.

```yaml
parameters:
- name: environment
  type: string
  values:
  - dev
  - staging
  - production
```

### 4. Template Organization

```
templates/
├── stages/
│   ├── build-stage.yml
│   ├── test-stage.yml
│   └── deploy-stage.yml
├── jobs/
│   ├── build-job.yml
│   └── test-job.yml
├── steps/
│   ├── npm-build.yml
│   └── docker-build.yml
└── variables/
    ├── common.yml
    └── production.yml
```

### 5. Versioning Templates

Use tags or branches to version your template repository.

```yaml
resources:
  repositories:
  - repository: templates
    type: github
    name: myorg/pipeline-templates
    ref: refs/tags/v2.1.0  # Specific version tag
```

## Common Template Patterns

### Build and Test Template

**templates/build-and-test.yml**
```yaml
parameters:
- name: projectPath
  type: string
  default: '.'

- name: nodeVersion
  type: string
  default: '20'

steps:
- task: NodeTool@0
  inputs:
    versionSpec: ${{ parameters.nodeVersion }}

- task: Cache@2
  inputs:
    key: 'npm | "$(Agent.OS)" | ${{ parameters.projectPath }}/package-lock.json'
    path: $(Pipeline.Workspace)/.npm

- script: npm ci --cache $(Pipeline.Workspace)/.npm
  workingDirectory: ${{ parameters.projectPath }}
  displayName: 'Install dependencies'

- script: npm run build
  workingDirectory: ${{ parameters.projectPath }}
  displayName: 'Build'

- script: npm test
  workingDirectory: ${{ parameters.projectPath }}
  displayName: 'Test'
```

### Docker Build Template

**templates/docker-build.yml**
```yaml
parameters:
- name: dockerfilePath
  type: string
  default: 'Dockerfile'

- name: imageName
  type: string

- name: imageTag
  type: string
  default: '$(Build.BuildId)'

steps:
- task: Docker@2
  displayName: 'Build Docker image'
  inputs:
    command: 'build'
    repository: ${{ parameters.imageName }}
    dockerfile: ${{ parameters.dockerfilePath }}
    tags: |
      ${{ parameters.imageTag }}
      latest

- task: Docker@2
  displayName: 'Push Docker image'
  inputs:
    command: 'push'
    repository: ${{ parameters.imageName }}
    tags: |
      ${{ parameters.imageTag }}
      latest
```

### Deployment Approval Template

**templates/deploy-with-approval.yml**
```yaml
parameters:
- name: environment
  type: string

- name: serviceConnection
  type: string

stages:
- stage: Deploy_${{ parameters.environment }}
  jobs:
  - deployment: Deploy
    environment: ${{ parameters.environment }}  # Approval configured in environment
    strategy:
      runOnce:
        deploy:
          steps:
          - task: AzureWebApp@1
            inputs:
              azureSubscription: ${{ parameters.serviceConnection }}
              appName: 'myapp-${{ parameters.environment }}'
```

## Debugging Templates

### View Expanded Template

Use the Azure DevOps UI to view the fully expanded YAML after template processing.

### Template Syntax Validation

```yaml
# Use template expressions for debugging
- script: echo "Environment: ${{ parameters.environment }}"
  displayName: 'Debug: Show parameters'
```

## Summary

Templates are powerful for:
- **Reusability**: Write once, use many times
- **Maintainability**: Update in one place
- **Consistency**: Enforce standards across pipelines
- **Modularity**: Break complex pipelines into manageable pieces

Key takeaways:
1. Use parameters for flexibility
2. Provide sensible defaults
3. Document your templates
4. Organize templates logically
5. Version your template repositories
6. Test templates thoroughly

## Further Reading

- [Templates - Azure Pipelines](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates)
- [Template types & usage](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/templates)
- [Template expressions](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/template-expressions)
- [Template parameters](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/template-parameters)
- [Extends template](https://learn.microsoft.com/en-us/azure/devops/pipelines/security/templates)