#!/usr/bin/env python3
"""
GitLab CI/CD Best Practices Checker

This script checks GitLab CI/CD YAML files for best practices:
- Cache usage for dependency installation
- Artifact expiration settings
- Proper use of 'needs' vs 'dependencies'
- Use of 'rules' vs deprecated 'only'/'except'
- Interruptible job configuration
- Retry configuration
- Timeout settings
- Image version pinning
- DAG optimization opportunities
"""

import sys
import yaml
import re
import json
from pathlib import Path
from typing import Dict, List, Any, Set
from collections import defaultdict


class BestPracticeIssue:
    """Represents a best practice issue"""

    def __init__(self, severity: str, line: int, message: str, rule: str, suggestion: str = ""):
        self.severity = severity  # 'suggestion', 'warning'
        self.line = line
        self.message = message
        self.rule = rule
        self.suggestion = suggestion

    def __str__(self):
        result = f"{self.severity.upper()}: Line {self.line}: {self.message} [{self.rule}]"
        if self.suggestion:
            result += f"\n  💡 Suggestion: {self.suggestion}"
        return result

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON output"""
        result = {
            'severity': self.severity,
            'line': self.line,
            'message': self.message,
            'rule': self.rule
        }
        if self.suggestion:
            result['suggestion'] = self.suggestion
        return result


class BestPracticesChecker:
    """Checks GitLab CI/CD best practices"""

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
        self._check_cache_usage()
        self._check_artifact_expiration()
        self._check_needs_vs_dependencies()
        self._check_rules_usage()
        self._check_interruptible()
        self._check_retry_configuration()
        self._check_timeout_settings()
        self._check_image_pinning()
        self._check_dag_opportunities()
        self._check_parallel_usage()
        self._check_resource_optimization()
        self._check_environment_configuration()
        self._check_extends_usage()
        self._check_missing_tags()
        self._check_dependency_proxy_usage()
        self._check_coverage_regex()

        return self.issues

    def _build_line_map(self, content: str):
        """Build line number map for error reporting"""
        lines = content.split('\n')
        current_line = 1

        for line in lines:
            match = re.match(r'^(\s*)([a-zA-Z0-9_-]+):', line)
            if match:
                key = match.group(2)
                self.line_map[key] = current_line
            current_line += 1

    def _get_line(self, key: str) -> int:
        """Get line number for a key"""
        return self.line_map.get(key, 0)

    def _is_job(self, key: str) -> bool:
        """Check if a key represents a job"""
        global_keywords = {
            'default', 'include', 'stages', 'variables', 'workflow', 'spec'
        }
        return key not in global_keywords and isinstance(self.config.get(key), dict)

    def _inherits_setting(self, job: Dict[str, Any], setting: str, visited: Set[str] = None) -> bool:
        """Check if a job inherits a setting from extended templates or default.

        Args:
            job: The job configuration dict
            setting: The setting key to check for (e.g., 'interruptible', 'retry')
            visited: Set of already visited templates to prevent infinite loops

        Returns:
            True if the setting is inherited from a template or default
        """
        if visited is None:
            visited = set()

        # Check if job has extends
        extends = job.get('extends')
        if not extends:
            return False

        # Normalize to list
        templates = [extends] if isinstance(extends, str) else extends

        for template in templates:
            # Prevent infinite loops
            if template in visited:
                continue
            visited.add(template)

            # Get template config
            template_config = self.config.get(template)
            if not isinstance(template_config, dict):
                continue

            # Check if template has the setting
            if setting in template_config:
                return True

            # Recursively check if template inherits the setting
            if self._inherits_setting(template_config, setting, visited):
                return True

        return False

    def _check_cache_usage(self):
        """Check for proper cache usage"""

        # Keywords that suggest dependency installation
        dependency_keywords = ['npm', 'pip', 'yarn', 'bundle', 'go mod', 'composer', 'mvn', 'gradle']

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            line = self._get_line(job_name)
            script = job.get('script', [])

            if isinstance(script, str):
                script = [script]

            # Check if job installs dependencies
            installs_deps = False
            for cmd in script:
                if any(keyword in str(cmd).lower() for keyword in dependency_keywords):
                    if any(install_cmd in str(cmd).lower() for install_cmd in ['install', 'ci', 'get', 'download']):
                        installs_deps = True
                        break

            if installs_deps and 'cache' not in job:
                # Check if it inherits from default
                has_default_cache = 'cache' in self.config.get('default', {})
                extends = job.get('extends')

                # Check if extends a template with cache
                has_template_cache = False
                if extends:
                    templates = [extends] if isinstance(extends, str) else extends
                    for template in templates:
                        if template.startswith('.') and 'cache' in self.config.get(template, {}):
                            has_template_cache = True
                            break

                if not has_default_cache and not has_template_cache:
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Job '{job_name}' installs dependencies but doesn't use cache",
                        'cache-missing',
                        "Add 'cache' configuration to speed up dependency installation"
                    ))

            # Check cache key
            if 'cache' in job:
                cache = job['cache']
                caches = [cache] if isinstance(cache, dict) else cache

                for cache_item in caches:
                    if isinstance(cache_item, dict):
                        if 'key' not in cache_item:
                            self.issues.append(BestPracticeIssue(
                                'warning',
                                line,
                                f"Job '{job_name}' has cache without explicit 'key'",
                                'cache-no-key',
                                "Use 'key: ${CI_COMMIT_REF_SLUG}' or similar for better cache management"
                            ))

    def _check_artifact_expiration(self):
        """Check artifact expiration settings"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            if 'artifacts' in job:
                line = self._get_line(job_name)
                artifacts = job['artifacts']

                if isinstance(artifacts, dict) and 'expire_in' not in artifacts:
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Job '{job_name}' has artifacts without expiration",
                        'artifact-no-expiration',
                        "Add 'expire_in' to avoid storage bloat (e.g., '1 week', '30 days')"
                    ))

    def _check_needs_vs_dependencies(self):
        """Check for proper use of needs vs dependencies"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            line = self._get_line(job_name)
            has_needs = 'needs' in job
            has_dependencies = 'dependencies' in job

            # If using needs, suggest using dependencies to control artifact downloads
            if has_needs and not has_dependencies:
                needs = job['needs']
                needs_list = needs if isinstance(needs, list) else [needs]

                # If needs more than 2 jobs, suggest using dependencies
                if len(needs_list) > 2:
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Job '{job_name}' uses 'needs' but not 'dependencies'",
                        'needs-without-dependencies',
                        "Consider using 'dependencies' to control which artifacts are downloaded"
                    ))

    def _check_rules_usage(self):
        """Check for deprecated only/except usage"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            line = self._get_line(job_name)
            has_only = 'only' in job
            has_except = 'except' in job
            has_rules = 'rules' in job

            if (has_only or has_except) and not has_rules:
                self.issues.append(BestPracticeIssue(
                    'warning',
                    line,
                    f"Job '{job_name}' uses deprecated 'only'/'except'",
                    'deprecated-only-except',
                    "Replace 'only'/'except' with 'rules' for more flexibility"
                ))

    def _check_interruptible(self):
        """Check for interruptible configuration"""

        # Check if default interruptible is set
        default_interruptible = self.config.get('default', {}).get('interruptible')

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            line = self._get_line(job_name)

            # Check if job inherits interruptible from extends
            has_inherited_interruptible = self._inherits_setting(job, 'interruptible')

            # Jobs that should not be interruptible
            non_interruptible_keywords = ['deploy', 'release', 'publish', 'production']
            is_critical = any(keyword in job_name.lower() for keyword in non_interruptible_keywords)

            if is_critical and job.get('interruptible', False):
                self.issues.append(BestPracticeIssue(
                    'warning',
                    line,
                    f"Job '{job_name}' is critical but marked as interruptible",
                    'interruptible-critical',
                    "Set 'interruptible: false' for critical deployment jobs"
                ))

            # Long-running test jobs should be interruptible
            # Skip if default interruptible is set or inherited from template
            if 'test' in job_name.lower() and 'interruptible' not in job:
                if not default_interruptible and not has_inherited_interruptible:
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Test job '{job_name}' not marked as interruptible",
                        'missing-interruptible',
                        "Add 'interruptible: true' to allow cancellation of redundant test runs"
                    ))

    def _check_retry_configuration(self):
        """Check retry configuration"""

        # Check if default retry is set
        default_retry = self.config.get('default', {}).get('retry')

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            # Jobs that commonly have flaky tests or network issues
            flaky_indicators = ['test', 'e2e', 'integration', 'api']
            is_potentially_flaky = any(indicator in job_name.lower() for indicator in flaky_indicators)

            # Check if job inherits retry from extends
            has_inherited_retry = self._inherits_setting(job, 'retry')

            if is_potentially_flaky and 'retry' not in job:
                # Skip if default retry is set or inherited from template
                if not default_retry and not has_inherited_retry:
                    line = self._get_line(job_name)
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Job '{job_name}' might benefit from retry configuration",
                        'missing-retry',
                        "Add 'retry' with specific conditions (e.g., runner_system_failure, stuck_or_timeout_failure)"
                    ))

            # Check retry configuration format
            if 'retry' in job:
                line = self._get_line(job_name)
                retry = job['retry']

                if isinstance(retry, int) and retry > 2:
                    self.issues.append(BestPracticeIssue(
                        'warning',
                        line,
                        f"Job '{job_name}' has high retry count ({retry})",
                        'high-retry-count',
                        "Consider using structured retry with 'max' and 'when' conditions"
                    ))

    def _check_timeout_settings(self):
        """Check timeout configuration"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            script = job.get('script', [])
            if isinstance(script, str):
                script = [script]

            # Check for long-running operations without timeout
            long_running_keywords = ['build', 'compile', 'test', 'deploy', 'migration']
            is_long_running = any(keyword in job_name.lower() for keyword in long_running_keywords)

            if is_long_running and 'timeout' not in job:
                line = self._get_line(job_name)
                self.issues.append(BestPracticeIssue(
                    'suggestion',
                    line,
                    f"Long-running job '{job_name}' has no explicit timeout",
                    'missing-timeout',
                    "Add 'timeout' to prevent jobs from hanging indefinitely"
                ))

    def _check_image_pinning(self):
        """Check for proper Docker image version pinning"""

        def check_image(image_value, context, line_key):
            """Check image pinning for a specific image.

            Args:
                image_value: The image string or dict to check
                context: Descriptive context for the message (e.g., "job 'deploy_staging'")
                line_key: The actual key to look up in line_map (e.g., "deploy_staging")
            """
            if not isinstance(image_value, str):
                if isinstance(image_value, dict):
                    image_value = image_value.get('name', '')
                else:
                    return

            line = self._get_line(line_key) if line_key else 0

            # Check for :latest tag
            if ':latest' in image_value:
                self.issues.append(BestPracticeIssue(
                    'warning',
                    line,
                    f"Using ':latest' tag in {context}",
                    'image-latest-tag',
                    "Pin to specific version (e.g., 'node:18-alpine') or SHA digest"
                ))
            # Check if no version specified
            elif ':' not in image_value and '@' not in image_value:
                # Ignore if it's a variable
                if not image_value.startswith('$'):
                    self.issues.append(BestPracticeIssue(
                        'warning',
                        line,
                        f"Image '{image_value}' has no version tag in {context}",
                        'image-no-version',
                        "Pin to specific version (e.g., 'node:18-alpine')"
                    ))

        # Check global image
        if 'image' in self.config:
            check_image(self.config['image'], 'global image', 'image')

        # Check default image
        if 'default' in self.config and 'image' in self.config['default']:
            check_image(self.config['default']['image'], 'default image', 'default')

        # Check job images
        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            if 'image' in job:
                check_image(job['image'], f"job '{job_name}'", job_name)

            # Check service images
            if 'services' in job:
                services = job['services']
                if isinstance(services, list):
                    for service in services:
                        check_image(service, f"job '{job_name}' services", job_name)

    def _check_dag_opportunities(self):
        """Check for DAG optimization opportunities"""

        # Find jobs that could use 'needs'
        jobs_by_stage = defaultdict(list)

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            stage = job.get('stage', 'test')
            jobs_by_stage[stage].append((job_name, job))

        # Check if multiple stages exist without needs
        stages = self.config.get('stages', ['build', 'test', 'deploy'])

        if len(stages) > 2:
            for job_name, job in self.config.items():
                if not self._is_job(job_name) or job_name.startswith('.'):
                    continue

                if 'needs' not in job and 'trigger' not in job:
                    stage = job.get('stage', 'test')
                    stage_index = stages.index(stage) if stage in stages else 0

                    if stage_index > 0:  # Not in first stage
                        line = self._get_line(job_name)
                        self.issues.append(BestPracticeIssue(
                            'suggestion',
                            line,
                            f"Job '{job_name}' in stage '{stage}' might benefit from 'needs'",
                            'dag-optimization',
                            "Use 'needs' to create a DAG and run jobs as soon as dependencies complete"
                        ))
                        break  # Only suggest once per file

    def _check_parallel_usage(self):
        """Check for parallel execution opportunities"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            # Check for test jobs that might benefit from parallelization
            if 'test' in job_name.lower() and 'parallel' not in job:
                script = job.get('script', [])
                if isinstance(script, str):
                    script = [script]

                # Look for test commands
                test_commands = ['npm test', 'pytest', 'go test', 'rspec', 'jest']
                has_tests = any(
                    any(cmd in str(line) for cmd in test_commands)
                    for line in script
                )

                if has_tests:
                    line = self._get_line(job_name)
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Test job '{job_name}' might benefit from parallelization",
                        'parallel-opportunity',
                        "Consider using 'parallel: N' to split tests across multiple runners"
                    ))
                    break  # Only suggest once per file

    def _check_resource_optimization(self):
        """Check for resource optimization opportunities"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            # Check for resource_group on deployment jobs
            is_deployment = any(keyword in job_name.lower() for keyword in ['deploy', 'release'])

            if is_deployment and 'resource_group' not in job:
                environment = job.get('environment')
                if environment:
                    line = self._get_line(job_name)
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Deployment job '{job_name}' should use resource_group",
                        'missing-resource-group',
                        "Add 'resource_group' to prevent concurrent deployments to same environment"
                    ))

    def _check_environment_configuration(self):
        """Check environment configuration best practices"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            if 'environment' in job:
                line = self._get_line(job_name)
                environment = job['environment']

                if isinstance(environment, dict):
                    # Check for URL
                    if 'url' not in environment:
                        self.issues.append(BestPracticeIssue(
                            'suggestion',
                            line,
                            f"Environment in job '{job_name}' missing 'url'",
                            'environment-no-url',
                            "Add 'url' to make environment easily accessible from GitLab UI"
                        ))

                    # Check for on_stop on non-production environments
                    env_name = environment.get('name', '')
                    is_dynamic = 'review' in env_name.lower() or '$' in env_name

                    if is_dynamic and 'on_stop' not in environment:
                        self.issues.append(BestPracticeIssue(
                            'suggestion',
                            line,
                            f"Dynamic environment in job '{job_name}' missing 'on_stop'",
                            'environment-no-stop',
                            "Add 'on_stop' and 'auto_stop_in' for automatic cleanup of review apps"
                        ))

    def _check_extends_usage(self):
        """Check for extends usage opportunities"""

        # Find jobs with similar configuration
        job_configs = {}

        for job_name, job in self.config.items():
            if not self._is_job(job_name) or job_name.startswith('.'):
                continue

            # Create a signature of common keywords
            signature = tuple(sorted([k for k in job.keys() if k not in ['script', 'stage', 'environment']]))
            if signature:
                if signature not in job_configs:
                    job_configs[signature] = []
                job_configs[signature].append(job_name)

        # Find duplicate configurations
        for signature, jobs in job_configs.items():
            if len(jobs) >= 3:  # If 3 or more jobs share configuration
                # Check if they're already using extends
                using_extends = any('extends' in self.config[job] for job in jobs)

                if not using_extends:
                    line = self._get_line(jobs[0])
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Jobs {', '.join(jobs[:3])} share similar configuration",
                        'extends-opportunity',
                        "Consider creating a template job (starting with '.') and use 'extends'"
                    ))
                    break  # Only suggest once

    def _check_missing_tags(self):
        """Check for jobs missing tags (important for self-hosted runners)"""

        # Check if any job has tags defined (indicates self-hosted runners)
        has_tags_in_pipeline = False
        for job_name, job in self.config.items():
            if self._is_job(job_name) and 'tags' in job:
                has_tags_in_pipeline = True
                break

        # If some jobs have tags, warn about jobs without tags
        if has_tags_in_pipeline:
            for job_name, job in self.config.items():
                if not self._is_job(job_name):
                    continue

                if 'tags' not in job:
                    # Skip if job extends a template (might inherit tags)
                    if 'extends' in job:
                        continue

                    line = self._get_line(job_name)
                    self.issues.append(BestPracticeIssue(
                        'warning',
                        line,
                        f"Job '{job_name}' missing 'tags' keyword",
                        'missing-tags',
                        "Add 'tags' to ensure job runs on appropriate runners in self-hosted environment"
                    ))

    def _check_dependency_proxy_usage(self):
        """Check for CI_DEPENDENCY_PROXY usage to avoid Docker Hub rate limits"""

        has_docker_images = False
        uses_dependency_proxy = False

        # Check if we have Docker images from Docker Hub
        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            # Check image
            if 'image' in job:
                image = job['image']
                if isinstance(image, str):
                    # Check if it's from Docker Hub (no registry prefix or docker.io)
                    if not any(reg in image for reg in ['gcr.io', 'ghcr.io', 'registry.gitlab.com', 'quay.io']):
                        if '/' not in image or image.startswith('docker.io/') or image.count('/') == 1:
                            has_docker_images = True

                        # Check if using dependency proxy
                        if '$CI_DEPENDENCY_PROXY' in image or '${CI_DEPENDENCY_PROXY' in image:
                            uses_dependency_proxy = True

            # Check services
            if 'services' in job:
                services = job['services']
                if isinstance(services, list):
                    for service in services:
                        if isinstance(service, str):
                            if not any(reg in service for reg in ['gcr.io', 'ghcr.io', 'registry.gitlab.com', 'quay.io']):
                                if '/' not in service or service.startswith('docker.io/') or service.count('/') == 1:
                                    has_docker_images = True

                            if '$CI_DEPENDENCY_PROXY' in service or '${CI_DEPENDENCY_PROXY' in service:
                                uses_dependency_proxy = True

        # If we have Docker Hub images but not using dependency proxy, suggest it
        if has_docker_images and not uses_dependency_proxy:
            self.issues.append(BestPracticeIssue(
                'suggestion',
                0,
                "Pipeline uses Docker Hub images without dependency proxy",
                'no-dependency-proxy',
                "Use $CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX to avoid Docker Hub rate limits. "
                "Example: image: $CI_DEPENDENCY_PROXY_GROUP_IMAGE_PREFIX/node:16"
            ))

    def _check_coverage_regex(self):
        """Check for coverage regex on test jobs"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            # Heuristic: if job name contains 'test' or stage is 'test'
            is_test_job = (
                'test' in job_name.lower() or
                job.get('stage') == 'test' or
                'pytest' in str(job.get('script', [])) or
                'jest' in str(job.get('script', [])) or
                'npm test' in str(job.get('script', [])) or
                'go test' in str(job.get('script', []))
            )

            if is_test_job:
                # Check if coverage is configured
                has_coverage = 'coverage' in job

                # Check if artifacts have coverage reports
                has_coverage_report = False
                if 'artifacts' in job and isinstance(job['artifacts'], dict):
                    reports = job['artifacts'].get('reports', {})
                    if isinstance(reports, dict) and 'coverage_report' in reports:
                        has_coverage_report = True

                if not has_coverage and not has_coverage_report:
                    line = self._get_line(job_name)
                    self.issues.append(BestPracticeIssue(
                        'suggestion',
                        line,
                        f"Test job '{job_name}' missing coverage configuration",
                        'missing-coverage',
                        "Add 'coverage' regex or 'artifacts:reports:coverage_report' to track code coverage"
                    ))


def main():
    """Main entry point"""

    if len(sys.argv) < 2:
        print("Usage: check_best_practices.py <gitlab-ci.yml> [--json]", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    json_output = '--json' in sys.argv

    checker = BestPracticesChecker(file_path)
    issues = checker.check()

    # Group by severity
    by_severity = defaultdict(list)
    for issue in issues:
        by_severity[issue.severity].append(issue)

    if json_output:
        # Output JSON format
        result = {
            'validator': 'best_practices',
            'file': file_path,
            'success': len(issues) == 0,
            'issues': [issue.to_dict() for issue in issues],
            'summary': {
                'warnings': len(by_severity.get('warning', [])),
                'suggestions': len(by_severity.get('suggestion', []))
            }
        }
        print(json.dumps(result, indent=2))
    else:
        # Output formatted text
        if issues:
            print(f"\n{'='*80}")
            print(f"Best Practices Check for: {file_path}")
            print(f"{'='*80}\n")

            # Print warnings first, then suggestions
            for severity in ['warning', 'suggestion']:
                if severity in by_severity:
                    print(f"\n{severity.upper()}S ({len(by_severity[severity])}):")
                    print("-" * 80)
                    for issue in by_severity[severity]:
                        print(f"  {issue}\n")

            print(f"{'='*80}")
            print(f"Summary: {len(by_severity.get('warning', []))} warnings, "
                  f"{len(by_severity.get('suggestion', []))} suggestions")
            print(f"{'='*80}\n")

            print("✓ Best practices check completed")
        else:
            print(f"✓ No best practice issues found in {file_path}")

    # Exit with 1 if issues were found (to trigger WARNINGS display in shell script)
    sys.exit(1 if issues else 0)


if __name__ == '__main__':
    main()
