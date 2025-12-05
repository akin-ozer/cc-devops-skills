# Kubernetes Troubleshooting Workflows

## General Debugging Workflow

When facing any Kubernetes issue, follow this systematic approach:

### 1. Identify the Problem Layer

Kubernetes issues typically fall into these categories:

```
Application Layer     → Application crashes, errors, bugs
Pod Layer            → Pod not starting, restarting, pending
Service Layer        → Network connectivity, DNS issues
Node Layer           → Node not ready, resource exhaustion
Cluster Layer        → Control plane issues, API problems
Storage Layer        → Volume mount failures, PVC issues
Configuration Layer  → ConfigMap, Secret, RBAC issues
```

### 2. Gather Initial Information

```bash
# What's the current state?
kubectl get pods -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Quick status check
kubectl describe pod <pod-name> -n <namespace>
```

### 3. Drill Down Based on State

Follow the appropriate workflow based on pod state:

- **Pending** → Resource/Scheduling Workflow
- **ImagePullBackOff** → Image Pull Workflow
- **CrashLoopBackOff** → Application Crash Workflow
- **Running but not working** → Service/Network Workflow
- **Error/Unknown** → Node/Cluster Workflow

---

## Pod Lifecycle Troubleshooting

### Pod Pending Workflow

```
1. kubectl describe pod → Check events section
   ↓
2. Check scheduling issues:
   - Insufficient resources? → kubectl top nodes
   - Node selector issues? → Check nodeSelector in pod spec
   - Taints/tolerations? → kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
   - PVC pending? → kubectl get pvc -n <namespace>
   ↓
3. Take action:
   - Add nodes or free resources
   - Adjust node selector
   - Add tolerations
   - Fix PVC/PV binding
```

### Pod CrashLoopBackOff Workflow

```
1. kubectl logs <pod> --previous
   ↓
2. Analyze crash reason:
   - Application error? → Fix code/config
   - Missing dependencies? → Check env vars, volumes, secrets
   - Resource limits? → kubectl describe pod → Check OOMKilled
   - Failed health checks? → Check liveness/readiness probe settings
   ↓
3. Common checks:
   kubectl get pod <pod> -o yaml | grep -A 10 env
   kubectl get pod <pod> -o yaml | grep -A 10 volumeMounts
   kubectl get pod <pod> -o yaml | grep -A 10 livenessProbe
   ↓
4. Fix and verify:
   - Update deployment/pod spec
   - kubectl apply -f updated-config.yaml
   - Watch: kubectl get pods -w
```

### Pod ImagePullBackOff Workflow

```
1. kubectl describe pod → Find exact error
   ↓
2. Verify image:
   - Does image exist? → docker pull <image> (test locally)
   - Correct tag? → Check deployment spec
   - Private registry? → Check imagePullSecrets
   ↓
3. Fix authentication (if needed):
   kubectl create secret docker-registry <secret> \
     --docker-server=<server> \
     --docker-username=<user> \
     --docker-password=<pass>
   ↓
4. Update pod spec with imagePullSecrets
   ↓
5. Verify:
   kubectl get pods -w
```

---

## Network Troubleshooting Workflow

### Service Connectivity Workflow

```
1. Verify service exists:
   kubectl get svc <service-name> -n <namespace>
   ↓
2. Check endpoints:
   kubectl get endpoints <service-name> -n <namespace>
   ↓
   No endpoints? → Check selector matches pod labels
   ↓
3. Test DNS resolution:
   kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
   nslookup <service-name>.<namespace>.svc.cluster.local
   ↓
   DNS fails? → Check CoreDNS pods and logs
   ↓
4. Test connectivity:
   curl <service-name>.<namespace>.svc.cluster.local:<port>
   ↓
   Connection fails? → Check:
   - Network policies: kubectl get networkpolicies -n <namespace>
   - Target port matches pod port
   - Pod is ready: kubectl get pods -n <namespace>
   ↓
5. Check from outside cluster (if applicable):
   - LoadBalancer service? → Check external IP assigned
   - Ingress? → kubectl get ingress -n <namespace>
   - NodePort? → Access via <node-ip>:<nodePort>
```

### DNS Issues Workflow

```
1. Test DNS from problem pod:
   kubectl exec <pod> -n <namespace> -- nslookup kubernetes.default
   ↓
2. Check CoreDNS health:
   kubectl get pods -n kube-system -l k8s-app=kube-dns
   kubectl logs -n kube-system -l k8s-app=kube-dns
   ↓
3. Verify DNS service:
   kubectl get svc -n kube-system kube-dns
   kubectl get endpoints -n kube-system kube-dns
   ↓
4. Check pod DNS config:
   kubectl exec <pod> -n <namespace> -- cat /etc/resolv.conf
   ↓
5. Fix if needed:
   - Restart CoreDNS: kubectl rollout restart -n kube-system deployment/coredns
   - Check network policies allow DNS (port 53)
   - Verify kubelet configuration
```

---

## Resource and Performance Workflow

### High Resource Usage Investigation

```
1. Identify resource hog:
   kubectl top nodes
   kubectl top pods --all-namespaces
   ↓
2. Check specific pod:
   kubectl top pod <pod-name> -n <namespace> --containers
   kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Limits"
   ↓
3. Analyze application:
   - Memory leak? → Check logs for errors
   - CPU spike? → Profile application
   - Check resource requests/limits appropriate?
   ↓
4. Take action:
   - Increase limits if legitimate usage
   - Fix application if bug/leak
   - Implement HPA if scaling needed
   - Add resource quotas to prevent overconsumption
```

### Node Resource Exhaustion Workflow

```
1. Check node status:
   kubectl get nodes
   kubectl describe node <node-name>
   ↓
2. Look for pressure conditions:
   - MemoryPressure
   - DiskPressure
   - PIDPressure
   ↓
3. Check node resources:
   kubectl top node <node-name>
   ↓
4. Find resource consumers:
   kubectl describe node <node-name> | grep -A 20 "Allocated resources"
   ↓
5. Actions:
   - Evict non-critical pods
   - Add more nodes
   - Adjust resource requests/limits
   - Clean up disk space if DiskPressure
```

---

## Storage Troubleshooting Workflow

### PVC Binding Issues Workflow

```
1. Check PVC status:
   kubectl get pvc -n <namespace>
   kubectl describe pvc <pvc-name> -n <namespace>
   ↓
2. Check for matching PV:
   kubectl get pv
   ↓
   No matching PV? → Check:
   - Storage class exists: kubectl get storageclass
   - Dynamic provisioner working
   - Manual PV needed?
   ↓
3. Verify storage class:
   kubectl describe storageclass <class-name>
   ↓
4. Check provisioner logs (if dynamic):
   kubectl logs -n kube-system <provisioner-pod>
   ↓
5. Fix:
   - Create matching PV (static)
   - Fix storage class configuration (dynamic)
   - Verify provisioner is running
```

---

## Deployment and Rollout Workflow

### Stuck Deployment Workflow

```
1. Check rollout status:
   kubectl rollout status deployment/<name> -n <namespace>
   ↓
2. Check replica sets:
   kubectl get rs -n <namespace>
   kubectl describe rs <new-replicaset> -n <namespace>
   ↓
3. Check new pod status:
   kubectl get pods -n <namespace> -l app=<app-label>
   ↓
   Pods failing? → Follow pod troubleshooting workflow
   ↓
4. Check rollout strategy:
   kubectl get deployment <name> -n <namespace> -o yaml | grep -A 10 strategy
   ↓
5. Options:
   - Fix pod issues and rollout will continue
   - Pause rollout: kubectl rollout pause deployment/<name>
   - Rollback: kubectl rollout undo deployment/<name>
   - Check revision history: kubectl rollout history deployment/<name>
```

---

## Quick Reference Commands

### Essential Debug Commands

```bash
# Pod debugging
kubectl get pods -n <namespace> -o wide
kubectl describe pod <pod> -n <namespace>
kubectl logs <pod> -n <namespace> [-c container]
kubectl logs <pod> -n <namespace> --previous
kubectl exec <pod> -n <namespace> -it -- /bin/sh

# Service debugging
kubectl get svc -n <namespace>
kubectl get endpoints -n <namespace>
kubectl describe svc <service> -n <namespace>

# Events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -n <namespace>

# Network debugging
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash

# Cluster health
kubectl get nodes
kubectl cluster-info
kubectl get componentstatuses
```

### Emergency Commands

```bash
# Delete stuck pod
kubectl delete pod <pod> -n <namespace> --force --grace-period=0

# Restart deployment
kubectl rollout restart deployment/<name> -n <namespace>

# Rollback deployment
kubectl rollout undo deployment/<name> -n <namespace>

# Cordon node (prevent new pods)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```
