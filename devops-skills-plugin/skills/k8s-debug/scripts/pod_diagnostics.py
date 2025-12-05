#!/usr/bin/env python3
"""
Kubernetes Pod Diagnostics Script
Gathers comprehensive diagnostic information about a specific pod
"""

import subprocess
import json
import sys
import argparse
from datetime import datetime


def run_kubectl(cmd):
    """Execute kubectl command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", "Command timed out", 1


def get_pod_info(pod_name, namespace="default"):
    """Gather comprehensive pod diagnostic information"""

    print(f"\n{'='*80}")
    print(f"Pod Diagnostics for: {pod_name} (namespace: {namespace})")
    print(f"Timestamp: {datetime.now().isoformat()}")
    print(f"{'='*80}\n")

    # Pod Status
    print("\n## POD STATUS ##")
    stdout, stderr, _ = run_kubectl(f"kubectl get pod {pod_name} -n {namespace} -o wide")
    print(stdout or stderr)

    # Pod Description
    print("\n## POD DESCRIPTION ##")
    stdout, stderr, _ = run_kubectl(f"kubectl describe pod {pod_name} -n {namespace}")
    print(stdout or stderr)

    # Pod YAML
    print("\n## POD YAML ##")
    stdout, stderr, _ = run_kubectl(f"kubectl get pod {pod_name} -n {namespace} -o yaml")
    print(stdout or stderr)

    # Events related to the pod
    print("\n## RECENT EVENTS ##")
    stdout, stderr, _ = run_kubectl(
        f"kubectl get events -n {namespace} --field-selector involvedObject.name={pod_name} --sort-by='.lastTimestamp'"
    )
    print(stdout or stderr)

    # Container logs (all containers)
    print("\n## CONTAINER LOGS ##")
    stdout, _, _ = run_kubectl(f"kubectl get pod {pod_name} -n {namespace} -o jsonpath='{{.spec.containers[*].name}}'")
    containers = stdout.strip().split()

    for container in containers:
        print(f"\n### Container: {container} ###")
        stdout, stderr, _ = run_kubectl(f"kubectl logs {pod_name} -n {namespace} -c {container} --tail=100")
        print(stdout or stderr)

        # Previous logs if container restarted
        print(f"\n### Previous logs for: {container} ###")
        stdout, stderr, _ = run_kubectl(f"kubectl logs {pod_name} -n {namespace} -c {container} --previous --tail=50 2>&1")
        if "previous terminated container" not in stderr.lower():
            print(stdout or stderr)

    # Resource usage
    print("\n## RESOURCE USAGE ##")
    stdout, stderr, _ = run_kubectl(f"kubectl top pod {pod_name} -n {namespace} --containers 2>&1")
    print(stdout or stderr)

    # Node information
    print("\n## NODE INFORMATION ##")
    stdout, _, _ = run_kubectl(f"kubectl get pod {pod_name} -n {namespace} -o jsonpath='{{.spec.nodeName}}'")
    node_name = stdout.strip()
    if node_name:
        print(f"Pod is running on node: {node_name}")
        stdout, stderr, _ = run_kubectl(f"kubectl describe node {node_name}")
        print(stdout or stderr)


def main():
    parser = argparse.ArgumentParser(description='Gather Kubernetes pod diagnostics')
    parser.add_argument('pod_name', help='Name of the pod to diagnose')
    parser.add_argument('-n', '--namespace', default='default', help='Namespace (default: default)')
    parser.add_argument('-o', '--output', help='Output file path (optional)')

    args = parser.parse_args()

    if args.output:
        sys.stdout = open(args.output, 'w')

    get_pod_info(args.pod_name, args.namespace)

    if args.output:
        sys.stdout.close()
        print(f"\nDiagnostics written to: {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
