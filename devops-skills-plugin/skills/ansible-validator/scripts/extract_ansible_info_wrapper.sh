#!/bin/bash
# Wrapper script for extract_ansible_info.py that handles PyYAML dependency
# Creates a temporary venv if PyYAML is not available

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/extract_ansible_info.py"

# Check if we have arguments
if [ $# -lt 1 ]; then
    echo "Usage: extract_ansible_info_wrapper.sh <playbook-or-role-path>" >&2
    exit 1
fi

TARGET_PATH="$1"

# Try to run with system Python first
if python3 -c "import yaml" 2>/dev/null; then
    # PyYAML is available, run directly
    python3 "$PYTHON_SCRIPT" "$TARGET_PATH"
    exit $?
fi

# PyYAML not available, create temporary venv
TEMP_VENV=$(mktemp -d -t ansible-validator.XXXXXX)
trap "rm -rf $TEMP_VENV" EXIT

echo "PyYAML not found in system Python. Creating temporary environment..." >&2

# Create venv and install PyYAML
python3 -m venv "$TEMP_VENV" >&2
source "$TEMP_VENV/bin/activate" >&2
pip install --quiet pyyaml >&2

# Run the script
python3 "$PYTHON_SCRIPT" "$TARGET_PATH"

# Cleanup happens automatically via trap
