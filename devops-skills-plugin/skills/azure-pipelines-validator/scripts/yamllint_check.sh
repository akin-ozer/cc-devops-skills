#!/bin/bash
# YAML Lint Check Script for Azure Pipelines
# Runs yamllint with Azure Pipelines-specific configuration
#
# This script handles yamllint with transparent venv management:
# 1. Tries to use system yamllint if available
# 2. Falls back to venv yamllint if exists
# 3. Returns gracefully if yamllint is not available

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/../.venv"
YAMLLINT_CONFIG="$SCRIPT_DIR/../assets/.yamllint"

# Check if file path is provided
if [ $# -lt 1 ]; then
    echo "Usage: yamllint_check.sh <azure-pipelines.yml>" >&2
    exit 1
fi

FILE_PATH="$1"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH" >&2
    exit 1
fi

# Function to run yamllint
run_yamllint() {
    local yamllint_cmd="$1"

    if [ -f "$YAMLLINT_CONFIG" ]; then
        $yamllint_cmd -c "$YAMLLINT_CONFIG" "$FILE_PATH"
    else
        # No config file, use defaults
        $yamllint_cmd "$FILE_PATH"
    fi
}

# Try system yamllint first
if command -v yamllint &> /dev/null; then
    run_yamllint "yamllint"
    exit $?
fi

# Try venv yamllint
if [ -d "$VENV_DIR" ] && [ -f "$VENV_DIR/bin/activate" ]; then
    # Activate venv
    source "$VENV_DIR/bin/activate" 2>/dev/null

    # Check if yamllint is available in venv
    if command -v yamllint &> /dev/null; then
        run_yamllint "yamllint"
        exit $?
    fi
fi

# yamllint not available - skip gracefully
echo "ℹ  yamllint not available (skipping YAML linting)" >&2
echo "   To enable: pip install yamllint" >&2
exit 0