// BAD SCRIPTED PIPELINE - Contains multiple validation issues
// This file is intentionally written poorly to demonstrate validation capabilities

// No timestamps wrapper - INFO
// No ansiColor wrapper - INFO
// No timeout wrapper - WARNING

// Missing 'node' block - WARNING
stage('Checkout') {
    // Code outside node block - not recommended
    checkout scm;  // Unnecessary semicolon - WARNING
}

node {
    // Unbalanced brace example (will be caught)
    stage('Build') {
        // Multiple individual sh steps - WARNING
        sh 'echo "Starting build"';
        sh 'mkdir -p build';
        sh 'cd build';
        sh 'cmake ..';
        sh 'make';
        sh 'echo "Build complete"';

        // Hardcoded credentials - CRITICAL ERROR
        sh 'git config user.name "admin"'
        sh 'git config user.password "supersecret123"'

        // Hardcoded API token - ERROR
        def apiToken = 'sk-1234567890abcdefghijklmnop'
        sh "curl -H 'Authorization: Bearer ${apiToken}' https://api.example.com"

        // Variable without 'def' - INFO
        myVar = 'global variable'  // Should use 'def' for proper scoping

        // Variable with bad interpolation - WARNING
        def message = 'Build number: $BUILD_NUMBER'  // Should use double quotes
    }

    stage('Test') {
        // No try-catch error handling - WARNING
        sh 'npm test'  // Could fail without proper handling
        sh 'pytest tests/'

        // No test result publishing - WARNING
        // Missing: junit '**/test-results/*.xml'

        // JsonSlurper on controller - WARNING (performance issue)
        def jsonSlurper = new groovy.json.JsonSlurper()
        def testResults = jsonSlurper.parseText(readFile('results.json'))

        // Large file read on controller - INFO
        def logFile = readFile('huge-application.log')  // Could be huge!
        def lines = logFile.split('\n')
    }

    stage('Security Scan') {
        // Hardcoded database credentials - CRITICAL ERROR
        def dbUser = "admin"
        def dbPass = "P@ssw0rd123!"

        sh "mysql -u ${dbUser} -p${dbPass} -e 'SELECT * FROM users'"

        // Hardcoded SSH key - CRITICAL ERROR
        sh 'echo "-----BEGIN RSA PRIVATE KEY-----" > /tmp/key.pem'

        // Base64 encoded credential (still detectable) - INFO
        def encodedCred = "YWRtaW46cGFzc3dvcmQ="  // admin:password in base64
    }

    stage('Docker Build') {
        // Docker build without proper tagging - WARNING
        sh 'docker build .'

        // No Docker registry credentials - if pushing
        sh 'docker push myapp'  // Will likely fail
    }

    stage('Complex Logic') {
        // Method that should be @NonCPS but isn't
        def processData(data) {
            // Complex iteration that should be @NonCPS
            return data.collect { it.toUpperCase() }
        }

        // Using pipeline steps in what should be @NonCPS - ERROR if marked
        @NonCPS
        def badMethod() {
            sh 'echo "This will fail!"'  // Can't use pipeline steps in @NonCPS
            sleep 5  // Can't use async steps in @NonCPS
        }
    }

    stage('Parallel Deploy') {
        // Parallel without failFast - INFO
        parallel(
            'Deploy US': {
                sh 'deploy-us.sh'
            },
            'Deploy EU': {
                sh 'deploy-eu.sh'
            }
            // Missing failFast: true
        )
    }

    stage('Manual Approval') {
        // Input without timeout - WARNING
        input message: 'Deploy to production?'  // Could wait forever!

        // No submitter restriction - INFO
        // Missing: submitter: 'admin,ops'
    }

    stage('Production Deploy') {
        // No environment check - WARNING
        // Should check: if (env.BRANCH_NAME == 'main')

        // HTTP request on controller - WARNING
        def response = sh(script: 'curl http://api.example.com/status', returnStdout: true)

        // Should use curl on agent with jq instead of parsing on controller

        sh 'kubectl apply -f production.yaml'
    }

    // No cleanup at end - INFO
    // Missing: cleanWs() or deleteDir()
}

// No error handling (try-catch-finally) - WARNING
// No currentBuild.result setting
// No notifications on failure - INFO
// No proper logging
// No workspace cleanup - INFO

// Unmatched braces (will be caught by validator)
def brokenFunction() {
    if (true) {
        echo "Missing closing brace"
    // Missing }
}

// Unused variable (will be detected)
def unusedVar = 'never used'

// Missing properties configuration
// No build parameters defined
// No build discarder
// No concurrent build control

/* Additional Issues:
 * - No retry for flaky operations
 * - No stash/unstash for artifacts between agents
 * - No proper Git operations (tags, etc.)
 * - No Docker inside() for consistent environment
 * - No Kubernetes pod template
 * - No proper credential management with withCredentials
 * - No environment variable validation
 * - Multiple stages could run in parallel but don't
 * - No archiveArtifacts for build outputs
 * - No fingerprinting
 * - No build description or display name
 * - Could exceed reasonable pipeline size
 * - Few/no comments for complex logic
 * - Hardcoded values instead of parameters
 * - No version tagging
 * - No rollback capability
 */

// Unmatched quotes (will be caught)
def badString = "unclosed string

// Unmatched parentheses (will be caught)
def badFunction(param {
    echo "missing closing paren"
}