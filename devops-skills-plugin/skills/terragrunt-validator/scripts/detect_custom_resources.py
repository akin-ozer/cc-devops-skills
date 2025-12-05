#!/usr/bin/env python3
"""
Terragrunt Custom Resource Detector

This script analyzes Terragrunt and Terraform configurations to identify:
- Custom Terraform providers (non-HashiCorp official)
- Custom modules (local or remote)
- Provider versions used

Outputs a report that can be used to guide documentation lookup via WebSearch or Context7.
"""

import os
import re
import json
import argparse
import sys
from pathlib import Path
from typing import Dict, List, Set, Tuple
from collections import defaultdict


# Known official HashiCorp providers (comprehensive list)
OFFICIAL_PROVIDERS = {
    # Core providers
    'hashicorp/aws', 'hashicorp/azurerm', 'hashicorp/google', 'hashicorp/google-beta',
    'hashicorp/kubernetes', 'hashicorp/kubernetes-alpha',

    # Utility providers
    'hashicorp/null', 'hashicorp/random', 'hashicorp/local', 'hashicorp/template',
    'hashicorp/external', 'hashicorp/archive', 'hashicorp/http', 'hashicorp/time',
    'hashicorp/tls', 'hashicorp/cloudinit',

    # HashiCorp products
    'hashicorp/vault', 'hashicorp/consul', 'hashicorp/nomad', 'hashicorp/tfe',
    'hashicorp/hcp', 'hashicorp/boundary', 'hashicorp/waypoint',

    # Kubernetes ecosystem
    'hashicorp/helm',

    # Cloud providers (additional)
    'hashicorp/azuread', 'hashicorp/azurestack', 'hashicorp/googleworkspace',
    'hashicorp/opc', 'hashicorp/oraclepaas',

    # Infrastructure providers
    'hashicorp/vsphere', 'hashicorp/dns', 'hashicorp/ad',

    # Also accept short forms (without hashicorp/ prefix)
    'aws', 'azurerm', 'google', 'google-beta', 'kubernetes', 'null', 'random',
    'local', 'template', 'external', 'archive', 'http', 'time', 'tls',
    'cloudinit', 'vault', 'consul', 'nomad', 'tfe', 'hcp', 'boundary',
    'waypoint', 'helm', 'azuread', 'azurestack', 'googleworkspace', 'vsphere',
    'dns', 'ad', 'opc', 'oraclepaas',

    # OpenTofu registry format
    'registry.opentofu.org/hashicorp/aws',
    'registry.opentofu.org/hashicorp/azurerm',
    'registry.opentofu.org/hashicorp/google',
    'registry.opentofu.org/hashicorp/kubernetes',
}


class ResourceDetector:
    def __init__(self, target_dir: str):
        self.target_dir = Path(target_dir)
        self.custom_providers = defaultdict(set)
        self.custom_modules = defaultdict(list)
        self.terragrunt_configs = []

    def find_hcl_files(self) -> List[Path]:
        """Find all .hcl and .tf files in the target directory."""
        hcl_files = []
        for ext in ['*.hcl', '*.tf']:
            hcl_files.extend(self.target_dir.rglob(ext))
        return hcl_files

    def extract_providers(self, content: str, filepath: str) -> None:
        """Extract provider configurations from HCL content."""
        # Find required_providers blocks with balanced braces
        start_pattern = r'required_providers\s*{'
        matches = list(re.finditer(start_pattern, content, re.MULTILINE))

        for match in matches:
            # Extract the full block with balanced braces
            start_pos = match.end() - 1  # Position of opening brace
            block_content = self._extract_balanced_braces(content, start_pos)

            # Extract individual provider declarations
            # Format: provider_name = { source = "org/provider", version = "x.y.z" }
            provider_decl_pattern = r'(\w+)\s*=\s*{[^}]*source\s*=\s*"([^"]+)"[^}]*version\s*=\s*"([^"]+)"'
            for provider_match in re.finditer(provider_decl_pattern, block_content):
                provider_name = provider_match.group(1)
                provider_source = provider_match.group(2)
                provider_version = provider_match.group(3)

                # Check if it's a custom provider (not official HashiCorp)
                if provider_source not in OFFICIAL_PROVIDERS:
                    self.custom_providers[provider_source].add(provider_version)

        # Also look for standalone provider blocks
        standalone_provider_pattern = r'provider\s+"(\w+)"\s*{([^}]+)}'
        for match in re.finditer(standalone_provider_pattern, content, re.MULTILINE | re.DOTALL):
            provider_name = match.group(1)
            # Try to find version in the block
            version_match = re.search(r'version\s*=\s*"([^"]+)"', match.group(2))
            if version_match:
                version = version_match.group(1)
                # Assume non-official if not in common list
                potential_source = f"hashicorp/{provider_name}"
                if potential_source not in OFFICIAL_PROVIDERS:
                    self.custom_providers[provider_name].add(version)

        # Check for providers in Terragrunt generate blocks
        # Format: generate "name" { ... contents = <<EOF ... required_providers { ... } EOF }
        generate_pattern = r'generate\s+"[^"]+"\s*{[^}]*contents\s*=\s*<<EOF(.*?)EOF'
        for match in re.finditer(generate_pattern, content, re.MULTILINE | re.DOTALL):
            generated_content = match.group(1)
            # Recursively extract providers from generated content
            self._extract_providers_from_block(generated_content)

    def _extract_providers_from_block(self, content: str) -> None:
        """Helper to extract providers from a content block."""
        # Find required_providers blocks with nested braces
        # Use a simple approach: find the start, then match balanced braces
        start_pattern = r'required_providers\s*{'
        matches = list(re.finditer(start_pattern, content, re.MULTILINE))

        for match in matches:
            # Extract the full block with balanced braces
            start_pos = match.end() - 1  # Position of opening brace
            block_content = self._extract_balanced_braces(content, start_pos)

            # Now extract individual provider declarations
            provider_decl_pattern = r'(\w+)\s*=\s*{[^}]*source\s*=\s*"([^"]+)"[^}]*version\s*=\s*"([^"]+)"'
            for provider_match in re.finditer(provider_decl_pattern, block_content):
                provider_name = provider_match.group(1)
                provider_source = provider_match.group(2)
                provider_version = provider_match.group(3)

                if provider_source not in OFFICIAL_PROVIDERS:
                    self.custom_providers[provider_source].add(provider_version)

    def _extract_balanced_braces(self, content: str, start_pos: int) -> str:
        """Extract content within balanced braces starting from start_pos."""
        if start_pos >= len(content) or content[start_pos] != '{':
            return ""

        depth = 0
        for i in range(start_pos, len(content)):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
                if depth == 0:
                    return content[start_pos+1:i]

        return content[start_pos+1:]  # Return rest if unbalanced

    def extract_modules(self, content: str, filepath: str) -> None:
        """Extract module configurations from HCL content."""
        # Pattern for module blocks
        module_pattern = r'module\s+"([^"]+)"\s*{([^}]+)}'
        matches = re.finditer(module_pattern, content, re.MULTILINE | re.DOTALL)

        for match in matches:
            module_name = match.group(1)
            module_content = match.group(2)

            # Extract source
            source_match = re.search(r'source\s*=\s*"([^"]+)"', module_content)
            if not source_match:
                continue

            source = source_match.group(1)

            # Extract version if available
            version_match = re.search(r'version\s*=\s*"([^"]+)"', module_content)
            version = version_match.group(1) if version_match else "latest"

            # Categorize the module
            module_info = {
                'name': module_name,
                'source': source,
                'version': version,
                'file': str(filepath),
                'type': self._categorize_module_source(source)
            }

            # Only add if it's a custom or remote module (not local relative paths to same repo)
            if module_info['type'] in ['git', 'registry', 'http', 'custom']:
                self.custom_modules[source].append(module_info)

        # Also check for Terragrunt-style terraform blocks
        # Format: terraform { source = "tfr://..." }
        terragrunt_module_pattern = r'terraform\s*{[^}]*source\s*=\s*"([^"]+)"'
        for match in re.finditer(terragrunt_module_pattern, content, re.MULTILINE | re.DOTALL):
            source = match.group(1)

            # Parse version from source string (e.g., tfr:///.../module?version=1.0.0)
            version = "latest"
            version_in_source = re.search(r'[?&]version=([^&"]+)', source)
            if version_in_source:
                version = version_in_source.group(1)

            # Parse ref from git sources (e.g., git::...?ref=v1.0.0)
            ref_in_source = re.search(r'[?&]ref=([^&"]+)', source)
            if ref_in_source:
                version = ref_in_source.group(1)

            # Clean the source for categorization
            clean_source = re.sub(r'\?.*$', '', source)

            module_info = {
                'name': Path(filepath).parent.name,  # Use directory name as module name
                'source': clean_source,
                'version': version,
                'file': str(filepath),
                'type': self._categorize_module_source(clean_source)
            }

            if module_info['type'] in ['git', 'registry', 'http', 'custom', 'terragrunt']:
                self.custom_modules[clean_source].append(module_info)

    def _categorize_module_source(self, source: str) -> str:
        """Categorize the module source type."""
        if source.startswith('./') or source.startswith('../'):
            return 'local'
        elif source.startswith('tfr:///'):
            # Terragrunt registry format
            return 'terragrunt'
        elif source.startswith('git::') or 'github.com' in source or 'gitlab.com' in source:
            return 'git'
        elif source.startswith('http://') or source.startswith('https://'):
            return 'http'
        elif '/' in source and not source.startswith('.'):
            # Check if this looks like a provider source (org/name) vs module (org/name/provider)
            # Provider sources have exactly 2 path components (e.g., hashicorp/aws, datadog/datadog)
            # Module sources have 3+ components (e.g., terraform-aws-modules/vpc/aws)
            parts = source.split('/')
            if len(parts) == 2:
                # This looks like a provider source, not a module
                # Filter these out as they're detected separately in extract_providers
                return 'provider'
            else:
                # Likely Terraform Registry format (e.g., terraform-aws-modules/vpc/aws)
                return 'registry'
        else:
            return 'custom'

    def analyze_directory(self) -> None:
        """Analyze all HCL files in the target directory."""
        hcl_files = self.find_hcl_files()

        if not hcl_files:
            print(f"No .hcl or .tf files found in {self.target_dir}", file=sys.stderr)
            return

        for filepath in hcl_files:
            try:
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()
                    self.extract_providers(content, filepath)
                    self.extract_modules(content, filepath)
            except Exception as e:
                print(f"Error reading {filepath}: {e}", file=sys.stderr)

    def generate_report(self, output_format: str = 'text') -> str:
        """Generate a report of custom resources found."""
        if output_format == 'json':
            return self._generate_json_report()
        else:
            return self._generate_text_report()

    def _generate_json_report(self) -> str:
        """Generate JSON format report."""
        report = {
            'custom_providers': {
                provider: list(versions)
                for provider, versions in self.custom_providers.items()
            },
            'custom_modules': {
                source: modules
                for source, modules in self.custom_modules.items()
            }
        }
        return json.dumps(report, indent=2)

    def _generate_text_report(self) -> str:
        """Generate human-readable text report."""
        lines = []
        lines.append("=" * 80)
        lines.append("Terragrunt Custom Resource Detection Report")
        lines.append("=" * 80)
        lines.append("")

        # Custom Providers Section
        if self.custom_providers:
            lines.append("CUSTOM PROVIDERS DETECTED:")
            lines.append("-" * 80)
            for provider, versions in sorted(self.custom_providers.items()):
                lines.append(f"\nProvider: {provider}")
                lines.append(f"  Versions: {', '.join(sorted(versions))}")
                lines.append(f"  → Action: Search for '{provider} terraform provider documentation'")
                lines.append(f"            or use Context7 with library ID: /{provider}")
            lines.append("")
        else:
            lines.append("CUSTOM PROVIDERS: None detected")
            lines.append("")

        # Custom Modules Section
        if self.custom_modules:
            lines.append("CUSTOM MODULES DETECTED:")
            lines.append("-" * 80)
            for source, modules in sorted(self.custom_modules.items()):
                module_info = modules[0]  # Take first occurrence for details
                lines.append(f"\nModule Source: {source}")
                lines.append(f"  Type: {module_info['type']}")
                lines.append(f"  Version: {module_info['version']}")
                lines.append(f"  Used in: {module_info['file']}")
                lines.append(f"  Used {len(modules)} time(s)")

                # Provide search guidance based on module type
                if module_info['type'] == 'git':
                    lines.append(f"  → Action: Search for '{source} documentation'")
                elif module_info['type'] == 'registry' or module_info['type'] == 'terragrunt':
                    # Clean up tfr:/// prefix for registry lookup
                    clean_source = source.replace('tfr:///', '')
                    lines.append(f"  → Action: Search for 'terraform {clean_source} module documentation'")
                    lines.append(f"            or visit https://registry.terraform.io/modules/{clean_source}")
                else:
                    lines.append(f"  → Action: Search for documentation related to this module source")
            lines.append("")
        else:
            lines.append("CUSTOM MODULES: None detected")
            lines.append("")

        # Summary
        lines.append("=" * 80)
        lines.append("SUMMARY")
        lines.append("=" * 80)
        lines.append(f"Custom Providers: {len(self.custom_providers)}")
        lines.append(f"Custom Modules: {len(self.custom_modules)}")
        lines.append("")

        if self.custom_providers or self.custom_modules:
            lines.append("RECOMMENDED ACTIONS:")
            lines.append("1. Use WebSearch to look up documentation for each custom resource")
            lines.append("2. Pay attention to version compatibility")
            lines.append("3. Review provider/module documentation for required configuration")
            lines.append("4. Check for any known issues or breaking changes")
        else:
            lines.append("No custom providers or modules detected.")
            lines.append("All resources appear to be standard HashiCorp providers or local modules.")
        lines.append("")

        return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description='Detect custom providers and modules in Terragrunt/Terraform configurations'
    )
    parser.add_argument(
        'directory',
        nargs='?',
        default='.',
        help='Directory to analyze (default: current directory)'
    )
    parser.add_argument(
        '--format',
        choices=['text', 'json'],
        default='text',
        help='Output format (default: text)'
    )

    args = parser.parse_args()

    detector = ResourceDetector(args.directory)
    detector.analyze_directory()
    report = detector.generate_report(args.format)
    print(report)


if __name__ == '__main__':
    main()
