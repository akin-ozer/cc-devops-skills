"""
Common Jenkins pipeline patterns and templates
"""

try:
    from .syntax_helpers import GroovySyntax, ValidationHelpers
except ImportError:
    from syntax_helpers import GroovySyntax, ValidationHelpers


class PipelinePatterns:
    """Common pipeline pattern templates"""

    @staticmethod
    def ci_pattern(build_tool='maven'):
        """Standard CI pattern: checkout -> build -> test -> archive"""
        patterns = {
            'maven': {
                'build_cmd': 'mvn clean compile',
                'test_cmd': 'mvn test',
                'package_cmd': 'mvn package',
                'test_results': '**/target/surefire-reports/*.xml',
                'artifacts': '**/target/*.jar',
                'docker_image': 'maven:3.9.11-eclipse-temurin-21',
                'tool': 'maven'
            },
            'gradle': {
                'build_cmd': './gradlew clean build',
                'test_cmd': './gradlew test',
                'package_cmd': './gradlew assemble',
                'test_results': '**/build/test-results/**/*.xml',
                'artifacts': '**/build/libs/*.jar',
                'docker_image': 'gradle:9.1-jdk21',
                'tool': 'gradle'
            },
            'npm': {
                'build_cmd': 'npm ci && npm run build',
                'test_cmd': 'npm test',
                'package_cmd': 'npm pack',
                'test_results': '**/test-results/*.xml',
                'artifacts': '**/*.tgz',
                'docker_image': 'node:22-alpine',
                'tool': 'nodejs'
            },
            'python': {
                'build_cmd': 'pip install -r requirements.txt',
                'test_cmd': 'pytest --junitxml=test-results.xml',
                'package_cmd': 'python setup.py sdist bdist_wheel',
                'test_results': '**/test-results.xml',
                'artifacts': 'dist/*',
                'docker_image': 'python:3.12-slim-bookworm',
                'tool': 'python'
            },
            'go': {
                'build_cmd': 'go build ./...',
                'test_cmd': 'go test -v ./... | go-junit-report > test-results.xml',
                'package_cmd': 'go build -o app',
                'test_results': 'test-results.xml',
                'artifacts': 'app',
                'docker_image': 'golang:1.23-alpine',
                'tool': 'go'
            }
        }
        return patterns.get(build_tool.lower(), patterns['maven'])

    @staticmethod
    def cd_pattern():
        """Standard CD pattern: build -> test -> deploy (dev/staging/prod)"""
        return {
            'environments': ['dev', 'staging', 'production'],
            'approval_required': ['staging', 'production'],
            'approvers': 'admin,ops-team'
        }

    @staticmethod
    def docker_build_pattern():
        """Docker build and push pattern"""
        return {
            'build_cmd': 'docker build -t ${DOCKER_IMAGE}:${BUILD_NUMBER} .',
            'tag_latest': 'docker tag ${DOCKER_IMAGE}:${BUILD_NUMBER} ${DOCKER_IMAGE}:latest',
            'push_cmd': 'docker push ${DOCKER_IMAGE}:${BUILD_NUMBER}',
            'push_latest': 'docker push ${DOCKER_IMAGE}:latest',
            'test_cmd': 'docker run --rm ${DOCKER_IMAGE}:${BUILD_NUMBER} test'
        }

    @staticmethod
    def kubernetes_deploy_pattern():
        """Kubernetes deployment pattern"""
        return {
            'update_image': 'kubectl set image deployment/${DEPLOYMENT_NAME} ${CONTAINER_NAME}=${IMAGE}:${TAG}',
            'apply_manifests': 'kubectl apply -f k8s/',
            'rollout_status': 'kubectl rollout status deployment/${DEPLOYMENT_NAME}',
            'rollback': 'kubectl rollout undo deployment/${DEPLOYMENT_NAME}'
        }

    @staticmethod
    def parallel_test_pattern():
        """Parallel test execution pattern"""
        return {
            'test_types': ['unit', 'integration', 'e2e'],
            'browsers': ['chrome', 'firefox', 'safari'],
            'platforms': ['linux', 'windows', 'mac']
        }

    @staticmethod
    def performance_pattern(level='balanced'):
        """Pipeline performance optimization patterns with durability hints.

        Args:
            level: 'fast', 'balanced', or 'durable'
                - fast: Maximum performance (PERFORMANCE_OPTIMIZED) - use for basic build-test pipelines
                - balanced: Faster but survives most crashes (SURVIVABLE_NONATOMIC)
                - durable: Maximum durability (MAX_SURVIVABILITY) - use for mission-critical pipelines

        Returns:
            dict: Configuration options for the specified performance level
        """
        patterns = {
            'fast': {
                'durability_hint': 'PERFORMANCE_OPTIMIZED',
                'description': 'Maximum performance, minimal persistence (2-6x faster). Use for pipelines that can be safely re-run.',
                'options': """options {
    durabilityHint('PERFORMANCE_OPTIMIZED')
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 1, unit: 'HOURS')
    timestamps()
}"""
            },
            'balanced': {
                'durability_hint': 'SURVIVABLE_NONATOMIC',
                'description': 'Faster but survives most Jenkins crashes. Good balance for most pipelines.',
                'options': """options {
    durabilityHint('SURVIVABLE_NONATOMIC')
    buildDiscarder(logRotator(numToKeepStr: '20'))
    timeout(time: 2, unit: 'HOURS')
    timestamps()
    preserveStashes(buildCount: 5)
}"""
            },
            'durable': {
                'durability_hint': 'MAX_SURVIVABILITY',
                'description': 'Maximum durability (default, slowest). Use for mission-critical audit pipelines.',
                'options': """options {
    durabilityHint('MAX_SURVIVABILITY')
    buildDiscarder(logRotator(numToKeepStr: '50', daysToKeepStr: '90'))
    timeout(time: 4, unit: 'HOURS')
    timestamps()
    preserveStashes(buildCount: 10)
}"""
            }
        }
        return patterns.get(level.lower(), patterns['balanced'])


class StageTemplates:
    """Pre-built stage templates"""

    @staticmethod
    def checkout_stage(scm_url=None, branch='main', credentials=None):
        """Generate checkout stage"""
        branch_pattern_literal = GroovySyntax.single_quoted_literal(f'*/{branch}')
        branch_literal = GroovySyntax.single_quoted_literal(branch)
        if scm_url:
            scm_url_literal = GroovySyntax.single_quoted_literal(scm_url)
            if credentials:
                credentials_literal = GroovySyntax.single_quoted_literal(credentials)
                return f"""
        stage('Checkout') {{
            steps {{
                checkout scmGit(
                    branches: [[name: {branch_pattern_literal}]],
                    userRemoteConfigs: [[
                        url: {scm_url_literal},
                        credentialsId: {credentials_literal}
                    ]]
                )
            }}
        }}"""
            else:
                return f"""
        stage('Checkout') {{
            steps {{
                git branch: {branch_literal}, url: {scm_url_literal}
            }}
        }}"""
        else:
            return """
        stage('Checkout') {
            steps {
                checkout scm
            }
        }"""

    @staticmethod
    def build_stage(build_cmd):
        """Generate build stage"""
        build_cmd_literal = GroovySyntax.single_quoted_literal(build_cmd)
        return f"""
        stage('Build') {{
            steps {{
                sh {build_cmd_literal}
            }}
        }}"""

    @staticmethod
    def test_stage(test_cmd, test_results='**/test-results/*.xml'):
        """Generate test stage with reporting"""
        test_cmd_literal = GroovySyntax.single_quoted_literal(test_cmd)
        test_results_literal = GroovySyntax.single_quoted_literal(test_results)
        return f"""
        stage('Test') {{
            steps {{
                sh {test_cmd_literal}
            }}
            post {{
                always {{
                    junit {test_results_literal}
                }}
            }}
        }}"""

    @staticmethod
    def deploy_stage(environment, deploy_cmd, approval=False, approvers='admin'):
        """Generate deployment stage with optional approval"""
        stage_name = ValidationHelpers.normalize_stage_name(
            f"Deploy to {str(environment).strip().title()}"
        )
        stage_name_literal = GroovySyntax.single_quoted_literal(stage_name)
        deploy_message_literal = GroovySyntax.single_quoted_literal(
            f"Deploy to {str(environment).strip()}?"
        )
        approvers_literal = GroovySyntax.single_quoted_literal(approvers)
        deploy_cmd_literal = GroovySyntax.single_quoted_literal(deploy_cmd)
        if approval:
            return f"""
        stage({stage_name_literal}) {{
            input {{
                message {deploy_message_literal}
                ok 'Deploy'
                submitter {approvers_literal}
            }}
            steps {{
                sh {deploy_cmd_literal}
            }}
        }}"""
        else:
            return f"""
        stage({stage_name_literal}) {{
            steps {{
                sh {deploy_cmd_literal}
            }}
        }}"""

    @staticmethod
    def docker_build_stage(image_name, dockerfile='Dockerfile'):
        """Generate Docker build stage"""
        image_literal = GroovySyntax.single_quoted_literal(f'{image_name}:${{BUILD_NUMBER}}')
        build_args_literal = GroovySyntax.single_quoted_literal(f'-f {dockerfile} .')
        return f"""
        stage('Docker Build') {{
            steps {{
                script {{
                    docker.build({image_literal}, {build_args_literal})
                }}
            }}
        }}"""

    @staticmethod
    def docker_push_stage(image_name, registry=None, credentials=None):
        """Generate Docker push stage"""
        image_literal = GroovySyntax.single_quoted_literal(f'{image_name}:${{BUILD_NUMBER}}')
        if registry and credentials:
            registry_literal = GroovySyntax.single_quoted_literal(registry)
            credentials_literal = GroovySyntax.single_quoted_literal(credentials)
            return f"""
        stage('Docker Push') {{
            steps {{
                script {{
                    docker.withRegistry({registry_literal}, {credentials_literal}) {{
                        docker.image({image_literal}).push()
                        docker.image({image_literal}).push('latest')
                    }}
                }}
            }}
        }}"""
        else:
            return f"""
        stage('Docker Push') {{
            steps {{
                script {{
                    docker.image({image_literal}).push()
                    docker.image({image_literal}).push('latest')
                }}
            }}
        }}"""

    @staticmethod
    def parallel_test_stage(test_types=['unit', 'integration'], fail_fast=True):
        """Generate parallel test stages"""
        parallel_stages = []
        for test_type in test_types:
            stage_name = ValidationHelpers.normalize_stage_name(f'{test_type.title()} Tests')
            stage_name_literal = GroovySyntax.single_quoted_literal(stage_name)
            test_cmd_literal = GroovySyntax.single_quoted_literal(f'npm run test:{test_type}')
            parallel_stages.append(f"""
                stage({stage_name_literal}) {{
                    steps {{
                        sh {test_cmd_literal}
                    }}
                }}""")

        stages_str = '\n'.join(parallel_stages)
        fail_fast_line = "            failFast true\n" if fail_fast else ""
        return f"""
        stage('Parallel Tests') {{
{fail_fast_line}
            parallel {{
{stages_str}
            }}
        }}"""


class PostConditions:
    """Common post-condition templates"""

    @staticmethod
    def standard_post(archive_artifacts=None, cleanup=True):
        """Standard post conditions"""
        post_blocks = []

        if cleanup:
            post_blocks.append("""
        always {
            deleteDir()
        }""")

        if archive_artifacts:
            artifacts_literal = GroovySyntax.single_quoted_literal(archive_artifacts)
            post_blocks.append(f"""
        success {{
            archiveArtifacts artifacts: {artifacts_literal}, fingerprint: true
        }}""")

        post_blocks.append("""
        failure {
            echo 'Pipeline failed!'
        }""")

        blocks_str = '\n'.join(post_blocks)
        return f"""
    post {{
{blocks_str}
    }}"""

    @staticmethod
    def notification_post(email=None, slack=None, archive_artifacts=None, cleanup=True):
        """Post conditions with notifications and optional artifact archiving."""
        post_blocks = []
        success_steps = []
        failure_steps = []

        if archive_artifacts:
            artifacts_literal = GroovySyntax.single_quoted_literal(archive_artifacts)
            success_steps.append(
                f"            archiveArtifacts artifacts: {artifacts_literal}, fingerprint: true"
            )

        if email:
            email_literal = GroovySyntax.single_quoted_literal(email)
            success_steps.extend([
                "            emailext(",
                "                subject: \"Build Succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}\",",
                "                body: \"Check console output at ${env.BUILD_URL}\",",
                f"                to: {email_literal}",
                "            )",
            ])
            failure_steps.extend([
                "            emailext(",
                "                subject: \"Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}\",",
                "                body: \"Check console output at ${env.BUILD_URL}\",",
                f"                to: {email_literal}",
                "            )",
            ])

        if slack:
            slack_literal = GroovySyntax.single_quoted_literal(slack)
            success_steps.append(
                f"            slackSend(color: 'good', message: \"Build ${{env.BUILD_NUMBER}} succeeded\", channel: {slack_literal})"
            )
            failure_steps.append(
                f"            slackSend(color: 'danger', message: \"Build ${{env.BUILD_NUMBER}} failed\", channel: {slack_literal})"
            )

        if success_steps:
            post_blocks.append("        success {\n" + "\n".join(success_steps) + "\n        }")

        if failure_steps:
            post_blocks.append("        failure {\n" + "\n".join(failure_steps) + "\n        }")
        else:
            post_blocks.append("""
        failure {
            echo 'Pipeline failed!'
        }""")

        if cleanup:
            post_blocks.append("""
        always {
            deleteDir()
        }""")

        blocks_str = '\n'.join(post_blocks)
        return f"""
    post {{
{blocks_str}
    }}"""


class EnvironmentTemplates:
    """Environment variable templates"""

    @staticmethod
    def standard_env():
        """Standard environment variables"""
        return """
    environment {
        BUILD_ENV = 'production'
        JAVA_HOME = tool name: 'JDK-21', type: 'jdk'
    }"""

    @staticmethod
    def docker_env(registry=None):
        """Docker-related environment variables"""
        if registry:
            return f"""
    environment {{
        DOCKER_REGISTRY = '{registry}'
        DOCKER_IMAGE = '${{DOCKER_REGISTRY}}/${{JOB_NAME}}'
    }}"""
        else:
            return """
    environment {
        DOCKER_IMAGE = "${JOB_NAME}"
    }"""

    @staticmethod
    def aws_env():
        """AWS-related environment variables with credentials"""
        return """
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        AWS_CREDENTIALS = credentials('aws-credentials')
    }"""

    @staticmethod
    def kubernetes_env():
        """Kubernetes-related environment variables"""
        return """
    environment {
        KUBECONFIG = credentials('kubeconfig')
        DEPLOYMENT_NAME = 'myapp'
        NAMESPACE = 'production'
    }"""
