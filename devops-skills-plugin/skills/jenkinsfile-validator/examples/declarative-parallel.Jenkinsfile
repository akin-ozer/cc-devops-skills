// Good Declarative Pipeline Example - Parallel Stages
// This pipeline demonstrates best practices for parallel execution

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh '''
                    echo "Building application..."
                    mkdir -p dist
                    echo "Build complete"
                '''
            }
        }

        stage('Quality Gates') {
            failFast true
            parallel {
                stage('Unit Tests') {
                    agent {
                        label 'linux'
                    }
                    steps {
                        sh 'echo "Running unit tests..."'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: '**/unit-test-results/*.xml'
                        }
                    }
                }
                stage('Integration Tests') {
                    agent {
                        label 'linux'
                    }
                    steps {
                        sh 'echo "Running integration tests..."'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: '**/integration-test-results/*.xml'
                        }
                    }
                }
                stage('Security Scan') {
                    agent {
                        label 'security'
                    }
                    steps {
                        sh 'echo "Running security scan..."'
                    }
                }
                stage('Code Quality') {
                    agent {
                        label 'linux'
                    }
                    steps {
                        sh 'echo "Running code quality checks..."'
                    }
                }
            }
        }

        stage('Package') {
            steps {
                sh 'echo "Creating deployment package..."'
                archiveArtifacts artifacts: 'dist/**/*', fingerprint: true, allowEmptyArchive: true
            }
        }

        stage('Deploy') {
            failFast true
            parallel {
                stage('Deploy to Region US-East') {
                    steps {
                        sh 'echo "Deploying to US-East..."'
                    }
                }
                stage('Deploy to Region US-West') {
                    steps {
                        sh 'echo "Deploying to US-West..."'
                    }
                }
                stage('Deploy to Region EU') {
                    steps {
                        sh 'echo "Deploying to EU..."'
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo 'All parallel stages completed successfully!'
        }
        failure {
            echo 'One or more parallel stages failed!'
        }
    }
}