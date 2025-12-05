#!/bin/bash

# Scripted Pipeline Validator
# Validates Jenkins Scripted Pipeline syntax and structure

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
    echo "Validates a Scripted Jenkins Pipeline"
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

# Basic Groovy syntax validation
validate_groovy_syntax() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Skip comments and empty lines
        if echo "$line" | grep -qE '^\s*(//|$)'; then
            continue
        fi

        # Check for unmatched braces (simple check)
        local open_braces=$(echo "$line" | grep -o '{' | wc -l)
        local close_braces=$(echo "$line" | grep -o '}' | wc -l)

        # Check for unmatched quotes
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

        # Note: Per-line parenthesis check removed to avoid false positives
        # Multi-line constructs like properties([...]) are valid Groovy
    done < "$file"

    # Check overall brace balance
    local total_open=$(grep -o '{' "$file" | wc -l)
    local total_close=$(grep -o '}' "$file" | wc -l)

    if (( total_open != total_close )); then
        log_error "EOF" "Unbalanced braces: $total_open opening, $total_close closing"
    fi
}

# Validate node block usage
validate_node_blocks() {
    local file=$1
    local line_num=0
    local has_node=false

    while IFS= read -r line; do
        ((line_num++))

        # Check for node blocks
        if echo "$line" | grep -qE '^\s*node\s*(\(|{)'; then
            has_node=true

            # Check if node has label or is empty
            if echo "$line" | grep -qE '^\s*node\s*\(\s*\)'; then
                log_warning "$line_num" "Empty node() - consider using node('label') for specific agents"
                log_warning "$line_num" "  → Use: node('docker') or node('linux') for specific agents"
            fi
        fi

        # Check for stage definitions outside node blocks (potential issue)
        if echo "$line" | grep -qE '^\s*stage\s*\(' && [[ "$has_node" == false ]]; then
            log_info "$line_num" "Stage defined outside node block - ensure this is intentional"
        fi
    done < "$file"

    if [[ "$has_node" == false ]]; then
        log_warning 1 "No node blocks found - scripted pipelines typically use node blocks for agent allocation"
        log_warning 1 "  → Wrap your pipeline code in node { ... } block"
    fi
}

# Check for error handling
validate_error_handling() {
    local file=$1
    local line_num=0
    local has_try=false
    local has_catch=false
    local has_finally=false

    while IFS= read -r line; do
        ((line_num++))

        # Check for try-catch-finally blocks
        if echo "$line" | grep -qE '^\s*try\s*{'; then
            has_try=true
            local try_line=$line_num

            # Look for corresponding catch/finally in next 100 lines
            local check_line=$line_num
            local found_catch=false
            local found_finally=false

            for ((i=0; i<100; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                # Match catch with optional leading } for "} catch (" pattern
                if echo "$next_line" | grep -qE 'catch\s*\('; then
                    found_catch=true
                fi

                # Match finally with optional leading } for "} finally {" pattern
                if echo "$next_line" | grep -qE 'finally\s*\{'; then
                    found_finally=true
                    break
                fi
            done

            if [[ "$found_catch" == false ]]; then
                log_warning "$try_line" "try block without catch - consider adding error handling"
                log_warning "$try_line" "  → Add: catch (Exception e) { ... }"
            fi
        fi

        # Check for sh/bat commands without try-catch
        if echo "$line" | grep -qE '\s+(sh|bat)\s*["\047(]' && ! echo "$line" | grep -q 'returnStatus'; then
            # This is a heuristic - check if we're in a try block by looking backward
            # Also need to check we're not in catch/finally (which would be inside try)
            local in_try=false
            local in_catch_finally=false
            local check_back=$line_num
            local brace_depth=0

            for ((i=0; i<100 && check_back>0; i++)); do
                ((check_back--))
                local prev_line=$(sed -n "${check_back}p" "$file")

                # Track brace depth to understand scope
                local close_braces=$(echo "$prev_line" | grep -o '}' | wc -l)
                local open_braces=$(echo "$prev_line" | grep -o '{' | wc -l)
                brace_depth=$((brace_depth + close_braces - open_braces))

                # Check if we find a try block at the right depth
                if echo "$prev_line" | grep -qE '^\s*try\s*\{'; then
                    in_try=true
                    break
                fi

                # If we're in catch or finally block, we're effectively in error handling
                if echo "$prev_line" | grep -qE 'catch\s*\(|finally\s*\{'; then
                    in_catch_finally=true
                    break
                fi

                # Stop if we exit the current block structure too far
                if [ $brace_depth -gt 3 ]; then
                    break
                fi
            done

            if [[ "$in_try" == false ]] && [[ "$in_catch_finally" == false ]]; then
                log_info "$line_num" "Consider wrapping shell commands in try-catch for better error handling"
            fi
        fi
    done < "$file"
}

# Validate @NonCPS usage
validate_noncps() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        if echo "$line" | grep -q '@NonCPS'; then
            # Check if next lines contain problematic pipeline steps
            local check_line=$line_num
            local found_issue=false

            for ((i=0; i<30; i++)); do
                ((check_line++))
                local next_line=$(sed -n "${check_line}p" "$file")

                # Check for async pipeline steps in @NonCPS method
                if echo "$next_line" | grep -qE '\s+(sh|bat|sleep|timeout|node|stage)\s*["\047(]'; then
                    log_error "$check_line" "Cannot use pipeline steps (sh, sleep, etc.) in @NonCPS methods"
                    log_error "$check_line" "  → Remove @NonCPS or refactor to not use async pipeline steps"
                    found_issue=true
                    break
                fi

                # Stop at method end
                if echo "$next_line" | grep -qE '^\s*}\s*$'; then
                    break
                fi
            done
        fi
    done < "$file"
}

# Check for proper variable declarations
validate_variables() {
    local file=$1
    local line_num=0

    # Track declared variables to avoid false positives on reassignments
    # Using a simple string list instead of associative array for bash 3.x compatibility
    local declared_vars=""

    # First pass: collect all declared variables
    while IFS= read -r line; do
        ((line_num++))

        # Track variables declared with def, String, Integer, Boolean, Map, List
        if echo "$line" | grep -qE '^\s*(def|String|Integer|Boolean|Map|List)\s+([a-zA-Z_][a-zA-Z0-9_]*)'; then
            local var_name=$(echo "$line" | grep -oE '(def|String|Integer|Boolean|Map|List)\s+[a-zA-Z_][a-zA-Z0-9_]*' | awk '{print $2}')
            if [[ -n "$var_name" ]]; then
                declared_vars="$declared_vars:$var_name:"
            fi
        fi
    done < "$file"

    # Second pass: check for issues
    line_num=0
    while IFS= read -r line; do
        ((line_num++))

        # Skip comments
        if echo "$line" | grep -qE '^\s*//'; then
            continue
        fi

        # Check for variable assignments without def
        if echo "$line" | grep -qE '^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*=' && ! echo "$line" | grep -qE '^\s*(def|String|Integer|Boolean|Map|List)'; then
            # Check if it's not a property assignment (has dot notation)
            if ! echo "$line" | grep -q '\.'; then
                # Extract variable name
                local var_name=$(echo "$line" | grep -oE '^\s*[a-zA-Z_][a-zA-Z0-9_]*' | tr -d ' ')
                # Only warn if variable was not previously declared
                if [[ "$declared_vars" != *":$var_name:"* ]]; then
                    log_info "$line_num" "Consider using 'def' for variable declaration for better scoping"
                    log_info "$line_num" "  → Use: def myVar = ... instead of myVar = ..."
                fi
            fi
        fi

        # Check for proper string interpolation
        if echo "$line" | grep -q '\$[A-Z_][A-Z0-9_]*' && ! echo "$line" | grep -q '"\$'; then
            log_warning "$line_num" "Variable interpolation should use double quotes, not single quotes"
            log_warning "$line_num" "  → Use: \"text \${VAR}\" instead of 'text \$VAR'"
        fi
    done < "$file"
}

# Check for common anti-patterns
validate_antipatterns() {
    local file=$1
    local line_num=0

    while IFS= read -r line; do
        ((line_num++))

        # Check for JsonSlurper on controller
        if echo "$line" | grep -q 'JsonSlurper'; then
            log_warning "$line_num" "JsonSlurper runs on controller - consider using jq on agent instead"
            log_warning "$line_num" "  → Use: sh(script: 'jq ...', returnStdout: true)"
        fi

        # Check for HttpRequest without proper delegation
        if echo "$line" | grep -qE 'HttpRequest|httpRequest' && ! echo "$line" | grep -q 'sh.*curl'; then
            log_warning "$line_num" "Consider using curl/wget on agent instead of HTTP libraries on controller"
            log_warning "$line_num" "  → Use: sh 'curl -s http://...' for better performance"
        fi

        # Check for readFile without size checks
        if echo "$line" | grep -q 'readFile' && ! echo "$line" | grep -q 'encoding'; then
            log_info "$line_num" "Consider checking file size before readFile to avoid memory issues"
        fi

        # Check for writeFile
        if echo "$line" | grep -q 'writeFile'; then
            log_info "$line_num" "Ensure writeFile is writing to workspace, not arbitrary locations"
        fi
    done < "$file"
}

# Check for parallel execution opportunities
validate_parallel_usage() {
    local file=$1
    local line_num=0
    local stage_count=0

    while IFS= read -r line; do
        ((line_num++))

        if echo "$line" | grep -qE '^\s*stage\s*\('; then
            ((stage_count++))
        fi
    done < "$file"

    if [ $stage_count -gt 3 ] && ! grep -q 'parallel' "$file"; then
        log_info 1 "Consider using parallel execution for independent stages to improve build time"
        log_info 1 "  → See: references/scripted_syntax.md#parallel-execution"
    fi
}

# Check for timestamps and other useful wrappers
validate_wrappers() {
    local file=$1

    if ! grep -q 'timestamps' "$file"; then
        log_info 1 "Consider adding timestamps() wrapper for better log readability"
        log_info 1 "  → Wrap pipeline: timestamps { node { ... } }"
    fi

    if ! grep -q 'ansiColor' "$file" && ! grep -q 'xterm' "$file"; then
        log_info 1 "Consider adding ansiColor wrapper for colorized output"
        log_info 1 "  → Wrap pipeline: ansiColor('xterm') { ... }"
    fi
}

# Main validation function
validate_scripted() {
    local file=$1

    echo -e "${BLUE}=== Validating Scripted Pipeline ===${NC}"
    echo "File: $file"
    echo ""

    # Run all validation checks (|| true prevents early exit on validation failures)
    validate_groovy_syntax "$file" || true
    validate_node_blocks "$file" || true
    validate_error_handling "$file" || true
    validate_noncps "$file" || true
    validate_variables "$file" || true
    validate_antipatterns "$file" || true
    validate_parallel_usage "$file" || true
    validate_wrappers "$file" || true

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

validate_scripted "$JENKINSFILE"
