#!/bin/bash
# Wrapper script for detect_crd.py that handles PyYAML dependency
# Creates a temporary venv if PyYAML is not available

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/detect_crd.py"

# Check if we have arguments
if [ $# -lt 1 ]; then
    echo "Usage: detect_crd_wrapper.sh <yaml-file> [yaml-file ...]" >&2
    exit 1
fi

YAML_FILES=("$@")
VALID_FILES=()

for yaml_file in "${YAML_FILES[@]}"; do
    if [ -f "$yaml_file" ]; then
        VALID_FILES+=("$yaml_file")
    else
        echo "Warning: file not found, skipping: $yaml_file" >&2
    fi
done

if [ ${#VALID_FILES[@]} -eq 0 ]; then
    # No valid files to process is not an error for batch workflows.
    echo "[]"
    exit 0
fi

# Try to run with system Python first
if python3 -c "import yaml" 2>/dev/null; then
    # PyYAML is available, run directly
    python3 "$PYTHON_SCRIPT" "${VALID_FILES[@]}"
    exit 0
fi

# PyYAML not available, create temporary venv
TEMP_VENV=$(mktemp -d -t helm-validator.XXXXXX)
trap 'rm -rf "$TEMP_VENV"' EXIT

echo "PyYAML not found in system Python. Creating temporary environment..." >&2

# Create venv and install PyYAML
python3 -m venv "$TEMP_VENV" >/dev/null 2>&1 || {
    echo "Error: failed to create temporary virtual environment" >&2
    exit 1
}
"$TEMP_VENV/bin/python3" -m pip install --quiet --disable-pip-version-check pyyaml

# Run the script
"$TEMP_VENV/bin/python3" "$PYTHON_SCRIPT" "${VALID_FILES[@]}"

# Cleanup happens automatically via trap
