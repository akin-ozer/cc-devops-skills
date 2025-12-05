#!/bin/bash

# Declarative Pipeline Validator
# Validates Jenkins Declarative Pipeline syntax and structure

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Validation result arrays
declare -a ERROR_MESSAGES=()
declare -a WARNING_MESSAGES=()
declare -a INFO_MESSAGES=()

usage() {
    echo "Usage: $0 <jenkinsfile>"
    echo "Validates a Declarative Jenkins Pipeline"
    exit 1
}

log_error() {
    local line=$1
    local message=$2
    ERROR_MESSAGES+=("ERROR [Line $line]: $message")
    ((ERRORS++))
}

log_warning() {
    local line=$1
    local message=$2
    WARNING_MESSAGES+=("WARNING [Line $line]: $message")
    ((WARNINGS++))
}

log_info() {
    local line=$1
    local message=$2
    INFO_MESSAGES+=("INFO [Line $line]: $message")
    ((INFO++))
}

# Check if file starts with 'pipeline {'
validate_pipeline_block() {
    local file=$1

    # Remove comments and empty lines for checking
    local first_meaningful=$(grep -v '^\s*//' "$file" | grep -v '^\s*$' | head -1)

    if ! echo "$first_meaningful" | grep -q '^\s*pipeline\s*{'; then
        log_error 1 "Declarative pipeline must start with 'pipeline {' block"
        return 1
    fi

    return 0
}

# Check for required top-level sections
validate_required_sections() {
    local file=$1

    # Check for agent section
    if ! grep -q '^\s*agent\s' "$file"; then
        local line=$(grep -n 'pipeline\s*{' "$file" | head -1 | cut -d: -f1)
        # Default to line 1 if pipeline block not found
        line=${line:-1}
        log_error "$line" "Missing required section 'agent' - must be defined at pipeline or stage level"
        log_error "$line" "  → Add 'agent any' or specific agent configuration"
    fi

    # Check for stages section
    if ! grep -q '^\s*stages\s*{' "$file"; then
        local line=$(grep -n 'pipeline\s*{' "$file" | head -1 | cut -d: -f1)
        # Default to line 1 if pipeline block not found
        line=${line:-1}
        log_error "$line" "Missing required section 'stages'"
        log_error "$line" "  → Add 'stages { ... }' block containing your pipeline stages"
    fi

    # If stages exists, check for at least one stage
    if grep -q '^\s*stages\s*{' "$file"; then
        if ! grep -q '^\s*stage(' "$file"; then
            local line=$(grep -n 'stages\s*{' "$file" | head -1 | cut -d: -f1)
            line=${line:-1}
            log_error "$line" "stages block must contain at least one stage"
            log_error "$line" "  → Add 'stage('name') { ... }' inside stages block"
        fi
    fi
}

# Validate stage structure
validate_stages() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Check for stage definitions (but skip nested stages inside parallel blocks)
        if echo "$line" | grep -q '^\s*stage('; then
            # Check if stage has a name
            if ! echo "$line" | grep -q "stage(['\"]"; then
                log_error "$line_num" "Stage must have a name in quotes"
                log_error "$line_num" "  → Use: stage('Stage Name') { ... }"
            fi

            # Check for steps block (need to look ahead)
            local stage_start=$line_num
            local has_valid_body=false
            local has_agent=false
            local check_line=$line_num

            # Initialize brace depth - account for opening brace on stage line itself
            # e.g., stage('Build') { has one opening brace
            local stage_open_braces=$(echo "$line" | grep -o '{' | wc -l)
            local stage_close_braces=$(echo "$line" | grep -o '}' | wc -l)
            local brace_depth=$((stage_open_braces - stage_close_braces))

            # Look for steps, parallel, or script blocks within this stage
            # Use brace depth tracking to find the stage boundary correctly
            for ((i=0; i<100; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                # Skip empty lines and comments
                if echo "$next_line" | grep -qE '^\s*(//.*)?$'; then
                    continue
                fi

                # Track brace depth
                local open_braces=$(echo "$next_line" | grep -o '{' | wc -l)
                local close_braces=$(echo "$next_line" | grep -o '}' | wc -l)
                brace_depth=$((brace_depth + open_braces - close_braces))

                # Check for valid stage body types at the stage level (brace_depth == 1)
                # steps, parallel, and matrix are all valid stage body types
                if echo "$next_line" | grep -qE '^\s*steps\s*\{'; then
                    has_valid_body=true
                fi

                if echo "$next_line" | grep -qE '^\s*parallel\s*\{'; then
                    has_valid_body=true
                fi

                if echo "$next_line" | grep -qE '^\s*matrix\s*\{'; then
                    has_valid_body=true
                fi

                # Check for stage-level agent
                if echo "$next_line" | grep -qE '^\s*agent\s'; then
                    has_agent=true
                fi

                # Stop if we've exited the stage block (brace depth back to 0 or negative)
                if [ $brace_depth -le 0 ]; then
                    break
                fi

                # Safety: Stop if we hit another top-level stage (at depth 0)
                if [ $brace_depth -eq 0 ] && echo "$next_line" | grep -q '^\s*stage('; then
                    break
                fi
            done

            # Only report error if no valid body found
            # Note: Stages inside parallel blocks don't need steps at their level
            # because the parallel block itself satisfies the requirement
            if [[ "$has_valid_body" == false ]] && [[ "$has_agent" == false ]]; then
                # Check if this might be a nested stage inside a parallel block
                # by looking backward for parallel {
                local is_nested_in_parallel=false
                local look_back=$line_num
                local back_depth=0

                for ((j=0; j<50 && look_back>1; j++)); do
                    ((look_back--))
                    local prev_line=$(sed -n "${look_back}p" "$file")

                    if echo "$prev_line" | grep -qE '^\s*parallel\s*\{'; then
                        is_nested_in_parallel=true
                        break
                    fi

                    # Stop if we hit the stages block start
                    if echo "$prev_line" | grep -qE '^\s*stages\s*\{'; then
                        break
                    fi
                done

                # Don't error on nested parallel stages - they're checked separately
                if [[ "$is_nested_in_parallel" == false ]]; then
                    log_error "$stage_start" "Stage must contain 'steps', 'parallel', or 'matrix' block"
                    log_error "$stage_start" "  → Add 'steps { ... }' inside stage"
                fi
            fi
        fi
    done < "$file"
}

# Check for invalid directive placement
validate_directive_placement() {
    local file=$1
    local line_num=0
    local in_steps=false
    local in_post=false

    while IFS= read -r line; do
        ((line_num++))

        # Track if we're inside steps block
        if echo "$line" | grep -q '^\s*steps\s*{'; then
            in_steps=true
        fi

        if echo "$line" | grep -q '^\s*post\s*{'; then
            in_post=true
        fi

        # Reset on closing brace (simple heuristic)
        if [[ "$in_steps" == true ]] && echo "$line" | grep -q '^\s*}\s*$'; then
            in_steps=false
        fi

        if [[ "$in_post" == true ]] && echo "$line" | grep -q '^\s*}\s*$'; then
            in_post=false
        fi

        # Check for directives that shouldn't be in steps
        if [[ "$in_steps" == true ]]; then
            if echo "$line" | grep -qE '^\s*(environment|options|parameters|triggers|tools)\s*{'; then
                log_error "$line_num" "Directive '$(echo "$line" | grep -oE '(environment|options|parameters|triggers|tools)')' cannot be inside 'steps' block"
                log_error "$line_num" "  → Move this directive to pipeline or stage level"
            fi
        fi
    done < "$file"
}

# Check for common syntax errors
validate_syntax() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Skip comment lines
        if echo "$line" | grep -q '^\s*//'; then
            continue
        fi

        # Check for semicolons at end of lines (not needed in Jenkins pipelines)
        if echo "$line" | grep -qE '[^"\047];\s*$' && ! echo "$line" | grep -q '^\s*//'; then
            log_warning "$line_num" "Semicolon at end of line is unnecessary in Jenkins pipelines"
            log_warning "$line_num" "  → Remove trailing semicolon"
        fi

        # Check for unmatched quotes (basic check)
        # Skip lines that are part of multi-line strings (triple quotes or heredocs)
        if echo "$line" | grep -qE "'''|\"\"\""; then
            continue
        fi

        # Skip lines inside multi-line sh blocks (contain just string content)
        if echo "$line" | grep -qE '^\s*(echo|mkdir|make|cd|cmake|mvn|gradle|npm|yarn|kubectl|docker|git)\s'; then
            continue
        fi

        # Remove escaped quotes before counting
        local clean_line=$(echo "$line" | sed "s/\\\\'//g" | sed 's/\\"//g')
        local single_quotes=$(echo "$clean_line" | grep -o "'" | wc -l)
        local double_quotes=$(echo "$clean_line" | grep -o '"' | wc -l)

        # Only flag truly unbalanced quotes (not in multi-line contexts)
        # Skip if line has shell command patterns that commonly span lines
        if (( single_quotes % 2 != 0 )); then
            # Only error if not a shell command continuation
            if ! echo "$line" | grep -qE "sh\s+'''|sh\s*\(|script:|'''"; then
                log_error "$line_num" "Unmatched single quote detected"
            fi
        fi

        if (( double_quotes % 2 != 0 )); then
            # Only error if not a shell command continuation
            if ! echo "$line" | grep -qE 'sh\s+"""|sh\s*\(|script:|"""'; then
                log_error "$line_num" "Unmatched double quote detected"
            fi
        fi

        # Check for common typos in section names (singular instead of plural)
        # Only flag when followed by { (not function calls like step([...]))
        # Note: 'stage' is valid as stage('name'), so we check specifically for 'stage {'
        if echo "$line" | grep -qE '^\s*(option|parameter|trigger|tool)\s*\{'; then
            local typo=$(echo "$line" | grep -oE '(option|parameter|trigger|tool)')
            log_error "$line_num" "Possible typo: '$typo' (did you mean '${typo}s'?)"
        fi
        # Special check for 'step {' (not step( which is valid)
        if echo "$line" | grep -qE '^\s*step\s*\{'; then
            log_error "$line_num" "Possible typo: 'step' (did you mean 'steps'?)"
        fi
    done < "$file"
}

# Validate environment variable syntax
validate_environment() {
    local file=$1
    local line_num=0
    local in_env=false

    while IFS= read -r line; do
        ((line_num++))

        if echo "$line" | grep -q '^\s*environment\s*{'; then
            in_env=true
            continue
        fi

        if [[ "$in_env" == true ]]; then
            if echo "$line" | grep -q '^\s*}\s*$'; then
                in_env=false
                continue
            fi

            # Check for proper environment variable syntax
            if echo "$line" | grep -q '=' && ! echo "$line" | grep -q '^\s*//' && ! echo "$line" | grep -qE '^\s*[A-Z_][A-Z0-9_]*\s*='; then
                log_warning "$line_num" "Environment variable should be UPPER_CASE"
                log_warning "$line_num" "  → Convention: MY_VAR = 'value'"
            fi
        fi
    done < "$file"
}

# Check for parallel stages usage
validate_parallel() {
    local file=$1

    if grep -q '^\s*parallel\s*{' "$file"; then
        local line=$(grep -n 'parallel\s*{' "$file" | head -1 | cut -d: -f1)

        # Check for parallelsAlwaysFailFast() in pipeline options (global setting)
        local has_global_failfast=false
        if grep -q 'parallelsAlwaysFailFast' "$file"; then
            has_global_failfast=true
        fi

        # If global setting is present, no need to check individual parallel blocks
        if [[ "$has_global_failfast" == true ]]; then
            return 0
        fi

        # Check if failFast is considered on individual parallel blocks
        # In Declarative pipelines, failFast appears BEFORE the parallel block (as a stage directive)
        # So we need to check both before (-B) and after (-A) the parallel block
        local has_failfast=false
        if grep -B 5 'parallel\s*{' "$file" | grep -q 'failFast'; then
            has_failfast=true
        fi
        if grep -A 20 'parallel\s*{' "$file" | grep -q 'failFast'; then
            has_failfast=true
        fi

        if [[ "$has_failfast" == false ]]; then
            log_info "$line" "Consider adding 'failFast true' to parallel block to stop on first failure"
            log_info "$line" "  → Or add 'parallelsAlwaysFailFast()' in pipeline options for global coverage"
        fi
    fi
}

# Validate when conditions
validate_when() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        if echo "$line" | grep -q '^\s*when\s*{'; then
            # Check for valid when conditions in next few lines
            local has_condition=false
            local check_line=$line_num

            for ((i=0; i<10; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                if echo "$next_line" | grep -qE '^\s*(branch|environment|expression|tag|not|allOf|anyOf)'; then
                    has_condition=true
                    break
                fi

                if echo "$next_line" | grep -q '^\s*}\s*$'; then
                    break
                fi
            done

            if [[ "$has_condition" == false ]]; then
                log_warning "$line_num" "when block appears empty or has no valid condition"
                log_warning "$line_num" "  → Use: branch, environment, expression, tag, or boolean operators"
            fi
        fi
    done < "$file"
}

# Validate matrix builds (requires Jenkins 2.0+)
validate_matrix() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        if echo "$line" | grep -q '^\s*matrix\s*{'; then
            local matrix_start=$line_num
            local has_axes=false
            local has_stages=false
            local check_line=$line_num
            local brace_count=1

            # Check matrix block structure
            for ((i=0; i<50; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                # Track braces
                local open=$(echo "$next_line" | grep -o '{' | wc -l)
                local close=$(echo "$next_line" | grep -o '}' | wc -l)
                brace_count=$((brace_count + open - close))

                if echo "$next_line" | grep -q '^\s*axes\s*{'; then
                    has_axes=true
                fi

                if echo "$next_line" | grep -q '^\s*stages\s*{'; then
                    has_stages=true
                fi

                # Exit when matrix block closes
                if [ $brace_count -le 0 ]; then
                    break
                fi
            done

            # Validate matrix structure
            if [[ "$has_axes" == false ]]; then
                log_error "$matrix_start" "Matrix block missing required 'axes' section"
                log_error "$matrix_start" "  → Add 'axes { axis { name 'AXIS_NAME'; values 'val1', 'val2' } }'"
            fi

            if [[ "$has_stages" == false ]]; then
                log_error "$matrix_start" "Matrix block missing required 'stages' section"
                log_error "$matrix_start" "  → Add 'stages { stage('Build') { steps { ... } } }'"
            fi

            # Check for best practices
            if ! grep -A 30 "^\s*matrix\s*{" "$file" | grep -q 'failFast'; then
                log_info "$matrix_start" "Consider adding 'failFast true' to matrix options for faster feedback"
                log_info "$matrix_start" "  → options { failFast true }"
            fi
        fi

        # Validate axis definitions
        if echo "$line" | grep -q '^\s*axis\s*{'; then
            local axis_start=$line_num
            local has_name=false
            local has_values=false
            local check_line=$line_num

            for ((i=0; i<10; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                if echo "$next_line" | grep -q '^\s*name\s'; then
                    has_name=true
                fi

                if echo "$next_line" | grep -q '^\s*values\s'; then
                    has_values=true
                fi

                if echo "$next_line" | grep -q '^\s*}\s*$'; then
                    break
                fi
            done

            if [[ "$has_name" == false ]]; then
                log_error "$axis_start" "Axis missing required 'name' property"
                log_error "$axis_start" "  → Add 'name \"AXIS_NAME\"'"
            fi

            if [[ "$has_values" == false ]]; then
                log_error "$axis_start" "Axis missing required 'values' property"
                log_error "$axis_start" "  → Add 'values \"val1\", \"val2\"'"
            fi
        fi

        # Validate excludes section (optional but must be valid if present)
        if echo "$line" | grep -q '^\s*excludes\s*{'; then
            local excludes_start=$line_num
            local check_line=$line_num
            local has_exclude=false

            for ((i=0; i<20; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                if echo "$next_line" | grep -q '^\s*exclude\s*{'; then
                    has_exclude=true
                fi

                if echo "$next_line" | grep -q '^\s*}\s*$'; then
                    break
                fi
            done

            if [[ "$has_exclude" == false ]]; then
                log_warning "$excludes_start" "excludes block is empty"
                log_warning "$excludes_start" "  → Add 'exclude { axis { ... } }' or remove excludes block"
            fi
        fi
    done < "$file"
}

# Validate @Library shared library imports
validate_shared_libraries() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Check for @Library annotations
        if echo "$line" | grep -q '@Library'; then
            # Check for proper syntax: @Library('name') _  or @Library(['lib1', 'lib2'])
            if ! echo "$line" | grep -qE "@Library\s*\(\s*['\"\[]"; then
                log_error "$line_num" "Invalid @Library syntax"
                log_error "$line_num" "  → Use: @Library('library-name') _ or @Library(['lib1', 'lib2']) _"
            fi

            # Check if underscore is used for implicit import
            if echo "$line" | grep -qE "@Library\s*\([^)]+\)\s*$"; then
                log_warning "$line_num" "Missing underscore after @Library - add '_' for implicit import"
                log_warning "$line_num" "  → @Library('library-name') _"
            fi

            # Check for version specification
            if ! echo "$line" | grep -qE "@Library\s*\(['\"][^'\"]+@"; then
                log_info "$line_num" "Consider pinning library version for reproducible builds"
                log_info "$line_num" "  → @Library('library-name@branch-or-tag') _"
            fi
        fi

        # Check for library step usage
        if echo "$line" | grep -q '^\s*library\s*'; then
            if ! echo "$line" | grep -qE "library\s+(identifier:|['\"])"; then
                log_warning "$line_num" "Invalid library step syntax"
                log_warning "$line_num" "  → Use: library identifier: 'name@version' or library 'name'"
            fi
        fi
    done < "$file"
}

# Main validation function
validate_declarative() {
    local file=$1

    echo -e "${BLUE}=== Validating Declarative Pipeline ===${NC}"
    echo "File: $file"
    echo ""

    # Run all validation checks (|| true prevents early exit on validation failures)
    validate_pipeline_block "$file" || true
    validate_required_sections "$file" || true
    validate_stages "$file" || true
    validate_directive_placement "$file" || true
    validate_syntax "$file" || true
    validate_environment "$file" || true
    validate_parallel "$file" || true
    validate_when "$file" || true
    validate_matrix "$file" || true
    validate_shared_libraries "$file" || true

    # Print results
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

    # Summary
    echo -e "${BLUE}=== Summary ===${NC}"
    if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ Validation passed with no errors or warnings${NC}"
        return 0
    elif [ $ERRORS -eq 0 ]; then
        echo -e "${YELLOW}✓ Validation passed with $WARNINGS warning(s)${NC}"
        return 0
    else
        echo -e "${RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
        return 1
    fi
}

# Main execution
if [ $# -ne 1 ]; then
    usage
fi

JENKINSFILE="$1"

if [ ! -f "$JENKINSFILE" ]; then
    echo -e "${RED}Error: File '$JENKINSFILE' not found${NC}"
    exit 1
fi

validate_declarative "$JENKINSFILE"
