// Good Declarative Pipeline Example - Docker CI/CD
// This pipeline demonstrates best practices for Docker-based builds

pipeline {
    agent {
        docker {
            image 'maven:3.8.1-adoptopenjdk-11'
            args '-v $HOME/.m2:/root/.m2'
        }
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10', artifactNumToKeepStr: '5'))
        disableConcurrentBuilds()
        timeout(time: 1, unit: 'HOURS')
        timestamps()
        ansiColor('xterm')
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'production'], description: 'Deployment environment')
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Run test suite')
        booleanParam(name: 'DEPLOY', defaultValue: false, description: 'Deploy after build')
    }

    environment {
        APP_NAME = 'my-docker-app'
        DOCKER_REGISTRY = 'registry.example.com'
        DOCKER_IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}:${env.BUILD_NUMBER}"
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
                    mvn clean compile -DskipTests
                '''
            }
        }

        stage('Test') {
            when {
                expression { return params.RUN_TESTS }
            }
            failFast true
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh 'mvn test -Dtest=**/unit/**'
                    }
                }
                stage('Integration Tests') {
                    steps {
                        sh 'mvn verify -Dtest=**/integration/**'
                    }
                }
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                sh 'mvn package -DskipTests'
                archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
            }
        }

        stage('Docker Build') {
            agent any
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}")
                }
            }
        }

        stage('Deploy') {
            when {
                allOf {
                    expression { return params.DEPLOY }
                    branch 'main'
                }
            }
            input {
                message "Deploy to ${params.ENVIRONMENT}?"
                ok "Deploy"
                submitter "ops,admin"
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'docker-registry-creds',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        docker login -u $DOCKER_USER -p $DOCKER_PASS ${DOCKER_REGISTRY}
                        docker push ${DOCKER_IMAGE}
                    '''
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            echo "Build ${env.BUILD_NUMBER} succeeded!"
        }
        failure {
            echo "Build ${env.BUILD_NUMBER} failed!"
        }
    }
}