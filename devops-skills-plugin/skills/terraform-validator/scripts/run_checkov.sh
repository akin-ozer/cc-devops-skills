#!/bin/bash

# Checkov Terraform Security Scanner Wrapper Script
# This script provides a convenient interface for running Checkov security scans
# on Terraform configurations with common options and helpful error handling.

set -e

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

# Help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <path>

Run Checkov security scanner on Terraform configurations.

ARGUMENTS:
    path                    Path to Terraform file or directory to scan

OPTIONS:
    -f, --format FORMAT     Output format: cli, json, sarif, gitlab_sast (default: cli)
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

    # Scan Terraform plan JSON
    $(basename "$0") -f json ./tfplan.json

EOF
}

# Check if checkov is installed
check_checkov_installed() {
    if ! command -v checkov &> /dev/null; then
        echo -e "${RED}ERROR: checkov is not installed${NC}" >&2
        echo "" >&2
        echo "Install checkov using one of these methods:" >&2
        echo "  pip3 install checkov" >&2
        echo "  brew install checkov  (macOS only)" >&2
        echo "" >&2
        echo "For more information, visit: https://www.checkov.io/" >&2
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--format)
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
                SKIP_CHECKS="$2"
                shift 2
                ;;
            --check)
                RUN_CHECKS="$2"
                shift 2
                ;;
            -*)
                echo -e "${RED}ERROR: Unknown option: $1${NC}" >&2
                echo "Use -h or --help for usage information" >&2
                exit 1
                ;;
            *)
                SCAN_PATH="$1"
                shift
                ;;
        esac
    done

    # Validate required arguments
    if [ -z "$SCAN_PATH" ]; then
        echo -e "${RED}ERROR: Path argument is required${NC}" >&2
        echo "Use -h or --help for usage information" >&2
        exit 1
    fi

    # Validate path exists
    if [ ! -e "$SCAN_PATH" ]; then
        echo -e "${RED}ERROR: Path does not exist: $SCAN_PATH${NC}" >&2
        exit 1
    fi
}

# Build checkov command
build_command() {
    local cmd="checkov"

    # Determine if scanning a file or directory
    if [ -f "$SCAN_PATH" ]; then
        cmd="$cmd -f \"$SCAN_PATH\""
    else
        cmd="$cmd -d \"$SCAN_PATH\""
    fi

    # Add output format
    if [ "$OUTPUT_FORMAT" != "cli" ]; then
        cmd="$cmd -o $OUTPUT_FORMAT"
    fi

    # Add module download flag
    if [ "$DOWNLOAD_MODULES" = "true" ]; then
        cmd="$cmd --download-external-modules true"
    fi

    # Add compact flag
    if [ "$COMPACT_OUTPUT" = "true" ]; then
        cmd="$cmd --compact"
    fi

    # Add quiet flag
    if [ "$QUIET_MODE" = "true" ]; then
        cmd="$cmd --quiet"
    fi

    # Add skip checks
    if [ -n "$SKIP_CHECKS" ]; then
        cmd="$cmd --skip-check $SKIP_CHECKS"
    fi

    # Add run specific checks
    if [ -n "$RUN_CHECKS" ]; then
        cmd="$cmd --check $RUN_CHECKS"
    fi

    echo "$cmd"
}

# Main execution
main() {
    parse_args "$@"
    check_checkov_installed

    # Display scan information
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
    fi

    # Build and execute command
    cmd=$(build_command)

    # Execute checkov
    if [ "$QUIET_MODE" != "true" ]; then
        echo -e "${BLUE}Running: ${NC}$cmd"
        echo ""
    fi

    eval "$cmd"
    exit_code=$?

    # Display summary based on exit code
    if [ "$QUIET_MODE" != "true" ]; then
        echo ""
        echo -e "${BLUE}========================================${NC}"
        if [ $exit_code -eq 0 ]; then
            echo -e "${GREEN}Scan completed: No security issues found${NC}"
        else
            echo -e "${YELLOW}Scan completed: Security issues detected${NC}"
            echo -e "Review the output above for details"
        fi
        echo -e "${BLUE}========================================${NC}"
    fi

    exit $exit_code
}

# Run main function
main "$@"