#!/bin/bash

# Shared Library Validator
# Validates Jenkins Shared Library files (vars/*.groovy, src/**/*.groovy)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Validation result arrays
declare -a ERROR_MESSAGES=()
declare -a WARNING_MESSAGES=()
declare -a INFO_MESSAGES=()

usage() {
    echo -e "${BOLD}Usage:${NC} $0 <file_or_directory>"
    echo ""
    echo "Validates Jenkins Shared Library Groovy files."
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  $0 vars/myStep.groovy      # Validate single global variable file"
    echo "  $0 vars/                   # Validate all vars/*.groovy files"
    echo "  $0 src/                    # Validate src/**/*.groovy files"
    echo "  $0 .                       # Validate entire shared library"
    echo ""
    echo -e "${BOLD}File Types:${NC}"
    echo "  vars/*.groovy    - Global variable definitions (callable steps)"
    echo "  src/**/*.groovy  - Groovy source classes"
    echo ""
    exit 1
}

log_error() {
    local line=$1
    local message=$2
    ERROR_MESSAGES+=("ERROR [Line $line]: $message")
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    local line=$1
    local message=$2
    WARNING_MESSAGES+=("WARNING [Line $line]: $message")
    WARNINGS=$((WARNINGS + 1))
}

log_info() {
    local line=$1
    local message=$2
    INFO_MESSAGES+=("INFO [Line $line]: $message")
    INFO=$((INFO + 1))
}

# Detect file type within shared library
detect_library_file_type() {
    local file=$1
    local filepath=$(realpath "$file" 2>/dev/null || echo "$file")

    if [[ "$filepath" == */vars/*.groovy ]]; then
        echo "vars"
    elif [[ "$filepath" == */src/*.groovy ]] || [[ "$filepath" == */src/**/*.groovy ]]; then
        echo "src"
    elif [[ "$file" == *.groovy ]]; then
        # Check content to determine type
        if grep -qE '^\s*def\s+call\s*\(' "$file" 2>/dev/null; then
            echo "vars"
        elif grep -qE '^\s*(class|interface|enum|trait)\s+' "$file" 2>/dev/null; then
            echo "src"
        else
            echo "unknown"
        fi
    else
        echo "unknown"
    fi
}

# Validate vars/*.groovy global variable files
validate_vars_file() {
    local file=$1
    local filename=$(basename "$file" .groovy)
    local line_num=0
    local has_call_method=false
    local has_doc_comment=false
    local in_call_method=false
    local brace_count=0

    echo -e "${BLUE}=== Validating Global Variable: ${BOLD}$filename${NC}${BLUE} ===${NC}"
    echo "File: $file"
    echo ""

    # Check for call() method
    if grep -qE '^\s*def\s+call\s*\(' "$file"; then
        has_call_method=true
    fi

    # Check for documentation comment
    if grep -qE '^\s*/\*\*' "$file"; then
        has_doc_comment=true
    fi

    # Line by line validation
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Skip empty lines and comments for some checks
        if [[ -z "${line// }" ]] || [[ "$line" =~ ^[[:space:]]*//.* ]] || [[ "$line" =~ ^[[:space:]]*\*.* ]]; then
            continue
        fi

        # Check for hardcoded credentials
        if echo "$line" | grep -qiE '(password|secret|token|api[_-]?key)\s*=\s*["\047][a-zA-Z0-9]'; then
            log_error "$line_num" "Potential hardcoded credential detected"
            log_error "$line_num" "  → Use credentials() or parameters instead"
        fi

        # Check for @NonCPS annotation usage
        if echo "$line" | grep -q '@NonCPS'; then
            # Check next non-empty line for pipeline steps
            local next_lines=$(tail -n +$((line_num + 1)) "$file" | head -20)
            if echo "$next_lines" | grep -qE '^\s*(sh|bat|echo|checkout|archiveArtifacts|junit|input|build)\s'; then
                log_error "$line_num" "@NonCPS method contains pipeline steps (sh, echo, etc.)"
                log_error "$line_num" "  → Pipeline steps cannot be used in @NonCPS methods"
                log_error "$line_num" "  → Move pipeline steps outside the @NonCPS method"
            fi
        fi

        # Check for proper error handling in pipeline steps
        if echo "$line" | grep -qE '^\s*sh\s+["\047]'; then
            # Check if inside try block
            local context=$(head -n $line_num "$file" | tail -20)
            if ! echo "$context" | grep -q 'try\s*{'; then
                log_info "$line_num" "Consider wrapping sh step in try-catch for error handling"
            fi
        fi

        # Check for return type documentation
        if echo "$line" | grep -qE '^\s*def\s+call\s*\(' && ! echo "$line" | grep -qE '^\s*(String|boolean|int|def|void|Map|List)'; then
            log_info "$line_num" "Consider specifying return type for call() method"
        fi

        # Check for deprecated methods
        if echo "$line" | grep -qE 'new\s+File\s*\('; then
            log_warning "$line_num" "Using 'new File()' - prefer readFile/writeFile for pipeline compatibility"
            log_warning "$line_num" "  → Use readFile('path') instead of new File('path').text"
        fi

        # Check for URL/HTTP on controller
        if echo "$line" | grep -qE 'new\s+URL\s*\(' || echo "$line" | grep -q 'HttpURLConnection'; then
            log_warning "$line_num" "HTTP operations run on controller - use httpRequest step or curl on agent"
            log_warning "$line_num" "  → Use: sh 'curl ...' or httpRequest plugin"
        fi

        # Check for JsonSlurper on controller
        if echo "$line" | grep -q 'JsonSlurper'; then
            log_warning "$line_num" "JsonSlurper runs on controller - consider using jq on agent for large files"
            log_warning "$line_num" "  → For small JSON: JsonSlurperClassic is safer"
            log_warning "$line_num" "  → For large JSON: sh 'jq ... file.json'"
        fi

        # Check for proper CPS handling with closures
        if echo "$line" | grep -qE '\.(each|collect|find|findAll|any|every)\s*\{'; then
            # Check if marked @NonCPS
            local prev_lines=$(head -n $line_num "$file" | tail -10)
            if ! echo "$prev_lines" | grep -q '@NonCPS'; then
                log_info "$line_num" "Groovy closure detected - ensure method is @NonCPS if not using pipeline steps"
                log_info "$line_num" "  → Closures like .each{}, .collect{} require @NonCPS annotation"
            fi
        fi

        # Check for environment variable access
        if echo "$line" | grep -qE 'System\.getenv\s*\('; then
            log_warning "$line_num" "Using System.getenv() - prefer env.VAR_NAME for pipeline compatibility"
        fi

        # Check for sleep usage
        if echo "$line" | grep -qE 'Thread\.sleep\s*\('; then
            log_warning "$line_num" "Using Thread.sleep() - prefer sleep() step for pipeline compatibility"
        fi

    done < "$file"

    # Post-file checks
    if [ "$has_call_method" = false ]; then
        log_warning "1" "No call() method found - file may not be callable as a step"
        log_warning "1" "  → Add: def call(Map config = [:]) { ... }"
    fi

    if [ "$has_doc_comment" = false ]; then
        log_info "1" "No documentation comment found - consider adding /** ... */ block"
        log_info "1" "  → Documents step usage for Pipeline Syntax generator"
    fi

    # Check file naming convention
    if [[ ! "$filename" =~ ^[a-z][a-zA-Z0-9]*$ ]]; then
        log_warning "1" "Filename '$filename' should be camelCase starting with lowercase"
        log_warning "1" "  → Convention: myStepName.groovy"
    fi
}

# Validate src/**/*.groovy class files
validate_src_file() {
    local file=$1
    local filename=$(basename "$file" .groovy)
    local line_num=0
    local has_package=false
    local has_class=false
    local has_serializable=false

    echo -e "${BLUE}=== Validating Source Class: ${BOLD}$filename${NC}${BLUE} ===${NC}"
    echo "File: $file"
    echo ""

    # Check for package declaration
    if grep -qE '^\s*package\s+' "$file"; then
        has_package=true
    fi

    # Check for class/interface/enum
    if grep -qE '^\s*(class|interface|enum|trait)\s+' "$file"; then
        has_class=true
    fi

    # Check for Serializable
    if grep -q 'implements.*Serializable' "$file"; then
        has_serializable=true
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Skip empty lines and comments
        if [[ -z "${line// }" ]] || [[ "$line" =~ ^[[:space:]]*//.* ]]; then
            continue
        fi

        # Check for hardcoded credentials
        if echo "$line" | grep -qiE '(password|secret|token|api[_-]?key)\s*=\s*["\047][a-zA-Z0-9]'; then
            log_error "$line_num" "Potential hardcoded credential detected"
        fi

        # Check for proper import usage
        if echo "$line" | grep -qE '^\s*import\s+' && echo "$line" | grep -q '\*'; then
            log_info "$line_num" "Wildcard import detected - prefer explicit imports"
        fi

        # Check for static method usage in CPS context
        if echo "$line" | grep -qE 'static.*def\s+' && ! grep -q '@NonCPS' "$file"; then
            log_info "$line_num" "Static method detected - ensure CPS compatibility or add @NonCPS"
        fi

    done < "$file"

    # Post-file checks
    if [ "$has_class" = true ] && [ "$has_serializable" = false ]; then
        log_warning "1" "Class does not implement Serializable - may cause CPS issues"
        log_warning "1" "  → Add: implements Serializable"
    fi

    if [ "$has_class" = true ] && [ "$has_package" = false ]; then
        log_warning "1" "No package declaration - add package statement"
        log_warning "1" "  → Add: package com.example.jenkins"
    fi

    # Check class naming matches filename
    local class_name=$(grep -oE '^\s*(class|interface|enum|trait)\s+([A-Z][a-zA-Z0-9]*)' "$file" | head -1 | awk '{print $2}')
    if [ -n "$class_name" ] && [ "$class_name" != "$filename" ]; then
        log_error "1" "Class name '$class_name' does not match filename '$filename'"
    fi
}

# Print validation results
print_results() {
    echo ""
    echo -e "${BLUE}=== Validation Results ===${NC}"
    echo ""

    if [ ${#ERROR_MESSAGES[@]} -gt 0 ]; then
        echo -e "${RED}ERRORS (${ERRORS}):${NC}"
        for msg in "${ERROR_MESSAGES[@]}"; do
            echo -e "${RED}$msg${NC}"
        done
        echo ""
    fi

    if [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}WARNINGS (${WARNINGS}):${NC}"
        for msg in "${WARNING_MESSAGES[@]}"; do
            echo -e "${YELLOW}$msg${NC}"
        done
        echo ""
    fi

    if [ ${#INFO_MESSAGES[@]} -gt 0 ]; then
        echo -e "${BLUE}INFO (${INFO}):${NC}"
        for msg in "${INFO_MESSAGES[@]}"; do
            echo -e "${BLUE}$msg${NC}"
        done
        echo ""
    fi

    echo -e "${BLUE}=== Summary ===${NC}"
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ Validation passed with no errors or warnings${NC}"
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠ Validation passed with ${WARNINGS} warning(s)${NC}"
    else
        echo -e "${RED}✗ Validation failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)${NC}"
    fi
}

# Validate a single file
validate_file() {
    local file=$1
    local file_type=$(detect_library_file_type "$file")

    case "$file_type" in
        vars)
            validate_vars_file "$file"
            ;;
        src)
            validate_src_file "$file"
            ;;
        unknown)
            echo -e "${YELLOW}Warning: Could not determine file type for $file${NC}"
            echo "Treating as vars file..."
            validate_vars_file "$file"
            ;;
    esac
}

# Validate directory of files
validate_directory() {
    local dir=$1
    local file_count=0

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ${BOLD}Jenkins Shared Library Validator${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "Directory: ${BOLD}$dir${NC}"
    echo ""

    # Find and validate vars files
    if [ -d "$dir/vars" ]; then
        echo -e "${BLUE}--- Validating vars/ directory ---${NC}"
        for file in "$dir/vars"/*.groovy; do
            if [ -f "$file" ]; then
                file_count=$((file_count + 1))
                validate_file "$file"
                echo ""
            fi
        done
    fi

    # Find and validate src files
    if [ -d "$dir/src" ]; then
        echo -e "${BLUE}--- Validating src/ directory ---${NC}"
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                file_count=$((file_count + 1))
                validate_file "$file"
                echo ""
            fi
        done < <(find "$dir/src" -name "*.groovy" -type f 2>/dev/null)
    fi

    # If no vars or src, validate all groovy files
    if [ $file_count -eq 0 ]; then
        echo -e "${YELLOW}No vars/ or src/ directory found. Validating all .groovy files...${NC}"
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                file_count=$((file_count + 1))
                validate_file "$file"
                echo ""
            fi
        done < <(find "$dir" -name "*.groovy" -type f 2>/dev/null)
    fi

    if [ $file_count -eq 0 ]; then
        echo -e "${YELLOW}No Groovy files found in $dir${NC}"
        exit 0
    fi

    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}Validated ${file_count} file(s)${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
}

# Main execution
if [ $# -ne 1 ]; then
    usage
fi

TARGET="$1"

if [ -f "$TARGET" ]; then
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  ${BOLD}Jenkins Shared Library Validator${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    validate_file "$TARGET"
    print_results
elif [ -d "$TARGET" ]; then
    validate_directory "$TARGET"
    print_results
else
    echo -e "${RED}Error: '$TARGET' is not a valid file or directory${NC}"
    exit 2
fi

# Exit with appropriate code
if [ $ERRORS -gt 0 ]; then
    exit 1
fi
exit 0