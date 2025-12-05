#!/usr/bin/env bash
#
# ShellCheck Wrapper with Temporary Virtual Environment
#
# This script creates a temporary Python virtual environment, installs shellcheck-py,
# runs shellcheck, and cleans up afterwards.
#
# Usage: ./shellcheck_wrapper.sh [shellcheck-options] <script-file>
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VENV_DIR=""
CLEANUP_ON_EXIT=true
CACHE_VENV=false
VENV_CACHE_DIR="${HOME}/.cache/bash-script-validator/shellcheck-venv"

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_ON_EXIT" == "true" ]] && [[ -n "$VENV_DIR" ]] && [[ -d "$VENV_DIR" ]]; then
        echo -e "${BLUE}[INFO]${NC} Cleaning up temporary virtual environment..." >&2
        rm -rf "$VENV_DIR"
    fi
}

trap cleanup EXIT INT TERM

# Check if Python 3 is available
check_python() {
    if ! command -v python3 &>/dev/null; then
        echo -e "${RED}[ERROR]${NC} python3 not found. Please install Python 3." >&2
        exit 1
    fi
}

# Check if shellcheck is already available system-wide
check_system_shellcheck() {
    if command -v shellcheck &>/dev/null; then
        # ShellCheck is available, use it directly
        shellcheck "$@"
        exit $?
    fi
}

# Create and activate virtual environment
setup_venv() {
    if [[ "$CACHE_VENV" == "true" ]] && [[ -d "$VENV_CACHE_DIR" ]]; then
        echo -e "${GREEN}[INFO]${NC} Using cached virtual environment..." >&2
        VENV_DIR="$VENV_CACHE_DIR"
        CLEANUP_ON_EXIT=false
        return 0
    fi

    echo -e "${BLUE}[INFO]${NC} Creating temporary virtual environment..." >&2

    if [[ "$CACHE_VENV" == "true" ]]; then
        mkdir -p "$(dirname "$VENV_CACHE_DIR")"
        VENV_DIR="$VENV_CACHE_DIR"
        CLEANUP_ON_EXIT=false
    else
        VENV_DIR=$(mktemp -d -t shellcheck-venv.XXXXXX)
    fi

    python3 -m venv "$VENV_DIR"

    # Activate virtual environment
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"
}

# Install shellcheck-py
install_shellcheck() {
    local marker_file="$VENV_DIR/.shellcheck_installed"

    if [[ -f "$marker_file" ]]; then
        echo -e "${GREEN}[INFO]${NC} ShellCheck already installed in cached venv" >&2
        return 0
    fi

    echo -e "${BLUE}[INFO]${NC} Installing shellcheck-py..." >&2

    # Upgrade pip first (suppress output)
    pip3 install --upgrade pip &>/dev/null

    # Install shellcheck-py
    if pip3 install shellcheck-py &>/dev/null; then
        echo -e "${GREEN}[INFO]${NC} ShellCheck installed successfully" >&2
        touch "$marker_file"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} Failed to install shellcheck-py" >&2
        return 1
    fi
}

# Run shellcheck
run_shellcheck() {
    if [[ ! -f "$VENV_DIR/bin/shellcheck" ]]; then
        echo -e "${RED}[ERROR]${NC} ShellCheck binary not found in virtual environment" >&2
        exit 1
    fi

    # Run shellcheck with all provided arguments
    "$VENV_DIR/bin/shellcheck" "$@"
}

# Main function
main() {
    # If no arguments, show usage
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 [--cache] [--no-cache] [shellcheck-options] <script-file>"
        echo ""
        echo "Options:"
        echo "  --cache      Cache the virtual environment for faster subsequent runs"
        echo "  --no-cache   Don't use cached venv (default)"
        echo "  --clear-cache Clear the cached virtual environment"
        echo ""
        echo "Examples:"
        echo "  $0 script.sh"
        echo "  $0 --cache -s bash script.sh"
        echo "  $0 -f gcc script.sh"
        exit 0
    fi

    # Parse wrapper-specific options
    local args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cache)
                CACHE_VENV=true
                shift
                ;;
            --no-cache)
                CACHE_VENV=false
                shift
                ;;
            --clear-cache)
                if [[ -d "$VENV_CACHE_DIR" ]]; then
                    echo -e "${BLUE}[INFO]${NC} Clearing cached virtual environment..."
                    rm -rf "$VENV_CACHE_DIR"
                    echo -e "${GREEN}[INFO]${NC} Cache cleared"
                else
                    echo -e "${YELLOW}[INFO]${NC} No cache to clear"
                fi
                exit 0
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done

    # Check if system shellcheck is available
    check_system_shellcheck "${args[@]}"

    # System shellcheck not found, use venv approach
    check_python
    setup_venv
    install_shellcheck

    # Run shellcheck with remaining arguments
    run_shellcheck "${args[@]}"
}

main "$@"