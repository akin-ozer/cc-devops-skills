#!/bin/bash

# Script to scaffold basic Helm chart directory structure
# Usage: bash generate_chart_structure.sh <chart-name> <output-directory> [options]
#
# Options:
#   --force             Overwrite existing chart without prompting
#   --image <repo>      Set image repository WITHOUT tag (default: nginx)
#   --tag <tag>         Set image tag (default: uses chart appVersion)
#   --port <number>     Set service port (default: 80)
#   --type <type>       Set workload type: deployment, statefulset, daemonset (default: deployment)
#   --with-templates    Generate basic resource templates (deployment.yaml, service.yaml, etc.)
#   --with-ingress      Include ingress template (implies --with-templates)
#   --with-hpa          Include HPA template (implies --with-templates)
#
# Note: If --image contains a colon (e.g., redis:7-alpine), it will be automatically
#       split into repository and tag

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
FORCE=false
IMAGE_REPO="nginx"
IMAGE_TAG=""
SERVICE_PORT=80
WORKLOAD_TYPE="deployment"
WITH_TEMPLATES=false
WITH_INGRESS=false
WITH_HPA=false

# Function to print error and exit
error_exit() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

# Function to print warning
warn() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
}

# Function to validate chart name (DNS-1123 subdomain)
# Must be lowercase, alphanumeric, hyphens allowed (not at start/end), max 63 chars
validate_chart_name() {
    local name="$1"

    # Check if empty
    if [ -z "$name" ]; then
        error_exit "Chart name cannot be empty"
    fi

    # Check length (max 63 characters for DNS-1123)
    if [ ${#name} -gt 63 ]; then
        error_exit "Chart name '${name}' exceeds 63 characters (DNS-1123 limit)"
    fi

    # Check for valid characters (lowercase alphanumeric and hyphens)
    if ! echo "$name" | grep -qE '^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'; then
        error_exit "Chart name '${name}' is invalid. Must:
  - Start with a lowercase letter or number
  - Contain only lowercase letters, numbers, and hyphens
  - End with a lowercase letter or number
  - Not contain consecutive hyphens
Examples: myapp, my-app, app1, my-cool-app"
    fi

    # Check for consecutive hyphens
    if echo "$name" | grep -q '\-\-'; then
        error_exit "Chart name '${name}' contains consecutive hyphens (not allowed)"
    fi
}

# Function to validate port number
validate_port() {
    local port="$1"
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error_exit "Invalid port number '${port}'. Must be between 1 and 65535"
    fi
}

# Function to validate workload type
validate_workload_type() {
    local type="$1"
    case "$type" in
        deployment|statefulset|daemonset)
            return 0
            ;;
        *)
            error_exit "Invalid workload type '${type}'. Must be: deployment, statefulset, or daemonset"
            ;;
    esac
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 <chart-name> <output-directory> [options]

Arguments:
  chart-name        Name of the Helm chart (must be DNS-1123 compliant)
  output-directory  Directory where chart will be created

Options:
  --force           Overwrite existing chart without prompting
  --image <repo>    Set image repository (default: nginx)
                    Note: If image contains ':' (e.g., redis:7-alpine), it will be
                    automatically split into repository and tag
  --tag <tag>       Set image tag (default: uses chart appVersion)
  --port <number>   Set service port (default: 80)
  --type <type>     Set workload type: deployment, statefulset, daemonset (default: deployment)
  --with-templates  Generate basic resource templates (deployment.yaml, service.yaml, etc.)
  --with-ingress    Include ingress template (implies --with-templates)
  --with-hpa        Include HPA template (implies --with-templates)
  -h, --help        Show this help message

Examples:
  $0 myapp ./charts
  $0 my-service ./charts --image myregistry/myapp --port 8080
  $0 my-service ./charts --image redis --tag 7-alpine
  $0 my-db ./charts --type statefulset --force
  $0 myapp ./charts --with-templates --with-ingress

Chart name requirements (DNS-1123 subdomain):
  - Maximum 63 characters
  - Lowercase letters, numbers, and hyphens only
  - Must start and end with alphanumeric character
  - No consecutive hyphens
EOF
    exit 0
}

# Parse arguments
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --image)
            IMAGE_REPO="$2"
            shift 2
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --port)
            SERVICE_PORT="$2"
            shift 2
            ;;
        --type)
            WORKLOAD_TYPE="$2"
            shift 2
            ;;
        --with-templates)
            WITH_TEMPLATES=true
            shift
            ;;
        --with-ingress)
            WITH_TEMPLATES=true
            WITH_INGRESS=true
            shift
            ;;
        --with-hpa)
            WITH_TEMPLATES=true
            WITH_HPA=true
            shift
            ;;
        -*)
            error_exit "Unknown option: $1. Use --help for usage information."
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
    esac
done

# Restore positional parameters
set -- "${POSITIONAL_ARGS[@]}"

# Check required arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <chart-name> <output-directory> [options]"
    echo "Example: $0 myapp ./charts"
    echo "Use --help for more information"
    exit 1
fi

CHART_NAME="$1"
OUTPUT_DIR="$2"
CHART_DIR="${OUTPUT_DIR}/${CHART_NAME}"

# Validate inputs
validate_chart_name "$CHART_NAME"
validate_port "$SERVICE_PORT"
validate_workload_type "$WORKLOAD_TYPE"

# Auto-split image:tag if colon is present and --tag wasn't explicitly set
if [[ "$IMAGE_REPO" == *":"* ]] && [ -z "$IMAGE_TAG" ]; then
    # Split on the last colon (to handle registry:port/image:tag format)
    IMAGE_TAG="${IMAGE_REPO##*:}"
    IMAGE_REPO="${IMAGE_REPO%:*}"
    echo "  Note: Auto-split image into repository '${IMAGE_REPO}' and tag '${IMAGE_TAG}'"
fi

# Check if chart directory already exists
if [ -d "$CHART_DIR" ]; then
    if [ "$FORCE" = true ]; then
        warn "Overwriting existing chart at ${CHART_DIR}"
        rm -rf "$CHART_DIR"
    else
        echo -e "${YELLOW}Chart directory already exists: ${CHART_DIR}${NC}"
        read -p "Do you want to overwrite it? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted. Use --force to overwrite without prompting."
            exit 1
        fi
        rm -rf "$CHART_DIR"
    fi
fi

echo "Creating Helm chart structure for: ${CHART_NAME}"
echo "  Output directory: ${CHART_DIR}"
echo "  Image: ${IMAGE_REPO}"
echo "  Port: ${SERVICE_PORT}"
echo "  Workload type: ${WORKLOAD_TYPE}"

# Create directories
mkdir -p "${CHART_DIR}/templates"
mkdir -p "${CHART_DIR}/charts"

# Create Chart.yaml
cat > "${CHART_DIR}/Chart.yaml" <<EOF
apiVersion: v2
name: ${CHART_NAME}
description: A Helm chart for Kubernetes
type: application

# This is the chart version. This version number should be incremented each time you make changes
# to the chart and its templates, including the app version.
# Versions are expected to follow Semantic Versioning (https://semver.org/)
version: 0.1.0

# This is the version number of the application being deployed. This version number should be
# incremented each time you make changes to the application. Versions are not expected to
# follow Semantic Versioning. They should reflect the version the application is using.
appVersion: "1.0.0"
EOF

# Create values.yaml with customized settings
cat > "${CHART_DIR}/values.yaml" <<EOF
# Default values for ${CHART_NAME}.
# This is a YAML-formatted file.
# Declare variables to be passed into your templates.

# Workload type: ${WORKLOAD_TYPE}
replicaCount: 1

image:
  repository: ${IMAGE_REPO}
  pullPolicy: IfNotPresent
  # Overrides the image tag whose default is the chart appVersion.
  tag: "${IMAGE_TAG}"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  # Specifies whether a service account should be created
  create: true
  # Automatically mount a ServiceAccount's API credentials?
  automount: true
  # Annotations to add to the service account
  annotations: {}
  # The name of the service account to use.
  # If not set and create is true, a name is generated using the fullname template
  name: ""

podAnnotations: {}
podLabels: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: ${SERVICE_PORT}
  targetPort: 8080
  # -- Port name used in service and container port definitions
  # Customize for non-HTTP services (e.g., redis, mysql, grpc)
  portName: http

# -- Liveness probe configuration
livenessProbe:
  httpGet:
    path: /healthz
    port: http
  initialDelaySeconds: 30
  periodSeconds: 10

# -- Readiness probe configuration
readinessProbe:
  httpGet:
    path: /ready
    port: http
  initialDelaySeconds: 5
  periodSeconds: 5

# -- Startup probe configuration (for slow-starting containers)
startupProbe: {}
  # httpGet:
  #   path: /healthz
  #   port: http
  # initialDelaySeconds: 10
  # periodSeconds: 10
  # failureThreshold: 30

ingress:
  enabled: false
  className: ""
  annotations: {}
    # kubernetes.io/ingress.class: nginx
    # kubernetes.io/tls-acme: "true"
  hosts:
    - host: ${CHART_NAME}.local
      paths:
        - path: /
          pathType: ImplementationSpecific
  tls: []
  #  - secretName: ${CHART_NAME}-tls
  #    hosts:
  #      - ${CHART_NAME}.local

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 100
  targetCPUUtilizationPercentage: 80
  # targetMemoryUtilizationPercentage: 80
EOF

# Add StatefulSet-specific values if workload type is statefulset
if [ "$WORKLOAD_TYPE" = "statefulset" ]; then
    cat >> "${CHART_DIR}/values.yaml" <<EOF

# StatefulSet specific configuration
persistence:
  enabled: true
  storageClass: ""
  accessModes:
    - ReadWriteOnce
  size: 1Gi
  mountPath: /data
EOF
fi

# Add DaemonSet-specific values if workload type is daemonset
if [ "$WORKLOAD_TYPE" = "daemonset" ]; then
    cat >> "${CHART_DIR}/values.yaml" <<EOF

# DaemonSet specific configuration
updateStrategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1

# Host networking (for node-level daemons)
hostNetwork: false
hostPID: false
EOF
fi

# Add common trailing values
cat >> "${CHART_DIR}/values.yaml" <<EOF

# -- Environment variables
env: []
# - name: ENV_VAR_NAME
#   value: "value"

# -- Environment variables from ConfigMaps or Secrets
envFrom: []
# - configMapRef:
#     name: my-configmap
# - secretRef:
#     name: my-secret

# -- Volume mounts
volumeMounts: []
# - name: config
#   mountPath: /etc/config

# -- Volumes
volumes: []
# - name: config
#   configMap:
#     name: my-config

nodeSelector: {}

tolerations: []

affinity: {}
EOF

# Create .helmignore
cat > "${CHART_DIR}/.helmignore" <<EOF
# Patterns to ignore when building packages.
# This supports shell glob matching, relative path matching, and
# negation (prefixed with !). Only one pattern per line.
.DS_Store
# Common VCS dirs
.git/
.gitignore
.bzr/
.bzrignore
.hg/
.hgignore
.svn/
# Common backup files
*.swp
*.bak
*.tmp
*.orig
*~
# Various IDEs
.project
.idea/
*.tmproj
.vscode/
# CI/CD
.github/
.gitlab-ci.yml
# Testing
test/
tests/
*.test
# Documentation
README.md
CONTRIBUTING.md
EOF

# Create NOTES.txt
cat > "${CHART_DIR}/templates/NOTES.txt" <<EOF
Thank you for installing {{ .Chart.Name }}.

Your release is named {{ .Release.Name }}.

To get the status of your release:

  helm status {{ .Release.Name }} -n {{ .Release.Namespace }}

To connect to your service:
{{- if and .Values.ingress (eq .Values.ingress.enabled true) }}
{{- range \$host := .Values.ingress.hosts }}
  {{- range .paths }}
  http{{ if \$.Values.ingress.tls }}s{{ end }}://{{ \$host.host }}{{ .path }}
  {{- end }}
{{- end }}
{{- else if contains "NodePort" .Values.service.type }}
  export NODE_PORT=\$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "${CHART_NAME}.fullname" . }})
  export NODE_IP=\$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo "Service available at: \$NODE_IP:\$NODE_PORT"
{{- else if contains "LoadBalancer" .Values.service.type }}
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
  kubectl get svc --namespace {{ .Release.Namespace }} -w {{ include "${CHART_NAME}.fullname" . }}

  export SERVICE_IP=\$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "${CHART_NAME}.fullname" . }} --template "{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}")
  echo "Service available at: \$SERVICE_IP:{{ .Values.service.port }}"
{{- else if contains "ClusterIP" .Values.service.type }}
  kubectl port-forward --namespace {{ .Release.Namespace }} svc/{{ include "${CHART_NAME}.fullname" . }} {{ .Values.service.port }}:{{ .Values.service.port }}

  Then access via: localhost:{{ .Values.service.port }}
{{- end }}
EOF

# Generate _helpers.tpl using the standard helpers script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/generate_standard_helpers.sh" ]; then
    bash "${SCRIPT_DIR}/generate_standard_helpers.sh" "${CHART_NAME}" "${CHART_DIR}" 2>/dev/null || true
fi

# Generate resource templates if requested
if [ "$WITH_TEMPLATES" = true ]; then
    echo "  Generating resource templates..."

    # Generate ServiceAccount template
    cat > "${CHART_DIR}/templates/serviceaccount.yaml" <<SAEOF
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "${CHART_NAME}.serviceAccountName" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automount }}
{{- end }}
SAEOF

    # Generate Service template
    cat > "${CHART_DIR}/templates/service.yaml" <<SVCEOF
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.portName | default "http" }}
      protocol: TCP
      name: {{ .Values.service.portName | default "http" }}
  selector:
    {{- include "${CHART_NAME}.selectorLabels" . | nindent 4 }}
SVCEOF

    # Generate headless service for StatefulSet
    if [ "$WORKLOAD_TYPE" = "statefulset" ]; then
        cat > "${CHART_DIR}/templates/service-headless.yaml" <<HLSVCEOF
apiVersion: v1
kind: Service
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}-headless
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.portName | default "http" }}
      protocol: TCP
      name: {{ .Values.service.portName | default "http" }}
  selector:
    {{- include "${CHART_NAME}.selectorLabels" . | nindent 4 }}
HLSVCEOF
    fi

    # Generate workload template based on type
    case "$WORKLOAD_TYPE" in
        deployment)
            cat > "${CHART_DIR}/templates/deployment.yaml" <<DEPEOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "${CHART_NAME}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if .Values.configMap }}
        {{- if .Values.configMap.enabled }}
        checksum/config: {{ include (print \$.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
        {{- if .Values.secret }}
        {{- if .Values.secret.enabled }}
        checksum/secret: {{ include (print \$.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
      labels:
        {{- include "${CHART_NAME}.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "${CHART_NAME}.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: {{ .Values.service.portName | default "http" }}
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
DEPEOF
            ;;
        statefulset)
            cat > "${CHART_DIR}/templates/statefulset.yaml" <<STSEOF
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  serviceName: {{ include "${CHART_NAME}.fullname" . }}-headless
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      {{- include "${CHART_NAME}.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if .Values.configMap }}
        {{- if .Values.configMap.enabled }}
        checksum/config: {{ include (print \$.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
        {{- if .Values.secret }}
        {{- if .Values.secret.enabled }}
        checksum/secret: {{ include (print \$.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
      labels:
        {{- include "${CHART_NAME}.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "${CHART_NAME}.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: {{ .Values.service.portName | default "http" }}
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          volumeMounts:
            {{- if .Values.persistence.enabled }}
            - name: data
              mountPath: {{ .Values.persistence.mountPath }}
            {{- end }}
            {{- with .Values.volumeMounts }}
            {{- toYaml . | nindent 12 }}
            {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
  {{- if .Values.persistence.enabled }}
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          {{- range .Values.persistence.accessModes }}
          - {{ . | quote }}
          {{- end }}
        {{- if .Values.persistence.storageClass }}
        storageClassName: {{ .Values.persistence.storageClass | quote }}
        {{- end }}
        resources:
          requests:
            storage: {{ .Values.persistence.size | quote }}
  {{- end }}
STSEOF
            ;;
        daemonset)
            cat > "${CHART_DIR}/templates/daemonset.yaml" <<DSEOF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  selector:
    matchLabels:
      {{- include "${CHART_NAME}.selectorLabels" . | nindent 6 }}
  {{- with .Values.updateStrategy }}
  updateStrategy:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        {{- if .Values.configMap }}
        {{- if .Values.configMap.enabled }}
        checksum/config: {{ include (print \$.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
        {{- if .Values.secret }}
        {{- if .Values.secret.enabled }}
        checksum/secret: {{ include (print \$.Template.BasePath "/secret.yaml") . | sha256sum }}
        {{- end }}
        {{- end }}
      labels:
        {{- include "${CHART_NAME}.labels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "${CHART_NAME}.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      hostNetwork: {{ .Values.hostNetwork | default false }}
      {{- if .Values.hostPID }}
      hostPID: true
      {{- end }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: {{ .Values.service.portName | default "http" }}
              containerPort: {{ .Values.service.targetPort }}
              protocol: TCP
          {{- with .Values.livenessProbe }}
          livenessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.readinessProbe }}
          readinessProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.startupProbe }}
          startupProbe:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          {{- with .Values.env }}
          env:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.envFrom }}
          envFrom:
            {{- toYaml . | nindent 12 }}
          {{- end }}
          {{- with .Values.volumeMounts }}
          volumeMounts:
            {{- toYaml . | nindent 12 }}
          {{- end }}
      {{- with .Values.volumes }}
      volumes:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
DSEOF
            ;;
    esac

    # Generate Ingress template if requested
    if [ "$WITH_INGRESS" = true ]; then
        cat > "${CHART_DIR}/templates/ingress.yaml" <<'INGEOF'
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "CHART_PLACEHOLDER.fullname" . }}
  labels:
    {{- include "CHART_PLACEHOLDER.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "CHART_PLACEHOLDER.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
INGEOF
        sed -i.bak "s/CHART_PLACEHOLDER/${CHART_NAME}/g" "${CHART_DIR}/templates/ingress.yaml"
        rm -f "${CHART_DIR}/templates/ingress.yaml.bak"
    fi

    # Generate HPA template if requested (only for Deployment and StatefulSet)
    if [ "$WITH_HPA" = true ] && [ "$WORKLOAD_TYPE" != "daemonset" ]; then
        # Determine the workload kind for HPA
        HPA_KIND="Deployment"
        if [ "$WORKLOAD_TYPE" = "statefulset" ]; then
            HPA_KIND="StatefulSet"
        fi
        cat > "${CHART_DIR}/templates/hpa.yaml" <<HPAEOF
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "${CHART_NAME}.fullname" . }}
  labels:
    {{- include "${CHART_NAME}.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: ${HPA_KIND}
    name: {{ include "${CHART_NAME}.fullname" . }}
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
HPAEOF
    elif [ "$WITH_HPA" = true ] && [ "$WORKLOAD_TYPE" = "daemonset" ]; then
        warn "HPA is not applicable for DaemonSet workloads - skipping hpa.yaml"
    fi
    echo "  ✅ Resource templates generated"
fi

echo ""
echo -e "${GREEN}✅ Chart structure created successfully!${NC}"
echo ""
echo "   📁 ${CHART_DIR}/"
echo "   ├── Chart.yaml"
echo "   ├── values.yaml"
echo "   ├── .helmignore"
echo "   ├── templates/"
if [ -f "${CHART_DIR}/templates/_helpers.tpl" ]; then
    echo "   │   ├── _helpers.tpl"
fi
echo "   │   ├── NOTES.txt"
if [ "$WITH_TEMPLATES" = true ]; then
    echo "   │   ├── serviceaccount.yaml"
    echo "   │   ├── service.yaml"
    if [ "$WORKLOAD_TYPE" = "statefulset" ]; then
        echo "   │   ├── service-headless.yaml"
        echo "   │   ├── statefulset.yaml"
    elif [ "$WORKLOAD_TYPE" = "daemonset" ]; then
        echo "   │   ├── daemonset.yaml"
    else
        echo "   │   ├── deployment.yaml"
    fi
    if [ "$WITH_INGRESS" = true ]; then
        echo "   │   ├── ingress.yaml"
    fi
    if [ "$WITH_HPA" = true ] && [ "$WORKLOAD_TYPE" != "daemonset" ]; then
        echo "   │   └── hpa.yaml"
    fi
fi
echo "   └── charts/"
echo ""
echo "Next steps:"
if [ "$WITH_TEMPLATES" = true ]; then
    echo "1. Customize values in ${CHART_DIR}/values.yaml"
    echo "2. Validate with: helm lint ${CHART_DIR}"
    echo "3. Test rendering: helm template test ${CHART_DIR}"
else
    echo "1. Generate templates or use --with-templates flag"
    echo "2. Customize values in ${CHART_DIR}/values.yaml"
    echo "3. Validate with: helm lint ${CHART_DIR}"
fi
