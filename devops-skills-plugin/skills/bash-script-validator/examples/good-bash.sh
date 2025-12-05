#!/usr/bin/env bash
#
# Example of a well-written bash script following best practices
#

set -euo pipefail

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/tmp/example.log"

# Functions
log_info() {
    echo "[INFO] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $*" >&2 | tee -a "$LOG_FILE"
}

cleanup() {
    log_info "Cleaning up..."
    rm -f "$temp_file"
}

trap cleanup EXIT

process_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Processing file: $file"

    # Good: using modern command substitution
    local line_count
    line_count=$(wc -l < "$file")

    log_info "File has $line_count lines"
    return 0
}

main() {
    log_info "Script started"

    # Create temporary file
    local temp_file
    temp_file=$(mktemp)

    # Good: proper argument handling
    if [[ $# -eq 0 ]]; then
        log_error "Usage: $0 <file1> [file2 ...]"
        exit 1
    fi

    # Good: quoted "$@" preserves arguments
    for file in "$@"; do
        if ! process_file "$file"; then
            log_error "Failed to process: $file"
            exit 1
        fi
    done

    log_info "Script completed successfully"
}

main "$@"