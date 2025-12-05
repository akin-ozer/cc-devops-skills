// Good Scripted Pipeline Example - Basic CI
// This pipeline demonstrates best practices for scripted pipelines

// Build properties
properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    disableConcurrentBuilds(),
    parameters([
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment'),
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run test suite')
    ])
])

// Global variables
def version
def buildSuccess = false

// Helper method for Groovy operations
@NonCPS
def parseVersion(String content) {
    def matcher = (content =~ /version\s*=\s*['"](.+)['"]/)
    return matcher ? matcher[0][1] : '1.0.0'
}

timeout(time: 30, unit: 'MINUTES') {
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
                    sh '''
                        echo "Starting build..."
                        mkdir -p build
                        echo "Compiling application..."
                        echo "Build complete"
                    '''
                }

                if (params.RUN_TESTS) {
                    stage('Test') {
                        try {
                            sh 'echo "Running tests..."'
                            // Publish test results
                            junit allowEmptyResults: true, testResults: '**/test-results/*.xml'
                        } catch (Exception e) {
                            echo "Tests failed: ${e.message}"
                            throw e
                        }
                    }
                }

                stage('Package') {
                    sh 'echo "Packaging application..."'
                    archiveArtifacts artifacts: 'build/**/*', allowEmptyArchive: true, fingerprint: true
                }

                buildSuccess = true
                currentBuild.result = 'SUCCESS'

            } catch (Exception e) {
                currentBuild.result = 'FAILURE'
                echo "Pipeline failed: ${e.message}"
                throw e

            } finally {
                stage('Cleanup') {
                    cleanWs()

                    // Send notification
                    def status = buildSuccess ? 'succeeded' : 'failed'
                    echo "Build ${env.BUILD_NUMBER} ${status}"
                }
            }
        }
    }
}
}