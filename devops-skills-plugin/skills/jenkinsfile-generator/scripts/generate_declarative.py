#!/usr/bin/env python3
"""
Generate Declarative Jenkins Pipeline

This script generates a Declarative Jenkinsfile with specified configuration.
"""

import argparse
import sys
import os
from pathlib import Path

# Add lib to path
sys.path.insert(0, str(Path(__file__).parent / 'lib'))

from common_patterns import PipelinePatterns, StageTemplates, PostConditions, EnvironmentTemplates
from syntax_helpers import DeclarativeSyntax, FormattingHelpers, ValidationHelpers


class DeclarativePipelineGenerator:
    """Generator for Declarative Jenkins Pipelines"""

    def __init__(self, config):
        self.config = config
        self.pipeline_parts = []

    def generate(self):
        """Generate complete declarative pipeline"""
        # Start pipeline block
        self.pipeline_parts.append("pipeline {")

        # Add agent
        self._add_agent()

        # Add environment (if specified)
        self._add_environment()

        # Add parameters (if specified)
        self._add_parameters()

        # Add options (if specified)
        self._add_options()

        # Add triggers (if specified)
        self._add_triggers()

        # Add tools (if specified)
        self._add_tools()

        # Add stages
        self._add_stages()

        # Add post conditions
        self._add_post()

        # Close pipeline block
        self.pipeline_parts.append("}")

        # Format and return
        content = '\n'.join(self.pipeline_parts)
        return FormattingHelpers.format_jenkinsfile(
            FormattingHelpers.add_header_comment(
                content,
                f"Declarative Pipeline - {self.config.get('name', 'Generated Pipeline')}"
            )
        )

    def _add_agent(self):
        """Add agent configuration"""
        agent_type = self.config.get('agent', 'any')

        if agent_type == 'docker':
            agent_block = DeclarativeSyntax.agent_block(
                'docker',
                image=self.config.get('docker_image', 'ubuntu:latest'),
                args=self.config.get('docker_args', ''),
                reuseNode=self.config.get('docker_reuse_node', False)
            )
        elif agent_type == 'dockerfile':
            agent_block = DeclarativeSyntax.agent_block(
                'dockerfile',
                filename=self.config.get('dockerfile', 'Dockerfile'),
                dir=self.config.get('dockerfile_dir', '.'),
                additionalBuildArgs=self.config.get('dockerfile_build_args', '')
            )
        elif agent_type == 'kubernetes':
            agent_block = DeclarativeSyntax.agent_block(
                'kubernetes',
                yaml=self.config.get('k8s_yaml', ''),
                inheritFrom=self.config.get('k8s_inherit_from', '')
            )
        elif agent_type == 'label':
            agent_block = DeclarativeSyntax.agent_block(
                'label',
                label=self.config.get('agent_label', 'linux')
            )
        elif agent_type == 'none':
            agent_block = DeclarativeSyntax.agent_block('none')
        else:
            agent_block = DeclarativeSyntax.agent_block('any')

        self.pipeline_parts.append(agent_block)

    def _add_environment(self):
        """Add environment variables"""
        env_vars = self.config.get('environment', {})
        credentials = self.config.get('credentials', {})

        if env_vars or credentials:
            env_block = DeclarativeSyntax.environment_block(env_vars, credentials)
            if env_block:
                self.pipeline_parts.append("")
                self.pipeline_parts.append(env_block)

    def _add_parameters(self):
        """Add parameters"""
        parameters = self.config.get('parameters', [])

        if parameters:
            param_block = DeclarativeSyntax.parameters_block(parameters)
            if param_block:
                self.pipeline_parts.append("")
                self.pipeline_parts.append(param_block)

    def _add_options(self):
        """Add options"""
        options = self.config.get('options', {})

        if options:
            options_block = DeclarativeSyntax.options_block(options)
            if options_block:
                self.pipeline_parts.append("")
                self.pipeline_parts.append(options_block)

    def _add_triggers(self):
        """Add triggers"""
        triggers = self.config.get('triggers', {})

        if triggers:
            triggers_block = DeclarativeSyntax.triggers_block(triggers)
            if triggers_block:
                self.pipeline_parts.append("")
                self.pipeline_parts.append(triggers_block)

    def _add_tools(self):
        """Add tools"""
        tools = self.config.get('tools', {})

        if tools:
            tools_block = DeclarativeSyntax.tools_block(tools)
            if tools_block:
                self.pipeline_parts.append("")
                self.pipeline_parts.append(tools_block)

    def _add_stages(self):
        """Add stages based on configuration"""
        self.pipeline_parts.append("")
        self.pipeline_parts.append("    stages {")
        first_stage = True

        # Get stage list from config or use default
        stages = self.config.get('stages', ['build', 'test'])

        # Get build tool pattern if specified
        build_tool = self.config.get('build_tool', 'maven')
        pattern = PipelinePatterns.ci_pattern(build_tool)

        # Generate stages based on type
        for stage in stages:
            if stage == 'checkout':
                self.pipeline_parts.append(StageTemplates.checkout_stage(
                    scm_url=self.config.get('scm_url'),
                    branch=self.config.get('branch', 'main'),
                    credentials=self.config.get('scm_credentials')
                ))
            elif stage == 'build':
                build_cmd = self.config.get('build_cmd', pattern['build_cmd'])
                self.pipeline_parts.append(StageTemplates.build_stage(build_cmd))
            elif stage == 'test':
                test_cmd = self.config.get('test_cmd', pattern['test_cmd'])
                test_results = self.config.get('test_results', pattern['test_results'])
                self.pipeline_parts.append(StageTemplates.test_stage(test_cmd, test_results))
            elif stage == 'deploy':
                deploy_cmd = self.config.get('deploy_cmd', './deploy.sh')
                environment = self.config.get('deploy_env', 'production')
                approval = self.config.get('deploy_approval', True)
                approvers = self.config.get('deploy_approvers', 'admin')
                self.pipeline_parts.append(StageTemplates.deploy_stage(
                    environment, deploy_cmd, approval, approvers
                ))
            elif stage == 'docker-build':
                image_name = self.config.get('docker_image_name', 'myapp')
                dockerfile = self.config.get('dockerfile', 'Dockerfile')
                self.pipeline_parts.append(StageTemplates.docker_build_stage(image_name, dockerfile))
            elif stage == 'docker-push':
                image_name = self.config.get('docker_image_name', 'myapp')
                registry = self.config.get('docker_registry')
                registry_creds = self.config.get('docker_registry_credentials')
                self.pipeline_parts.append(StageTemplates.docker_push_stage(
                    image_name, registry, registry_creds
                ))
            elif stage == 'parallel-tests':
                test_types = self.config.get('test_types', ['unit', 'integration'])
                self.pipeline_parts.append(StageTemplates.parallel_test_stage(test_types))
            else:
                # Custom stage
                custom_cmd = self.config.get(f'{stage}_cmd', f'echo "Running {stage}"')
                self.pipeline_parts.append(f"""
        stage('{stage.capitalize()}') {{
            steps {{
                sh '{custom_cmd}'
            }}
        }}""")

        self.pipeline_parts.append("    }")

    def _add_post(self):
        """Add post conditions"""
        artifacts = self.config.get('archive_artifacts')
        cleanup = self.config.get('cleanup', True)
        email = self.config.get('notification_email')
        slack = self.config.get('notification_slack')

        if email or slack:
            post_block = PostConditions.notification_post(email, slack)
        else:
            post_block = PostConditions.standard_post(artifacts, cleanup)

        if post_block:
            self.pipeline_parts.append("")
            self.pipeline_parts.append(post_block)


def parse_args():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='Generate Declarative Jenkins Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # Basic CI pipeline
  %(prog)s --output Jenkinsfile --stages build,test --build-tool maven

  # Docker-based pipeline
  %(prog)s --output Jenkinsfile --agent docker --docker-image maven:3.9.9-eclipse-temurin-21

  # Full CD pipeline with deployment
  %(prog)s --output Jenkinsfile --stages checkout,build,test,deploy --deploy-env production

  # Kubernetes agent pipeline
  %(prog)s --output Jenkinsfile --agent kubernetes --k8s-yaml pod.yaml
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
    parser.add_argument('--agent', default='any',
                        choices=['any', 'none', 'label', 'docker', 'dockerfile', 'kubernetes'],
                        help='Agent type')
    parser.add_argument('--agent-label', default='linux',
                        help='Agent label (for --agent label)')
    parser.add_argument('--docker-image', default='ubuntu:latest',
                        help='Docker image (for --agent docker)')
    parser.add_argument('--docker-args', default='',
                        help='Docker arguments (for --agent docker)')
    parser.add_argument('--dockerfile', default='Dockerfile',
                        help='Dockerfile name (for --agent dockerfile)')
    parser.add_argument('--k8s-yaml', default='',
                        help='Kubernetes YAML content or file path')

    # Build configuration
    parser.add_argument('--build-tool', default='maven',
                        choices=['maven', 'gradle', 'npm', 'python', 'go'],
                        help='Build tool (determines default commands)')
    parser.add_argument('--build-cmd', help='Custom build command')
    parser.add_argument('--test-cmd', help='Custom test command')
    parser.add_argument('--deploy-cmd', default='./deploy.sh',
                        help='Deploy command')

    # SCM configuration
    parser.add_argument('--scm-url', help='Git repository URL')
    parser.add_argument('--branch', default='main', help='Git branch')
    parser.add_argument('--scm-credentials', help='SCM credentials ID')

    # Options
    parser.add_argument('--timeout', type=int, help='Pipeline timeout in hours')
    parser.add_argument('--build-discarder', type=int, default=10,
                        help='Number of builds to keep')
    parser.add_argument('--disable-concurrent', action='store_true',
                        help='Disable concurrent builds')
    parser.add_argument('--timestamps', action='store_true',
                        help='Add timestamps to console output')
    parser.add_argument('--preserve-stashes', type=int, metavar='N',
                        help='Preserve stashes for N builds (for stage restarting)')
    parser.add_argument('--durability-hint',
                        choices=['PERFORMANCE_OPTIMIZED', 'SURVIVABLE_NONATOMIC', 'MAX_SURVIVABILITY'],
                        help='Pipeline durability hint (trade performance for durability)')
    parser.add_argument('--quiet-period', type=int,
                        help='Override global quiet period in seconds')
    parser.add_argument('--skip-stages-after-unstable', action='store_true',
                        help='Skip remaining stages if build becomes unstable')
    parser.add_argument('--disable-resume', action='store_true',
                        help='Do not allow pipeline to resume if controller restarts')
    parser.add_argument('--parallels-fail-fast', action='store_true',
                        help='Abort all parallel stages when one fails')

    # Deployment
    parser.add_argument('--deploy-env', default='production',
                        help='Deployment environment name')
    parser.add_argument('--no-deploy-approval', action='store_true',
                        help='Skip deployment approval')
    parser.add_argument('--deploy-approvers', default='admin',
                        help='Comma-separated list of deployment approvers')

    # Notifications
    parser.add_argument('--notification-email', help='Email for notifications')
    parser.add_argument('--notification-slack', help='Slack channel for notifications')

    # Docker
    parser.add_argument('--docker-image-name', default='myapp',
                        help='Docker image name for docker-build/push stages')
    parser.add_argument('--docker-registry', help='Docker registry URL')
    parser.add_argument('--docker-registry-credentials', help='Docker registry credentials ID')

    # Post-build
    parser.add_argument('--archive-artifacts', help='Artifacts pattern to archive')
    parser.add_argument('--no-cleanup', action='store_true',
                        help='Disable workspace cleanup')

    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_args()

    # Build configuration from args
    config = {
        'name': args.name,
        'stages': args.stages.split(','),
        'agent': args.agent,
        'agent_label': args.agent_label,
        'docker_image': args.docker_image,
        'docker_args': args.docker_args,
        'dockerfile': args.dockerfile,
        'k8s_yaml': args.k8s_yaml,
        'build_tool': args.build_tool,
        'scm_url': args.scm_url,
        'branch': args.branch,
        'scm_credentials': args.scm_credentials,
        'deploy_cmd': args.deploy_cmd,
        'deploy_env': args.deploy_env,
        'deploy_approval': not args.no_deploy_approval,
        'deploy_approvers': args.deploy_approvers,
        'notification_email': args.notification_email,
        'notification_slack': args.notification_slack,
        'docker_image_name': args.docker_image_name,
        'docker_registry': args.docker_registry,
        'docker_registry_credentials': args.docker_registry_credentials,
        'archive_artifacts': args.archive_artifacts,
        'cleanup': not args.no_cleanup,
    }

    # Add custom commands if specified
    if args.build_cmd:
        config['build_cmd'] = args.build_cmd
    if args.test_cmd:
        config['test_cmd'] = args.test_cmd

    # Add options
    options = {}
    if args.timeout:
        options['timeout'] = {'time': args.timeout, 'unit': 'HOURS'}
    if args.build_discarder:
        options['buildDiscarder'] = {'numToKeepStr': str(args.build_discarder)}
    if args.disable_concurrent:
        options['disableConcurrentBuilds'] = True
    if args.timestamps:
        options['timestamps'] = True
    if args.preserve_stashes:
        options['preserveStashes'] = {'buildCount': args.preserve_stashes}
    if args.durability_hint:
        options['durabilityHint'] = args.durability_hint
    if args.quiet_period:
        options['quietPeriod'] = args.quiet_period
    if args.skip_stages_after_unstable:
        options['skipStagesAfterUnstable'] = True
    if args.disable_resume:
        options['disableResume'] = True
    if args.parallels_fail_fast:
        options['parallelsAlwaysFailFast'] = True
    if options:
        config['options'] = options

    # Generate pipeline
    generator = DeclarativePipelineGenerator(config)
    jenkinsfile_content = generator.generate()

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(jenkinsfile_content)

    print(f"✓ Generated Declarative Jenkinsfile: {args.output}")
    print(f"  Pipeline: {args.name}")
    print(f"  Stages: {', '.join(config['stages'])}")
    print(f"  Agent: {args.agent}")
    print("\n" + "="*60)
    print("NEXT STEP: Validate using jenkinsfile-validator skill")
    print("="*60)

    return 0


if __name__ == '__main__':
    sys.exit(main())
