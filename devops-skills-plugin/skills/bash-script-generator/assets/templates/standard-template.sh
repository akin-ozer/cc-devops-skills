#!/usr/bin/env bash
#
# Script Name: SCRIPT_NAME
# Description: Brief description of what this script does
# Usage: SCRIPT_NAME [OPTIONS] ARGUMENTS
#

set -euo pipefail
IFS=$'\n\t'

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly VERSION="1.0.0"

VERBOSE=false
DRY_RUN=false
LOG_LEVEL=1  # 0=DEBUG 1=INFO 2=WARN 3=ERROR

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [ARGUMENTS]

Description:
    Brief description of what the script does

Options:
    -h, --help      Show this help message and exit
    -v, --verbose   Enable verbose output
    -d, --debug     Enable debug mode
    -n, --dry-run   Perform dry run without making changes

Examples:
    ${SCRIPT_NAME} -v file.txt
    ${SCRIPT_NAME} --dry-run input.txt output.txt

EOF
}

log() {
    local level="$1"
    shift
    echo "[${level}] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_debug() { if [[ ${LOG_LEVEL} -le 0 ]]; then log "DEBUG" "$@"; fi; }
log_info()  { if [[ ${LOG_LEVEL} -le 1 ]]; then log "INFO"  "$@"; fi; }
log_warn()  { if [[ ${LOG_LEVEL} -le 2 ]]; then log "WARN"  "$@"; fi; }
log_error() { log "ERROR" "$@"; }

die() {
    log_error "$@"
    exit 1
}

check_command() {
    command -v "$1" &> /dev/null || die "Required command not found: $1"
}

validate_file() {
    [[ -f "$1" ]] || die "File not found: $1"
    [[ -r "$1" ]] || die "File not readable: $1"
}

cleanup() {
    local exit_code=$?
    log_debug "Cleaning up..."
    exit "${exit_code}"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage; exit 0 ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -d|--debug) LOG_LEVEL=0; VERBOSE=true; shift ;;
            -n|--dry-run) DRY_RUN=true; shift ;;
            -*) die "Unknown option: $1" ;;
            *) break ;;
        esac
    done
    ARGS=("$@")
}

main() {
    parse_args "$@"

    log_info "Starting ${SCRIPT_NAME}..."

    # Main logic goes here

    log_info "Completed successfully"
}

trap cleanup EXIT ERR INT TERM

main "$@"
