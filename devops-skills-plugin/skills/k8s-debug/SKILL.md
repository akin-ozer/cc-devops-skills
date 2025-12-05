---
name: k8s-debug
description: Comprehensive Kubernetes debugging and troubleshooting toolkit. Use this skill when diagnosing Kubernetes cluster issues, debugging failing pods, investigating network connectivity problems, analyzing resource usage, troubleshooting deployments, or performing cluster health checks.
---

# Kubernetes Debugging Skill

## Overview

Systematic toolkit for debugging and troubleshooting Kubernetes clusters, pods, services, and deployments. Provides scripts, workflows, and reference guides for identifying and resolving common Kubernetes issues efficiently.

## When to Use This Skill

Invoke this skill when encountering:
- Pod failures (CrashLoopBackOff, ImagePullBackOff, Pending, OOMKilled)
- Service connectivity or DNS resolution issues
- Network policy or ingress problems
- Volume and storage mount failures
- Deployment rollout issues
- Cluster health or performance degradation
- Resource exhaustion (CPU/memory)
- Configuration problems (ConfigMaps, Secrets, RBAC)

## Debugging Workflow

Follow this systematic approach for any Kubernetes issue:

### 1. Identify the Problem Layer

Categorize the issue:
- **Application Layer**: Application crashes, errors, bugs
- **Pod Layer**: Pod not starting, restarting, or pending
- **Service Layer**: Network connectivity, DNS issues
- **Node Layer**: Node not ready, resource exhaustion
- **Cluster Layer**: Control plane issues, API problems
- **Storage Layer**: Volume mount failures, PVC issues
- **Configuration Layer**: ConfigMap, Secret, RBAC issues

### 2. Gather Diagnostic Information

Use the appropriate diagnostic script based on scope:

#### Pod-Level Diagnostics
Use `scripts/pod_diagnostics.py` for comprehensive pod analysis:

```bash
python3 scripts/pod_diagnostics.py <pod-name> -n <namespace>
```

This script gathers:
- Pod status and description
- Pod events
- Container logs (current and previous)
- Resource usage
- Node information
- YAML configuration

Output can be saved for analysis: `python3 scripts/pod_diagnostics.py <pod-name> -n <namespace> -o diagnostics.txt`

#### Cluster-Level Health Check
Use `scripts/cluster_health.sh` for overall cluster diagnostics:

```bash
./scripts/cluster_health.sh
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
Use `scripts/network_debug.sh` for connectivity issues:

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

### 3. Follow Issue-Specific Workflow

Based on the identified issue, consult `references/troubleshooting_workflow.md` for detailed workflows:

- **Pod Pending**: Resource/scheduling workflow
- **CrashLoopBackOff**: Application crash workflow
- **ImagePullBackOff**: Image pull workflow
- **Service issues**: Network connectivity workflow
- **DNS failures**: DNS troubleshooting workflow
- **Resource exhaustion**: Performance investigation workflow
- **Storage issues**: PVC binding workflow
- **Deployment stuck**: Rollout workflow

### 4. Apply Targeted Fixes

Refer to `references/common_issues.md` for specific solutions to common problems.

## Common Debugging Patterns

### Pattern 1: Pod Not Starting

```bash
# Quick assessment
kubectl get pod <pod-name> -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# Detailed diagnostics
python3 scripts/pod_diagnostics.py <pod-name> -n <namespace>

# Check common causes:
# - ImagePullBackOff: Verify image exists and credentials
# - CrashLoopBackOff: Check logs with --previous flag
# - Pending: Check node resources and scheduling
```

### Pattern 2: Service Connectivity Issues

```bash
# Verify service and endpoints
kubectl get svc <service-name> -n <namespace>
kubectl get endpoints <service-name> -n <namespace>

# Network diagnostics
./scripts/network_debug.sh <namespace> <pod-name>

# Test connectivity from debug pod
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
# Inside: curl <service-name>.<namespace>.svc.cluster.local:<port>

# Check network policies
kubectl get networkpolicies -n <namespace>
```

### Pattern 3: Application Performance Issues

```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n <namespace> --containers

# Get pod metrics
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 resources

# Check for OOMKilled
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 lastState

# Review application logs
kubectl logs <pod-name> -n <namespace> --tail=100
```

### Pattern 4: Cluster Health Assessment

```bash
# Run comprehensive health check
./scripts/cluster_health.sh > cluster-health-$(date +%Y%m%d-%H%M%S).txt

# Review output for:
# - Node conditions and resource pressure
# - Failed or pending pods
# - Recent error events
# - Component health status
# - Resource quota usage
```

## Essential Manual Commands

While scripts automate diagnostics, understand these core commands:

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

## Reference Documentation

### Detailed Troubleshooting Guides

Consult `references/troubleshooting_workflow.md` for:
- Step-by-step workflows for each issue type
- Decision trees for diagnosis
- Command sequences for systematic debugging
- Quick reference command cheat sheet

### Common Issues Database

Consult `references/common_issues.md` for:
- Detailed explanations of each common issue
- Symptoms and causes
- Specific debugging steps
- Solutions and fixes
- Prevention strategies

## Best Practices

### Systematic Approach
1. **Observe**: Gather facts before making changes
2. **Analyze**: Use diagnostic scripts to collect comprehensive data
3. **Hypothesize**: Form theory about root cause
4. **Test**: Verify hypothesis with targeted commands
5. **Fix**: Apply appropriate solution
6. **Verify**: Confirm issue is resolved
7. **Document**: Record findings for future reference

### Data Collection
- Save diagnostic output to files for analysis
- Capture logs before restarting failing pods
- Record events timeline for incident reports
- Export resource metrics for trend analysis

### Prevention
- Set appropriate resource requests and limits
- Implement health checks (liveness/readiness probes)
- Use proper logging and monitoring
- Apply network policies incrementally
- Test changes in non-production environments
- Maintain documentation of cluster architecture

## Advanced Debugging Techniques

### Debug Containers (Kubernetes 1.23+)
```bash
# Attach ephemeral debug container
kubectl debug <pod-name> -n <namespace> -it --image=nicolaka/netshoot

# Create debug copy of pod
kubectl debug <pod-name> -n <namespace> -it --copy-to=<debug-pod-name> --container=<container>
```

### Port Forwarding for Testing
```bash
# Forward pod port to local machine
kubectl port-forward pod/<pod-name> -n <namespace> <local-port>:<pod-port>

# Forward service port
kubectl port-forward svc/<service-name> -n <namespace> <local-port>:<service-port>
```

### Proxy for API Access
```bash
# Start kubectl proxy
kubectl proxy --port=8080

# Access API
curl http://localhost:8080/api/v1/namespaces/<namespace>/pods/<pod-name>
```

### Custom Column Output
```bash
# Custom pod info
kubectl get pods -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,IP:.status.podIP

# Node taints
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

## Troubleshooting Checklist

Before escalating issues, verify:

- [ ] Reviewed pod events: `kubectl describe pod`
- [ ] Checked pod logs (current and previous)
- [ ] Verified resource availability on nodes
- [ ] Confirmed image exists and is accessible
- [ ] Validated service selectors match pod labels
- [ ] Tested DNS resolution from pods
- [ ] Checked network policies
- [ ] Reviewed recent cluster events
- [ ] Confirmed ConfigMaps/Secrets exist
- [ ] Validated RBAC permissions
- [ ] Checked for resource quotas/limits
- [ ] Reviewed cluster component health

## Related Tools

Useful additional tools for Kubernetes debugging:
- **kubectl-debug**: Advanced debugging plugin
- **stern**: Multi-pod log tailing
- **kubectx/kubens**: Context and namespace switching
- **k9s**: Terminal UI for Kubernetes
- **lens**: Desktop IDE for Kubernetes
- **Prometheus/Grafana**: Monitoring and alerting
- **Jaeger/Zipkin**: Distributed tracing
