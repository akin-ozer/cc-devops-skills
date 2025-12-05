// Declarative Pipeline with Unknown/Custom Plugins
// This example is designed to test the plugin documentation lookup workflow
// It contains plugins NOT in references/common_plugins.md that require Claude to look them up

pipeline {
    agent any

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    environment {
        APP_NAME = 'my-application'
        APP_VERSION = '1.0.0'
        NEXUS_URL = 'https://nexus.example.com'
        SONAR_URL = 'https://sonarqube.example.com'
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
                    echo "Building ${APP_NAME} version ${APP_VERSION}"
                    ./gradlew clean build -x test
                '''
            }
        }

        stage('Code Quality') {
            steps {
                // Unknown Plugin: SonarQube Scanner
                // Claude should look this up: "Jenkins sonarqube scanner plugin"
                withSonarQubeEnv('SonarQube') {
                    sh './gradlew sonarqube'
                }

                // Unknown Plugin: Quality Gate
                // Part of SonarQube plugin
                waitForQualityGate abortPipeline: true
            }
        }

        stage('Security Scan') {
            steps {
                // Unknown Plugin: OWASP Dependency Check
                // Claude should look this up
                dependencyCheck additionalArguments: '--scan ./', odcInstallation: 'dependency-check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage('Publish Artifacts') {
            steps {
                // Unknown Plugin: Nexus Artifact Uploader
                // Claude should look this up: "Jenkins nexus artifact uploader plugin"
                nexusArtifactUploader(
                    nexusVersion: 'nexus3',
                    protocol: 'https',
                    nexusUrl: "${NEXUS_URL}",
                    groupId: 'com.example',
                    version: "${APP_VERSION}",
                    repository: 'maven-releases',
                    credentialsId: 'nexus-credentials',
                    artifacts: [
                        [artifactId: "${APP_NAME}", classifier: '', file: "build/libs/${APP_NAME}-${APP_VERSION}.jar", type: 'jar']
                    ]
                )
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                // Unknown Plugin: Kubernetes Continuous Deploy
                // Different from kubernetes plugin - Claude should look this up
                kubernetesDeploy(
                    configs: 'k8s/*.yaml',
                    kubeConfig: [path: ''],
                    enableConfigSubstitution: true
                )
            }
        }

        stage('Performance Test') {
            steps {
                // Unknown Plugin: Performance Plugin
                // Claude should look this up
                perfReport sourceDataFiles: 'results/*.jtl',
                    compareBuildPrevious: true,
                    errorFailedThreshold: 5,
                    errorUnstableThreshold: 10
            }
        }

        stage('Notify') {
            steps {
                // Unknown Plugin: Datadog
                // Claude should look this up: "Jenkins datadog plugin"
                datadogEvent(
                    title: "Deployment Complete",
                    text: "${APP_NAME} v${APP_VERSION} deployed successfully",
                    alertType: "success",
                    tags: ["app:${APP_NAME}", "version:${APP_VERSION}"]
                )

                // Unknown Plugin: Microsoft Teams
                // Claude should look this up
                office365ConnectorSend(
                    webhookUrl: 'https://outlook.office.com/webhook/xxx',
                    message: "Build ${BUILD_NUMBER} completed for ${APP_NAME}",
                    status: 'Success'
                )

                // Unknown Plugin: Jira
                // Claude should look this up
                jiraComment(
                    issueKey: 'PROJ-123',
                    body: "Deployed ${APP_NAME} v${APP_VERSION} - Build #${BUILD_NUMBER}"
                )
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        failure {
            // Unknown Plugin: PagerDuty
            // Claude should look this up
            pagerduty(
                resolve: false,
                serviceKey: 'xxx',
                incidentKey: "${JOB_NAME}",
                incidentDescription: "Build failed for ${APP_NAME}"
            )
        }
    }
}

/*
 * UNKNOWN PLUGINS IN THIS FILE (for testing plugin lookup):
 *
 * 1. withSonarQubeEnv / waitForQualityGate - SonarQube Scanner Plugin
 * 2. dependencyCheck / dependencyCheckPublisher - OWASP Dependency Check Plugin
 * 3. nexusArtifactUploader - Nexus Artifact Uploader Plugin
 * 4. kubernetesDeploy - Kubernetes Continuous Deploy Plugin
 * 5. perfReport - Performance Plugin
 * 6. datadogEvent - Datadog Plugin
 * 7. office365ConnectorSend - Office 365 Connector Plugin
 * 8. jiraComment - Jira Plugin
 * 9. pagerduty - PagerDuty Plugin
 *
 * Claude should:
 * 1. Run validation script (will pass syntax check)
 * 2. Identify these as unknown plugins
 * 3. Look up documentation using Context7 or WebSearch
 * 4. Provide guidance on proper usage and parameters
 */