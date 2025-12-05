#!/bin/bash
#
# Azure Pipelines Validator
#
# Comprehensive validation script for Azure Pipelines YAML files
# Runs syntax validation, best practices checks, and security scanning
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Python wrapper for venv management
PYTHON_WRAPPER="$SCRIPT_DIR/python_wrapper.sh"

# Default options
RUN_YAML_LINT=true
RUN_SYNTAX=true
RUN_BEST_PRACTICES=true
RUN_SECURITY=true
STRICT_MODE=false
FILE_PATH=""

# Usage information
usage() {
    cat << EOF
Usage: $(basename "$0") [azure-pipelines.yml] [options]

Validates Azure Pipelines YAML files for syntax, best practices, and security.

Arguments:
  [file]                   Path to Azure Pipelines YAML file (optional)
                           If not specified, auto-detects azure-pipelines*.yml files

Options:
  --syntax-only            Run only syntax validation
  --best-practices         Run only best practices check
  --security-only          Run only security scan
  --no-best-practices      Skip best practices check
  --no-security            Skip security scan
  --skip-yaml-lint         Skip YAML linting (yamllint)
  --strict                 Fail on warnings (not just errors)
  -h, --help               Show this help message

Examples:
  $(basename "$0")                              # Auto-detect pipeline files
  $(basename "$0") azure-pipelines.yml
  $(basename "$0") azure-pipelines.yml --syntax-only
  $(basename "$0") azure-pipelines.yml --no-best-practices
  $(basename "$0") azure-pipelines.yml --strict

Exit Codes:
  0 - All validations passed
  1 - Validation errors found
  2 - Invalid arguments or file not found

EOF
    exit 0
}

# Auto-detect Azure Pipelines files
auto_detect_files() {
    local files=()

    # Search for azure-pipelines*.yml and azure-pipelines*.yaml files
    while IFS= read -r -d '' file; do
        files+=("$file")
    done < <(find . -maxdepth 3 -type f \( -name "azure-pipelines*.yml" -o -name "azure-pipelines*.yaml" \) -print0 2>/dev/null)

    local count=${#files[@]}

    if [ $count -eq 0 ]; then
        echo -e "${YELLOW}No Azure Pipelines files found.${NC}"
        echo ""
        echo "Searched for: azure-pipelines*.yml, azure-pipelines*.yaml"
        echo "Please specify a file path or create an azure-pipelines.yml file."
        exit 2
    elif [ $count -eq 1 ]; then
        FILE_PATH="${files[0]}"
        echo -e "${BLUE}Auto-detected:${NC} $FILE_PATH"
        echo ""
    else
        echo -e "${YELLOW}Multiple Azure Pipelines files found:${NC}"
        echo ""
        for i in "${!files[@]}"; do
            echo "  $((i+1)). ${files[$i]}"
        done
        echo ""
        echo "Please specify which file to validate:"
        echo "  $(basename "$0") <file-path>"
        exit 2
    fi
}

# Parse arguments
parse_args() {
    # Handle case when no arguments are provided - try auto-detection
    if [ $# -eq 0 ]; then
        auto_detect_files
        return
    fi

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                ;;
            --syntax-only)
                RUN_BEST_PRACTICES=false
                RUN_SECURITY=false
                shift
                ;;
            --best-practices)
                RUN_SYNTAX=false
                RUN_SECURITY=false
                shift
                ;;
            --security-only)
                RUN_SYNTAX=false
                RUN_BEST_PRACTICES=false
                shift
                ;;
            --no-best-practices)
                RUN_BEST_PRACTICES=false
                shift
                ;;
            --no-security)
                RUN_SECURITY=false
                shift
                ;;
            --skip-yaml-lint)
                RUN_YAML_LINT=false
                shift
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            -*)
                echo "Error: Unknown option: $1"
                echo "Run '$(basename "$0") --help' for usage information"
                exit 2
                ;;
            *)
                if [ -z "$FILE_PATH" ]; then
                    FILE_PATH="$1"
                else
                    echo "Error: Multiple files specified"
                    exit 2
                fi
                shift
                ;;
        esac
    done

    # If no file specified after parsing options, try auto-detection
    if [ -z "$FILE_PATH" ]; then
        auto_detect_files
    fi

    if [ ! -f "$FILE_PATH" ]; then
        echo "Error: File not found: $FILE_PATH"
        exit 2
    fi
}

# Print header
print_header() {
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "  Azure Pipelines Validator"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "File: $FILE_PATH"
    echo ""
}

# Print summary
print_summary() {
    local yaml_lint_result=$1
    local syntax_result=$2
    local best_practices_result=$3
    local security_result=$4

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "  Validation Summary"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""

    if [ "$RUN_YAML_LINT" = true ]; then
        printf "YAML Lint:              "
        if [ "$yaml_lint_result" = "PASSED" ]; then
            echo -e "${GREEN}PASSED${NC}"
        elif [ "$yaml_lint_result" = "SKIPPED" ]; then
            echo -e "SKIPPED"
        elif [ "$yaml_lint_result" = "WARNINGS" ]; then
            echo -e "${YELLOW}WARNINGS${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    fi

    if [ "$RUN_SYNTAX" = true ]; then
        printf "Syntax Validation:      "
        if [ "$syntax_result" = "PASSED" ]; then
            echo -e "${GREEN}PASSED${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    fi

    if [ "$RUN_BEST_PRACTICES" = true ]; then
        printf "Best Practices:         "
        if [ "$best_practices_result" = "PASSED" ]; then
            echo -e "${GREEN}PASSED${NC}"
        elif [ "$best_practices_result" = "WARNINGS" ]; then
            echo -e "${YELLOW}WARNINGS${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    fi

    if [ "$RUN_SECURITY" = true ]; then
        printf "Security Scan:          "
        if [ "$security_result" = "PASSED" ]; then
            echo -e "${GREEN}PASSED${NC}"
        elif [ "$security_result" = "WARNINGS" ]; then
            echo -e "${YELLOW}WARNINGS${NC}"
        else
            echo -e "${RED}FAILED${NC}"
        fi
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
}

# Main validation
main() {
    parse_args "$@"
    print_header

    local yaml_lint_result="SKIPPED"
    local syntax_result="SKIPPED"
    local best_practices_result="SKIPPED"
    local security_result="SKIPPED"
    local overall_exit=0

    # Step 0: YAML Lint (optional)
    if [ "$RUN_YAML_LINT" = true ]; then
        echo "[0/4] Running YAML lint check..."
        echo ""

        if bash "$SCRIPT_DIR/yamllint_check.sh" "$FILE_PATH"; then
            yaml_lint_result="PASSED"
        else
            yaml_lint_exit=$?
            # yamllint returns 0 if not available (graceful skip)
            if [ $yaml_lint_exit -eq 0 ]; then
                yaml_lint_result="SKIPPED"
            else
                yaml_lint_result="WARNINGS"
                if [ "$STRICT_MODE" = true ]; then
                    overall_exit=1
                fi
            fi
        fi
        echo ""
    fi

    # Step 1: Syntax Validation
    if [ "$RUN_SYNTAX" = true ]; then
        echo "[1/4] Running syntax validation..."
        echo ""

        if bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/validate_syntax.py" "$FILE_PATH"; then
            syntax_result="PASSED"
        else
            syntax_result="FAILED"
            overall_exit=1
        fi
        echo ""
    fi

    # Step 2: Best Practices Check
    if [ "$RUN_BEST_PRACTICES" = true ]; then
        echo "[2/4] Running best practices check..."
        echo ""

        set +e  # Disable exit on error for validation command
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_best_practices.py" "$FILE_PATH"
        best_practices_exit=$?
        set -e  # Re-enable exit on error
        if [ $best_practices_exit -eq 0 ]; then
            best_practices_result="PASSED"
        elif [ $best_practices_exit -eq 2 ]; then
            best_practices_result="WARNINGS"
            if [ "$STRICT_MODE" = true ]; then
                overall_exit=1
            fi
        else
            best_practices_result="FAILED"
            overall_exit=1
        fi
        echo ""
    fi

    # Step 3: Security Scan
    if [ "$RUN_SECURITY" = true ]; then
        echo "[3/4] Running security scan..."
        echo ""

        set +e  # Disable exit on error for validation command
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_security.py" "$FILE_PATH"
        security_exit=$?
        set -e  # Re-enable exit on error
        if [ $security_exit -eq 0 ]; then
            security_result="PASSED"
        elif [ $security_exit -eq 2 ]; then
            security_result="WARNINGS"
            if [ "$STRICT_MODE" = true ]; then
                overall_exit=1
            fi
        else
            security_result="FAILED"
            overall_exit=1
        fi
        echo ""
    fi

    # Print summary
    print_summary "$yaml_lint_result" "$syntax_result" "$best_practices_result" "$security_result"

    # Final result
    if [ $overall_exit -eq 0 ]; then
        echo -e "${GREEN}✓ All validation checks passed${NC}"
        exit 0
    else
        echo -e "${RED}✗ Validation failed${NC}"
        exit 1
    fi
}

main "$@"