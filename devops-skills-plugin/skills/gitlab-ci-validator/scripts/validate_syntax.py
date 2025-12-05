#!/usr/bin/env python3
"""
GitLab CI/CD Syntax Validator

This script validates GitLab CI/CD YAML files for:
- Valid YAML syntax
- GitLab CI schema compliance
- Required fields and structure
- Job naming conventions
- Stage references
- Dependency references
"""

import sys
import yaml
import re
import json
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

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON output"""
        return {
            'severity': self.severity,
            'line': self.line,
            'message': self.message,
            'rule': self.rule
        }


class GitLabCIValidator:
    """Validates GitLab CI/CD configuration files"""

    # Reserved keywords that cannot be used as job names
    RESERVED_KEYWORDS = {
        'image', 'services', 'stages', 'types', 'before_script',
        'after_script', 'variables', 'cache', 'include', 'pages',
        'default', 'workflow', 'spec'
    }

    # Global keywords that can appear at the top level
    GLOBAL_KEYWORDS = {
        'default', 'include', 'stages', 'variables', 'workflow',
        'spec', 'pages'
    }

    # Valid job keywords
    JOB_KEYWORDS = {
        'script', 'image', 'services', 'before_script', 'after_script',
        'stage', 'only', 'except', 'rules', 'tags', 'allow_failure',
        'when', 'dependencies', 'needs', 'artifacts', 'cache',
        'environment', 'coverage', 'retry', 'timeout', 'parallel',
        'trigger', 'include', 'extends', 'variables', 'interruptible',
        'resource_group', 'release', 'secrets', 'identity',
        'manual_confirmation', 'inherit', 'pages', 'dast_configuration',
        'run', 'hooks', 'id_tokens'
    }

    # Valid when values
    VALID_WHEN_VALUES = {
        'on_success', 'on_failure', 'always', 'manual', 'delayed', 'never'
    }

    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.errors: List[ValidationError] = []
        self.config: Dict[str, Any] = {}
        self.line_map: Dict[Any, int] = {}

    def validate(self) -> Tuple[bool, List[ValidationError]]:
        """Run all validations and return results"""

        # Step 1: Load and parse YAML
        if not self._load_yaml():
            return False, self.errors

        # Step 2: Validate structure
        self._validate_structure()

        # Step 3: Validate stages
        self._validate_stages()

        # Step 4: Validate jobs
        self._validate_jobs()

        # Step 5: Validate dependencies
        self._validate_dependencies()

        # Step 6: Validate rules and conditions
        self._validate_rules()

        # Step 7: Validate GitLab CI limits
        self._validate_gitlab_limits()

        # Step 8: Validate extends relationships
        self._validate_extends_relationships()

        # Step 9: Validate include configurations
        self._validate_includes()

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

            # Build line number map (approximate - YAML doesn't provide exact line numbers)
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
        """Build enhanced line number map for error reporting"""
        lines = content.split('\n')
        current_line = 1

        for line in lines:
            # Extract key from line if it looks like a YAML key (with any indentation)
            match = re.match(r'^(\s*)([a-zA-Z0-9_-]+):', line)
            if match:
                indent_level = len(match.group(1))
                key = match.group(2)

                # Store both the base key and indented versions for better lookups
                self.line_map[key] = current_line

                # Also store with indent prefix for nested keys
                indent_key = f"{indent_level}:{key}"
                self.line_map[indent_key] = current_line

            current_line += 1

    def _get_line(self, key: str) -> int:
        """Get approximate line number for a key"""
        return self.line_map.get(key, 0)

    def _find_line_for_text(self, text: str) -> int:
        """Find line number for specific text in file"""
        if not hasattr(self, '_file_content'):
            try:
                with open(self.file_path, 'r') as f:
                    self._file_content = f.read().split('\n')
            except:
                return 0

        for i, line in enumerate(self._file_content, 1):
            if text in line:
                return i
        return 0

    def _validate_structure(self):
        """Validate overall structure"""

        # Check for common typos in global keywords
        common_typos = {
            'stage': 'stages',
            'include_': 'include',
            'variable': 'variables'
        }

        for typo, correct in common_typos.items():
            if typo in self.config and correct not in self.config:
                self.errors.append(ValidationError(
                    'warning',
                    self._get_line(typo),
                    f"Did you mean '{correct}' instead of '{typo}'?",
                    'structure-typo'
                ))

    def _validate_stages(self):
        """Validate stages configuration"""

        if 'stages' in self.config:
            stages = self.config['stages']

            if not isinstance(stages, list):
                self.errors.append(ValidationError(
                    'error',
                    self._get_line('stages'),
                    "'stages' must be a list",
                    'stages-not-list'
                ))
                return

            if not stages:
                self.errors.append(ValidationError(
                    'warning',
                    self._get_line('stages'),
                    "Empty 'stages' list - using default stages",
                    'stages-empty'
                ))

            # Check for duplicate stages
            seen = set()
            for stage in stages:
                if not isinstance(stage, str):
                    self.errors.append(ValidationError(
                        'error',
                        self._get_line('stages'),
                        f"Stage name must be a string, got {type(stage).__name__}",
                        'stage-invalid-type'
                    ))
                    continue

                if stage in seen:
                    self.errors.append(ValidationError(
                        'warning',
                        self._get_line('stages'),
                        f"Duplicate stage '{stage}'",
                        'stage-duplicate'
                    ))
                seen.add(stage)

    def _validate_jobs(self):
        """Validate all jobs"""

        defined_stages = set(self.config.get('stages', []))
        default_stages = {'.pre', 'build', 'test', 'deploy', '.post'}
        valid_stages = defined_stages or default_stages

        for key, value in self.config.items():
            # Skip global keywords and hidden jobs
            if key in self.GLOBAL_KEYWORDS or key.startswith('.'):
                continue

            # This should be a job
            if not isinstance(value, dict):
                self.errors.append(ValidationError(
                    'error',
                    self._get_line(key),
                    f"Job '{key}' must be a dictionary",
                    'job-not-dict'
                ))
                continue

            self._validate_job(key, value, valid_stages)

    def _validate_job(self, job_name: str, job: Dict[str, Any], valid_stages: Set[str]):
        """Validate a single job"""

        line = self._get_line(job_name)

        # Check for reserved keywords used as job names
        if job_name in self.RESERVED_KEYWORDS:
            self.errors.append(ValidationError(
                'error',
                line,
                f"'{job_name}' is a reserved keyword and cannot be used as a job name",
                'job-reserved-keyword'
            ))

        # Check job name format
        if not re.match(r'^[a-zA-Z0-9:_. -]+$', job_name):
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Job name '{job_name}' contains unusual characters",
                'job-name-format'
            ))

        # Check for 'script' keyword (required unless it's a trigger/include job)
        has_script = 'script' in job
        has_trigger = 'trigger' in job
        has_extends = 'extends' in job

        if not has_script and not has_trigger and not has_extends:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}' must have 'script', 'trigger', or 'extends' keyword",
                'job-missing-script'
            ))

        # Validate 'stage' reference
        if 'stage' in job:
            stage = job['stage']
            if not isinstance(stage, str):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': 'stage' must be a string",
                    'job-stage-invalid-type'
                ))
            elif stage not in valid_stages:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': references undefined stage '{stage}'",
                    'job-stage-undefined'
                ))

        # Validate 'when' keyword
        if 'when' in job:
            when = job['when']
            if when not in self.VALID_WHEN_VALUES:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': invalid 'when' value '{when}'. "
                    f"Must be one of: {', '.join(sorted(self.VALID_WHEN_VALUES))}",
                    'job-when-invalid'
                ))

        # Check for mixing 'rules' with 'only'/'except'
        has_rules = 'rules' in job
        has_only = 'only' in job
        has_except = 'except' in job

        if has_rules and (has_only or has_except):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': cannot use 'rules' with 'only'/'except'",
                'job-rules-conflict'
            ))

        # Warn about deprecated only/except
        if has_only or has_except:
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Job '{job_name}': 'only'/'except' are deprecated, use 'rules' instead",
                'job-deprecated-only-except'
            ))

        # Validate unknown keywords
        for keyword in job.keys():
            if keyword not in self.JOB_KEYWORDS:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Job '{job_name}': unknown keyword '{keyword}'",
                    'job-unknown-keyword'
                ))

        # Validate script format
        if 'script' in job:
            script = job['script']
            if not isinstance(script, (str, list)):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': 'script' must be a string or list",
                    'job-script-invalid-type'
                ))
            elif isinstance(script, list):
                for i, cmd in enumerate(script):
                    if not isinstance(cmd, str):
                        self.errors.append(ValidationError(
                            'error',
                            line,
                            f"Job '{job_name}': script command #{i+1} must be a string",
                            'job-script-item-invalid'
                        ))

        # Validate artifacts
        if 'artifacts' in job:
            self._validate_artifacts(job_name, job['artifacts'], line)

        # Validate cache
        if 'cache' in job:
            self._validate_cache(job_name, job['cache'], line)

        # Validate parallel
        if 'parallel' in job:
            self._validate_parallel(job_name, job['parallel'], line)

        # Validate hooks
        if 'hooks' in job:
            self._validate_hooks(job_name, job['hooks'], line)

        # Validate manual_confirmation
        if 'manual_confirmation' in job:
            self._validate_manual_confirmation(job_name, job['manual_confirmation'], line)

    def _validate_artifacts(self, job_name: str, artifacts: Any, line: int):
        """Validate artifacts configuration"""

        if not isinstance(artifacts, dict):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': 'artifacts' must be a dictionary",
                'artifacts-not-dict'
            ))
            return

        valid_artifact_keywords = {
            'paths', 'exclude', 'expire_in', 'expose_as', 'name',
            'untracked', 'when', 'reports', 'public'
        }

        for keyword in artifacts.keys():
            if keyword not in valid_artifact_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Job '{job_name}': unknown artifacts keyword '{keyword}'",
                    'artifacts-unknown-keyword'
                ))

        # Check for 'paths' (commonly required)
        if 'paths' not in artifacts and 'reports' not in artifacts:
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Job '{job_name}': artifacts should have 'paths' or 'reports'",
                'artifacts-no-paths'
            ))

    def _validate_cache(self, job_name: str, cache: Any, line: int):
        """Validate cache configuration"""

        if not isinstance(cache, (dict, list)):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': 'cache' must be a dictionary or list",
                'cache-invalid-type'
            ))
            return

        caches = [cache] if isinstance(cache, dict) else cache

        for cache_item in caches:
            if not isinstance(cache_item, dict):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': cache item must be a dictionary",
                    'cache-item-not-dict'
                ))
                continue

            valid_cache_keywords = {
                'paths', 'key', 'untracked', 'policy', 'when'
            }

            for keyword in cache_item.keys():
                if keyword not in valid_cache_keywords:
                    self.errors.append(ValidationError(
                        'warning',
                        line,
                        f"Job '{job_name}': unknown cache keyword '{keyword}'",
                        'cache-unknown-keyword'
                    ))

            # Validate policy
            if 'policy' in cache_item:
                policy = cache_item['policy']
                valid_policies = {'pull', 'push', 'pull-push'}
                if policy not in valid_policies:
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}': invalid cache policy '{policy}'. "
                        f"Must be one of: {', '.join(sorted(valid_policies))}",
                        'cache-invalid-policy'
                    ))

    def _validate_parallel(self, job_name: str, parallel: Any, line: int):
        """Validate parallel configuration"""

        # parallel can be an integer or a dict with matrix
        if isinstance(parallel, int):
            if parallel < 2 or parallel > 200:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Job '{job_name}': parallel value {parallel} should be between 2 and 200",
                    'parallel-invalid-range'
                ))
        elif isinstance(parallel, dict):
            if 'matrix' in parallel:
                matrix = parallel['matrix']
                if not isinstance(matrix, list):
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}': parallel:matrix must be a list",
                        'parallel-matrix-not-list'
                    ))
                else:
                    # Validate matrix items
                    for i, matrix_item in enumerate(matrix):
                        if not isinstance(matrix_item, dict):
                            self.errors.append(ValidationError(
                                'error',
                                line,
                                f"Job '{job_name}': parallel:matrix item #{i+1} must be a dictionary",
                                'parallel-matrix-item-invalid'
                            ))
                            continue

                        # Each matrix item should have at least one variable with a list of values
                        for var_name, var_values in matrix_item.items():
                            if not isinstance(var_values, list):
                                self.errors.append(ValidationError(
                                    'error',
                                    line,
                                    f"Job '{job_name}': parallel:matrix variable '{var_name}' must have a list of values",
                                    'parallel-matrix-var-not-list'
                                ))
                            elif not var_values:
                                self.errors.append(ValidationError(
                                    'warning',
                                    line,
                                    f"Job '{job_name}': parallel:matrix variable '{var_name}' has empty values list",
                                    'parallel-matrix-var-empty'
                                ))
            else:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': parallel must be an integer or have 'matrix' key",
                    'parallel-invalid-type'
                ))
        else:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': parallel must be an integer or dictionary",
                'parallel-invalid-type'
            ))

    def _validate_hooks(self, job_name: str, hooks: Any, line: int):
        """Validate hooks configuration"""

        if not isinstance(hooks, dict):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': 'hooks' must be a dictionary",
                'hooks-not-dict'
            ))
            return

        valid_hook_keywords = {'pre_get_sources_script'}

        for keyword in hooks.keys():
            if keyword not in valid_hook_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Job '{job_name}': unknown hooks keyword '{keyword}'",
                    'hooks-unknown-keyword'
                ))

        # Validate pre_get_sources_script
        if 'pre_get_sources_script' in hooks:
            script = hooks['pre_get_sources_script']
            if not isinstance(script, (str, list)):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': hooks:pre_get_sources_script must be a string or list",
                    'hooks-script-invalid-type'
                ))
            elif isinstance(script, list):
                for i, cmd in enumerate(script):
                    if not isinstance(cmd, str):
                        self.errors.append(ValidationError(
                            'error',
                            line,
                            f"Job '{job_name}': hooks:pre_get_sources_script command #{i+1} must be a string",
                            'hooks-script-item-invalid'
                        ))

    def _validate_manual_confirmation(self, job_name: str, manual_confirmation: Any, line: int):
        """Validate manual_confirmation configuration"""

        if not isinstance(manual_confirmation, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Job '{job_name}': 'manual_confirmation' must be a string",
                'manual-confirmation-invalid-type'
            ))
            return

        # Check if job has when: manual (required for manual_confirmation)
        job = self.config.get(job_name, {})
        if job.get('when') != 'manual':
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Job '{job_name}': 'manual_confirmation' requires 'when: manual'",
                'manual-confirmation-no-manual-when'
            ))

    def _validate_dependencies(self):
        """Validate job dependencies"""

        # Collect all job names
        all_jobs = {
            key for key in self.config.keys()
            if key not in self.GLOBAL_KEYWORDS and isinstance(self.config[key], dict)
        }

        for job_name, job in self.config.items():
            if job_name in self.GLOBAL_KEYWORDS or not isinstance(job, dict):
                continue

            line = self._get_line(job_name)

            # Validate 'dependencies'
            if 'dependencies' in job:
                deps = job['dependencies']
                if not isinstance(deps, list):
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}': 'dependencies' must be a list",
                        'dependencies-not-list'
                    ))
                else:
                    for dep in deps:
                        if dep not in all_jobs:
                            self.errors.append(ValidationError(
                                'error',
                                line,
                                f"Job '{job_name}': references undefined job '{dep}' in dependencies",
                                'dependencies-undefined-job'
                            ))

            # Validate 'needs'
            if 'needs' in job:
                needs = job['needs']
                if isinstance(needs, list):
                    for need in needs:
                        if isinstance(need, str):
                            if need not in all_jobs:
                                self.errors.append(ValidationError(
                                    'error',
                                    line,
                                    f"Job '{job_name}': references undefined job '{need}' in needs",
                                    'needs-undefined-job'
                                ))
                        elif isinstance(need, dict):
                            if 'job' in need and need['job'] not in all_jobs:
                                self.errors.append(ValidationError(
                                    'error',
                                    line,
                                    f"Job '{job_name}': references undefined job '{need['job']}' in needs",
                                    'needs-undefined-job'
                                ))
                elif not isinstance(needs, dict):
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}': 'needs' must be a list or dictionary",
                        'needs-invalid-type'
                    ))

            # Validate 'extends'
            if 'extends' in job:
                extends = job['extends']
                extends_list = [extends] if isinstance(extends, str) else extends

                if isinstance(extends_list, list):
                    for ext in extends_list:
                        # Hidden jobs (templates) should start with '.'
                        if not ext.startswith('.') and ext not in all_jobs:
                            self.errors.append(ValidationError(
                                'warning',
                                line,
                                f"Job '{job_name}': extends '{ext}' which is not defined. "
                                "Template jobs should start with '.'",
                                'extends-undefined'
                            ))

        # Check for circular dependencies in 'needs'
        self._check_circular_dependencies(all_jobs)

    def _check_circular_dependencies(self, all_jobs: Set[str]):
        """Check for circular dependencies in 'needs'"""

        def get_job_needs(job_name: str) -> Set[str]:
            """Get the set of jobs that this job needs"""
            job = self.config.get(job_name, {})
            needs = job.get('needs', [])

            if isinstance(needs, dict):
                return set()

            if not isinstance(needs, list):
                return set()

            result = set()
            for need in needs:
                if isinstance(need, str):
                    result.add(need)
                elif isinstance(need, dict) and 'job' in need:
                    result.add(need['job'])

            return result

        def has_cycle(job_name: str, visited: Set[str], path: Set[str]) -> List[str]:
            """Check for cycles using DFS. Returns cycle path if found."""
            if job_name in path:
                # Found a cycle
                return [job_name]

            if job_name in visited:
                return []

            visited.add(job_name)
            path.add(job_name)

            for needed_job in get_job_needs(job_name):
                if needed_job not in all_jobs:
                    continue  # Skip undefined jobs (already reported)

                cycle = has_cycle(needed_job, visited, path)
                if cycle:
                    cycle.append(job_name)
                    return cycle

            path.remove(job_name)
            return []

        visited = set()
        for job_name in all_jobs:
            if job_name not in visited:
                cycle = has_cycle(job_name, visited, set())
                if cycle:
                    # Reverse to get correct order
                    cycle.reverse()
                    cycle_str = ' -> '.join(cycle)
                    self.errors.append(ValidationError(
                        'error',
                        self._get_line(cycle[0]),
                        f"Circular dependency detected: {cycle_str}",
                        'circular-dependency'
                    ))
                    break  # Only report first cycle found

    def _validate_rules(self):
        """Validate rules and conditions"""

        for job_name, job in self.config.items():
            if job_name in self.GLOBAL_KEYWORDS or not isinstance(job, dict):
                continue

            if 'rules' not in job:
                continue

            line = self._get_line(job_name)
            rules = job['rules']

            if not isinstance(rules, list):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}': 'rules' must be a list",
                    'rules-not-list'
                ))
                continue

            for i, rule in enumerate(rules):
                if not isinstance(rule, dict):
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}': rule #{i+1} must be a dictionary",
                        'rule-not-dict'
                    ))
                    continue

                valid_rule_keywords = {
                    'if', 'changes', 'exists', 'when', 'allow_failure',
                    'variables', 'needs'
                }

                for keyword in rule.keys():
                    if keyword not in valid_rule_keywords:
                        self.errors.append(ValidationError(
                            'warning',
                            line,
                            f"Job '{job_name}': unknown rule keyword '{keyword}'",
                            'rule-unknown-keyword'
                        ))

                # Validate 'when' in rules
                if 'when' in rule:
                    when = rule['when']
                    if when not in self.VALID_WHEN_VALUES:
                        self.errors.append(ValidationError(
                            'error',
                            line,
                            f"Job '{job_name}': invalid 'when' value in rule: '{when}'",
                            'rule-when-invalid'
                        ))

    def _validate_gitlab_limits(self):
        """Validate GitLab CI/CD limits and constraints"""

        # GitLab CI/CD limits (as of GitLab 15.x+)
        MAX_JOBS = 500  # Maximum number of jobs per pipeline
        MAX_JOB_NAME_LENGTH = 255  # Maximum job name length
        MAX_NEEDS = 50  # Maximum needs dependencies per job

        # Count all jobs (excluding global keywords and hidden templates)
        all_jobs = {
            key: value for key, value in self.config.items()
            if key not in self.GLOBAL_KEYWORDS and isinstance(value, dict)
        }

        job_count = len(all_jobs)

        # Check total job count
        if job_count > MAX_JOBS:
            self.errors.append(ValidationError(
                'error',
                1,
                f"Total job count ({job_count}) exceeds GitLab limit of {MAX_JOBS} jobs per pipeline",
                'gitlab-limit-max-jobs'
            ))
        elif job_count > MAX_JOBS * 0.8:  # Warn at 80%
            self.errors.append(ValidationError(
                'warning',
                1,
                f"Total job count ({job_count}) is approaching GitLab limit of {MAX_JOBS} jobs (>80%)",
                'gitlab-limit-max-jobs-warning'
            ))

        # Check individual job constraints
        for job_name, job in all_jobs.items():
            line = self._get_line(job_name)

            # Check job name length
            if len(job_name) > MAX_JOB_NAME_LENGTH:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job name '{job_name}' exceeds maximum length of {MAX_JOB_NAME_LENGTH} characters (current: {len(job_name)})",
                    'gitlab-limit-job-name-length'
                ))

            # Check needs dependencies count
            if 'needs' in job:
                needs = job['needs']
                needs_count = 0

                if isinstance(needs, list):
                    needs_count = len(needs)
                elif isinstance(needs, dict):
                    # When needs is a dict, it can contain multiple jobs
                    if 'job' in needs:
                        needs_count = 1
                    elif 'pipeline' in needs or 'project' in needs:
                        needs_count = 1

                if needs_count > MAX_NEEDS:
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Job '{job_name}' has {needs_count} needs dependencies, exceeding GitLab limit of {MAX_NEEDS}",
                        'gitlab-limit-max-needs'
                    ))

    def _validate_extends_relationships(self):
        """Validate extends relationships for circular references and depth"""

        MAX_EXTENDS_DEPTH = 11  # GitLab limit for extends chain depth

        # Collect all jobs and templates
        all_jobs = {
            key: value for key, value in self.config.items()
            if isinstance(value, dict)
        }

        def get_extends_list(job_name: str) -> List[str]:
            """Get the list of templates/jobs this job extends"""
            job = self.config.get(job_name, {})
            extends = job.get('extends', [])

            if isinstance(extends, str):
                return [extends]
            elif isinstance(extends, list):
                return extends
            return []

        def check_circular_extends(job_name: str, visited: Set[str], path: Set[str]) -> List[str]:
            """Check for circular extends using DFS. Returns cycle path if found."""
            if job_name in path:
                # Found a cycle
                return [job_name]

            if job_name in visited:
                return []

            visited.add(job_name)
            path.add(job_name)

            for extended_job in get_extends_list(job_name):
                if extended_job not in all_jobs:
                    continue  # Skip undefined templates (already reported)

                cycle = check_circular_extends(extended_job, visited, path)
                if cycle:
                    cycle.append(job_name)
                    return cycle

            path.remove(job_name)
            return []

        def get_extends_depth(job_name: str, visited: Set[str] = None) -> int:
            """Calculate the extends chain depth for a job"""
            if visited is None:
                visited = set()

            if job_name in visited:
                # Circular reference (already reported)
                return 0

            visited.add(job_name)

            extends_list = get_extends_list(job_name)
            if not extends_list:
                return 0

            max_depth = 0
            for extended_job in extends_list:
                if extended_job in all_jobs:
                    depth = get_extends_depth(extended_job, visited.copy())
                    max_depth = max(max_depth, depth)

            return max_depth + 1

        # Check for circular extends
        visited = set()
        for job_name in all_jobs.keys():
            if job_name not in visited:
                cycle = check_circular_extends(job_name, visited, set())
                if cycle:
                    # Reverse to get correct order
                    cycle.reverse()
                    cycle_str = ' -> '.join(cycle)
                    line = self._get_line(cycle[0])
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Circular extends detected: {cycle_str}",
                        'circular-extends'
                    ))
                    break  # Only report first cycle found

        # Check extends depth
        for job_name in all_jobs.keys():
            # Skip hidden templates (they're meant to be extended)
            if job_name.startswith('.'):
                continue

            depth = get_extends_depth(job_name)
            if depth > MAX_EXTENDS_DEPTH:
                line = self._get_line(job_name)
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Job '{job_name}' has extends chain depth of {depth}, exceeding GitLab limit of {MAX_EXTENDS_DEPTH}",
                    'gitlab-limit-extends-depth'
                ))
            elif depth > MAX_EXTENDS_DEPTH * 0.8:  # Warn at 80%
                line = self._get_line(job_name)
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Job '{job_name}' has extends chain depth of {depth}, approaching GitLab limit of {MAX_EXTENDS_DEPTH} (>80%)",
                    'gitlab-limit-extends-depth-warning'
                ))

    def _validate_includes(self):
        """Validate include configurations including components, project, local, remote, and template"""

        if 'include' not in self.config:
            return

        includes = self.config['include']
        line = self._get_line('include')

        # Normalize to list
        if not isinstance(includes, list):
            includes = [includes]

        # GitLab 18.5+ limit: max 100 components per project
        MAX_COMPONENTS_PER_PROJECT = 100
        component_count = 0

        for i, inc in enumerate(includes):
            if inc is None:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{i+1} is null",
                    'include-null-item'
                ))
                continue

            # Include can be a string (shorthand for local file) or dict
            if isinstance(inc, str):
                # Shorthand for local file
                self._validate_local_include(inc, line, i+1)
                continue

            if not isinstance(inc, dict):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{i+1} must be a string or dictionary, got {type(inc).__name__}",
                    'include-invalid-type'
                ))
                continue

            # Determine include type
            include_types = []
            if 'component' in inc:
                include_types.append('component')
            if 'local' in inc:
                include_types.append('local')
            if 'remote' in inc:
                include_types.append('remote')
            if 'template' in inc:
                include_types.append('template')
            if 'project' in inc:
                include_types.append('project')
            if 'file' in inc and 'project' not in inc:
                # 'file' alone is invalid, must be with 'project'
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{i+1}: 'file' must be used with 'project'",
                    'include-file-without-project'
                ))

            # Check that exactly one include type is specified
            if len(include_types) == 0:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{i+1}: must specify one of: component, local, remote, template, or project",
                    'include-no-type'
                ))
                continue
            elif len(include_types) > 1:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{i+1}: cannot specify multiple include types: {', '.join(include_types)}",
                    'include-multiple-types'
                ))
                continue

            # Validate based on type
            include_type = include_types[0]

            if include_type == 'component':
                component_count += 1
                self._validate_component_include(inc, line, i+1)
            elif include_type == 'local':
                self._validate_local_include(inc['local'], line, i+1)
            elif include_type == 'remote':
                self._validate_remote_include(inc, line, i+1)
            elif include_type == 'template':
                self._validate_template_include(inc, line, i+1)
            elif include_type == 'project':
                self._validate_project_include(inc, line, i+1)

        # Check component count limit
        if component_count > MAX_COMPONENTS_PER_PROJECT:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Total component count ({component_count}) exceeds GitLab limit of {MAX_COMPONENTS_PER_PROJECT} components per project",
                'include-component-limit-exceeded'
            ))
        elif component_count > MAX_COMPONENTS_PER_PROJECT * 0.8:  # Warn at 80%
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Total component count ({component_count}) is approaching GitLab limit of {MAX_COMPONENTS_PER_PROJECT} components (>80%)",
                'include-component-limit-warning'
            ))

    def _validate_component_include(self, inc: Dict[str, Any], line: int, item_num: int):
        """Validate include:component syntax (GitLab 16.x+)"""

        component = inc.get('component')

        if not isinstance(component, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'component' must be a string",
                'include-component-invalid-type'
            ))
            return

        # Component format: <fqdn>/<path>@<version>
        # Examples:
        # - $CI_SERVER_FQDN/components/docker/build-and-push@1.0.0
        # - gitlab.com/components/docker/build@~latest
        # - $CI_SERVER_FQDN/org/project/subproject@2.1.0

        # Check for @ separator (version is required)
        if '@' not in component:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: component '{component}' must specify a version with '@version'",
                'include-component-no-version'
            ))
            return

        # Split into path and version
        component_parts = component.rsplit('@', 1)
        if len(component_parts) != 2:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: invalid component format '{component}'. Expected: <fqdn>/<path>@<version>",
                'include-component-invalid-format'
            ))
            return

        component_path, version = component_parts

        # Validate component path format
        # Should have at least: <fqdn>/<org>/<project>
        # Can be variable like $CI_SERVER_FQDN or literal domain
        if component_path.startswith('$'):
            # Variable reference - check it's a valid variable name
            var_match = re.match(r'^\$\{?[A-Z_][A-Z0-9_]*\}?', component_path)
            if not var_match:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: invalid variable in component path '{component_path}'",
                    'include-component-invalid-variable'
                ))
                return
            # Extract the rest after variable
            remaining_path = component_path[var_match.end():]
            if not remaining_path.startswith('/'):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: component path must have '/' after variable: '{component_path}'",
                    'include-component-missing-slash'
                ))
        else:
            # Literal domain/path
            # Should match: domain.com/org/project or similar
            if '/' not in component_path:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: component path must include organization and project: '{component_path}'",
                    'include-component-incomplete-path'
                ))

        # Validate version format
        # Can be: 1.0.0, ~latest, ~1.0, 1, etc.
        if version == '~latest':
            # Valid: ~latest for absolute latest version
            pass
        elif version.startswith('~'):
            # Partial semantic version like ~1.0 (matches latest 1.0.x)
            version_pattern = version[1:]  # Remove ~
            # Should be numeric with optional dots
            if not re.match(r'^\d+(\.\d+)*$', version_pattern):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: invalid version pattern '{version}'. Expected: ~latest, ~1.0, or semantic version",
                    'include-component-invalid-version-pattern'
                ))
        else:
            # Semantic version: 1.0.0, 1.0, or 1
            if not re.match(r'^\d+(\.\d+){0,2}$', version):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: invalid semantic version '{version}'. Expected: X.Y.Z, X.Y, or X",
                    'include-component-invalid-semver'
                ))

        # Validate inputs if present
        if 'inputs' in inc:
            inputs = inc['inputs']
            if not isinstance(inputs, dict):
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: 'inputs' must be a dictionary",
                    'include-component-inputs-invalid-type'
                ))

        # Check for invalid keywords with component
        valid_component_keywords = {'component', 'inputs', 'rules'}
        for keyword in inc.keys():
            if keyword not in valid_component_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Include item #{item_num}: unknown keyword '{keyword}' for component include",
                    'include-component-unknown-keyword'
                ))

    def _validate_local_include(self, local_path: Any, line: int, item_num: int):
        """Validate include:local syntax"""

        if not isinstance(local_path, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'local' must be a string",
                'include-local-invalid-type'
            ))
            return

        # Local path should start with / for absolute or ./ for relative
        if not local_path.startswith(('/','.')):
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Include item #{item_num}: local path '{local_path}' should start with '/' or './'",
                'include-local-path-format'
            ))

        # Should end with .yml or .yaml
        if not local_path.endswith(('.yml', '.yaml')):
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Include item #{item_num}: local path '{local_path}' should end with .yml or .yaml",
                'include-local-file-extension'
            ))

    def _validate_remote_include(self, inc: Dict[str, Any], line: int, item_num: int):
        """Validate include:remote syntax"""

        remote = inc.get('remote')

        if not isinstance(remote, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'remote' must be a string URL",
                'include-remote-invalid-type'
            ))
            return

        # Should be a valid URL
        if not remote.startswith(('http://', 'https://')):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: remote URL must start with http:// or https://",
                'include-remote-invalid-url'
            ))

        # Check for valid keywords with remote
        valid_remote_keywords = {'remote', 'rules'}
        for keyword in inc.keys():
            if keyword not in valid_remote_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Include item #{item_num}: unknown keyword '{keyword}' for remote include",
                    'include-remote-unknown-keyword'
                ))

    def _validate_template_include(self, inc: Dict[str, Any], line: int, item_num: int):
        """Validate include:template syntax"""

        template = inc.get('template')

        if not isinstance(template, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'template' must be a string",
                'include-template-invalid-type'
            ))
            return

        # Template should end with .yml or .yaml
        if not template.endswith(('.yml', '.yaml', '.gitlab-ci.yml')):
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Include item #{item_num}: template '{template}' should end with .yml or .yaml",
                'include-template-file-extension'
            ))

        # Common GitLab templates: Auto-DevOps.gitlab-ci.yml, Jobs/*.gitlab-ci.yml, Security/*.gitlab-ci.yml
        # These are in /lib/gitlab/ci/templates/
        # Just validate the format, don't check if template exists (that requires API access)

        # Check for valid keywords with template
        valid_template_keywords = {'template', 'rules'}
        for keyword in inc.keys():
            if keyword not in valid_template_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Include item #{item_num}: unknown keyword '{keyword}' for template include",
                    'include-template-unknown-keyword'
                ))

    def _validate_project_include(self, inc: Dict[str, Any], line: int, item_num: int):
        """Validate include:project syntax"""

        project = inc.get('project')

        if not isinstance(project, str):
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'project' must be a string",
                'include-project-invalid-type'
            ))
            return

        # Project format should be: group/project or group/subgroup/project
        if '/' not in project:
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Include item #{item_num}: project '{project}' should include group/project format",
                'include-project-format'
            ))

        # 'file' is required with 'project'
        if 'file' not in inc:
            self.errors.append(ValidationError(
                'error',
                line,
                f"Include item #{item_num}: 'file' is required when using 'project'",
                'include-project-missing-file'
            ))
        else:
            file_val = inc['file']
            # file can be a string or list of strings
            if isinstance(file_val, str):
                files = [file_val]
            elif isinstance(file_val, list):
                files = file_val
            else:
                self.errors.append(ValidationError(
                    'error',
                    line,
                    f"Include item #{item_num}: 'file' must be a string or list of strings",
                    'include-project-file-invalid-type'
                ))
                files = []

            # Validate each file path
            for file_path in files:
                if not isinstance(file_path, str):
                    self.errors.append(ValidationError(
                        'error',
                        line,
                        f"Include item #{item_num}: file path must be a string",
                        'include-project-file-item-invalid'
                    ))
                    continue

                # File should start with / or ./
                if not file_path.startswith(('/', './')):
                    self.errors.append(ValidationError(
                        'warning',
                        line,
                        f"Include item #{item_num}: file path '{file_path}' should start with '/' or './'",
                        'include-project-file-path-format'
                    ))

                # Should end with .yml or .yaml
                if not file_path.endswith(('.yml', '.yaml')):
                    self.errors.append(ValidationError(
                        'warning',
                        line,
                        f"Include item #{item_num}: file path '{file_path}' should end with .yml or .yaml",
                        'include-project-file-extension'
                    ))

        # 'ref' is recommended for reproducibility (commit SHA, tag, or branch)
        if 'ref' not in inc:
            self.errors.append(ValidationError(
                'warning',
                line,
                f"Include item #{item_num}: consider specifying 'ref' (commit SHA, tag, or branch) for reproducibility",
                'include-project-no-ref'
            ))

        # Check for valid keywords with project
        valid_project_keywords = {'project', 'file', 'ref', 'rules'}
        for keyword in inc.keys():
            if keyword not in valid_project_keywords:
                self.errors.append(ValidationError(
                    'warning',
                    line,
                    f"Include item #{item_num}: unknown keyword '{keyword}' for project include",
                    'include-project-unknown-keyword'
                ))


def main():
    """Main entry point"""

    if len(sys.argv) < 2:
        print("Usage: validate_syntax.py <gitlab-ci.yml> [--json]", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    json_output = '--json' in sys.argv

    validator = GitLabCIValidator(file_path)
    success, errors = validator.validate()

    # Group by severity
    by_severity = defaultdict(list)
    for error in errors:
        by_severity[error.severity].append(error)

    if json_output:
        # Output JSON format
        result = {
            'validator': 'syntax',
            'file': file_path,
            'success': success,
            'issues': [error.to_dict() for error in errors],
            'summary': {
                'errors': len(by_severity.get('error', [])),
                'warnings': len(by_severity.get('warning', [])),
                'info': len(by_severity.get('info', []))
            }
        }
        print(json.dumps(result, indent=2))
    else:
        # Output formatted text
        if errors:
            print(f"\n{'='*80}")
            print(f"Validation Results for: {file_path}")
            print(f"{'='*80}\n")

            # Print errors first, then warnings, then info
            for severity in ['error', 'warning', 'info']:
                if severity in by_severity:
                    print(f"\n{severity.upper()}S ({len(by_severity[severity])}):")
                    print("-" * 80)
                    for error in by_severity[severity]:
                        print(f"  {error}")

            print(f"\n{'='*80}")
            print(f"Summary: {len(by_severity['error'])} errors, "
                  f"{len(by_severity.get('warning', []))} warnings, "
                  f"{len(by_severity.get('info', []))} info")
            print(f"{'='*80}\n")

        if success:
            print(f"✓ Syntax validation passed for {file_path}")
        else:
            print(f"✗ Syntax validation failed for {file_path}")

    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
