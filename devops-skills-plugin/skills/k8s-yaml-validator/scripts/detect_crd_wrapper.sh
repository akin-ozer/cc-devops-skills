#!/bin/bash
# Wrapper script for detect_crd.py that handles PyYAML dependency
# Creates a temporary venv if PyYAML is not available

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/detect_crd.py"

# Check if we have arguments
if [ $# -lt 1 ]; then
    echo "Usage: detect_crd_wrapper.sh <yaml-file>" >&2
    exit 1
fi

YAML_FILE="$1"

# Try to run with system Python first
if python3 -c "import yaml" 2>/dev/null; then
    # PyYAML is available, run directly
    python3 "$PYTHON_SCRIPT" "$YAML_FILE"
    exit $?
fi

# PyYAML not available, create temporary venv
TEMP_VENV=$(mktemp -d -t k8s-yaml-validator.XXXXXX)
trap "rm -rf $TEMP_VENV" EXIT

echo "PyYAML not found in system Python. Creating temporary environment..." >&2

# Create venv and install PyYAML
python3 -m venv "$TEMP_VENV" >&2
source "$TEMP_VENV/bin/activate" >&2
pip install --quiet pyyaml >&2

# Run the script
python3 "$PYTHON_SCRIPT" "$YAML_FILE"

# Cleanup happens automatically via trap
