// Good Scripted Pipeline Example - Docker CI/CD
// This pipeline demonstrates best practices for Docker-based scripted pipelines

// Build properties
properties([
    buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '5')),
    disableConcurrentBuilds(),
    parameters([
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Target environment'),
        booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Deploy after build')
    ])
])

// Global variables
def dockerImage
def version

timestamps {
    ansiColor('xterm') {
        timeout(time: 1, unit: 'HOURS') {
            node('docker') {
                try {
                    stage('Checkout') {
                        checkout scm
                        version = sh(script: 'git describe --tags --always', returnStdout: true).trim()
                        currentBuild.displayName = "#${env.BUILD_NUMBER} - ${version}"
                    }

                    stage('Build') {
                        docker.image('maven:3.8.1-adoptopenjdk-11').inside('-v $HOME/.m2:/root/.m2') {
                            sh '''
                                echo "Building with Maven..."
                                mvn clean package -DskipTests
                            '''
                        }
                    }

                    stage('Test') {
                        docker.image('maven:3.8.1-adoptopenjdk-11').inside('-v $HOME/.m2:/root/.m2') {
                            try {
                                sh 'mvn test'
                            } finally {
                                junit '**/target/surefire-reports/*.xml'
                            }
                        }
                    }

                    stage('Docker Build') {
                        dockerImage = docker.build("myapp:${version}", "-f Dockerfile .")
                    }

                    if (params.DEPLOY) {
                        stage('Push to Registry') {
                            withCredentials([usernamePassword(
                                credentialsId: 'docker-registry-creds',
                                usernameVariable: 'DOCKER_USER',
                                passwordVariable: 'DOCKER_PASS'
                            )]) {
                                docker.withRegistry('https://registry.example.com', 'docker-registry-creds') {
                                    dockerImage.push()
                                    dockerImage.push('latest')
                                }
                            }
                        }

                        if (params.ENVIRONMENT == 'production') {
                            stage('Approval') {
                                timeout(time: 1, unit: 'HOURS') {
                                    input message: 'Deploy to production?', submitter: 'ops,admin'
                                }
                            }
                        }

                        stage('Deploy') {
                            withCredentials([file(credentialsId: 'kubeconfig', variable: 'KUBECONFIG')]) {
                                sh """
                                    kubectl --kubeconfig=\$KUBECONFIG set image deployment/myapp myapp=myapp:${version}
                                    kubectl --kubeconfig=\$KUBECONFIG rollout status deployment/myapp
                                """
                            }
                        }
                    }

                    currentBuild.result = 'SUCCESS'
                    archiveArtifacts artifacts: 'target/*.jar', fingerprint: true

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