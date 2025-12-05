#!/usr/bin/env python3
"""
Azure Pipelines Security Scanner

This script scans Azure Pipelines YAML files for security issues:
- Hardcoded secrets and credentials
- Task version security
- Container image security
- Dangerous script patterns
- Service connection security
- Secrets exposure in logs
- Script injection vulnerabilities
"""

import sys
import yaml
import re
from pathlib import Path
from typing import Dict, List, Any, Pattern


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


class SecurityScanner:
    """Scans Azure Pipelines files for security issues"""

    # Patterns for detecting hardcoded secrets
    SECRET_PATTERNS = [
        (re.compile(r'(?i)(password|passwd|pwd)\s*[:=]\s*["\']?(?!\$\()[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:,.<>?/\\|`~]{8,}["\']?'), 'hardcoded-password'),
        (re.compile(r'(?i)(api[_-]?key|apikey)\s*[:=]\s*["\']?(?!\$\()[a-zA-Z0-9_\-]{16,}["\']?'), 'hardcoded-api-key'),
        (re.compile(r'(?i)(secret|token|access[_-]?key)\s*[:=]\s*["\']?(?!\$\()[a-zA-Z0-9_\-]{16,}["\']?'), 'hardcoded-secret'),
        (re.compile(r'(?i)(aws_access_key_id|aws_secret_access_key)\s*[:=]\s*["\']?(?!\$\()[A-Z0-9]{16,}["\']?'), 'hardcoded-aws-credentials'),
        (re.compile(r'(?i)bearer\s+(?!\$\()[a-zA-Z0-9_\-\.]{20,}'), 'hardcoded-bearer-token'),
        (re.compile(r'-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----'), 'hardcoded-private-key'),
        (re.compile(r'(?i)(client_secret|client_id)\s*[:=]\s*["\']?(?!\$\()[a-zA-Z0-9_\-]{16,}["\']?'), 'hardcoded-oauth-credentials'),
        (re.compile(r'(?i)(database_url|connection_?string)\s*[:=]\s*["\']?(?!\$\()(?:postgresql|mysql|mongodb|sqlserver)://[^"\'\s]+["\']?'), 'hardcoded-connection-string'),
        (re.compile(r'(?i)(subscription[_-]?id|tenant[_-]?id)\s*[:=]\s*["\']?(?!\$\()[a-f0-9\-]{36}["\']?'), 'hardcoded-azure-ids'),
    ]

    # Dangerous script patterns
    DANGEROUS_PATTERNS = [
        (re.compile(r'curl\s+[^|]*\|\s*(bash|sh|pwsh|powershell)'), 'curl-pipe-shell', 'Download and verify scripts before execution'),
        (re.compile(r'wget\s+[^|]*\|\s*(bash|sh|pwsh|powershell)'), 'wget-pipe-shell', 'Download and verify scripts before execution'),
        (re.compile(r'Invoke-WebRequest.*\|\s*(Invoke-Expression|iex)'), 'invoke-web-pipe-iex', 'Download and verify scripts before execution'),
        (re.compile(r'(?<!\#)\s*eval\s+[\$\(]'), 'eval-command', 'Avoid using eval with variables to prevent code injection'),
        (re.compile(r'chmod\s+777'), 'chmod-777', 'Avoid overly permissive file permissions (use 755 or 644)'),
        (re.compile(r'--insecure|-k\s'), 'insecure-ssl', 'Do not disable SSL/TLS verification'),
        (re.compile(r'--no-verify'), 'skip-verification', 'Do not skip verification checks'),
        (re.compile(r'git\s+config\s+--global\s+http\.sslVerify\s+false'), 'git-disable-ssl', 'Do not disable Git SSL verification'),
    ]

    # Patterns that might leak secrets in logs
    SECRET_EXPOSURE_PATTERNS = [
        re.compile(r'(?i)echo\s+.*\$\((PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'(?i)Write-Host.*\$\((PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'(?i)console\.log.*\$\((PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'(?i)print.*\$\((PASSWORD|SECRET|TOKEN|KEY|CREDENTIAL)'),
        re.compile(r'(?i)(echo|print|Write-Host|console\.log).*\$\(variables\..*(?:password|secret|token|key)'),
    ]

    # Container image security patterns
    INSECURE_IMAGE_PATTERNS = [
        re.compile(r':\s*latest\s*$'),  # Using :latest tag
        re.compile(r'(?i)FROM\s+[a-z0-9\-\./_]+:latest'),  # Dockerfile FROM with latest
    ]

    def __init__(self, file_path: str):
        self.file_path = Path(file_path)
        self.issues: List[SecurityIssue] = []
        self.config: Dict[str, Any] = {}
        self.raw_content: str = ""
        self.line_map: Dict[str, int] = {}
        # Track reported issues to avoid duplicates (line_number, rule) pairs
        self.reported_secrets: set = set()

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
        self._check_container_security()
        self._check_task_security()
        self._check_service_connections()
        self._check_checkout_security()
        self._check_variable_security()

        return self.issues

    def _build_line_map(self):
        """Build comprehensive line number map"""
        self.raw_lines = self.raw_content.split('\n')
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

    def _check_hardcoded_secrets(self):
        """Check for hardcoded secrets and credentials"""

        # Check in variables first (more specific, better context)
        variables = self.config.get('variables', {})
        if isinstance(variables, dict):
            for var_name, var_value in variables.items():
                if isinstance(var_value, str):
                    for pattern, rule in self.SECRET_PATTERNS:
                        # Check variable name and value
                        check_str = f"{var_name}: {var_value}"
                        if pattern.search(check_str):
                            line_num = self._get_line(var_name)
                            # Track this finding to avoid duplicates
                            finding_key = (line_num, rule)
                            if finding_key not in self.reported_secrets:
                                self.reported_secrets.add(finding_key)
                                self.issues.append(SecurityIssue(
                                    'high', line_num,
                                    f"Variable '{var_name}' may contain hardcoded secret",
                                    rule,
                                    "Use Azure DevOps variable groups with secret variables or Azure Key Vault"
                                ))
                            break

        # Check in raw content (scripts, etc.) - skip lines already reported
        lines = self.raw_content.split('\n')
        for line_num, line in enumerate(lines, 1):
            # Skip comments and variable references
            if '#' in line:
                line = line[:line.index('#')]

            # Skip if it's a variable reference like $(secretVar)
            if re.search(r'\$\([^)]+\)', line):
                continue

            for pattern, rule in self.SECRET_PATTERNS:
                if pattern.search(line):
                    # Check if this line+rule was already reported
                    finding_key = (line_num, rule)
                    if finding_key not in self.reported_secrets:
                        self.reported_secrets.add(finding_key)
                        self.issues.append(SecurityIssue(
                            'high', line_num,
                            f"Potential hardcoded secret detected",
                            rule,
                            "Use secret variables or Azure Key Vault instead of hardcoding secrets"
                        ))
                    break

    def _check_dangerous_scripts(self):
        """Check for dangerous script patterns"""

        def check_script(script_content: str, context: str, script_key: str):
            for pattern, rule, remediation in self.DANGEROUS_PATTERNS:
                match = pattern.search(script_content)
                if match:
                    # Find line number by searching for script content
                    line_num = self._find_line_containing(match.group(0)[:30]) or self._find_line_containing(script_key + ':')
                    self.issues.append(SecurityIssue(
                        'high', line_num,
                        f"Dangerous pattern detected in {context}",
                        rule,
                        remediation
                    ))

        # Check all script steps
        def process_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict):
                    for script_key in ['script', 'bash', 'pwsh', 'powershell']:
                        if script_key in step:
                            script_content = str(step[script_key])
                            check_script(script_content, f"{context} ({script_key})", script_key)

        self._traverse_steps(process_steps)

    def _check_secret_exposure(self):
        """Check for potential secret exposure in logs"""

        def process_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict):
                    for script_key in ['script', 'bash', 'pwsh', 'powershell']:
                        if script_key in step:
                            script_content = str(step[script_key])
                            for pattern in self.SECRET_EXPOSURE_PATTERNS:
                                if pattern.search(script_content):
                                    self.issues.append(SecurityIssue(
                                        'medium', 0,
                                        f"Potential secret exposure in logs in {context}",
                                        'secret-in-logs',
                                        "Use ##vso[task.setvariable variable=name;issecret=true] or avoid logging secrets"
                                    ))
                                    break

        self._traverse_steps(process_steps)

    def _check_container_security(self):
        """Check container image security"""

        # Check container images in resources
        resources = self.config.get('resources', {})
        if 'containers' in resources:
            for container in resources['containers']:
                if isinstance(container, dict) and 'image' in container:
                    image = container['image']
                    if isinstance(image, str):
                        for pattern in self.INSECURE_IMAGE_PATTERNS:
                            if pattern.search(image):
                                container_name = container.get('container', 'unknown')
                                self.issues.append(SecurityIssue(
                                    'medium', self._get_line(container_name),
                                    f"Container '{container_name}' uses ':latest' tag",
                                    'container-latest-tag',
                                    "Pin container images to specific versions or SHA digests"
                                ))
                                break

        # Check container at job level
        def check_job_containers(jobs: List[Any]):
            for job in jobs:
                if isinstance(job, dict) and 'container' in job:
                    container = job['container']
                    if isinstance(container, str):
                        for pattern in self.INSECURE_IMAGE_PATTERNS:
                            if pattern.search(container):
                                job_name = job.get('job') or job.get('deployment', 'unknown')
                                self.issues.append(SecurityIssue(
                                    'medium', self._get_line(job_name),
                                    f"Job '{job_name}' uses container with ':latest' tag",
                                    'container-latest-tag',
                                    "Pin container images to specific versions or SHA digests"
                                ))
                                break
                    elif isinstance(container, dict) and 'image' in container:
                        for pattern in self.INSECURE_IMAGE_PATTERNS:
                            if pattern.search(container['image']):
                                job_name = job.get('job') or job.get('deployment', 'unknown')
                                self.issues.append(SecurityIssue(
                                    'medium', self._get_line(job_name),
                                    f"Job '{job_name}' uses container with ':latest' tag",
                                    'container-latest-tag',
                                    "Pin container images to specific versions or SHA digests"
                                ))
                                break

        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    check_job_containers(stage.get('jobs', []))

        if 'jobs' in self.config:
            check_job_containers(self.config['jobs'])

    def _check_task_security(self):
        """Check task version security"""

        def process_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict) and 'task' in step:
                    task = step['task']
                    if isinstance(task, str):
                        line_num = self._find_line_containing(f"task: {task}") or self._find_line_containing(task)
                        # Check for missing version
                        if '@' not in task:
                            self.issues.append(SecurityIssue(
                                'medium', line_num,
                                f"Task '{task}' in {context} missing version (security risk)",
                                'task-no-version',
                                "Always specify task version to prevent unexpected changes"
                            ))

                        # Warn about very old tasks (@1 for critical tasks)
                        if any(critical in task for critical in ['AzureCLI@', 'AzurePowerShell@', 'Kubernetes@']):
                            if '@1' in task:
                                self.issues.append(SecurityIssue(
                                    'low', line_num,
                                    f"Task '{task}' in {context} uses older version",
                                    'task-old-version',
                                    "Consider updating to latest major version for security fixes"
                                ))

        self._traverse_steps(process_steps)

    def _check_service_connections(self):
        """Check for hardcoded service connections"""

        # Check for Azure service connections in tasks
        def process_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict) and 'inputs' in step:
                    inputs = step['inputs']
                    if isinstance(inputs, dict):
                        # Check common service connection inputs
                        for key in ['azureSubscription', 'connectedServiceName', 'dockerRegistryServiceConnection']:
                            if key in inputs:
                                value = str(inputs[key])
                                # Check if it looks like a GUID (hardcoded)
                                if re.match(r'^[a-f0-9\-]{36}$', value):
                                    self.issues.append(SecurityIssue(
                                        'low', 0,
                                        f"Task in {context} may use hardcoded service connection ID",
                                        'hardcoded-service-connection',
                                        "Use service connection names instead of IDs for portability"
                                    ))

        self._traverse_steps(process_steps)

    def _check_checkout_security(self):
        """Check checkout security settings"""

        def process_steps(steps: List[Any], context: str):
            for step in steps:
                if isinstance(step, dict) and 'checkout' in step:
                    checkout = step['checkout']
                    # Check if clean is disabled
                    if isinstance(step, dict) and 'clean' in step:
                        if step['clean'] == False or step['clean'] == 'false':
                            self.issues.append(SecurityIssue(
                                'low', 0,
                                f"Checkout in {context} has clean disabled",
                                'checkout-no-clean',
                                "Enable clean checkout to prevent contamination from previous builds"
                            ))

                    # Check for submodules without verification
                    if isinstance(step, dict) and 'submodules' in step:
                        if step.get('submodules') == 'recursive' and not step.get('fetchDepth'):
                            self.issues.append(SecurityIssue(
                                'low', 0,
                                f"Checkout in {context} uses recursive submodules without depth limit",
                                'checkout-submodule-risk',
                                "Consider setting fetchDepth to limit exposure"
                            ))

        self._traverse_steps(process_steps)

    def _check_variable_security(self):
        """Check variable security configuration"""

        variables = self.config.get('variables', [])

        if isinstance(variables, list):
            for var in variables:
                if isinstance(var, dict) and 'name' in var and 'value' in var:
                    var_name = var['name']
                    # Check if sensitive variable is not marked as secret
                    if any(keyword in var_name.lower() for keyword in ['password', 'secret', 'token', 'key', 'credential']):
                        if not var.get('isSecret'):
                            self.issues.append(SecurityIssue(
                                'medium', self._get_line(var_name),
                                f"Variable '{var_name}' appears sensitive but not marked as secret",
                                'variable-not-secret',
                                "Add 'isSecret: true' to sensitive variables or use variable groups"
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

                    # Deployment strategy steps
                    if 'strategy' in job and isinstance(job['strategy'], dict):
                        for strategy_type in ['runOnce', 'rolling', 'canary']:
                            if strategy_type in job['strategy']:
                                strategy = job['strategy'][strategy_type]
                                if isinstance(strategy, dict):
                                    for phase in ['preDeploy', 'deploy', 'routeTraffic', 'postRouteTraffic', 'on']:
                                        if phase in strategy:
                                            phase_data = strategy[phase]
                                            if isinstance(phase_data, dict) and 'steps' in phase_data:
                                                process_steps(phase_data['steps'], f"job '{job_name}' {strategy_type}.{phase}")

        # Steps in stages
        if 'stages' in self.config:
            for stage in self.config['stages']:
                if isinstance(stage, dict):
                    for job in stage.get('jobs', []):
                        if isinstance(job, dict):
                            job_name = job.get('job') or job.get('deployment', 'unknown')
                            if 'steps' in job:
                                process_steps(job['steps'], f"job '{job_name}'")

                            # Deployment strategy steps
                            if 'strategy' in job and isinstance(job['strategy'], dict):
                                for strategy_type in ['runOnce', 'rolling', 'canary']:
                                    if strategy_type in job['strategy']:
                                        strategy = job['strategy'][strategy_type]
                                        if isinstance(strategy, dict):
                                            for phase in ['preDeploy', 'deploy', 'routeTraffic', 'postRouteTraffic', 'on']:
                                                if phase in strategy:
                                                    phase_data = strategy[phase]
                                                    if isinstance(phase_data, dict) and 'steps' in phase_data:
                                                        process_steps(phase_data['steps'], f"job '{job_name}' {strategy_type}.{phase}")


def main():
    if len(sys.argv) < 2:
        print("Usage: check_security.py <azure-pipelines.yml>", file=sys.stderr)
        sys.exit(1)

    scanner = SecurityScanner(sys.argv[1])
    issues = scanner.scan()

    if issues:
        # Group by severity
        critical = [i for i in issues if i.severity == 'critical']
        high = [i for i in issues if i.severity == 'high']
        medium = [i for i in issues if i.severity == 'medium']
        low = [i for i in issues if i.severity == 'low']

        for severity_list, name in [(critical, 'CRITICAL'), (high, 'HIGH'), (medium, 'MEDIUM'), (low, 'LOW')]:
            if severity_list:
                print(f"{name} SEVERITY ({len(severity_list)}):")
                print("─" * 80)
                for issue in severity_list:
                    print(f"  {issue}\n")

        if critical or high:
            print("✗ Security scan failed - critical/high severity issues found")
            sys.exit(1)
        else:
            print("⚠ Security scan found warnings - low/medium severity issues found")
            sys.exit(2)  # Exit code 2 for warnings (distinct from passed)
    else:
        print("✓ Security scan passed - no issues found")
        sys.exit(0)


if __name__ == '__main__':
    main()
