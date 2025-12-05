# Kubernetes YAML Best Practices

This reference provides comprehensive best practices for creating, maintaining, and validating Kubernetes resources in Helm charts.

## General YAML Best Practices

### Formatting and Style

- Use 2 spaces for indentation (not tabs)
- Keep lines under 120 characters when possible
- Use lowercase for keys
- Quote string values containing special characters
- Always specify apiVersion and kind
- Include metadata.name for all resources
- Use consistent naming conventions (lowercase, hyphens for separators)

### Resource Organization

- One resource per file for clarity (unless logically grouped)
- Use `---` to separate multiple resources in a single file
- Name files descriptively: `<resource-type>-<name>.yaml`
- Group related resources together (e.g., deployment + service + configmap)

## Metadata Best Practices

### Standard Metadata Structure

```yaml
metadata:
  name: my-app
  namespace: production
  labels:
    app.kubernetes.io/name: my-app
    app.kubernetes.io/instance: my-app-prod
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: my-system
    app.kubernetes.io/managed-by: helm
    helm.sh/chart: my-app-1.0.0
  annotations:
    description: "Backend service for my-app"
    prometheus.io/scrape: "true"
    prometheus.io/port: "8080"
```

### Kubernetes Recommended Labels

Always include these standard labels for better tooling integration:

| Label | Description | Example |
|-------|-------------|---------|
| `app.kubernetes.io/name` | Application name | `nginx` |
| `app.kubernetes.io/instance` | Unique instance identifier | `nginx-prod` |
| `app.kubernetes.io/version` | Application version | `1.21.0` |
| `app.kubernetes.io/component` | Component within architecture | `frontend` |
| `app.kubernetes.io/part-of` | Higher-level application | `wordpress` |
| `app.kubernetes.io/managed-by` | Tool managing the resource | `helm` |

### Helm-Specific Labels

```yaml
labels:
  helm.sh/chart: {{ include "mychart.chart" . }}
  app.kubernetes.io/managed-by: {{ .Release.Service }}
```

## Labels and Selectors

### Selector Best Practices

- Selectors must match pod labels exactly
- Use immutable selectors (they cannot be changed after creation)
- Keep selector labels minimal but unique

**Good:**
```yaml
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
      app.kubernetes.io/instance: my-app-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: my-app
        app.kubernetes.io/instance: my-app-prod
        app.kubernetes.io/version: "1.0.0"  # Additional labels OK
```

**Bad:**
```yaml
spec:
  selector:
    matchLabels:
      app: my-app
      version: "1.0.0"  # Version in selector prevents rolling updates!
```

### Label Key Conventions

- Use DNS subdomain format for prefixed keys: `prefix/key`
- Keys without prefix are private to the user
- Standard prefixes: `app.kubernetes.io/`, `helm.sh/`, `kubernetes.io/`

## Resource Limits and Requests

### Why They Matter

- **Requests**: Minimum resources guaranteed to the container
- **Limits**: Maximum resources the container can use
- Required for proper scheduling, QoS class assignment, and cluster stability

### Recommended Configuration

```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### Guidelines by Resource Type

| Resource Type | Requests | Limits | Notes |
|---------------|----------|--------|-------|
| CPU | Set always | Optional | Consider burstable workloads |
| Memory | Set always | Set always | Prevents OOM kills |
| Ephemeral Storage | Optional | Recommended | For disk-intensive apps |

### QoS Classes

Kubernetes assigns Quality of Service classes based on resource settings:

1. **Guaranteed**: requests == limits for all containers
2. **Burstable**: At least one container has requests < limits
3. **BestEffort**: No requests or limits set (not recommended)

```yaml
# Guaranteed QoS
resources:
  requests:
    memory: "128Mi"
    cpu: "500m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### Memory Guidelines

- Set memory limits to prevent OOM kills affecting other pods
- Memory is incompressible - exceeding limits causes termination
- Monitor actual usage before setting production values

### CPU Guidelines

- CPU is compressible - exceeding limits causes throttling, not termination
- Consider not setting CPU limits for burstable workloads
- Use millicores: `100m` = 0.1 CPU core

## Probes Configuration

### Liveness Probe

Determines if the container should be restarted:

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
    httpHeaders:
      - name: X-Health-Check
        value: liveness
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
  successThreshold: 1
```

### Readiness Probe

Determines if the container can receive traffic:

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 3
  successThreshold: 1
```

### Startup Probe

For slow-starting containers (Kubernetes 1.18+):

```yaml
startupProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 30  # 30 * 10 = 300s max startup time
  successThreshold: 1
```

### Probe Types

| Type | Use Case | Example |
|------|----------|---------|
| `httpGet` | HTTP endpoints | REST APIs, web apps |
| `tcpSocket` | TCP connections | Databases, message queues |
| `exec` | Custom scripts | Complex health checks |
| `grpc` | gRPC services | gRPC health protocol |

### Probe Best Practices

- **Liveness**: Check if app is running, not dependencies
- **Readiness**: Check if app can serve traffic (including dependencies)
- **Startup**: Use for slow-starting apps instead of long `initialDelaySeconds`
- Set appropriate timeouts to prevent false positives
- Don't make probes too aggressive (high CPU overhead)

## Security Context

### Pod-Level Security Context

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 3000
    fsGroup: 2000
    fsGroupChangePolicy: "OnRootMismatch"
    seccompProfile:
      type: RuntimeDefault
```

### Container-Level Security Context

```yaml
containers:
  - name: app
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      runAsNonRoot: true
      runAsUser: 1000
      capabilities:
        drop:
          - ALL
        add:
          - NET_BIND_SERVICE  # Only if needed
      seccompProfile:
        type: RuntimeDefault
```

### Security Context Fields Explained

| Field | Level | Description |
|-------|-------|-------------|
| `runAsNonRoot` | Pod/Container | Prevents running as root |
| `runAsUser` | Pod/Container | Specifies UID to run as |
| `runAsGroup` | Pod/Container | Specifies GID to run as |
| `fsGroup` | Pod | Group ownership for volumes |
| `readOnlyRootFilesystem` | Container | Makes root filesystem read-only |
| `allowPrivilegeEscalation` | Container | Prevents privilege escalation |
| `capabilities` | Container | Linux capabilities management |
| `seccompProfile` | Pod/Container | Syscall filtering |

### Recommended Security Baseline

```yaml
spec:
  securityContext:
    runAsNonRoot: true
    seccompProfile:
      type: RuntimeDefault
  containers:
    - name: app
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

## Image Management

### Image Specification Best Practices

```yaml
containers:
  - name: app
    image: registry.example.com/my-app:v1.2.3
    imagePullPolicy: IfNotPresent
```

### Image Pull Policy

| Policy | When to Use |
|--------|-------------|
| `Always` | For `:latest` tags or mutable tags |
| `IfNotPresent` | For immutable tags (recommended) |
| `Never` | For pre-loaded images (rare) |

### Image Best Practices

- **Always use specific tags**: Never use `:latest` in production
- **Use digest for immutability**: `image@sha256:abc123...`
- **Use private registries**: For security and reliability
- **Scan images**: Implement vulnerability scanning in CI/CD

```yaml
# Recommended: Specific tag
image: nginx:1.21.6

# Better: Digest for immutability
image: nginx@sha256:2834dc507516af02784808c5f48b7cbe38b8ed5d0f4837f16e78d00deb7e7767

# Avoid: Mutable tags
image: nginx:latest  # Don't do this in production
```

## Pod Disruption Budgets

### Why PDBs Matter

Pod Disruption Budgets ensure high availability during voluntary disruptions like:
- Node drains
- Cluster upgrades
- Deployment rollouts

### PDB Configuration

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: my-app-pdb
spec:
  # Option 1: Minimum available pods
  minAvailable: 2

  # Option 2: Maximum unavailable pods (use one, not both)
  # maxUnavailable: 1

  selector:
    matchLabels:
      app.kubernetes.io/name: my-app
```

### PDB Best Practices

- Set PDB for all production workloads with multiple replicas
- Use `minAvailable` when you need minimum capacity guarantee
- Use `maxUnavailable` when you want to limit disruption rate
- Don't set `minAvailable` equal to replicas (blocks all disruptions)

```yaml
# Good: Allows 1 pod to be unavailable
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ include "mychart.fullname" . }}-pdb
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      {{- include "mychart.selectorLabels" . | nindent 6 }}
```

## Horizontal Pod Autoscaler

### HPA Configuration

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
        - type: Pods
          value: 4
          periodSeconds: 15
      selectPolicy: Max
```

### HPA Best Practices

- Always set resource requests (required for CPU/memory-based scaling)
- Set appropriate `minReplicas` for base capacity
- Use stabilization windows to prevent flapping
- Consider custom metrics for business-specific scaling
- Don't use HPA with `replicas` field in Deployment (conflicts)

### Helm Template for HPA

```yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "mychart.fullname" . }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "mychart.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
{{- end }}
```

## Network Policies

### Default Deny All

Start with a default deny policy, then allow specific traffic:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: my-namespace
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allow Specific Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### Allow Egress to External Services

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-egress-to-database
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
      ports:
        - protocol: TCP
          port: 5432
    # Allow DNS resolution
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

### Network Policy Best Practices

- Start with default deny, then allow specific traffic
- Always allow DNS egress (UDP port 53)
- Use namespace selectors for cross-namespace communication
- Label namespaces for policy targeting
- Test policies in staging before production

## Service Configuration

### Service Types

| Type | Use Case |
|------|----------|
| `ClusterIP` | Internal cluster communication (default) |
| `NodePort` | External access via node ports (30000-32767) |
| `LoadBalancer` | Cloud provider load balancers |
| `ExternalName` | DNS CNAME for external services |

### Service Best Practices

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "mychart.selectorLabels" . | nindent 4 }}
```

### Named Ports

Always use named ports for clarity:

```yaml
# In Deployment
ports:
  - name: http
    containerPort: 8080
    protocol: TCP
  - name: metrics
    containerPort: 9090
    protocol: TCP

# In Service
ports:
  - name: http
    port: 80
    targetPort: http  # References named port
```

## ConfigMaps and Secrets

### ConfigMap Best Practices

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}-config
data:
  # For simple key-value pairs
  LOG_LEVEL: "info"
  MAX_CONNECTIONS: "100"

  # For file content
  app.properties: |
    server.port=8080
    server.host=0.0.0.0
```

### Secret Best Practices

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mychart.fullname" . }}-secret
type: Opaque
data:
  # Base64 encoded values
  password: {{ .Values.password | b64enc | quote }}
  api-key: {{ .Values.apiKey | b64enc | quote }}
stringData:
  # Plain text (will be encoded)
  config.yaml: |
    database:
      host: {{ .Values.database.host }}
```

### Mounting as Environment Variables

```yaml
env:
  - name: LOG_LEVEL
    valueFrom:
      configMapKeyRef:
        name: my-config
        key: LOG_LEVEL
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-secret
        key: password
```

### Mounting as Files

```yaml
volumes:
  - name: config
    configMap:
      name: my-config
  - name: secrets
    secret:
      secretName: my-secret
      defaultMode: 0400

volumeMounts:
  - name: config
    mountPath: /etc/config
    readOnly: true
  - name: secrets
    mountPath: /etc/secrets
    readOnly: true
```

## Common Validation Issues

### Missing Required Fields

| Issue | Fix |
|-------|-----|
| Missing `apiVersion` | Add appropriate API version |
| Missing `kind` | Add resource kind |
| Missing `metadata.name` | Add resource name |
| Missing `spec.selector` | Add pod selector for Deployments/Services |
| Empty `containers` | Add at least one container |

### Selector Mismatches

```yaml
# Error: Selector doesn't match pod labels
spec:
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        application: my-app  # Wrong label key!
```

### Invalid Values

| Field | Valid Format | Example |
|-------|--------------|---------|
| CPU | Millicores or decimal | `500m`, `0.5` |
| Memory | Binary units | `512Mi`, `1Gi` |
| Port | 1-65535 | `8080` |
| DNS names | Lowercase alphanumeric with hyphens | `my-app-service` |

### Namespace Issues

- Not all resources are namespaced (e.g., ClusterRole, PersistentVolume)
- Services must be in the same namespace as pods they target
- Default namespace is "default" if not specified

## Deprecation Warnings

### Deprecated APIs

| Old API | New API | K8s Version |
|---------|---------|-------------|
| `extensions/v1beta1` Deployment | `apps/v1` | 1.16+ |
| `extensions/v1beta1` Ingress | `networking.k8s.io/v1` | 1.19+ |
| `networking.k8s.io/v1beta1` Ingress | `networking.k8s.io/v1` | 1.19+ |
| `policy/v1beta1` PodDisruptionBudget | `policy/v1` | 1.21+ |
| `policy/v1beta1` PodSecurityPolicy | Removed (use PSA) | 1.25+ |
| `autoscaling/v2beta1` HPA | `autoscaling/v2` | 1.23+ |
| `batch/v1beta1` CronJob | `batch/v1` | 1.21+ |

### Checking API Versions

```bash
# List available API versions
kubectl api-versions

# Check if resource supports specific version
kubectl api-resources | grep deployments
```

## CRD-Specific Considerations

### API Version Compatibility

- Check the CRD version installed in the cluster
- Use the correct apiVersion for the CRD
- Be aware of deprecations (e.g., v1alpha1 → v1beta1 → v1)

### Required Fields

- CRDs often have custom required fields in spec
- Check the CRD documentation for field requirements
- Use `kubectl explain <kind>` to see field documentation

### Validation

- CRDs may have custom validation rules
- OpenAPI schema validation is stricter in newer K8s versions
- Use dry-run to catch validation errors before applying

```bash
# Explain CRD fields
kubectl explain certificate.spec
kubectl explain certificate.spec.issuerRef
```

## Anti-Patterns to Avoid

### 1. Running as Root

```yaml
# Bad
securityContext:
  runAsUser: 0

# Good
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

### 2. Using Latest Tag

```yaml
# Bad
image: nginx:latest

# Good
image: nginx:1.21.6
```

### 3. No Resource Limits

```yaml
# Bad - No limits
containers:
  - name: app
    image: my-app:1.0

# Good - With limits
containers:
  - name: app
    image: my-app:1.0
    resources:
      limits:
        memory: "256Mi"
        cpu: "500m"
```

### 4. Privileged Containers

```yaml
# Bad
securityContext:
  privileged: true

# Good
securityContext:
  privileged: false
  allowPrivilegeEscalation: false
```

### 5. No Probes

```yaml
# Bad - No health checks
containers:
  - name: app

# Good - With probes
containers:
  - name: app
    livenessProbe:
      httpGet:
        path: /health
        port: 8080
    readinessProbe:
      httpGet:
        path: /ready
        port: 8080
```

## Summary Checklist

Before deploying Kubernetes resources, verify:

### Required
- [ ] `apiVersion` and `kind` are correct
- [ ] `metadata.name` follows naming conventions
- [ ] Labels include recommended Kubernetes labels
- [ ] Selectors match pod labels exactly
- [ ] At least one container is defined

### Recommended
- [ ] Resource requests and limits are set
- [ ] Liveness and readiness probes are configured
- [ ] Security context is defined (non-root, read-only fs)
- [ ] Image uses specific tag (not `latest`)
- [ ] Secrets are used for sensitive data (not ConfigMaps)

### Production
- [ ] Pod Disruption Budget is configured
- [ ] Network Policies are in place
- [ ] HPA is configured for scalable workloads
- [ ] Service accounts are properly scoped
- [ ] Pod anti-affinity for high availability