#!/bin/bash

# Checkov Terraform Security Scanner Wrapper Script
# Provides stable CLI parsing and predictable exit handling.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install_checkov.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FORMAT="cli"
DOWNLOAD_MODULES="false"
COMPACT_OUTPUT="false"
QUIET_MODE="false"
SKIP_CHECKS=""
RUN_CHECKS=""
SCAN_PATH=""

# Includes commonly used checkov formats.
ALLOWED_FORMATS=("cli" "json" "sarif" "gitlab_sast" "csv" "junitxml" "cyclonedx" "cyclonedx_json" "github_failed_only" "spdx")

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <path>

Run Checkov security scanner on Terraform configurations.

ARGUMENTS:
    path                    Path to Terraform file or directory to scan

OPTIONS:
    -f, --format FORMAT     Output format (default: cli)
    -d, --download-modules  Download external Terraform modules before scanning
    -c, --compact           Show compact output (only failed checks)
    -q, --quiet             Suppress informational output
    --skip CHECKS           Comma-separated list of checks to skip (e.g., CKV_AWS_20,CKV_AWS_21)
    --check CHECKS          Comma-separated list of checks to run (only these)
    -h, --help              Show this help message

EXAMPLES:
    # Scan a directory with default settings
    $(basename "$0") ./terraform

    # Scan with JSON output
    $(basename "$0") -f json ./terraform

    # Scan and download external modules
    $(basename "$0") -d ./terraform

    # Scan with specific checks only
    $(basename "$0") --check CKV_AWS_20,CKV_AWS_57 ./terraform

    # Skip specific checks
    $(basename "$0") --skip CKV_AWS_* ./terraform

    # Scan Terraform plan JSON as file input
    $(basename "$0") -f json ./tfplan.json

EOF
}

is_allowed_format() {
    local format="$1"
    local allowed
    for allowed in "${ALLOWED_FORMATS[@]}"; do
        if [ "$allowed" = "$format" ]; then
            return 0
        fi
    done
    return 1
}

require_value() {
    local flag="$1"
    local value="${2:-}"
    if [ -z "$value" ] || [[ "$value" == -* ]]; then
        echo -e "${RED}ERROR: $flag requires a value${NC}" >&2
        echo "Use -h or --help for usage information" >&2
        exit 1
    fi
}

check_checkov_installed() {
    if ! command -v checkov >/dev/null 2>&1; then
        echo -e "${RED}ERROR: checkov is not installed${NC}" >&2
        echo "" >&2
        echo "Install checkov using one of these methods:" >&2
        echo "  pip3 install checkov" >&2
        echo "  brew install checkov  (macOS only)" >&2
        if [ -f "$INSTALL_SCRIPT" ]; then
            echo "  bash $INSTALL_SCRIPT install" >&2
        fi
        echo "" >&2
        echo "For more information, visit: https://www.checkov.io/" >&2
        exit 1
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--format)
                require_value "$1" "${2:-}"
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -d|--download-modules)
                DOWNLOAD_MODULES="true"
                shift
                ;;
            -c|--compact)
                COMPACT_OUTPUT="true"
                shift
                ;;
            -q|--quiet)
                QUIET_MODE="true"
                shift
                ;;
            --skip)
                require_value "$1" "${2:-}"
                SKIP_CHECKS="$2"
                shift 2
                ;;
            --check)
                require_value "$1" "${2:-}"
                RUN_CHECKS="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
                echo "Use -h or --help for usage information" >&2
                exit 1
                ;;
            *)
                if [ -n "$SCAN_PATH" ]; then
                    echo -e "${RED}ERROR: Multiple paths provided: $SCAN_PATH and $1${NC}" >&2
                    exit 1
                fi
                SCAN_PATH="$1"
                shift
                ;;
        esac
    done

    if [ -z "$SCAN_PATH" ]; then
        echo -e "${RED}ERROR: Path argument is required${NC}" >&2
        echo "Use -h or --help for usage information" >&2
        exit 1
    fi

    if [ ! -e "$SCAN_PATH" ]; then
        echo -e "${RED}ERROR: Path does not exist: $SCAN_PATH${NC}" >&2
        exit 1
    fi

    if ! is_allowed_format "$OUTPUT_FORMAT"; then
        echo -e "${RED}ERROR: Invalid output format: $OUTPUT_FORMAT${NC}" >&2
        echo "Allowed formats: ${ALLOWED_FORMATS[*]}" >&2
        exit 1
    fi
}

build_command() {
    local cmd=(checkov)

    if [ -f "$SCAN_PATH" ]; then
        cmd+=(-f "$SCAN_PATH")
    else
        cmd+=(-d "$SCAN_PATH")
    fi

    if [ "$OUTPUT_FORMAT" != "cli" ]; then
        cmd+=(-o "$OUTPUT_FORMAT")
    fi

    if [ "$DOWNLOAD_MODULES" = "true" ]; then
        cmd+=(--download-external-modules true)
    fi

    if [ "$COMPACT_OUTPUT" = "true" ]; then
        cmd+=(--compact)
    fi

    if [ "$QUIET_MODE" = "true" ]; then
        cmd+=(--quiet)
    fi

    if [ -n "$SKIP_CHECKS" ]; then
        cmd+=(--skip-check "$SKIP_CHECKS")
    fi

    if [ -n "$RUN_CHECKS" ]; then
        cmd+=(--check "$RUN_CHECKS")
    fi

    CHECKOV_CMD=("${cmd[@]}")
}

print_command() {
    local rendered=""
    local arg
    for arg in "${CHECKOV_CMD[@]}"; do
        rendered+=$(printf "%q " "$arg")
    done
    echo "$rendered"
}

main() {
    parse_args "$@"
    check_checkov_installed
    build_command

    if [ "$QUIET_MODE" != "true" ]; then
        echo -e "${BLUE}========================================${NC}"
        echo -e "${BLUE}Checkov Security Scanner${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo -e "Target: ${GREEN}$SCAN_PATH${NC}"
        echo -e "Format: ${GREEN}$OUTPUT_FORMAT${NC}"
        [ "$DOWNLOAD_MODULES" = "true" ] && echo -e "Modules: ${GREEN}Download enabled${NC}"
        [ -n "$SKIP_CHECKS" ] && echo -e "Skip: ${YELLOW}$SKIP_CHECKS${NC}"
        [ -n "$RUN_CHECKS" ] && echo -e "Run: ${YELLOW}$RUN_CHECKS${NC}"
        echo -e "${BLUE}========================================${NC}"
        echo ""
        echo -e "${BLUE}Running: ${NC}$(print_command)"
        echo ""
    fi

    set +e
    "${CHECKOV_CMD[@]}"
    exit_code=$?
    set -e

    if [ "$QUIET_MODE" != "true" ]; then
        echo ""
        echo -e "${BLUE}========================================${NC}"
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}Scan completed: No security issues found${NC}"
        else
            echo -e "${YELLOW}Scan completed: Security issues detected or scanner returned non-zero exit${NC}"
            echo -e "Review the output above for details"
        fi
        echo -e "${BLUE}========================================${NC}"
    fi

    exit $exit_code
}

main "$@"
