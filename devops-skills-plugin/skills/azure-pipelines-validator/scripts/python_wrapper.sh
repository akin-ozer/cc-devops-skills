#!/bin/bash
# Python Wrapper Script for Azure Pipelines Validator
# Handles PyYAML and yamllint dependencies with transparent venv management
#
# This script:
# 1. Tries to use system Python if PyYAML is available
# 2. Falls back to a persistent venv if PyYAML is missing
# 3. Auto-installs PyYAML and yamllint in venv if needed
# 4. Runs the target Python script with all arguments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../.venv"

# Check if we have arguments
if [ $# -lt 2 ]; then
    echo "Usage: python_wrapper.sh <python-script> <args...>" >&2
    exit 1
fi

# Hard requirement: python3 must exist
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required to run Azure Pipelines validators." >&2
    echo "Install python3, then rerun validation." >&2
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
    if ! python3 -m venv "$VENV_DIR" >&2; then
        echo "Error: Failed to create virtual environment at $VENV_DIR" >&2
        echo "Install Python venv support (for example python3-venv) and retry." >&2
        exit 1
    fi

    # Activate venv
    source "$VENV_DIR/bin/activate" >&2

    # Upgrade pip quietly
    if ! pip install --quiet --upgrade pip >&2; then
        echo "Error: Failed to upgrade pip in $VENV_DIR" >&2
        exit 1
    fi

    # Install required packages
    echo "Installing required packages (PyYAML, yamllint)..." >&2
    if ! pip install --quiet pyyaml yamllint >&2; then
        echo "Error: Failed to install required packages (PyYAML, yamllint)." >&2
        echo "Check network access or preinstall dependencies, then retry." >&2
        exit 1
    fi

    echo "Virtual environment created at $VENV_DIR" >&2
    echo "" >&2
else
    # Use existing venv
    source "$VENV_DIR/bin/activate" >&2

    # Check if yamllint is installed, install if missing
    if ! python3 -c "import yamllint" 2>/dev/null; then
        echo "Installing yamllint in virtual environment..." >&2
        if ! pip install --quiet yamllint >&2; then
            echo "Error: Failed to install yamllint in $VENV_DIR" >&2
            exit 1
        fi
    fi
fi

# Run the script with venv Python
python3 "$PYTHON_SCRIPT" "$@"
