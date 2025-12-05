# Scripted Pipeline Syntax Reference

Complete reference for Jenkins Scripted Pipeline syntax using Groovy.

## Overview

Scripted Pipeline is written using Groovy, providing maximum flexibility and power. Unlike Declarative Pipeline, Scripted Pipeline uses imperative programming and has few structural restrictions.

## Basic Structure

```groovy
node {
    stage('Build') {
        echo 'Building...'
    }

    stage('Test') {
        echo 'Testing...'
    }

    stage('Deploy') {
        echo 'Deploying...'
    }
}
```

## node Block

The `node` block allocates an executor (agent) for the pipeline.

```groovy
// Run on any available agent
node {
    // steps here
}

// Run on specific labeled agent
node('linux') {
    // steps here
}

// Run on Docker agent
node('docker') {
    // steps here
}

// Run on specific node
node('master') {
    // steps here
}

// Run on agent matching expression
node('linux && java11') {
    // steps here
}
```

## stage Block

Stages organize pipeline into logical sections (mainly for visualization).

```groovy
node {
    stage('Checkout') {
        checkout scm
    }

    stage('Build') {
        sh 'make build'
    }

    stage('Test') {
        sh 'make test'
    }
}
```

## Variables and Data Types

### Variable Declaration

```groovy
// Using def (recommended for local scope)
def myString = 'Hello'
def myNumber = 42
def myBoolean = true
def myList = [1, 2, 3]
def myMap = [key1: 'value1', key2: 'value2']

// Without def (global scope - use cautiously)
globalVar = 'accessible everywhere'

// Typed variables
String name = 'Jenkins'
Integer count = 10
Boolean flag = false
List<String> items = ['a', 'b', 'c']
Map<String, String> config = [env: 'prod', version: '1.0']
```

### String Interpolation

```groovy
def name = 'World'

// Double quotes for interpolation
def greeting = "Hello, ${name}!"

// Single quotes for literal strings
def literal = 'Hello, ${name}!'  // Won't interpolate

// Multi-line strings
def multiLine = """
    This is a
    multi-line string
    with ${name}
"""

// Multi-line without interpolation
def multiLineLiteral = '''
    This is a
    literal multi-line string
    with ${name}
'''
```

## Control Structures

### if-else

```groovy
node {
    def environment = 'production'

    if (environment == 'production') {
        echo 'Deploying to production'
    } else if (environment == 'staging') {
        echo 'Deploying to staging'
    } else {
        echo 'Deploying to development'
    }

    // Ternary operator
    def message = (environment == 'production') ? 'PROD' : 'NON-PROD'
}
```

### for Loops

```groovy
node {
    // Iterate over list
    def items = ['build', 'test', 'deploy']
    for (item in items) {
        echo "Step: ${item}"
    }

    // Iterate with index
    for (int i = 0; i < items.size(); i++) {
        echo "${i}: ${items[i]}"
    }

    // Range iteration
    for (i in 0..5) {
        echo "Number: ${i}"
    }

    // Each method
    items.each { item ->
        echo "Processing ${item}"
    }

    // Each with index
    items.eachWithIndex { item, index ->
        echo "${index}: ${item}"
    }
}
```

### while Loops

```groovy
node {
    def counter = 0
    while (counter < 5) {
        echo "Counter: ${counter}"
        counter++
    }
}
```

### switch Statement

```groovy
node {
    def environment = 'staging'

    switch(environment) {
        case 'development':
            echo 'Dev environment'
            break
        case 'staging':
            echo 'Staging environment'
            break
        case 'production':
            echo 'Production environment'
            break
        default:
            error 'Unknown environment'
    }
}
```

## Error Handling

### try-catch-finally

```groovy
node {
    try {
        sh 'make build'
        sh 'make test'
    } catch (Exception e) {
        echo "Build failed: ${e.message}"
        currentBuild.result = 'FAILURE'
        throw e  // Re-throw if needed
    } finally {
        echo 'Cleaning up...'
        sh 'make clean'
    }
}
```

### try-catch with Different Exception Types

```groovy
node {
    try {
        sh 'risky-command'
    } catch (hudson.AbortException e) {
        echo "Process was aborted: ${e.message}"
    } catch (Exception e) {
        echo "General error: ${e.message}"
        currentBuild.result = 'FAILURE'
    }
}
```

### Catching Specific Errors

```groovy
node {
    try {
        def result = sh(script: 'test-command', returnStatus: true)
        if (result != 0) {
            error "Command failed with exit code ${result}"
        }
    } catch (Exception e) {
        echo "Handling error: ${e}"
        // Continue or fail
    }
}
```

## Methods and Functions

### Defining Methods

```groovy
// Method definition
def buildApplication() {
    echo 'Building application...'
    sh 'mvn clean package'
}

// Method with parameters
def deploy(String environment, String version) {
    echo "Deploying version ${version} to ${environment}"
    sh "kubectl set image deployment/app app=${version}"
}

// Method with return value
def getVersion() {
    return sh(script: 'git describe --tags', returnStdout: true).trim()
}

// Usage
node {
    buildApplication()
    def version = getVersion()
    deploy('production', version)
}
```

### @NonCPS Methods

Methods that should not use Continuation Passing Style (for complex Groovy operations).

```groovy
@NonCPS
def parseJson(String json) {
    def jsonSlurper = new groovy.json.JsonSlurper()
    return jsonSlurper.parseText(json)
}

@NonCPS
def processData(data) {
    // Complex Groovy logic that doesn't involve pipeline steps
    return data.collect { it.toUpperCase() }
}

node {
    def json = '{"name": "Jenkins", "version": "2.0"}'
    def parsed = parseJson(json)
    echo "Name: ${parsed.name}"

    // WARNING: Cannot use pipeline steps (sh, echo, etc.) in @NonCPS methods
}
```

## Parallel Execution

### Basic Parallel

```groovy
node {
    stage('Parallel Tests') {
        parallel(
            'Unit Tests': {
                node('linux') {
                    sh 'make unit-test'
                }
            },
            'Integration Tests': {
                node('linux') {
                    sh 'make integration-test'
                }
            },
            'Smoke Tests': {
                node('linux') {
                    sh 'make smoke-test'
                }
            }
        )
    }
}
```

### Parallel with failFast

```groovy
node {
    stage('Deploy to Regions') {
        parallel(
            failFast: true,  // Stop all if one fails
            'Region US-EAST': {
                sh 'deploy-us-east.sh'
            },
            'Region US-WEST': {
                sh 'deploy-us-west.sh'
            },
            'Region EU': {
                sh 'deploy-eu.sh'
            }
        )
    }
}
```

### Dynamic Parallel Execution

```groovy
node {
    def branches = [:]

    def environments = ['dev', 'qa', 'staging']

    for (int i = 0; i < environments.size(); i++) {
        def env = environments[i]  // Important: capture variable

        branches["Deploy to ${env}"] = {
            node {
                echo "Deploying to ${env}"
                sh "deploy.sh ${env}"
            }
        }
    }

    parallel branches
}
```

## Working with Credentials

### Username and Password

```groovy
node {
    withCredentials([usernamePassword(
        credentialsId: 'my-credentials',
        usernameVariable: 'USERNAME',
        passwordVariable: 'PASSWORD'
    )]) {
        sh '''
            echo "Username: $USERNAME"
            # Use $PASSWORD in commands
        '''
    }
}
```

### Secret Text

```groovy
node {
    withCredentials([string(
        credentialsId: 'api-token',
        variable: 'API_TOKEN'
    )]) {
        sh 'curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com'
    }
}
```

### SSH Key

```groovy
node {
    withCredentials([sshUserPrivateKey(
        credentialsId: 'ssh-key',
        keyFileVariable: 'SSH_KEY',
        usernameVariable: 'SSH_USER'
    )]) {
        sh '''
            ssh -i $SSH_KEY $SSH_USER@server.example.com 'deploy.sh'
        '''
    }
}
```

### Multiple Credentials

```groovy
node {
    withCredentials([
        usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS'),
        string(credentialsId: 'api-key', variable: 'API_KEY')
    ]) {
        sh 'docker login -u $DOCKER_USER -p $DOCKER_PASS'
        sh 'curl -H "X-API-Key: $API_KEY" https://api.example.com'
    }
}
```

## Environment Variables

### Setting Environment Variables

```groovy
node {
    // Using withEnv
    withEnv(['ENV=production', 'VERSION=1.0']) {
        sh 'echo "Environment: $ENV, Version: $VERSION"'
    }

    // Direct assignment
    env.MY_VAR = 'value'
    sh 'echo $MY_VAR'

    // From shell command
    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
}
```

### Accessing Environment Variables

```groovy
node {
    echo "Build number: ${env.BUILD_NUMBER}"
    echo "Job name: ${env.JOB_NAME}"
    echo "Workspace: ${env.WORKSPACE}"

    def branch = env.BRANCH_NAME ?: 'main'
    echo "Branch: ${branch}"
}
```

## Common Wrappers

### Timestamps

```groovy
timestamps {
    node {
        echo 'This output will have timestamps'
        sh 'sleep 5'
        echo 'Done'
    }
}
```

### Timeout

```groovy
timeout(time: 30, unit: 'MINUTES') {
    node {
        sh 'long-running-command'
    }
}

// With activity timeout
timeout(time: 5, unit: 'MINUTES', activity: true) {
    node {
        // Timeout if no console output for 5 minutes
        sh 'command-with-output'
    }
}
```

### Retry

```groovy
retry(3) {
    node {
        sh 'flaky-test-command'
    }
}

// With custom condition
retry(3) {
    try {
        sh 'test-command'
    } catch (Exception e) {
        if (e.message.contains('timeout')) {
            throw e  // Retry
        } else {
            return  // Don't retry
        }
    }
}
```

### Lock

```groovy
lock(resource: 'deployment-lock', inversePrecedence: true) {
    node {
        echo 'Only one build can deploy at a time'
        sh 'deploy.sh'
    }
}
```

### AnsiColor

```groovy
ansiColor('xterm') {
    node {
        sh 'ls --color=always'
    }
}
```

## Working with Docker

### Using Docker Images

```groovy
node {
    docker.image('maven:3.8.1-adoptopenjdk-11').inside {
        sh 'mvn --version'
        sh 'mvn clean package'
    }

    // With additional arguments
    docker.image('maven:3.8.1').inside('-v /tmp:/tmp -e MAVEN_OPTS="-Xmx1024m"') {
        sh 'mvn clean install'
    }
}
```

### Building Docker Images

```groovy
node {
    def image = docker.build("my-app:${env.BUILD_NUMBER}")

    // With custom Dockerfile
    def image2 = docker.build("my-app:latest", "-f Dockerfile.prod .")

    // Push to registry
    docker.withRegistry('https://registry.example.com', 'registry-credentials') {
        image.push()
        image.push('latest')
    }
}
```

### Running Docker Containers

```groovy
node {
    def container = docker.image('nginx:latest').run('-p 8080:80')

    try {
        // Run tests against container
        sh 'curl http://localhost:8080'
    } finally {
        container.stop()
    }
}
```

## Working with Git

### Basic Checkout

```groovy
node {
    checkout scm

    // Or explicit checkout
    checkout([
        $class: 'GitSCM',
        branches: [[name: '*/main']],
        userRemoteConfigs: [[
            url: 'https://github.com/user/repo.git',
            credentialsId: 'github-credentials'
        ]]
    ])
}
```

### Git Operations

```groovy
node {
    // Get commit info
    def commit = sh(script: 'git rev-parse HEAD', returnStdout: true).trim()
    def shortCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    def branch = sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()

    echo "Commit: ${commit}"
    echo "Short: ${shortCommit}"
    echo "Branch: ${branch}"

    // Tag
    sh "git tag -a v${env.BUILD_NUMBER} -m 'Build ${env.BUILD_NUMBER}'"
    sh 'git push origin --tags'
}
```

## Stash and Unstash

```groovy
node('build-agent') {
    stage('Build') {
        sh 'make build'
        stash name: 'build-artifacts', includes: 'target/*.jar'
    }
}

node('deploy-agent') {
    stage('Deploy') {
        unstash 'build-artifacts'
        sh 'deploy.sh target/*.jar'
    }
}
```

## Input and Approval

```groovy
node {
    stage('Build') {
        sh 'make build'
    }

    stage('Approval') {
        def userInput = input(
            message: 'Deploy to production?',
            parameters: [
                choice(name: 'ENVIRONMENT', choices: ['staging', 'production'], description: 'Target environment'),
                string(name: 'VERSION', defaultValue: '1.0', description: 'Version to deploy')
            ],
            submitter: 'admin,ops'
        )

        echo "Deploying ${userInput.VERSION} to ${userInput.ENVIRONMENT}"
    }

    stage('Deploy') {
        sh "deploy.sh ${userInput.ENVIRONMENT} ${userInput.VERSION}"
    }
}
```

## Build Parameters

```groovy
properties([
    parameters([
        string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: 'Deployment environment'),
        choice(name: 'VERSION', choices: ['1.0', '1.1', '2.0'], description: 'Version'),
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run tests')
    ])
])

node {
    echo "Environment: ${params.DEPLOY_ENV}"
    echo "Version: ${params.VERSION}"

    if (params.RUN_TESTS) {
        sh 'make test'
    }
}
```

## Accessing Build Information

```groovy
node {
    // Current build
    echo "Build number: ${currentBuild.number}"
    echo "Build result: ${currentBuild.result}"  // SUCCESS, FAILURE, UNSTABLE, ABORTED
    echo "Display name: ${currentBuild.displayName}"
    echo "Duration: ${currentBuild.duration}"

    // Set build properties
    currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.BRANCH_NAME}"
    currentBuild.description = "Deployed version ${version}"
    currentBuild.result = 'SUCCESS'

    // Previous build
    if (currentBuild.previousBuild) {
        echo "Previous result: ${currentBuild.previousBuild.result}"
    }
}
```

## Complete Example

```groovy
@Library('shared-library@master') _

// Build properties
properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    disableConcurrentBuilds(),
    parameters([
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment'),
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip tests')
    ])
])

// Variables
def version
def dockerImage

// Helper methods
def buildApp() {
    sh 'mvn clean package'
}

@NonCPS
def parseVersion(String pomXml) {
    def matcher = (pomXml =~ /<version>(.+)<\/version>/)
    return matcher[0][1]
}

// Main pipeline
timestamps {
    ansiColor('xterm') {
        node('linux') {
            try {
                stage('Checkout') {
                    checkout scm
                    version = sh(script: 'git describe --tags --always', returnStdout: true).trim()
                    currentBuild.displayName = "#${env.BUILD_NUMBER} - ${version}"
                }

                stage('Build') {
                    docker.image('maven:3.8.1-adoptopenjdk-11').inside {
                        buildApp()
                        stash name: 'app-jar', includes: 'target/*.jar'
                    }
                }

                if (!params.SKIP_TESTS) {
                    stage('Test') {
                        parallel(
                            'Unit Tests': {
                                sh 'mvn test'
                            },
                            'Integration Tests': {
                                sh 'mvn verify'
                            }
                        )
                        junit '**/target/test-results/*.xml'
                    }
                }

                stage('Docker Build') {
                    unstash 'app-jar'
                    dockerImage = docker.build("myapp:${version}")
                }

                if (params.ENVIRONMENT == 'production') {
                    stage('Approval') {
                        timeout(time: 1, unit: 'HOURS') {
                            input message: 'Deploy to production?', submitter: 'ops,admin'
                        }
                    }
                }

                stage('Deploy') {
                    withCredentials([
                        usernamePassword(credentialsId: 'registry-creds', usernameVariable: 'USER', passwordVariable: 'PASS'),
                        string(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')
                    ]) {
                        sh 'docker login -u $USER -p $PASS registry.example.com'
                        dockerImage.push()

                        sh """
                            kubectl set image deployment/myapp myapp=myapp:${version}
                            kubectl rollout status deployment/myapp
                        """
                    }
                }

                currentBuild.result = 'SUCCESS'

            } catch (Exception e) {
                currentBuild.result = 'FAILURE'
                echo "Pipeline failed: ${e.message}"
                throw e

            } finally {
                stage('Cleanup') {
                    cleanWs()

                    // Send notification
                    def color = currentBuild.result == 'SUCCESS' ? 'good' : 'danger'
                    slackSend color: color, message: "Build ${currentBuild.displayName}: ${currentBuild.result}"
                }
            }
        }
    }
}
```

## References

- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Groovy Language Documentation](http://groovy-lang.org/documentation.html)
- [Jenkins Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)