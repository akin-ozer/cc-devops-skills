# Jenkins Pipeline Best Practices - Generator Reference

Quick reference for generating best-practice Jenkinsfiles.

## Performance Best Practices

### 1. Combine Shell Commands

**Bad:**
```groovy
sh 'echo "Starting build"'
sh 'mkdir build'
sh 'cd build && cmake ..'
sh 'make'
```

**Good:**
```groovy
sh '''
    echo "Starting build"
    mkdir build
    cd build && cmake ..
    make
'''
```

### 2. Use Agent-Based Operations

**Bad (runs on controller):**
```groovy
def data = readFile('data.json')
def parsed = new groovy.json.JsonSlurper().parseText(data)
```

**Good (runs on agent):**
```groovy
def result = sh(script: 'jq ".field" data.json', returnStdout: true).trim()
```

### 3. Minimize Controller Memory Usage

**Bad:**
```groovy
def logFile = readFile('huge-log.txt')  // Loads entire file
```

**Good:**
```groovy
def errorCount = sh(script: 'grep ERROR huge-log.txt | wc -l', returnStdout: true).trim()
```

---

## Security Best Practices

### 1. Never Hardcode Credentials

**Bad:**
```groovy
sh 'docker login -u admin -p password123'
sh 'curl -H "Authorization: Bearer abc123xyz" https://api.example.com'
```

**Good:**
```groovy
withCredentials([usernamePassword(
    credentialsId: 'docker-hub',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
}
```

### 2. Use Environment Credentials Binding

```groovy
environment {
    DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
    // Creates DOCKER_CREDENTIALS_USR and DOCKER_CREDENTIALS_PSW
    API_KEY = credentials('api-key')
}
```

### 3. Validate User Input

**Bad:**
```groovy
sh "git checkout ${params.BRANCH}"  // Injection risk!
```

**Good:**
```groovy
parameters {
    choice(name: 'BRANCH', choices: ['main', 'develop', 'release'], description: 'Branch to build')
}

// Or validate
def branch = params.BRANCH
if (!branch.matches(/^[a-zA-Z0-9_\-\/]+$/)) {
    error "Invalid branch name: ${branch}"
}
```

---

## Reliability Best Practices

### 1. Always Use Timeouts

```groovy
// Pipeline level
options {
    timeout(time: 1, unit: 'HOURS')
}

// Stage level
stage('Long Running') {
    options {
        timeout(time: 30, unit: 'MINUTES')
    }
    steps {
        sh './long-task.sh'
    }
}
```

### 2. Implement Error Handling

**Declarative:**
```groovy
post {
    always {
        cleanWs()
    }
    success {
        slackSend color: 'good', message: "Build succeeded"
    }
    failure {
        slackSend color: 'danger', message: "Build failed"
    }
}
```

**Scripted:**
```groovy
node {
    try {
        stage('Build') { sh 'make build' }
        stage('Test') { sh 'make test' }
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        cleanWs()
    }
}
```

### 3. Use catchError for Resilient Pipelines

Allow pipelines to continue after non-critical failures:

**catchError - Continue on Failure:**
```groovy
// Mark stage as failed but continue pipeline
stage('Non-Critical Tests') {
    steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            sh 'npm run test:experimental'
        }
    }
}

// Mark build as unstable if integration tests fail
stage('Integration Tests') {
    steps {
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
            sh 'npm run test:integration'
        }
    }
}
```

**warnError - Quick Unstable Pattern:**
```groovy
stage('Code Analysis') {
    steps {
        warnError('Linting warnings detected') {
            sh 'npm run lint'
        }
    }
}
```

**unstable - Explicit Unstable Status:**
```groovy
stage('Coverage Check') {
    steps {
        script {
            def coverage = sh(script: 'get-coverage.sh', returnStdout: true).trim().toInteger()
            if (coverage < 80) {
                unstable(message: "Code coverage ${coverage}% is below 80% threshold")
            }
        }
    }
}
```

**error - Fail Without Stack Trace:**
```groovy
stage('Validation') {
    steps {
        script {
            if (!fileExists('config.json')) {
                error('Configuration file not found')
            }
        }
    }
}
```

**Combined Error Handling Pattern (Recommended):**
```groovy
stage('Test Suite') {
    steps {
        // Critical - fail build if unit tests fail
        sh 'npm run test:unit'

        // Important - mark unstable if integration tests fail
        catchError(buildResult: 'UNSTABLE', stageResult: 'UNSTABLE') {
            sh 'npm run test:integration'
        }

        // Non-critical - warn only
        warnError('Smoke tests had warnings') {
            sh 'npm run test:smoke'
        }

        // Optional - continue regardless
        catchError(buildResult: 'SUCCESS', stageResult: 'FAILURE') {
            sh 'npm run test:experimental'
        }
    }
}
```

**catchError Parameters:**
| Parameter | Values | Description |
|-----------|--------|-------------|
| `buildResult` | SUCCESS, UNSTABLE, FAILURE, NOT_BUILT, ABORTED | Overall build result on error |
| `stageResult` | SUCCESS, UNSTABLE, FAILURE, NOT_BUILT, ABORTED | Stage result on error |
| `message` | String | Message logged on error |
| `catchInterruptions` | true/false | Whether to catch timeout/abort exceptions (default: true) |

### 3. Clean Workspace

```groovy
post {
    always {
        cleanWs()
    }
}

// Or use deleteDir()
post {
    cleanup {
        deleteDir()
    }
}
```

### 4. Implement Retries

```groovy
retry(3) {
    sh 'curl -f https://flaky-api.example.com/data'
}

// With backoff
script {
    def attempts = 0
    retry(3) {
        attempts++
        if (attempts > 1) {
            sleep time: attempts * 10, unit: 'SECONDS'
        }
        sh 'flaky-command'
    }
}
```

---

## Pipeline Structure Best Practices

### 1. Use Descriptive Stage Names

**Bad:**
```groovy
stage('Step 1') { }
stage('Step 2') { }
```

**Good:**
```groovy
stage('Build Application') { }
stage('Run Unit Tests') { }
stage('Build Docker Image') { }
stage('Deploy to Staging') { }
```

### 2. Use Nested Stages for Organization

```groovy
stages {
    stage('Build') {
        stages {
            stage('Compile') { }
            stage('Package') { }
        }
    }
    stage('Quality Checks') {
        parallel {
            stage('Unit Tests') { }
            stage('Integration Tests') { }
            stage('Code Analysis') { }
        }
    }
}
```

### 3. Use Parallel Execution

```groovy
stage('Tests') {
    parallel {
        stage('Unit Tests') {
            steps { sh 'mvn test' }
        }
        stage('Integration Tests') {
            steps { sh 'mvn verify' }
        }
        stage('E2E Tests') {
            steps { sh 'npm run e2e' }
        }
    }
}
```

### 4. Use failFast with Parallel

```groovy
stage('Deploy') {
    failFast true
    parallel {
        stage('Region 1') { }
        stage('Region 2') { }
        stage('Region 3') { }
    }
}
```

---

## Options Best Practices

### Recommended Pipeline Options

```groovy
options {
    buildDiscarder(logRotator(
        numToKeepStr: '10',           // Keep last 10 builds
        daysToKeepStr: '30',          // Keep builds from last 30 days
        artifactNumToKeepStr: '5'     // Keep artifacts from last 5 builds
    ))
    timestamps()                       // Add timestamps to console
    timeout(time: 1, unit: 'HOURS')   // Pipeline timeout
    disableConcurrentBuilds()          // No concurrent builds
    parallelsAlwaysFailFast()          // Fail fast in parallel stages
}
```

---

## Docker Best Practices

### 1. Use Docker Agents

```groovy
agent {
    docker {
        image 'maven:3.9.9-eclipse-temurin-21'
        args '-v $HOME/.m2:/root/.m2'
        reuseNode true
    }
}
```

### 2. Reuse Docker Images

**Bad:**
```groovy
sh 'docker run maven:3.9.9 mvn clean'
sh 'docker run maven:3.9.9 mvn compile'
sh 'docker run maven:3.9.9 mvn package'
```

**Good:**
```groovy
docker.image('maven:3.9.9').inside {
    sh 'mvn clean compile package'
}
```

### 3. Build Once, Deploy Many

```groovy
stage('Build') {
    steps {
        script {
            dockerImage = docker.build("myapp:${env.BUILD_NUMBER}")
        }
    }
}

stage('Test') {
    steps {
        script {
            dockerImage.inside { sh 'run-tests.sh' }
        }
    }
}

stage('Deploy') {
    steps {
        script {
            dockerImage.push()
            dockerImage.push('latest')
        }
    }
}
```

### 4. Docker Image Selection Best Practices

#### Node.js Images

Per [Snyk's Node.js Docker best practices](https://snyk.io/blog/choosing-the-best-node-js-docker-image/):

| Image Type | Recommendation | Use Case |
|------------|----------------|----------|
| `node:22-bookworm-slim` | **Recommended for production** | Minimal size, stable Debian base |
| `node:22-alpine` | Use with caution | Smallest size, but Alpine is **experimental** in Node.js |
| `node:22` | Development only | Large image, includes unnecessary tools |
| `node:lts` | Avoid in CI/CD | Tag changes over time, not reproducible |

**Best Practice:**
```groovy
agent {
    docker {
        // Use specific version for reproducibility
        image 'node:22.11.0-bookworm-slim'  // Specific + slim
    }
}

// Alternative for size-sensitive builds (with caution)
agent {
    docker {
        image 'node:22-alpine'  // Note: Alpine is experimental in Node.js
    }
}
```

**Why avoid Alpine for Node.js?**
- Node.js marks Alpine as "experimental" in their official documentation
- Uses musl libc instead of glibc (potential compatibility issues)
- Native dependencies may require recompilation
- Some npm packages may not work correctly

#### Java/Maven Images

```groovy
// Recommended: Eclipse Temurin (successor to AdoptOpenJDK)
agent {
    docker { image 'maven:3.9.11-eclipse-temurin-21' }
}

// For smaller images
agent {
    docker { image 'maven:3.9.11-eclipse-temurin-21-alpine' }
}
```

#### Python Images

```groovy
// Recommended: Slim variant with Debian Bookworm
agent {
    docker { image 'python:3.12-slim-bookworm' }
}

// Alpine (smaller but may need additional build tools)
agent {
    docker { image 'python:3.12-alpine' }
}
```

#### Go Images

```groovy
// Alpine works well for Go (statically compiled)
agent {
    docker { image 'golang:1.23-alpine' }
}
```

**General Rules:**
1. Always use specific version tags (not `latest` or `lts`)
2. Prefer `-slim` or `-bookworm-slim` variants for production
3. Use Alpine only when you understand the trade-offs
4. Test native dependencies before switching to Alpine

---

## Kubernetes Best Practices

### 1. Set Resource Limits

```groovy
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.9.9
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
'''
    }
}
```

### 2. Use Service Accounts

```groovy
agent {
    kubernetes {
        yaml '''
spec:
  serviceAccountName: jenkins-agent
'''
    }
}
```

---

## Testing Best Practices

### 1. Always Publish Test Results

```groovy
post {
    always {
        junit '**/target/surefire-reports/*.xml'
        publishHTML([
            reportDir: 'coverage',
            reportFiles: 'index.html',
            reportName: 'Coverage Report'
        ])
    }
}
```

### 2. Archive Artifacts

```groovy
post {
    success {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }
}
```

### 3. Separate Build and Test Stages

```groovy
stages {
    stage('Build') {
        steps {
            sh 'mvn clean package -DskipTests'
        }
    }
    stage('Test') {
        steps {
            sh 'mvn test'
        }
        post {
            always {
                junit '**/target/surefire-reports/*.xml'
            }
        }
    }
}
```

---

## Notification Best Practices

### Send Notifications for Important Events

```groovy
post {
    failure {
        slackSend(
            color: 'danger',
            message: "Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
    fixed {
        slackSend(
            color: 'good',
            message: "Build FIXED: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

### Include Relevant Information

```groovy
post {
    failure {
        mail to: 'team@example.com',
             subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
             body: """
Build: ${env.BUILD_URL}
Branch: ${env.BRANCH_NAME}
Commit: ${env.GIT_COMMIT}
"""
    }
}
```

---

## Multi-Branch Pipeline Best Practices

### Use Branch-Specific Logic

```groovy
stage('Deploy') {
    when {
        branch 'main'
    }
    steps {
        sh 'deploy-production.sh'
    }
}

stage('Deploy to Staging') {
    when {
        branch 'develop'
    }
    steps {
        sh 'deploy-staging.sh'
    }
}
```

### Use PR Triggers

```groovy
stage('PR Validation') {
    when {
        changeRequest()
    }
    steps {
        sh 'run-pr-checks.sh'
    }
}
```

---

## Input Best Practices

### Free Agents During Input

**Good (input outside agent):**
```groovy
stage('Approval') {
    input {
        message 'Deploy to production?'
        ok 'Deploy'
        submitter 'admin,ops-team'
    }
    steps {
        sh './deploy.sh'
    }
}
```

**Bad (holds agent during input):**
```groovy
stage('Approval') {
    steps {
        input 'Deploy to production?'
        sh './deploy.sh'
    }
}
```

---

## Summary Checklist

- [ ] Combine multiple shell commands into single steps
- [ ] Use agent-based operations, not controller-based
- [ ] Never hardcode credentials
- [ ] Implement timeouts for all builds
- [ ] Add proper error handling (try-catch, post blocks)
- [ ] Clean workspace after builds
- [ ] Use parallel execution for independent tasks
- [ ] Publish test results and artifacts
- [ ] Send notifications for important events
- [ ] Use descriptive stage names
- [ ] Configure build discarder
- [ ] Use Docker for consistent build environment
- [ ] Set resource limits for Kubernetes pods
- [ ] Validate user input
- [ ] Use least-privilege credentials
- [ ] Free agents during input

---

## References

- [Official Jenkins Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [Jenkins Performance Best Practices](https://www.jenkins.io/doc/book/scaling/best-practices/)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)