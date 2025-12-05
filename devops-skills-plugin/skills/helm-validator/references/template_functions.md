# Helm Template Functions Reference

This reference provides a comprehensive guide to Helm template functions, including built-in functions and Sprig library functions.

## Essential Helm Functions

### include

Includes a named template and allows piping the output to other functions.

**Syntax:**
```yaml
{{ include "template.name" . }}
```

**Examples:**
```yaml
# Include and indent
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}

# Include and quote
value: {{ include "mychart.value" . | quote }}

# Include with custom context
{{- include "mychart.container" (dict "root" . "container" .Values.mainContainer) }}
```

**When to use:** Prefer `include` over `template` when you need to manipulate the output with functions.

### tpl

Evaluates a string as a template, allowing dynamic template rendering.

**Syntax:**
```yaml
{{ tpl <string> <context> }}
```

**Examples:**
```yaml
# Render a value as template
{{ tpl .Values.customConfig . }}

# Render external file as template
{{ tpl (.Files.Get "config/app.conf") . }}

# values.yaml
customConfig: |
  server:
    host: {{ .Values.server.host }}
    port: {{ .Values.server.port }}
```

**When to use:** When users need to provide template strings in values or external files.

### required

Enforces that a value must be provided, failing with a custom error message if missing.

**Syntax:**
```yaml
{{ required "error message" .Values.path }}
```

**Examples:**
```yaml
# Require a critical value
apiVersion: v1
kind: Service
metadata:
  name: {{ required "A valid service name is required!" .Values.service.name }}

# Require database password
data:
  password: {{ required "database.password must be set" .Values.database.password | b64enc }}

# Require multiple values
env:
  - name: API_KEY
    value: {{ required "apiKey must be provided" .Values.apiKey | quote }}
```

**When to use:** For critical values that have no sensible default.

### lookup

Queries existing Kubernetes resources in the cluster during template rendering.

**Syntax:**
```yaml
{{ lookup "apiVersion" "kind" "namespace" "name" }}
```

**Examples:**
```yaml
# Look up existing secret
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
{{- if $secret }}
  # Secret exists, use existing password
  password: {{ $secret.data.password }}
{{- else }}
  # Create new password
  password: {{ randAlphaNum 16 | b64enc }}
{{- end }}

# List all pods in namespace
{{- $pods := lookup "v1" "Pod" .Release.Namespace "" }}

# Get specific resource
{{- $cm := lookup "v1" "ConfigMap" "default" "my-config" }}
```

**⚠️ Cautions:**
- Only works during `helm install` and `helm upgrade`, not with `helm template`
- Requires cluster access
- Can slow down rendering
- Creates tight coupling between chart and cluster state

**When to use:** When you need to check for existing resources or migrate from existing deployments.

## String Functions

### quote / squote

Wraps a string in double or single quotes.

**Examples:**
```yaml
# Double quotes
env:
  - name: HOST
    value: {{ .Values.host | quote }}  # Output: "localhost"

# Single quotes
value: {{ .Values.name | squote }}  # Output: 'myapp'
```

### default

Provides a fallback value if the input is empty.

**Examples:**
```yaml
# Simple default
replicas: {{ .Values.replicaCount | default 1 }}

# Chain with other functions
image: {{ .Values.image.tag | default .Chart.AppVersion | quote }}

# Default for nested values
{{ .Values.server.port | default 8080 }}
```

### trim / trimSuffix / trimPrefix

Removes whitespace or specific strings.

**Examples:**
```yaml
# Remove whitespace
name: {{ .Values.name | trim }}

# Remove suffix
name: {{ .Release.Name | trimSuffix "-dev" }}

# Remove prefix
name: {{ .Values.fullName | trimPrefix "app-" }}

# Common pattern for resource names
name: {{ include "mychart.fullname" . | trunc 63 | trimSuffix "-" }}
```

### upper / lower / title

Changes string case.

**Examples:**
```yaml
# Uppercase
env: {{ .Values.environment | upper }}  # Output: PRODUCTION

# Lowercase
name: {{ .Values.name | lower }}  # Output: myapp

# Title case
label: {{ .Values.label | title }}  # Output: My Application
```

### trunc

Truncates a string to a specified length.

**Examples:**
```yaml
# Truncate to 63 chars (K8s DNS limit)
name: {{ .Release.Name | trunc 63 | trimSuffix "-" }}

# Truncate to 20 chars
shortName: {{ .Values.name | trunc 20 }}
```

### repeat

Repeats a string N times.

**Examples:**
```yaml
# Repeat string
value: {{ "=" | repeat 10 }}  # Output: ==========

# Create separator
comment: {{ "#" | repeat 20 }}  # Output: ####################
```

### replace

Replaces occurrences of a substring.

**Examples:**
```yaml
# Replace underscores with hyphens
name: {{ .Values.name | replace "_" "-" }}

# Replace spaces
label: {{ .Values.label | replace " " "-" | lower }}

# Chart label (replace + with _)
chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
```

### substr

Extracts a substring.

**Examples:**
```yaml
# Get first 10 characters
short: {{ .Values.name | substr 0 10 }}

# Get characters 5-15
middle: {{ .Values.name | substr 5 15 }}
```

### nospace

Removes all whitespace from a string.

**Examples:**
```yaml
# Remove all spaces
compact: {{ .Values.value | nospace }}  # "hello world" → "helloworld"
```

### contains / hasPrefix / hasSuffix

Checks if a string contains, starts with, or ends with a substring.

**Examples:**
```yaml
# Check if contains
{{- if contains "prod" .Values.environment }}
  # Production configuration
{{- end }}

# Check prefix
{{- if hasPrefix "app-" .Values.name }}
  name: {{ .Values.name }}
{{- else }}
  name: {{ printf "app-%s" .Values.name }}
{{- end }}

# Check suffix
{{- if hasSuffix "-service" .Values.name }}
  # Already has suffix
{{- end }}
```

## Type Conversion Functions

### toYaml / fromYaml

Converts between Go objects and YAML strings.

**Examples:**
```yaml
# Convert to YAML
{{- with .Values.resources }}
resources:
  {{- toYaml . | nindent 2 }}
{{- end }}

# Parse YAML string
{{- $config := .Values.configYaml | fromYaml }}
{{- $config.database.host }}
```

### toJson / fromJson

Converts between Go objects and JSON strings.

**Examples:**
```yaml
# Convert to JSON
data:
  config.json: |
    {{- .Values.config | toJson | nindent 4 }}

# Parse JSON
{{- $data := .Values.jsonString | fromJson }}
{{- $data.key }}
```

### toString

Converts any value to a string.

**Examples:**
```yaml
# Convert number to string
port: {{ .Values.port | toString | quote }}

# Convert boolean to string
enabled: {{ .Values.enabled | toString }}
```

## List/Array Functions

### list

Creates a list.

**Examples:**
```yaml
# Create list
{{- $myList := list "a" "b" "c" }}

# Pass multiple arguments to template
{{- include "mychart.template" (list . "arg1" "arg2") }}
```

### append / prepend

Adds elements to a list.

**Examples:**
```yaml
# Append to list
{{- $list := list "a" "b" }}
{{- $list = append $list "c" }}  # ["a", "b", "c"]

# Prepend to list
{{- $list := list "b" "c" }}
{{- $list = prepend $list "a" }}  # ["a", "b", "c"]
```

### first / rest / last

Gets elements from a list.

**Examples:**
```yaml
# Get first element
{{- $first := first $myList }}

# Get all but first
{{- $rest := rest $myList }}

# Get last element
{{- $last := last $myList }}
```

### has

Checks if a list contains an element.

**Examples:**
```yaml
{{- if has "production" .Values.environments }}
  # Production configuration
{{- end }}
```

### compact

Removes empty/nil elements from a list.

**Examples:**
```yaml
{{- $list := list "a" "" "b" nil "c" }}
{{- $cleaned := compact $list }}  # ["a", "b", "c"]
```

### uniq

Removes duplicate elements.

**Examples:**
```yaml
{{- $list := list "a" "b" "a" "c" "b" }}
{{- $unique := uniq $list }}  # ["a", "b", "c"]
```

### sortAlpha

Sorts list alphabetically.

**Examples:**
```yaml
{{- $sorted := .Values.items | sortAlpha }}
```

## Dictionary/Map Functions

### dict

Creates a dictionary.

**Examples:**
```yaml
# Create dict
{{- $myDict := dict "key1" "value1" "key2" "value2" }}

# Pass custom context to template
{{- include "mychart.template" (dict "root" . "custom" "value") }}

# Complex context
{{- $ctx := dict "top" . "container" .Values.mainContainer "port" .Values.service.port }}
{{- include "mychart.container" $ctx }}
```

### merge / mergeOverwrite

Merges dictionaries.

**Examples:**
```yaml
# Merge dictionaries (dest, src1, src2, ...)
{{- $defaults := dict "replicas" 1 "port" 80 }}
{{- $overrides := dict "replicas" 3 }}
{{- $final := merge $overrides $defaults }}
# Result: {"replicas": 3, "port": 80}

# mergeOverwrite (right-most wins)
{{- $result := mergeOverwrite $dict1 $dict2 }}
```

### keys / values

Gets keys or values from a dictionary.

**Examples:**
```yaml
# Get all keys
{{- $keys := keys .Values.config }}

# Get all values
{{- $vals := values .Values.config }}

# Iterate over keys
{{- range $key := keys .Values.labels | sortAlpha }}
  {{ $key }}: {{ index $.Values.labels $key }}
{{- end }}
```

### pick / omit

Selects or excludes keys from a dictionary.

**Examples:**
```yaml
# Pick specific keys
{{- $subset := pick .Values.config "host" "port" }}

# Omit specific keys
{{- $filtered := omit .Values.config "password" "secret" }}
```

### hasKey

Checks if a dictionary has a key.

**Examples:**
```yaml
{{- if hasKey .Values "database" }}
  {{- if hasKey .Values.database "password" }}
    # Password is configured
  {{- end }}
{{- end }}
```

### pluck

Gets a value by key from multiple dictionaries.

**Examples:**
```yaml
# Get "name" from first dict that has it
{{- $name := pluck "name" .Values.override .Values.defaults | first }}
```

## Encoding Functions

### b64enc / b64dec

Base64 encode/decode.

**Examples:**
```yaml
# Encode secret
apiVersion: v1
kind: Secret
data:
  password: {{ .Values.password | b64enc }}

# Decode existing secret
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
{{- if $secret }}
  {{- $decoded := $secret.data.password | b64dec }}
{{- end }}
```

### sha256sum

Generates SHA256 hash.

**Examples:**
```yaml
# Create checksum annotation to trigger rolling update
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}

# Hash password
data:
  passwordHash: {{ .Values.password | sha256sum }}
```

### uuidv4

Generates a random UUID v4.

**Examples:**
```yaml
# Generate unique ID
id: {{ uuidv4 }}
```

## Mathematical Functions

### add / sub / mul / div / mod

Basic arithmetic operations.

**Examples:**
```yaml
# Addition
replicas: {{ add .Values.baseReplicas 2 }}

# Subtraction
port: {{ sub .Values.maxPort 100 }}

# Multiplication
memory: {{ mul .Values.memoryPerPod .Values.replicas }}

# Division
cpuPerPod: {{ div .Values.totalCpu .Values.replicas }}

# Modulo
remainder: {{ mod .Values.value 10 }}
```

### max / min

Gets maximum or minimum value.

**Examples:**
```yaml
# Ensure at least 1 replica
replicas: {{ max 1 .Values.replicaCount }}

# Cap at 10 replicas
replicas: {{ min 10 .Values.replicaCount }}
```

### floor / ceil / round

Rounding functions.

**Examples:**
```yaml
# Round down
value: {{ floor 3.7 }}  # 3

# Round up
value: {{ ceil 3.2 }}  # 4

# Round to nearest
value: {{ round 3.5 }}  # 4
```

## Date Functions

### now

Gets current time.

**Examples:**
```yaml
# Current timestamp
annotations:
  timestamp: {{ now | date "2006-01-02T15:04:05Z" }}
```

### date

Formats a date/time.

**Examples:**
```yaml
# Format date
date: {{ now | date "2006-01-02" }}  # 2024-01-15

# Full timestamp
timestamp: {{ now | date "2006-01-02T15:04:05Z07:00" }}

# Custom format
generated: {{ now | date "Monday, 02-Jan-06 15:04:05 MST" }}
```

### dateModify

Modifies a date.

**Examples:**
```yaml
# Add 24 hours
tomorrow: {{ now | dateModify "24h" }}

# Subtract 7 days
lastWeek: {{ now | dateModify "-168h" }}
```

## Comparison Functions

### eq / ne

Equality and inequality.

**Examples:**
```yaml
{{- if eq .Values.environment "production" }}
  # Production settings
{{- end }}

{{- if ne .Values.replicaCount 1 }}
  # Multiple replicas
{{- end }}
```

### lt / le / gt / ge

Less than, less than or equal, greater than, greater than or equal.

**Examples:**
```yaml
{{- if gt .Values.replicaCount 1 }}
  # Multiple replicas
{{- end }}

{{- if le .Values.maxConnections 100 }}
  # Low connection count
{{- end }}
```

### and / or / not

Logical operations.

**Examples:**
```yaml
{{- if and .Values.ingress.enabled .Values.ingress.tls.enabled }}
  # Ingress with TLS
{{- end }}

{{- if or (eq .Values.env "dev") (eq .Values.env "staging") }}
  # Non-production environment
{{- end }}

{{- if not .Values.production }}
  # Development mode
{{- end }}
```

## Flow Control Functions

### fail

Fails template rendering with an error message.

**Examples:**
```yaml
{{- if not .Values.required }}
  {{- fail "required value is not set" }}
{{- end }}

{{- if lt .Values.replicas 1 }}
  {{- fail "replicas must be at least 1" }}
{{- end }}
```

### coalesce

Returns the first non-empty value.

**Examples:**
```yaml
# Use first non-empty value
name: {{ coalesce .Values.nameOverride .Values.name .Chart.Name }}

# Multiple fallbacks
host: {{ coalesce .Values.database.host .Values.defaultHost "localhost" }}
```

### ternary

Inline if-then-else.

**Examples:**
```yaml
# Ternary operator
type: {{ ternary "LoadBalancer" "ClusterIP" .Values.production }}

# With comparison
replicas: {{ ternary 3 1 (eq .Values.env "production") }}
```

## Indentation Functions

### indent

Indents each line by N spaces.

**Examples:**
```yaml
# Indent by 4 spaces
metadata:
  labels:
{{ include "mychart.labels" . | indent 4 }}
```

### nindent

Adds a newline then indents.

**Examples:**
```yaml
# Newline + indent (preferred)
metadata:
  labels:
    {{- include "mychart.labels" . | nindent 4 }}
```

**Why prefer nindent:** Most YAML structures need a newline before the indented content, making `nindent` the right choice in most cases.

## Random Functions

### randAlphaNum

Generates random alphanumeric string.

**Examples:**
```yaml
# Generate random password
{{- $password := randAlphaNum 16 }}

# Generate unique suffix
name: {{ printf "%s-%s" .Release.Name (randAlphaNum 5) }}
```

### randAlpha / randNumeric

Generates random alphabetic or numeric string.

**Examples:**
```yaml
# Random letters only
code: {{ randAlpha 8 }}

# Random numbers only
id: {{ randNumeric 6 }}
```

### randAscii

Generates random ASCII string.

**Examples:**
```yaml
# Random ASCII characters
token: {{ randAscii 32 }}
```

## File Functions

### Files.Get

Reads a file from the chart.

**Examples:**
```yaml
# Read configuration file
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  config.yaml: |
    {{- .Files.Get "config/app.yaml" | nindent 4 }}
```

### Files.GetBytes

Reads a file as bytes (for binary files).

**Examples:**
```yaml
# Include binary file
data:
  image.png: {{ .Files.GetBytes "files/image.png" | b64enc }}
```

### Files.Glob

Reads multiple files matching a pattern.

**Examples:**
```yaml
# Include all YAML files
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  {{- range $path, $content := .Files.Glob "config/*.yaml" }}
  {{ base $path }}: |
    {{- $content | nindent 4 }}
  {{- end }}
```

### Files.Lines

Reads a file line by line.

**Examples:**
```yaml
# Process file line by line
{{- range .Files.Lines "config/servers.txt" }}
  - {{ . }}
{{- end }}
```

### Files.AsConfig / Files.AsSecrets

Creates ConfigMap or Secret data from files.

**Examples:**
```yaml
# ConfigMap from files
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  {{- (.Files.Glob "config/*").AsConfig | nindent 2 }}

# Secret from files
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "mychart.fullname" . }}
data:
  {{- (.Files.Glob "secrets/*").AsSecrets | nindent 2 }}
```

## Path Functions

### base / dir / ext / clean

Path manipulation functions.

**Examples:**
```yaml
# Get filename
{{- $filename := base "/path/to/file.yaml" }}  # file.yaml

# Get directory
{{- $dir := dir "/path/to/file.yaml" }}  # /path/to

# Get extension
{{- $ext := ext "file.yaml" }}  # .yaml

# Clean path
{{- $clean := clean "/path//to/../file" }}  # /path/file
```

## Regex Functions

### regexMatch

Tests if a string matches a regex.

**Examples:**
```yaml
{{- if regexMatch "^[0-9]+$" .Values.port }}
  # Port is numeric
{{- end }}
```

### regexFind / regexFindAll

Finds regex matches.

**Examples:**
```yaml
# Find first match
{{- $match := regexFind "[0-9]+" .Values.version }}

# Find all matches
{{- $matches := regexFindAll "[A-Z]+" .Values.name -1 }}
```

### regexReplaceAll

Replaces regex matches.

**Examples:**
```yaml
# Replace all digits
name: {{ regexReplaceAll "[0-9]" .Values.name "" }}

# Replace pattern
clean: {{ regexReplaceAll "[^a-z0-9-]" .Values.name "" }}
```

### regexSplit

Splits string by regex.

**Examples:**
```yaml
# Split by delimiter
{{- $parts := regexSplit ":" .Values.imageTag -1 }}
```

## Semantic Version Functions

### semver / semverCompare

Work with semantic versions.

**Examples:**
```yaml
# Parse semantic version
{{- $version := semver "1.2.3" }}
{{- $version.Major }}  # 1
{{- $version.Minor }}  # 2
{{- $version.Patch }}  # 3

# Compare versions
{{- if semverCompare ">=1.20.0" .Capabilities.KubeVersion.Version }}
  # Kubernetes 1.20 or higher
{{- end }}
```

## Advanced Patterns

### Custom Context Passing

```yaml
{{- define "mychart.container" -}}
{{- $root := .root }}
{{- $container := .container }}
{{- $port := .port }}
name: {{ $container.name }}
image: {{ $container.image }}
ports:
  - containerPort: {{ $port }}
{{- end }}

# Usage
{{- include "mychart.container" (dict "root" . "container" .Values.mainContainer "port" 8080) }}
```

### Multi-Stage Processing

```yaml
{{- $config := .Values.configYaml | fromYaml }}
{{- $merged := merge .Values.overrides $config }}
{{- $filtered := omit $merged "internalKey" }}
{{- toYaml $filtered | nindent 2 }}
```

### Conditional Value Selection

```yaml
{{- $value := "" }}
{{- if .Values.custom }}
{{- $value = .Values.custom }}
{{- else if .Values.default }}
{{- $value = .Values.default }}
{{- else }}
{{- $value = "fallback" }}
{{- end }}
```

### Pipeline Composition

```yaml
# Chain multiple functions
value: {{ .Values.name | trim | lower | replace " " "-" | trunc 63 | trimSuffix "-" | quote }}

# Multi-line pipeline
{{- .Values.config
  | toYaml
  | indent 2
  | trim }}
```

## Function Combination Examples

### Resource Name Generation

```yaml
{{- define "mychart.resourceName" -}}
{{- $name := include "mychart.fullname" . -}}
{{- $suffix := .suffix | default "" -}}
{{- if $suffix }}
{{- printf "%s-%s" $name $suffix | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
```

### Safe Value Extraction

```yaml
{{- $password := "" }}
{{- if and .Values.database (hasKey .Values.database "password") }}
{{- $password = .Values.database.password }}
{{- else }}
{{- $password = randAlphaNum 16 }}
{{- end }}
```

### Configuration Merging

```yaml
{{- $defaults := .Files.Get "config/defaults.yaml" | fromYaml }}
{{- $overrides := .Values.config | default (dict) }}
{{- $final := merge $overrides $defaults }}
config: |
  {{- $final | toYaml | nindent 2 }}
```

## Performance Tips

1. **Cache template results** - Use variables to avoid recalculating:
```yaml
{{- $fullname := include "mychart.fullname" . }}
name: {{ $fullname }}
matchLabels:
  app: {{ $fullname }}
```

2. **Minimize lookups** - `lookup` queries are expensive:
```yaml
{{- $secret := lookup "v1" "Secret" .Release.Namespace "my-secret" }}
{{- if $secret }}
  # Use $secret multiple times
{{- end }}
```

3. **Use with for scoping** - Reduces template complexity:
```yaml
{{- with .Values.ingress }}
  {{- if .enabled }}
    host: {{ .host }}
  {{- end }}
{{- end }}
```

## Debugging Functions

### printf

Formatted string output for debugging.

**Examples:**
```yaml
# Debug values
{{- printf "Debug: name=%s, replicas=%d" .Values.name .Values.replicas | fail }}
```

### toYaml for inspection

```yaml
# Inspect values
{{- toYaml .Values | fail }}
```

## Common Gotchas

1. **Nil vs Empty String**
```yaml
# This fails if value is nil
{{- if .Values.optional }}  # Error if nil!

# This works
{{- if .Values.optional | default "" }}  # Safe
```

2. **Type Conversion**
```yaml
# Port is integer in values but needs string comparison
{{- if eq (.Values.port | toString) "80" }}
```

3. **Pipeline Precedence**
```yaml
# Wrong - quote applies to "true", not the result
{{- if .Values.enabled | quote }}

# Right - use parentheses
{{- if (.Values.enabled | quote) }}
```

4. **Whitespace in Conditionals**
```yaml
# Creates extra whitespace
{{ if .Values.enabled }}
  value: true
{{ end }}

# Better - chomp whitespace
{{- if .Values.enabled }}
  value: true
{{- end }}
```
