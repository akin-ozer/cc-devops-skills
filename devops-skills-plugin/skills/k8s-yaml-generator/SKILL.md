---
name: k8s-yaml-generator
description: Comprehensive toolkit for generating, validating, and managing Kubernetes YAML resources. Use this skill when creating Kubernetes manifests (Deployments, Services, ConfigMaps, StatefulSets, etc.), working with Custom Resource Definitions (CRDs), or generating production-ready K8s configurations.
---

# K8s Generator

## Overview

This skill provides a complete workflow for generating Kubernetes YAML resources with built-in validation and intelligent CRD support. Generate production-ready manifests for any Kubernetes resource type, with automatic validation and version-aware documentation lookup for custom resources.

## When to Use This Skill

Use this skill when:
- Generating Kubernetes YAML manifests (Deployments, Services, ConfigMaps, etc.)
- Creating custom resources (ArgoCD Applications, Istio VirtualServices, etc.)
- Building production-ready Kubernetes configurations
- Need to ensure YAML validity and K8s API compliance
- Working with CRDs that require documentation lookup

## Core Workflow

Follow this workflow when generating Kubernetes YAML resources:

### 1. Understand Requirements

**Gather information about:**
- Resource type (Deployment, Service, ConfigMap, CRD, etc.)
- Target Kubernetes version (if specified)
- Application requirements (replicas, ports, volumes, etc.)
- Environment-specific needs (namespaces, labels, annotations)
- Custom resource specifications (for CRDs)

**For CRDs specifically:**
- Identify the CRD type and version (e.g., ArgoCD Application v1alpha1, Istio VirtualService v1beta1)
- Determine if documentation is needed (complex CRDs, unfamiliar APIs)

### 2. Fetch CRD Documentation (if needed)

**When dealing with Custom Resource Definitions (CRDs):**

**IMPORTANT: Always consider version compatibility when working with CRDs**

**Step 2a: Identify the CRD and Version**
- Extract the CRD's apiVersion and kind from the user request
- Examples:
  - ArgoCD Application: `apiVersion: argoproj.io/v1alpha1, kind: Application`
  - Istio VirtualService: `apiVersion: networking.istio.io/v1beta1, kind: VirtualService`
  - Cert-Manager Certificate: `apiVersion: cert-manager.io/v1, kind: Certificate`

**Step 2b: Resolve Library ID using Context7 MCP**

Use the `mcp__context7__resolve-library-id` tool to find the correct library:

```
libraryName: "<project-name>"
```

Examples:
- For ArgoCD: `libraryName: "argo-cd"`
- For Istio: `libraryName: "istio"`
- For Cert-Manager: `libraryName: "cert-manager"`

**The tool will return:**
- A list of matching libraries with their Context7-compatible IDs (format: `/org/project` or `/org/project/version`)
- Benchmark scores indicating documentation quality
- Code snippet counts showing coverage

**Select the most appropriate library based on:**
- Name match accuracy
- Target version compatibility (if user specified a version)
- Benchmark score (higher is better, 100 is highest)
- Documentation coverage (code snippet count)

**Step 2c: Fetch Documentation using Context7 MCP**

Use the `mcp__context7__get-library-docs` tool with the selected library ID:

```
context7CompatibleLibraryID: "/org/project/version"
topic: "specific CRD type or feature"
page: 1
```

Examples:
- For ArgoCD Application CRD: `context7CompatibleLibraryID: "/argoproj/argo-cd/v2.9.0", topic: "application crd spec", page: 1`
- For Istio VirtualService: `context7CompatibleLibraryID: "/istio/istio/1.20.0", topic: "virtualservice", page: 1`

**If context is insufficient:**
- Increment the `page` parameter (page: 2, page: 3, etc.) with the same topic
- Try different topic keywords
- Maximum page number is 10

**Step 2d: Fallback to Web Search**

**If context7 MCP fails or returns insufficient information:**
- Use the `WebSearch` tool with version-specific queries
- Include the version in the search query: `"<CRD-name> <version> spec documentation"`
- Examples:
  - `"ArgoCD Application v1alpha1 spec documentation"`
  - `"Istio VirtualService v1beta1 configuration"`
  - `"cert-manager Certificate v1 spec fields"`

**CRITICAL: Always include version information in web searches to ensure compatibility**

### 3. Generate YAML Resource

**Apply Kubernetes best practices:**

**General Best Practices:**
- Use explicit API versions (avoid deprecated versions)
- Include meaningful labels for organization and selection (use [Kubernetes recommended labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/)):
  ```yaml
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-abc123
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: frontend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: claude-code
  ```
- Add annotations for metadata and tooling:
  ```yaml
  annotations:
    description: "Purpose of this resource"
    contact: "team@example.com"
  ```
- Specify resource requests and limits (for Pods):
  ```yaml
  resources:
    requests:
      memory: "64Mi"
      cpu: "250m"
    limits:
      memory: "128Mi"
      cpu: "500m"
  ```
- Use namespaces for multi-tenancy
- Implement health checks (livenessProbe, readinessProbe)
- Follow naming conventions (lowercase, hyphens, descriptive)

**Security Best Practices:**
- Never run containers as root (use `securityContext`)
- Implement Pod Security Standards
- Use least-privilege RBAC
- Store secrets in Secret objects, not ConfigMaps
- Use `imagePullPolicy: Always` or `IfNotPresent` appropriately

**For CRDs:**
- Reference the fetched documentation for accurate spec fields
- Include all required fields
- Use appropriate defaults for optional fields
- Add comments explaining complex configurations

**Common Resource Templates:**

**Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  namespace: default
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/version: "1.0.0"
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: claude-code
spec:
  replicas: 3
  selector:
    matchLabels:
      app.kubernetes.io/name: myapp
      app.kubernetes.io/instance: myapp-prod
  template:
    metadata:
      labels:
        app.kubernetes.io/name: myapp
        app.kubernetes.io/instance: myapp-prod
        app.kubernetes.io/version: "1.0.0"
        app.kubernetes.io/component: backend
        app.kubernetes.io/part-of: myplatform
        app.kubernetes.io/managed-by: claude-code
    spec:
      containers:
      - name: myapp
        image: myapp:1.0.0
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "250m"
          limits:
            memory: "128Mi"
            cpu: "500m"
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

**Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  namespace: default
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/component: backend
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: claude-code
spec:
  type: ClusterIP  # or LoadBalancer, NodePort
  selector:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8080
    name: http
```

**ConfigMap:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  namespace: default
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/component: config
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: claude-code
data:
  app.properties: |
    key1=value1
    key2=value2
  config.json: |
    {
      "setting": "value"
    }
```

### 4. Validate Generated YAML

**CRITICAL: Always validate generated YAML using the devops-skills:k8s-yaml-validator skill**

After generating the YAML resource, immediately invoke the devops-skills:k8s-yaml-validator skill:

**Use the Skill tool:**
```
Skill: devops-skills:k8s-yaml-validator
```

**The devops-skills:k8s-yaml-validator skill will:**
1. Validate YAML syntax using `yamllint`
2. Validate Kubernetes API compliance using `kubeconform`
3. Check for best practices and common issues
4. For CRDs: Automatically detect custom resources and fetch documentation if needed
5. Perform dry-run validation against the cluster (if available)

**Wait for validation results and address any issues:**
- Syntax errors: Fix YAML formatting issues
- Schema errors: Correct field names, types, or structure
- Best practice violations: Update according to recommendations
- CRD validation errors: Re-fetch documentation and correct spec fields

**If validation fails:**
- Review the error messages carefully
- Update the YAML to address the issues
- Re-run validation
- Repeat until validation passes

### 5. Deliver the Resource

**Once validation passes:**
- Present the validated YAML to the user
- Include a summary of what was generated
- Highlight any important configuration choices
- Suggest next steps (kubectl apply, customization, etc.)

**Format:**
```yaml
# Generated and validated Kubernetes resource
# Resource: <Type>
# Namespace: <namespace>
# Validation: Passed

<YAML content here>
```

**Suggest next steps:**
```bash
# Apply the resource
kubectl apply -f <filename>.yaml

# Verify the resource
kubectl get <resource-type> <name> -n <namespace>

# Check status
kubectl describe <resource-type> <name> -n <namespace>
```

## Advanced Features

### Multi-Resource Generation

When generating multiple related resources:
1. Create each resource following the core workflow
2. Use consistent labels across resources for grouping
3. Consider resource dependencies (create ConfigMaps before Deployments)
4. Validate each resource individually with devops-skills:k8s-yaml-validator
5. Optionally combine into a single multi-document YAML file using `---` separator

**Example multi-document YAML:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: myapp-config
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/part-of: myplatform
data:
  key: value
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/part-of: myplatform
spec:
  # deployment spec with matching labels
---
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/part-of: myplatform
spec:
  # service spec with matching selector
```

### Version-Specific Generation

When targeting specific Kubernetes versions:
- Use appropriate API versions (check deprecations)
- Reference version-specific features
- Note any version-specific caveats
- Example: Ingress moved from `extensions/v1beta1` to `networking.k8s.io/v1` in K8s 1.19+

### Namespace Management

Best practices for namespace handling:
- Always specify namespace in metadata (except for cluster-scoped resources)
- Use namespaces for environment separation (dev, staging, prod)
- Consider namespace-scoped resources vs cluster-scoped
- Include namespace creation YAML if needed

## Common CRDs and Examples

### ArgoCD Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/part-of: myplatform
    app.kubernetes.io/managed-by: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: HEAD
    path: manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: myapp
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Istio VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/component: networking
    app.kubernetes.io/part-of: myplatform
spec:
  hosts:
  - myapp.example.com
  gateways:
  - myapp-gateway
  http:
  - route:
    - destination:
        host: myapp-service
        port:
          number: 8080
```

### Cert-Manager Certificate

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
  labels:
    app.kubernetes.io/name: myapp
    app.kubernetes.io/instance: myapp-prod
    app.kubernetes.io/component: tls
    app.kubernetes.io/part-of: myplatform
spec:
  secretName: myapp-tls-secret
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - myapp.example.com
```

## Troubleshooting

### CRD Documentation Not Found
- **Issue**: Context7 MCP cannot find the CRD documentation
- **Solution**:
  - Try alternative search terms (project name variations)
  - Use WebSearch as fallback with version-specific queries
  - Check the official project documentation directly

### Validation Failures
- **Issue**: devops-skills:k8s-yaml-validator reports errors
- **Solution**:
  - Read error messages carefully
  - Check field names and types against documentation
  - Verify API version compatibility
  - Ensure required fields are present

### Version Mismatches
- **Issue**: Generated YAML uses wrong API version
- **Solution**:
  - Confirm target Kubernetes version with user
  - Check API deprecation status
  - Update apiVersion field to correct version
  - Re-validate

## Integration with Other Skills

This skill works seamlessly with:
- **devops-skills:k8s-yaml-validator**: Automatic validation of generated resources
- **k8s-debug**: Troubleshooting deployed resources
- **helm-validator**: Validating Helm charts that use these resources

## Summary

The k8s-generator skill provides:
1. ✅ Intelligent YAML generation for any Kubernetes resource
2. ✅ Automatic validation via devops-skills:k8s-yaml-validator
3. ✅ Version-aware CRD documentation lookup via context7 MCP
4. ✅ Fallback web search for CRD specifications
5. ✅ Best practices and security considerations
6. ✅ Production-ready configurations

Always follow the core workflow: Understand → Fetch CRD Docs (if needed) → Generate → Validate → Deliver
