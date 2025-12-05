---
name: helm-validator
description: Comprehensive toolkit for validating, linting, testing, and analyzing Helm charts and their rendered Kubernetes resources. Use this skill when working with Helm charts, validating templates, debugging chart issues, working with Custom Resource Definitions (CRDs) that require documentation lookup, or checking Helm best practices.
---

# Helm Chart Validator & Analysis Toolkit

## Overview

This skill provides a comprehensive validation and analysis workflow for Helm charts, combining Helm-native linting, template rendering, YAML validation, schema validation, CRD documentation lookup, and security best practices checking.

**IMPORTANT: This is a READ-ONLY validator.** It analyzes charts and proposes improvements but does NOT modify any files. All proposed changes are listed in the final summary for the user to review and apply manually or via the helm-generator skill.

## When to Use This Skill

Invoke this skill when:
- Validating Helm charts before packaging or deployment
- Debugging Helm template rendering errors
- Testing chart templates with different values
- Working with Custom Resource Definitions (CRDs) that need documentation
- Implementing or refactoring Helm template helpers (`_helpers.tpl`)
- Performing dry-run tests to catch admission controller errors
- Ensuring charts follow Helm and Kubernetes best practices
- Automating repetitive template patterns with Helm functions
- The user asks to "validate", "lint", "check", "test", or "improve" Helm charts
- Creating or optimizing template functions like `include`, `tpl`, `required`, etc.

## Validation & Testing Workflow

Follow this sequential validation workflow. Each stage catches different types of issues:

### Stage 1: Tool Check

Before starting validation, verify required tools are installed:

```bash
bash scripts/setup_tools.sh
```

Required tools:
- **helm**: Helm package manager for Kubernetes (v3+)
- **yamllint**: YAML syntax and style linting
- **kubeconform**: Kubernetes schema validation with CRD support
- **kubectl**: Cluster dry-run testing (optional but recommended)

If tools are missing, provide installation instructions from the script output and ask the user if they want to install them.

### Stage 2: Helm Chart Structure Validation

Verify the chart follows the standard Helm directory structure:

```bash
bash scripts/validate_chart_structure.sh <chart-directory>
```

**Expected structure:**
```
mychart/
  Chart.yaml          # Chart metadata (required)
  values.yaml         # Default values (required)
  values.schema.json  # JSON Schema for values validation (optional)
  templates/          # Template directory (required)
    _helpers.tpl      # Template helpers (recommended)
    NOTES.txt         # Post-install notes (recommended)
    *.yaml            # Kubernetes manifest templates
  charts/             # Chart dependencies (optional)
  crds/               # Custom Resource Definitions (optional)
  .helmignore         # Files to ignore during packaging (optional)
```

**Common issues caught:**
- Missing required files (Chart.yaml, values.yaml, templates/)
- Invalid Chart.yaml syntax or missing required fields
- Malformed values.schema.json
- Incorrect file permissions

### Stage 3: Helm Lint

Run Helm's built-in linter to catch chart-specific issues:

```bash
helm lint <chart-directory> --strict
```

**Optional flags:**
- `--values <values-file>`: Test with specific values
- `--set key=value`: Override specific values
- `--debug`: Show detailed error information

**Common issues caught:**
- Invalid Chart.yaml metadata
- Template syntax errors
- Missing or undefined values
- Deprecated Kubernetes API versions
- Chart best practice violations

**Auto-fix approach:**
- For template errors, identify the problematic template file
- Show the user the specific line causing issues
- Propose fixes using the Edit tool
- Re-run `helm lint` after fixes

### Stage 4: Template Rendering

Render templates locally to verify they produce valid YAML:

```bash
helm template <release-name> <chart-directory> \
  --values <values-file> \
  --debug \
  --output-dir ./rendered
```

**Options to consider:**
- `--values values.yaml`: Use specific values file
- `--set key=value`: Override individual values
- `--show-only templates/deployment.yaml`: Render specific template
- `--validate`: Validate against Kubernetes OpenAPI schema
- `--include-crds`: Include CRDs in rendered output
- `--is-upgrade`: Simulate upgrade scenario
- `--kube-version 1.28.0`: Target specific Kubernetes version

**Common issues caught:**
- Template syntax errors (Go template issues)
- Undefined variables or values
- Type mismatches (string vs. integer)
- Missing required values
- Logic errors in conditionals or loops
- Incorrect indentation in nested templates

**For template errors:**
- Identify the template file and line number
- Check if values are properly defined in values.yaml
- Verify template function usage (quote, required, default, include, etc.)
- Test with different value combinations

### Stage 5: YAML Syntax Validation

Validate YAML syntax and formatting of rendered templates:

```bash
yamllint -c assets/.yamllint ./rendered/*.yaml
```

**Common issues caught:**
- Indentation errors (tabs vs spaces)
- Trailing whitespace
- Line length violations
- Syntax errors
- Duplicate keys
- Document start/end markers

**Auto-fix approach:**
- For simple issues (indentation, trailing spaces), propose fixes using the Edit tool
- For template-generated issues, fix the source template, not rendered output
- Always show the user what will be changed before applying fixes

### Stage 6: CRD Detection and Documentation Lookup

Before schema validation, detect if the chart contains or renders Custom Resource Definitions:

```bash
# Check crds/ directory
bash scripts/detect_crd_wrapper.sh <chart-directory>/crds/*.yaml

# Check rendered templates
bash scripts/detect_crd_wrapper.sh ./rendered/*.yaml
```

The script outputs JSON with resource information:
```json
[
  {
    "kind": "Certificate",
    "apiVersion": "cert-manager.io/v1",
    "group": "cert-manager.io",
    "version": "v1",
    "isCRD": true,
    "name": "example-cert"
  }
]
```

**For each detected CRD:**

1. **Try context7 MCP first (preferred):**
   ```
   Use mcp__context7__resolve-library-id with the CRD project name
   Example: "cert-manager" for cert-manager.io CRDs
            "prometheus-operator" for monitoring.coreos.com CRDs
            "istio" for networking.istio.io CRDs

   Then use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID from resolve step
   - topic: The CRD kind and relevant features (e.g., "Certificate spec")
   - tokens: 5000 (adjust based on need)
   ```

2. **Fallback to WebSearch if context7 fails:**
   ```
   Search query pattern:
   "<kind>" "<group>" kubernetes CRD "<version>" documentation spec

   Example:
   "Certificate" "cert-manager.io" kubernetes CRD "v1" documentation spec
   "Prometheus" "monitoring.coreos.com" kubernetes CRD "v1" documentation spec
   ```

3. **Extract key information:**
   - Required fields in `spec`
   - Field types and validation rules
   - Examples from documentation
   - Version-specific changes or deprecations
   - Common configuration patterns

**Why this matters:** CRDs have custom schemas not available in standard Kubernetes validation tools. Understanding the CRD's spec requirements prevents validation errors and ensures correct resource configuration.

### Stage 7: Schema Validation

Validate rendered templates against Kubernetes schemas:

```bash
kubeconform \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  -summary \
  -verbose \
  ./rendered/*.yaml
```

**Options to consider:**
- Add `-strict` to reject unknown fields (recommended for production)
- Add `-ignore-missing-schemas` if working with custom/internal CRDs
- Add `-kubernetes-version 1.28.0` to validate against specific K8s version
- Add `-output json` for programmatic processing

**Common issues caught:**
- Invalid apiVersion or kind
- Missing required fields
- Wrong field types
- Invalid enum values
- Unknown fields (with -strict)

**For CRDs:** If kubeconform reports "no schema found", this is expected. Use the documentation from Stage 6 to manually validate the spec fields.

### Stage 8: Cluster Dry-Run (if available)

If kubectl is configured and cluster access is available, perform a server-side dry-run:

```bash
# Test installation
helm install <release-name> <chart-directory> \
  --dry-run \
  --debug \
  --values <values-file>

# Test upgrade
helm upgrade <release-name> <chart-directory> \
  --dry-run \
  --debug \
  --values <values-file>
```

**This catches:**
- Admission controller rejections
- Policy violations (PSP, OPA, Kyverno, etc.)
- Resource quota violations
- Missing namespaces
- Invalid ConfigMap/Secret references
- Webhook validations
- Existing resource conflicts

**If dry-run is not possible:**
- Use kubectl with rendered templates: `kubectl apply --dry-run=server -f ./rendered/`
- Skip if no cluster access
- Document that cluster-specific validation was skipped

**For updates to existing releases:**
```bash
helm diff upgrade <release-name> <chart-directory>
```
This shows what would change, helping catch unintended modifications. (Requires helm-diff plugin)

### Stage 9: Security Best Practices Check (MANDATORY)

**IMPORTANT:** This stage is MANDATORY. Analyze rendered templates for security best practices compliance.

**Check rendered Deployment/Pod templates for:**

1. **Missing securityContext** - Look for pods/containers without security settings:
   ```yaml
   # Check if pod-level securityContext exists
   spec:
     securityContext:
       runAsNonRoot: true
       runAsUser: 1000
       fsGroup: 2000
   ```

2. **Missing container securityContext** - Each container should have:
   ```yaml
   securityContext:
     allowPrivilegeEscalation: false
     readOnlyRootFilesystem: true
     runAsNonRoot: true
     capabilities:
       drop:
         - ALL
   ```

3. **Missing resource limits/requests** - Check for:
   ```yaml
   resources:
     limits:
       cpu: "100m"
       memory: "128Mi"
     requests:
       cpu: "100m"
       memory: "128Mi"
   ```

4. **Image tag issues** - Flag if using `:latest` or no tag

5. **Missing probes** - Check for liveness/readiness probes

**How to check:** Read the rendered deployment YAML files and grep for these patterns:
```bash
# Check for securityContext
grep -l "securityContext" ./rendered/*.yaml

# Check for resources
grep -l "resources:" ./rendered/*.yaml

# Check for latest tag
grep "image:.*:latest" ./rendered/*.yaml
```

### Stage 10: Final Report (MANDATORY)

**IMPORTANT:** This stage is MANDATORY even if all validations pass. You MUST complete ALL of the following actions.

**This is a READ-ONLY validator. Do NOT modify any files. List all proposed changes in the summary.**

#### Step 1: Load Reference Files (MANDATORY when warnings exist)

**If ANY warnings, errors, or security issues were found, you MUST read:**
```
Read references/helm_best_practices.md
Read references/k8s_best_practices.md
```

Use these references to provide context and recommendations for each issue found.

#### Step 2: Present Validation Summary

**Always present a validation summary** formatted as a table showing:
- Each validation stage executed (Stages 1-9)
- Status of each stage (✅ Passed, ⚠️ Warning, ❌ Failed)
- Count of issues found per stage

Example:
```
| Stage | Status | Issues |
|-------|--------|--------|
| 1. Tool Check | ✅ Passed | All tools available |
| 2. Structure | ⚠️ Warning | Missing: .helmignore, NOTES.txt |
| 3. Helm Lint | ✅ Passed | 0 errors |
| 4. Template Render | ✅ Passed | 5 templates rendered |
| 5. YAML Syntax | ✅ Passed | No yamllint errors |
| 6. CRD Detection | ✅ Passed | 1 CRD documented |
| 7. Schema Validation | ✅ Passed | All resources valid |
| 8. Dry-Run | ✅ Passed | No cluster errors |
| 9. Security Check | ⚠️ Warning | Missing securityContext |
```

#### Step 3: Categorize All Issues

Group findings by severity:

**❌ Errors (must fix):**
- Template syntax errors
- Missing required fields
- Schema validation failures
- Dry-run failures

**⚠️ Warnings (should fix):**
- Deprecated Kubernetes APIs
- Missing securityContext
- Missing resource limits/requests
- Using `:latest` image tag
- Missing recommended files (_helpers.tpl, .helmignore, NOTES.txt)

**ℹ️ Info (recommendations):**
- Missing values.schema.json
- Missing README.md
- Optimization opportunities

#### Step 4: List Proposed Changes (DO NOT APPLY)

For each issue, provide a **proposed fix** with:
- File path and line number (if applicable)
- Before/after code blocks
- Explanation of why this change is recommended

Example format:
```
## Proposed Changes

### 1. Add securityContext to Deployment
**File:** templates/deployment.yaml:25
**Severity:** ⚠️ Warning
**Reason:** Running containers as root is a security risk

**Current:**
```yaml
spec:
  containers:
    - name: app
      image: nginx:1.21
```

**Proposed:**
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 2000
  containers:
    - name: app
      image: nginx:1.21
      securityContext:
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop:
            - ALL
```

### 2. Add .helmignore file
**File:** .helmignore (new file)
**Severity:** ⚠️ Warning
**Reason:** Excludes unnecessary files from chart packaging

**Proposed:** Copy from `assets/.helmignore`
```

#### Step 5: Automation Opportunities

List all detected automation opportunities:
- If `_helpers.tpl` is missing → Recommend: `bash scripts/generate_helpers.sh <chart>`
- If `.helmignore` is missing → Recommend: Copy from `assets/.helmignore`
- If `values.schema.json` is missing → Recommend: Copy and customize from `assets/values.schema.json`
- If `NOTES.txt` is missing → Recommend: Create post-install notes template
- If `README.md` is missing → Recommend: Create chart documentation

#### Step 6: Final Summary

Provide a final summary:
```
## Validation Summary

**Chart:** <chart-name>
**Status:** ⚠️ Warnings Found (or ✅ Ready for Deployment)

**Issues Found:**
- Errors: X
- Warnings: Y
- Info: Z

**Proposed Changes:** N changes recommended

**Next Steps:**
1. Review proposed changes above
2. Apply changes manually or use helm-generator skill
3. Re-run validation to confirm fixes
```

## Helm Templating Automation & Best Practices

This section covers advanced Helm templating techniques, helper functions, and automation strategies.

### Template Helpers (`_helpers.tpl`)

Template helpers are reusable functions defined in `templates/_helpers.tpl`. They promote DRY principles and consistency.

**Standard helper patterns:**

1. **Chart name helper:**
```yaml
{{/*
Expand the name of the chart.
*/}}
{{- define "mychart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}
```

2. **Fullname helper:**
```yaml
{{/*
Create a default fully qualified app name.
*/}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}
```

3. **Chart reference helper:**
```yaml
{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "mychart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
```

4. **Standard labels helper:**
```yaml
{{/*
Common labels
*/}}
{{- define "mychart.labels" -}}
helm.sh/chart: {{ include "mychart.chart" . }}
{{ include "mychart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
```

5. **Selector labels helper:**
```yaml
{{/*
Selector labels
*/}}
{{- define "mychart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mychart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
```

6. **ServiceAccount name helper:**
```yaml
{{/*
Create the name of the service account to use
*/}}
{{- define "mychart.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "mychart.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
```

**When to create helpers:**
- Values used in multiple templates
- Complex logic that's repeated
- Label sets that should be consistent
- Name generation patterns
- Conditional resource inclusion

### Essential Template Functions

Reference and use these Helm template functions for robust charts:

1. **`required` - Enforce required values:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ required "A valid service name is required!" .Values.service.name }}
```

2. **`default` - Provide fallback values:**
```yaml
replicas: {{ .Values.replicaCount | default 1 }}
```

3. **`quote` - Safely quote string values:**
```yaml
env:
  - name: DATABASE_HOST
    value: {{ .Values.database.host | quote }}
```

4. **`include` - Use helpers with pipeline:**
```yaml
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

5. **`tpl` - Render strings as templates:**
```yaml
{{- tpl .Values.customConfig . }}
```

6. **`toYaml` - Convert objects to YAML:**
```yaml
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

7. **`fromYaml` - Parse YAML strings:**
```yaml
{{- $config := .Values.configYaml | fromYaml }}
```

8. **`merge` - Merge maps:**
```yaml
{{- $merged := merge .Values.override .Values.defaults }}
```

9. **`lookup` - Query cluster resources (use carefully):**
```yaml
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
{{- if $secret }}
  # Secret exists, use it
{{- else }}
  # Create new secret
{{- end }}
```

### Advanced Template Patterns

1. **Conditional resource creation:**
```yaml
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ... ingress definition
{{- end }}
```

2. **Range over lists:**
```yaml
{{- range .Values.extraEnvVars }}
- name: {{ .name }}
  value: {{ .value | quote }}
{{- end }}
```

3. **Range over maps:**
```yaml
{{- range $key, $value := .Values.configMap }}
{{ $key }}: {{ $value | quote }}
{{- end }}
```

4. **With blocks for scoping:**
```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

5. **Named templates with custom context:**
```yaml
{{- include "mychart.container" (dict "root" . "container" .Values.mainContainer) }}
```

### Values Structure Best Practices

**Prefer flat structures when possible:**

```yaml
# Good - Flat structure
serverName: nginx
serverPort: 80

# Acceptable - Nested structure for related settings
server:
  name: nginx
  port: 80
  replicas: 3
```

**Always provide defaults in values.yaml:**
```yaml
replicaCount: 1

image:
  repository: nginx
  pullPolicy: IfNotPresent
  tag: "1.21.0"

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

**Document all values:**
```yaml
# replicaCount is the number of pod replicas for the deployment
replicaCount: 1

# image configures the container image
image:
  # image.repository is the container image registry and name
  repository: nginx
  # image.tag overrides the image tag (default is chart appVersion)
  tag: "1.21.0"
```

### Template Comments and Documentation

Use Helm template comments for documentation:

```yaml
{{- /*
mychart.fullname generates the fullname for resources.
It supports nameOverride and fullnameOverride values.
Usage: {{ include "mychart.fullname" . }}
*/ -}}
{{- define "mychart.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

Use YAML comments for user-facing notes:

```yaml
# WARNING: Changing the storage class will not migrate existing data
storageClass: "standard"
```

### Whitespace Management

Use `-` to chomp whitespace in template directives:

```yaml
{{- if .Values.enabled }}
  # Remove leading whitespace
{{- end }}

{{ .Values.name -}}
  # Remove trailing whitespace
```

Good formatting:
```yaml
{{- if .Values.enabled }}
  key: value
{{- end }}
```

Bad formatting:
```yaml
{{if .Values.enabled}}
key: value
{{end}}
```

## Helper Patterns Reference

When analyzing charts, identify opportunities for helper functions:

1. **Identify repetition:**
   - Same label sets across resources
   - Repeated name generation logic
   - Common conditional patterns

2. **Common helper patterns to recommend:**
   - Chart name helper (`.name`)
   - Fullname helper (`.fullname`)
   - Chart version label (`.chart`)
   - Common labels (`.labels`)
   - Selector labels (`.selectorLabels`)
   - ServiceAccount name (`.serviceAccountName`)

3. **When to recommend helpers:**
   - Missing `_helpers.tpl` file
   - Repeated code patterns across templates
   - Inconsistent label usage
   - Long resource names that need truncation

## Best Practices Reference

For detailed Helm and Kubernetes best practices, load the references:

```
Read references/helm_best_practices.md
Read references/k8s_best_practices.md
```

These references include:
- Chart structure and metadata
- Template conventions and patterns
- Values file organization
- Security best practices
- Resource limits and requests
- Common validation issues and fixes

**When to load:** When validation reveals issues that need context, when implementing new features, or when the user asks about best practices.

## Working with Chart Dependencies

When a chart has dependencies (in `Chart.yaml` or `charts/` directory):

1. **Update dependencies:**
```bash
helm dependency update <chart-directory>
```

2. **List dependencies:**
```bash
helm dependency list <chart-directory>
```

3. **Validate dependencies:**
   - Check that dependency versions are available
   - Verify dependency values are properly scoped
   - Test templates with dependency resources

4. **Override dependency values:**
```yaml
# values.yaml
postgresql:
  enabled: true
  postgresqlPassword: "secret"
  persistence:
    size: 10Gi
```

## Error Handling Strategies

### Tool Not Available
- Run `scripts/setup_tools.sh` to check availability
- Provide installation instructions
- Skip optional stages but document what was skipped
- Continue with available tools

### Template Rendering Errors
- Show the specific template file and line number
- Check if values are defined in values.yaml
- Verify template function syntax
- Test with simpler value combinations
- Use `--debug` flag for detailed error messages

### Cluster Access Issues
- Fall back to client-side validation
- Use rendered templates with kubectl
- Skip cluster validation if no kubectl config
- Document limitations in validation report

### CRD Documentation Not Found
- Document that documentation lookup failed
- Attempt validation with kubeconform CRD schemas
- Suggest manual CRD inspection:
  ```bash
  kubectl get crd <crd-name>.group -o yaml
  kubectl explain <kind>
  ```

### Validation Stage Failures
- Continue to next stage even if one fails
- Collect all errors before presenting to user
- Prioritize fixing Helm lint errors first
- Then fix template errors
- Finally fix schema/validation errors

### macOS Extended Attributes Issue

**Symptom:** Helm reports "Chart.yaml file is missing" even though the file exists and is readable.

**Cause:** On macOS, files created programmatically (via Write tool, scripts, or certain editors) may have extended attributes (e.g., `com.apple.provenance`, `com.apple.quarantine`) that interfere with Helm's file detection.

**Diagnosis:**
```bash
# Check for extended attributes
xattr /path/to/chart/Chart.yaml

# If attributes are present, you'll see output like:
# com.apple.provenance
# com.apple.quarantine
```

**Solutions:**

1. **Remove extended attributes:**
   ```bash
   # Remove all extended attributes from a file
   xattr -c /path/to/chart/Chart.yaml

   # Remove all extended attributes recursively from chart directory
   xattr -cr /path/to/chart/
   ```

2. **Create files using shell commands instead:**
   ```bash
   # Use cat with heredoc instead of direct file writes
   cat > Chart.yaml << 'EOF'
   apiVersion: v2
   name: mychart
   version: 0.1.0
   EOF
   ```

3. **Copy from helm-created chart:**
   ```bash
   # Create a fresh chart and copy structure
   helm create temp-chart
   cp -r temp-chart/* /path/to/your/chart/
   rm -rf temp-chart
   ```

**Prevention:** When creating new chart files on macOS, prefer using `helm create` as a base or use shell heredocs (`cat > file << 'EOF'`) rather than direct file creation tools.

## Communication Guidelines

When presenting validation results and fixes:

1. **Be clear and concise** about what was found
2. **Explain why issues matter** (e.g., "This will cause pod creation to fail")
3. **Provide context** from Helm best practices when relevant
4. **Group related issues** (e.g., all missing helper issues together)
5. **Use file:line references** when available
6. **Show confidence level** for auto-fixes (high confidence = syntax, low = logic changes)
7. **Always provide a summary after applying fixes** including:
   - What was changed and why
   - File and line references for each fix
   - Total count of issues resolved
   - Final validation status
   - Any remaining warnings or recommendations

## Version Awareness

Always consider Kubernetes and Helm version compatibility:
- Check for deprecated Kubernetes APIs
- Ensure Helm chart apiVersion is v2 (for Helm 3+)
- For CRDs, ensure the apiVersion matches what's in the cluster
- Use `kubectl api-versions` to list available API versions
- Reference version-specific documentation when available
- Set `kubeVersion` constraint in Chart.yaml if needed

## Chart Testing

For comprehensive testing, use Helm test resources:

1. **Create test resources:**
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

2. **Run tests:**
```bash
helm test <release-name>
```

## Automation Opportunities Reference

**During Stage 10 (Final Report), list all detected automation opportunities in the summary.**

**Do NOT ask user questions or modify files. Simply list recommendations.**

**Automation opportunities to detect and list:**

| Missing Item | Recommendation |
|--------------|----------------|
| `_helpers.tpl` | Run: `bash scripts/generate_helpers.sh <chart>` |
| `.helmignore` | Copy from: `assets/.helmignore` |
| `values.schema.json` | Copy and customize from: `assets/values.schema.json` |
| `NOTES.txt` | Create post-install notes template |
| `README.md` | Create chart documentation |
| Repeated patterns | Extract to helper functions |

**Security recommendations to include when issues found:**

| Issue | Recommendation |
|-------|----------------|
| Missing pod securityContext | Add `runAsNonRoot: true`, `runAsUser: 1000`, `fsGroup: 2000` |
| Missing container securityContext | Add `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` |
| Missing resource limits | Add CPU/memory limits and requests |
| Using `:latest` tag | Pin to specific image version |
| Missing probes | Add liveness and readiness probes |

**Template improvement recommendations:**

| Issue | Recommendation |
|-------|----------------|
| Using `template` instead of `include` | Replace with `include` for pipeline support |
| Missing `nindent` | Add `nindent` for proper YAML indentation |
| No default values | Add `default` function for optional values |
| Missing `required` function | Add `required` for critical values |

## Resources

### scripts/

**setup_tools.sh**
- Checks for required validation tools (helm, yamllint, kubeconform, kubectl)
- Provides installation instructions for missing tools
- Verifies versions of installed tools
- Usage: `bash scripts/setup_tools.sh`

**validate_chart_structure.sh**
- Validates Helm chart directory structure
- Checks for required files (Chart.yaml, values.yaml, templates/)
- Verifies file formats and syntax
- Usage: `bash scripts/validate_chart_structure.sh <chart-directory>`

**detect_crd_wrapper.sh**
- Wrapper script that handles Python dependency management
- Automatically creates temporary venv if PyYAML is not available
- Calls detect_crd.py to parse YAML files
- Usage: `bash scripts/detect_crd_wrapper.sh <file.yaml>`

**detect_crd.py**
- Parses YAML files to identify Custom Resource Definitions
- Extracts kind, apiVersion, group, and version information
- Outputs JSON for programmatic processing
- Requires PyYAML (handled automatically by wrapper script)
- Can be called directly: `python3 scripts/detect_crd.py <file.yaml>`

**generate_helpers.sh**
- Generates standard Helm helpers (_helpers.tpl) for a chart
- Creates fullname, labels, and selector helpers
- Usage: `bash scripts/generate_helpers.sh <chart-directory>`

### references/

**helm_best_practices.md**
- Comprehensive guide to Helm chart best practices
- Covers template patterns, helper functions, values structure
- Common validation issues and how to fix them
- Security and performance recommendations
- Load when providing context for Helm-specific issues

**k8s_best_practices.md**
- Comprehensive guide to Kubernetes YAML best practices
- Covers metadata, labels, resource limits, security context
- Common validation issues and how to fix them
- Load when providing context for Kubernetes-specific issues

**template_functions.md**
- Reference guide for Helm template functions
- Examples of all built-in functions
- Sprig function library reference
- Custom function patterns
- Load when implementing complex templates

### assets/

**.helmignore**
- Standard .helmignore file for excluding files from packaging
- Pre-configured with common patterns

**.yamllint**
- Pre-configured yamllint rules for Kubernetes YAML
- Follows Kubernetes conventions (2-space indentation, line length, etc.)
- Can be customized per project
- Usage: `yamllint -c assets/.yamllint <file.yaml>`

**values.schema.json**
- Example JSON Schema for values validation
- Can be copied and customized for specific charts
- Provides type safety and validation
