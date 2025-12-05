# Kubernetes YAML Best Practices

## General YAML Best Practices

### Formatting and Style
- Use 2 spaces for indentation (not tabs)
- Keep lines under 80 characters when possible
- Use lowercase for keys
- Quote string values containing special characters
- Always specify apiVersion and kind
- Include metadata.name for all resources

### Resource Organization
- One resource per file for clarity (unless logically grouped)
- Use `---` to separate multiple resources in a single file
- Name files descriptively: `<resource-type>-<name>.yaml`

## Kubernetes-Specific Best Practices

### Metadata
```yaml
metadata:
  name: my-app
  namespace: production
  labels:
    app: my-app
    version: v1.0.0
    component: backend
    managed-by: kubectl
  annotations:
    description: "Backend service for my-app"
```

### Labels and Selectors
- Always include `app` label
- Use consistent label keys across resources
- Include version labels for rollout tracking
- Selectors must match pod labels exactly

### Resource Limits and Requests
Always specify both requests and limits:
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "250m"
  limits:
    memory: "128Mi"
    cpu: "500m"
```

### Probes
Always define liveness and readiness probes:
```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Security
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

### Image Management
```yaml
image: registry.example.com/my-app:v1.2.3  # Always use specific tags
imagePullPolicy: IfNotPresent  # Or Always for :latest
```

## Common Validation Issues

### Missing Required Fields
- `apiVersion` and `kind` are always required
- `metadata.name` is required for all resources
- `spec.selector` must be specified for Deployments/Services
- `spec.template.spec.containers` must have at least one container

### Selector Mismatches
Deployment selector must match pod template labels:
```yaml
# Deployment
spec:
  selector:
    matchLabels:
      app: my-app  # Must match pod labels below
  template:
    metadata:
      labels:
        app: my-app  # Must match selector above
```

### Invalid Values
- CPU: Use millicore notation (e.g., "500m") or fractional (e.g., "0.5")
- Memory: Use Mi, Gi notation (e.g., "512Mi")
- Port numbers: Must be 1-65535
- DNS names: Must be lowercase alphanumeric with hyphens

### Namespace Issues
- Not all resources are namespaced (e.g., ClusterRole, PersistentVolume)
- Services must be in the same namespace as the pods they target
- Default namespace is "default" if not specified

## CRD-Specific Considerations

### API Version Compatibility
- Check the CRD version installed in the cluster
- Use the correct apiVersion for the CRD
- Be aware of deprecations (e.g., v1alpha1 → v1beta1 → v1)

### Required Fields
- CRDs often have custom required fields in spec
- Check the CRD documentation for field requirements
- Use kubectl explain <kind> to see field documentation

### Validation
- CRDs may have custom validation rules
- OpenAPI schema validation is stricter in newer K8s versions
- Use dry-run to catch validation errors before applying

## Deprecation Warnings

### Common Deprecated APIs
- `extensions/v1beta1` → `apps/v1` (Deployments, DaemonSets)
- `networking.k8s.io/v1beta1` → `networking.k8s.io/v1` (Ingress)
- `policy/v1beta1` → `policy/v1` (PodDisruptionBudget)

Always use the latest stable API version.
