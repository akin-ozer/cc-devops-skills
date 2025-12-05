#!/usr/bin/env python3
"""
GitLab CI/CD Security Scanner

This script scans GitLab CI/CD YAML files for security issues:
- Hardcoded secrets and credentials
- Unmasked sensitive variables
- Insecure Docker image usage
- Dangerous script patterns
- Secrets in logs
- Insecure dependency installation
- Command injection vulnerabilities
- Unpinned external resources
"""

import sys
import yaml
import re
import json
from pathlib import Path
from typing import Dict, List, Any, Pattern
from collections import defaultdict


class SecurityIssue:
    """Represents a security issue"""

    def __init__(self, severity: str, line: int, message: str, rule: str, remediation: str = ""):
        self.severity = severity  # 'critical', 'high', 'medium', 'low'
        self.line = line
        self.message = message
        self.rule = rule
        self.remediation = remediation

    def __str__(self):
        result = f"{self.severity.upper()}: Line {self.line}: {self.message} [{self.rule}]"
        if self.remediation:
            result += f"\n  🔒 Remediation: {self.remediation}"
        return result

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary for JSON output"""
        result = {
            'severity': self.severity,
            'line': self.line,
            'message': self.message,
            'rule': self.rule
        }
        if self.remediation:
            result['remediation'] = self.remediation
        return result


class SecurityScanner:
    """Scans GitLab CI/CD files for security issues"""

    # Patterns for detecting hardcoded secrets
    SECRET_PATTERNS = [
        (re.compile(r'(?i)(password|passwd|pwd)\s*[:=]\s*["\']?[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:,.<>?/\\|`~]{8,}["\']?'), 'password'),
        (re.compile(r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?[a-zA-Z0-9_\-]{16,}["\']?'), 'api-key'),
        (re.compile(r'(?i)(secret|token)\s*[:=]\s*["\']?[a-zA-Z0-9_\-]{16,}["\']?'), 'secret-token'),
        (re.compile(r'(?i)(aws_access_key_id|aws_secret_access_key)\s*[:=]\s*["\']?[A-Z0-9]{16,}["\']?'), 'aws-credentials'),
        (re.compile(r'(?i)bearer\s+[a-zA-Z0-9_\-\.]{20,}'), 'bearer-token'),
        (re.compile(r'(?i)authorization:\s*(basic|bearer)\s+[a-zA-Z0-9_\-\.=]+'), 'auth-header'),
        (re.compile(r'-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'), 'private-key'),
        (re.compile(r'(?i)(client_secret|client_id)\s*[:=]\s*["\']?[a-zA-Z0-9_\-]{16,}["\']?'), 'oauth-credentials'),
        (re.compile(r'(?i)(database_url|db_url|connection_string)\s*[:=]\s*["\']?[a-zA-Z0-9]+://[^"\'\s]+["\']?'), 'connection-string'),
    ]

    # Dangerous script patterns
    DANGEROUS_PATTERNS = [
        (re.compile(r'curl\s+[^|]*\|\s*(bash|sh)'), 'curl-pipe-bash', 'Download and verify scripts before execution'),
        (re.compile(r'wget\s+[^|]*\|\s*(bash|sh)'), 'wget-pipe-bash', 'Download and verify scripts before execution'),
        (re.compile(r'eval\s+\$'), 'eval-variable', 'Avoid using eval with variables to prevent code injection'),
        (re.compile(r'\$\{.*?\}.*?\|.*?(bash|sh)'), 'variable-pipe-shell', 'Validate input before piping to shell'),
        (re.compile(r'chmod\s+777'), 'chmod-777', 'Avoid overly permissive file permissions'),
        (re.compile(r'--no-verify'), 'skip-verification', 'Do not skip verification checks'),
        (re.compile(r'--insecure|-k\s'), 'insecure-ssl', 'Do not disable SSL/TLS verification'),
    ]

    # Patterns that might leak secrets in logs
    ECHO_SECRET_PATTERNS = [
        re.compile(r'echo\s+.*\$(PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'print.*\$(PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'console\.log.*\$(PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
    ]

    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.issues: List[SecurityIssue] = []
        self.config: Dict[str, Any] = {}
        self.raw_content: str = ""
        self.line_map: Dict[str, int] = {}

    def scan(self) -> List[SecurityIssue]:
        """Run all security scans"""

        try:
            with open(self.file_path, 'r') as f:
                self.raw_content = f.read()
            self.config = yaml.safe_load(self.raw_content)
            self._build_line_map()
        except Exception as e:
            print(f"Error loading file: {e}", file=sys.stderr)
            return []

        if not isinstance(self.config, dict):
            return []

        # Run all security checks
        self._check_hardcoded_secrets()
        self._check_dangerous_scripts()
        self._check_secret_exposure()
        self._check_image_security()
        self._check_dependency_security()
        self._check_variable_security()
        self._check_include_security()
        self._check_artifact_security()
        self._check_git_strategy_security()

        return self.issues

    def _build_line_map(self):
        """Build line number map"""
        lines = self.raw_content.split('\n')
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

    def _find_line_for_text(self, text: str) -> int:
        """Find line number for specific text"""
        lines = self.raw_content.split('\n')
        for i, line in enumerate(lines, 1):
            if text in line:
                return i
        return 0

    def _is_job(self, key: str) -> bool:
        """Check if a key represents a job"""
        global_keywords = {
            'default', 'include', 'stages', 'variables', 'workflow', 'spec'
        }
        return key not in global_keywords and isinstance(self.config.get(key), dict)

    def _check_hardcoded_secrets(self):
        """Check for hardcoded secrets"""

        # Check in raw content for better detection
        lines = self.raw_content.split('\n')

        # Pattern to match variable references: $VAR, ${VAR}, $CI_VAR, etc.
        var_reference_pattern = re.compile(r'\$\{?[A-Z_][A-Z0-9_]*\}?')

        for line_num, line in enumerate(lines, 1):
            # Skip comments
            if line.strip().startswith('#'):
                continue

            for pattern, secret_type in self.SECRET_PATTERNS:
                match = pattern.search(line)
                if match:
                    # Get the matched value (after the key/operator)
                    matched_text = match.group(0)

                    # Extract the value part (everything after : or =)
                    value_match = re.search(r'[:=]\s*(.+)$', matched_text)
                    if value_match:
                        value_part = value_match.group(1).strip()

                        # Check if the value contains variable references
                        # If it's a variable reference or contains variables, skip it
                        if var_reference_pattern.search(value_part):
                            continue

                        # Check if value looks like a placeholder (all caps, contains underscores, etc.)
                        if value_part.replace('"', '').replace("'", '').replace('_', '').replace('-', '').isupper():
                            continue

                        # This looks like a real hardcoded secret
                        self.issues.append(SecurityIssue(
                            'critical',
                            line_num,
                            f"Potential hardcoded {secret_type} detected",
                            f'hardcoded-{secret_type}',
                            "Use CI/CD variables or secrets manager instead of hardcoding credentials"
                        ))
                    else:
                        # If we can't extract the value, check the whole match
                        if not var_reference_pattern.search(matched_text):
                            self.issues.append(SecurityIssue(
                                'critical',
                                line_num,
                                f"Potential hardcoded {secret_type} detected",
                                f'hardcoded-{secret_type}',
                                "Use CI/CD variables or secrets manager instead of hardcoding credentials"
                            ))

    def _check_dangerous_scripts(self):
        """Check for dangerous script patterns"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            # Check all script sections
            for script_key in ['script', 'before_script', 'after_script']:
                if script_key not in job:
                    continue

                script = job[script_key]
                if isinstance(script, str):
                    script = [script]

                for cmd in script:
                    cmd_str = str(cmd)

                    for pattern, rule_id, remediation in self.DANGEROUS_PATTERNS:
                        if pattern.search(cmd_str):
                            line = self._find_line_for_text(cmd_str[:50])
                            self.issues.append(SecurityIssue(
                                'high',
                                line,
                                f"Dangerous script pattern in job '{job_name}': {rule_id}",
                                rule_id,
                                remediation
                            ))

    def _check_secret_exposure(self):
        """Check for potential secret exposure in logs"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            line = self._get_line(job_name)

            # Check script sections for echo/print of secrets
            for script_key in ['script', 'before_script', 'after_script']:
                if script_key not in job:
                    continue

                script = job[script_key]
                if isinstance(script, str):
                    script = [script]

                for cmd in script:
                    cmd_str = str(cmd)

                    for pattern in self.ECHO_SECRET_PATTERNS:
                        if pattern.search(cmd_str):
                            self.issues.append(SecurityIssue(
                                'high',
                                line,
                                f"Job '{job_name}' may expose secrets in logs",
                                'secret-in-logs',
                                "Avoid printing secret variables; ensure they are masked in CI/CD settings"
                            ))

            # Check for debug flags that might expose secrets
            if 'variables' in job:
                variables = job['variables']
                if isinstance(variables, dict):
                    if variables.get('CI_DEBUG_TRACE') == 'true':
                        self.issues.append(SecurityIssue(
                            'medium',
                            line,
                            f"Job '{job_name}' has CI_DEBUG_TRACE enabled",
                            'debug-trace-enabled',
                            "Debug trace may expose sensitive information; use only for troubleshooting"
                        ))

    def _check_image_security(self):
        """Check Docker image security"""

        def check_image(image_value, context, line):
            if not isinstance(image_value, str):
                if isinstance(image_value, dict):
                    image_value = image_value.get('name', '')
                else:
                    return

            # Check for :latest tag (security risk due to unpredictability)
            if ':latest' in image_value:
                self.issues.append(SecurityIssue(
                    'medium',
                    line,
                    f"Using ':latest' tag in {context} is a security risk",
                    'image-latest-tag',
                    "Pin to specific version or SHA digest to ensure consistent, verified images"
                ))

            # Check for variables in image names (potential injection)
            if '$' in image_value and '@sha256' not in image_value:
                self.issues.append(SecurityIssue(
                    'medium',
                    line,
                    f"Using variable in image name in {context} without SHA pinning",
                    'image-variable-no-digest',
                    "When using variables for images, ensure they resolve to SHA digests"
                ))

            # Warn about unverified registries
            if not any(registry in image_value for registry in [
                'docker.io', 'gcr.io', 'registry.gitlab.com', 'ghcr.io', 'quay.io'
            ]) and '/' in image_value:
                if not image_value.startswith('$'):
                    self.issues.append(SecurityIssue(
                        'low',
                        line,
                        f"Using image from unverified registry in {context}",
                        'image-unknown-registry',
                        "Ensure the registry is trusted and uses secure authentication"
                    ))

        # Check global and default images
        if 'image' in self.config:
            check_image(self.config['image'], 'global image', self._get_line('image'))

        if 'default' in self.config and 'image' in self.config['default']:
            check_image(self.config['default']['image'], 'default image', self._get_line('default'))

        # Check job images and services
        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            line = self._get_line(job_name)

            if 'image' in job:
                check_image(job['image'], f"job '{job_name}'", line)

            if 'services' in job:
                services = job['services']
                if isinstance(services, list):
                    for service in services:
                        check_image(service, f"job '{job_name}' services", line)

    def _check_dependency_security(self):
        """Check dependency installation security"""

        insecure_install_patterns = [
            (r'npm\s+install(?!\s+--ignore-scripts)', 'npm-without-ignore-scripts',
             'Use npm ci or npm install --ignore-scripts to prevent arbitrary script execution'),
            (r'pip\s+install(?!.*--require-hashes)', 'pip-without-hashes',
             'Use pip install --require-hashes for verified dependency installation'),
            (r'gem\s+install(?!.*--trust-policy)', 'gem-without-trust-policy',
             'Use gem install with --trust-policy to verify gem signatures'),
        ]

        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            script = job.get('script', [])
            if isinstance(script, str):
                script = [script]

            for cmd in script:
                cmd_str = str(cmd)

                for pattern, rule_id, remediation in insecure_install_patterns:
                    if re.search(pattern, cmd_str):
                        line = self._find_line_for_text(cmd_str[:50])
                        self.issues.append(SecurityIssue(
                            'medium',
                            line,
                            f"Insecure dependency installation in job '{job_name}'",
                            rule_id,
                            remediation
                        ))

    def _check_variable_security(self):
        """Check variable security"""

        # Check global variables
        if 'variables' in self.config:
            self._check_variable_dict('global', self.config['variables'], self._get_line('variables'))

        # Check job variables
        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            if 'variables' in job:
                self._check_variable_dict(f"job '{job_name}'", job['variables'], self._get_line(job_name))

    def _check_variable_dict(self, context: str, variables: Any, line: int):
        """Check a variables dictionary for security issues"""

        if not isinstance(variables, dict):
            return

        sensitive_var_patterns = [
            'PASSWORD', 'SECRET', 'TOKEN', 'KEY', 'CREDENTIAL',
            'API_KEY', 'APIKEY', 'AUTH', 'PRIVATE'
        ]

        for var_name, var_value in variables.items():
            # Check if sensitive variable name has a static value (might be hardcoded)
            if any(pattern in var_name.upper() for pattern in sensitive_var_patterns):
                if isinstance(var_value, str) and not var_value.startswith('$'):
                    # Check if it looks like an actual secret (not a placeholder)
                    if len(var_value) > 8 and not var_value.isupper():
                        self.issues.append(SecurityIssue(
                            'critical',
                            line,
                            f"Sensitive variable '{var_name}' in {context} appears to have hardcoded value",
                            'variable-hardcoded-secret',
                            "Use CI/CD variables with masking enabled or secrets manager"
                        ))

    def _check_include_security(self):
        """Check include security for all types: component, project, remote, local, template"""

        if 'include' not in self.config:
            return

        includes = self.config['include']
        if not isinstance(includes, list):
            includes = [includes]

        line = self._get_line('include')

        for i, inc in enumerate(includes):
            # Handle string includes (shorthand for local)
            if isinstance(inc, str):
                self._check_local_include_security(inc, line, i+1)
                continue

            if not isinstance(inc, dict):
                continue

            # Check component includes (GitLab 16.x+)
            if 'component' in inc:
                self._check_component_include_security(inc, line, i+1)

            # Check remote includes
            if 'remote' in inc:
                self._check_remote_include_security(inc, line, i+1)

            # Check project includes
            if 'project' in inc:
                self._check_project_include_security(inc, line, i+1)

            # Check local includes
            if 'local' in inc:
                self._check_local_include_security(inc['local'], line, i+1)

            # Check template includes
            if 'template' in inc:
                self._check_template_include_security(inc, line, i+1)

    def _check_component_include_security(self, inc: Dict[str, Any], line: int, item_num: int):
        """Check security for component includes"""

        component = inc.get('component', '')

        # Check for ~latest version (not recommended for production)
        if '@~latest' in component:
            self.issues.append(SecurityIssue(
                'medium',
                line,
                f"Include item #{item_num}: Component uses '~latest' version which may include breaking changes",
                'include-component-latest-version',
                "Pin to specific semantic version (e.g., @1.2.3) for production stability"
            ))

        # Check for external/untrusted component sources
        if 'gitlab.com' in component and '$CI_SERVER_FQDN' not in component:
            # Component from gitlab.com (public) - ensure it's from verified sources
            if '/components/' not in component:
                self.issues.append(SecurityIssue(
                    'medium',
                    line,
                    f"Include item #{item_num}: Component from external source - ensure it's from a trusted organization",
                    'include-component-external-source',
                    "Verify the component source and consider mirroring to your own GitLab instance"
                ))

        # Check if inputs contain sensitive data (should use variables instead)
        if 'inputs' in inc:
            inputs = inc['inputs']
            if isinstance(inputs, dict):
                for key, value in inputs.items():
                    if isinstance(value, str):
                        # Check for hardcoded secrets in inputs
                        sensitive_patterns = ['password', 'token', 'secret', 'key', 'credential']
                        if any(pattern in key.lower() for pattern in sensitive_patterns):
                            # Check if value is hardcoded (not a variable reference)
                            if not value.startswith('$'):
                                self.issues.append(SecurityIssue(
                                    'critical',
                                    line,
                                    f"Include item #{item_num}: Component input '{key}' may contain hardcoded sensitive data",
                                    'include-component-hardcoded-input',
                                    "Use CI/CD variables ($VARIABLE_NAME) instead of hardcoded values"
                                ))

    def _check_remote_include_security(self, inc: Dict[str, Any], line: int, item_num: int):
        """Check security for remote includes"""

        remote = inc.get('remote', '')

        # Always warn about remote includes - they're not verified
        self.issues.append(SecurityIssue(
            'high',
            line,
            f"Include item #{item_num}: Remote include from '{remote}' has no integrity verification",
            'include-remote-unverified',
            "Store remote files locally or verify their integrity. Use project includes with pinned refs instead"
        ))

        # Check for http:// (insecure)
        if remote.startswith('http://'):
            self.issues.append(SecurityIssue(
                'critical',
                line,
                f"Include item #{item_num}: Remote include uses insecure HTTP protocol",
                'include-remote-insecure-http',
                "Use HTTPS for remote includes to prevent man-in-the-middle attacks"
            ))

        # Check for githubusercontent.com raw links (commonly used but not recommended)
        if 'raw.githubusercontent.com' in remote:
            self.issues.append(SecurityIssue(
                'medium',
                line,
                f"Include item #{item_num}: Including from GitHub raw content without verification",
                'include-remote-github-raw',
                "Consider using GitLab's project include with pinned ref for better security"
            ))

    def _check_project_include_security(self, inc: Dict[str, Any], line: int, item_num: int):
        """Check security for project includes"""

        # Check project includes without specific ref
        if 'ref' not in inc:
            self.issues.append(SecurityIssue(
                'medium',
                line,
                f"Include item #{item_num}: Project include without pinned ref",
                'include-project-unpinned',
                "Pin includes to specific commit SHA or protected tag for reproducibility"
            ))
        else:
            ref = inc['ref']
            # Check for branch names instead of commits/tags
            if isinstance(ref, str):
                # Check if it's a commit SHA (40 hex chars) or version tag
                is_sha = re.match(r'^[0-9a-f]{40}$', ref)
                is_version_tag = re.match(r'^v?\d+\.\d+', ref)

                if not is_sha and not is_version_tag:
                    # Check for common branch names
                    if ref in ['main', 'master', 'develop', 'dev', 'staging', 'production']:
                        self.issues.append(SecurityIssue(
                            'medium',
                            line,
                            f"Include item #{item_num}: Uses branch name '{ref}' instead of commit SHA",
                            'include-project-branch-ref',
                            "Pin to specific commit SHA for reproducibility and security"
                        ))

        # Check for cross-project includes (may have different security contexts)
        project = inc.get('project', '')
        if '/' in project:
            # Check if it's from a different group
            self.issues.append(SecurityIssue(
                'low',
                line,
                f"Include item #{item_num}: Cross-project include from '{project}' - ensure appropriate access controls",
                'include-project-cross-project',
                "Verify that the included project has appropriate security controls and access restrictions"
            ))

    def _check_local_include_security(self, local_path: str, line: int, item_num: int):
        """Check security for local includes"""

        if not isinstance(local_path, str):
            return

        # Check for path traversal attempts
        if '..' in local_path:
            self.issues.append(SecurityIssue(
                'high',
                line,
                f"Include item #{item_num}: Local path '{local_path}' contains '..' (path traversal)",
                'include-local-path-traversal',
                "Use absolute paths starting with '/' or relative paths without '..'"
            ))

        # Note: Absolute paths starting with / are normal in GitLab CI local includes
        # They are relative to the repository root, so no additional warning needed

    def _check_template_include_security(self, inc: Dict[str, Any], line: int, item_num: int):
        """Check security for template includes"""

        template = inc.get('template', '')

        # GitLab templates are generally safe, but check for suspicious patterns
        # Templates from GitLab are in /lib/gitlab/ci/templates/

        # Warn about Auto-DevOps if enabled without review
        if 'Auto-DevOps' in template:
            self.issues.append(SecurityIssue(
                'low',
                line,
                f"Include item #{item_num}: Auto-DevOps template includes default security scanning",
                'include-template-auto-devops',
                "Review Auto-DevOps template configuration to ensure it matches your security requirements"
            ))

        # Check for deprecated templates (Security/ templates are deprecated, Jobs/ are current)
        deprecated_templates = [
            'Security/SAST.gitlab-ci.yml',
            'Security/Secret-Detection.gitlab-ci.yml',
            'Security/Dependency-Scanning.gitlab-ci.yml',
            'Security/License-Scanning.gitlab-ci.yml',
            'Security/Container-Scanning.gitlab-ci.yml',
            'Security/DAST.gitlab-ci.yml',
        ]
        for deprecated in deprecated_templates:
            if template == deprecated:
                self.issues.append(SecurityIssue(
                    'medium',
                    line,
                    f"Include item #{item_num}: Template '{template}' is deprecated",
                    'include-template-deprecated',
                    "Use Jobs/ templates instead (e.g., Jobs/SAST.gitlab-ci.yml)"
                ))

    def _check_artifact_security(self):
        """Check artifact security"""

        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            if 'artifacts' not in job:
                continue

            line = self._get_line(job_name)
            artifacts = job['artifacts']

            if not isinstance(artifacts, dict):
                continue

            # Check for overly broad artifact paths
            if 'paths' in artifacts:
                paths = artifacts['paths']
                if isinstance(paths, list):
                    for path in paths:
                        # Warn about including entire directories
                        if path in ['/', '.', './', '*', '**']:
                            self.issues.append(SecurityIssue(
                                'high',
                                line,
                                f"Job '{job_name}' includes overly broad artifact path '{path}'",
                                'artifact-broad-path',
                                "Specify explicit paths to avoid exposing sensitive files"
                            ))

                        # Warn about including common sensitive directories
                        if any(sensitive in path.lower() for sensitive in ['.git', '.env', 'secrets', 'credentials']):
                            self.issues.append(SecurityIssue(
                                'high',
                                line,
                                f"Job '{job_name}' may include sensitive files in artifacts: '{path}'",
                                'artifact-sensitive-path',
                                "Exclude sensitive directories from artifacts"
                            ))


    def _check_git_strategy_security(self):
        """Check Git strategy security"""

        # Check global variables for GIT_STRATEGY
        if 'variables' in self.config:
            self._check_git_strategy_in_variables('global', self.config['variables'], self._get_line('variables'))

        # Check default section
        if 'default' in self.config:
            default = self.config['default']
            if isinstance(default, dict) and 'variables' in default:
                self._check_git_strategy_in_variables('default', default['variables'], self._get_line('default'))

        # Check per-job Git strategies
        for job_name, job in self.config.items():
            if not self._is_job(job_name):
                continue

            line = self._get_line(job_name)

            # Check job variables
            if 'variables' in job:
                self._check_git_strategy_in_variables(f"job '{job_name}'", job['variables'], line)

    def _check_git_strategy_in_variables(self, context: str, variables: Any, line: int):
        """Check GIT_STRATEGY variable for security implications"""

        if not isinstance(variables, dict):
            return

        if 'GIT_STRATEGY' in variables:
            strategy = variables['GIT_STRATEGY']

            # Warn about 'none' strategy with external scripts
            if strategy == 'none':
                self.issues.append(SecurityIssue(
                    'medium',
                    line,
                    f"Git strategy 'none' in {context} may execute untrusted code",
                    'git-strategy-none',
                    "Strategy 'none' skips repository cloning; ensure scripts come from trusted sources"
                ))

            # Warn about 'fetch' without depth limit
            if strategy == 'fetch':
                if 'GIT_DEPTH' not in variables:
                    self.issues.append(SecurityIssue(
                        'low',
                        line,
                        f"Git strategy 'fetch' in {context} without GIT_DEPTH may be inefficient",
                        'git-strategy-fetch-no-depth',
                        "Consider setting GIT_DEPTH to limit history and improve performance"
                    ))

def main():
    """Main entry point"""

    if len(sys.argv) < 2:
        print("Usage: check_security.py <gitlab-ci.yml> [--json]", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]
    json_output = '--json' in sys.argv

    scanner = SecurityScanner(file_path)
    issues = scanner.scan()

    # Group by severity
    by_severity = defaultdict(list)
    for issue in issues:
        by_severity[issue.severity].append(issue)

    # Determine if scan passed (no critical or high issues)
    has_critical_or_high = bool(by_severity.get('critical') or by_severity.get('high'))

    if json_output:
        # Output JSON format
        result = {
            'validator': 'security',
            'file': file_path,
            'success': not has_critical_or_high,
            'issues': [issue.to_dict() for issue in issues],
            'summary': {
                'critical': len(by_severity.get('critical', [])),
                'high': len(by_severity.get('high', [])),
                'medium': len(by_severity.get('medium', [])),
                'low': len(by_severity.get('low', []))
            }
        }
        print(json.dumps(result, indent=2))
    else:
        # Output formatted text
        if issues:
            print(f"\n{'='*80}")
            print(f"Security Scan for: {file_path}")
            print(f"{'='*80}\n")

            # Print in severity order
            for severity in ['critical', 'high', 'medium', 'low']:
                if severity in by_severity:
                    print(f"\n{severity.upper()} SEVERITY ({len(by_severity[severity])}):")
                    print("-" * 80)
                    for issue in by_severity[severity]:
                        print(f"  {issue}\n")

            print(f"{'='*80}")
            print(f"Summary: "
                  f"{len(by_severity.get('critical', []))} critical, "
                  f"{len(by_severity.get('high', []))} high, "
                  f"{len(by_severity.get('medium', []))} medium, "
                  f"{len(by_severity.get('low', []))} low")
            print(f"{'='*80}\n")

            # Exit with error if critical or high issues found
            if has_critical_or_high:
                print("❌ Security scan found critical or high severity issues")
            else:
                print("⚠️  Security scan found medium/low severity issues")
        else:
            print(f"✓ No security issues found in {file_path}")

    sys.exit(1 if has_critical_or_high else 0)


if __name__ == '__main__':
    main()
