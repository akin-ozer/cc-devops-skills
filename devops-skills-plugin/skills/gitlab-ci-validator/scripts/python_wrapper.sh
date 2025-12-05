#!/bin/bash
# Wrapper script that handles PyYAML dependency
# Creates a persistent venv if PyYAML is not available

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../.venv"

# Check if we have arguments
if [ $# -lt 2 ]; then
    echo "Usage: python_wrapper.sh <python-script> <args...>" >&2
    exit 1
fi

PYTHON_SCRIPT="$1"
shift  # Remove first argument, rest are passed to the Python script

# Try to run with system Python first
if python3 -c "import yaml" 2>/dev/null; then
    # PyYAML is available in system, run directly
    python3 "$PYTHON_SCRIPT" "$@"
    exit $?
fi

# PyYAML not available in system, check for venv
if [ ! -d "$VENV_DIR" ]; then
    # Create persistent venv
    echo "PyYAML not found. Creating persistent virtual environment..." >&2
    python3 -m venv "$VENV_DIR" >&2
    source "$VENV_DIR/bin/activate" >&2
    pip install --quiet pyyaml >&2
    echo "Virtual environment created at $VENV_DIR" >&2
    echo "" >&2
else
    # Use existing venv
    source "$VENV_DIR/bin/activate" >&2
fi

# Run the script with venv Python
python3 "$PYTHON_SCRIPT" "$@"
