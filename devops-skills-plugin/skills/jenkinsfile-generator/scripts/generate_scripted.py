#!/usr/bin/env python3
"""
Generate Scripted Jenkins Pipeline

This script generates a Scripted Jenkinsfile with specified configuration.
"""

import argparse
import sys
import os
from pathlib import Path

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent / 'lib'))

from common_patterns import PipelinePatterns
from syntax_helpers import ScriptedSyntax, FormattingHelpers, ValidationHelpers


class ScriptedPipelineGenerator:
    """Generator for Scripted Jenkins Pipelines"""

    def __init__(self, config):
        self.config = config
        self.pipeline_parts = []

    def generate(self):
        """Generate complete scripted pipeline"""
        # Get agent/node configuration
        node_label = self.config.get('agent_label')

        # Build node content
        node_content = self._build_node_content()

        # Create node block
        if node_label:
            pipeline = ScriptedSyntax.node_block(node_label, node_content)
        else:
            pipeline = ScriptedSyntax.node_block(content=node_content)

        # Format and return
        return FormattingHelpers.format_jenkinsfile(
            FormattingHelpers.add_header_comment(
                pipeline,
                f"Scripted Pipeline - {self.config.get('name', 'Generated Pipeline')}"
            )
        )

    def _build_node_content(self):
        """Build content inside node block"""
        parts = []

        # Get stages
        stages = self.config.get('stages', ['build', 'test'])
        build_tool = self.config.get('build_tool', 'maven')
        pattern = PipelinePatterns.ci_pattern(build_tool)

        # Determine if we need try-catch-finally
        use_error_handling = self.config.get('error_handling', True)

        if use_error_handling:
            # Build try block content
            try_content = self._build_stages_content(stages, pattern)

            # Build catch block
            catch_content = """        currentBuild.result = 'FAILURE'
        echo "Pipeline failed: ${e.message}"
        throw e"""

            # Build finally block (cleanup)
            finally_content = ""
            if self.config.get('cleanup', True):
                finally_content = "        deleteDir()"

            # Add notification in catch if configured
            if self.config.get('notification_email'):
                catch_content = f"""        currentBuild.result = 'FAILURE'
        emailext(
            subject: "Build Failed: ${{env.JOB_NAME}} #${{env.BUILD_NUMBER}}",
            body: "Error: ${{e.message}}\\nCheck console output at ${{env.BUILD_URL}}",
            to: '{self.config.get('notification_email')}'
        )
        throw e"""

            node_content = ScriptedSyntax.try_catch_finally(
                try_content, catch_content, finally_content
            )
        else:
            # Simple stages without error handling
            node_content = self._build_stages_content(stages, pattern)
            if self.config.get('cleanup', True):
                node_content += "\n\n    deleteDir()"

        return node_content

    def _build_stages_content(self, stages, pattern):
        """Build stages content"""
        stage_blocks = []

        for stage in stages:
            if stage == 'checkout':
                stage_content = self._generate_checkout_stage()
            elif stage == 'build':
                stage_content = self._generate_build_stage(pattern)
            elif stage == 'test':
                stage_content = self._generate_test_stage(pattern)
            elif stage == 'deploy':
                stage_content = self._generate_deploy_stage()
            elif stage == 'docker-build':
                stage_content = self._generate_docker_build_stage()
            elif stage == 'docker-push':
                stage_content = self._generate_docker_push_stage()
            elif stage == 'parallel-tests':
                stage_content = self._generate_parallel_tests_stage()
            else:
                # Custom stage
                custom_cmd = self.config.get(f'{stage}_cmd', f'echo "Running {stage}"')
                stage_content = f"""        sh '{custom_cmd}'"""

            stage_block = ScriptedSyntax.stage_block(
                stage.capitalize(),
                stage_content
            )
            stage_blocks.append(stage_block)

        return '\n\n'.join(stage_blocks)

    def _generate_checkout_stage(self):
        """Generate checkout stage"""
        scm_url = self.config.get('scm_url')
        branch = self.config.get('branch', 'main')
        credentials = self.config.get('scm_credentials')

        if scm_url:
            if credentials:
                return f"""        checkout scmGit(
            branches: [[name: '*/{branch}']],
            userRemoteConfigs: [[
                url: '{scm_url}',
                credentialsId: '{credentials}'
            ]]
        )"""
            else:
                return f"""        git branch: '{branch}', url: '{scm_url}'"""
        else:
            return """        checkout scm"""

    def _generate_build_stage(self, pattern):
        """Generate build stage"""
        build_cmd = self.config.get('build_cmd', pattern['build_cmd'])

        # Check if using Docker
        if self.config.get('docker_image'):
            docker_image = self.config.get('docker_image')
            docker_args = self.config.get('docker_args', '')
            content = f"""            sh '{build_cmd}'"""

            return ScriptedSyntax.docker_inside_block(docker_image, content, docker_args)
        else:
            return f"""        sh '{build_cmd}'"""

    def _generate_test_stage(self, pattern):
        """Generate test stage"""
        test_cmd = self.config.get('test_cmd', pattern['test_cmd'])
        test_results = self.config.get('test_results', pattern['test_results'])

        content = f"""        sh '{test_cmd}'
        junit '{test_results}'"""

        # Check if using Docker
        if self.config.get('docker_image'):
            docker_image = self.config.get('docker_image')
            docker_args = self.config.get('docker_args', '')
            return ScriptedSyntax.docker_inside_block(docker_image, content, docker_args)
        else:
            return content

    def _generate_deploy_stage(self):
        """Generate deploy stage"""
        deploy_cmd = self.config.get('deploy_cmd', './deploy.sh')
        deploy_env = self.config.get('deploy_env', 'production')
        approval = self.config.get('deploy_approval', True)
        approvers = self.config.get('deploy_approvers', 'admin')

        if approval:
            return f"""        input message: 'Deploy to {deploy_env}?', submitter: '{approvers}'
        sh '{deploy_cmd}'"""
        else:
            return f"""        sh '{deploy_cmd}'"""

    def _generate_docker_build_stage(self):
        """Generate Docker build stage"""
        image_name = self.config.get('docker_image_name', 'myapp')
        dockerfile = self.config.get('dockerfile', 'Dockerfile')

        return f"""        def customImage = docker.build('{image_name}:${{BUILD_NUMBER}}', '-f {dockerfile} .')"""

    def _generate_docker_push_stage(self):
        """Generate Docker push stage"""
        image_name = self.config.get('docker_image_name', 'myapp')
        registry = self.config.get('docker_registry')
        registry_creds = self.config.get('docker_registry_credentials')

        if registry and registry_creds:
            return f"""        docker.withRegistry('{registry}', '{registry_creds}') {{
            docker.image('{image_name}:${{BUILD_NUMBER}}').push()
            docker.image('{image_name}:${{BUILD_NUMBER}}').push('latest')
        }}"""
        else:
            return f"""        docker.image('{image_name}:${{BUILD_NUMBER}}').push()
        docker.image('{image_name}:${{BUILD_NUMBER}}').push('latest')"""

    def _generate_parallel_tests_stage(self):
        """Generate parallel test stages"""
        test_types = self.config.get('test_types', ['unit', 'integration'])

        parallel_stages = {}
        for test_type in test_types:
            parallel_stages[f'{test_type.capitalize()} Tests'] = f"""            sh 'npm run test:{test_type}'"""

        # Return just the content without the stage wrapper
        # because ScriptedSyntax.parallel_block will be wrapped in a stage
        parallel_content = []
        for name, content in parallel_stages.items():
            parallel_content.append(f"""        '{name}': {{
            node {{
{content}
            }}
        }}""")

        return f"""        parallel(
{','.join(parallel_content)}
        )"""


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Generate Scripted Jenkins Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic CI pipeline
  %(prog)s --output Jenkinsfile --stages build,test --build-tool maven

  # Docker-based pipeline
  %(prog)s --output Jenkinsfile --docker-image maven:3.9.9-eclipse-temurin-21

  # Full CD pipeline with deployment
  %(prog)s --output Jenkinsfile --stages checkout,build,test,deploy --deploy-env production

  # Pipeline with specific node label
  %(prog)s --output Jenkinsfile --agent-label linux-docker --stages build,test
        '''
    )

    # Required arguments
    parser.add_argument('--output', '-o', required=True,
                        help='Output Jenkinsfile path')

    # Pipeline configuration
    parser.add_argument('--name', default='Generated Pipeline',
                        help='Pipeline name (for header comment)')
    parser.add_argument('--stages', default='build,test',
                        help='Comma-separated list of stages (build,test,deploy,etc.)')

    # Agent configuration
    parser.add_argument('--agent-label', help='Node label for agent selection')

    # Build configuration
    parser.add_argument('--build-tool', default='maven',
                        choices=['maven', 'gradle', 'npm', 'python', 'go'],
                        help='Build tool (determines default commands)')
    parser.add_argument('--build-cmd', help='Custom build command')
    parser.add_argument('--test-cmd', help='Custom test command')
    parser.add_argument('--deploy-cmd', default='./deploy.sh',
                        help='Deploy command')

    # Docker configuration
    parser.add_argument('--docker-image', help='Docker image to use for build')
    parser.add_argument('--docker-args', default='',
                        help='Docker run arguments')
    parser.add_argument('--docker-image-name', default='myapp',
                        help='Docker image name for docker-build/push stages')
    parser.add_argument('--docker-registry', help='Docker registry URL')
    parser.add_argument('--docker-registry-credentials', help='Docker registry credentials ID')
    parser.add_argument('--dockerfile', default='Dockerfile',
                        help='Dockerfile name')

    # SCM configuration
    parser.add_argument('--scm-url', help='Git repository URL')
    parser.add_argument('--branch', default='main', help='Git branch')
    parser.add_argument('--scm-credentials', help='SCM credentials ID')

    # Deployment
    parser.add_argument('--deploy-env', default='production',
                        help='Deployment environment name')
    parser.add_argument('--no-deploy-approval', action='store_true',
                        help='Skip deployment approval')
    parser.add_argument('--deploy-approvers', default='admin',
                        help='Comma-separated list of deployment approvers')

    # Error handling and cleanup
    parser.add_argument('--no-error-handling', action='store_true',
                        help='Disable try-catch-finally error handling')
    parser.add_argument('--no-cleanup', action='store_true',
                        help='Disable workspace cleanup')

    # Notifications
    parser.add_argument('--notification-email', help='Email for notifications')

    # Test configuration
    parser.add_argument('--test-types', default='unit,integration',
                        help='Comma-separated test types for parallel-tests stage')

    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_args()

    # Build configuration from args
    config = {
        'name': args.name,
        'stages': args.stages.split(','),
        'agent_label': args.agent_label,
        'build_tool': args.build_tool,
        'docker_image': args.docker_image,
        'docker_args': args.docker_args,
        'docker_image_name': args.docker_image_name,
        'docker_registry': args.docker_registry,
        'docker_registry_credentials': args.docker_registry_credentials,
        'dockerfile': args.dockerfile,
        'scm_url': args.scm_url,
        'branch': args.branch,
        'scm_credentials': args.scm_credentials,
        'deploy_cmd': args.deploy_cmd,
        'deploy_env': args.deploy_env,
        'deploy_approval': not args.no_deploy_approval,
        'deploy_approvers': args.deploy_approvers,
        'error_handling': not args.no_error_handling,
        'cleanup': not args.no_cleanup,
        'notification_email': args.notification_email,
        'test_types': args.test_types.split(','),
    }

    # Add custom commands if specified
    if args.build_cmd:
        config['build_cmd'] = args.build_cmd
    if args.test_cmd:
        config['test_cmd'] = args.test_cmd

    # Determine test results pattern
    pattern = PipelinePatterns.ci_pattern(args.build_tool)
    config['test_results'] = pattern['test_results']

    # Generate pipeline
    generator = ScriptedPipelineGenerator(config)
    jenkinsfile_content = generator.generate()

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(jenkinsfile_content)

    print(f"✓ Generated Scripted Jenkinsfile: {args.output}")
    print(f"  Pipeline: {args.name}")
    print(f"  Stages: {', '.join(config['stages'])}")
    if args.agent_label:
        print(f"  Agent Label: {args.agent_label}")
    print("\n" + "="*60)
    print("NEXT STEP: Validate the generated Jenkinsfile")
    print("  Use: jenkinsfile-validator skill")
    print("="*60)

    return 0


if __name__ == '__main__':
    sys.exit(main())
