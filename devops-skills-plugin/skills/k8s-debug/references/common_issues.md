# Common Kubernetes Issues and Troubleshooting

## Pod Issues

### CrashLoopBackOff

**Symptoms:**
- Pod repeatedly crashes and restarts
- Status shows `CrashLoopBackOff`
- Increasing restart count

**Common Causes:**
1. Application error causing immediate exit
2. Missing environment variables or configuration
3. Insufficient resources (memory/CPU)
4. Failed health checks (liveness probe)
5. Missing dependencies or volumes

**Debugging Steps:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# View current logs
kubectl logs <pod-name> -n <namespace>

# View previous container logs (from crashed container)
kubectl logs <pod-name> -n <namespace> --previous

# Check resource limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 resources

# Check liveness/readiness probes
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 livenessProbe
```

**Solutions:**
- Fix application code causing crashes
- Add missing environment variables via ConfigMap/Secret
- Increase resource limits
- Adjust or remove overly aggressive liveness probes
- Ensure all required volumes are mounted and accessible

---

### ImagePullBackOff / ErrImagePull

**Symptoms:**
- Pod status shows `ImagePullBackOff` or `ErrImagePull`
- Pod fails to start
- Events show image pull errors

**Common Causes:**
1. Image doesn't exist or wrong image name/tag
2. Private registry requires authentication
3. Network issues accessing registry
4. Image pull secrets missing or incorrect
5. Registry rate limiting

**Debugging Steps:**
```bash
# Check exact error message
kubectl describe pod <pod-name> -n <namespace>

# Verify image name and tag
kubectl get pod <pod-name> -n <namespace> -o yaml | grep image:

# Check image pull secrets
kubectl get pod <pod-name> -n <namespace> -o yaml | grep imagePullSecrets -A 2

# List secrets in namespace
kubectl get secrets -n <namespace>

# Test image pull manually on node
docker pull <image-name>
```

**Solutions:**
- Verify image exists in registry: `docker pull <image>`
- Create image pull secret: `kubectl create secret docker-registry <secret-name> --docker-server=<registry> --docker-username=<user> --docker-password=<pass>`
- Add imagePullSecrets to pod spec
- Use correct image tag (avoid `latest` in production)
- Check registry credentials and permissions

---

### Pending Pods

**Symptoms:**
- Pod stuck in `Pending` state
- Pod never gets scheduled

**Common Causes:**
1. Insufficient cluster resources (CPU/memory)
2. No nodes match pod's node selector
3. Taints on nodes prevent scheduling
4. PersistentVolumeClaim not bound
5. Pod affinity/anti-affinity rules cannot be satisfied

**Debugging Steps:**
```bash
# Check scheduling events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe nodes

# Check PVC status
kubectl get pvc -n <namespace>

# Check node selectors and taints
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 nodeSelector
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints
```

**Solutions:**
- Add more nodes to cluster or free up resources
- Remove/adjust node selectors
- Add tolerations for taints
- Create or fix PersistentVolume for PVC
- Adjust affinity/anti-affinity rules
- Check resource quotas: `kubectl get resourcequota -n <namespace>`

---

### OOMKilled (Out of Memory)

**Symptoms:**
- Pod restarts with exit code 137
- Last state shows `OOMKilled`
- Container was killed due to memory

**Debugging Steps:**
```bash
# Check pod status and last state
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 lastState

# Check memory limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 resources

# Check actual memory usage
kubectl top pod <pod-name> -n <namespace> --containers
```

**Solutions:**
- Increase memory limits
- Fix memory leaks in application
- Optimize application memory usage
- Add memory requests/limits if missing

---

## Service and Networking Issues

### Service Not Accessible

**Symptoms:**
- Cannot connect to service from within or outside cluster
- Connection timeout or refused

**Common Causes:**
1. Service selector doesn't match pod labels
2. Target port mismatch
3. Network policies blocking traffic
4. Service type incorrect (ClusterIP vs LoadBalancer)
5. Endpoints not created

**Debugging Steps:**
```bash
# Check service configuration
kubectl get svc <service-name> -n <namespace> -o yaml

# Check endpoints
kubectl get endpoints <service-name> -n <namespace>

# Check pod labels
kubectl get pods -n <namespace> --show-labels

# Test from another pod
kubectl run tmp-shell --rm -i --tty --image nicolaka/netshoot -- /bin/bash
# Inside pod: curl <service-name>.<namespace>.svc.cluster.local

# Check network policies
kubectl get networkpolicies -n <namespace>
```

**Solutions:**
- Ensure service selector matches pod labels exactly
- Verify port and targetPort are correct
- Check network policies allow traffic
- Use correct service type for use case
- Ensure pods are running and ready

---

### DNS Resolution Failures

**Symptoms:**
- Pods cannot resolve service names
- `nslookup` or `dig` commands fail
- DNS timeouts

**Common Causes:**
1. CoreDNS not running properly
2. DNS service not accessible
3. Pod DNS config incorrect
4. Network policies blocking DNS

**Debugging Steps:**
```bash
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl exec <pod-name> -n <namespace> -- nslookup kubernetes.default

# Check pod DNS config
kubectl exec <pod-name> -n <namespace> -- cat /etc/resolv.conf

# Check DNS service
kubectl get svc -n kube-system kube-dns
```

**Solutions:**
- Restart CoreDNS: `kubectl rollout restart deployment/coredns -n kube-system`
- Verify DNS service endpoints exist
- Check network policies allow port 53
- Verify kubelet DNS settings

---

## Volume and Storage Issues

### PersistentVolumeClaim Pending

**Symptoms:**
- PVC stuck in `Pending` state
- Pod cannot start due to volume mount

**Debugging Steps:**
```bash
# Check PVC status
kubectl describe pvc <pvc-name> -n <namespace>

# List available PVs
kubectl get pv

# Check storage class
kubectl get storageclass
```

**Solutions:**
- Create matching PersistentVolume
- Verify storage class exists and is correct
- Check volume provisioner is working
- Ensure sufficient storage available

---

## Resource and Configuration Issues

### ConfigMap/Secret Not Found

**Symptoms:**
- Pod fails to start
- Events show volume mount errors
- Missing environment variables

**Debugging Steps:**
```bash
# List ConfigMaps
kubectl get configmaps -n <namespace>

# List Secrets
kubectl get secrets -n <namespace>

# Check pod configuration
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 env
```

**Solutions:**
- Create missing ConfigMap/Secret
- Verify names match exactly (case-sensitive)
- Check namespace matches
- Ensure keys referenced exist in ConfigMap/Secret

---

## Performance Issues

### High CPU/Memory Usage

**Debugging Steps:**
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n <namespace>

# Check resource requests/limits
kubectl describe pod <pod-name> -n <namespace> | grep -A 5 Limits

# Get detailed metrics
kubectl get --raw /apis/metrics.k8s.io/v1beta1/namespaces/<namespace>/pods/<pod-name>
```

**Solutions:**
- Optimize application code
- Adjust resource requests/limits
- Scale horizontally with more replicas
- Implement caching or performance improvements

---

## Deployment Issues

### Deployment Stuck/Not Rolling Out

**Symptoms:**
- New version not deployed
- Old pods still running
- Rollout stuck

**Debugging Steps:**
```bash
# Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Check rollout history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Check replica sets
kubectl get rs -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

**Solutions:**
- Check if new pods are failing (CrashLoopBackOff, ImagePullBackOff)
- Verify readiness probes are passing
- Check deployment strategy settings
- Rollback if needed: `kubectl rollout undo deployment/<deployment-name> -n <namespace>`
