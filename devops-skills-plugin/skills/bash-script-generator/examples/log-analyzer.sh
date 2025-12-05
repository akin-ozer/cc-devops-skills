#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] LOG_FILE

Analyze log files and generate summary reports

Options:
    -h          Show this help
    -t TYPE     Report type: errors|summary|timeline (default: summary)
    -o FILE     Output file (default: stdout)

Examples:
    ${0##*/} application.log
    ${0##*/} -t errors -o errors.txt application.log
EOF
}

analyze_errors() {
    local log_file="$1"

    echo "Error Summary:"
    echo "=============="

    grep "ERROR" "${log_file}" \
        | sed 's/.*ERROR: //' \
        | sed 's/ -.*//' \
        | sort \
        | uniq -c \
        | sort -rn \
        | awk '{printf "  %-40s %6d\n", $2, $1}'

    echo ""
    echo "Total errors: $(grep -c "ERROR" "${log_file}" 2>/dev/null || echo "0")"
}

generate_summary() {
    local log_file="$1"

    echo "Log File Analysis Summary"
    echo "========================="
    echo ""
    echo "File: ${log_file}"
    echo "Total lines: $(wc -l < "${log_file}")"
    echo ""

    echo "Log Levels:"
    for level in DEBUG INFO WARN ERROR FATAL; do
        local count=$(grep -c "${level}" "${log_file}" 2>/dev/null || echo "0")
        printf "  %-10s %6d\n" "${level}:" "${count}"
    done
}

main() {
    local report_type="summary"
    local output_file=""
    local log_file=""

    while getopts ":ht:o:" opt; do
        case ${opt} in
            h) usage; exit 0 ;;
            t) report_type="${OPTARG}" ;;
            o) output_file="${OPTARG}" ;;
            :) echo "Option -${OPTARG} requires an argument" >&2; exit 1 ;;
            \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    log_file="${1:-}"
    [[ -n "${log_file}" ]] || { echo "Error: LOG_FILE required" >&2; usage; exit 1; }
    [[ -f "${log_file}" ]] || { echo "Error: File not found: ${log_file}" >&2; exit 1; }

    local output
    case "${report_type}" in
        errors)   output=$(analyze_errors "${log_file}") ;;
        summary)  output=$(generate_summary "${log_file}") ;;
        *) echo "Invalid report type: ${report_type}" >&2; exit 1 ;;
    esac

    if [[ -n "${output_file}" ]]; then
        echo "${output}" > "${output_file}"
        echo "Report saved to: ${output_file}"
    else
        echo "${output}"
    fi
}

main "$@"