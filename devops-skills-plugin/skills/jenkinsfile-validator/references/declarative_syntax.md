# Declarative Pipeline Syntax Reference

Complete reference for Jenkins Declarative Pipeline syntax based on official documentation.

## Basic Structure

```groovy
pipeline {
    agent any

    stages {
        stage('Build') {
            steps {
                echo 'Building...'
            }
        }
    }
}
```

## Required Sections

### 1. pipeline
The outermost block that contains all pipeline code.

```groovy
pipeline {
    // All declarative pipeline code goes here
}
```

### 2. agent
Specifies where the pipeline or stage will execute. **Required** at top level or per stage.

```groovy
// Execute on any available agent
agent any

// Execute on agent with specific label
agent {
    label 'linux'
}

// Execute in Docker container
agent {
    docker {
        image 'maven:3.8.1-adoptopenjdk-11'
        args '-v /tmp:/tmp'
    }
}

// Execute in Kubernetes pod
agent {
    kubernetes {
        yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: maven
    image: maven:3.8.1-adoptopenjdk-11
'''
    }
}

// No agent (stages must define their own)
agent none
```

### 3. stages
Contains a sequence of one or more stage directives. **Required**.

```groovy
stages {
    stage('Build') {
        steps {
            // build steps
        }
    }
    stage('Test') {
        steps {
            // test steps
        }
    }
}
```

### 4. steps
Defines actions to execute within a stage. **Required** in each stage (unless stage has stages).

```groovy
steps {
    echo 'Hello World'
    sh 'make'
    bat 'build.bat'
    script {
        // Groovy script
        def myVar = 'value'
    }
}
```

## Optional Top-Level Directives

### environment
Defines environment variables available to all steps.

```groovy
environment {
    CC = 'clang'
    DISABLE_AUTH = 'true'
    DB_ENGINE = 'sqlite'

    // From credentials
    AWS_ACCESS_KEY_ID = credentials('aws-secret-key-id')

    // From credentials with username/password
    DOCKER_CREDS = credentials('docker-hub-credentials')
    // Creates: DOCKER_CREDS_USR and DOCKER_CREDS_PSW
}
```

### options
Configures pipeline-specific settings.

```groovy
options {
    // Keep only last 10 builds
    buildDiscarder(logRotator(numToKeepStr: '10'))

    // Disable concurrent builds
    disableConcurrentBuilds()

    // Prevent builds from running forever
    timeout(time: 1, unit: 'HOURS')

    // Add timestamps to console output
    timestamps()

    // Retry failed pipeline up to 3 times
    retry(3)

    // Skip default checkout
    skipDefaultCheckout()

    // Prepend all console output with time
    ansiColor('xterm')
}
```

### parameters
Defines build parameters users can provide.

```groovy
parameters {
    string(
        name: 'DEPLOY_ENV',
        defaultValue: 'staging',
        description: 'Environment to deploy to'
    )

    choice(
        name: 'VERSION',
        choices: ['1.0', '1.1', '2.0'],
        description: 'Version to deploy'
    )

    booleanParam(
        name: 'RUN_TESTS',
        defaultValue: true,
        description: 'Run tests before deploy'
    )

    text(
        name: 'RELEASE_NOTES',
        defaultValue: '',
        description: 'Release notes'
    )

    password(
        name: 'SECRET',
        defaultValue: '',
        description: 'Secret value'
    )
}

// Access in pipeline:
// ${params.DEPLOY_ENV}
```

### triggers
Defines automatic build triggers.

```groovy
triggers {
    // Poll SCM every 15 minutes
    pollSCM('H/15 * * * *')

    // Cron schedule
    cron('H 4 * * 1-5')  // Weekdays at 4 AM

    // Trigger from upstream job
    upstream(
        upstreamProjects: 'job1,job2',
        threshold: hudson.model.Result.SUCCESS
    )
}
```

### tools
Auto-installs and configures tools.

```groovy
tools {
    maven 'Maven 3.8.1'
    jdk 'JDK 11'
    gradle 'Gradle 7.0'
}
```

### libraries
Loads shared libraries.

```groovy
@Library('my-shared-library@master') _

// Or
libraries {
    lib('my-shared-library@master')
}
```

## Stage-Level Directives

### agent (stage-level)
Override agent for specific stage.

```groovy
stage('Build') {
    agent {
        docker 'maven:3.8.1-adoptopenjdk-11'
    }
    steps {
        sh 'mvn clean package'
    }
}
```

### environment (stage-level)
Stage-specific environment variables.

```groovy
stage('Deploy') {
    environment {
        DEPLOY_ENV = 'production'
    }
    steps {
        sh 'deploy.sh $DEPLOY_ENV'
    }
}
```

### when
Conditional execution of stage.

```groovy
stage('Deploy to Production') {
    when {
        branch 'main'
        environment name: 'DEPLOY_ENV', value: 'production'
        expression { return params.RUN_DEPLOY }
    }
    steps {
        echo 'Deploying...'
    }
}

// When conditions:
when {
    branch 'main'                              // Branch name
    branch pattern: "release-\\d+", comparator: "REGEXP"

    environment name: 'DEPLOY', value: 'true'  // Environment variable

    expression { return currentBuild.result == null }  // Groovy expression

    tag "release-*"                            // Git tag
    tag pattern: "release-\\d+", comparator: "REGEXP"

    not { branch 'main' }                      // Negation

    allOf {                                    // AND
        branch 'main'
        environment name: 'DEPLOY', value: 'true'
    }

    anyOf {                                    // OR
        branch 'main'
        branch 'develop'
    }

    triggeredBy 'UserIdCause'                  // Trigger type
    triggeredBy cause: 'UserIdCause', detail: 'admin'

    buildingTag()                              // Building a tag

    changelog '.*\\[DEPLOY\\].*'               // Changelog pattern

    changeset "**/*.js"                        // Changed files

    equals expected: 2, actual: currentBuild.number  // Comparison
}
```

### input
Pause for user input.

```groovy
stage('Deploy') {
    input {
        message "Deploy to production?"
        ok "Deploy"
        submitter "admin,ops"
        parameters {
            string(name: 'VERSION', description: 'Version to deploy')
        }
    }
    steps {
        echo "Deploying ${VERSION}"
    }
}
```

### options (stage-level)
Stage-specific options.

```groovy
stage('Test') {
    options {
        timeout(time: 30, unit: 'MINUTES')
        retry(2)
        timestamps()
    }
    steps {
        sh 'run-tests.sh'
    }
}
```

## post
Runs after pipeline/stage completion.

```groovy
post {
    always {
        // Always run, regardless of status
        echo 'Pipeline completed'
        cleanWs()
    }

    success {
        // Run only if successful
        slackSend color: 'good', message: 'Build succeeded!'
    }

    failure {
        // Run only if failed
        mail to: 'team@example.com',
             subject: "Build Failed: ${currentBuild.fullDisplayName}",
             body: "Something is wrong"
    }

    unstable {
        // Run if unstable (tests failed but build succeeded)
        echo 'Build is unstable'
    }

    changed {
        // Run if status changed from previous build
        echo 'Build status changed'
    }

    fixed {
        // Run if previous build failed but current succeeded
        echo 'Build is fixed'
    }

    regression {
        // Run if previous build succeeded but current failed
        echo 'Build regressed'
    }

    aborted {
        // Run if aborted
        echo 'Build was aborted'
    }

    cleanup {
        // Always run, after all other post conditions
        echo 'Cleaning up...'
        deleteDir()
    }
}
```

## Parallel Stages

Execute stages in parallel.

```groovy
stage('Parallel Tests') {
    parallel {
        stage('Test on Linux') {
            agent { label 'linux' }
            steps {
                sh 'make test'
            }
        }
        stage('Test on Windows') {
            agent { label 'windows' }
            steps {
                bat 'make test'
            }
        }
        stage('Test on Mac') {
            agent { label 'mac' }
            steps {
                sh 'make test'
            }
        }
    }
}

// With failFast
stage('Parallel Deploy') {
    failFast true  // Stop all parallel stages if one fails
    parallel {
        stage('Deploy to Region 1') {
            steps { sh 'deploy-region1.sh' }
        }
        stage('Deploy to Region 2') {
            steps { sh 'deploy-region2.sh' }
        }
    }
}
```

## Sequential Stages

Nested stages that run sequentially.

```groovy
stage('Build and Test') {
    stages {
        stage('Build') {
            steps {
                sh 'make build'
            }
        }
        stage('Test') {
            steps {
                sh 'make test'
            }
        }
    }
}
```

## Matrix

Run stages across combinations of axes.

```groovy
stage('Test') {
    matrix {
        axes {
            axis {
                name 'PLATFORM'
                values 'linux', 'mac', 'windows'
            }
            axis {
                name 'BROWSER'
                values 'chrome', 'firefox', 'safari'
            }
        }

        excludes {
            exclude {
                axis {
                    name 'PLATFORM'
                    values 'linux'
                }
                axis {
                    name 'BROWSER'
                    values 'safari'
                }
            }
        }

        stages {
            stage('Test') {
                steps {
                    echo "Testing on ${PLATFORM} with ${BROWSER}"
                }
            }
        }
    }
}
```

## Common Steps

```groovy
steps {
    // Shell commands
    sh 'echo "Hello"'
    sh '''
        echo "Multi-line"
        echo "shell script"
    '''
    sh(script: 'ls -la', returnStdout: true)
    sh(script: 'exit 1', returnStatus: true)

    // Windows batch
    bat 'echo Hello'

    // PowerShell
    powershell 'Write-Host "Hello"'

    // Echo
    echo 'Message'

    // Error
    error 'Build failed'

    // Retry
    retry(3) {
        sh 'flaky-command'
    }

    // Timeout
    timeout(time: 5, unit: 'MINUTES') {
        sh 'long-running-command'
    }

    // Script (run Groovy code)
    script {
        def myVar = 'value'
        if (myVar == 'value') {
            echo 'Condition met'
        }
    }

    // Credentials
    withCredentials([string(credentialsId: 'my-secret', variable: 'SECRET')]) {
        sh 'echo $SECRET'
    }

    // Git checkout
    checkout scm
    checkout([
        $class: 'GitSCM',
        branches: [[name: '*/main']],
        userRemoteConfigs: [[url: 'https://github.com/user/repo.git']]
    ])

    // Archive artifacts
    archiveArtifacts artifacts: '**/*.jar', fingerprint: true

    // Publish test results
    junit '**/target/test-results/*.xml'

    // Stash/unstash
    stash name: 'build-artifacts', includes: 'target/*.jar'
    unstash 'build-artifacts'

    // Delete workspace
    deleteDir()

    // Clean workspace
    cleanWs()
}
```

## Built-in Variables

```groovy
// Build info
currentBuild.number          // Build number
currentBuild.result          // SUCCESS, FAILURE, UNSTABLE, ABORTED
currentBuild.currentResult   // Current result
currentBuild.displayName     // Display name
currentBuild.description     // Build description
currentBuild.duration        // Build duration in ms

// Environment variables
env.BUILD_ID
env.BUILD_NUMBER
env.BUILD_TAG
env.BUILD_URL
env.JOB_NAME
env.JOB_BASE_NAME
env.NODE_NAME
env.WORKSPACE
env.JENKINS_HOME
env.BRANCH_NAME              // For multibranch pipelines
env.CHANGE_ID                // For pull requests
env.GIT_COMMIT
env.GIT_BRANCH

// Parameters
params.PARAMETER_NAME

// SCM
scm.userRemoteConfigs
scm.branches
```

## Complete Example

```groovy
pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Deployment environment')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run tests')
    }

    environment {
        APP_NAME = 'my-app'
        VERSION = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "${APP_NAME}:${VERSION}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            agent {
                docker {
                    image 'maven:3.8.1-adoptopenjdk-11'
                }
            }
            steps {
                sh 'mvn clean package'
                stash name: 'build-artifacts', includes: 'target/*.jar'
            }
        }

        stage('Test') {
            when {
                expression { return params.RUN_TESTS }
            }
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
            }
            post {
                always {
                    junit '**/target/test-results/*.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                unstash 'build-artifacts'
                sh "docker build -t ${DOCKER_IMAGE} ."
            }
        }

        stage('Deploy') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to ${params.ENVIRONMENT}?"
                ok "Deploy"
                submitter "ops,admin"
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'docker-hub', usernameVariable: 'USER', passwordVariable: 'PASS')]) {
                    sh '''
                        docker login -u $USER -p $PASS
                        docker push ${DOCKER_IMAGE}
                    '''
                }
                sh "kubectl set image deployment/${APP_NAME} ${APP_NAME}=${DOCKER_IMAGE}"
            }
        }
    }

    post {
        success {
            slackSend color: 'good', message: "Build ${env.BUILD_NUMBER} succeeded"
        }
        failure {
            mail to: 'team@example.com',
                 subject: "Build ${env.BUILD_NUMBER} failed",
                 body: "Check ${env.BUILD_URL}"
        }
        cleanup {
            cleanWs()
        }
    }
}
```

## References

- [Official Pipeline Syntax Documentation](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Pipeline Steps Reference](https://www.jenkins.io/doc/pipeline/steps/)
- [Pipeline Development Tools](https://www.jenkins.io/doc/book/pipeline/development/)