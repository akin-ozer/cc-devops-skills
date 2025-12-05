// Good Scripted Pipeline Example - Conditional and Parallel Execution
// This pipeline demonstrates best practices for conditional logic and parallel stages

// Build properties
properties([
    buildDiscarder(logRotator(numToKeepStr: '10')),
    parameters([
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment'),
        booleanParam(name: 'RUN_SECURITY_SCAN', defaultValue: true, description: 'Run security scan'),
        booleanParam(name: 'RUN_PERFORMANCE_TEST', defaultValue: false, description: 'Run performance tests')
    ])
])

// Global variables
def testResults = [:]

// Non-CPS method for complex Groovy operations
@NonCPS
def aggregateResults(Map results) {
    def total = results.values().sum { it ? 1 : 0 }
    return "Passed: ${total}/${results.size()}"
}

timestamps {
    ansiColor('xterm') {
        timeout(time: 1, unit: 'HOURS') {
            node('linux') {
                try {
                    stage('Checkout') {
                        checkout scm
                        currentBuild.displayName = "#${env.BUILD_NUMBER} - ${env.BRANCH_NAME ?: 'unknown'}"
                    }

                    stage('Build') {
                        sh '''
                            echo "Building application..."
                            mkdir -p build
                            echo "Build complete"
                        '''
                    }

                    stage('Parallel Tests') {
                        def branches = [:]
                        branches['failFast'] = true

                        branches['Unit Tests'] = {
                            node('linux') {
                                try {
                                    sh 'echo "Running unit tests..."'
                                    testResults['unit'] = true
                                } catch (Exception e) {
                                    testResults['unit'] = false
                                    throw e
                                }
                            }
                        }

                        branches['Integration Tests'] = {
                            node('linux') {
                                try {
                                    sh 'echo "Running integration tests..."'
                                    testResults['integration'] = true
                                } catch (Exception e) {
                                    testResults['integration'] = false
                                    throw e
                                }
                            }
                        }

                        if (params.RUN_SECURITY_SCAN) {
                            branches['Security Scan'] = {
                                node('security') {
                                    try {
                                        sh 'echo "Running security scan..."'
                                        testResults['security'] = true
                                    } catch (Exception e) {
                                        testResults['security'] = false
                                        throw e
                                    }
                                }
                            }
                        }

                        if (params.RUN_PERFORMANCE_TEST) {
                            branches['Performance Tests'] = {
                                node('performance') {
                                    try {
                                        sh 'echo "Running performance tests..."'
                                        testResults['performance'] = true
                                    } catch (Exception e) {
                                        testResults['performance'] = false
                                        throw e
                                    }
                                }
                            }
                        }

                        parallel branches
                    }

                    // Conditional deployment based on branch
                    if (env.BRANCH_NAME == 'main' || env.BRANCH_NAME == 'master') {
                        stage('Deploy to Production') {
                            timeout(time: 30, unit: 'MINUTES') {
                                input message: 'Deploy to production?', submitter: 'ops,admin'
                            }

                            withCredentials([string(credentialsId: 'deploy-token', variable: 'DEPLOY_TOKEN')]) {
                                sh 'echo "Deploying to production..."'
                            }
                        }
                    } else if (env.BRANCH_NAME == 'develop') {
                        stage('Deploy to Staging') {
                            withCredentials([string(credentialsId: 'deploy-token', variable: 'DEPLOY_TOKEN')]) {
                                sh 'echo "Deploying to staging..."'
                            }
                        }
                    } else {
                        echo "Skipping deployment for branch: ${env.BRANCH_NAME}"
                    }

                    currentBuild.result = 'SUCCESS'
                    echo "Test results: ${aggregateResults(testResults)}"

                } catch (Exception e) {
                    currentBuild.result = 'FAILURE'
                    echo "Pipeline failed: ${e.message}"
                    throw e

                } finally {
                    stage('Cleanup') {
                        cleanWs()
                        echo "Build ${env.BUILD_NUMBER} completed with status: ${currentBuild.result}"
                    }
                }
            }
        }
    }
}