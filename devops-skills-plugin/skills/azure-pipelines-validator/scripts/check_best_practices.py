#!/usr/bin/env python3
"""
Azure Pipelines Best Practices Checker

This script checks Azure Pipelines YAML files for best practices:
- displayName usage for clarity
- Task version pinning
- Pool vmImage specific versions
- Cache usage for package managers
- Timeout configuration
- Artifact expiration
- Deployment conditions
- Template usage recommendations
- Parallel execution opportunities
"""

import sys
import yaml
import re
from pathlib import Path
from typing import Dict, List, Any, Set
from collections import defaultdict


class BestPracticeIssue:
    """Represents a best practice issue"""

    def __init__(self, severity: str, line: int, message: str, rule: str, suggestion: str = ""):
        self.severity = severity  # 'warning', 'info'
        self.line = line
        self.message = message
        self.rule = rule
        self.suggestion = suggestion

    def __str__(self):
        result = f"{self.severity.upper()}: Line {self.line}: {self.message} [{self.rule}]"
        if self.suggestion:
            result += f"\n  💡 Suggestion: {self.suggestion}"
        return result


class BestPracticesChecker:
    """Checks Azure Pipelines files for best practices"""

    # Package managers that should use caching
    PACKAGE_MANAGERS = {
        'npm': {'install', 'ci'},
        'yarn': {'install'},
        'pip': {'install'},
        'dotnet': {'restore'},
        'maven': {'-B'},
        'gradle': {'build', 'test'}
    }

    # Tasks that commonly need caching
    CACHE_TASKS = {'Npm@1', 'Maven@3', 'Gradle@2', 'DotNetCoreCLI@2'}

    # Tasks where @0 is the only/current major version and is acceptable
    # These tasks have not released a @1 version yet, so @0 is correct
    ACCEPTABLE_AT_ZERO_TASKS = {
        'GoTool',           # Go version installer - only @0 available
        'NodeTool',         # Node.js version installer - only @0 available
        'UsePythonVersion', # Python version selector - only @0 available
        'KubernetesManifest', # K8s manifest deploy - only @0 available
        'DockerCompose',    # Docker Compose - only @0 available
        'HelmInstaller',    # Helm installer - only @0 available
        'HelmDeploy',       # Helm deploy - only @0 available
        'Cache',            # Pipeline caching - commonly @2 but @0 still valid
    }

    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.issues: List[BestPracticeIssue] = []
        self.config: Dict[str, Any] = {}
        self.line_map: Dict[str, int] = {}

    def check(self) -> List[BestPracticeIssue]:
        """Run all best practice checks"""

        try:
            with open(self.file_path, 'r') as f:
                content = f.read()
            self.config = yaml.safe_load(content)
            self._build_line_map(content)
        except Exception as e:
            print(f"Error loading file: {e}", file=sys.stderr)
            return []

        if not isinstance(self.config, dict):
            return []

        # Run all checks
        self._check_display_names()
        self._check_task_versions()
        self._check_pool_images()
        self._check_cache_usage()
        self._check_timeouts()
        self._check_conditions()
        self._check_parallel_opportunities()
        self._check_artifact_retention()
        self._check_template_usage()
        self._check_variable_groups()

        return self.issues

    def _build_line_map(self, content: str):
        """Build comprehensive line number map for error reporting"""
        self.raw_lines = content.split('\n')
        for line_num, line in enumerate(self.raw_lines, 1):
            stripped = line.strip()
            if stripped and not stripped.startswith('#'):
                if ':' in stripped:
                    key = stripped.split(':')[0].strip('- ')
                    if key and key not in self.line_map:
                        self.line_map[key] = line_num
                    # Also store full stripped line for value lookups
                    self.line_map[stripped] = line_num

    def _get_line(self, key: str) -> int:
        """Get approximate line number for a key or value"""
        if key in self.line_map:
            return self.line_map[key]
        # Search for the key in raw lines
        for line_num, line in enumerate(self.raw_lines, 1):
            if key in line:
                return line_num
        return 0

    def _find_line_containing(self, value: str) -> int:
        """Find line number containing a specific value"""
        for line_num, line in enumerate(self.raw_lines, 1):
            if value in line:
                return line_num
        return 0

    def _check_display_names(self):
        """Check for missing displayName properties"""

        # Check stages
        if 'stages' in self.config:
            for stage in self.config.get('stages', []):
                if isinstance(stage, dict) and 'stage' in stage:
                    stage_name = stage['stage']
                    if 'displayName' not in stage:
                        self.issues.append(BestPracticeIssue(
                            'info', self._get_line(stage_name),
                            f"Stage '{stage_name}' should have displayName for better readability",
                            'missing-displayname',
                            f"Add 'displayName: \"Your Stage Description\"' to stage '{stage_name}'"
                        ))

                    # Check jobs within stage
                    self._check_jobs_display_names(stage.get('jobs', []))

        # Check jobs at pipeline level
        if 'jobs' in self.config:
            self._check_jobs_display_names(self.config['jobs'])

    def _check_jobs_display_names(self, jobs: List[Any]):
        """Check displayName for jobs"""
        for job in jobs:
            if isinstance(job, dict):
                job_name = job.get('job') or job.get('deployment')
                if job_name and 'displayName' not in job:
                    self.issues.append(BestPracticeIssue(
                        'info', self._get_line(job_name),
                        f"Job '{job_name}' should have displayName for better readability",
                        'missing-displayname',
                        f"Add 'displayName: \"Your Job Description\"' to job '{job_name}'"
                    ))

    def _check_task_versions(self):
        """Check that tasks use specific version numbers"""

        def check_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict) and 'task' in step:
                    task = step['task']
                    if isinstance(task, str):
                        line_num = self._find_line_containing(f"task: {task}") or self._find_line_containing(task)

                        # Extract task name (without version) for whitelist check
                        task_name = task.split('@')[0] if '@' in task else task

                        # Check if using @0 or missing version
                        if '@0' in task:
                            # Skip warning if task is in the acceptable @0 whitelist
                            if task_name not in self.ACCEPTABLE_AT_ZERO_TASKS:
                                self.issues.append(BestPracticeIssue(
                                    'warning', line_num,
                                    f"Task '{task}' in {context} uses @0 which may break with updates",
                                    'task-version-zero',
                                    "Pin to a specific major version (e.g., @1, @2, @3)"
                                ))

                        # Check if version is present
                        if '@' not in task:
                            self.issues.append(BestPracticeIssue(
                                'warning', line_num,
                                f"Task '{task}' in {context} is missing version specification",
                                'task-missing-version',
                                "Add version specification (e.g., TaskName@2)"
                            ))

        # Check all steps
        self._traverse_steps(check_steps)

    def _check_pool_images(self):
        """Check pool vmImage specifications"""

        def check_pool(pool: Any, context: str):
            if isinstance(pool, dict) and 'vmImage' in pool:
                vm_image = pool['vmImage']
                if isinstance(vm_image, str):
                    # Warn about using 'latest' tags
                    if 'latest' in vm_image.lower():
                        self.issues.append(BestPracticeIssue(
                            'warning', self._get_line('vmImage'),
                            f"Pool vmImage '{vm_image}' uses 'latest' which may cause inconsistent builds",
                            'pool-latest-image',
                            "Pin to specific OS version (e.g., 'ubuntu-22.04' instead of 'ubuntu-latest')"
                        ))

        # Check root-level pool
        if 'pool' in self.config:
            check_pool(self.config['pool'], 'pipeline')

        # Check job-level pools
        def check_job_pools(jobs: List[Any]):
            for job in jobs:
                if isinstance(job, dict) and 'pool' in job:
                    job_name = job.get('job') or job.get('deployment', 'unknown')
                    check_pool(job['pool'], f"job '{job_name}'")

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    check_job_pools(stage.get('jobs', []))

        if 'jobs' in self.config:
            check_job_pools(self.config['jobs'])

    def _check_cache_usage(self):
        """Check for cache usage with package managers"""

        has_cache = False
        package_install_steps = []

        def find_cache_and_installs(steps: List[Any], context: str):
            nonlocal has_cache
            for step in steps:
                if isinstance(step, dict):
                    # Check for Cache@2 task
                    if 'task' in step and 'Cache@' in str(step['task']):
                        has_cache = True

                    # Check for package manager tasks
                    if 'task' in step:
                        task = step['task']
                        for cache_task in self.CACHE_TASKS:
                            if cache_task in str(task):
                                package_install_steps.append((context, task))

                    # Check for script-based package installations
                    for script_key in ['script', 'bash', 'pwsh', 'powershell']:
                        if script_key in step:
                            script = str(step[script_key])
                            for pkg_mgr, commands in self.PACKAGE_MANAGERS.items():
                                for cmd in commands:
                                    if pkg_mgr in script and cmd in script:
                                        package_install_steps.append((context, f"{pkg_mgr} {cmd}"))

        self._traverse_steps(find_cache_and_installs)

        # If we have package installations but no cache
        if package_install_steps and not has_cache:
            contexts = ', '.join(set(ctx for ctx, _ in package_install_steps))
            self.issues.append(BestPracticeIssue(
                'warning', 0,
                f"Pipeline installs packages but doesn't use caching in: {contexts}",
                'missing-cache',
                "Add Cache@2 task to cache dependencies and speed up builds"
            ))

    def _check_timeouts(self):
        """Check for timeout configuration on long-running jobs"""

        def check_job(job: Dict[str, Any]):
            if isinstance(job, dict):
                job_name = job.get('job') or job.get('deployment')
                if job_name and 'timeoutInMinutes' not in job:
                    # Check if it's a deployment job (usually long-running)
                    if 'deployment' in job:
                        self.issues.append(BestPracticeIssue(
                            'info', self._get_line(job_name),
                            f"Deployment job '{job_name}' should specify timeoutInMinutes",
                            'missing-timeout',
                            "Add 'timeoutInMinutes: 60' (or appropriate value) to prevent hung jobs"
                        ))

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    for job in stage.get('jobs', []):
                        check_job(job)

        if 'jobs' in self.config:
            for job in self.config['jobs']:
                check_job(job)

    def _check_conditions(self):
        """Check for proper condition usage on deployment jobs"""

        def check_job(job: Dict[str, Any], parent_stage_has_condition: bool = False):
            if isinstance(job, dict) and 'deployment' in job:
                job_name = job['deployment']
                # Only flag if NEITHER job NOR parent stage has a condition
                job_has_condition = 'condition' in job
                if not job_has_condition and not parent_stage_has_condition:
                    environment = job.get('environment', 'unknown')
                    if 'prod' in environment.lower() or 'production' in environment.lower():
                        self.issues.append(BestPracticeIssue(
                            'warning', self._get_line(job_name),
                            f"Production deployment '{job_name}' should have condition for safety",
                            'missing-deployment-condition',
                            "Add condition to control when production deployment runs (on job or stage)"
                        ))

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    # Check if the stage itself has a condition
                    stage_has_condition = 'condition' in stage
                    for job in stage.get('jobs', []):
                        check_job(job, parent_stage_has_condition=stage_has_condition)

        if 'jobs' in self.config:
            for job in self.config['jobs']:
                # Jobs at pipeline level have no parent stage
                check_job(job, parent_stage_has_condition=False)

    def _check_parallel_opportunities(self):
        """Check for opportunities to parallelize test jobs"""

        def check_job(job: Dict[str, Any]):
            if isinstance(job, dict):
                job_name = job.get('job', '')
                if 'test' in job_name.lower() and 'strategy' not in job:
                    steps = job.get('steps', [])
                    # Look for test execution steps
                    has_test_step = any(
                        isinstance(step, dict) and (
                            'test' in str(step).lower() or
                            'Test@' in str(step.get('task', ''))
                        )
                        for step in steps
                    )
                    if has_test_step:
                        self.issues.append(BestPracticeIssue(
                            'info', self._get_line(job_name),
                            f"Test job '{job_name}' could benefit from parallel execution",
                            'parallel-opportunity',
                            "Consider using 'strategy.parallel' to run tests concurrently"
                        ))

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    for job in stage.get('jobs', []):
                        check_job(job)

        if 'jobs' in self.config:
            for job in self.config['jobs']:
                check_job(job)

    def _check_artifact_retention(self):
        """Check for artifact retention policies"""

        def check_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict):
                    # Check PublishBuildArtifacts or PublishPipelineArtifact
                    if 'task' in step:
                        task = str(step['task'])
                        if 'PublishBuildArtifacts@' in task or 'PublishPipelineArtifact@' in task:
                            # Note: Artifact retention is typically set at project/org level
                            # but we can suggest documenting it
                            pass

        self._traverse_steps(check_steps)

    def _check_template_usage(self):
        """Check for opportunities to use templates"""

        # Count duplicate job patterns
        job_patterns = defaultdict(list)

        def analyze_job(job: Dict[str, Any]):
            if isinstance(job, dict) and 'template' not in job:
                # Create a simple signature of the job
                steps = job.get('steps', [])
                if len(steps) > 3:  # Only check substantial jobs
                    step_types = tuple(
                        step.get('task', step.get('script', step.get('bash', '')))[:20]
                        for step in steps if isinstance(step, dict)
                    )
                    if step_types:
                        job_name = job.get('job') or job.get('deployment', 'unknown')
                        job_patterns[step_types].append(job_name)

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    for job in stage.get('jobs', []):
                        analyze_job(job)

        if 'jobs' in self.config:
            for job in self.config['jobs']:
                analyze_job(job)

        # Report duplicate patterns
        for pattern, jobs in job_patterns.items():
            if len(jobs) > 1:
                self.issues.append(BestPracticeIssue(
                    'info', 0,
                    f"Jobs {', '.join(jobs)} have similar steps and could use a template",
                    'template-opportunity',
                    "Consider extracting common steps into a template for reusability"
                ))

    def _check_variable_groups(self):
        """Check for hardcoded variables that should use variable groups"""

        if 'variables' not in self.config:
            return

        variables = self.config['variables']

        if isinstance(variables, dict):
            # Inline variables
            if len(variables) > 10:
                self.issues.append(BestPracticeIssue(
                    'info', self._get_line('variables'),
                    f"Pipeline has {len(variables)} inline variables",
                    'many-inline-variables',
                    "Consider using variable groups for better organization and reusability"
                ))

    def _traverse_steps(self, callback):
        """Traverse all steps in the pipeline and apply callback"""

        def process_steps(steps: List[Any], context: str):
            if isinstance(steps, list):
                callback(steps, context)

        # Steps at pipeline level
        if 'steps' in self.config:
            process_steps(self.config['steps'], 'pipeline')

        # Steps in jobs
        if 'jobs' in self.config:
            for job in self.config['jobs']:
                if isinstance(job, dict):
                    job_name = job.get('job') or job.get('deployment', 'unknown')
                    if 'steps' in job:
                        process_steps(job['steps'], f"job '{job_name}'")

        # Steps in stages
        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    for job in stage.get('jobs', []):
                        if isinstance(job, dict):
                            job_name = job.get('job') or job.get('deployment', 'unknown')
                            if 'steps' in job:
                                process_steps(job['steps'], f"job '{job_name}'")


def main():
    if len(sys.argv) < 2:
        print("Usage: check_best_practices.py <azure-pipelines.yml>", file=sys.stderr)
        sys.exit(1)

    checker = BestPracticesChecker(sys.argv[1])
    issues = checker.check()

    if issues:
        # Group by severity
        warnings = [i for i in issues if i.severity == 'warning']
        infos = [i for i in issues if i.severity == 'info']

        if warnings:
            print(f"WARNINGS ({len(warnings)}):")
            print("─" * 80)
            for issue in warnings:
                print(f"  {issue}\n")

        if infos:
            print(f"SUGGESTIONS ({len(infos)}):")
            print("─" * 80)
            for issue in infos:
                print(f"  {issue}\n")

        if warnings:
            print("⚠  Best practices check found warnings")
            sys.exit(2)  # Exit code 2 for warnings (distinct from passed)
        else:
            print("ℹ  Best practices check completed with suggestions")
            sys.exit(2)  # Exit code 2 for suggestions
    else:
        print("✓ Best practices check passed")
        sys.exit(0)


if __name__ == '__main__':
    main()
