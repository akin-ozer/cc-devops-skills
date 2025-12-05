#!/usr/bin/env python3
"""
Detect Custom Resource Definitions (CRDs) in Kubernetes YAML files.
Extracts kind, apiVersion, and group information for CRD documentation lookup.
"""

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is not installed. Please run: pip install pyyaml", file=sys.stderr)
    print("Or use the wrapper script: bash scripts/detect_crd_wrapper.sh", file=sys.stderr)
    sys.exit(1)


def parse_yaml_file(file_path):
    """Parse a YAML file that may contain multiple documents."""
    try:
        with open(file_path, 'r') as f:
            return list(yaml.safe_load_all(f))
    except Exception as e:
        print(f"Error parsing YAML file: {e}", file=sys.stderr)
        return []


def is_standard_k8s_resource(api_version, kind):
    """Check if a resource is a standard Kubernetes resource."""
    standard_groups = {
        # Core API group
        'v1': True,
        # Apps
        'apps/v1': True,
        # Batch
        'batch/v1': True,
        'batch/v1beta1': True,
        # Networking
        'networking.k8s.io/v1': True,
        'networking.k8s.io/v1beta1': True,
        # Policy
        'policy/v1': True,
        'policy/v1beta1': True,
        # RBAC
        'rbac.authorization.k8s.io/v1': True,
        'rbac.authorization.k8s.io/v1beta1': True,
        # Storage
        'storage.k8s.io/v1': True,
        'storage.k8s.io/v1beta1': True,
        # Autoscaling
        'autoscaling/v1': True,
        'autoscaling/v2': True,
        'autoscaling/v2beta1': True,
        'autoscaling/v2beta2': True,
        # API Extensions (CRD definitions themselves)
        'apiextensions.k8s.io/v1': True,
        'apiextensions.k8s.io/v1beta1': True,
        # Admission Registration
        'admissionregistration.k8s.io/v1': True,
        'admissionregistration.k8s.io/v1beta1': True,
        # Certificates
        'certificates.k8s.io/v1': True,
        'certificates.k8s.io/v1beta1': True,
        # Coordination
        'coordination.k8s.io/v1': True,
        # Discovery
        'discovery.k8s.io/v1': True,
        'discovery.k8s.io/v1beta1': True,
        # Events
        'events.k8s.io/v1': True,
        'events.k8s.io/v1beta1': True,
        # Flow Control
        'flowcontrol.apiserver.k8s.io/v1': True,
        'flowcontrol.apiserver.k8s.io/v1beta1': True,
        'flowcontrol.apiserver.k8s.io/v1beta2': True,
        'flowcontrol.apiserver.k8s.io/v1beta3': True,
        # Node
        'node.k8s.io/v1': True,
        'node.k8s.io/v1beta1': True,
        # Scheduling
        'scheduling.k8s.io/v1': True,
        'scheduling.k8s.io/v1beta1': True,
        # Resource (for resource quotas/claims)
        'resource.k8s.io/v1alpha2': True,
        # Internal (apiserver)
        'internal.apiserver.k8s.io/v1alpha1': True,
    }

    # Check if it's a standard group
    return api_version in standard_groups


def extract_resource_info(doc):
    """Extract resource information from a Kubernetes resource document."""
    if not doc or not isinstance(doc, dict):
        return None

    kind = doc.get('kind')
    api_version = doc.get('apiVersion')

    if not kind or not api_version:
        return None

    # Extract group from apiVersion (e.g., "cert-manager.io/v1" -> "cert-manager.io")
    group = api_version.split('/')[0] if '/' in api_version else 'core'
    version = api_version.split('/')[-1]

    is_crd = not is_standard_k8s_resource(api_version, kind)

    return {
        'kind': kind,
        'apiVersion': api_version,
        'group': group,
        'version': version,
        'isCRD': is_crd,
        'name': doc.get('metadata', {}).get('name', 'unnamed')
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: detect_crd.py <yaml-file>", file=sys.stderr)
        sys.exit(1)

    file_path = sys.argv[1]

    if not Path(file_path).exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        sys.exit(1)

    documents = parse_yaml_file(file_path)
    resources = []

    for doc in documents:
        resource_info = extract_resource_info(doc)
        if resource_info:
            resources.append(resource_info)

    # Output as JSON for easy parsing
    print(json.dumps(resources, indent=2))


if __name__ == '__main__':
    main()
