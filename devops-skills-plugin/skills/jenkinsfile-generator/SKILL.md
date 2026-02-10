---
name: jenkinsfile-generator
description: Comprehensive toolkit for generating best practice Jenkinsfiles for both Declarative and Scripted pipeline syntaxes. Use this skill when creating new Jenkins pipelines, implementing CI/CD workflows.
---

# Jenkinsfile Generator Skill

Generate production-ready Jenkinsfiles following best practices. All generated files are validated using devops-skills:jenkinsfile-validator skill.

## When to Use
- Creating new Jenkinsfiles (declarative or scripted)
- CI/CD pipelines, Docker/Kubernetes deployments
- Parallel execution, matrix builds, parameterized pipelines
- DevSecOps pipelines with security scanning
- Shared library scaffolding

## Quick Reference

```groovy
// Minimal Declarative Pipeline
pipeline {
    agent any
    stages {
        stage('Build') { steps { sh 'make' } }
        stage('Test') { steps { sh 'make test' } }
    }
}

// Error-tolerant stage
stage('Flaky Tests') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
            sh 'run-flaky-tests.sh'
        }
    }
}

// Conditional deployment with approval
stage('Deploy') {
    when { branch 'main'; beforeAgent true }
    input { message 'Deploy to production?' }
    steps { sh './deploy.sh' }
}
```

| Option | Purpose |
|--------|---------|
| `timeout(time: 1, unit: 'HOURS')` | Prevent hung builds |
| `buildDiscarder(logRotator(numToKeepStr: '10'))` | Manage disk space |
| `disableConcurrentBuilds()` | Prevent race conditions |
| `catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE')` | Continue on error |

## Core Capabilities

### 1. Declarative Pipelines (RECOMMENDED)
**Process:**
1. **Read templates for structure reference:**
   - Read `assets/templates/declarative/basic.Jenkinsfile` to understand the standard structure
   - Templates show the expected sections: pipeline → agent → environment → options → parameters → stages → post
   - For complex requests, adapt the structure rather than copying verbatim
2. **Consult reference documentation:**
   - Read `references/best_practices.md` for performance, security, and reliability patterns
   - Read `references/common_plugins.md` for plugin-specific syntax
3. **Generate with required elements:**
   - Proper stages with descriptive names
   - Environment block with credentials binding (never hardcode secrets)
   - Options: timeout, buildDiscarder, timestamps, disableConcurrentBuilds
   - Post conditions: always (cleanup), success (artifacts), failure (notifications)
   - **Always add `failFast true` or `parallelsAlwaysFailFast()` for parallel blocks**
   - **Always include `fingerprint: true` when using `archiveArtifacts`**
4. **ALWAYS validate** using devops-skills:jenkinsfile-validator skill

### 2. Scripted Pipelines
**When:** Complex conditional logic, dynamic generation, full Groovy control
**Process:**
1. **Read templates for structure reference:**
   - Read `assets/templates/scripted/basic.Jenkinsfile` for node/stage patterns
   - Understand try-catch-finally structure for error handling
2. Implement try-catch-finally for error handling
3. **ALWAYS validate** using devops-skills:jenkinsfile-validator skill

### 3. Parallel/Matrix Pipelines
Use `parallel {}` block or `matrix {}` with `axes {}` for multi-dimensional builds.

### 4. Security Scanning (DevSecOps)
Add SonarQube, OWASP Dependency-Check, Trivy stages with fail thresholds.

### 5. Shared Library Scaffolding
```bash
python3 scripts/generate_shared_library.py --name my-library --package org.example
```

## Declarative Syntax Reference

### Agent Types
```groovy
agent any                                    // Any available agent
agent { label 'linux && docker' }           // Label-based
agent { docker { image 'maven:3.9.11-eclipse-temurin-21' } }
agent { kubernetes { yaml '...' } }         // K8s pod template
agent { kubernetes { yamlFile 'pod.yaml' } } // External YAML
```

### Environment & Credentials
```groovy
environment {
    VERSION = '1.0.0'
    AWS_KEY = credentials('aws-key-id')     // Creates _USR and _PSW vars
}
```

### Options
```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 1, unit: 'HOURS')
    disableConcurrentBuilds()
    timestamps()
    parallelsAlwaysFailFast()
    durabilityHint('PERFORMANCE_OPTIMIZED')  // 2-6x faster for simple pipelines
}
```

### Parameters
```groovy
parameters {
    string(name: 'VERSION', defaultValue: '1.0.0')
    choice(name: 'ENV', choices: ['dev', 'staging', 'prod'])
    booleanParam(name: 'SKIP_TESTS', defaultValue: false)
}
```

### When Conditions
| Condition | Example |
|-----------|---------|
| `branch` | `branch 'main'` or `branch pattern: 'release/*', comparator: 'GLOB'` |
| `tag` | `tag pattern: 'v*', comparator: 'GLOB'` |
| `changeRequest` | `changeRequest target: 'main'` |
| `changeset` | `changeset 'src/**/*.java'` |
| `expression` | `expression { env.DEPLOY == 'true' }` |
| `allOf/anyOf/not` | Combine conditions |

Add `beforeAgent true` to skip agent allocation if condition fails.

### Error Handling
```groovy
catchError(buildResult: 'UNSTABLE', stageResult: 'FAILURE') { sh '...' }
warnError('msg') { sh '...' }      // Mark UNSTABLE but continue
unstable(message: 'Coverage low')   // Explicit UNSTABLE
error('Config missing')             // Fail without stack trace
```

### Post Section
```groovy
post {
    always { junit '**/target/*.xml'; cleanWs() }
    success { archiveArtifacts artifacts: '**/*.jar', fingerprint: true }
    failure { slackSend color: 'danger', message: 'Build failed' }
    fixed { echo 'Build fixed!' }
}
```
**Order:** always → changed → fixed → regression → failure → success → unstable → cleanup

**NOTE:** Always use `fingerprint: true` with `archiveArtifacts` for build traceability and artifact tracking.

### Parallel & Matrix

**IMPORTANT:** Always ensure parallel blocks fail fast on first failure using one of these approaches:

**Option 1: Global (RECOMMENDED)** - Use `parallelsAlwaysFailFast()` in pipeline options:
```groovy
options {
    parallelsAlwaysFailFast()  // Applies to ALL parallel blocks in pipeline
}
```
This is the preferred approach as it covers all parallel blocks automatically.

**Option 2: Per-block** - Use `failFast true` on individual parallel stages:
```groovy
stage('Tests') {
    failFast true  // Only affects this parallel block
    parallel {
        stage('Unit') { steps { sh 'npm test:unit' } }
        stage('E2E') { steps { sh 'npm test:e2e' } }
    }
}
```

**NOTE:** When `parallelsAlwaysFailFast()` is set in options, explicit `failFast true` on individual parallel blocks is redundant.

```groovy
stage('Matrix') {
    failFast true
    matrix {
        axes {
            axis { name 'PLATFORM'; values 'linux', 'windows' }
            axis { name 'BROWSER'; values 'chrome', 'firefox' }
        }
        excludes { exclude { axis { name 'PLATFORM'; values 'linux' }; axis { name 'BROWSER'; values 'safari' } } }
        stages { stage('Test') { steps { echo "Testing ${PLATFORM}/${BROWSER}" } } }
    }
}

### Input (Manual Approval)
```groovy
stage('Deploy') {
    input { message 'Deploy?'; ok 'Deploy'; submitter 'admin,ops' }
    steps { sh './deploy.sh' }
}
```
**IMPORTANT:** Place `input` outside steps to avoid holding agents.

## Scripted Syntax Reference

```groovy
node('agent-label') {
    try {
        stage('Build') { sh 'make build' }
        stage('Test') { sh 'make test' }
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        deleteDir()
    }
}

// Parallel
parallel(
    'Unit': { node { sh 'npm test:unit' } },
    'E2E': { node { sh 'npm test:e2e' } }
)

// Environment
withEnv(['VERSION=1.0.0']) { sh 'echo $VERSION' }
withCredentials([string(credentialsId: 'key', variable: 'KEY')]) { sh 'curl -H "Auth: $KEY" ...' }
```

### @NonCPS for Non-Serializable Operations
```groovy
@NonCPS
def parseJson(String json) {
    new groovy.json.JsonSlurper().parseText(json)
}
```
**Rules:** No pipeline steps (`sh`, `echo`) inside @NonCPS. Use for JsonSlurper, iterators, regex Matchers.

## Docker & Kubernetes

### Docker Agent
```groovy
agent { docker { image 'maven:3.9.11'; args '-v $HOME/.m2:/root/.m2'; reuseNode true } }
```

### Build & Push
```groovy
def img = docker.build("myapp:${BUILD_NUMBER}")
docker.withRegistry('https://registry.example.com', 'creds') { img.push(); img.push('latest') }
```

### Kubernetes Pod
```groovy
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.9.11-eclipse-temurin-21
    command: [sleep, 99d]
'''
    }
}
// Use: container('maven') { sh 'mvn package' }
```

## Shared Libraries

```groovy
@Library('my-shared-library') _
// or dynamically: library 'my-library@1.0.0'

// vars/log.groovy
def info(msg) { echo "INFO: ${msg}" }

// Usage
log.info 'Starting build'
```

## Validation Workflow

**CRITICAL: ALWAYS validate using devops-skills:jenkinsfile-validator skill:**

1. Generate Jenkinsfile
2. Invoke `devops-skills:jenkinsfile-validator` skill
3. **Handle validation results by severity:**
   - **ERRORS:** MUST fix before presenting to user - these break the pipeline
   - **WARNINGS:** SHOULD fix - these indicate potential issues
   - **INFO/SUGGESTIONS:** Consider applying based on use case:
     - `failFast true` for parallel blocks → apply by default
     - Build triggers → ask user if they want automated builds
     - Other optimizations → apply if they improve the pipeline
4. Re-validate after fixes
5. Only present validated Jenkinsfiles to user

**Validation commands:**
```bash
# Full validation (syntax + security + best practices)
bash scripts/validate_jenkinsfile.sh Jenkinsfile

# Syntax only (fastest)
bash scripts/validate_jenkinsfile.sh --syntax-only Jenkinsfile
```

## Generator Scripts

**When to use scripts vs manual generation:**
- **Use scripts for:** Simple, standard pipelines with common patterns (basic CI, straightforward CD)
- **Use manual generation for:** Complex pipelines with multiple features (parallel tests + security scanning + Docker + K8s deployments), custom logic, or non-standard requirements

```bash
# Declarative (simple pipelines)
python3 scripts/generate_declarative.py --output Jenkinsfile --stages build,test,deploy --agent docker

# Scripted (simple pipelines)
python3 scripts/generate_scripted.py --output Jenkinsfile --stages build,test --agent label:linux

# Shared Library (always use script for scaffolding)
python3 scripts/generate_shared_library.py --name my-library --package com.example
```

## Plugin Documentation Lookup

**Always consult Context7 or WebSearch for:**
- Plugins NOT covered in `references/common_plugins.md`
- Version-specific documentation requests
- Complex plugin configurations or advanced options
- When user explicitly asks for latest documentation

**May skip external lookup when:**
- Using basic plugin syntax already documented in `references/common_plugins.md`
- Simple, well-documented plugin steps (e.g., basic `sh`, `checkout scm`, `junit`)

**Plugins covered in common_plugins.md:** Git, Docker, Kubernetes, Credentials, JUnit, Slack, SonarQube, OWASP Dependency-Check, Email, AWS, Azure, HTTP Request, Microsoft Teams, Nexus, Artifactory, GitHub

**Lookup methods (in order of preference):**
1. **Context7:** `mcp__context7__resolve-library-id` with `/jenkinsci/<plugin-name>-plugin`
2. **WebSearch:** `Jenkins [plugin-name] plugin documentation 2025`
3. **Official:** plugins.jenkins.io, jenkins.io/doc/pipeline/steps/

## References

- `references/best_practices.md` - Performance, security, reliability patterns
- `references/common_plugins.md` - Git, Docker, K8s, credentials, notifications
- `assets/templates/` - Declarative and scripted templates
- `devops-skills:jenkinsfile-validator` skill - Syntax and best practices validation

**Always prefer Declarative unless scripted flexibility is required.**
