# Helm Chart Best Practices

This reference provides comprehensive best practices for creating, maintaining, and validating Helm charts.

## Chart Structure

### Required Files

Every Helm chart must have:

```
mychart/
  Chart.yaml     # Chart metadata
  values.yaml    # Default configuration values
  templates/     # Template directory
```

### Chart.yaml Structure

Use apiVersion v2 for Helm 3+ charts:

```yaml
apiVersion: v2
name: mychart
description: A Helm chart for Kubernetes
type: application  # or 'library' for helper charts
version: 0.1.0     # Chart version (SemVer)
appVersion: "1.16.0"  # Version of the app

# Optional but recommended
keywords:
  - web
  - application
home: https://github.com/example/mychart
sources:
  - https://github.com/example/mychart
maintainers:
  - name: Your Name
    email: your.email@example.com

# Dependencies
dependencies:
  - name: postgresql
    version: "~11.6.0"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled

# Kubernetes version constraint
kubeVersion: ">=1.21.0-0"
```

## Template Best Practices

### 1. Use Named Templates (Helpers)

Define reusable templates in `templates/_helpers.tpl`:

**Good:**
```yaml
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

**Usage:**
```yaml
metadata:
  name: {{ include "mychart.fullname" . }}
```

### 2. Use `include` Instead of `template`

**Good:**
```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

**Bad:**
```yaml
metadata:
  labels:
    {{- template "mychart.labels" . }}
```

**Why:** `include` allows piping the output to other functions like `nindent`, `indent`, `quote`, etc.

### 3. Always Quote String Values

**Good:**
```yaml
env:
  - name: DATABASE_HOST
    value: {{ .Values.database.host | quote }}
```

**Bad:**
```yaml
env:
  - name: DATABASE_HOST
    value: {{ .Values.database.host }}
```

**Why:** Prevents YAML parsing issues with special characters and ensures strings are treated as strings.

### 4. Use `required` for Critical Values

**Good:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  password: {{ required "A valid .Values.password is required!" .Values.password | b64enc }}
```

**Why:** Fails early with a helpful error message if required values are missing.

### 5. Provide Defaults with `default` Function

**Good:**
```yaml
replicas: {{ .Values.replicaCount | default 1 }}
```

**Why:** Makes charts more resilient and easier to use with minimal configuration.

### 6. Use `nindent` for Proper Indentation

**Good:**
```yaml
spec:
  template:
    metadata:
      labels:
        {{- include "mychart.labels" . | nindent 8 }}
```

**Bad:**
```yaml
spec:
  template:
    metadata:
      labels:
{{ include "mychart.labels" . | indent 8 }}
```

**Why:** `nindent` adds a newline before indenting, which is usually what you want in YAML.

### 7. Use `toYaml` for Complex Structures

**Good:**
```yaml
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

**Why:** Allows users to specify complex YAML structures in values without template complexity.

### 8. Conditional Resource Creation

**Good:**
```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "mychart.fullname" . }}
# ... ingress definition
{{- end }}
```

**Why:** Allows users to optionally enable/disable resources.

### 9. Use `with` for Scoping

**Good:**
```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

**Why:** Changes the scope of `.` to the specified value, making templates cleaner.

### 10. Template Comments

**Good:**
```yaml
{{- /*
This helper creates the fullname for resources.
It supports nameOverride and fullnameOverride values.
*/ -}}
{{- define "mychart.fullname" -}}
{{- end }}
```

**Bad:**
```yaml
# This creates the fullname
{{- define "mychart.fullname" -}}
{{- end }}
```

**Why:** Template comments (`{{- /* */ -}}`) are removed during rendering, while YAML comments (`#`) remain in output.

## Values File Best Practices

### 1. Use Flat Structures When Possible

**Good (Simple):**
```yaml
replicaCount: 1
imagePullPolicy: IfNotPresent
```

**Good (Related Settings):**
```yaml
image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.21.0"
```

**Bad (Overly Nested):**
```yaml
app:
  deployment:
    pod:
      container:
        image:
          repository: nginx
```

### 2. Document All Values

**Good:**
```yaml
# replicaCount is the number of pod replicas for the deployment
replicaCount: 1

# image configures the container image
image:
  # image.repository is the container image registry and name
  repository: nginx
  # image.pullPolicy is the image pull policy
  pullPolicy: IfNotPresent
  # image.tag overrides the image tag (default is chart appVersion)
  tag: "1.21.0"
```

**Why:** Makes charts self-documenting and easier to use.

### 3. Provide Sensible Defaults

**Good:**
```yaml
replicaCount: 1

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Why:** Charts should work out of the box with minimal configuration.

### 4. Use Boolean Flags for Feature Toggles

**Good:**
```yaml
ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: chart-example.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
```

**Why:** Makes it clear when features are optional and how to enable them.

### 5. Group Related Configuration

**Good:**
```yaml
autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  targetMemoryUtilizationPercentage: 80
```

### 6. Provide Empty Structures for Optional Config

**Good:**
```yaml
nodeSelector: {}
tolerations: []
affinity: {}
```

**Why:** Shows users what optional configurations are available.

## Kubernetes Resource Best Practices

### 1. Always Set Resource Limits and Requests

**Good:**
```yaml
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Why:** Ensures proper scheduling and prevents resource exhaustion.

### 2. Use Proper Label Conventions

**Good:**
```yaml
metadata:
  labels:
    app.kubernetes.io/name: {{ include "mychart.name" . }}
    app.kubernetes.io/instance: {{ .Release.Name }}
    app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
    app.kubernetes.io/managed-by: {{ .Release.Service }}
    helm.sh/chart: {{ include "mychart.chart" . }}
```

**Why:** Follows Kubernetes recommended labels for better tooling integration.

### 3. Use SecurityContext

**Good:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 2000
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

**Why:** Improves security posture.

### 4. Define Probes

**Good:**
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5
```

**Why:** Ensures Kubernetes can properly manage application health.

### 5. Use ConfigMaps and Secrets Appropriately

**Good:**
```yaml
# ConfigMap for non-sensitive config
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  app.conf: |
    {{- .Values.config | nindent 4 }}
```

```yaml
# Secret for sensitive data
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mychart.fullname" . }}
type: Opaque
data:
  password: {{ .Values.password | b64enc }}
```

## Template Function Reference

### String Functions

- `quote` - Quote a string
- `squote` - Single quote a string
- `trim` - Remove whitespace
- `trimSuffix` - Remove suffix
- `trimPrefix` - Remove prefix
- `upper` - Convert to uppercase
- `lower` - Convert to lowercase
- `title` - Title case
- `trunc` - Truncate string
- `repeat` - Repeat string
- `substr` - Substring
- `nospace` - Remove all whitespace

### Type Conversion

- `toYaml` - Convert to YAML
- `fromYaml` - Parse YAML
- `toJson` - Convert to JSON
- `fromJson` - Parse JSON
- `toString` - Convert to string
- `toStrings` - Convert list to strings

### Flow Control

- `default` - Provide default value
- `required` - Require a value
- `fail` - Fail with error message
- `coalesce` - Return first non-empty value

### Collections

- `list` - Create a list
- `dict` - Create a dictionary
- `merge` - Merge dictionaries
- `pick` - Pick keys from dictionary
- `omit` - Omit keys from dictionary
- `keys` - Get dictionary keys
- `values` - Get dictionary values

### Encoding

- `b64enc` - Base64 encode
- `b64dec` - Base64 decode
- `sha256sum` - SHA256 hash

## Testing Best Practices

### 1. Create Test Resources

**Good:**
```yaml
# templates/tests/test-connection.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "mychart.fullname" . }}-test-connection"
  annotations:
    "helm.sh/hook": test
spec:
  containers:
    - name: wget
      image: busybox
      command: ['wget']
      args: ['{{ include "mychart.fullname" . }}:{{ .Values.service.port }}']
  restartPolicy: Never
```

**Run tests:**
```bash
helm test <release-name>
```

### 2. Test with Multiple Values

```bash
# Test with production values
helm template my-release ./mychart -f values-prod.yaml

# Test with development values
helm template my-release ./mychart -f values-dev.yaml

# Test with overrides
helm template my-release ./mychart --set replicaCount=3
```

### 3. Validate Before Installing

```bash
# Lint the chart
helm lint ./mychart

# Dry-run install
helm install my-release ./mychart --dry-run --debug

# Validate against cluster
helm install my-release ./mychart --dry-run
```

## Security Best Practices

### 1. Don't Hardcode Secrets

**Bad:**
```yaml
data:
  password: cGFzc3dvcmQ=  # Don't do this!
```

**Good:**
```yaml
data:
  password: {{ .Values.password | b64enc }}
```

### 2. Use RBAC

**Good:**
```yaml
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "mychart.serviceAccountName" . }}
{{- end }}
```

### 3. Run as Non-Root

**Good:**
```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
```

### 4. Drop Capabilities

**Good:**
```yaml
securityContext:
  capabilities:
    drop:
      - ALL
```

## Performance Best Practices

### 1. Use `.helmignore`

Exclude unnecessary files from the chart package:

```
# .helmignore
.git/
.gitignore
*.md
.DS_Store
*.swp
test/
```

### 2. Minimize Template Complexity

**Good:**
```yaml
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

**Bad:**
```yaml
resources:
  {{- if .Values.resources.limits }}
  limits:
    {{- if .Values.resources.limits.cpu }}
    cpu: {{ .Values.resources.limits.cpu }}
    {{- end }}
    {{- if .Values.resources.limits.memory }}
    memory: {{ .Values.resources.limits.memory }}
    {{- end }}
  {{- end }}
  # ... more nested conditionals
```

### 3. Use Helpers for Repeated Logic

Don't repeat the same template logic in multiple places - extract it to a helper.

## Version Control Best Practices

### 1. Use SemVer for Chart Versions

- `MAJOR.MINOR.PATCH`
- Increment MAJOR for breaking changes
- Increment MINOR for new features
- Increment PATCH for bug fixes

### 2. Maintain a CHANGELOG

Document changes between versions.

### 3. Tag Releases

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Common Pitfalls to Avoid

### 1. Not Using `-` for Whitespace Control

**Bad:**
```yaml
{{ if .Values.enabled }}
  key: value
{{ end }}
```

**Good:**
```yaml
{{- if .Values.enabled }}
  key: value
{{- end }}
```

### 2. Not Truncating Resource Names

Kubernetes resource names must be <= 63 characters:

**Bad:**
```yaml
name: {{ .Release.Name }}-{{ .Chart.Name }}-deployment
```

**Good:**
```yaml
name: {{ include "mychart.fullname" . | trunc 63 | trimSuffix "-" }}
```

### 3. Using `template` Instead of `include`

Use `include` when you need to pipe the output to other functions.

### 4. Not Validating User Input

**Bad:**
```yaml
replicas: {{ .Values.replicaCount }}
```

**Good:**
```yaml
replicas: {{ required "replicaCount is required" .Values.replicaCount }}
```

### 5. Hardcoding Values in Templates

**Bad:**
```yaml
image: nginx:1.21.0
```

**Good:**
```yaml
image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
```

## Upgrade and Migration Best Practices

### 1. Use Helm Hooks

```yaml
metadata:
  annotations:
    "helm.sh/hook": pre-upgrade
    "helm.sh/hook-weight": "1"
    "helm.sh/hook-delete-policy": hook-succeeded
```

Available hooks:
- `pre-install`
- `post-install`
- `pre-upgrade`
- `post-upgrade`
- `pre-delete`
- `post-delete`
- `pre-rollback`
- `post-rollback`
- `test`

### 2. Test Upgrades

```bash
# Show what would change
helm diff upgrade my-release ./mychart

# Dry-run upgrade
helm upgrade my-release ./mychart --dry-run --debug
```

### 3. Support Rolling Back

Ensure your charts support rollback by not using hooks that delete critical resources.

## Documentation Best Practices

### 1. Create a Comprehensive README

Include:
- Chart description
- Prerequisites
- Installation instructions
- Configuration options (values)
- Examples
- Upgrade notes

### 2. Document Template Functions

Add comments to your `_helpers.tpl`:

```yaml
{{- /*
mychart.fullname generates a fully qualified application name.
It supports fullnameOverride and nameOverride values.
Maximum length is 63 characters per DNS naming spec.
Usage: {{ include "mychart.fullname" . }}
*/ -}}
{{- define "mychart.fullname" -}}
{{- end }}
```

### 3. Provide NOTES.txt

Create `templates/NOTES.txt` with post-installation instructions:

```
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }}
  $ helm get all {{ .Release.Name }}

{{- if .Values.ingress.enabled }}
Application URL:
{{- range .Values.ingress.hosts }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ . }}{{ $.Values.ingress.path }}
{{- end }}
{{- end }}
```

## Packaging and Distribution

### 1. Package the Chart

```bash
helm package ./mychart
```

### 2. Create Chart Repository

```bash
# Create index
helm repo index .

# Serve repository
helm serve
```

### 3. Publish to Artifact Hub

Create `artifacthub-repo.yml` in your repository:

```yaml
repositoryID: <uuid>
owners:
  - name: Your Name
    email: your.email@example.com
```

## Summary Checklist

Before releasing a chart, verify:

- [ ] Chart.yaml has all required fields
- [ ] values.yaml has sensible defaults
- [ ] All values are documented
- [ ] Templates use helpers for repeated logic
- [ ] Resource names are properly truncated
- [ ] Labels follow Kubernetes conventions
- [ ] Resources have limits and requests
- [ ] SecurityContext is defined
- [ ] Probes are configured
- [ ] Secrets are parameterized, not hardcoded
- [ ] `helm lint` passes
- [ ] `helm template` renders successfully
- [ ] Dry-run install succeeds
- [ ] Tests are defined and pass
- [ ] README.md is comprehensive
- [ ] NOTES.txt provides helpful post-install info
- [ ] Chart version follows SemVer
- [ ] .helmignore excludes unnecessary files
