---
name: azure-pipelines-generator
description: Comprehensive toolkit for generating best practice Azure DevOps Pipelines following current standards and conventions. Use this skill when creating new Azure Pipelines, implementing CI/CD workflows, or building deployment pipelines.
---

# Azure Pipelines Generator

## Overview

Generate production-ready Azure DevOps Pipeline configurations following current best practices, security standards, and naming conventions. All generated resources are automatically validated using the devops-skills:azure-pipelines-validator skill to ensure syntax correctness and compliance with best practices.

## Core Capabilities

### 1. Generate Basic CI Pipelines

Create simple continuous integration pipelines for building and testing applications.

**When to use:**
- User requests: "Create an Azure Pipeline for...", "Build a CI pipeline...", "Generate Azure DevOps pipeline..."
- Scenarios: Continuous integration, automated builds, automated testing

**Process:**
1. Understand the user's requirements (language, framework, testing needs)
2. Identify triggers, pool/agent requirements, and build steps
3. Reference `docs/yaml-schema.md` for YAML structure
4. Reference `docs/best-practices.md` for implementation patterns
5. Reference `docs/tasks-reference.md` for common tasks
6. Generate the pipeline following these principles:
   - Use specific vmImage versions (not 'latest')
   - Pin task versions to major versions (e.g., `@2`)
   - Use displayName for all stages, jobs, and important steps
   - Implement caching for package managers
   - Add proper test result publishing
   - Use conditions appropriately
   - Set reasonable timeouts
7. **ALWAYS validate** the generated pipeline using the devops-skills:azure-pipelines-validator skill
8. If validation fails, fix the issues and re-validate

**Example structure:**
```yaml
trigger:
  branches:
    include:
    - main
    - develop

pool:
  vmImage: 'ubuntu-22.04'

variables:
  buildConfiguration: 'Release'

steps:
- task: NodeTool@0
  displayName: 'Install Node.js'
  inputs:
    versionSpec: '20.x'

- task: Cache@2
  displayName: 'Cache npm packages'
  inputs:
    key: 'npm | "$(Agent.OS)" | package-lock.json'
    path: $(Pipeline.Workspace)/.npm

- script: npm ci --cache $(Pipeline.Workspace)/.npm
  displayName: 'Install dependencies'

- script: npm run build
  displayName: 'Build application'

- script: npm test
  displayName: 'Run tests'

- task: PublishTestResults@2
  condition: succeededOrFailed()
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/test-results.xml'
```

### 2. Generate Multi-Stage CI/CD Pipelines

Create complex pipelines with multiple stages for build, test, and deployment.

**When to use:**
- User requests: "Create a full CI/CD pipeline...", "Build multi-stage pipeline...", "Deploy to multiple environments..."
- Scenarios: Complete CI/CD workflows, multi-environment deployments, complex build processes

**Process:**
1. Identify all stages needed (Build, Test, Deploy)
2. Determine stage dependencies and conditions
3. Plan deployment strategies and environments
4. Use `docs/yaml-schema.md` for stage/job/step hierarchy
5. Reference `examples/multi-stage-cicd.yml` for patterns
6. Generate pipeline with:
   - Clear stage organization
   - Proper `dependsOn` relationships
   - Deployment jobs for environment tracking
   - Conditions for branch-specific deployments
   - Artifact management between stages
7. **ALWAYS validate** using devops-skills:azure-pipelines-validator skill

**Example:**
```yaml
stages:
- stage: Build
  displayName: 'Build Stage'
  jobs:
  - job: BuildJob
    displayName: 'Build Application'
    pool:
      vmImage: 'ubuntu-22.04'
    steps:
    - script: npm run build
      displayName: 'Build'
    - publish: $(Build.SourcesDirectory)/dist
      artifact: drop

- stage: Test
  displayName: 'Test Stage'
  dependsOn: Build
  jobs:
  - job: TestJob
    displayName: 'Run Tests'
    steps:
    - script: npm test
      displayName: 'Test'

- stage: DeployProd
  displayName: 'Deploy to Production'
  dependsOn: Test
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployProd
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploying"
```

### 3. Generate Docker Build Pipelines

Create pipelines for building and pushing Docker images to container registries.

**When to use:**
- User requests: "Build Docker image...", "Push to container registry...", "Create Docker pipeline..."
- Scenarios: Container builds, registry pushes, multi-stage Docker builds

**Process:**
1. Identify Docker registry (ACR, Docker Hub, etc.)
2. Determine image naming and tagging strategy
3. Plan for security scanning if needed
4. Reference `docs/tasks-reference.md` for Docker@2 task
5. Reference `examples/kubernetes-deploy.yml` for Docker build patterns
6. Generate pipeline with:
   - Docker@2 task for build and push
   - Service connection for registry authentication
   - Proper image tagging (build ID, latest, semantic version)
   - Optional security scanning with Trivy or similar
7. **ALWAYS validate** using devops-skills:azure-pipelines-validator skill

**Example:**
```yaml
variables:
  dockerRegistryServiceConnection: 'myACR'
  imageRepository: 'myapp'
  containerRegistry: 'myregistry.azurecr.io'
  tag: '$(Build.BuildId)'

steps:
- task: Docker@2
  displayName: 'Build and Push'
  inputs:
    command: buildAndPush
    repository: $(imageRepository)
    dockerfile: '$(Build.SourcesDirectory)/Dockerfile'
    containerRegistry: $(dockerRegistryServiceConnection)
    tags: |
      $(tag)
      latest
```

### 4. Generate Kubernetes Deployment Pipelines

Create pipelines that deploy applications to Kubernetes clusters.

**When to use:**
- User requests: "Deploy to Kubernetes...", "Create K8s deployment pipeline...", "Deploy to AKS..."
- Scenarios: Kubernetes deployments, AKS deployments, manifest deployments

**Process:**
1. Identify Kubernetes deployment method (kubectl, Helm, manifests)
2. Determine cluster connection details
3. Plan namespace and environment strategy
4. Reference `docs/tasks-reference.md` for Kubernetes tasks
5. Reference `examples/kubernetes-deploy.yml` for patterns
6. Generate pipeline with:
   - KubernetesManifest@0 or Kubernetes@1 tasks
   - Service connection for cluster authentication
   - Proper namespace management
   - Rollout status checking
   - Health check validation
7. **ALWAYS validate** using devops-skills:azure-pipelines-validator skill

**Example:**
```yaml
- task: KubernetesManifest@0
  displayName: 'Deploy to Kubernetes'
  inputs:
    action: 'deploy'
    kubernetesServiceConnection: 'myK8sCluster'
    namespace: 'production'
    manifests: |
      k8s/deployment.yml
      k8s/service.yml
    containers: '$(containerRegistry)/$(imageRepository):$(tag)'
```

### 5. Generate Language-Specific Pipelines

Create pipelines optimized for specific programming languages and frameworks.

**Supported Languages:**
- **.NET/C#**: DotNetCoreCLI@2 tasks, NuGet restore, test, publish
- **Node.js**: NodeTool@0, Npm@1 tasks, npm ci, build, test
- **Python**: UsePythonVersion@0, pip install, pytest
- **Java**: Maven@3 or Gradle@2 tasks
- **Go**: GoTool@0 for version management, go build/test commands, module caching
- **Docker**: Multi-stage builds, layer caching

**Process:**
1. Identify the programming language and framework
2. Reference `docs/tasks-reference.md` for language-specific tasks
3. Reference language-specific examples (dotnet-cicd.yml, python-cicd.yml, go-cicd.yml)
4. Generate pipeline with:
   - Language/runtime setup tasks
   - Package manager caching
   - Build commands specific to framework
   - Test execution with proper reporting
   - Artifact publishing
5. **ALWAYS validate** using devops-skills:azure-pipelines-validator skill

#### Go Language Pipeline Details

**Tasks for Go:**
- **GoTool@0**: Install specific Go version (note: @0 is the current/only major version)
- **Cache@2**: Cache Go modules from `$(GOPATH)/pkg/mod`
- **Script steps**: For `go build`, `go test`, `go vet`, `go mod download`

**Go Module Caching Pattern:**
```yaml
- task: Cache@2
  displayName: 'Cache Go modules'
  inputs:
    key: 'go | "$(Agent.OS)" | go.sum'
    restoreKeys: |
      go | "$(Agent.OS)"
    path: $(GOPATH)/pkg/mod
```

**Go Build Commands:**
```yaml
# Download dependencies
- script: go mod download
  displayName: 'Download Go modules'

# Run linting/vetting
- script: go vet ./...
  displayName: 'Run Go vet'

# Run tests with coverage
- script: go test -v -race -coverprofile=coverage.out -covermode=atomic ./...
  displayName: 'Run Go tests with coverage'

# Build for Linux (common for containers)
- script: |
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-w -s" -o $(Build.ArtifactStagingDirectory)/app ./cmd/server
  displayName: 'Build Go binary for Linux'
```

**Go Matrix Testing Example:**
```yaml
strategy:
  matrix:
    go121:
      goVersion: '1.21'
    go122:
      goVersion: '1.22'
  maxParallel: 2

steps:
- task: GoTool@0
  displayName: 'Install Go $(goVersion)'
  inputs:
    version: $(goVersion)

- script: go test -v ./...
  displayName: 'Run tests'
```

**Reference:** See `examples/go-cicd.yml` for a complete Go CI/CD pipeline example.

### 6. Generate Template-Based Pipelines

Create reusable templates and pipelines that use them.

**When to use:**
- User requests: "Create reusable template...", "Use templates for...", "Build modular pipeline..."
- Scenarios: Template libraries, DRY configurations, shared CI/CD logic

**Process:**
1. Identify common patterns to extract
2. Design template parameters
3. Reference `docs/templates-guide.md` for template syntax
4. Reference `examples/templates/` for template patterns
5. Generate templates with:
   - Clear parameter definitions with types and defaults
   - Documentation comments
   - Proper parameter usage with ${{ }} syntax
   - Conditional logic and iteration as needed
6. Generate main pipeline that uses templates
7. **ALWAYS validate** both templates and main pipeline

**Example:**
```yaml
# Template: templates/build.yml
parameters:
- name: nodeVersion
  type: string
  default: '20.x'

steps:
- task: NodeTool@0
  inputs:
    versionSpec: ${{ parameters.nodeVersion }}
- script: npm ci
- script: npm run build

# Main pipeline
steps:
- template: templates/build.yml
  parameters:
    nodeVersion: '20.x'
```

### 7. Handling Azure Pipelines Tasks and Documentation Lookup

When generating pipelines that use specific Azure Pipelines tasks or require latest documentation:

**Detection:**
- User mentions specific tasks (e.g., "DotNetCoreCLI", "Docker", "AzureWebApp")
- User requests integration with Azure services
- Pipeline requires specific Azure DevOps features

**Process:**

1. **ALWAYS check local documentation first (REQUIRED):**
   Local docs are sufficient for most common tasks and should be your primary reference:
   - `docs/tasks-reference.md` - Contains .NET, Node.js, Python, Go, Docker, Kubernetes, Azure tasks
   - `docs/yaml-schema.md` - Complete YAML syntax reference
   - `docs/best-practices.md` - Security, performance, naming patterns

   **Most pipelines can be generated using only local docs.** External lookup is only needed for:
   - Tasks not documented locally (rare Azure services, third-party marketplace tasks)
   - Specific version compatibility questions
   - Troubleshooting specific error messages

2. **Read relevant example files (RECOMMENDED):**
   Before generating, read the example file(s) that match the user's request:
   - Go pipeline? → Read `examples/go-cicd.yml`
   - Docker/K8s? → Read `examples/kubernetes-deploy.yml`
   - Multi-stage? → Read `examples/multi-stage-cicd.yml`
   - Templates? → Read `examples/template-usage.yml`

   This ensures consistent patterns and best practices.

3. **For tasks NOT in local docs, use external sources:**

   **Option A - Context7 MCP (Preferred when available):**
   - Try to resolve library ID using `mcp__context7__resolve-library-id`
   - Query: "azure-pipelines" or "azure-devops"
   - Fetch documentation using `mcp__context7__get-library-docs`
   - Context7 provides structured, version-aware documentation
   - Best for: Complex tasks, multiple input options, detailed examples

   **Option B - WebSearch (Fallback or for specific queries):**
   ```
   Search query pattern: "[TaskName] Azure Pipelines task documentation"
   Examples:
   - "AzureWebApp@1 Azure Pipelines task documentation"
   - "KubernetesManifest@0 Azure Pipelines task inputs"
   - "Docker@2 Azure Pipelines task latest version"
   ```
   - Best for: Quick lookups, specific version info, troubleshooting

   **When to use which:**
   - Use Context7 first for comprehensive task documentation
   - Use WebSearch when Context7 lacks the specific task, for troubleshooting, or for quick version checks
   - Either approach is acceptable - the goal is accurate, up-to-date information

4. **Analyze documentation for:**
   - Task name and version (e.g., `Docker@2`)
   - Required vs optional inputs
   - Input types and valid values
   - Task outputs if any
   - Best practices and examples
   - Service connection requirements

5. **Generate pipeline using discovered information:**
   - Use correct task name and version
   - Include all required inputs
   - Use appropriate input types
   - Add comments explaining task purpose
   - Include service connections where needed

6. **Include helpful comments:**
   ```yaml
   # Docker@2: Build and push Docker images to a container registry
   # Requires: Docker registry service connection
   - task: Docker@2
     displayName: 'Build and Push Docker image'
     inputs:
       command: buildAndPush
       repository: myapp
       dockerfile: Dockerfile
       containerRegistry: myDockerRegistry
   ```

**Example with task documentation lookup:**
```yaml
# Task: AzureFunctionApp@1
# Purpose: Deploy to Azure Functions
# Service Connection: Azure Resource Manager
- task: AzureFunctionApp@1
  displayName: 'Deploy Azure Function'
  inputs:
    azureSubscription: 'AzureServiceConnection'  # Required: ARM service connection
    appType: 'functionAppLinux'                  # Linux function app
    appName: 'myfunctionapp'                     # Function app name
    package: '$(Build.ArtifactStagingDirectory)/**/*.zip'  # Deployment package
    runtimeStack: 'NODE|20'                      # Node.js 20 runtime
```

## Validation Workflow

**CRITICAL:** Every generated Azure Pipeline configuration MUST be validated before presenting to the user.

### Validation Process

1. **After generating any pipeline configuration**, immediately invoke the `devops-skills:azure-pipelines-validator` skill:
   ```
   Skill: devops-skills:azure-pipelines-validator
   ```

2. **The devops-skills:azure-pipelines-validator skill will:**
   - Validate YAML syntax
   - Check Azure Pipelines schema compliance
   - Verify task names and versions
   - Check for best practices violations
   - Perform security scanning (hardcoded secrets, etc.)
   - Report any errors, warnings, or suggestions

3. **If validation fails:**
   - Analyze the reported errors
   - Fix the issues in the generated configuration
   - Re-validate until all checks pass

4. **If validation succeeds:**
   - Present the validated configuration to the user
   - Mention that validation was successful
   - Provide usage instructions

### When to Skip Validation

Only skip validation when:
- Generating partial code snippets (not complete files)
- Creating examples for documentation purposes
- User explicitly requests to skip validation

## Best Practices to Enforce

Reference `docs/best-practices.md` for comprehensive guidelines. Key principles:

### Mandatory Standards

1. **Security First:**
   - Never hardcode secrets or credentials
   - Use service connections for external services
   - Mark sensitive variables as secret in Azure DevOps
   - Use specific vmImage versions (not 'latest')
   - **Docker image tagging strategy:**
     - When **pushing** images: Use build-specific tag as primary (e.g., `$(Build.BuildId)`), optionally add `:latest` for convenience
     - When **pulling/deploying** images: Always use specific tags, never pull `:latest` in production deployments
     - Example: Push with `$(tag)` AND `latest`, but deploy using `$(containerRegistry)/$(imageRepository):$(tag)`

2. **Version Pinning:**
   - Use specific vmImage versions: `ubuntu-22.04` not `ubuntu-latest`
   - Pin tasks to major versions: `Docker@2` not `Docker@0`
   - Specify language/runtime versions: `'20.x'` for Node.js
   - **Note on @0 versions:** Some tasks only have @0 as their current/latest major version (e.g., `GoTool@0`, `NodeTool@0`, `KubernetesManifest@0`). Using @0 for these tasks is correct and acceptable - the goal is to use the latest available major version, not to avoid @0 specifically.

3. **Performance:**
   - Implement caching for package managers (Cache@2 task)
   - Use explicit `dependsOn` for parallel execution
   - Set artifact expiration
   - Use shallow clone when full history not needed
   - Optimize matrix strategies

4. **Naming:**
   - Stages: PascalCase (e.g., `BuildAndTest`, `DeployProduction`)
   - Jobs: PascalCase (e.g., `BuildJob`, `TestJob`)
   - displayName: Sentence case (e.g., `'Build application'`, `'Run tests'`)
   - Variables: camelCase or snake_case (be consistent)

5. **Organization:**
   - Use stages for complex pipelines
   - Use deployment jobs for environment tracking
   - Use templates for reusable logic
   - Use variable groups for environment-specific variables
   - Add comments for complex logic

6. **Error Handling:**
   - Set timeoutInMinutes for long-running jobs
   - Use conditions appropriately (succeeded(), failed(), always())
   - Use continueOnError for non-critical steps
   - Publish test results with `condition: succeededOrFailed()`

7. **Testing:**
   - Always publish test results (PublishTestResults@2)
   - Publish code coverage (PublishCodeCoverageResults@1)
   - Run linting as separate job or step
   - Include security scanning for dependencies

## Resources

### Documentation (Load as Needed)

- `docs/yaml-schema.md` - Complete Azure Pipelines YAML syntax reference
  - Pipeline structure, stages, jobs, steps
  - Triggers, pools, variables, parameters
  - Conditions and expressions
  - **Use this:** For YAML syntax and structure

- `docs/tasks-reference.md` - Common Azure Pipelines tasks catalog
  - .NET, Node.js, Python, Docker, Kubernetes tasks
  - Task inputs, outputs, and examples
  - Service connection requirements
  - **Use this:** When selecting which task to use

- `docs/best-practices.md` - Azure Pipelines best practices
  - Security patterns, performance optimization
  - Pipeline design, error handling
  - Common patterns and anti-patterns
  - **Use this:** When implementing any pipeline

- `docs/templates-guide.md` - Templates and reusability guide
  - Template types (step, job, stage, variable)
  - Parameter definitions and usage
  - Template expressions and iteration
  - **Use this:** For creating reusable templates

### Examples (Reference for Patterns)

**IMPORTANT:** When generating pipelines, **explicitly read** the relevant example files to ensure consistent patterns and best practices. Use the Read tool to load these files before generating.

| Example File | When to Read |
|-------------|--------------|
| `examples/basic-ci.yml` | Simple CI pipelines, single-stage builds |
| `examples/multi-stage-cicd.yml` | Multi-environment deployments, complex workflows |
| `examples/kubernetes-deploy.yml` | Docker + K8s deployments, container builds |
| `examples/go-cicd.yml` | Go/Golang applications |
| `examples/dotnet-cicd.yml` | .NET/C# applications |
| `examples/python-cicd.yml` | Python applications |
| `examples/template-usage.yml` | Template-based pipelines |
| `examples/templates/build-template.yml` | Creating reusable build templates |
| `examples/templates/deploy-template.yml` | Creating reusable deployment templates |

**Example reading workflow:**
```
1. User requests: "Create a Go CI/CD pipeline with Docker"
2. Read: examples/go-cicd.yml (for Go patterns)
3. Read: examples/kubernetes-deploy.yml (for Docker/K8s patterns)
4. Generate pipeline combining both patterns
5. Validate with devops-skills:azure-pipelines-validator skill
```

## Typical Workflow Example

**User request:** "Create a CI/CD pipeline for a Node.js app with Docker deployment to AKS"

**Process:**
1. ✅ Understand requirements:
   - Node.js application
   - Build and test code
   - Build Docker image
   - Push to container registry
   - Deploy to Azure Kubernetes Service
   - Multiple environments (staging, production)

2. ✅ Reference resources:
   - Check `docs/yaml-schema.md` for multi-stage structure
   - Check `docs/tasks-reference.md` for NodeTool, Docker, Kubernetes tasks
   - Check `docs/best-practices.md` for pipeline patterns
   - Review `examples/multi-stage-cicd.yml` and `examples/kubernetes-deploy.yml`

3. ✅ Search for latest task documentation:
   - WebSearch: "Docker@2 Azure Pipelines task"
   - WebSearch: "KubernetesManifest@0 Azure Pipelines"
   - Context7 (if available): Query azure-pipelines library

4. ✅ Generate pipeline:
   - Stage 1: Build Node.js application
     - NodeTool@0 for Node.js setup
     - npm ci with caching
     - npm run build and test
     - Publish test results
   - Stage 2: Build Docker image
     - Docker@2 buildAndPush
     - Tag with Build.BuildId and latest
   - Stage 3: Deploy to AKS
     - Deployment job with environment
     - KubernetesManifest@0 for deployment
     - Health check validation

5. ✅ Validate:
   - Invoke `devops-skills:azure-pipelines-validator` skill
   - Fix any reported issues
   - Re-validate if needed

6. ✅ Present to user:
   - Show validated pipeline
   - Explain each stage
   - Provide setup instructions (service connections, environments)
   - Mention successful validation

## Common Pipeline Patterns

### Basic Three-Stage Pattern
```yaml
stages:
- stage: Build
  jobs:
  - job: BuildJob
    steps:
    - script: echo "Building"

- stage: Test
  dependsOn: Build
  jobs:
  - job: TestJob
    steps:
    - script: echo "Testing"

- stage: Deploy
  dependsOn: Test
  jobs:
  - deployment: DeployJob
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploying"
```

### Matrix Testing Pattern
```yaml
strategy:
  matrix:
    node18:
      nodeVersion: '18.x'
    node20:
      nodeVersion: '20.x'
    node22:
      nodeVersion: '22.x'
  maxParallel: 3

steps:
- task: NodeTool@0
  inputs:
    versionSpec: $(nodeVersion)
- script: npm test
```

### Conditional Deployment Pattern
```yaml
- stage: DeployProd
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - deployment: DeployProd
    environment: production
    strategy:
      runOnce:
        deploy:
          steps:
          - script: echo "Deploy"
```

## Error Messages and Troubleshooting

### If devops-skills:azure-pipelines-validator reports errors:

1. **Syntax errors:** Fix YAML formatting, indentation, or structure
2. **Task version errors:** Ensure tasks use proper version format (TaskName@version)
3. **Pool/vmImage errors:** Use specific vmImage versions, not 'latest'
4. **Stage/Job errors:** Verify stages contain jobs, jobs contain steps
5. **Security warnings:** Address hardcoded secrets, :latest tags

### If documentation for specific task is not found:

1. Try alternative search queries
2. Check Microsoft Learn directly: https://learn.microsoft.com/azure/devops/pipelines/tasks/reference/
3. Check GitHub: https://github.com/microsoft/azure-pipelines-tasks
4. Ask user if they have specific task version requirements

## Summary

Always follow this sequence when generating Azure Pipelines:

1. **Understand** - Clarify user requirements, language, deployment targets
2. **Reference** - Check docs/yaml-schema.md, tasks-reference.md, best-practices.md
3. **Search** - For specific tasks, use WebSearch or Context7 for current docs
4. **Generate** - Follow standards (pinning, caching, naming, stages)
5. **Validate** - ALWAYS use devops-skills:azure-pipelines-validator skill
6. **Fix** - Resolve any validation errors
7. **Present** - Deliver validated, production-ready pipeline

Generate Azure Pipelines that are:
- ✅ Secure with proper secrets management and version pinning
- ✅ Following current best practices and conventions
- ✅ Using proper YAML structure and hierarchy
- ✅ Optimized for performance (caching, parallelization)
- ✅ Well-documented with displayName and comments
- ✅ Validated and compliant
- ✅ Production-ready and maintainable