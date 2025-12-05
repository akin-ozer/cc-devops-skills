#!/bin/bash
# Wrapper script for extract_tf_info.py that handles python-hcl2 dependency
# Creates a temporary venv if python-hcl2 is not available, auto-cleans on exit

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/extract_tf_info.py"

# Check if we have arguments
if [ $# -lt 1 ]; then
    echo "Usage: extract_tf_info_wrapper.sh <terraform-file-or-directory>" >&2
    echo "" >&2
    echo "Extracts provider, module, and resource information from Terraform files." >&2
    echo "Outputs JSON structure for validation and documentation lookup." >&2
    exit 1
fi

TARGET_PATH="$1"

# Validate target exists
if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: Path does not exist: $TARGET_PATH" >&2
    exit 1
fi

# Try to run with system Python first
if python3 -c "import hcl2" 2>/dev/null; then
    # python-hcl2 is available, run directly
    python3 "$PYTHON_SCRIPT" "$TARGET_PATH"
    exit $?
fi

# python-hcl2 not available, create temporary venv
TEMP_VENV=$(mktemp -d -t terraform-validator.XXXXXX)
trap "rm -rf $TEMP_VENV" EXIT

echo "python-hcl2 not found in system Python. Creating temporary environment..." >&2

# Create venv and install python-hcl2
python3 -m venv "$TEMP_VENV" >&2
source "$TEMP_VENV/bin/activate" >&2
pip install --quiet python-hcl2 >&2

# Run the script
python3 "$PYTHON_SCRIPT" "$TARGET_PATH"

# Cleanup happens automatically via trap