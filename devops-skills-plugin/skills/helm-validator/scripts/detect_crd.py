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


STANDARD_API_GROUPS = {
    # Core APIs are represented by apiVersion "v1" (handled separately)
    "admissionregistration.k8s.io",
    "apiextensions.k8s.io",
    "apiregistration.k8s.io",
    "apps",
    "authentication.k8s.io",
    "authorization.k8s.io",
    "autoscaling",
    "batch",
    "certificates.k8s.io",
    "coordination.k8s.io",
    "discovery.k8s.io",
    "events.k8s.io",
    "extensions",
    "flowcontrol.apiserver.k8s.io",
    "internal.apiserver.k8s.io",
    "networking.k8s.io",
    "node.k8s.io",
    "policy",
    "rbac.authorization.k8s.io",
    "resource.k8s.io",
    "scheduling.k8s.io",
    "storage.k8s.io",
}


def parse_yaml_file(file_path):
    """Parse a YAML file that may contain multiple documents."""
    try:
        with open(file_path, "r", encoding="utf-8") as f:
            return list(yaml.safe_load_all(f))
    except Exception as e:
        print(f"Error parsing YAML file {file_path}: {e}", file=sys.stderr)
        return None


def is_standard_k8s_resource(api_version):
    """Check if a resource is a standard Kubernetes resource."""
    # Core API group has no slash (e.g. "v1")
    if api_version == "v1":
        return True

    if "/" not in api_version:
        return False

    group = api_version.split("/", 1)[0]
    return group in STANDARD_API_GROUPS


def extract_resource_info(doc):
    """Extract resource information from a Kubernetes resource document."""
    if not doc or not isinstance(doc, dict):
        return None

    kind = doc.get("kind")
    api_version = doc.get("apiVersion")

    if not kind or not api_version:
        return None

    # Extract group from apiVersion (e.g., "cert-manager.io/v1" -> "cert-manager.io")
    group = api_version.split("/")[0] if "/" in api_version else "core"
    version = api_version.split("/")[-1]

    is_crd = not is_standard_k8s_resource(api_version)

    return {
        "kind": kind,
        "apiVersion": api_version,
        "group": group,
        "version": version,
        "isCRD": is_crd,
        "name": doc.get("metadata", {}).get("name", "unnamed"),
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: detect_crd.py <yaml-file> [yaml-file ...]", file=sys.stderr)
        sys.exit(1)

    file_paths = sys.argv[1:]
    resources = []
    has_errors = False

    for file_path in file_paths:
        path = Path(file_path)
        if not path.exists():
            print(f"File not found: {file_path}", file=sys.stderr)
            has_errors = True
            continue

        documents = parse_yaml_file(path)
        if documents is None:
            has_errors = True
            continue

        for doc in documents:
            resource_info = extract_resource_info(doc)
            if resource_info:
                resources.append(resource_info)

    # Output as JSON for easy parsing
    print(json.dumps(resources, indent=2))
    if has_errors:
        sys.exit(1)


if __name__ == "__main__":
    main()
