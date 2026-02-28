#!/bin/bash

# Jenkinsfile Validator - Main Orchestrator Script
# Runs all validators in sequence with unified output
#
# Usage: validate_jenkinsfile.sh [OPTIONS] <jenkinsfile>
#
# Options:
#   --syntax-only       Run only syntax validation
#   --security-only     Run only security checks
#   --best-practices    Run only best practices check
#   --no-security       Skip security checks
#   --no-best-practices Skip best practices check
#   --strict            Fail on warnings
#   -h, --help          Show this help message
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed
#   2 - Usage error

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Symbols
PASS_SYMBOL="✓"
FAIL_SYMBOL="✗"
WARN_SYMBOL="⚠"
SKIP_SYMBOL="○"

# Default options
RUN_SYNTAX=true
RUN_SECURITY=true
RUN_BEST_PRACTICES=true
STRICT_MODE=false

# Counters
TOTAL_ERRORS=0
TOTAL_WARNINGS=0
TOTAL_INFO=0

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] <jenkinsfile>

Validates Jenkins pipeline files (Declarative and Scripted).

Options:
  --syntax-only       Run only syntax validation
  --security-only     Run only security checks
  --best-practices    Run only best practices check
  --no-security       Skip security checks
  --no-best-practices Skip best practices check
  --strict            Fail on warnings (treat warnings as errors)
  -h, --help          Show this help message

Examples:
  $(basename "$0") Jenkinsfile                    # Full validation
  $(basename "$0") --syntax-only Jenkinsfile      # Syntax only
  $(basename "$0") --strict Jenkinsfile           # Fail on warnings
  $(basename "$0") --no-security Jenkinsfile      # Skip security scan

Exit codes:
  0 - Validation passed
  1 - Validation failed (errors found, or warnings in strict mode)
  2 - Usage error
EOF
    exit 2
}

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  Jenkinsfile Validator v1.2.1${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    local title=$1
    echo ""
    echo -e "${BLUE}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ ${BOLD}$title${NC}"
    echo -e "${BLUE}└──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

check_prerequisites() {
    local required_tools=("bash" "grep" "sed" "awk" "head" "wc")
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tool(s): ${missing_tools[*]}${NC}"
        echo "Install missing tools and rerun validation."
        exit 2
    fi

    # Optional dependency used in recommendations and troubleshooting flows.
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${YELLOW}Warning: jq not found (optional).${NC}"
        echo "  jq is recommended for JSON-heavy pipeline debugging."
    fi
}

run_validator_script() {
    local script_path=$1
    shift

    if [ ! -r "$script_path" ]; then
        echo -e "${RED}ERROR [Runner]: Required script is missing or not readable: $(basename "$script_path")${NC}"
        return 127
    fi

    if [ ! -x "$script_path" ]; then
        echo -e "${YELLOW}WARNING [Runner]: $(basename "$script_path") is not executable. Using 'bash' fallback.${NC}"
    fi

    local output=""
    local status=0
    set +e
    output=$(bash "$script_path" "$@" 2>&1)
    status=$?
    set -e

    if [ -n "$output" ]; then
        echo "$output"
    fi

    if [ "$status" -gt 1 ]; then
        echo -e "${RED}ERROR [Runner]: $(basename "$script_path") exited with unexpected code ${status}${NC}"
    fi

    return "$status"
}

count_error_warning_lines() {
    local output=$1
    local clean_output
    clean_output=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g')
    local errors
    local warnings
    errors=$(printf '%s\n' "$clean_output" | grep -E -c '^ERROR \[' || true)
    warnings=$(printf '%s\n' "$clean_output" | grep -E -c '^WARNING \[' || true)
    echo "${errors}:${warnings}"
}

count_info_lines() {
    local output=$1
    local clean_output
    clean_output=$(printf '%s\n' "$output" | sed 's/\x1b\[[0-9;]*m//g')
    printf '%s\n' "$clean_output" | grep -E -c '^INFO \[' || true
}

# Detect pipeline type (Declarative or Scripted)
detect_pipeline_type() {
    local file=$1

    # Remove comments and check for pipeline block
    local first_meaningful
    first_meaningful=$(grep -v '^\s*//' "$file" | grep -v '^\s*$' | grep -v '^\s*\*' | grep -v '^\s*/\*' | head -20)

    if echo "$first_meaningful" | grep -q '^\s*pipeline\s*{'; then
        echo "declarative"
    elif echo "$first_meaningful" | grep -q '^\s*node\s*[({]'; then
        echo "scripted"
    elif grep -q 'pipeline\s*{' "$file"; then
        echo "declarative"
    elif grep -q 'node\s*[({]' "$file"; then
        echo "scripted"
    else
        echo "unknown"
    fi
}

# Run syntax validation based on pipeline type
run_syntax_validation() {
    local file=$1
    local type=$2
    local errors=0
    local warnings=0

    print_section "1. Syntax Validation"

    if [ "$type" == "declarative" ]; then
        echo -e "Pipeline type: ${GREEN}Declarative${NC}"
        echo ""

        local output=""
        local script_status=0
        set +e
        output=$(run_validator_script "$SCRIPT_DIR/validate_declarative.sh" "$file")
        script_status=$?
        set -e
        echo "$output"

        local counts
        counts=$(count_error_warning_lines "$output")
        errors=${counts%%:*}
        warnings=${counts##*:}
        if [ "$script_status" -gt 1 ]; then
            errors=$((errors + 1))
        fi
    elif [ "$type" == "scripted" ]; then
        echo -e "Pipeline type: ${GREEN}Scripted${NC}"
        echo ""

        local output=""
        local script_status=0
        set +e
        output=$(run_validator_script "$SCRIPT_DIR/validate_scripted.sh" "$file")
        script_status=$?
        set -e
        echo "$output"

        local counts
        counts=$(count_error_warning_lines "$output")
        errors=${counts%%:*}
        warnings=${counts##*:}
        if [ "$script_status" -gt 1 ]; then
            errors=$((errors + 1))
        fi
    else
        echo -e "${YELLOW}Warning: Could not determine pipeline type${NC}"
        echo "Attempting both validators..."
        echo ""

        local ran_any=false
        local declarative_errors=999999
        local declarative_warnings=999999
        local scripted_errors=999999
        local scripted_warnings=999999

        echo -e "${BLUE}Trying Declarative validation:${NC}"
        local declarative_output=""
        local declarative_status=0
        set +e
        declarative_output=$(run_validator_script "$SCRIPT_DIR/validate_declarative.sh" "$file")
        declarative_status=$?
        set -e
        echo "$declarative_output"
        if [ "$declarative_status" -ne 127 ]; then
            ran_any=true
            local decl_counts
            decl_counts=$(count_error_warning_lines "$declarative_output")
            declarative_errors=${decl_counts%%:*}
            declarative_warnings=${decl_counts##*:}
            if [ "$declarative_status" -gt 1 ]; then
                declarative_errors=$((declarative_errors + 1))
            fi
        fi

        echo ""
        echo -e "${BLUE}Trying Scripted validation:${NC}"
        local scripted_output=""
        local scripted_status=0
        set +e
        scripted_output=$(run_validator_script "$SCRIPT_DIR/validate_scripted.sh" "$file")
        scripted_status=$?
        set -e
        echo "$scripted_output"
        if [ "$scripted_status" -ne 127 ]; then
            ran_any=true
            local scr_counts
            scr_counts=$(count_error_warning_lines "$scripted_output")
            scripted_errors=${scr_counts%%:*}
            scripted_warnings=${scr_counts##*:}
            if [ "$scripted_status" -gt 1 ]; then
                scripted_errors=$((scripted_errors + 1))
            fi
        fi

        if [ "$ran_any" == false ]; then
            echo -e "${RED}ERROR [Runner]: No syntax validators are available.${NC}"
            errors=1
            warnings=0
        elif [ "$scripted_errors" -lt "$declarative_errors" ] || { [ "$scripted_errors" -eq "$declarative_errors" ] && [ "$scripted_warnings" -lt "$declarative_warnings" ]; }; then
            errors=$scripted_errors
            warnings=$scripted_warnings
            echo ""
            echo -e "${BLUE}Using scripted result as best match for unknown pipeline type.${NC}"
        else
            errors=$declarative_errors
            warnings=$declarative_warnings
            echo ""
            echo -e "${BLUE}Using declarative result as best match for unknown pipeline type.${NC}"
        fi
    fi

    TOTAL_ERRORS=$((TOTAL_ERRORS + errors))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + warnings))

    if [ "$errors" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}${PASS_SYMBOL} Syntax validation passed${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}${FAIL_SYMBOL} Syntax validation failed with $errors error(s)${NC}"
        return 1
    fi
}

# Run security scan
run_security_scan() {
    local file=$1
    local errors=0
    local warnings=0
    local info=0

    print_section "2. Security Scan"

    if [ -r "$SCRIPT_DIR/common_validation.sh" ]; then
        # Run credential check via script (not sourced, to get proper output)
        echo -e "${BLUE}Scanning for hardcoded credentials...${NC}"
        echo ""

        local output
        local script_status=0
        set +e
        output=$(run_validator_script "$SCRIPT_DIR/common_validation.sh" check_credentials "$file")
        script_status=$?
        set -e
        echo "$output"

        local counts
        counts=$(count_error_warning_lines "$output")
        errors=${counts%%:*}
        warnings=${counts##*:}
        info=$(count_info_lines "$output")
        if [ "$script_status" -gt 1 ]; then
            errors=$((errors + 1))
        fi
    else
        echo -e "${YELLOW}Warning: common_validation.sh not found or not readable, skipping security scan${NC}"
    fi

    TOTAL_ERRORS=$((TOTAL_ERRORS + errors))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + warnings))
    TOTAL_INFO=$((TOTAL_INFO + info))

    if [ "$errors" -eq 0 ] && [ "$warnings" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}${PASS_SYMBOL} Security scan passed - no credentials detected${NC}"
        return 0
    elif [ "$errors" -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}${WARN_SYMBOL} Security scan completed with $warnings warning(s)${NC}"
        return 0
    else
        echo ""
        echo -e "${RED}${FAIL_SYMBOL} Security scan failed with $errors error(s)${NC}"
        return 1
    fi
}

# Run best practices check
run_best_practices() {
    local file=$1
    local errors=0
    local warnings=0

    print_section "3. Best Practices Check"

    if [ -r "$SCRIPT_DIR/best_practices.sh" ]; then
        local output
        local script_status=0
        set +e
        output=$(run_validator_script "$SCRIPT_DIR/best_practices.sh" "$file")
        script_status=$?
        set -e
        echo "$output"

        local counts
        counts=$(count_error_warning_lines "$output")
        errors=${counts%%:*}
        warnings=${counts##*:}
        if [ "$script_status" -gt 1 ]; then
            errors=$((errors + 1))
        fi
    else
        echo -e "${YELLOW}Warning: best_practices.sh not found or not readable, skipping best practices check${NC}"
    fi

    # Don't add to totals - best practices has its own scoring

    if [ "$errors" -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

# Print final summary
print_summary() {
    local file=$1
    local syntax_result=$2
    local security_result=$3
    local practices_result=$4

    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  Validation Summary${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "File: ${BOLD}$file${NC}"
    echo ""

    # Syntax result
    if [ "$RUN_SYNTAX" == true ]; then
        if [ "$syntax_result" == "0" ]; then
            echo -e "  ${GREEN}${PASS_SYMBOL}${NC} Syntax Validation    : ${GREEN}PASSED${NC}"
        else
            echo -e "  ${RED}${FAIL_SYMBOL}${NC} Syntax Validation    : ${RED}FAILED${NC}"
        fi
    else
        echo -e "  ${BLUE}${SKIP_SYMBOL}${NC} Syntax Validation    : ${BLUE}SKIPPED${NC}"
    fi

    # Security result
    if [ "$RUN_SECURITY" == true ]; then
        if [ "$security_result" == "0" ]; then
            echo -e "  ${GREEN}${PASS_SYMBOL}${NC} Security Scan        : ${GREEN}PASSED${NC}"
        else
            echo -e "  ${RED}${FAIL_SYMBOL}${NC} Security Scan        : ${RED}FAILED${NC}"
        fi
    else
        echo -e "  ${BLUE}${SKIP_SYMBOL}${NC} Security Scan        : ${BLUE}SKIPPED${NC}"
    fi

    # Best practices result
    if [ "$RUN_BEST_PRACTICES" == true ]; then
        if [ "$practices_result" == "0" ]; then
            echo -e "  ${GREEN}${PASS_SYMBOL}${NC} Best Practices       : ${GREEN}PASSED${NC}"
        else
            echo -e "  ${YELLOW}${WARN_SYMBOL}${NC} Best Practices       : ${YELLOW}REVIEW NEEDED${NC}"
        fi
    else
        echo -e "  ${BLUE}${SKIP_SYMBOL}${NC} Best Practices       : ${BLUE}SKIPPED${NC}"
    fi

    echo ""
    echo -e "${BLUE}────────────────────────────────────────────────────────────────${NC}"

    # Overall result
    local overall_pass=true

    if [ "$RUN_SYNTAX" == true ] && [ "$syntax_result" != "0" ]; then
        overall_pass=false
    fi

    if [ "$RUN_SECURITY" == true ] && [ "$security_result" != "0" ]; then
        overall_pass=false
    fi

    # In strict mode, warnings also cause failure
    if [ "$STRICT_MODE" == true ] && [ "$TOTAL_WARNINGS" -gt 0 ]; then
        overall_pass=false
    fi

    echo ""
    if [ "$overall_pass" == true ]; then
        echo -e "  ${GREEN}${BOLD}${PASS_SYMBOL} VALIDATION PASSED${NC}"
        if [ "$TOTAL_WARNINGS" -gt 0 ]; then
            echo -e "    (with $TOTAL_WARNINGS warning(s) - review recommended)"
        fi
        echo ""
        return 0
    else
        echo -e "  ${RED}${BOLD}${FAIL_SYMBOL} VALIDATION FAILED${NC}"
        if [ "$STRICT_MODE" == true ] && [ "$TOTAL_WARNINGS" -gt 0 ]; then
            echo -e "    (strict mode: $TOTAL_WARNINGS warning(s) treated as errors)"
        fi
        echo ""
        return 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --syntax-only)
                RUN_SECURITY=false
                RUN_BEST_PRACTICES=false
                shift
                ;;
            --security-only)
                RUN_SYNTAX=false
                RUN_BEST_PRACTICES=false
                shift
                ;;
            --best-practices)
                RUN_SYNTAX=false
                RUN_SECURITY=false
                shift
                ;;
            --no-security)
                RUN_SECURITY=false
                shift
                ;;
            --no-best-practices)
                RUN_BEST_PRACTICES=false
                shift
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            -*)
                echo -e "${RED}Error: Unknown option: $1${NC}"
                usage
                ;;
            *)
                JENKINSFILE="$1"
                shift
                ;;
        esac
    done
}

# Main execution
main() {
    parse_args "$@"
    check_prerequisites

    # Validate input
    if [ -z "${JENKINSFILE:-}" ]; then
        echo -e "${RED}Error: No Jenkinsfile specified${NC}"
        usage
    fi

    if [ ! -f "$JENKINSFILE" ]; then
        echo -e "${RED}Error: File '$JENKINSFILE' not found${NC}"
        exit 2
    fi

    print_header
    echo -e "Validating: ${BOLD}$JENKINSFILE${NC}"

    # Detect pipeline type
    local pipeline_type
    pipeline_type=$(detect_pipeline_type "$JENKINSFILE")

    # Track results
    local syntax_result=0
    local security_result=0
    local practices_result=0

    # Run validations based on options
    if [ "$RUN_SYNTAX" == true ]; then
        run_syntax_validation "$JENKINSFILE" "$pipeline_type" || syntax_result=$?
    fi

    if [ "$RUN_SECURITY" == true ]; then
        run_security_scan "$JENKINSFILE" || security_result=$?
    fi

    if [ "$RUN_BEST_PRACTICES" == true ]; then
        run_best_practices "$JENKINSFILE" || practices_result=$?
    fi

    # Print summary and exit with appropriate code
    print_summary "$JENKINSFILE" "$syntax_result" "$security_result" "$practices_result"
}

main "$@"
