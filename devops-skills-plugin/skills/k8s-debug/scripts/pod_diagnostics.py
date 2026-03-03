#!/usr/bin/env python3
"""
Kubernetes Pod Diagnostics Script
Gathers comprehensive diagnostic information about a specific pod
with explicit preflight checks and graceful fallbacks.
"""

import argparse
import os
import shutil
import subprocess
import sys
from datetime import datetime
from typing import Sequence, Tuple

REQUEST_TIMEOUT = os.environ.get("K8S_REQUEST_TIMEOUT", "15s")


def run_kubectl(args: Sequence[str], timeout: int = 30) -> Tuple[str, str, int]:
    """Execute kubectl command and return (stdout, stderr, exit_code)."""
    cmd = ["kubectl", f"--request-timeout={REQUEST_TIMEOUT}", *args]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return result.stdout, result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "", f"Command timed out: {' '.join(cmd)}", 1


def print_output(stdout: str, stderr: str) -> None:
    """Print command output, preferring stdout then stderr."""
    if stdout.strip():
        print(stdout.rstrip())
    elif stderr.strip():
        print(stderr.rstrip())


def print_section(title: str) -> None:
    print(f"\n## {title} ##")


def ensure_prerequisites(namespace: str, pod_name: str) -> bool:
    """Validate local tool availability and cluster access prerequisites."""
    if shutil.which("kubectl") is None:
        print("ERROR: kubectl is not installed or not in PATH.", file=sys.stderr)
        return False

    stdout, stderr, code = run_kubectl(["config", "current-context"])
    if code != 0:
        print("ERROR: Unable to determine active Kubernetes context.", file=sys.stderr)
        print_output(stdout, stderr)
        return False

    stdout, stderr, code = run_kubectl(["get", "pod", pod_name, "-n", namespace, "-o", "name"])
    if code != 0:
        print(
            f"ERROR: Pod '{pod_name}' in namespace '{namespace}' is not accessible.",
            file=sys.stderr,
        )
        print_output(stdout, stderr)
        return False

    stdout, _, _ = run_kubectl(["auth", "can-i", "create", "pods/exec", "-n", namespace])
    if stdout.strip() != "yes":
        print(
            "WARN: RBAC may block pod exec; in-container diagnostics can be limited.",
            file=sys.stderr,
        )

    return True


def get_pod_info(pod_name: str, namespace: str = "default") -> None:
    """Gather comprehensive pod diagnostic information."""

    print(f"\n{'=' * 80}")
    print(f"Pod Diagnostics for: {pod_name} (namespace: {namespace})")
    print(f"Timestamp: {datetime.utcnow().isoformat(timespec='seconds')}Z")
    print(f"{'=' * 80}\n")

    # Pod Status
    print_section("POD STATUS")
    stdout, stderr, _ = run_kubectl(["get", "pod", pod_name, "-n", namespace, "-o", "wide"])
    print_output(stdout, stderr)

    # Pod Description
    print_section("POD DESCRIPTION")
    stdout, stderr, _ = run_kubectl(["describe", "pod", pod_name, "-n", namespace])
    print_output(stdout, stderr)

    # Pod YAML
    print_section("POD YAML")
    stdout, stderr, _ = run_kubectl(["get", "pod", pod_name, "-n", namespace, "-o", "yaml"])
    print_output(stdout, stderr)

    # Events related to the pod
    print_section("RECENT EVENTS")
    stdout, stderr, _ = run_kubectl(
        [
            "get",
            "events",
            "-n",
            namespace,
            "--field-selector",
            f"involvedObject.name={pod_name}",
            "--sort-by=.lastTimestamp",
        ]
    )
    print_output(stdout, stderr)

    # Container logs (all containers)
    print_section("CONTAINER LOGS")
    stdout, stderr, code = run_kubectl(
        ["get", "pod", pod_name, "-n", namespace, "-o", "jsonpath={.spec.containers[*].name}"]
    )
    if code != 0:
        print_output(stdout, stderr)
        print("INFO: Skipping container logs because container names could not be queried.")
        containers = []
    else:
        containers = stdout.strip().split()

    if not containers:
        print("INFO: No containers detected for this pod.")

    for container in containers:
        print(f"\n### Container: {container} ###")
        stdout, stderr, _ = run_kubectl(
            ["logs", pod_name, "-n", namespace, "-c", container, "--tail=100"],
            timeout=45,
        )
        print_output(stdout, stderr)

        print(f"\n### Previous logs for: {container} ###")
        stdout, stderr, code = run_kubectl(
            ["logs", pod_name, "-n", namespace, "-c", container, "--previous", "--tail=50"],
            timeout=45,
        )
        previous_log_message = f"{stdout}\n{stderr}".lower()
        if code == 0:
            print_output(stdout, stderr)
        elif (
            "previous terminated container" in previous_log_message
            or "is not terminated" in previous_log_message
        ):
            print("INFO: No previous terminated container logs available.")
        else:
            print_output(stdout, stderr)

    # Init container logs — only emitted when the pod has init containers.
    # Init container failures are a primary cause of Init:CrashLoopBackOff and
    # Init:0/N pending states; their logs must be visible in diagnostic output.
    stdout, stderr, code = run_kubectl(
        ["get", "pod", pod_name, "-n", namespace, "-o", "jsonpath={.spec.initContainers[*].name}"]
    )
    if code != 0:
        print_section("INIT CONTAINER LOGS")
        print_output(stdout, stderr)
        print("INFO: Skipping init container logs because init container names could not be queried.")
    else:
        init_containers = stdout.strip().split()
        if init_containers:
            print_section("INIT CONTAINER LOGS")
            for container in init_containers:
                print(f"\n### Init Container: {container} ###")
                stdout, stderr, _ = run_kubectl(
                    ["logs", pod_name, "-n", namespace, "-c", container, "--tail=100"],
                    timeout=45,
                )
                print_output(stdout, stderr)

                print(f"\n### Previous init container logs for: {container} ###")
                stdout, stderr, code = run_kubectl(
                    ["logs", pod_name, "-n", namespace, "-c", container, "--previous", "--tail=50"],
                    timeout=45,
                )
                previous_log_message = f"{stdout}\n{stderr}".lower()
                if code == 0:
                    print_output(stdout, stderr)
                elif (
                    "previous terminated container" in previous_log_message
                    or "is not terminated" in previous_log_message
                ):
                    print("INFO: No previous terminated init container logs available.")
                else:
                    print_output(stdout, stderr)

    # Resource usage
    print_section("RESOURCE USAGE")
    stdout, stderr, code = run_kubectl(
        ["top", "pod", pod_name, "-n", namespace, "--containers"],
        timeout=20,
    )
    if code == 0:
        print_output(stdout, stderr)
    elif "metrics" in stderr.lower():
        print("INFO: Metrics API is unavailable. Skipping 'kubectl top' output.")
        print_output("", stderr)
    else:
        print_output(stdout, stderr)

    # Node information
    print_section("NODE INFORMATION")
    stdout, stderr, code = run_kubectl(
        ["get", "pod", pod_name, "-n", namespace, "-o", "jsonpath={.spec.nodeName}"]
    )
    if code != 0:
        print_output(stdout, stderr)
        return

    node_tokens = stdout.strip().split()
    node_name = node_tokens[0] if node_tokens else ""
    if node_name:
        print(f"Pod is running on node: {node_name}")
        stdout, stderr, _ = run_kubectl(["describe", "node", node_name], timeout=45)
        print_output(stdout, stderr)
    else:
        print("INFO: Node name is not available yet (pod may still be unscheduled).")


def main() -> int:
    parser = argparse.ArgumentParser(description="Gather Kubernetes pod diagnostics")
    parser.add_argument("pod_name", help="Name of the pod to diagnose")
    parser.add_argument("-n", "--namespace", default="default", help="Namespace (default: default)")
    parser.add_argument("-o", "--output", help="Output file path (optional)")

    args = parser.parse_args()

    if not ensure_prerequisites(args.namespace, args.pod_name):
        return 1

    original_stdout = sys.stdout
    output_handle = None
    if args.output:
        output_handle = open(args.output, "w", encoding="utf-8")
        sys.stdout = output_handle

    try:
        get_pod_info(args.pod_name, args.namespace)
    finally:
        if output_handle is not None:
            sys.stdout = original_stdout
            output_handle.close()
            print(f"\nDiagnostics written to: {args.output}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    sys.exit(main())
