# Jenkins Pipeline Best Practices

Comprehensive guide based on official Jenkins documentation and community best practices.

## Performance Best Practices

### 1. Combine Shell Commands

**Bad:**
```groovy
sh 'echo "Starting build"'
sh 'mkdir build'
sh 'cd build'
sh 'cmake ..'
sh 'make'
sh 'echo "Build complete"'
```

**Good:**
```groovy
sh '''
    echo "Starting build"
    mkdir build
    cd build
    cmake ..
    make
    echo "Build complete"
'''
```

**Why:** Each `sh` step has start-up and tear-down overhead. Combining commands reduces this overhead and improves performance.

### 2. Use Agent-Based Operations

**Bad (runs on controller):**
```groovy
@NonCPS
def parseJson(String jsonString) {
    def jsonSlurper = new groovy.json.JsonSlurper()
    return jsonSlurper.parseText(jsonString)
}

def data = readFile('data.json')
def parsed = parseJson(data)
```

**Good (runs on agent):**
```groovy
def result = sh(script: 'jq ".field" data.json', returnStdout: true).trim()
```

**Why:** Controller resources are shared across all builds. Heavy operations should run on agents to prevent controller bottlenecks.

### 3. Minimize Data Transfer to Controller

**Bad:**
```groovy
def logFile = readFile('huge-log.txt')  // Loads entire file into controller memory
def lines = logFile.split('\n')
```

**Good:**
```groovy
def errorCount = sh(script: 'grep ERROR huge-log.txt | wc -l', returnStdout: true).trim()
```

**Why:** Reduces memory usage on controller and network transfer time.

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

withCredentials([string(credentialsId: 'api-token', variable: 'API_TOKEN')]) {
    sh 'curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com'
}
```

**Why:** Credentials stored in Jenkins Credentials Manager are encrypted and access-controlled.

### 2. Use Credentials Binding

**Good:**
```groovy
environment {
    AWS_CREDENTIALS = credentials('aws-credentials-id')
    // Creates AWS_CREDENTIALS_USR and AWS_CREDENTIALS_PSW
}
```

### 3. Validate User Input

**Bad:**
```groovy
parameters {
    string(name: 'BRANCH', defaultValue: '', description: 'Branch to build')
}

sh "git checkout ${params.BRANCH}"  // Injection risk!
```

**Good:**
```groovy
parameters {
    choice(name: 'BRANCH', choices: ['main', 'develop', 'release'], description: 'Branch to build')
}

// Or validate input
def branch = params.BRANCH
if (!branch.matches(/^[a-zA-Z0-9_\-\/]+$/)) {
    error "Invalid branch name: ${branch}"
}
```

## Reliability Best Practices

### 1. Use Timeouts

**Good:**
```groovy
// Declarative
options {
    timeout(time: 1, unit: 'HOURS')
}

// Scripted
timeout(time: 30, unit: 'MINUTES') {
    node {
        // steps
    }
}
```

**Why:** Prevents builds from hanging indefinitely and consuming resources.

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
        mail to: 'team@example.com',
             subject: "Build Failed: ${currentBuild.fullDisplayName}",
             body: "Check ${env.BUILD_URL}"
    }
}
```

**Scripted:**
```groovy
node {
    try {
        stage('Build') {
            sh 'make build'
        }
        stage('Test') {
            sh 'make test'
        }
    } catch (Exception e) {
        currentBuild.result = 'FAILURE'
        mail to: 'team@example.com',
             subject: "Build Failed",
             body: "Error: ${e.message}"
        throw e
    } finally {
        cleanWs()
    }
}
```

### 3. Use Proper Workspace Cleanup

**Good:**
```groovy
post {
    always {
        cleanWs()
    }
}

// Or for specific cleanup
post {
    cleanup {
        deleteDir()
    }
}
```

**Why:** Ensures consistent build environment and prevents disk space issues.

### 4. Implement Retries for Flaky Operations

**Good:**
```groovy
retry(3) {
    sh 'curl -f https://flaky-api.example.com/data'
}

// Or with exponential backoff
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

## Maintainability Best Practices

### 1. Use Shared Libraries

**Bad:** Copy-pasting common code across Jenkinsfiles

**Good:**
```groovy
@Library('my-shared-library@master') _

pipeline {
    agent any
    stages {
        stage('Build') {
            steps {
                buildMavenProject()  // From shared library
            }
        }
        stage('Deploy') {
            steps {
                deployToKubernetes(env: 'production')  // From shared library
            }
        }
    }
}
```

### 2. Use Descriptive Stage Names

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

### 3. Add Comments for Complex Logic

**Good:**
```groovy
script {
    // Calculate next version based on git tags
    def lastTag = sh(script: 'git describe --tags --abbrev=0', returnStdout: true).trim()
    def (major, minor, patch) = lastTag.tokenize('.')

    // Increment patch version for feature branches
    if (env.BRANCH_NAME.startsWith('feature/')) {
        patch = patch.toInteger() + 1
    }

    def nextVersion = "${major}.${minor}.${patch}"
    echo "Next version: ${nextVersion}"
}
```

### 4. Break Long Pipelines into Stages

**Good:**
```groovy
pipeline {
    stages {
        stage('Preparation') {
            stages {
                stage('Checkout') { }
                stage('Setup Environment') { }
            }
        }
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
}
```

## Optimization Best Practices

### 1. Use Parallel Execution

**Good:**
```groovy
stage('Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'mvn test'
            }
        }
        stage('Integration Tests') {
            steps {
                sh 'mvn verify'
            }
        }
        stage('E2E Tests') {
            steps {
                sh 'npm run e2e'
            }
        }
    }
}
```

### 2. Use failFast with Parallel

**Good:**
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

**Why:** Stops remaining parallel tasks immediately if one fails, saving time and resources.

### 3. Use Stash/Unstash for Artifacts

**Good:**
```groovy
node('build-agent') {
    stage('Build') {
        sh 'mvn package'
        stash name: 'app-jar', includes: 'target/*.jar'
    }
}

node('test-agent') {
    stage('Test') {
        unstash 'app-jar'
        sh 'java -jar target/*.jar --test'
    }
}
```

### 4. Skip Default Checkout When Not Needed

**Good:**
```groovy
options {
    skipDefaultCheckout()  // Don't checkout automatically
}

stages {
    stage('Build') {
        steps {
            checkout scm  // Checkout only when needed
        }
    }
}
```

## Docker Best Practices

### 1. Use Docker Agents for Consistent Environment

**Good:**
```groovy
agent {
    docker {
        image 'maven:3.8.1-adoptopenjdk-11'
        args '-v $HOME/.m2:/root/.m2'
    }
}
```

### 2. Reuse Docker Images

**Bad:**
```groovy
sh 'docker run maven:3.8.1 mvn clean'
sh 'docker run maven:3.8.1 mvn compile'
sh 'docker run maven:3.8.1 mvn package'
```

**Good:**
```groovy
docker.image('maven:3.8.1').inside {
    sh 'mvn clean compile package'
}
```

### 3. Build Once, Deploy Many Times

**Good:**
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
            dockerImage.inside {
                sh 'run-tests.sh'
            }
        }
    }
}

stage('Deploy to Staging') {
    steps {
        script {
            dockerImage.push('staging')
        }
    }
}

stage('Deploy to Production') {
    steps {
        script {
            dockerImage.push('production')
            dockerImage.push('latest')
        }
    }
}
```

## Kubernetes Best Practices

### 1. Use Resource Limits

**Good:**
```groovy
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.1
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

**Good:**
```groovy
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-agent
  containers:
  - name: kubectl
    image: bitnami/kubectl:latest
'''
    }
}
```

## Testing Best Practices

### 1. Always Publish Test Results

**Good:**
```groovy
post {
    always {
        junit '**/target/test-results/*.xml'
        publishHTML([
            reportDir: 'coverage',
            reportFiles: 'index.html',
            reportName: 'Coverage Report'
        ])
    }
}
```

### 2. Archive Artifacts

**Good:**
```groovy
post {
    success {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }
}
```

### 3. Separate Build and Test Stages

**Good:**
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
                junit '**/target/test-results/*.xml'
            }
        }
    }
}
```

## Build Trigger Best Practices

### 1. Use Webhooks Instead of Polling

**Bad:**
```groovy
triggers {
    pollSCM('H/5 * * * *')  // Polls every 5 minutes
}
```

**Good:**
Configure webhooks in your repository to trigger builds on push/PR

**Why:** Webhooks are more efficient and provide faster feedback than polling.

### 2. Use Appropriate Cron Syntax

**Good:**
```groovy
triggers {
    cron('H 2 * * *')  // Daily at ~2 AM (H for hash-based distribution)
    cron('H H(0-7) * * *')  // Once between midnight and 7 AM
}
```

## Notification Best Practices

### 1. Send Notifications for Important Events

**Good:**
```groovy
post {
    failure {
        slackSend (
            color: 'danger',
            message: "Build FAILED: ${env.JOB_NAME} #${env.BUILD_NUMBER} (<${env.BUILD_URL}|Open>)"
        )
    }
    fixed {
        slackSend (
            color: 'good',
            message: "Build FIXED: ${env.JOB_NAME} #${env.BUILD_NUMBER}"
        )
    }
}
```

### 2. Include Relevant Information

**Good:**
```groovy
post {
    failure {
        mail to: 'team@example.com',
             subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
             body: """
Build: ${env.BUILD_URL}
Branch: ${env.BRANCH_NAME}
Commit: ${env.GIT_COMMIT}
Author: ${env.CHANGE_AUTHOR}

Please check the build logs for details.
"""
    }
}
```

## Multi-Branch Pipeline Best Practices

### 1. Use Branch-Specific Logic

**Good:**
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

### 2. Use Pull Request Triggers

**Good:**
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

## Credential Management Best Practices

### 1. Use Least Privilege

- Create separate credentials for different purposes
- Use read-only credentials where possible
- Rotate credentials regularly

### 2. Use Credential Domains

Organize credentials by domain (global, project-specific, etc.)

### 3. Mask Sensitive Output

**Good:**
```groovy
withCredentials([string(credentialsId: 'api-key', variable: 'API_KEY')]) {
    wrap([$class: 'MaskPasswordsBuildWrapper']) {
        sh 'echo "Using API key: $API_KEY"'  // Will be masked in logs
    }
}
```

## Pipeline Configuration Best Practices

### 1. Use Build Discarder

**Good:**
```groovy
options {
    buildDiscarder(logRotator(
        numToKeepStr: '10',           // Keep last 10 builds
        daysToKeepStr: '30',          // Keep builds from last 30 days
        artifactNumToKeepStr: '5',    // Keep artifacts from last 5 builds
        artifactDaysToKeepStr: '14'   // Keep artifacts from last 14 days
    ))
}
```

### 2. Disable Concurrent Builds When Needed

**Good:**
```groovy
options {
    disableConcurrentBuilds()
}
```

### 3. Use Timestamps

**Good:**
```groovy
options {
    timestamps()
}
```

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
- [ ] Use webhooks instead of polling
- [ ] Implement retries for flaky operations
- [ ] Use descriptive stage names
- [ ] Add comments for complex logic
- [ ] Use shared libraries for common code
- [ ] Configure build discarder
- [ ] Use Docker for consistent build environment
- [ ] Set resource limits for Kubernetes pods
- [ ] Validate user input
- [ ] Use least-privilege credentials
- [ ] Separate build and test stages

## References

- [Official Jenkins Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [CloudBees Pipeline Best Practices](https://docs.cloudbees.com/docs/admin-resources/latest/pipeline-best-practices/)
- [Jenkins Performance Best Practices](https://www.jenkins.io/doc/book/scaling/best-practices/)