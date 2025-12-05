#!/bin/sh
#
# Example of a well-written POSIX shell script
#

set -eu

# POSIX-compliant - no bashisms

readonly SCRIPT_NAME="${0##*/}"
readonly LOG_FILE="/tmp/example.log"

log_info() {
    printf '[INFO] %s\n' "$*" | tee -a "$LOG_FILE"
}

log_error() {
    printf '[ERROR] %s\n' "$*" >&2
}

cleanup() {
    log_info "Cleaning up..."
    rm -f "$temp_file"
}

trap cleanup EXIT INT TERM

process_file() {
    file="$1"

    # POSIX: using [ ] not [[ ]]
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi

    log_info "Processing file: $file"

    # POSIX: command substitution with $()
    line_count=$(wc -l < "$file")

    log_info "File has $line_count lines"
    return 0
}

main() {
    log_info "Script started"

    # Create temporary file
    temp_file=$(mktemp)

    # Proper argument handling
    if [ $# -eq 0 ]; then
        log_error "Usage: $SCRIPT_NAME <file1> [file2 ...]"
        exit 1
    fi

    # POSIX: iterate over positional parameters
    for file in "$@"; do
        if ! process_file "$file"; then
            log_error "Failed to process: $file"
            exit 1
        fi
    done

    log_info "Script completed successfully"
}

main "$@"