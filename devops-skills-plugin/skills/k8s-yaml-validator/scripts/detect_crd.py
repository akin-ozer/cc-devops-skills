#!/usr/bin/env python3
"""
Detect Custom Resource Definitions (CRDs) in Kubernetes YAML files.
Extracts kind, apiVersion, and group information for CRD documentation lookup.

This script is resilient to syntax errors in individual documents within
multi-document YAML files. It will parse valid documents and report errors
for invalid ones, allowing CRD detection to proceed for parseable resources.
"""

import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("Error: PyYAML is not installed. Please run: pip install pyyaml", file=sys.stderr)
    print("Or use the wrapper script: bash scripts/detect_crd_wrapper.sh", file=sys.stderr)
    sys.exit(1)


def split_yaml_documents(content):
    """
    Split YAML content into individual documents.
    Handles document separators (---) properly.
    """
    # Split on document separator, keeping track of line numbers
    documents = []
    current_doc = []
    current_start_line = 1
    line_num = 0

    for line in content.split('\n'):
        line_num += 1
        if line.strip() == '---':
            if current_doc:
                doc_content = '\n'.join(current_doc)
                if doc_content.strip():  # Only add non-empty documents
                    documents.append({
                        'content': doc_content,
                        'start_line': current_start_line
                    })
            current_doc = []
            current_start_line = line_num + 1
        else:
            current_doc.append(line)

    # Don't forget the last document
    if current_doc:
        doc_content = '\n'.join(current_doc)
        if doc_content.strip():
            documents.append({
                'content': doc_content,
                'start_line': current_start_line
            })

    return documents


def parse_yaml_file(file_path):
    """
    Parse a YAML file that may contain multiple documents.

    This function is resilient to syntax errors in individual documents.
    It parses each document separately and continues even if some fail,
    matching the behavior of kubeconform which can validate 2/3 resources
    even when 1/3 has syntax errors.

    Returns:
        tuple: (list of parsed documents, list of parse errors)
    """
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading file: {e}", file=sys.stderr)
        return [], [{'error': str(e), 'document': 0}]

    # First, try parsing the entire file at once (fast path)
    try:
        documents = list(yaml.safe_load_all(content))
        return documents, []
    except yaml.YAMLError:
        # If full parsing fails, try document-by-document parsing
        pass

    # Split into individual documents and parse each separately
    doc_parts = split_yaml_documents(content)
    documents = []
    errors = []

    for i, doc_info in enumerate(doc_parts, 1):
        try:
            parsed = yaml.safe_load(doc_info['content'])
            if parsed is not None:
                documents.append(parsed)
        except yaml.YAMLError as e:
            error_msg = str(e)
            # Extract line number from error if available
            line_match = re.search(r'line (\d+)', error_msg)
            error_line = doc_info['start_line']
            if line_match:
                error_line = doc_info['start_line'] + int(line_match.group(1)) - 1

            errors.append({
                'document': i,
                'start_line': doc_info['start_line'],
                'error_line': error_line,
                'error': error_msg
            })
            print(f"Warning: Document {i} (starting at line {doc_info['start_line']}) has syntax errors: {error_msg}", file=sys.stderr)

    if errors:
        print(f"Parsed {len(documents)} of {len(doc_parts)} documents successfully. {len(errors)} document(s) had errors.", file=sys.stderr)

    return documents, errors


def is_standard_k8s_resource(api_version, kind):
    """Check if a resource is a standard Kubernetes resource."""
    standard_groups = {
        # Core API group
        'v1': True,
        # Apps group
        'apps/v1': True,
        # Batch group
        'batch/v1': True,
        'batch/v1beta1': True,
        # Networking group
        'networking.k8s.io/v1': True,
        'networking.k8s.io/v1beta1': True,
        # Policy group
        'policy/v1': True,
        'policy/v1beta1': True,
        # RBAC group
        'rbac.authorization.k8s.io/v1': True,
        'rbac.authorization.k8s.io/v1beta1': True,
        # Storage group
        'storage.k8s.io/v1': True,
        'storage.k8s.io/v1beta1': True,
        # Autoscaling group
        'autoscaling/v1': True,
        'autoscaling/v2': True,
        'autoscaling/v2beta1': True,
        'autoscaling/v2beta2': True,
        # API Extensions group (for CRD definitions themselves)
        'apiextensions.k8s.io/v1': True,
        'apiextensions.k8s.io/v1beta1': True,
        # Certificates group
        'certificates.k8s.io/v1': True,
        'certificates.k8s.io/v1beta1': True,
        # Admission Registration group
        'admissionregistration.k8s.io/v1': True,
        'admissionregistration.k8s.io/v1beta1': True,
        # Coordination group (Leases)
        'coordination.k8s.io/v1': True,
        # Discovery group (EndpointSlices)
        'discovery.k8s.io/v1': True,
        'discovery.k8s.io/v1beta1': True,
        # Events group
        'events.k8s.io/v1': True,
        'events.k8s.io/v1beta1': True,
        # Flow Control group (v1 is GA since K8s 1.29, v1beta3 deprecated in 1.32)
        'flowcontrol.apiserver.k8s.io/v1': True,
        'flowcontrol.apiserver.k8s.io/v1beta1': True,
        'flowcontrol.apiserver.k8s.io/v1beta2': True,
        'flowcontrol.apiserver.k8s.io/v1beta3': True,
        # Storage Migration group (K8s 1.30+)
        'storagemigration.k8s.io/v1alpha1': True,
        # Node group (RuntimeClass)
        'node.k8s.io/v1': True,
        'node.k8s.io/v1beta1': True,
        # Scheduling group (PriorityClass)
        'scheduling.k8s.io/v1': True,
        'scheduling.k8s.io/v1beta1': True,
        # Snapshot Storage group (VolumeSnapshots)
        'snapshot.storage.k8s.io/v1': True,
        'snapshot.storage.k8s.io/v1beta1': True,
        # Networking alpha (AdminNetworkPolicy - K8s 1.30+)
        'networking.k8s.io/v1alpha1': True,
        # Certificates alpha (ClusterTrustBundle - K8s 1.30+)
        'certificates.k8s.io/v1alpha1': True,
        # Resource group (ResourceClaims - K8s 1.26+)
        'resource.k8s.io/v1alpha2': True,
        'resource.k8s.io/v1alpha3': True,
        # Internal API Server group
        'internal.apiserver.k8s.io/v1alpha1': True,
        # API Registration group
        'apiregistration.k8s.io/v1': True,
        'apiregistration.k8s.io/v1beta1': True,
        # Authentication group
        'authentication.k8s.io/v1': True,
        'authentication.k8s.io/v1beta1': True,
        # Authorization group
        'authorization.k8s.io/v1': True,
        'authorization.k8s.io/v1beta1': True,
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

    documents, parse_errors = parse_yaml_file(file_path)
    resources = []

    for doc in documents:
        resource_info = extract_resource_info(doc)
        if resource_info:
            resources.append(resource_info)

    # Build output with both resources and any parse errors
    output = {
        'resources': resources,
        'parseErrors': parse_errors,
        'summary': {
            'totalDocuments': len(documents) + len(parse_errors),
            'parsedSuccessfully': len(documents),
            'parseErrors': len(parse_errors),
            'crdsDetected': sum(1 for r in resources if r.get('isCRD', False))
        }
    }

    # Output as JSON for easy parsing
    print(json.dumps(output, indent=2))


if __name__ == '__main__':
    main()
