#!/usr/bin/env bash
#
# Generate bash script templates
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="${SCRIPT_DIR}/../assets/templates"

usage() {
    cat << EOF
Usage: ${0##*/} standard OUTPUT_FILE

Generate bash script from the standard template

The standard template includes:
    - Proper shebang and strict mode (set -euo pipefail)
    - Logging functions (debug, info, warn, error)
    - Error handling (die, check_command, validate_file)
    - Argument parsing with getopts
    - Cleanup trap handlers
    - Usage documentation

Examples:
    ${0##*/} standard myscript.sh
    ${0##*/} standard /usr/local/bin/deploy.sh

EOF
}

main() {
    local template_type="${1:-standard}"
    local output_file="${2:-}"

    if [[ "${template_type}" == "-h" || "${template_type}" == "--help" ]]; then
        usage
        exit 0
    fi

    [[ -n "${output_file}" ]] || { echo "Error: OUTPUT_FILE required" >&2; usage; exit 1; }

    local template_file="${TEMPLATES_DIR}/${template_type}-template.sh"

    if [[ ! -f "${template_file}" ]]; then
        echo "Error: Template not found: ${template_type}" >&2
        echo "Available templates:" >&2
        ls -1 "${TEMPLATES_DIR}"/*.sh 2>/dev/null | sed 's/.*\//  /' | sed 's/-template.sh//' || true
        exit 1
    fi

    cp "${template_file}" "${output_file}"
    chmod +x "${output_file}"

    echo "Created script: ${output_file}"
    echo "Template: ${template_type}"
}

main "$@"