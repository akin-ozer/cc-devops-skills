#!/usr/bin/env python3
"""
Jenkins Shared Library Scaffolding Generator

Generates a complete shared library structure following Jenkins best practices.

Usage:
    python generate_shared_library.py --name my-jenkins-library --output ./output

Structure generated:
    my-jenkins-library/
    ├── src/
    │   └── org/
    │       └── example/
    │           └── Utils.groovy
    ├── vars/
    │   ├── log.groovy
    │   ├── log.txt
    │   ├── buildApp.groovy
    │   ├── buildApp.txt
    │   ├── deployApp.groovy
    │   └── deployApp.txt
    ├── resources/
    │   └── org/
    │       └── example/
    │           └── config.json
    └── README.md
"""

import argparse
import os
from datetime import datetime


class SharedLibraryGenerator:
    """Generates Jenkins Shared Library scaffolding"""

    def __init__(self, name, package='org.example', output_dir='.'):
        self.name = name
        self.package = package
        self.package_path = package.replace('.', '/')
        self.output_dir = os.path.join(output_dir, name)
        self.timestamp = datetime.now().strftime('%Y-%m-%d')

    def generate(self):
        """Generate the complete shared library structure"""
        self._create_directory_structure()
        self._generate_src_files()
        self._generate_vars_files()
        self._generate_resources()
        self._generate_readme()
        print(f"Shared library '{self.name}' generated at: {self.output_dir}")

    def _create_directory_structure(self):
        """Create the directory structure"""
        dirs = [
            f"src/{self.package_path}",
            "vars",
            f"resources/{self.package_path}",
            "test/groovy",
        ]
        for dir_path in dirs:
            os.makedirs(os.path.join(self.output_dir, dir_path), exist_ok=True)

    def _generate_src_files(self):
        """Generate src/ Groovy class files"""
        # Utils.groovy
        utils_content = f'''package {self.package}

/**
 * Utility class for common pipeline operations
 * Generated: {self.timestamp}
 */
class Utils implements Serializable {{

    /**
     * Get the current Git branch name
     */
    static String getBranchName(script) {{
        return script.sh(
            script: 'git rev-parse --abbrev-ref HEAD',
            returnStdout: true
        ).trim()
    }}

    /**
     * Get the current Git commit SHA
     */
    static String getCommitSha(script) {{
        return script.sh(
            script: 'git rev-parse HEAD',
            returnStdout: true
        ).trim()
    }}

    /**
     * Get short commit SHA (7 characters)
     */
    static String getShortCommitSha(script) {{
        return script.sh(
            script: 'git rev-parse --short HEAD',
            returnStdout: true
        ).trim()
    }}

    /**
     * Check if running on a specific branch
     */
    static boolean isMainBranch(script) {{
        def branch = getBranchName(script)
        return branch == 'main' || branch == 'master'
    }}

    /**
     * Validate required environment variables
     */
    static void validateEnvVars(script, List<String> requiredVars) {{
        def missing = requiredVars.findAll {{ !script.env[it] }}
        if (missing) {{
            script.error("Missing required environment variables: ${{missing.join(', ')}}")
        }}
    }}
}}
'''
        self._write_file(f"src/{self.package_path}/Utils.groovy", utils_content)

        # Docker.groovy
        docker_content = f'''package {self.package}

/**
 * Docker utility class for container operations
 * Generated: {self.timestamp}
 */
class Docker implements Serializable {{

    private def script
    private String registry
    private String credentialsId

    Docker(script, String registry = null, String credentialsId = null) {{
        this.script = script
        this.registry = registry
        this.credentialsId = credentialsId
    }}

    /**
     * Build a Docker image
     */
    def build(String imageName, String tag = 'latest', String dockerfile = 'Dockerfile', String context = '.') {{
        def fullImageName = registry ? "${{registry}}/${{imageName}}" : imageName
        def imageTag = "${{fullImageName}}:${{tag}}"

        script.echo "Building Docker image: ${{imageTag}}"
        return script.docker.build(imageTag, "-f ${{dockerfile}} ${{context}}")
    }}

    /**
     * Push a Docker image to registry
     */
    def push(def image, String... tags) {{
        if (!registry) {{
            script.error("Registry not configured for push operation")
        }}

        script.docker.withRegistry("https://${{registry}}", credentialsId) {{
            tags.each {{ tag ->
                script.echo "Pushing image with tag: ${{tag}}"
                image.push(tag)
            }}
        }}
    }}

    /**
     * Build and push in one operation
     */
    def buildAndPush(String imageName, List<String> tags = ['latest']) {{
        def image = build(imageName, tags[0])
        push(image, *tags)
        return image
    }}

    /**
     * Run a container for testing
     */
    def test(String imageName, String command) {{
        script.sh "docker run --rm ${{imageName}} ${{command}}"
    }}

    /**
     * Clean up dangling images
     */
    def cleanup() {{
        script.sh 'docker image prune -f || true'
    }}
}}
'''
        self._write_file(f"src/{self.package_path}/Docker.groovy", docker_content)

        # Notifications.groovy
        notifications_content = f'''package {self.package}

/**
 * Notification utilities for pipeline status updates
 * Generated: {self.timestamp}
 */
class Notifications implements Serializable {{

    private def script

    Notifications(script) {{
        this.script = script
    }}

    /**
     * Send Slack notification
     */
    def slack(String channel, String message, String color = 'good') {{
        try {{
            script.slackSend(
                channel: channel,
                color: color,
                message: message
            )
        }} catch (Exception e) {{
            script.echo "Warning: Failed to send Slack notification: ${{e.message}}"
        }}
    }}

    /**
     * Send email notification
     */
    def email(String to, String subject, String body) {{
        try {{
            script.emailext(
                to: to,
                subject: subject,
                body: body,
                mimeType: 'text/html'
            )
        }} catch (Exception e) {{
            script.echo "Warning: Failed to send email notification: ${{e.message}}"
        }}
    }}

    /**
     * Send build status notification
     */
    def buildStatus(String channel = null, String email = null) {{
        def status = script.currentBuild.currentResult ?: 'SUCCESS'
        def color = status == 'SUCCESS' ? 'good' : 'danger'
        def message = """
            *Build ${{status}}*
            Job: ${{script.env.JOB_NAME}} #${{script.env.BUILD_NUMBER}}
            Branch: ${{script.env.BRANCH_NAME ?: 'N/A'}}
            <${{script.env.BUILD_URL}}|View Build>
        """.stripIndent().trim()

        if (channel) {{
            slack(channel, message, color)
        }}

        if (email) {{
            def subject = "[${{status}}] ${{script.env.JOB_NAME}} #${{script.env.BUILD_NUMBER}}"
            this.email(email, subject, message.replace('*', '<b>').replace('</b>', '</b>'))
        }}
    }}
}}
'''
        self._write_file(f"src/{self.package_path}/Notifications.groovy", notifications_content)

    def _generate_vars_files(self):
        """Generate vars/ global variable files"""
        # log.groovy - Logging utilities
        log_groovy = '''/**
 * Logging utilities for Jenkins pipelines
 *
 * Usage:
 *   @Library('my-jenkins-library') _
 *   log.info 'Starting build...'
 *   log.warning 'Deprecated feature used'
 *   log.error 'Build failed!'
 */

def info(String message) {
    echo "\\033[34m[INFO]\\033[0m ${message}"
}

def warning(String message) {
    echo "\\033[33m[WARNING]\\033[0m ${message}"
}

def error(String message) {
    echo "\\033[31m[ERROR]\\033[0m ${message}"
}

def success(String message) {
    echo "\\033[32m[SUCCESS]\\033[0m ${message}"
}

def debug(String message) {
    if (env.DEBUG == 'true') {
        echo "\\033[35m[DEBUG]\\033[0m ${message}"
    }
}
'''
        self._write_file("vars/log.groovy", log_groovy)
        self._write_file("vars/log.txt", "Logging utilities: log.info(), log.warning(), log.error(), log.success(), log.debug()")

        # buildApp.groovy - Standard build function
        build_app_groovy = f'''/**
 * Standard application build function
 *
 * Usage:
 *   @Library('{self.name}') _
 *   buildApp(
 *       buildTool: 'maven',
 *       jdkVersion: 'JDK-21'
 *   )
 */

def call(Map config = [:]) {{
    def buildTool = config.get('buildTool', 'maven')
    def jdkVersion = config.get('jdkVersion', 'JDK-21')
    def skipTests = config.get('skipTests', false)
    def additionalArgs = config.get('additionalArgs', '')

    pipeline {{
        agent any

        tools {{
            jdk jdkVersion
        }}

        stages {{
            stage('Checkout') {{
                steps {{
                    checkout scm
                }}
            }}

            stage('Build') {{
                steps {{
                    script {{
                        switch(buildTool) {{
                            case 'maven':
                                def testFlag = skipTests ? '-DskipTests' : ''
                                sh "mvn clean package ${{testFlag}} ${{additionalArgs}}"
                                break
                            case 'gradle':
                                def testFlag = skipTests ? '-x test' : ''
                                sh "./gradlew clean build ${{testFlag}} ${{additionalArgs}}"
                                break
                            case 'npm':
                                sh 'npm ci'
                                sh "npm run build ${{additionalArgs}}"
                                if (!skipTests) {{
                                    sh 'npm test'
                                }}
                                break
                            default:
                                error "Unknown build tool: ${{buildTool}}"
                        }}
                    }}
                }}
            }}
        }}

        post {{
            always {{
                cleanWs()
            }}
        }}
    }}
}}
'''
        self._write_file("vars/buildApp.groovy", build_app_groovy)
        self._write_file("vars/buildApp.txt", "Build application: buildApp(buildTool: 'maven', jdkVersion: 'JDK-21', skipTests: false)")

        # deployApp.groovy - Deployment function
        deploy_app_groovy = f'''/**
 * Standard deployment function
 *
 * Usage:
 *   @Library('{self.name}') _
 *   deployApp(
 *       environment: 'staging',
 *       kubeConfig: 'kubeconfig-staging',
 *       namespace: 'myapp-staging'
 *   )
 */

def call(Map config = [:]) {{
    def environment = config.get('environment', 'dev')
    def kubeConfig = config.get('kubeConfig')
    def namespace = config.get('namespace', 'default')
    def manifests = config.get('manifests', 'k8s/')
    def approval = config.get('approval', environment != 'dev')

    if (approval) {{
        stage("Approve Deploy to ${{environment}}") {{
            input message: "Deploy to ${{environment}}?",
                  ok: 'Deploy',
                  submitter: 'admin,ops-team'
        }}
    }}

    stage("Deploy to ${{environment}}") {{
        if (kubeConfig) {{
            withCredentials([file(credentialsId: kubeConfig, variable: 'KUBECONFIG')]) {{
                sh """
                    kubectl apply -f ${{manifests}} -n ${{namespace}}
                    kubectl rollout status deployment -n ${{namespace}} --timeout=300s
                """
            }}
        }} else {{
            error "kubeConfig credential ID is required for deployment"
        }}
    }}
}}
'''
        self._write_file("vars/deployApp.groovy", deploy_app_groovy)
        self._write_file("vars/deployApp.txt", "Deploy application: deployApp(environment: 'staging', kubeConfig: 'kubeconfig-staging', namespace: 'myapp')")

        # dockerBuild.groovy - Docker build and push
        docker_build_groovy = f'''/**
 * Docker build and push function
 *
 * Usage:
 *   @Library('{self.name}') _
 *   dockerBuild(
 *       imageName: 'myapp',
 *       registry: 'registry.example.com',
 *       credentialsId: 'docker-registry-creds'
 *   )
 */

def call(Map config = [:]) {{
    def imageName = config.get('imageName', env.JOB_NAME)
    def registry = config.get('registry')
    def credentialsId = config.get('credentialsId')
    def dockerfile = config.get('dockerfile', 'Dockerfile')
    def context = config.get('context', '.')
    def tags = config.get('tags', [env.BUILD_NUMBER, 'latest'])
    def push = config.get('push', true)

    def fullImageName = registry ? "${{registry}}/${{imageName}}" : imageName

    stage('Build Docker Image') {{
        script {{
            def image = docker.build("${{fullImageName}}:${{tags[0]}}", "-f ${{dockerfile}} ${{context}}")

            // Tag with additional tags
            tags.drop(1).each {{ tag ->
                image.tag(tag)
            }}

            if (push && registry && credentialsId) {{
                stage('Push Docker Image') {{
                    docker.withRegistry("https://${{registry}}", credentialsId) {{
                        tags.each {{ tag ->
                            image.push(tag)
                        }}
                    }}
                }}
            }}

            return image
        }}
    }}
}}
'''
        self._write_file("vars/dockerBuild.groovy", docker_build_groovy)
        self._write_file("vars/dockerBuild.txt", "Docker build: dockerBuild(imageName: 'myapp', registry: 'registry.example.com', credentialsId: 'docker-creds')")

        # securityScan.groovy - Security scanning
        security_scan_groovy = f'''/**
 * Security scanning function
 *
 * Usage:
 *   @Library('{self.name}') _
 *   securityScan(
 *       sonarqube: true,
 *       owaspDependencyCheck: true,
 *       trivy: true,
 *       trivyImage: 'myapp:latest'
 *   )
 */

def call(Map config = [:]) {{
    def sonarqube = config.get('sonarqube', false)
    def sonarqubeServer = config.get('sonarqubeServer', 'sonarqube-server')
    def owaspDependencyCheck = config.get('owaspDependencyCheck', false)
    def trivy = config.get('trivy', false)
    def trivyImage = config.get('trivyImage')
    def failOnCritical = config.get('failOnCritical', true)

    def scanStages = [:]

    if (sonarqube) {{
        scanStages['SonarQube Analysis'] = {{
            stage('SonarQube Analysis') {{
                withSonarQubeEnv(sonarqubeServer) {{
                    sh 'mvn sonar:sonar'
                }}
            }}
        }}
    }}

    if (owaspDependencyCheck) {{
        scanStages['OWASP Dependency Check'] = {{
            stage('OWASP Dependency Check') {{
                dependencyCheck(
                    additionalArguments: '--scan . --format HTML --format XML',
                    odcInstallation: 'OWASP-Dependency-Check'
                )
                dependencyCheckPublisher(
                    pattern: 'dependency-check-report.xml',
                    failedTotalCritical: failOnCritical ? 0 : 999
                )
            }}
        }}
    }}

    if (trivy && trivyImage) {{
        scanStages['Trivy Container Scan'] = {{
            stage('Trivy Container Scan') {{
                def severityFlag = failOnCritical ? '--exit-code 1 --severity CRITICAL' : '--severity CRITICAL,HIGH'
                sh """
                    docker run --rm \\
                        -v /var/run/docker.sock:/var/run/docker.sock \\
                        aquasec/trivy:latest image \\
                        ${{severityFlag}} \\
                        --ignore-unfixed \\
                        ${{trivyImage}}
                """
            }}
        }}
    }}

    if (scanStages) {{
        parallel scanStages
    }}

    if (sonarqube) {{
        stage('Quality Gate') {{
            timeout(time: 5, unit: 'MINUTES') {{
                waitForQualityGate abortPipeline: true
            }}
        }}
    }}
}}
'''
        self._write_file("vars/securityScan.groovy", security_scan_groovy)
        self._write_file("vars/securityScan.txt", "Security scanning: securityScan(sonarqube: true, owaspDependencyCheck: true, trivy: true, trivyImage: 'myapp:latest')")

    def _generate_resources(self):
        """Generate resources/ files"""
        config_json = '''{
    "environments": {
        "dev": {
            "namespace": "dev",
            "replicas": 1
        },
        "staging": {
            "namespace": "staging",
            "replicas": 2
        },
        "production": {
            "namespace": "production",
            "replicas": 3
        }
    },
    "notifications": {
        "slack": {
            "channel": "#builds"
        },
        "email": {
            "recipients": "team@example.com"
        }
    }
}
'''
        self._write_file(f"resources/{self.package_path}/config.json", config_json)

    def _generate_readme(self):
        """Generate README.md"""
        readme = f'''# {self.name}

Jenkins Shared Library for CI/CD pipelines.

Generated: {self.timestamp}

## Directory Structure

```
{self.name}/
├── src/                          # Groovy source files (classes)
│   └── {self.package_path}/
│       ├── Utils.groovy          # Utility class
│       ├── Docker.groovy         # Docker operations
│       └── Notifications.groovy  # Notification utilities
├── vars/                         # Global pipeline variables
│   ├── log.groovy                # Logging utilities
│   ├── buildApp.groovy           # Build function
│   ├── deployApp.groovy          # Deployment function
│   ├── dockerBuild.groovy        # Docker build/push
│   └── securityScan.groovy       # Security scanning
├── resources/                    # Resource files
│   └── {self.package_path}/
│       └── config.json           # Configuration data
└── README.md
```

## Installation

### Global Configuration

1. Go to **Manage Jenkins** → **System Configuration** → **Global Pipeline Libraries**
2. Add a new library:
   - **Name**: `{self.name}`
   - **Default version**: `main`
   - **Retrieval method**: Modern SCM → Git
   - **Project Repository**: `<your-git-repo-url>`

### Per-Pipeline Configuration

```groovy
// Jenkinsfile
library identifier: '{self.name}@main', retriever: modernSCM([
    $class: 'GitSCMSource',
    remote: '<your-git-repo-url>',
    credentialsId: 'git-credentials'
])
```

## Usage

### Import the Library

```groovy
@Library('{self.name}') _
```

Or with a specific version:

```groovy
@Library('{self.name}@v1.0.0') _
```

### Available Functions

#### Logging

```groovy
log.info 'Starting build...'
log.warning 'Deprecated feature used'
log.error 'Build failed!'
log.success 'Build completed!'
log.debug 'Debug message (only shown when DEBUG=true)'
```

#### Build Application

```groovy
buildApp(
    buildTool: 'maven',      // 'maven', 'gradle', or 'npm'
    jdkVersion: 'JDK-21',
    skipTests: false,
    additionalArgs: ''
)
```

#### Deploy Application

```groovy
deployApp(
    environment: 'staging',
    kubeConfig: 'kubeconfig-staging',
    namespace: 'myapp-staging',
    manifests: 'k8s/',
    approval: true
)
```

#### Docker Build and Push

```groovy
dockerBuild(
    imageName: 'myapp',
    registry: 'registry.example.com',
    credentialsId: 'docker-registry-creds',
    dockerfile: 'Dockerfile',
    context: '.',
    tags: [env.BUILD_NUMBER, 'latest'],
    push: true
)
```

#### Security Scanning

```groovy
securityScan(
    sonarqube: true,
    sonarqubeServer: 'sonarqube-server',
    owaspDependencyCheck: true,
    trivy: true,
    trivyImage: 'myapp:latest',
    failOnCritical: true
)
```

### Using Classes

```groovy
@Library('{self.name}') _
import {self.package}.Utils
import {self.package}.Docker
import {self.package}.Notifications

pipeline {{
    agent any

    stages {{
        stage('Example') {{
            steps {{
                script {{
                    // Use utility functions
                    def branch = Utils.getBranchName(this)
                    def sha = Utils.getShortCommitSha(this)

                    echo "Building ${{branch}} at ${{sha}}"

                    // Use Docker class
                    def docker = new Docker(this, 'registry.example.com', 'docker-creds')
                    def image = docker.build('myapp', sha)
                    docker.push(image, sha, 'latest')

                    // Use Notifications
                    def notify = new Notifications(this)
                    notify.slack('#builds', "Build completed: ${{sha}}")
                }}
            }}
        }}
    }}
}}
```

### Loading Resources

```groovy
@Library('{self.name}') _

pipeline {{
    agent any

    stages {{
        stage('Load Config') {{
            steps {{
                script {{
                    def config = libraryResource '{self.package_path}/config.json'
                    def configMap = readJSON text: config
                    echo "Production replicas: ${{configMap.environments.production.replicas}}"
                }}
            }}
        }}
    }}
}}
```

## Testing

Unit tests for shared library functions can be added to `test/groovy/`.

See [Jenkins Pipeline Unit Testing Framework](https://github.com/jenkinsci/JenkinsPipelineUnit) for details.

## Contributing

1. Create a feature branch
2. Make your changes
3. Add/update tests
4. Submit a pull request

## License

MIT License
'''
        self._write_file("README.md", readme)

    def _write_file(self, relative_path, content):
        """Write content to a file"""
        file_path = os.path.join(self.output_dir, relative_path)
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        with open(file_path, 'w') as f:
            f.write(content)
        print(f"  Created: {relative_path}")


def main():
    parser = argparse.ArgumentParser(
        description='Generate Jenkins Shared Library scaffolding',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
    %(prog)s --name my-jenkins-library
    %(prog)s --name my-jenkins-library --package com.mycompany.jenkins
    %(prog)s --name my-jenkins-library --output ./output
        '''
    )
    parser.add_argument(
        '--name', '-n',
        required=True,
        help='Name of the shared library'
    )
    parser.add_argument(
        '--package', '-p',
        default='org.example',
        help='Java package name for src/ classes (default: org.example)'
    )
    parser.add_argument(
        '--output', '-o',
        default='.',
        help='Output directory (default: current directory)'
    )

    args = parser.parse_args()

    generator = SharedLibraryGenerator(
        name=args.name,
        package=args.package,
        output_dir=args.output
    )
    generator.generate()


if __name__ == '__main__':
    main()