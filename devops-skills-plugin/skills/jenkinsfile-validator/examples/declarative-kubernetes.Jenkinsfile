// Good Declarative Pipeline Example - Kubernetes CI/CD
// This pipeline demonstrates best practices for Kubernetes-based builds

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  containers:
  - name: maven
    image: maven:3.8.1-adoptopenjdk-11
    command:
    - cat
    tty: true
    resources:
      requests:
        memory: "1Gi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
  - name: docker
    image: docker:20.10
    command:
    - cat
    tty: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run/docker.sock
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
  volumes:
  - name: docker-sock
    hostPath:
      path: /var/run/docker.sock
'''
        }
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    environment {
        APP_NAME = 'k8s-app'
        DOCKER_IMAGE = "myregistry/${APP_NAME}:${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                container('maven') {
                    sh '''
                        echo "Building with Maven..."
                        mvn clean package -DskipTests
                    '''
                }
            }
        }

        stage('Test') {
            failFast true
            parallel {
                stage('Unit Tests') {
                    steps {
                        container('maven') {
                            sh 'mvn test'
                        }
                    }
                }
                stage('Code Quality') {
                    steps {
                        container('maven') {
                            sh 'mvn checkstyle:check'
                        }
                    }
                }
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Docker Build') {
            steps {
                container('docker') {
                    sh "docker build -t ${DOCKER_IMAGE} ."
                }
            }
        }

        stage('Deploy to Dev') {
            when {
                branch 'develop'
            }
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig-dev', variable: 'KUBECONFIG')]) {
                        sh '''
                            kubectl --kubeconfig=$KUBECONFIG set image deployment/${APP_NAME} \
                                ${APP_NAME}=${DOCKER_IMAGE}
                            kubectl --kubeconfig=$KUBECONFIG rollout status deployment/${APP_NAME}
                        '''
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            input {
                message "Deploy to production?"
                ok "Deploy"
                submitter "ops,admin"
            }
            steps {
                container('kubectl') {
                    withCredentials([file(credentialsId: 'kubeconfig-prod', variable: 'KUBECONFIG')]) {
                        sh '''
                            kubectl --kubeconfig=$KUBECONFIG set image deployment/${APP_NAME} \
                                ${APP_NAME}=${DOCKER_IMAGE}
                            kubectl --kubeconfig=$KUBECONFIG rollout status deployment/${APP_NAME}
                        '''
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
            echo 'Pipeline succeeded!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}