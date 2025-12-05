# Azure Pipelines Tasks Reference

This document provides a reference for commonly used built-in Azure Pipelines tasks.

## Task Syntax

```yaml
- task: TaskName@MajorVersion
  displayName: 'Human Readable Name'
  inputs:
    inputName: value
    anotherInput: value
  condition: succeeded()
  continueOnError: false
  enabled: true
  env:
    ENV_VAR: value
  timeoutInMinutes: 0
```

## .NET/C# Tasks

### DotNetCoreCLI@2

Build, test, package, or publish a .NET Core project.

```yaml
- task: DotNetCoreCLI@2
  displayName: 'Restore NuGet packages'
  inputs:
    command: 'restore'
    projects: '**/*.csproj'

- task: DotNetCoreCLI@2
  displayName: 'Build'
  inputs:
    command: 'build'
    projects: '**/*.csproj'
    arguments: '--configuration Release'

- task: DotNetCoreCLI@2
  displayName: 'Run Tests'
  inputs:
    command: 'test'
    projects: '**/*Tests/*.csproj'
    arguments: '--configuration Release --collect:"XPlat Code Coverage"'

- task: DotNetCoreCLI@2
  displayName: 'Publish'
  inputs:
    command: 'publish'
    projects: '**/*.csproj'
    arguments: '--configuration Release --output $(Build.ArtifactStagingDirectory)'
    zipAfterPublish: true
```

### NuGetCommand@2

Restore, pack, or push NuGet packages.

```yaml
- task: NuGetCommand@2
  displayName: 'NuGet restore'
  inputs:
    command: 'restore'
    restoreSolution: '**/*.sln'

- task: NuGetCommand@2
  displayName: 'NuGet pack'
  inputs:
    command: 'pack'
    packagesToPack: '**/*.nuspec'
    versioningScheme: 'byBuildNumber'
```

## Node.js/JavaScript Tasks

### NodeTool@0

Install a specific Node.js version.

```yaml
- task: NodeTool@0
  displayName: 'Use Node.js 20.x'
  inputs:
    versionSpec: '20.x'
```

### Npm@1

Run npm commands.

```yaml
- task: Npm@1
  displayName: 'npm install'
  inputs:
    command: 'install'

- task: Npm@1
  displayName: 'npm run build'
  inputs:
    command: 'custom'
    customCommand: 'run build'

- task: Npm@1
  displayName: 'npm test'
  inputs:
    command: 'custom'
    customCommand: 'run test'
```

## Python Tasks

### UsePythonVersion@0

Select a Python version to run on an agent.

```yaml
- task: UsePythonVersion@0
  displayName: 'Use Python 3.11'
  inputs:
    versionSpec: '3.11'
    addToPath: true
    architecture: 'x64'
```

### Pip@1 / Script

Install Python packages.

```yaml
- script: |
    python -m pip install --upgrade pip
    pip install -r requirements.txt
  displayName: 'Install dependencies'

- script: pytest tests/ --junitxml=junit/test-results.xml
  displayName: 'Run tests'
```

## Docker Tasks

### Docker@2

Build, push, or run Docker images.

```yaml
# Login to registry
- task: Docker@2
  displayName: 'Docker Login'
  inputs:
    command: 'login'
    containerRegistry: 'myDockerRegistryServiceConnection'

# Build image
- task: Docker@2
  displayName: 'Build Docker image'
  inputs:
    command: 'build'
    repository: 'myrepo/myimage'
    dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
    tags: |
      $(Build.BuildId)
      latest

# Push image
- task: Docker@2
  displayName: 'Push Docker image'
  inputs:
    command: 'push'
    repository: 'myrepo/myimage'
    tags: |
      $(Build.BuildId)
      latest

# Build and push (combined)
- task: Docker@2
  displayName: 'Build and Push'
  inputs:
    command: 'buildAndPush'
    repository: 'myrepo/myimage'
    dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
    containerRegistry: 'myDockerRegistryServiceConnection'
    tags: |
      $(Build.BuildId)
      latest
```

### DockerCompose@0

Build, push, or run multi-container Docker applications.

```yaml
- task: DockerCompose@0
  displayName: 'Run Docker Compose'
  inputs:
    action: 'Run services'
    dockerComposeFile: 'docker-compose.yml'
    projectName: '$(Build.Repository.Name)'
    qualifyImageNames: true
    buildImages: true
```

## Kubernetes Tasks

### Kubernetes@1

Deploy, configure, or update a Kubernetes cluster.

```yaml
- task: Kubernetes@1
  displayName: 'kubectl apply'
  inputs:
    connectionType: 'Kubernetes Service Connection'
    kubernetesServiceEndpoint: 'myK8sConnection'
    command: 'apply'
    arguments: '-f manifests/'

- task: Kubernetes@1
  displayName: 'kubectl set image'
  inputs:
    connectionType: 'Kubernetes Service Connection'
    kubernetesServiceEndpoint: 'myK8sConnection'
    command: 'set'
    arguments: 'image deployment/myapp myapp=$(containerRegistry)/myimage:$(Build.BuildId)'
```

### KubernetesManifest@0

Bake and deploy Kubernetes manifests.

```yaml
- task: KubernetesManifest@0
  displayName: 'Deploy to Kubernetes'
  inputs:
    action: 'deploy'
    kubernetesServiceConnection: 'myK8sConnection'
    namespace: 'production'
    manifests: |
      manifests/deployment.yml
      manifests/service.yml
    containers: '$(containerRegistry)/myimage:$(Build.BuildId)'
```

### HelmDeploy@0

Deploy using Helm charts.

```yaml
- task: HelmDeploy@0
  displayName: 'Helm deploy'
  inputs:
    connectionType: 'Kubernetes Service Connection'
    kubernetesServiceConnection: 'myK8sConnection'
    namespace: 'production'
    command: 'upgrade'
    chartType: 'FilePath'
    chartPath: '$(Build.SourcesDirectory)/charts/myapp'
    releaseName: 'myapp'
    arguments: '--set image.tag=$(Build.BuildId)'
```

## Azure Tasks

### AzureCLI@2

Run Azure CLI commands.

```yaml
- task: AzureCLI@2
  displayName: 'Azure CLI'
  inputs:
    azureSubscription: 'myAzureServiceConnection'
    scriptType: 'bash'
    scriptLocation: 'inlineScript'
    inlineScript: |
      az --version
      az account show
```

### AzurePowerShell@5

Run Azure PowerShell commands.

```yaml
- task: AzurePowerShell@5
  displayName: 'Azure PowerShell'
  inputs:
    azureSubscription: 'myAzureServiceConnection'
    scriptType: 'inlineScript'
    inline: |
      Get-AzResourceGroup
    azurePowerShellVersion: 'LatestVersion'
```

### AzureWebApp@1

Deploy to Azure App Service.

```yaml
- task: AzureWebApp@1
  displayName: 'Deploy to Azure Web App'
  inputs:
    azureSubscription: 'myAzureServiceConnection'
    appType: 'webAppLinux'
    appName: 'mywebapp'
    package: '$(Build.ArtifactStagingDirectory)/**/*.zip'
```

### AzureFunctionApp@1

Deploy to Azure Functions.

```yaml
- task: AzureFunctionApp@1
  displayName: 'Deploy Azure Function'
  inputs:
    azureSubscription: 'myAzureServiceConnection'
    appType: 'functionAppLinux'
    appName: 'myfunctionapp'
    package: '$(Build.ArtifactStagingDirectory)/**/*.zip'
```

### AzureRmWebAppDeployment@4

Advanced Azure App Service deployment.

```yaml
- task: AzureRmWebAppDeployment@4
  displayName: 'Azure App Service Deploy'
  inputs:
    azureSubscription: 'myAzureServiceConnection'
    appType: 'webAppLinux'
    WebAppName: 'mywebapp'
    packageForLinux: '$(Build.ArtifactStagingDirectory)/**/*.zip'
    RuntimeStack: 'NODE|20-lts'
```

## Build and Artifact Tasks

### PublishBuildArtifacts@1

Publish build artifacts to Azure Pipelines.

```yaml
- task: PublishBuildArtifacts@1
  displayName: 'Publish Artifact: drop'
  inputs:
    PathtoPublish: '$(Build.ArtifactStagingDirectory)'
    ArtifactName: 'drop'
    publishLocation: 'Container'
```

### DownloadBuildArtifacts@1

Download build artifacts.

```yaml
- task: DownloadBuildArtifacts@1
  displayName: 'Download Build Artifacts'
  inputs:
    buildType: 'current'
    downloadType: 'single'
    artifactName: 'drop'
    downloadPath: '$(System.ArtifactsDirectory)'
```

### PublishPipelineArtifact@1

Publish artifacts (preferred over PublishBuildArtifacts).

```yaml
- task: PublishPipelineArtifact@1
  displayName: 'Publish Pipeline Artifact'
  inputs:
    targetPath: '$(Build.ArtifactStagingDirectory)'
    artifact: 'drop'
    publishLocation: 'pipeline'
```

### DownloadPipelineArtifact@2

Download pipeline artifacts (preferred over DownloadBuildArtifacts).

```yaml
- task: DownloadPipelineArtifact@2
  displayName: 'Download Pipeline Artifact'
  inputs:
    buildType: 'current'
    artifactName: 'drop'
    targetPath: '$(Pipeline.Workspace)'
```

## Test and Code Coverage Tasks

### PublishTestResults@2

Publish test results.

```yaml
- task: PublishTestResults@2
  displayName: 'Publish Test Results'
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/test-results.xml'
    searchFolder: '$(System.DefaultWorkingDirectory)'
    mergeTestResults: true
    failTaskOnFailedTests: true
```

### PublishCodeCoverageResults@1

Publish code coverage results.

```yaml
- task: PublishCodeCoverageResults@1
  displayName: 'Publish Code Coverage'
  inputs:
    codeCoverageTool: 'Cobertura'
    summaryFileLocation: '$(System.DefaultWorkingDirectory)/**/coverage.xml'
    reportDirectory: '$(System.DefaultWorkingDirectory)/**/htmlcov'
```

## Utility Tasks

### CopyFiles@2

Copy files to a target folder.

```yaml
- task: CopyFiles@2
  displayName: 'Copy Files'
  inputs:
    SourceFolder: '$(Build.SourcesDirectory)'
    Contents: |
      **/*.js
      **/*.json
      !node_modules/**
    TargetFolder: '$(Build.ArtifactStagingDirectory)'
    CleanTargetFolder: true
```

### DeleteFiles@1

Delete files from the agent.

```yaml
- task: DeleteFiles@1
  displayName: 'Delete Files'
  inputs:
    SourceFolder: '$(Build.SourcesDirectory)'
    Contents: |
      **/node_modules
      **/temp
```

### Cache@2

Cache files and restore them in future runs.

```yaml
- task: Cache@2
  displayName: 'Cache npm'
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    restoreKeys: |
      npm | "$(Agent.OS)"
    path: $(Pipeline.Workspace)/.npm

- task: Cache@2
  displayName: 'Cache Maven'
  inputs:
    key: 'maven | "$(Agent.OS)" | **/pom.xml'
    restoreKeys: |
      maven | "$(Agent.OS)"
    path: $(Pipeline.Workspace)/.m2/repository
```

### PowerShell@2 / Bash@3

Run PowerShell or Bash scripts.

```yaml
- task: PowerShell@2
  displayName: 'Run PowerShell Script'
  inputs:
    targetType: 'inline'
    script: |
      Write-Host "Running PowerShell"
      Get-ChildItem -Path $(Build.SourcesDirectory)

- task: Bash@3
  displayName: 'Run Bash Script'
  inputs:
    targetType: 'inline'
    script: |
      echo "Running Bash"
      ls -la $(Build.SourcesDirectory)
```

## Security Tasks

### SonarCloudPrepare@1 / SonarCloudAnalyze@1

SonarCloud code analysis.

```yaml
- task: SonarCloudPrepare@1
  inputs:
    SonarCloud: 'SonarCloud'
    organization: 'myorg'
    scannerMode: 'CLI'
    configMode: 'manual'
    cliProjectKey: 'myproject'
    cliProjectName: 'My Project'

- task: SonarCloudAnalyze@1
  displayName: 'Run SonarCloud Analysis'

- task: SonarCloudPublish@1
  displayName: 'Publish SonarCloud Results'
  inputs:
    pollingTimeoutSec: '300'
```

### WhiteSource@21

WhiteSource security and license scanning.

```yaml
- task: WhiteSource@21
  inputs:
    cwd: '$(Build.SourcesDirectory)'
    projectName: 'MyProject'
```

## Version Control Tasks

### GitHubRelease@1

Create a GitHub release.

```yaml
- task: GitHubRelease@1
  displayName: 'Create GitHub Release'
  inputs:
    gitHubConnection: 'GitHubServiceConnection'
    repositoryName: '$(Build.Repository.Name)'
    action: 'create'
    target: '$(Build.SourceVersion)'
    tagSource: 'gitTag'
    tag: '$(Build.BuildNumber)'
    title: 'Release $(Build.BuildNumber)'
    releaseNotesSource: 'inline'
    releaseNotesInline: 'Release notes here'
    assets: '$(Build.ArtifactStagingDirectory)/**'
```

## Best Practices

1. **Pin task versions**: Always specify task version (e.g., `@2`, not `@0`)
2. **Use displayName**: Add clear display names for all tasks
3. **Cache dependencies**: Use Cache@2 for package managers
4. **Use conditions**: Control task execution with conditions
5. **Set timeouts**: Prevent hung tasks with timeoutInMinutes
6. **Use service connections**: Store credentials in service connections, not in pipeline
7. **Publish test results**: Always publish test results for visibility
8. **Use artifact tasks**: Prefer PublishPipelineArtifact over PublishBuildArtifacts
9. **Error handling**: Use continueOnError for non-critical tasks
10. **Environment variables**: Pass sensitive data via env, not as task inputs

## Finding Task Documentation

For detailed task documentation:

1. **Official Task Reference**: https://learn.microsoft.com/en-us/azure/devops/pipelines/tasks/reference/
2. **Task Source Code**: https://github.com/microsoft/azure-pipelines-tasks
3. **Use WebSearch**: Search for "[TaskName] Azure Pipelines task documentation"
4. **Use Context7**: Query for specific task documentation via MCP

## Task Versioning

Tasks follow semantic versioning:

```yaml
# Major version (recommended)
- task: TaskName@2

# Full version (for specific fixes)
- task: TaskName@2.3.1
```

Always use the latest major version unless you have specific compatibility requirements.

## Custom Tasks

You can also create and use custom tasks from:
- Azure DevOps Marketplace
- Private extensions
- YAML templates

```yaml
# Marketplace task
- task: PublisherName.ExtensionName.TaskName@version

# Template as reusable task
- template: templates/my-custom-task.yml
  parameters:
    parameter1: value
```