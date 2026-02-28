#!/usr/bin/env bash
#
# Generate bash script templates
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMPLATES_DIR="${SCRIPT_DIR}/../assets/templates"

list_templates() {
    local found=false

    for template_path in "${TEMPLATES_DIR}"/*-template.sh; do
        if [[ -f "${template_path}" ]]; then
            found=true
            basename "${template_path}" | sed 's/-template.sh$//'
        fi
    done

    if [[ "${found}" == "false" ]]; then
        echo "(none)"
    fi
}

default_output_file() {
    local template_type="$1"
    echo "./${template_type}-script.sh"
}

usage() {
    cat << EOF
Usage: ${0##*/} TEMPLATE_TYPE [OUTPUT_FILE]

Generate a bash script from a template.

Templates include:
    - Proper shebang and strict mode (set -euo pipefail)
    - Logging functions (debug, info, warn, error)
    - Error handling (die, check_command, validate_file)
    - Argument parsing with getopts
    - Cleanup trap handlers
    - Usage documentation

Examples:
    ${0##*/} standard
    ${0##*/} standard myscript.sh
    ${0##*/} standard /usr/local/bin/deploy.sh

Available templates:
$(list_templates)

EOF
}

main() {
    local template_type
    local output_file
    local template_file
    local output_dir

    if [[ $# -eq 0 ]]; then
        echo "Error: TEMPLATE_TYPE is required" >&2
        usage
        exit 1
    fi

    if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        usage
        exit 0
    fi

    if [[ $# -gt 2 ]]; then
        echo "Error: Too many arguments" >&2
        usage
        exit 1
    fi

    template_type="$1"
    output_file="${2:-$(default_output_file "${template_type}")}"
    template_file="${TEMPLATES_DIR}/${template_type}-template.sh"

    if [[ ! -f "${template_file}" ]]; then
        echo "Error: Template not found: ${template_type}" >&2
        echo "Available templates:" >&2
        while IFS= read -r template_name; do
            echo "  ${template_name}" >&2
        done < <(list_templates)
        exit 1
    fi

    output_dir="$(dirname "${output_file}")"
    if [[ "${output_dir}" != "." ]]; then
        mkdir -p "${output_dir}"
    fi

    cp "${template_file}" "${output_file}"
    chmod u+x "${output_file}"

    echo "Created script: ${output_file}"
    echo "Template: ${template_type}"
    echo "Source: ${template_file}"
}

main "$@"
