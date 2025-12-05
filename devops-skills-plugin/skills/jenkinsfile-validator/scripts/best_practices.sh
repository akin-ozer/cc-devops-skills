#!/bin/bash

# Best Practices Checker
# Checks Jenkins pipelines against best practices from official documentation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REFERENCES_DIR="$(dirname "$SCRIPT_DIR")/references"

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
PASS=0

# Validation result arrays
declare -a ERROR_MESSAGES=()
declare -a WARNING_MESSAGES=()
declare -a INFO_MESSAGES=()
declare -a PASS_MESSAGES=()

usage() {
    echo "Usage: $0 <jenkinsfile>"
    echo "Checks Jenkins pipeline against best practices"
    exit 1
}

log_error() {
    local category=$1
    local message=$2
    ERROR_MESSAGES+=("ERROR [$category]: $message")
    ((ERRORS++))
}

log_warning() {
    local category=$1
    local message=$2
    WARNING_MESSAGES+=("WARNING [$category]: $message")
    ((WARNINGS++))
}

log_info() {
    local category=$1
    local message=$2
    INFO_MESSAGES+=("INFO [$category]: $message")
    ((INFO++))
}

log_pass() {
    local category=$1
    PASS_MESSAGES+=("✓ $category")
    ((PASS++))
}

# Helper function to get file content without comments
# Handles:
#   - Single-line comments: // comment
#   - Inline comments: def x = 'value' // comment
#   - Multi-line block comments: /* ... */ (including content on same line as markers)
#   - Single-line block comments: /* comment */
#   - Inline block comments: code /* comment */ more_code
#   - Javadoc-style: /** ... */ and * comment lines
get_code_without_comments() {
    local file=$1

    # Simplified comment removal that avoids false positives from glob patterns
    # Only removes:
    # 1. Full-line // comments (lines starting with //)
    # 2. Full-line /* ... */ block comments
    # 3. Multi-line block comments that start at beginning of line
    # Does NOT remove inline comments to avoid breaking glob patterns like **/unit/**
    awk '
    BEGIN { in_block_comment = 0 }
    {
        # If in a block comment, look for end
        if (in_block_comment) {
            if (index($0, "*/") > 0) {
                in_block_comment = 0
                # Skip this line (it ends the block comment)
            }
            next
        }

        # Check for full-line // comment
        if ($0 ~ /^[[:space:]]*\/\//) {
            next
        }

        # Check for block comment starting at beginning of line
        if ($0 ~ /^[[:space:]]*\/\*/) {
            # Check if it ends on same line
            if ($0 ~ /\*\//) {
                # Single-line block comment, skip
                next
            } else {
                # Multi-line block comment starts
                in_block_comment = 1
                next
            }
        }

        # Check for javadoc continuation lines (starting with *)
        if ($0 ~ /^[[:space:]]*\*[^\/]/ || $0 ~ /^[[:space:]]*\*$/) {
            next
        }

        # Skip empty lines
        if ($0 ~ /^[[:space:]]*$/) {
            next
        }

        print
    }
    ' "$file" 2>/dev/null || cat "$file"
}

# 1. Check for combined shell commands
check_combined_shell_commands() {
    local file=$1
    # Only count actual sh/bat steps, not comments
    local sh_count=$(get_code_without_comments "$file" | grep -cE '^\s*(sh|bat)\s+["\047]' || true)

    if [ $sh_count -gt 5 ]; then
        log_warning "Performance" "Found $sh_count individual sh/bat steps - consider combining them"
        log_warning "Performance" "  → Use single sh step with triple-quoted multi-line string"
        log_warning "Performance" "  → This reduces overhead and improves performance"
    else
        log_pass "Shell commands are reasonably combined"
    fi
}

# 2. Check for agent-based operations (not controller)
check_agent_operations() {
    local file=$1
    local issues=0

    # Check for JsonSlurper
    if grep -q 'JsonSlurper' "$file"; then
        log_warning "Performance" "JsonSlurper runs on controller - use jq on agent instead"
        log_warning "Performance" "  → sh(script: 'jq \".field\" file.json', returnStdout: true)"
        ((issues++))
    fi

    # Check for HTTPRequest/HttpRequest
    if grep -qE '(HTTPRequest|HttpRequest|httpRequest)' "$file" && ! grep -q 'sh.*curl' "$file"; then
        log_warning "Performance" "HTTP requests on controller - use curl/wget on agent"
        log_warning "Performance" "  → sh 'curl -s http://example.com/api'"
        ((issues++))
    fi

    # Check for readFile with large files
    if grep -q 'readFile' "$file"; then
        log_info "Best Practice" "Ensure readFile is only used for small files to avoid controller memory issues"
    fi

    if [ $issues -eq 0 ]; then
        log_pass "No controller-heavy operations detected"
    fi
}

# 3. Check for proper credential management
check_credential_management() {
    local file=$1
    local good_practices=0
    local bad_practices=0

    # Check for withCredentials usage (good)
    if grep -q 'withCredentials' "$file"; then
        ((good_practices++))
    fi

    # Check for credentials() function (good)
    if grep -q 'credentials(' "$file"; then
        ((good_practices++))
    fi

    # Check for hardcoded values (bad)
    if grep -qiE '(password|token|api[_-]?key)\s*=\s*["\047][a-zA-Z0-9]' "$file"; then
        log_error "Security" "Potential hardcoded credentials detected"
        log_error "Security" "  → Use withCredentials or credentials() function"
        ((bad_practices++))
    fi

    if [ $good_practices -gt 0 ] && [ $bad_practices -eq 0 ]; then
        log_pass "Proper credential management detected"
    elif [ $bad_practices -eq 0 ]; then
        log_info "Security" "No credentials detected - ensure proper handling if added later"
    fi
}

# 4. Check for parallel execution usage
check_parallel_execution() {
    local file=$1
    # Only count actual stage definitions, not comments
    local stage_count=$(get_code_without_comments "$file" | grep -cE '^\s*stage[\s\(]' || true)

    # Check for actual parallel block usage, not just mentions in comments
    if get_code_without_comments "$file" | grep -qE '^\s*parallel\s*[\(\{]|parallel\s*:'; then
        log_pass "Parallel execution is used"

        # Check for parallelsAlwaysFailFast() in pipeline options (global setting)
        local has_global_failfast=false
        if get_code_without_comments "$file" | grep -q 'parallelsAlwaysFailFast'; then
            has_global_failfast=true
        fi

        # Only suggest failFast if global setting is not present
        if [[ "$has_global_failfast" == false ]]; then
            # Check for individual failFast settings
            if ! get_code_without_comments "$file" | grep -q 'failFast'; then
                log_info "Optimization" "Consider adding failFast: true to parallel blocks"
                log_info "Optimization" "  → Stops remaining parallel tasks on first failure"
            fi
        fi
    elif [ $stage_count -gt 4 ]; then
        log_info "Optimization" "Found $stage_count stages - consider parallel execution for independent stages"
        log_info "Optimization" "  → Can significantly reduce build time"
    fi
}

# 5. Check for error handling
check_error_handling() {
    local file=$1
    local has_try_catch=false
    local has_post=false

    if grep -qE '(try\s*\{|catch\s*\()' "$file"; then
        has_try_catch=true
    fi

    if grep -q 'post\s*{' "$file"; then
        has_post=true
    fi

    if [ "$has_try_catch" == true ] || [ "$has_post" == true ]; then
        log_pass "Error handling is present"

        # Check for post { always } or post { cleanup }
        if grep -q 'post\s*{' "$file"; then
            if grep -A 5 'post\s*{' "$file" | grep -qE '(always|cleanup)\s*{'; then
                log_pass "Post section includes cleanup actions"
            else
                log_info "Best Practice" "Consider adding 'always' or 'cleanup' sections to post block"
            fi
        fi
    else
        log_warning "Best Practice" "No error handling detected - consider adding try-catch or post sections"
        log_warning "Best Practice" "  → Ensures proper cleanup and notification on failures"
    fi
}

# 6. Check for timeout configuration
check_timeout() {
    local file=$1

    # Check for actual timeout usage, not just mentions in comments
    if get_code_without_comments "$file" | grep -qiE 'timeout\s*\(|timeout\s*:'; then
        log_pass "Timeout configuration is present"
    else
        log_warning "Best Practice" "No timeout configuration found"
        log_warning "Best Practice" "  → Add timeout to prevent hung builds"
        log_warning "Best Practice" "  → Declarative: options { timeout(time: 1, unit: 'HOURS') }"
    fi
}

# 7. Check for workspace cleanup
check_workspace_cleanup() {
    local file=$1

    # Use get_code_without_comments to avoid matching patterns in comments
    if get_code_without_comments "$file" | grep -qE '(cleanWs|deleteDir)'; then
        log_pass "Workspace cleanup is configured"
    else
        log_info "Best Practice" "Consider adding workspace cleanup for reproducible builds"
        log_info "Best Practice" "  → cleanWs() in post section or deleteDir() when needed"
    fi
}

# 8. Check for build triggers
check_build_triggers() {
    local file=$1

    # Check for actual trigger configuration, not just mentions in comments
    if get_code_without_comments "$file" | grep -qE 'triggers\s*\{|pollSCM\s*\(|cron\s*\('; then
        log_pass "Build triggers are configured"

        # Check for polling vs webhooks
        if get_code_without_comments "$file" | grep -q 'pollSCM'; then
            log_info "Optimization" "Using pollSCM - consider using webhooks instead for better performance"
        fi
    else
        log_info "Configuration" "No build triggers detected - configure if automated builds needed"
    fi
}

# 9. Check for test result publishing
check_test_publishing() {
    local file=$1
    local has_tests=false

    # Check for actual junit/publishHTML step calls, not just mentions in comments
    if get_code_without_comments "$file" | grep -qE 'junit\s+|junit\s*\(|testng\s*\(|publishHTML\s*\('; then
        log_pass "Test result publishing is configured"
        has_tests=true
    fi

    # Check if tests run but results not published
    if get_code_without_comments "$file" | grep -qE '(mvn|gradle|npm test|pytest)' && [ "$has_tests" == false ]; then
        log_warning "Best Practice" "Tests appear to run but results are not published"
        log_warning "Best Practice" "  → Add junit() or publishHTML() to publish test results"
    fi
}

# 10. Check for artifact archiving
check_artifact_archiving() {
    local file=$1

    # Use get_code_without_comments to avoid matching patterns in comments
    if get_code_without_comments "$file" | grep -q 'archiveArtifacts'; then
        log_pass "Artifact archiving is configured"

        # Check for fingerprinting
        if get_code_without_comments "$file" | grep -A 3 'archiveArtifacts' | grep -q 'fingerprint'; then
            log_pass "Artifact fingerprinting is enabled"
        else
            log_info "Best Practice" "Consider enabling fingerprinting for tracked artifacts"
        fi
    fi
}

# 11. Check for notifications
check_notifications() {
    local file=$1

    # Use get_code_without_comments to avoid matching patterns in comments
    if get_code_without_comments "$file" | grep -qE '(mail|emailext|slackSend|mattermostSend)'; then
        log_pass "Notifications are configured"
    else
        log_info "Configuration" "No notifications detected - consider adding for build failures"
    fi
}

# 12. Check for docker best practices
check_docker_practices() {
    local file=$1

    if grep -q 'docker' "$file"; then
        # Check for docker agent usage
        if grep -qE 'agent\s*{\s*docker' "$file"; then
            log_pass "Using Docker agents for consistent build environment"
        fi

        # Check for docker.image().inside() pattern
        if grep -q 'docker.image.*inside' "$file"; then
            log_pass "Using docker.inside() for build isolation"
        fi

        # Check for docker build without proper tagging
        if grep -q 'docker build' "$file" && ! grep -q '\-t ' "$file"; then
            log_warning "Docker" "Docker build without explicit tag - add -t for proper versioning"
        fi
    fi
}

# 13. Check for Kubernetes best practices
check_kubernetes_practices() {
    local file=$1

    if grep -qE '(kubernetes|podTemplate)' "$file"; then
        # Check for resource limits
        if grep -A 20 'podTemplate' "$file" | grep -qE '(limits|requests)'; then
            log_pass "Kubernetes pods have resource limits/requests"
        else
            log_warning "Kubernetes" "Pod template without resource limits - add for better resource management"
            log_warning "Kubernetes" "  → Prevents resource exhaustion on cluster"
        fi
    fi
}

# 14. Check for security best practices
check_security_practices() {
    local file=$1
    local security_score=0

    # Good: No hardcoded credentials
    if ! grep -qiE '(password|token|key)\s*=\s*["\047][a-zA-Z0-9]{8,}' "$file"; then
        ((security_score++))
    else
        log_error "Security" "Hardcoded credentials detected"
    fi

    # Good: Using credentials manager
    if grep -qE '(withCredentials|credentials\()' "$file"; then
        ((security_score++))
    fi

    # Good: Input validation for parameters
    if grep -q 'parameters' "$file"; then
        if grep -A 10 'parameters' "$file" | grep -qE '(defaultValue|choices)'; then
            ((security_score++))
        else
            log_info "Security" "Parameters without validation - add defaultValue or choices for safety"
        fi
    fi

    if [ $security_score -ge 2 ]; then
        log_pass "Good security practices detected"
    fi
}

# 15. Check for maintainability
check_maintainability() {
    local file=$1
    local line_count=$(wc -l < "$file" | tr -d ' ')

    if [ $line_count -gt 500 ]; then
        log_warning "Maintainability" "Pipeline is $line_count lines - consider breaking into shared libraries"
        log_warning "Maintainability" "  → Use @Library for reusable code"
    elif [ $line_count -gt 300 ]; then
        log_info "Maintainability" "Pipeline is $line_count lines - watch for complexity growth"
    else
        log_pass "Pipeline size is manageable ($line_count lines)"
    fi

    # Check for comments
    local comment_count=$(grep -cE '^\s*//' "$file" || true)
    if [ $comment_count -lt 3 ] && [ $line_count -gt 100 ]; then
        log_info "Maintainability" "Few comments detected - add comments for complex logic"
    fi
}

# Main validation function
check_best_practices() {
    local file=$1

    echo -e "${BLUE}=== Checking Jenkins Pipeline Best Practices ===${NC}"
    echo "File: $file"
    echo "Reference: https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/"
    echo ""

    # Run all checks (|| true prevents early exit on validation failures)
    check_combined_shell_commands "$file" || true
    check_agent_operations "$file" || true
    check_credential_management "$file" || true
    check_parallel_execution "$file" || true
    check_error_handling "$file" || true
    check_timeout "$file" || true
    check_workspace_cleanup "$file" || true
    check_build_triggers "$file" || true
    check_test_publishing "$file" || true
    check_artifact_archiving "$file" || true
    check_notifications "$file" || true
    check_docker_practices "$file" || true
    check_kubernetes_practices "$file" || true
    check_security_practices "$file" || true
    check_maintainability "$file" || true

    # Print results
    echo -e "${BLUE}=== Best Practices Report ===${NC}"
    echo ""

    if [ ${#PASS_MESSAGES[@]} -gt 0 ]; then
        echo -e "${GREEN}PASSED (${PASS}):${NC}"
        for msg in "${PASS_MESSAGES[@]}"; do
            echo -e "${GREEN}$msg${NC}"
        done
        echo ""
    fi

    if [ ${#ERROR_MESSAGES[@]} -gt 0 ]; then
        echo -e "${RED}CRITICAL ISSUES (${ERRORS}):${NC}"
        for msg in "${ERROR_MESSAGES[@]}"; do
            echo -e "${RED}$msg${NC}"
        done
        echo ""
    fi

    if [ ${#WARNING_MESSAGES[@]} -gt 0 ]; then
        echo -e "${YELLOW}IMPROVEMENTS RECOMMENDED (${WARNINGS}):${NC}"
        for msg in "${WARNING_MESSAGES[@]}"; do
            echo -e "${YELLOW}$msg${NC}"
        done
        echo ""
    fi

    if [ ${#INFO_MESSAGES[@]} -gt 0 ]; then
        echo -e "${BLUE}SUGGESTIONS (${INFO}):${NC}"
        for msg in "${INFO_MESSAGES[@]}"; do
            echo -e "${BLUE}$msg${NC}"
        done
        echo ""
    fi

    # Calculate score
    local total_checks=15
    local score=$(( (PASS * 100) / total_checks ))

    echo -e "${BLUE}=== Best Practices Score ===${NC}"
    echo -e "Score: ${score}% (${PASS}/${total_checks} checks passed)"
    echo ""

    if [ $score -ge 80 ]; then
        echo -e "${GREEN}Excellent! Your pipeline follows most best practices.${NC}"
    elif [ $score -ge 60 ]; then
        echo -e "${YELLOW}Good! Consider implementing suggested improvements.${NC}"
    elif [ $score -ge 40 ]; then
        echo -e "${YELLOW}Fair. Several important best practices are missing.${NC}"
    else
        echo -e "${RED}Needs improvement. Please review and implement best practices.${NC}"
    fi

    echo ""
    echo "For detailed best practices, see: $REFERENCES_DIR/best_practices.md"
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

check_best_practices "$JENKINSFILE"