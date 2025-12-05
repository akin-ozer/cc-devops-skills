#!/bin/bash

# Script to generate standard Helm helpers (_helpers.tpl)
# Usage: bash generate_standard_helpers.sh <chart-name> <chart-directory> [options]
#
# Options:
#   --force    Overwrite existing _helpers.tpl without prompting

set -e

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
FORCE=false

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
Examples: myapp, my-app, app1, my-cool-app"
    fi

    # Check for consecutive hyphens
    if echo "$name" | grep -q '\-\-'; then
        error_exit "Chart name '${name}' contains consecutive hyphens (not allowed)"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 <chart-name> <chart-directory> [options]

Arguments:
  chart-name        Name of the Helm chart (must be DNS-1123 compliant)
  chart-directory   Directory of the chart (must exist)

Options:
  --force           Overwrite existing _helpers.tpl without prompting
  -h, --help        Show this help message

Examples:
  $0 myapp ./myapp
  $0 my-service ./charts/my-service --force
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
    echo "Usage: $0 <chart-name> <chart-directory> [options]"
    echo "Example: $0 myapp ./myapp"
    echo "Use --help for more information"
    exit 1
fi

CHART_NAME="$1"
CHART_DIR="$2"
HELPERS_FILE="${CHART_DIR}/templates/_helpers.tpl"

# Validate chart name
validate_chart_name "$CHART_NAME"

# Check if chart directory exists
if [ ! -d "$CHART_DIR" ]; then
    error_exit "Chart directory does not exist: ${CHART_DIR}"
fi

# Check if _helpers.tpl already exists
if [ -f "$HELPERS_FILE" ]; then
    if [ "$FORCE" = true ]; then
        warn "Overwriting existing _helpers.tpl at ${HELPERS_FILE}"
    else
        echo -e "${YELLOW}File already exists: ${HELPERS_FILE}${NC}"
        read -p "Do you want to overwrite it? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborted. Use --force to overwrite without prompting."
            exit 1
        fi
    fi
fi

# Ensure templates directory exists
mkdir -p "${CHART_DIR}/templates"

# Generate _helpers.tpl
cat > "${HELPERS_FILE}" <<EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "${CHART_NAME}.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "${CHART_NAME}.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- \$name := default .Chart.Name .Values.nameOverride }}
{{- if contains \$name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name \$name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "${CHART_NAME}.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "${CHART_NAME}.labels" -}}
helm.sh/chart: {{ include "${CHART_NAME}.chart" . }}
{{ include "${CHART_NAME}.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "${CHART_NAME}.selectorLabels" -}}
app.kubernetes.io/name: {{ include "${CHART_NAME}.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "${CHART_NAME}.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "${CHART_NAME}.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
EOF

echo "✅ Generated _helpers.tpl at ${HELPERS_FILE}"
echo "   Chart name: ${CHART_NAME}"
echo "   Standard helpers included:"
echo "   - ${CHART_NAME}.name"
echo "   - ${CHART_NAME}.fullname"
echo "   - ${CHART_NAME}.chart"
echo "   - ${CHART_NAME}.labels"
echo "   - ${CHART_NAME}.selectorLabels"
echo "   - ${CHART_NAME}.serviceAccountName"
