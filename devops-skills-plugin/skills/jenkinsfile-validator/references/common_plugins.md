# Common Jenkins Plugins Reference

Documentation for frequently used Jenkins plugins in pipelines.

## Table of Contents

1. [Git Plugin](#git-plugin)
2. [Docker Plugin](#docker-plugin)
3. [Kubernetes Plugin](#kubernetes-plugin)
4. [Credentials Plugin](#credentials-plugin)
5. [Pipeline Utility Steps](#pipeline-utility-steps)
6. [JUnit Plugin](#junit-plugin)
7. [HTML Publisher Plugin](#html-publisher-plugin)
8. [Slack Notification Plugin](#slack-notification-plugin)
9. [Email Extension Plugin](#email-extension-plugin)
10. [Build Timeout Plugin](#build-timeout-plugin)
11. [Timestamper Plugin](#timestamper-plugin)
12. [AnsiColor Plugin](#ansicolor-plugin)
13. [Workspace Cleanup Plugin](#workspace-cleanup-plugin)

---

## Git Plugin

Provides Git repository access for Jenkins jobs.

### Checkout SCM

**Declarative:**
```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
    }
}
```

**Scripted:**
```groovy
node {
    checkout scm
}
```

### Explicit Git Checkout

```groovy
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    userRemoteConfigs: [[
        url: 'https://github.com/user/repo.git',
        credentialsId: 'github-credentials'
    ]]
])

// With multiple remotes
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/develop']],
    userRemoteConfigs: [
        [url: 'https://github.com/user/repo.git', name: 'origin'],
        [url: 'https://github.com/upstream/repo.git', name: 'upstream']
    ]
])
```

### Git Operations

```groovy
// Get commit hash
def commit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()

// Get short commit hash
def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()

// Get current branch
def branch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()

// Get commit author
def author = sh(script: 'git log -1 --pretty=%an', returnStdout: true).trim()

// Get commit message
def message = sh(script: 'git log -1 --pretty=%B', returnStdout: true).trim()

// Tag commit
sh "git tag -a v${env.BUILD_NUMBER} -m 'Release ${env.BUILD_NUMBER}'"
sh 'git push origin --tags'
```

### Environment Variables

- `GIT_COMMIT` - Current commit hash
- `GIT_BRANCH` - Branch name
- `GIT_PREVIOUS_COMMIT` - Previous commit
- `GIT_PREVIOUS_SUCCESSFUL_COMMIT` - Last successful build commit
- `GIT_URL` - Repository URL
- `GIT_AUTHOR_NAME` - Commit author name
- `GIT_AUTHOR_EMAIL` - Commit author email

---

## Docker Plugin

Jenkins plugin for running builds in Docker containers.

### Docker Agent

**Declarative:**
```groovy
pipeline {
    agent {
        docker {
            image 'maven:3.8.1-adoptopenjdk-11'
            args '-v /tmp:/tmp'
            label 'docker-agent'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh 'mvn --version'
            }
        }
    }
}
```

### Docker in Scripted Pipeline

```groovy
node {
    // Run inside container
    docker.image('maven:3.8.1').inside {
        sh 'mvn clean package'
    }

    // With additional arguments
    docker.image('node:14').inside('-v /tmp:/tmp -e NODE_ENV=production') {
        sh 'npm install'
        sh 'npm test'
    }

    // Build Docker image
    def image = docker.build("myapp:${env.BUILD_NUMBER}")

    // Build with custom Dockerfile
    def image2 = docker.build("myapp:latest", "-f Dockerfile.prod .")

    // Push to registry
    docker.withRegistry('https://registry.example.com', 'registry-credentials') {
        image.push()
        image.push('latest')
    }

    // Run container
    def container = docker.image('nginx:latest').run('-p 8080:80')
    try {
        sh 'curl http://localhost:8080'
    } finally {
        container.stop()
    }
}
```

### Docker Compose

```groovy
sh 'docker-compose up -d'
try {
    sh 'run-integration-tests.sh'
} finally {
    sh 'docker-compose down'
}
```

---

## Kubernetes Plugin

Run Jenkins agents as Kubernetes pods.

### Pod Template

**Declarative:**
```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: maven
    image: maven:3.8.1-adoptopenjdk-11
    command:
    - cat
    tty: true
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
  - name: docker
    image: docker:latest
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }
    stages {
        stage('Build') {
            steps {
                container('maven') {
                    sh 'mvn clean package'
                }
            }
        }
        stage('Docker Build') {
            steps {
                container('docker') {
                    sh 'docker build -t myapp:latest .'
                }
            }
        }
    }
}
```

### Scripted with Pod Template

```groovy
podTemplate(
    label: 'my-pod',
    containers: [
        containerTemplate(name: 'maven', image: 'maven:3.8.1', ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'kubectl', image: 'bitnami/kubectl:latest', ttyEnabled: true, command: 'cat')
    ],
    volumes: [
        secretVolume(secretName: 'kubeconfig', mountPath: '/home/jenkins/.kube')
    ]
) {
    node('my-pod') {
        stage('Build') {
            container('maven') {
                sh 'mvn clean package'
            }
        }
        stage('Deploy') {
            container('kubectl') {
                sh 'kubectl apply -f deployment.yaml'
            }
        }
    }
}
```

---

## Credentials Plugin

Securely store and use credentials in pipelines.

### Credential Types

#### Username and Password

```groovy
withCredentials([usernamePassword(
    credentialsId: 'my-credentials',
    usernameVariable: 'USERNAME',
    passwordVariable: 'PASSWORD'
)]) {
    sh 'echo "User: $USERNAME"'
    // Use $PASSWORD
}
```

#### Secret Text

```groovy
withCredentials([string(
    credentialsId: 'api-token',
    variable: 'API_TOKEN'
)]) {
    sh 'curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com'
}
```

#### SSH User Private Key

```groovy
withCredentials([sshUserPrivateKey(
    credentialsId: 'ssh-key',
    keyFileVariable: 'SSH_KEY',
    usernameVariable: 'SSH_USER'
)]) {
    sh 'ssh -i $SSH_KEY $SSH_USER@server.example.com "deploy.sh"'
}
```

#### File

```groovy
withCredentials([file(
    credentialsId: 'kubeconfig',
    variable: 'KUBECONFIG'
)]) {
    sh 'kubectl --kubeconfig=$KUBECONFIG get pods'
}
```

#### Certificate

```groovy
withCredentials([certificate(
    credentialsId: 'cert-id',
    keystoreVariable: 'KEYSTORE',
    passwordVariable: 'KEYSTORE_PASSWORD'
)]) {
    sh 'sign-app.sh $KEYSTORE $KEYSTORE_PASSWORD'
}
```

### Environment Credentials Binding

**Declarative:**
```groovy
environment {
    DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
    // Creates DOCKER_CREDENTIALS_USR and DOCKER_CREDENTIALS_PSW

    API_KEY = credentials('api-key')  // Secret text
}
```

---

## Pipeline Utility Steps

Common utility steps for pipelines.

### Read and Write Files

```groovy
// Read file
def content = readFile(file: 'version.txt')

// Write file
writeFile(file: 'output.txt', text: 'Hello World')

// Read JSON
def json = readJSON(file: 'config.json')
// Or from text
def data = readJSON(text: '{"key": "value"}')

// Write JSON
writeJSON(file: 'output.json', json: [name: 'Jenkins', version: '2.0'])

// Read YAML
def yaml = readYAML(file: 'config.yaml')

// Write YAML
writeYAML(file: 'output.yaml', data: [name: 'Jenkins', version: '2.0'])

// Read CSV
def csv = readCSV(file: 'data.csv')

// Read properties
def props = readProperties(file: 'config.properties')
```

### File Operations

```groovy
// Check if file exists
if (fileExists('path/to/file')) {
    echo 'File exists'
}

// Find files
def files = findFiles(glob: '**/*.jar')
files.each { file ->
    echo "Found: ${file.path}"
}

// Touch file
touch(file: 'marker.txt')

// ZIP files
zip(zipFile: 'archive.zip', dir: 'target')

// Unzip
unzip(zipFile: 'archive.zip', dir: 'output')
```

---

## JUnit Plugin

Publish JUnit test results.

### Basic Usage

```groovy
post {
    always {
        junit '**/target/test-results/*.xml'
    }
}

// With options
junit(
    testResults: '**/target/surefire-reports/*.xml',
    allowEmptyResults: true,
    keepLongStdio: true,
    healthScaleFactor: 1.0
)
```

---

## HTML Publisher Plugin

Publish HTML reports.

```groovy
publishHTML([
    reportDir: 'coverage',
    reportFiles: 'index.html',
    reportName: 'Coverage Report',
    keepAll: true,
    alwaysLinkToLastBuild: true,
    allowMissing: false
])

// Multiple reports
publishHTML([
    reportDir: 'test-results',
    reportFiles: 'index.html',
    reportName: 'Test Results'
])
publishHTML([
    reportDir: 'coverage',
    reportFiles: 'index.html',
    reportName: 'Code Coverage'
])
```

---

## Slack Notification Plugin

Send notifications to Slack.

```groovy
// Simple notification
slackSend(
    color: 'good',
    message: 'Build succeeded!'
)

// With details
slackSend(
    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
    message: """
Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}
Status: ${currentBuild.result}
Duration: ${currentBuild.durationString}
URL: ${env.BUILD_URL}
""",
    channel: '#builds',
    teamDomain: 'myteam',
    tokenCredentialId: 'slack-token'
)

// Conditional notifications
post {
    success {
        slackSend color: 'good', message: "Build ${env.BUILD_NUMBER} succeeded"
    }
    failure {
        slackSend color: 'danger', message: "Build ${env.BUILD_NUMBER} failed"
    }
    fixed {
        slackSend color: 'good', message: "Build ${env.BUILD_NUMBER} fixed!"
    }
}
```

---

## Email Extension Plugin

Send detailed email notifications.

```groovy
emailext(
    subject: "Build ${currentBuild.result}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
    body: """
<h2>Build ${currentBuild.result}</h2>
<p><strong>Job:</strong> ${env.JOB_NAME}</p>
<p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
<p><strong>Build URL:</strong> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
<p><strong>Duration:</strong> ${currentBuild.durationString}</p>
""",
    to: 'team@example.com',
    from: 'jenkins@example.com',
    replyTo: 'noreply@example.com',
    mimeType: 'text/html',
    attachLog: true,
    compressLog: true,
    attachmentsPattern: '**/target/*.jar'
)

// Conditional emails
post {
    failure {
        emailext(
            subject: "Build Failed: ${env.JOB_NAME}",
            body: "Check ${env.BUILD_URL}",
            to: 'team@example.com',
            recipientProviders: [
                developers(),  // Send to developers who made changes
                culprits(),    // Send to developers who broke the build
                requestor()    // Send to user who triggered the build
            ]
        )
    }
}
```

---

## Build Timeout Plugin

Set timeouts for builds.

**Declarative:**
```groovy
options {
    timeout(time: 1, unit: 'HOURS')
}
```

**Scripted:**
```groovy
timeout(time: 30, unit: 'MINUTES') {
    node {
        // steps
    }
}

// Activity timeout (no console output)
timeout(time: 10, unit: 'MINUTES', activity: true) {
    node {
        // steps
    }
}
```

---

## Timestamper Plugin

Add timestamps to console output.

**Declarative:**
```groovy
options {
    timestamps()
}
```

**Scripted:**
```groovy
timestamps {
    node {
        echo 'This will have timestamps'
    }
}
```

---

## AnsiColor Plugin

Add color to console output.

**Declarative:**
```groovy
options {
    ansiColor('xterm')
}
```

**Scripted:**
```groovy
ansiColor('xterm') {
    node {
        sh 'ls --color=always'
    }
}
```

---

## Workspace Cleanup Plugin

Clean workspace before/after builds.

```groovy
// Clean before build
cleanWs()

// Clean after build
post {
    always {
        cleanWs()
    }
}

// Clean with options
cleanWs(
    deleteDirs: true,
    disableDeferredWipeout: true,
    notFailBuild: true,
    patterns: [
        [pattern: 'target', type: 'INCLUDE'],
        [pattern: '*.log', type: 'INCLUDE']
    ]
)

// Delete directory
deleteDir()
```

---

## Additional Common Plugins

### Archive Artifacts

```groovy
archiveArtifacts(
    artifacts: '**/*.jar',
    allowEmptyArchive: false,
    fingerprint: true,
    onlyIfSuccessful: true
)
```

### Stash/Unstash

```groovy
// Stash files
stash(
    name: 'build-artifacts',
    includes: 'target/*.jar',
    excludes: 'target/*-sources.jar'
)

// Unstash files
unstash 'build-artifacts'
```

### Build Job

```groovy
// Trigger another job
build(
    job: 'downstream-job',
    parameters: [
        string(name: 'ENVIRONMENT', value: 'production'),
        booleanParam(name: 'RUN_TESTS', value: true)
    ],
    wait: true,
    propagate: true
)
```

### Input

```groovy
def userInput = input(
    message: 'Deploy to production?',
    ok: 'Deploy',
    parameters: [
        choice(name: 'ENVIRONMENT', choices: ['staging', 'production'], description: 'Target environment'),
        string(name: 'VERSION', defaultValue: '1.0', description: 'Version to deploy')
    ],
    submitter: 'admin,ops',
    submitterParameter: 'approver'
)

echo "Deploying ${userInput.VERSION} to ${userInput.ENVIRONMENT}"
echo "Approved by: ${userInput.approver}"
```

### Retry

```groovy
retry(3) {
    sh 'flaky-command'
}
```

### Sleep

```groovy
sleep(time: 30, unit: 'SECONDS')
```

### Wait Until

```groovy
waitUntil {
    def status = sh(script: 'check-status.sh', returnStatus: true)
    return status == 0
}
```

---

## Plugin Documentation Lookup

For unlisted plugins, use:

1. **Context7**: Search for `/jenkinsci/<plugin-name>-plugin`
2. **Web Search**: "Jenkins <plugin-name> plugin documentation"
3. **Official Plugins**: https://plugins.jenkins.io/

---

## References

- [Jenkins Plugins Index](https://plugins.jenkins.io/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Plugins Development Guide](https://www.jenkins.io/doc/developer/plugin-development/)