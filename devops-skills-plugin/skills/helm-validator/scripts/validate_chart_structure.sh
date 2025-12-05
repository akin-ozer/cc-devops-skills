#!/bin/bash
# Validate Helm chart directory structure

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <chart-directory>"
    exit 1
fi

CHART_DIR="$1"

if [ ! -d "$CHART_DIR" ]; then
    echo "❌ Error: Directory '$CHART_DIR' does not exist"
    exit 1
fi

echo "Validating Helm chart structure: $CHART_DIR"
echo

ERRORS=()
WARNINGS=()

# Check for required files
echo "Checking required files..."

if [ ! -f "$CHART_DIR/Chart.yaml" ]; then
    ERRORS+=("Chart.yaml is missing (REQUIRED)")
    echo "❌ Chart.yaml not found"
else
    echo "✅ Chart.yaml found"

    # Validate Chart.yaml syntax and required fields
    if command -v yq &> /dev/null; then
        if ! yq eval '.' "$CHART_DIR/Chart.yaml" > /dev/null 2>&1; then
            ERRORS+=("Chart.yaml has invalid YAML syntax")
            echo "❌ Chart.yaml has invalid syntax"
        else
            # Check required fields
            API_VERSION=$(yq eval '.apiVersion' "$CHART_DIR/Chart.yaml" 2>/dev/null)
            NAME=$(yq eval '.name' "$CHART_DIR/Chart.yaml" 2>/dev/null)
            VERSION=$(yq eval '.version' "$CHART_DIR/Chart.yaml" 2>/dev/null)

            if [ "$API_VERSION" = "null" ] || [ -z "$API_VERSION" ]; then
                ERRORS+=("Chart.yaml is missing 'apiVersion' field")
            elif [ "$API_VERSION" != "v2" ]; then
                WARNINGS+=("Chart.yaml apiVersion should be 'v2' for Helm 3+, found: $API_VERSION")
            fi

            if [ "$NAME" = "null" ] || [ -z "$NAME" ]; then
                ERRORS+=("Chart.yaml is missing 'name' field")
            fi

            if [ "$VERSION" = "null" ] || [ -z "$VERSION" ]; then
                ERRORS+=("Chart.yaml is missing 'version' field")
            fi
        fi
    else
        echo "   ℹ️  yq not installed - skipping Chart.yaml field validation"
        echo "   Install yq for enhanced validation: brew install yq"
    fi
fi

if [ ! -f "$CHART_DIR/values.yaml" ]; then
    ERRORS+=("values.yaml is missing (REQUIRED)")
    echo "❌ values.yaml not found"
else
    echo "✅ values.yaml found"

    # Validate values.yaml syntax
    if command -v yq &> /dev/null; then
        if ! yq eval '.' "$CHART_DIR/values.yaml" > /dev/null 2>&1; then
            ERRORS+=("values.yaml has invalid YAML syntax")
            echo "❌ values.yaml has invalid syntax"
        fi
    fi
fi

if [ ! -d "$CHART_DIR/templates" ]; then
    ERRORS+=("templates/ directory is missing (REQUIRED)")
    echo "❌ templates/ directory not found"
else
    echo "✅ templates/ directory found"

    # Check if templates directory has any files
    TEMPLATE_COUNT=$(find "$CHART_DIR/templates" -type f -name "*.yaml" -o -name "*.tpl" | wc -l)
    if [ "$TEMPLATE_COUNT" -eq 0 ]; then
        WARNINGS+=("templates/ directory is empty")
        echo "⚠️  templates/ directory is empty"
    else
        echo "   Found $TEMPLATE_COUNT template files"
    fi
fi

echo
echo "Checking recommended files..."

if [ ! -f "$CHART_DIR/templates/_helpers.tpl" ]; then
    WARNINGS+=("templates/_helpers.tpl not found (RECOMMENDED for template helpers)")
    echo "⚠️  templates/_helpers.tpl not found"
else
    echo "✅ templates/_helpers.tpl found"
fi

if [ ! -f "$CHART_DIR/templates/NOTES.txt" ]; then
    WARNINGS+=("templates/NOTES.txt not found (RECOMMENDED for post-install notes)")
    echo "⚠️  templates/NOTES.txt not found"
else
    echo "✅ templates/NOTES.txt found"
fi

if [ ! -f "$CHART_DIR/.helmignore" ]; then
    WARNINGS+=(".helmignore not found (RECOMMENDED to exclude files from packaging)")
    echo "⚠️  .helmignore not found"
else
    echo "✅ .helmignore found"
fi

if [ ! -f "$CHART_DIR/README.md" ]; then
    WARNINGS+=("README.md not found (RECOMMENDED for chart documentation)")
    echo "⚠️  README.md not found"
else
    echo "✅ README.md found"
fi

echo
echo "Checking optional files..."

if [ -f "$CHART_DIR/values.schema.json" ]; then
    echo "✅ values.schema.json found (provides values validation)"

    # Validate JSON syntax if jq is available
    if command -v jq &> /dev/null; then
        if ! jq empty "$CHART_DIR/values.schema.json" > /dev/null 2>&1; then
            ERRORS+=("values.schema.json has invalid JSON syntax")
            echo "❌ values.schema.json has invalid syntax"
        fi
    fi
else
    echo "ℹ️  values.schema.json not found (optional)"
fi

if [ -d "$CHART_DIR/charts" ]; then
    DEPS_COUNT=$(find "$CHART_DIR/charts" -type f -name "*.tgz" | wc -l)
    echo "✅ charts/ directory found ($DEPS_COUNT packaged dependencies)"
else
    echo "ℹ️  charts/ directory not found (optional - used for dependencies)"
fi

if [ -d "$CHART_DIR/crds" ]; then
    CRD_COUNT=$(find "$CHART_DIR/crds" -type f -name "*.yaml" | wc -l)
    echo "✅ crds/ directory found ($CRD_COUNT CRD files)"
else
    echo "ℹ️  crds/ directory not found (optional - used for Custom Resource Definitions)"
fi

if [ -f "$CHART_DIR/LICENSE" ]; then
    echo "✅ LICENSE found"
else
    echo "ℹ️  LICENSE not found (optional)"
fi

echo
echo "File permissions check..."

# Check if Chart.yaml is readable
if [ ! -r "$CHART_DIR/Chart.yaml" ]; then
    ERRORS+=("Chart.yaml is not readable - check file permissions")
fi

# Check if values.yaml is readable
if [ -f "$CHART_DIR/values.yaml" ] && [ ! -r "$CHART_DIR/values.yaml" ]; then
    ERRORS+=("values.yaml is not readable - check file permissions")
fi

# Check if templates directory is readable
if [ -d "$CHART_DIR/templates" ] && [ ! -r "$CHART_DIR/templates" ]; then
    ERRORS+=("templates/ directory is not readable - check permissions")
fi

echo
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ ${#ERRORS[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "✅ Chart structure is valid!"
    echo "   All required files are present and readable."
    exit 0
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo
    echo "❌ Errors found (${#ERRORS[@]}):"
    for error in "${ERRORS[@]}"; do
        echo "   • $error"
    done
fi

if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo
    echo "⚠️  Warnings (${#WARNINGS[@]}):"
    for warning in "${WARNINGS[@]}"; do
        echo "   • $warning"
    done
fi

if [ ${#ERRORS[@]} -gt 0 ]; then
    echo
    echo "❌ Chart structure validation FAILED"
    exit 1
else
    echo
    echo "✅ Chart structure is valid (with warnings)"
    exit 0
fi
