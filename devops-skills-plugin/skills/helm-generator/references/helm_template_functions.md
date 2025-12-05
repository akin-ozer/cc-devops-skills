# Helm Template Functions Reference

Comprehensive guide to Helm template functions with practical examples.

## Essential Template Functions

### 1. required - Enforce Required Values

Fails template rendering if a value is not provided.

```yaml
# Syntax
{{ required "error message" .Values.some.value }}

# Example
image: {{ required "image.repository is required!" .Values.image.repository }}
tag: {{ required "image.tag is required!" .Values.image.tag }}
```

**When to use:**
- Critical configuration values that must be set
- Values without sensible defaults
- Production deployments where safety is paramount

### 2. default - Provide Fallback Values

Provides a default value if the value is empty or undefined.

```yaml
# Syntax
{{ .Values.some.value | default "default-value" }}

# Examples
replicas: {{ .Values.replicaCount | default 1 }}
image:
  tag: {{ .Values.image.tag | default .Chart.AppVersion }}
  pullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}

# Computed defaults
serviceName: {{ .Values.service.name | default (printf "%s-svc" (include "mychart.fullname" .)) }}
```

**When to use:**
- Optional configuration values
- Values with sensible defaults
- Fallback to computed values

### 3. quote - Safely Quote Strings

Wraps a value in double quotes, escaping special characters.

```yaml
# Syntax
{{ .Values.some.value | quote }}

# Examples
env:
  - name: DATABASE_URL
    value: {{ .Values.database.url | quote }}
  - name: API_KEY
    value: {{ .Values.api.key | quote }}

# With pipeline
image: {{ .Values.image.repository | default "nginx" | quote }}
```

**When to use:**
- String values in environment variables
- Configuration values that might contain special characters
- YAML string fields that need guaranteed quoting

### 4. include - Include Templates with Pipeline Support

Includes a named template and allows piping the result to other functions.

```yaml
# Syntax
{{ include "template-name" context }}

# Examples
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}

# With modifications
annotations:
  checksum: {{ include "mychart.config" . | sha256sum }}
```

**When to use:**
- Including helpers or named templates
- When you need to pipe template output to other functions
- Prefer `include` over `template` for better composability

### 5. template - Include Templates (No Pipeline)

Includes a named template (cannot be piped).

```yaml
# Syntax
{{ template "template-name" context }}

# Example
metadata:
  labels:
    {{ template "mychart.labels" . }}
```

**When to use:**
- Simple template inclusion without modification
- Legacy templates (prefer `include` for new code)

### 6. toYaml - Convert to YAML

Converts an object to YAML format.

```yaml
# Syntax
{{ .Values.some.object | toYaml }}

# Examples
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}

{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

**When to use:**
- Complex nested objects from values.yaml
- Resource specifications (limits, requests)
- Selector, affinity, and toleration definitions

### 7. fromYaml - Parse YAML String

Parses a YAML string into an object.

```yaml
# Syntax
{{ .Values.yamlString | fromYaml }}

# Example
{{- $config := .Values.configYaml | fromYaml }}
{{- if $config.enabled }}
# Use $config values
{{- end }}
```

**When to use:**
- Parsing YAML strings from values
- Dynamic configuration loading

### 8. tpl - Render String as Template

Evaluates a string as a Go template.

```yaml
# Syntax
{{ tpl .Values.templateString . }}

# Example values.yaml
config:
  message: "Release: {{ .Release.Name }}"

# Template
data:
  message: {{ tpl .Values.config.message . }}
```

**When to use:**
- Dynamic template strings in values.yaml
- User-provided template content
- Advanced configuration patterns

### 9. nindent / indent - Control Indentation

Adds newline and indentation, or just indentation.

```yaml
# nindent - newline + indent
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}

# indent - just indent (no newline)
data:
  config: |
    {{ .Values.config | indent 4 }}
```

**When to use:**
- `nindent` for YAML blocks after keys
- `indent` for multi-line string content

### 10. printf - Format Strings

Formats a string using Go's fmt.Sprintf syntax.

```yaml
# Syntax
{{ printf "format" arg1 arg2 }}

# Examples
name: {{ printf "%s-%s" .Release.Name .Chart.Name }}
label: {{ printf "app.kubernetes.io/name: %s" .Chart.Name }}
```

**When to use:**
- Constructing names or identifiers
- String formatting and concatenation

## Logical Functions

### if / else / else if - Conditionals

```yaml
{{- if .Values.ingress.enabled }}
# Ingress resource
{{- end }}

{{- if eq .Values.service.type "LoadBalancer" }}
# LoadBalancer config
{{- else if eq .Values.service.type "NodePort" }}
# NodePort config
{{- else }}
# Default config
{{- end }}
```

### and / or / not - Boolean Logic

```yaml
{{- if and .Values.enabled (not .Values.debug) }}
# Enabled and not debug
{{- end }}

{{- if or .Values.useSSL .Values.production }}
# SSL or production
{{- end }}
```

### with - Scope Context

```yaml
{{- with .Values.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

**Note:** Inside `with`, `.` refers to the scoped value. Use `$` for root context.

## Comparison Functions

- `eq` - Equal: `{{ if eq .Values.env "prod" }}`
- `ne` - Not equal: `{{ if ne .Values.replicas 1 }}`
- `lt` - Less than: `{{ if lt .Values.replicas 3 }}`
- `le` - Less or equal: `{{ if le .Values.replicas 5 }}`
- `gt` - Greater than: `{{ if gt .Values.replicas 1 }}`
- `ge` - Greater or equal: `{{ if ge .Values.replicas 3 }}`

## String Functions (Sprig)

### Basic String Operations

```yaml
# upper / lower
name: {{ .Values.name | upper }}
label: {{ .Values.env | lower }}

# trim / trimSuffix / trimPrefix
name: {{ .Values.name | trim }}
name: {{ .Values.name | trimSuffix "-" }}

# trunc - truncate to length
name: {{ .Values.longName | trunc 63 | trimSuffix "-" }}

# replace
chart: {{ .Chart.Name | replace "." "-" }}

# contains
{{- if contains "prod" .Values.environment }}
# Production settings
{{- end }}
```

### String Testing

```yaml
# hasPrefix / hasSuffix
{{- if hasPrefix "prod-" .Values.name }}

# empty - test if value is empty
{{- if not (empty .Values.optional) }}
```

## List Functions (Sprig)

### list - Create Lists

```yaml
{{- $myList := list "item1" "item2" "item3" }}
```

### append / prepend

```yaml
{{- $list := list "a" "b" }}
{{- $list = append $list "c" }}
{{- $list = prepend $list "z" }}
```

### first / rest / last / initial

```yaml
first: {{ first .Values.items }}
last: {{ last .Values.items }}
```

### has - Check Membership

```yaml
{{- if has "production" .Values.environments }}
```

## Dict/Map Functions (Sprig)

### dict - Create Dictionary

```yaml
{{- $myDict := dict "key1" "value1" "key2" "value2" }}
{{- include "mychart.helper" $myDict }}
```

### set / unset

```yaml
{{- $_ := set .Values "newKey" "newValue" }}
{{- $_ := unset .Values "oldKey" }}
```

### hasKey

```yaml
{{- if hasKey .Values "optional" }}
```

### merge - Merge Dictionaries

```yaml
{{- $merged := merge .Values.override .Values.defaults }}
```

## Type Functions

### typeOf / kindOf

```yaml
{{- $type := typeOf .Values.someValue }}
```

### int / int64 / float64 / toString

```yaml
port: {{ .Values.port | int }}
cpu: {{ .Values.cpu | toString }}
```

## Crypto Functions

### sha256sum - SHA-256 Hash

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

### b64enc / b64dec - Base64

```yaml
data:
  password: {{ .Values.password | b64enc }}
```

## Date Functions

### now - Current Time

```yaml
annotations:
  timestamp: {{ now | date "2006-01-02T15:04:05Z07:00" }}
```

### date - Format Date

```yaml
date: {{ now | date "2006-01-02" }}
```

## Regex Functions

### regexMatch / regexFind / regexReplace

```yaml
{{- if regexMatch "^prod-" .Values.name }}

{{- $version := .Values.image.tag | regexFind "[0-9]+" }}

label: {{ .Values.name | regexReplaceAll "[^a-z0-9-]" "-" }}
```

## Flow Control Functions

### range - Iterate

```yaml
# Range over list
{{- range .Values.items }}
- {{ . }}
{{- end }}

# Range over map
{{- range $key, $value := .Values.config }}
{{ $key }}: {{ $value }}
{{- end }}

# Range with index
{{- range $index, $item := .Values.items }}
{{ $index }}: {{ $item }}
{{- end }}
```

## Lookup Function (Cluster Queries)

Query existing Kubernetes resources (use with caution).

```yaml
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
{{- if $secret }}
# Secret exists
data:
  password: {{ $secret.data.password }}
{{- else }}
# Create new secret
{{- end }}
```

**⚠️ Warning:** `lookup` queries the cluster, which:
- Breaks the declarative model
- May cause issues with `helm template`
- Can lead to non-reproducible builds
- Should be used sparingly

## Best Practices

### 1. Validation First

```yaml
# Validate required values
name: {{ required "name is required" .Values.name }}
port: {{ required "port is required" .Values.port }}
```

### 2. Provide Defaults

```yaml
# Always provide sensible defaults
replicas: {{ .Values.replicaCount | default 1 }}
image:
  pullPolicy: {{ .Values.image.pullPolicy | default "IfNotPresent" }}
```

### 3. Quote Strings

```yaml
# Quote string values in env vars and annotations
env:
  - name: DATABASE_URL
    value: {{ .Values.database.url | quote }}
```

### 4. Use include Over template

```yaml
# Prefer include for composability
labels:
  {{- include "mychart.labels" . | nindent 2 }}

# Not: {{ template "mychart.labels" . }}
```

### 5. Use toYaml for Complex Objects

```yaml
# Let toYaml handle complex structures
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}
```

### 6. Proper Indentation

```yaml
# Use nindent for YAML blocks
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}

# Use indent for multi-line strings
data:
  config: |
    {{ .Values.config | indent 4 }}
```

### 7. Whitespace Control

```yaml
# Use {{- and -}} to control whitespace
{{- if .Values.enabled }}
  content
{{- end }}
```

### 8. Fail Fast with required

```yaml
# Fail early if critical values missing
database:
  host: {{ required "database.host is required!" .Values.database.host }}
```

## Common Patterns

### ConfigMap Checksum

Trigger pod restart when ConfigMap changes:

```yaml
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

### Conditional Resource Creation

```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
# ...
{{- end }}
```

### Dynamic Names

```yaml
name: {{ include "mychart.fullname" . }}
serviceName: {{ include "mychart.fullname" . }}-svc
```

### Passing Custom Context

```yaml
{{- include "mychart.container" (dict "root" . "container" .Values.mainContainer) }}
```

Then in helper:

```yaml
{{- define "mychart.container" -}}
{{- $root := .root }}
{{- $container := .container }}
name: {{ $container.name }}
image: {{ $container.image }}
namespace: {{ $root.Release.Namespace }}
{{- end }}
```

## Resources

- [Helm Template Functions](https://helm.sh/docs/chart_template_guide/function_list/)
- [Sprig Function Library](https://masterminds.github.io/sprig/)
- [Go Template Documentation](https://pkg.go.dev/text/template)