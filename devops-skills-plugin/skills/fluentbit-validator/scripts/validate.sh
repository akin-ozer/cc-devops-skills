#!/usr/bin/env bash
#
# Fluent Bit Config Validator - Convenience Wrapper Script
#
# This script provides a simpler interface to validate_config.py
# Usage: bash validate.sh <config-file> [--check <type>] [--json]
#
# Examples:
#   bash validate.sh fluent-bit.conf
#   bash validate.sh fluent-bit.conf --check security
#   bash validate.sh fluent-bit.conf --json
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to the Python validation script
VALIDATOR_SCRIPT="${SCRIPT_DIR}/validate_config.py"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is not installed or not in PATH"
    echo "Please install Python 3 to use this validator"
    exit 1
fi

# Check if validator script exists
if [ ! -f "${VALIDATOR_SCRIPT}" ]; then
    echo "Error: validator script not found at ${VALIDATOR_SCRIPT}"
    exit 1
fi

# Show help if no arguments provided
if [ $# -eq 0 ]; then
    echo "Fluent Bit Config Validator"
    echo ""
    echo "Usage: $0 <config-file> [options]"
    echo ""
    echo "Options:"
    echo "  --file <path>         Path to Fluent Bit config file (can be first argument)"
    echo "  --check <type>        Run specific check type:"
    echo "                        structure, syntax, sections, tags, security,"
    echo "                        performance, best-practices, dry-run, all"
    echo "  --json                Output results in JSON format"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 fluent-bit.conf"
    echo "  $0 fluent-bit.conf --check security"
    echo "  $0 fluent-bit.conf --check all --json"
    echo "  $0 --file fluent-bit.conf --check performance"
    echo ""
    exit 0
fi

# If first argument doesn't start with --, treat it as the config file
if [[ "$1" != --* ]]; then
    CONFIG_FILE="$1"
    shift
    python3 "${VALIDATOR_SCRIPT}" --file "${CONFIG_FILE}" "$@"
else
    # Otherwise pass all arguments to the Python script
    python3 "${VALIDATOR_SCRIPT}" "$@"
fi