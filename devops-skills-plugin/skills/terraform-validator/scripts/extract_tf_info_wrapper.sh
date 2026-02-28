#!/bin/bash
# Wrapper script for extract_tf_info.py that handles python-hcl2 dependency.
# Reuses a cached virtual environment for repeat runs to avoid reinstall overhead.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/extract_tf_info.py"

DEFAULT_CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}/terraform-validator"
HCL2_VENV="${TF_VALIDATOR_HCL2_VENV:-$DEFAULT_CACHE_ROOT/hcl2-venv}"

usage() {
    echo "Usage: extract_tf_info_wrapper.sh <terraform-file-or-directory>" >&2
    echo "" >&2
    echo "Extracts provider, module, and resource information from Terraform files." >&2
    echo "Outputs JSON structure for validation and documentation lookup." >&2
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

TARGET_PATH="$1"
if [ ! -e "$TARGET_PATH" ]; then
    echo "Error: Path does not exist: $TARGET_PATH" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is required but not installed." >&2
    exit 1
fi

run_parser() {
    local py_bin="$1"
    "$py_bin" "$PYTHON_SCRIPT" "$TARGET_PATH"
}

# Fast path: system python already has python-hcl2.
if python3 -c "import hcl2" >/dev/null 2>&1; then
    run_parser python3
    exit $?
fi

mkdir -p "$(dirname "$HCL2_VENV")"

# Build or repair cached virtualenv if needed.
if [ ! -x "$HCL2_VENV/bin/python3" ]; then
    echo "python-hcl2 not found. Creating cached environment at: $HCL2_VENV" >&2
    python3 -m venv "$HCL2_VENV" >&2
fi

if ! "$HCL2_VENV/bin/python3" -c "import hcl2" >/dev/null 2>&1; then
    echo "Installing python-hcl2 into cached environment..." >&2
    "$HCL2_VENV/bin/pip" install --quiet --disable-pip-version-check python-hcl2 >&2
fi

run_parser "$HCL2_VENV/bin/python3"
