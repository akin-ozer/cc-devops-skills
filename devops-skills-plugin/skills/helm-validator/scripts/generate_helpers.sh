#!/bin/bash
# Generate standard Helm helpers (_helpers.tpl) for a chart

set -e

# Parse arguments
FORCE=false
CHART_DIR=""

usage() {
    echo "Usage: $0 [OPTIONS] <chart-directory>"
    echo ""
    echo "Options:"
    echo "  -f, --force    Overwrite existing _helpers.tpl without prompting"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 ./mychart"
    echo "  $0 --force ./mychart"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "❌ Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
        *)
            if [ -z "$CHART_DIR" ]; then
                CHART_DIR="$1"
            else
                echo "❌ Multiple chart directories specified"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$CHART_DIR" ]; then
    echo "❌ Error: No chart directory specified"
    echo "Use --help for usage information"
    exit 1
fi

if [ ! -d "$CHART_DIR" ]; then
    echo "❌ Error: Directory '$CHART_DIR' does not exist"
    exit 1
fi

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    echo "❌ Error: Chart.yaml not found in '$CHART_DIR'"
    exit 1
fi

HELPERS_FILE="$CHART_DIR/templates/_helpers.tpl"

# Get chart name from Chart.yaml using awk (no yq dependency)
CHART_NAME=$(awk '/^name:/ {gsub(/^name:[[:space:]]*/, ""); gsub(/["\047]/, ""); print; exit}' "$CHART_DIR/Chart.yaml" 2>/dev/null)

if [ -z "$CHART_NAME" ]; then
    echo "❌ Error: Could not read chart name from Chart.yaml"
    exit 1
fi

echo "Generating Helm helpers for chart: $CHART_NAME"
echo

# Check if _helpers.tpl already exists
if [ -f "$HELPERS_FILE" ]; then
    echo "⚠️  Warning: $HELPERS_FILE already exists"
    echo "   This script will append to the existing file."
    echo "   Review the output carefully and remove duplicates."
    echo

    if [ "$FORCE" = true ]; then
        echo "ℹ️  Force mode enabled - proceeding without prompt"
    else
        # Check if stdin is a terminal (interactive mode)
        if [ -t 0 ]; then
            read -p "Continue? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Aborted."
                exit 0
            fi
        else
            echo "❌ Error: _helpers.tpl exists and running in non-interactive mode"
            echo "   Use --force flag to overwrite without prompting"
            exit 1
        fi
    fi
    echo >> "$HELPERS_FILE"  # Add newline before appending
else
    # Create templates directory if it doesn't exist
    mkdir -p "$CHART_DIR/templates"
fi

cat >> "$HELPERS_FILE" << EOF
{{/*
Expand the name of the chart.
*/}}
{{- define "${CHART_NAME}.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
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

echo "✅ Generated standard helpers in: $HELPERS_FILE"
echo
echo "Generated helper templates:"
echo "  • ${CHART_NAME}.name           - Expand chart name"
echo "  • ${CHART_NAME}.fullname       - Create fully qualified app name"
echo "  • ${CHART_NAME}.chart          - Chart name and version label"
echo "  • ${CHART_NAME}.labels         - Common labels"
echo "  • ${CHART_NAME}.selectorLabels - Selector labels"
echo "  • ${CHART_NAME}.serviceAccountName - Service account name"
echo
echo "Usage in templates:"
echo "  metadata:"
echo "    name: {{ include \"${CHART_NAME}.fullname\" . }}"
echo "    labels:"
echo "      {{- include \"${CHART_NAME}.labels\" . | nindent 4 }}"
echo
echo "Next steps:"
echo "  1. Review the generated helpers"
echo "  2. Update your templates to use these helpers"
echo "  3. Test with: helm template <release-name> $CHART_DIR"
