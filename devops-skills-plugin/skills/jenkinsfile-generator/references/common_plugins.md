# Common Jenkins Plugins - Generator Reference

Quick reference for generating Jenkinsfiles with popular plugin steps.

## Table of Contents

1. [Git Plugin](#git-plugin)
2. [Docker Plugin](#docker-plugin)
3. [Kubernetes Plugin](#kubernetes-plugin)
4. [Credentials Plugin](#credentials-plugin)
5. [Pipeline Utility Steps](#pipeline-utility-steps)
6. [JUnit Plugin](#junit-plugin)
7. [Slack Notification Plugin](#slack-notification-plugin)
8. [Email Extension Plugin](#email-extension-plugin)
9. [Build Timeout Plugin](#build-timeout-plugin)
10. [Workspace Cleanup Plugin](#workspace-cleanup-plugin)
11. [AWS Steps Plugin](#aws-steps-plugin)
12. [Azure CLI Plugin](#azure-cli-plugin)
13. [SonarQube Plugin](#sonarqube-plugin)
14. [HTTP Request Plugin](#http-request-plugin)
15. [Microsoft Teams Notification Plugin](#microsoft-teams-notification-plugin)
16. [Nexus Artifact Uploader Plugin](#nexus-artifact-uploader-plugin)
17. [Artifactory Plugin](#artifactory-plugin)
18. [OWASP Dependency-Check Plugin](#owasp-dependency-check-plugin)
19. [GitHub Plugin](#github-plugin)

---

## Git Plugin

### Basic Checkout

```groovy
// Auto-detect SCM
checkout scm

// Explicit URL
git branch: 'main', url: 'https://github.com/user/repo.git'

// With credentials
git branch: 'main',
    url: 'https://github.com/user/repo.git',
    credentialsId: 'github-credentials'
```

### Advanced Checkout

```groovy
checkout scmGit(
    branches: [[name: '*/main']],
    userRemoteConfigs: [[
        url: 'https://github.com/user/repo.git',
        credentialsId: 'github-credentials'
    ]],
    extensions: [
        cloneOption(shallow: true, depth: 1),
        submodule(recursiveSubmodules: true)
    ]
)
```

### Git Environment Variables

- `GIT_COMMIT` - Current commit hash
- `GIT_BRANCH` - Branch name
- `GIT_URL` - Repository URL
- `GIT_AUTHOR_NAME` - Commit author

---

## Docker Plugin

### Docker Agent (Declarative)

```groovy
agent {
    docker {
        image 'maven:3.9.11-eclipse-temurin-21'
        args '-v $HOME/.m2:/root/.m2'
        reuseNode true
    }
}
```

### Docker Agent with Dockerfile

```groovy
agent {
    dockerfile {
        filename 'Dockerfile.build'
        dir 'docker'
        additionalBuildArgs '--build-arg VERSION=1.0'
    }
}
```

### Docker in Scripted Pipeline

```groovy
node {
    docker.image('maven:3.9.11').inside('-v $HOME/.m2:/root/.m2') {
        sh 'mvn clean package'
    }
}
```

### Build and Push Docker Image

```groovy
node {
    def image = docker.build("myapp:${env.BUILD_NUMBER}")

    docker.withRegistry('https://registry.example.com', 'docker-credentials') {
        image.push()
        image.push('latest')
    }
}
```

### Sidecar Container

```groovy
docker.image('mysql:8').withRun('-e MYSQL_ROOT_PASSWORD=secret') { db ->
    docker.image('maven:3.9.11').inside("--link ${db.id}:mysql") {
        sh 'mvn verify'
    }
}
```

---

## Kubernetes Plugin

### Pod Template (Declarative)

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
    command: ['sleep']
    args: ['99d']
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
  - name: docker
    image: docker:latest
    command: ['sleep']
    args: ['99d']
    volumeMounts:
    - name: dockersock
      mountPath: /var/run/docker.sock
  volumes:
  - name: dockersock
    hostPath:
      path: /var/run/docker.sock
'''
    }
}
```

### Container Step

```groovy
stage('Build') {
    steps {
        container('maven') {
            sh 'mvn clean package'
        }
    }
}
```

### Scripted Pod Template

```groovy
podTemplate(
    containers: [
        containerTemplate(name: 'maven', image: 'maven:3.9.11', ttyEnabled: true, command: 'cat'),
        containerTemplate(name: 'kubectl', image: 'bitnami/kubectl:latest', ttyEnabled: true, command: 'cat')
    ],
    volumes: [
        secretVolume(secretName: 'kubeconfig', mountPath: '/root/.kube')
    ]
) {
    node(POD_LABEL) {
        container('maven') {
            sh 'mvn clean package'
        }
    }
}
```

---

## Credentials Plugin

### Username/Password

```groovy
withCredentials([usernamePassword(
    credentialsId: 'docker-hub',
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'
)]) {
    sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
}
```

### Secret Text

```groovy
withCredentials([string(credentialsId: 'api-token', variable: 'API_TOKEN')]) {
    sh 'curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com'
}
```

### SSH Key

```groovy
withCredentials([sshUserPrivateKey(
    credentialsId: 'ssh-key',
    keyFileVariable: 'SSH_KEY',
    usernameVariable: 'SSH_USER'
)]) {
    sh 'ssh -i $SSH_KEY $SSH_USER@server.example.com "deploy.sh"'
}
```

### File Credential

```groovy
withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
    sh 'kubectl --kubeconfig=$KUBECONFIG get pods'
}
```

### Environment Binding (Declarative)

```groovy
environment {
    DOCKER_CREDENTIALS = credentials('docker-hub-credentials')
    // Creates DOCKER_CREDENTIALS_USR and DOCKER_CREDENTIALS_PSW
    API_KEY = credentials('api-key')
}
```

---

## Pipeline Utility Steps

### File Operations

```groovy
// Read file
def content = readFile(file: 'version.txt')

// Write file
writeFile(file: 'output.txt', text: 'Hello World')

// Read JSON
def json = readJSON(file: 'config.json')

// Write JSON
writeJSON(file: 'output.json', json: [name: 'Jenkins', version: '2.0'])

// Read YAML
def yaml = readYAML(file: 'config.yaml')

// Write YAML
writeYAML(file: 'output.yaml', data: [name: 'Jenkins'])

// Check if file exists
if (fileExists('path/to/file')) {
    echo 'File exists'
}

// Find files
def files = findFiles(glob: '**/*.jar')
```

### ZIP Operations

```groovy
// Create ZIP
zip(zipFile: 'archive.zip', dir: 'target')

// Unzip
unzip(zipFile: 'archive.zip', dir: 'output')
```

---

## JUnit Plugin

```groovy
post {
    always {
        junit(
            testResults: '**/target/surefire-reports/*.xml',
            allowEmptyResults: true,
            keepLongStdio: true
        )
    }
}
```

---

## Slack Notification Plugin

```groovy
// Simple notification
slackSend(color: 'good', message: 'Build succeeded!')

// With details
slackSend(
    color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
    message: "Build: ${env.JOB_NAME} #${env.BUILD_NUMBER}\nStatus: ${currentBuild.result}",
    channel: '#builds',
    tokenCredentialId: 'slack-token'
)

// Post conditions
post {
    success {
        slackSend color: 'good', message: "Build ${env.BUILD_NUMBER} succeeded"
    }
    failure {
        slackSend color: 'danger', message: "Build ${env.BUILD_NUMBER} failed"
    }
}
```

---

## Email Extension Plugin

```groovy
emailext(
    subject: "Build ${currentBuild.result}: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
    body: """
<h2>Build ${currentBuild.result}</h2>
<p><strong>Job:</strong> ${env.JOB_NAME}</p>
<p><strong>Build Number:</strong> ${env.BUILD_NUMBER}</p>
<p><strong>Build URL:</strong> <a href="${env.BUILD_URL}">${env.BUILD_URL}</a></p>
""",
    to: 'team@example.com',
    mimeType: 'text/html',
    attachLog: true
)

// With recipient providers
post {
    failure {
        emailext(
            subject: "Build Failed: ${env.JOB_NAME}",
            body: "Check ${env.BUILD_URL}",
            recipientProviders: [developers(), culprits(), requestor()]
        )
    }
}
```

---

## Build Timeout Plugin

```groovy
// Declarative
options {
    timeout(time: 1, unit: 'HOURS')
}

// Per-stage
stage('Long Running') {
    options {
        timeout(time: 30, unit: 'MINUTES')
    }
    steps {
        sh './long-task.sh'
    }
}

// Scripted
timeout(time: 30, unit: 'MINUTES') {
    node {
        // steps
    }
}
```

---

## Workspace Cleanup Plugin

```groovy
// Clean workspace
cleanWs()

// In post block
post {
    always {
        cleanWs()
    }
}

// With options
cleanWs(
    deleteDirs: true,
    patterns: [
        [pattern: 'target', type: 'INCLUDE'],
        [pattern: '*.log', type: 'INCLUDE']
    ]
)

// Simple delete
deleteDir()
```

---

## AWS Steps Plugin

```groovy
withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
    // S3 operations
    s3Upload(bucket: 'my-bucket', path: 'artifacts/', includePathPattern: '**/*.jar')
    s3Download(bucket: 'my-bucket', path: 'config/', file: 'config.json')

    // ECR login
    def login = ecrLogin()
    sh "${login}"

    // ECS deploy
    ecsDeployTaskDefinition(taskDefinition: 'my-task', cluster: 'my-cluster')
}
```

---

## Azure CLI Plugin

```groovy
withCredentials([azureServicePrincipal('azure-sp')]) {
    sh '''
        az login --service-principal -u $AZURE_CLIENT_ID -p $AZURE_CLIENT_SECRET --tenant $AZURE_TENANT_ID
        az account set --subscription $AZURE_SUBSCRIPTION_ID
        az webapp deploy --resource-group mygroup --name myapp --src-path app.zip
    '''
}
```

---

## SonarQube Plugin

```groovy
stage('SonarQube Analysis') {
    steps {
        withSonarQubeEnv('sonarqube-server') {
            sh 'mvn sonar:sonar'
        }
    }
}

stage('Quality Gate') {
    steps {
        timeout(time: 5, unit: 'MINUTES') {
            waitForQualityGate abortPipeline: true
        }
    }
}
```

**Common Gotcha:** Ensure the SonarQube Server URL in Jenkins configuration does NOT have a trailing slash (e.g., `http://sonarqube:9000` not `http://sonarqube:9000/`).

---

## HTTP Request Plugin

Make HTTP/HTTPS requests from pipeline with full control over method, headers, and response handling.

### Basic GET Request

```groovy
def response = httpRequest 'https://api.example.com/status'
echo "Status: ${response.status}"
echo "Content: ${response.content}"
```

### POST with JSON Body

```groovy
def response = httpRequest(
    url: 'https://api.example.com/deploy',
    httpMode: 'POST',
    contentType: 'APPLICATION_JSON',
    requestBody: '{"environment": "production", "version": "1.0.0"}',
    validResponseCodes: '200:299'
)
```

### With Authentication

```groovy
withCredentials([string(credentialsId: 'api-token', variable: 'API_TOKEN')]) {
    def response = httpRequest(
        url: 'https://api.example.com/data',
        httpMode: 'GET',
        customHeaders: [[name: 'Authorization', value: "Bearer ${API_TOKEN}"]],
        timeout: 30
    )
}
```

### Response Handling Options

```groovy
// Don't read response body (for large responses)
def response = httpRequest(
    url: 'https://api.example.com/large-file',
    responseHandle: 'NONE'
)

// Keep connection open for streaming
def response = httpRequest(
    url: 'https://api.example.com/stream',
    responseHandle: 'LEAVE_OPEN'
)
// Must close manually:
response.close()
```

### Advanced Options

```groovy
def response = httpRequest(
    url: 'https://api.example.com/upload',
    httpMode: 'PUT',
    uploadFile: './report.html',
    validResponseCodes: '200,201,204',
    ignoreSslErrors: true,
    httpProxy: 'http://proxy.local:8080',
    timeout: 60,
    consoleLogResponseBody: true
)
```

### HTTP Methods Available

- `GET` - Retrieve data (default)
- `POST` - Submit data
- `PUT` - Update/upload resource
- `PATCH` - Partial update
- `DELETE` - Remove resource
- `HEAD` - Retrieve headers only
- `OPTIONS` - Query available methods

---

## Microsoft Teams Notification Plugin

```groovy
// Simple notification
office365ConnectorSend(
    webhookUrl: 'https://outlook.office.com/webhook/...',
    message: 'Build completed!',
    color: '00FF00'
)

// With card formatting
office365ConnectorSend(
    webhookUrl: "${TEAMS_WEBHOOK}",
    message: "Build ${currentBuild.result}",
    status: currentBuild.result,
    factDefinitions: [
        [name: 'Job', value: env.JOB_NAME],
        [name: 'Build', value: "#${env.BUILD_NUMBER}"],
        [name: 'Duration', value: "${currentBuild.durationString}"]
    ],
    potentialAction: [[
        '@type': 'OpenUri',
        'name': 'View Build',
        'targets': [[
            'os': 'default',
            'uri': env.BUILD_URL
        ]]
    ]]
)

// In post block
post {
    success {
        office365ConnectorSend(
            webhookUrl: "${TEAMS_WEBHOOK}",
            message: "Build succeeded",
            color: '00FF00'
        )
    }
    failure {
        office365ConnectorSend(
            webhookUrl: "${TEAMS_WEBHOOK}",
            message: "Build failed",
            color: 'FF0000'
        )
    }
}
```

---

## Nexus Artifact Uploader Plugin

```groovy
nexusArtifactUploader(
    nexusVersion: 'nexus3',
    protocol: 'https',
    nexusUrl: 'nexus.example.com',
    repository: 'maven-releases',
    credentialsId: 'nexus-credentials',
    groupId: 'com.example',
    version: '1.0.0',
    artifacts: [
        [artifactId: 'myapp', classifier: '', file: 'target/myapp.jar', type: 'jar'],
        [artifactId: 'myapp', classifier: '', file: 'pom.xml', type: 'pom']
    ]
)
```

---

## Artifactory Plugin

```groovy
// Configure Artifactory server
def server = Artifactory.server('artifactory-server')
def uploadSpec = """{
    "files": [{
        "pattern": "target/*.jar",
        "target": "libs-release-local/com/example/myapp/1.0.0/"
    }]
}"""

// Upload
server.upload(uploadSpec)

// Download
def downloadSpec = """{
    "files": [{
        "pattern": "libs-release-local/com/example/myapp/1.0.0/*.jar",
        "target": "dependencies/"
    }]
}"""
server.download(downloadSpec)

// Publish build info
def buildInfo = Artifactory.newBuildInfo()
server.upload spec: uploadSpec, buildInfo: buildInfo
server.publishBuildInfo buildInfo
```

---

## OWASP Dependency-Check Plugin

```groovy
stage('Dependency Check') {
    steps {
        dependencyCheck(
            additionalArguments: '''
                --scan .
                --format HTML
                --format XML
                --format JSON
                --out dependency-check-report
                --suppression suppression.xml
                --failOnCVSS 7
            ''',
            odcInstallation: 'OWASP-Dependency-Check'
        )
    }
    post {
        always {
            dependencyCheckPublisher(
                pattern: '**/dependency-check-report.xml',
                failedTotalCritical: 0,
                failedTotalHigh: 5,
                unstableTotalMedium: 10
            )
        }
    }
}
```

---

## GitHub Plugin

### Set Commit Status

```groovy
// Using step
githubNotify(
    status: 'PENDING',
    description: 'Build in progress',
    context: 'jenkins/build'
)

// After build
post {
    success {
        githubNotify status: 'SUCCESS', description: 'Build passed'
    }
    failure {
        githubNotify status: 'FAILURE', description: 'Build failed'
    }
}
```

### Create/Update PR Comment

```groovy
// Using GitHub API via sh
withCredentials([string(credentialsId: 'github-token', variable: 'GITHUB_TOKEN')]) {
    sh '''
        curl -X POST \
            -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/owner/repo/issues/${CHANGE_ID}/comments \
            -d '{"body": "Build succeeded!"}'
    '''
}
```

---

## Common Build Steps

### Archive Artifacts

```groovy
archiveArtifacts(
    artifacts: '**/*.jar',
    fingerprint: true,
    onlyIfSuccessful: true
)
```

### Stash/Unstash

```groovy
// Stash
stash(name: 'build-artifacts', includes: 'target/*.jar')

// Unstash
unstash 'build-artifacts'
```

### Build Job

```groovy
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
        choice(name: 'ENVIRONMENT', choices: ['staging', 'production']),
        string(name: 'VERSION', defaultValue: '1.0')
    ],
    submitter: 'admin,ops'
)
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

---

## Plugin Documentation Lookup

For unlisted plugins:

1. **Context7**: Search for `/jenkinsci/<plugin-name>-plugin`
2. **Web Search**: "Jenkins <plugin-name> plugin documentation"
3. **Official Plugins**: https://plugins.jenkins.io/
4. **Pipeline Steps**: https://www.jenkins.io/doc/pipeline/steps/

---

## References

- [Jenkins Plugins Index](https://plugins.jenkins.io/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)