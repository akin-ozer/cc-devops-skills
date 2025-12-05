#!/usr/bin/env python3
"""
Terraform Configuration Parser

Extracts provider, module, and resource information from Terraform files (.tf)
to facilitate version-aware documentation lookup and validation.

This script uses python-hcl2 for proper HCL parsing instead of regex,
which handles nested blocks, heredocs, and complex types correctly.

Usage:
    python extract_tf_info.py <path-to-tf-file-or-directory>
    python extract_tf_info.py main.tf
    python extract_tf_info.py ./terraform/modules/

Output:
    JSON structure containing:
    - providers: List of required providers with versions
    - modules: List of module sources with versions
    - resources: List of resources by type
    - data_sources: List of data sources
    - variables: List of input variables
    - outputs: List of outputs
    - locals: List of local value names

Requirements:
    pip install python-hcl2
"""

import json
import os
import sys
from pathlib import Path
from typing import Any

# Check for python-hcl2 and provide helpful error message if missing
try:
    import hcl2
    HCL2_AVAILABLE = True
except ImportError:
    HCL2_AVAILABLE = False


class TerraformParser:
    """Parse Terraform HCL files to extract configuration metadata."""

    def __init__(self):
        self.providers: list[dict[str, Any]] = []
        self.modules: list[dict[str, Any]] = []
        self.resources: list[dict[str, Any]] = []
        self.data_sources: list[dict[str, Any]] = []
        self.variables: list[dict[str, Any]] = []
        self.outputs: list[dict[str, Any]] = []
        self.locals: list[dict[str, Any]] = []
        self.terraform_settings: dict[str, Any] = {}
        self._seen_providers: set[tuple] = set()

    def parse_file(self, filepath: str) -> None:
        """Parse a single Terraform file using python-hcl2."""
        if not HCL2_AVAILABLE:
            print("Error: python-hcl2 is required but not installed.", file=sys.stderr)
            print("Install it with: pip install python-hcl2", file=sys.stderr)
            sys.exit(1)

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                parsed = hcl2.load(f)

            self._extract_terraform_block(parsed, filepath)
            self._extract_providers(parsed, filepath)
            self._extract_modules(parsed, filepath)
            self._extract_resources(parsed, filepath)
            self._extract_data_sources(parsed, filepath)
            self._extract_variables(parsed, filepath)
            self._extract_outputs(parsed, filepath)
            self._extract_locals(parsed, filepath)

        except hcl2.lark_parser.UnexpectedToken as e:
            print(f"HCL syntax error in {filepath}: {e}", file=sys.stderr)
        except Exception as e:
            print(f"Error parsing {filepath}: {e}", file=sys.stderr)

    def parse_directory(self, dirpath: str) -> None:
        """Parse all .tf files in a directory recursively."""
        path = Path(dirpath)

        if not path.exists():
            print(f"Error: Path {dirpath} does not exist", file=sys.stderr)
            return

        # Find all .tf files
        tf_files = list(path.rglob("*.tf"))

        if not tf_files:
            print(f"Warning: No .tf files found in {dirpath}", file=sys.stderr)
            return

        for tf_file in tf_files:
            # Skip .terraform directory
            if '.terraform' in str(tf_file):
                continue
            self.parse_file(str(tf_file))

    def _extract_terraform_block(self, parsed: dict, filepath: str) -> None:
        """Extract terraform settings including required_providers."""
        terraform_blocks = parsed.get('terraform', [])

        for block in terraform_blocks:
            # Extract required_version
            if 'required_version' in block:
                self.terraform_settings['required_version'] = block['required_version']

            # Extract required_providers
            required_providers = block.get('required_providers', [])
            for provider_block in required_providers:
                if isinstance(provider_block, dict):
                    for name, config in provider_block.items():
                        if isinstance(config, dict):
                            source = config.get('source')
                            version = config.get('version')
                        else:
                            source = None
                            version = config if isinstance(config, str) else None

                        provider_key = (name, source)
                        if provider_key not in self._seen_providers:
                            self._seen_providers.add(provider_key)
                            self.providers.append({
                                'name': name,
                                'source': source,
                                'version': version,
                                'file': filepath,
                                'type': 'required_provider'
                            })

            # Extract backend configuration
            backend = block.get('backend', [])
            if backend:
                for backend_config in backend:
                    if isinstance(backend_config, dict):
                        for backend_type, config in backend_config.items():
                            self.terraform_settings['backend'] = {
                                'type': backend_type,
                                'config': config
                            }

    def _extract_providers(self, parsed: dict, filepath: str) -> None:
        """Extract provider configuration blocks."""
        provider_blocks = parsed.get('provider', [])

        for block in provider_blocks:
            if isinstance(block, dict):
                for name, config in block.items():
                    if isinstance(config, dict):
                        alias = config.get('alias')
                        region = config.get('region')

                        self.providers.append({
                            'name': name,
                            'alias': alias,
                            'region': region,
                            'file': filepath,
                            'type': 'provider_config'
                        })

    def _extract_modules(self, parsed: dict, filepath: str) -> None:
        """Extract module blocks."""
        module_blocks = parsed.get('module', [])

        for block in module_blocks:
            if isinstance(block, dict):
                for name, config in block.items():
                    if isinstance(config, dict):
                        source = config.get('source')
                        version = config.get('version')

                        # Extract providers passed to module
                        providers = config.get('providers')

                        # Determine module type based on source
                        module_type = self._determine_module_type(source) if source else 'unknown'

                        self.modules.append({
                            'name': name,
                            'source': source,
                            'version': version,
                            'type': module_type,
                            'providers': providers,
                            'file': filepath
                        })

    def _determine_module_type(self, source: str) -> str:
        """Determine module type from source string."""
        if source.startswith('./') or source.startswith('../'):
            return 'local'
        elif source.startswith('git::') or source.startswith('git@'):
            return 'git'
        elif source.startswith('s3::') or source.startswith('gcs::'):
            return 'cloud_storage'
        elif source.startswith('https://') or source.startswith('http://'):
            return 'http'
        elif '/' in source and not source.startswith('.'):
            # Likely terraform registry format: namespace/name/provider
            return 'registry'
        else:
            return 'unknown'

    def _extract_resources(self, parsed: dict, filepath: str) -> None:
        """Extract resource blocks."""
        resource_blocks = parsed.get('resource', [])

        for block in resource_blocks:
            if isinstance(block, dict):
                for resource_type, instances in block.items():
                    if isinstance(instances, dict):
                        for resource_name, config in instances.items():
                            # Extract key attributes for analysis
                            count = config.get('count') if isinstance(config, dict) else None
                            for_each = config.get('for_each') if isinstance(config, dict) else None
                            depends_on = config.get('depends_on') if isinstance(config, dict) else None
                            lifecycle = config.get('lifecycle') if isinstance(config, dict) else None

                            self.resources.append({
                                'type': resource_type,
                                'name': resource_name,
                                'has_count': count is not None,
                                'has_for_each': for_each is not None,
                                'has_depends_on': depends_on is not None,
                                'has_lifecycle': lifecycle is not None,
                                'file': filepath
                            })

    def _extract_data_sources(self, parsed: dict, filepath: str) -> None:
        """Extract data source blocks."""
        data_blocks = parsed.get('data', [])

        for block in data_blocks:
            if isinstance(block, dict):
                for data_type, instances in block.items():
                    if isinstance(instances, dict):
                        for data_name, config in instances.items():
                            self.data_sources.append({
                                'type': data_type,
                                'name': data_name,
                                'file': filepath
                            })

    def _extract_variables(self, parsed: dict, filepath: str) -> None:
        """Extract variable declarations."""
        variable_blocks = parsed.get('variable', [])

        for block in variable_blocks:
            if isinstance(block, dict):
                for name, config in block.items():
                    if isinstance(config, dict):
                        var_type = config.get('type')
                        description = config.get('description')
                        default = config.get('default')
                        sensitive = config.get('sensitive', False)
                        nullable = config.get('nullable')
                        validation = config.get('validation')

                        # Convert type to string representation if it's a complex type
                        type_str = self._type_to_string(var_type)

                        self.variables.append({
                            'name': name,
                            'type': type_str,
                            'description': description,
                            'has_default': default is not None,
                            'sensitive': sensitive,
                            'nullable': nullable,
                            'has_validation': validation is not None,
                            'file': filepath
                        })

    def _type_to_string(self, type_value: Any) -> str | None:
        """Convert type expression to string representation."""
        if type_value is None:
            return None
        if isinstance(type_value, str):
            return type_value
        if isinstance(type_value, dict):
            # Handle complex types like object({...}) or map(string)
            return str(type_value)
        if isinstance(type_value, list):
            # Handle type expressions returned as lists
            return ''.join(str(t) for t in type_value)
        return str(type_value)

    def _extract_outputs(self, parsed: dict, filepath: str) -> None:
        """Extract output declarations."""
        output_blocks = parsed.get('output', [])

        for block in output_blocks:
            if isinstance(block, dict):
                for name, config in block.items():
                    if isinstance(config, dict):
                        description = config.get('description')
                        sensitive = config.get('sensitive', False)
                        depends_on = config.get('depends_on')

                        self.outputs.append({
                            'name': name,
                            'description': description,
                            'sensitive': sensitive,
                            'has_depends_on': depends_on is not None,
                            'file': filepath
                        })

    def _extract_locals(self, parsed: dict, filepath: str) -> None:
        """Extract local value definitions."""
        locals_blocks = parsed.get('locals', [])

        for block in locals_blocks:
            if isinstance(block, dict):
                for name in block.keys():
                    self.locals.append({
                        'name': name,
                        'file': filepath
                    })

    def to_dict(self) -> dict[str, Any]:
        """Convert parsed data to dictionary."""
        return {
            'terraform_settings': self.terraform_settings,
            'providers': self.providers,
            'modules': self.modules,
            'resources': self.resources,
            'data_sources': self.data_sources,
            'variables': self.variables,
            'outputs': self.outputs,
            'locals': self.locals,
            'summary': {
                'provider_count': len(self.providers),
                'module_count': len(self.modules),
                'resource_count': len(self.resources),
                'data_source_count': len(self.data_sources),
                'variable_count': len(self.variables),
                'output_count': len(self.outputs),
                'local_count': len(self.locals)
            }
        }

    def to_json(self, indent: int = 2) -> str:
        """Convert parsed data to JSON string."""
        return json.dumps(self.to_dict(), indent=indent, default=str)


def check_dependencies() -> bool:
    """Check if required dependencies are installed."""
    if not HCL2_AVAILABLE:
        print("Error: python-hcl2 is required but not installed.", file=sys.stderr)
        print("", file=sys.stderr)
        print("Install it with:", file=sys.stderr)
        print("  pip install python-hcl2", file=sys.stderr)
        print("", file=sys.stderr)
        print("Or in a virtual environment:", file=sys.stderr)
        print("  python -m venv venv", file=sys.stderr)
        print("  source venv/bin/activate", file=sys.stderr)
        print("  pip install python-hcl2", file=sys.stderr)
        return False
    return True


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Terraform Configuration Parser")
        print("")
        print("Usage: python extract_tf_info.py <path-to-tf-file-or-directory>")
        print("")
        print("Examples:")
        print("  python extract_tf_info.py main.tf")
        print("  python extract_tf_info.py ./terraform/")
        print("")
        print("Output: JSON structure with providers, modules, resources, and more")
        sys.exit(1)

    if not check_dependencies():
        sys.exit(1)

    target_path = sys.argv[1]
    parser = TerraformParser()

    if os.path.isfile(target_path):
        if not target_path.endswith('.tf'):
            print(f"Error: {target_path} is not a .tf file", file=sys.stderr)
            sys.exit(1)
        parser.parse_file(target_path)
    elif os.path.isdir(target_path):
        parser.parse_directory(target_path)
    else:
        print(f"Error: {target_path} is not a valid file or directory", file=sys.stderr)
        sys.exit(1)

    # Output JSON
    print(parser.to_json())


if __name__ == "__main__":
    main()