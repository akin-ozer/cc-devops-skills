#!/usr/bin/env python3
"""
Azure Pipelines Syntax Validator

This script validates Azure Pipelines YAML files for:
- Valid YAML syntax
- Azure Pipelines schema compliance
- Required fields and structure
- Task format validation
- Pool/agent specifications
- Stage/job/step hierarchy
- Resource definitions
"""

import sys
import yaml
import re
from pathlib import Path
from typing import Dict, List, Any, Tuple, Set
from collections import defaultdict


class ValidationError:
    """Represents a validation error or warning"""

    def __init__(self, severity: str, line: int, message: str, rule: str):
        self.severity = severity  # 'error', 'warning', 'info'
        self.line = line
        self.message = message
        self.rule = rule

    def __str__(self):
        return f"{self.severity.upper()}: Line {self.line}: {self.message} [{self.rule}]"


class AzurePipelinesValidator:
    """Validates Azure Pipelines configuration files"""

    # Top-level keywords in Azure Pipelines
    PIPELINE_KEYWORDS = {
        'name', 'trigger', 'pr', 'schedules', 'pool', 'variables', 'parameters',
        'resources', 'stages', 'jobs', 'steps', 'extends', 'strategy',
        'container', 'services', 'workspace', 'lockBehavior', 'appendCommitMessageToRunName'
    }

    # Job-level keywords
    JOB_KEYWORDS = {
        'job', 'deployment', 'template', 'displayName', 'dependsOn', 'condition',
        'strategy', 'continueOnError', 'pool', 'workspace', 'container', 'services',
        'timeoutInMinutes', 'cancelTimeoutInMinutes', 'variables', 'steps',
        'environment', 'uses', 'templateContext'
    }

    # Step types in Azure Pipelines
    STEP_TYPES = {
        'task', 'script', 'bash', 'pwsh', 'powershell', 'checkout', 'download',
        'downloadBuild', 'getPackage', 'publish', 'template', 'reviewApp'
    }

    # Valid trigger types
    TRIGGER_TYPES = {'batch', 'branches', 'paths', 'tags'}

    # Deployment strategies
    DEPLOYMENT_STRATEGIES = {'runOnce', 'rolling', 'canary'}

    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.errors: List[ValidationError] = []
        self.config: Dict[str, Any] = {}
        self.line_map: Dict[str, int] = {}
        self.defined_stages: Set[str] = set()
        self.defined_jobs: Set[str] = set()

    def validate(self) -> Tuple[bool, List[ValidationError]]:
        """Run all validations and return results"""

        # Step 1: Load and parse YAML
        if not self._load_yaml():
            return False, self.errors

        # Step 2: Validate structure
        self._validate_structure()

        # Step 3: Validate pool configuration
        self._validate_pool()

        # Step 4: Validate stages
        if 'stages' in self.config:
            self._validate_stages()

        # Step 5: Validate jobs
        if 'jobs' in self.config:
            self._validate_jobs(self.config.get('jobs', []))

        # Step 6: Validate steps (single-stage, single-job pipeline)
        if 'steps' in self.config:
            self._validate_steps(self.config.get('steps', []), 'pipeline')

        # Step 7: Validate variables
        if 'variables' in self.config:
            self._validate_variables(self.config['variables'])

        # Step 8: Validate resources
        if 'resources' in self.config:
            self._validate_resources()

        # Step 9: Validate triggers
        self._validate_triggers()

        # Determine if validation passed (no errors, warnings are ok)
        has_errors = any(e.severity == 'error' for e in self.errors)
        return not has_errors, self.errors

    def _load_yaml(self) -> bool:
        """Load and parse YAML file"""
        try:
            with open(self.file_path, 'r') as f:
                content = f.read()

            # Parse YAML
            self.config = yaml.safe_load(content)

            if self.config is None:
                self.errors.append(ValidationError(
                    'error', 1, 'Empty or invalid YAML file', 'yaml-empty'
                ))
                return False

            if not isinstance(self.config, dict):
                self.errors.append(ValidationError(
                    'error', 1, 'Root must be a dictionary/object', 'yaml-invalid-root'
                ))
                return False

            # Build line number map
            self._build_line_map(content)

            return True

        except yaml.YAMLError as e:
            line = getattr(e, 'problem_mark', None)
            line_num = line.line + 1 if line else 1
            self.errors.append(ValidationError(
                'error', line_num, f'YAML syntax error: {str(e)}', 'yaml-syntax'
                ))
            return False
        except FileNotFoundError:
            self.errors.append(ValidationError(
                'error', 0, f'File not found: {self.file_path}', 'file-not-found'
            ))
            return False
        except Exception as e:
            self.errors.append(ValidationError(
                'error', 0, f'Error reading file: {str(e)}', 'file-read-error'
            ))
            return False

    def _build_line_map(self, content: str):
        """Build comprehensive line number map for error reporting"""
        self.raw_lines = content.split('\n')

        for line_num, line in enumerate(self.raw_lines, 1):
            stripped = line.strip()
            if stripped and not stripped.startswith('#'):
                # Extract key from line
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

    def _validate_structure(self):
        """Validate basic pipeline structure"""

        # Check for valid pipeline structure
        has_stages = 'stages' in self.config
        has_jobs = 'jobs' in self.config
        has_steps = 'steps' in self.config
        has_extends = 'extends' in self.config

        # Azure Pipelines can have: stages, jobs, steps, or extends
        if has_extends:
            return  # Template pipeline, skip structure validation

        if not (has_stages or has_jobs or has_steps):
            self.errors.append(ValidationError(
                'error', 1,
                'Pipeline must define stages, jobs, or steps',
                'missing-pipeline-content'
            ))

        # Cannot mix certain top-level keywords
        if has_stages and has_jobs:
            self.errors.append(ValidationError(
                'error', self._get_line('jobs'),
                'Cannot define both stages and jobs at root level',
                'invalid-hierarchy'
            ))

        if has_stages and has_steps:
            self.errors.append(ValidationError(
                'error', self._get_line('steps'),
                'Cannot define both stages and steps at root level',
                'invalid-hierarchy'
            ))

        if has_jobs and has_steps:
            self.errors.append(ValidationError(
                'error', self._get_line('steps'),
                'Cannot define both jobs and steps at root level',
                'invalid-hierarchy'
            ))

    def _validate_pool(self):
        """Validate pool configuration"""
        if 'pool' not in self.config:
            return

        pool = self.config['pool']

        if isinstance(pool, str):
            # Simple pool name reference
            return

        if isinstance(pool, dict):
            # Must have either name or vmImage
            if 'name' not in pool and 'vmImage' not in pool:
                self.errors.append(ValidationError(
                    'error', self._get_line('pool'),
                    "Pool must specify 'name' or 'vmImage'",
                    'pool-invalid'
                ))
        else:
            self.errors.append(ValidationError(
                'error', self._get_line('pool'),
                'Pool must be a string or object',
                'pool-invalid-type'
            ))

    def _validate_stages(self):
        """Validate stages configuration"""
        stages = self.config.get('stages', [])

        if not isinstance(stages, list):
            self.errors.append(ValidationError(
                'error', self._get_line('stages'),
                'Stages must be a list',
                'stages-not-list'
            ))
            return

        for idx, stage in enumerate(stages):
            if isinstance(stage, dict):
                # Check if it's a template reference
                if 'template' in stage:
                    continue

                if 'stage' in stage:
                    stage_name = stage['stage']
                    self.defined_stages.add(stage_name)

                    # Stages must have jobs
                    if 'jobs' not in stage:
                        self.errors.append(ValidationError(
                            'error', self._get_line(stage_name),
                            f"Stage '{stage_name}' must define jobs",
                            'stage-missing-jobs'
                        ))
                    else:
                        self._validate_jobs(stage['jobs'], stage_name)

                    # Validate dependsOn if present
                    if 'dependsOn' in stage:
                        self._validate_dependencies(stage['dependsOn'], stage_name, 'stage')
                else:
                    self.errors.append(ValidationError(
                        'error', self._get_line('stages'),
                        f'Stage {idx} must have "stage" or "template" property',
                        'stage-missing-identifier'
                    ))

    def _validate_jobs(self, jobs: List[Any], context: str = 'pipeline'):
        """Validate jobs configuration"""
        if not isinstance(jobs, list):
            self.errors.append(ValidationError(
                'error', self._get_line('jobs'),
                'Jobs must be a list',
                'jobs-not-list'
            ))
            return

        for idx, job in enumerate(jobs):
            if not isinstance(job, dict):
                continue

            # Check if it's a template reference
            if 'template' in job:
                continue

            job_type = None
            job_name = None

            if 'job' in job:
                job_type = 'job'
                job_name = job['job']
            elif 'deployment' in job:
                job_type = 'deployment'
                job_name = job['deployment']
            else:
                self.errors.append(ValidationError(
                    'error', 0,
                    f'Job {idx} in {context} must have "job", "deployment", or "template" property',
                    'job-missing-type'
                ))
                continue

            self.defined_jobs.add(job_name)

            # Regular jobs must have steps
            if job_type == 'job':
                if 'steps' not in job and 'template' not in job:
                    self.errors.append(ValidationError(
                        'error', self._get_line(job_name),
                        f"Job '{job_name}' must define steps",
                        'job-missing-steps'
                    ))
                elif 'steps' in job:
                    self._validate_steps(job['steps'], job_name)

            # Deployment jobs must have strategy and environment
            if job_type == 'deployment':
                if 'strategy' not in job:
                    self.errors.append(ValidationError(
                        'error', self._get_line(job_name),
                        f"Deployment job '{job_name}' must define strategy",
                        'deployment-missing-strategy'
                    ))
                else:
                    self._validate_deployment_strategy(job['strategy'], job_name)

                if 'environment' not in job:
                    self.errors.append(ValidationError(
                        'warning', self._get_line(job_name),
                        f"Deployment job '{job_name}' should specify environment",
                        'deployment-missing-environment'
                    ))

            # Validate dependsOn if present
            if 'dependsOn' in job:
                self._validate_dependencies(job['dependsOn'], job_name, 'job')

    def _validate_steps(self, steps: List[Any], context: str):
        """Validate steps configuration"""
        if not isinstance(steps, list):
            self.errors.append(ValidationError(
                'error', self._get_line('steps'),
                f'Steps in {context} must be a list',
                'steps-not-list'
            ))
            return

        for idx, step in enumerate(steps):
            if not isinstance(step, dict):
                continue

            # Check if it's a template reference
            if 'template' in step:
                continue

            # Check for valid step type
            has_valid_type = any(step_type in step for step_type in self.STEP_TYPES)

            if not has_valid_type:
                self.errors.append(ValidationError(
                    'error', 0,
                    f'Step {idx} in {context} must specify a valid step type: {", ".join(self.STEP_TYPES)}',
                    'step-invalid-type'
                ))
                continue

            # Validate task format
            if 'task' in step:
                self._validate_task(step['task'], context)

    def _validate_task(self, task: str, context: str):
        """Validate task format (TaskName@version)"""
        if not isinstance(task, str):
            return

        # Azure Pipelines task format: TaskName@MajorVersion
        task_pattern = re.compile(r'^[A-Za-z0-9_\-\.]+@\d+$')

        if not task_pattern.match(task):
            line_num = self._find_line_containing(f"task: {task}") or self._find_line_containing(task)
            self.errors.append(ValidationError(
                'error', line_num,
                f"Task '{task}' in {context} must follow format 'TaskName@version'",
                'task-invalid-format'
            ))

    def _validate_deployment_strategy(self, strategy: Dict[str, Any], job_name: str):
        """Validate deployment strategy"""
        if not isinstance(strategy, dict):
            return

        # Must have exactly one strategy type
        strategy_keys = set(strategy.keys()) & self.DEPLOYMENT_STRATEGIES

        if len(strategy_keys) == 0:
            self.errors.append(ValidationError(
                'error', self._get_line(job_name),
                f"Deployment strategy must specify one of: {', '.join(self.DEPLOYMENT_STRATEGIES)}",
                'strategy-missing-type'
            ))
        elif len(strategy_keys) > 1:
            self.errors.append(ValidationError(
                'error', self._get_line(job_name),
                f"Deployment strategy cannot specify multiple types: {', '.join(strategy_keys)}",
                'strategy-multiple-types'
            ))

    def _validate_dependencies(self, depends_on: Any, name: str, dep_type: str):
        """Validate dependsOn references"""
        if isinstance(depends_on, str):
            depends_on = [depends_on]

        if not isinstance(depends_on, list):
            return

        valid_deps = self.defined_stages if dep_type == 'stage' else self.defined_jobs

        for dep in depends_on:
            if isinstance(dep, str) and dep not in valid_deps and dep != '':
                self.errors.append(ValidationError(
                    'warning', self._get_line(name),
                    f"{dep_type.capitalize()} '{name}' depends on undefined {dep_type} '{dep}'",
                    f'{dep_type}-undefined-dependency'
                ))

    def _validate_variables(self, variables: Any):
        """Validate variables configuration"""
        if isinstance(variables, dict):
            # Simple key-value variables
            for key, value in variables.items():
                self._validate_variable_name(key)
        elif isinstance(variables, list):
            # List of variable definitions
            for var in variables:
                if isinstance(var, dict):
                    if 'name' in var:
                        self._validate_variable_name(var['name'])
                    elif 'group' in var:
                        # Variable group reference
                        pass
                    elif 'template' in var:
                        # Template reference
                        pass

    def _validate_variable_name(self, name: str):
        """Validate variable naming conventions"""
        if not re.match(r'^[A-Za-z_][A-Za-z0-9_]*$', name):
            self.errors.append(ValidationError(
                'warning', self._get_line(name),
                f"Variable '{name}' should use alphanumeric characters and underscores only",
                'variable-invalid-name'
            ))

    def _validate_resources(self):
        """Validate resources configuration"""
        resources = self.config.get('resources', {})

        if not isinstance(resources, dict):
            self.errors.append(ValidationError(
                'error', self._get_line('resources'),
                'Resources must be an object',
                'resources-invalid-type'
            ))
            return

        valid_resource_types = {'pipelines', 'builds', 'repositories', 'containers', 'packages', 'webhooks'}

        for resource_type in resources.keys():
            if resource_type not in valid_resource_types:
                self.errors.append(ValidationError(
                    'warning', self._get_line(resource_type),
                    f"Unknown resource type '{resource_type}'. Valid types: {', '.join(valid_resource_types)}",
                    'resource-unknown-type'
                ))

    def _validate_triggers(self):
        """Validate trigger configurations"""
        # Validate CI trigger
        if 'trigger' in self.config:
            trigger = self.config['trigger']
            if trigger != 'none' and not isinstance(trigger, (list, dict)):
                self.errors.append(ValidationError(
                    'warning', self._get_line('trigger'),
                    "Trigger should be 'none', a list of branches, or an object",
                    'trigger-invalid-type'
                ))

        # Validate PR trigger
        if 'pr' in self.config:
            pr = self.config['pr']
            if pr != 'none' and not isinstance(pr, (list, dict)):
                self.errors.append(ValidationError(
                    'warning', self._get_line('pr'),
                    "PR trigger should be 'none', a list of branches, or an object",
                    'pr-invalid-type'
                ))


def main():
    if len(sys.argv) < 2:
        print("Usage: validate_syntax.py <azure-pipelines.yml>", file=sys.stderr)
        sys.exit(1)

    validator = AzurePipelinesValidator(sys.argv[1])
    success, errors = validator.validate()

    if errors:
        for error in errors:
            print(error)
        print()

    if success:
        print("✓ Syntax validation passed")
        sys.exit(0)
    else:
        print("✗ Syntax validation failed")
        sys.exit(1)


if __name__ == '__main__':
    main()
