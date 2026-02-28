#!/usr/bin/env bash
#
# Fluent Bit Config Validator - Convenience Wrapper Script
#
# This script provides a simpler interface to validate_config.py
# Usage: bash validate.sh [--precheck] <config-file> [--check <type>] [--json]
#
# Examples:
#   bash validate.sh --precheck
#   bash validate.sh fluent-bit.conf
#   bash validate.sh fluent-bit.conf --check security
#   bash validate.sh fluent-bit.conf --json
#

set -euo pipefail

# Get the directory where this script is located
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR_REL="${SCRIPT_PATH%/*}"
if [ "${SCRIPT_DIR_REL}" = "${SCRIPT_PATH}" ]; then
    SCRIPT_DIR_REL="."
fi
SCRIPT_DIR="$(cd "${SCRIPT_DIR_REL}" && pwd)"

# Path to the Python validation script
VALIDATOR_SCRIPT="${SCRIPT_DIR}/validate_config.py"

print_help() {
    echo "Fluent Bit Config Validator"
    echo ""
    echo "Usage: $0 [--precheck] <config-file> [options]"
    echo "       $0 --precheck"
    echo ""
    echo "Options:"
    echo "  --precheck            Print binary availability and precheck status"
    echo "  --file <path>         Path to Fluent Bit config file (can be first argument)"
    echo "  --check <type>        Run specific check type:"
    echo "                        structure, syntax, sections, tags, security,"
    echo "                        performance, best-practices, dry-run, all"
    echo "  --json                Output results in JSON format"
    echo "  --fail-on-warning     Exit non-zero when warnings are present"
    echo "  --require-dry-run     Treat missing fluent-bit binary as an error"
    echo "  --help                Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --precheck"
    echo "  $0 fluent-bit.conf"
    echo "  $0 fluent-bit.conf --check security"
    echo "  $0 fluent-bit.conf --check all --json"
    echo "  $0 --precheck --file fluent-bit.conf --check all"
    echo ""
}

run_precheck() {
    local precheck_failed=0

    if command -v python3 >/dev/null 2>&1; then
        echo "python3: available"
    else
        echo "python3: missing"
        echo "Error: python3 is required for script-based validation; use manual review until python3 is installed."
        precheck_failed=1
    fi

    if command -v fluent-bit >/dev/null 2>&1; then
        echo "fluent-bit: available"
    else
        echo "fluent-bit: missing (dry-run will be skipped)"
        echo "Recommendation: Dry-run skipped because fluent-bit binary is not available in PATH; run dry-run in CI or a Fluent Bit runtime image."
    fi

    return "${precheck_failed}"
}

# Show help if no arguments provided
if [ $# -eq 0 ]; then
    print_help
    exit 0
fi

RUN_PRECHECK=false
FORWARD_ARGS=()
for arg in "$@"; do
    case "${arg}" in
        --precheck)
            RUN_PRECHECK=true
            ;;
        --help|-h)
            print_help
            exit 0
            ;;
        *)
            FORWARD_ARGS+=("${arg}")
            ;;
    esac
done

if [ "${RUN_PRECHECK}" = true ]; then
    run_precheck || exit 1
    if [ "${#FORWARD_ARGS[@]}" -eq 0 ]; then
        exit 0
    fi
fi

# Check if Python 3 is available before invoking the validator
if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 is not installed or not in PATH"
    echo "Please install Python 3 to use this validator"
    exit 1
fi

# Check if validator script exists
if [ ! -f "${VALIDATOR_SCRIPT}" ]; then
    echo "Error: validator script not found at ${VALIDATOR_SCRIPT}"
    exit 1
fi

# If first argument doesn't start with --, treat it as the config file
if [[ "${FORWARD_ARGS[0]}" != --* ]]; then
    CONFIG_FILE="${FORWARD_ARGS[0]}"
    if [ "${#FORWARD_ARGS[@]}" -gt 1 ]; then
        python3 "${VALIDATOR_SCRIPT}" --file "${CONFIG_FILE}" "${FORWARD_ARGS[@]:1}"
    else
        python3 "${VALIDATOR_SCRIPT}" --file "${CONFIG_FILE}"
    fi
else
    # Otherwise pass all arguments to the Python script
    python3 "${VALIDATOR_SCRIPT}" "${FORWARD_ARGS[@]}"
fi
