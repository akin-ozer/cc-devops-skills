// BAD DECLARATIVE PIPELINE - Contains multiple validation issues
// This file is intentionally written poorly to demonstrate validation capabilities

// Missing 'pipeline' wrapper - ERROR
stages {
    // Missing 'agent' directive - ERROR

    // Stage without proper name quotes - ERROR
    stage(Build Stage) {
        // Missing 'steps' block - ERROR
        echo 'Building...';  // Unnecessary semicolon - WARNING
        sh 'echo "Starting build"';  // Multiple individual sh steps - WARNING
        sh 'mkdir build';
        sh 'cd build';
        sh 'make';
        sh 'echo "Build complete"';
    }

    stage('Test') {
        steps {
            // Hardcoded credentials - ERROR
            sh 'docker login -u admin -p password123'

            // Hardcoded API key - ERROR
            sh 'curl -H "Authorization: Bearer abc123xyz789" https://api.example.com'

            // AWS credentials hardcoded - CRITICAL ERROR
            sh 'aws configure set aws_access_key_id AKIAIOSFODNN7EXAMPLE'

            // Test commands without result publishing - WARNING
            sh 'mvn test'
            // Missing: junit '**/target/test-results/*.xml'
        }
    }

    // Directive in wrong place - ERROR
    environment {
        // Should be at pipeline level, not inside stages
        api_key = "hardcoded-secret-key"  // Bad variable naming + hardcoded secret - ERROR
    }

    stage('Deploy') {
        // No 'when' condition for production deploy - WARNING
        steps {
            // JsonSlurper on controller - WARNING
            script {
                def jsonSlurper = new groovy.json.JsonSlurper()
                def config = jsonSlurper.parseText(readFile('config.json'))
            }

            // HTTP request on controller - WARNING
            script {
                def response = new URL('http://api.example.com').getText()
            }

            sh 'kubectl apply -f deployment.yaml'
        }
    }
}

// Missing post section - INFO
// No error handling - WARNING
// No timeout configuration - WARNING
// No workspace cleanup - INFO
// No notifications - INFO
// No artifact archiving - INFO
// No parallel execution for independent stages - INFO

/* Additional Issues:
 * - No build discarder option
 * - No timestamps option
 * - No parameters defined
 * - No triggers configured
 * - No credential management
 * - No proper environment variable naming
 * - No Docker/container usage for consistent builds
 * - Build could hang forever (no timeout)
 * - No input validation
 * - No test result publishing
 * - Pipeline could be >500 lines (maintainability issue if expanded)
 */