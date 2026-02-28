---
name: k8s-debug
description: Comprehensive Kubernetes debugging and troubleshooting toolkit. Use this skill when diagnosing Kubernetes cluster issues, debugging failing pods, investigating network connectivity problems, analyzing resource usage, troubleshooting deployments, or performing cluster health checks.
---

# Kubernetes Debugging Skill

## Overview

Systematic toolkit for debugging Kubernetes clusters, workloads, networking, and storage with a deterministic, safety-first workflow.

## Trigger Phrases

Use this skill when requests resemble:
- "My pod is in `CrashLoopBackOff`; help me find the root cause."
- "Service DNS works in one pod but not another."
- "Deployment rollout is stuck."
- "Pods are `Pending` and not scheduling."
- "Cluster health looks degraded after a change."
- "PVC is pending and pods cannot mount storage."

## Prerequisites

Run from the skill directory (`devops-skills-plugin/skills/k8s-debug`) so relative script paths work as written.

### Required
- `kubectl` installed and configured.
- An active cluster context.
- Read access to namespaces, pods, events, services, and nodes.

Quick preflight:

```bash
kubectl config current-context
kubectl auth can-i get pods -A
kubectl auth can-i get events -A
kubectl get ns
```

### Optional but Recommended
- `jq` for more precise filtering in `./scripts/cluster_health.sh`.
- Metrics API (`metrics-server`) for `kubectl top`.
- In-container debug tools (`nslookup`, `getent`, `curl`, `wget`, `ip`) for deep network tests.

Fallback behavior:
- If optional tools are missing, scripts continue and print warnings with reduced output.
- If `kubectl top` is unavailable, continue with `kubectl describe` and events.

## When to Use This Skill

Use this skill for:
- Pod failures (CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled)
- Service connectivity or DNS resolution issues
- Network policy or ingress problems
- Volume and storage mount failures
- Deployment rollout issues
- Cluster health or performance degradation
- Resource exhaustion (CPU/memory)
- Configuration problems (ConfigMaps, Secrets, RBAC)

## Safety Rules for Disruptive Commands

Default mode is read-only diagnosis first. Only execute disruptive commands after confirming blast radius and rollback.

Commands requiring explicit confirmation:
- `kubectl delete pod ... --force --grace-period=0`
- `kubectl drain ...`
- `kubectl rollout restart ...`
- `kubectl rollout undo ...`
- `kubectl debug ... --copy-to=...`

Before disruptive actions:
```bash
# Snapshot current state for rollback and incident notes
kubectl get deploy,rs,pod,svc -n <namespace> -o wide
kubectl get pod <pod-name> -n <namespace> -o yaml > before-<pod-name>.yaml
kubectl get events -n <namespace> --sort-by='.lastTimestamp' > before-events.txt
```

## Reference Navigation Map

Load only the section needed for the observed symptom.

| Symptom / Need | Open | Start section |
| --- | --- | --- |
| You need an end-to-end diagnosis path | `./references/troubleshooting_workflow.md` | `General Debugging Workflow` |
| Pod state is `Pending`, `CrashLoopBackOff`, or `ImagePullBackOff` | `./references/troubleshooting_workflow.md` | `Pod Lifecycle Troubleshooting` |
| Service reachability or DNS failure | `./references/troubleshooting_workflow.md` | `Network Troubleshooting Workflow` |
| Node pressure or performance regression | `./references/troubleshooting_workflow.md` | `Resource and Performance Workflow` |
| PVC / PV / storage class issues | `./references/troubleshooting_workflow.md` | `Storage Troubleshooting Workflow` |
| Quick symptom-to-fix lookup | `./references/common_issues.md` | matching issue heading |
| Post-mortem fix options for known issues | `./references/common_issues.md` | `Solutions` sections |

## Scripts Overview

| Script | Purpose | Required args | Optional args | Output | Fallback behavior |
| --- | --- | --- | --- | --- | --- |
| `./scripts/cluster_health.sh` | Cluster-wide health snapshot (nodes, workloads, events, common failure states) | None | `K8S_REQUEST_TIMEOUT` env var | Sectioned report to stdout | Continues when checks fail; warns when `jq`/metrics are unavailable |
| `./scripts/network_debug.sh` | Pod-centric network and DNS diagnostics | `<pod-name>` (`<namespace>` defaults to `default`) | `K8S_REQUEST_TIMEOUT` env var | Sectioned report to stdout | Continues through non-critical failures; prints warnings for missing permissions/tools |
| `./scripts/pod_diagnostics.py` | Deep pod diagnostics (status, describe, YAML, events, per-container logs, node context) | `<pod-name>` | `-n/--namespace`, `-o/--output` | Sectioned report to stdout or file | Fails fast on missing access; skips optional metrics/log blocks with clear messages |

## Deterministic Debugging Workflow

Follow this systematic approach for any Kubernetes issue:

### 1. Preflight and Scope

```bash
kubectl config current-context
kubectl get ns
kubectl auth can-i get pods -n <namespace>
```

If preflight fails, stop and fix access/context first.

### 2. Identify the Problem Layer

Categorize the issue:
- **Application Layer**: Application crashes, errors, bugs
- **Pod Layer**: Pod not starting, restarting, or pending
- **Service Layer**: Network connectivity, DNS issues
- **Node Layer**: Node not ready, resource exhaustion
- **Cluster Layer**: Control plane issues, API problems
- **Storage Layer**: Volume mount failures, PVC issues
- **Configuration Layer**: ConfigMap, Secret, RBAC issues

### 3. Gather Diagnostics with the Right Script

Use the appropriate diagnostic script based on scope:

#### Pod-Level Diagnostics
Use `./scripts/pod_diagnostics.py` for comprehensive pod analysis:

```bash
python3 ./scripts/pod_diagnostics.py <pod-name> -n <namespace>
```

This script gathers:
- Pod status and description
- Pod events
- Container logs (current and previous)
- Resource usage
- Node information
- YAML configuration

Output can be saved for analysis:

```bash
python3 ./scripts/pod_diagnostics.py <pod-name> -n <namespace> -o diagnostics.txt
```

#### Cluster-Level Health Check
Use `./scripts/cluster_health.sh` for overall cluster diagnostics:

```bash
./scripts/cluster_health.sh > cluster-health-$(date +%Y%m%d-%H%M%S).txt
```

This script checks:
- Cluster info and version
- Node status and resources
- Pods across all namespaces
- Failed/pending pods
- Recent events
- Deployments, services, statefulsets, daemonsets
- PVCs and PVs
- Component health
- Common error states (CrashLoopBackOff, ImagePullBackOff)

#### Network Diagnostics
Use `./scripts/network_debug.sh` for connectivity issues:

```bash
./scripts/network_debug.sh <namespace> <pod-name>
```

This script analyzes:
- Pod network configuration
- DNS setup and resolution
- Service endpoints
- Network policies
- Connectivity tests
- CoreDNS logs

### 4. Follow Issue-Specific Reference Workflow

Based on the identified issue, consult `./references/troubleshooting_workflow.md`:

- **Pod Pending**: Resource/scheduling workflow
- **CrashLoopBackOff**: Application crash workflow
- **ImagePullBackOff**: Image pull workflow
- **Service issues**: Network connectivity workflow
- **DNS failures**: DNS troubleshooting workflow
- **Resource exhaustion**: Performance investigation workflow
- **Storage issues**: PVC binding workflow
- **Deployment stuck**: Rollout workflow

### 5. Apply Targeted Fixes

Refer to `./references/common_issues.md` for symptom-specific fixes.

### 6. Verify and Close

Run final verification:

```bash
kubectl get pods -n <namespace> -o wide
kubectl get events -n <namespace> --sort-by='.lastTimestamp' | tail -20
kubectl rollout status deployment/<name> -n <namespace>
```

Issue is done when user-visible behavior is healthy and no new critical warning events appear.

## Example Flows

### Example 1: CrashLoopBackOff in `payments` Namespace

```bash
python3 ./scripts/pod_diagnostics.py payments-api-7c97f95dfb-q9l7k -n payments -o payments-diagnostics.txt
kubectl logs payments-api-7c97f95dfb-q9l7k -n payments --previous --tail=100
kubectl get deploy payments-api -n payments -o yaml | grep -A 8 livenessProbe
```

Then open `./references/common_issues.md` and apply the `CrashLoopBackOff` solutions.

### Example 2: Service DNS/Connectivity Failure

```bash
./scripts/network_debug.sh checkout checkout-api-75f49c9d8f-z6qtm
kubectl get svc checkout-api -n checkout
kubectl get endpoints checkout-api -n checkout
kubectl get networkpolicies -n checkout
```

Then follow `Service Connectivity Workflow` in `./references/troubleshooting_workflow.md`.

## Essential Manual Commands

### Pod Debugging

```bash
# View pod status
kubectl get pods -n <namespace> -o wide

# Detailed pod information
kubectl describe pod <pod-name> -n <namespace>

# View logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # Previous container
kubectl logs <pod-name> -n <namespace> -c <container>  # Specific container

# Execute commands in pod
kubectl exec <pod-name> -n <namespace> -it -- /bin/sh

# Get pod YAML
kubectl get pod <pod-name> -n <namespace> -o yaml
```

### Service and Network Debugging

```bash
# Check services
kubectl get svc -n <namespace>
kubectl describe svc <service-name> -n <namespace>

# Check endpoints
kubectl get endpoints -n <namespace>

# Test DNS
kubectl exec <pod-name> -n <namespace> -- nslookup kubernetes.default

# View events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Resource Monitoring

```bash
# Node resources
kubectl top nodes
kubectl describe nodes

# Pod resources
kubectl top pods -n <namespace>
kubectl top pod <pod-name> -n <namespace> --containers
```

### Emergency Operations

```bash
# Restart deployment
kubectl rollout restart deployment/<name> -n <namespace>

# Rollback deployment
kubectl rollout undo deployment/<name> -n <namespace>

# Force delete stuck pod
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0

# Drain node (maintenance)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Cordon node (prevent scheduling)
kubectl cordon <node-name>
```

## Completion Criteria

Troubleshooting session is complete when all are true:
- [ ] Cluster context and namespace are confirmed.
- [ ] Relevant diagnostic script output is captured.
- [ ] Root cause is identified and tied to evidence (events/logs/config/state).
- [ ] Any disruptive action was preceded by snapshot and rollback plan.
- [ ] Fix verification commands show healthy state.
- [ ] Reference path used (`./references/troubleshooting_workflow.md` or `./references/common_issues.md`) is documented in notes.

## Related Tools

Useful additional tools for Kubernetes debugging:
- **kubectl-debug**: Advanced debugging plugin
- **stern**: Multi-pod log tailing
- **kubectx/kubens**: Context and namespace switching
- **k9s**: Terminal UI for Kubernetes
- **lens**: Desktop IDE for Kubernetes
- **Prometheus/Grafana**: Monitoring and alerting
- **Jaeger/Zipkin**: Distributed tracing
