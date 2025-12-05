#!/bin/bash

# Common Validation Functions
# Shared validation functions for both Declarative and Scripted pipelines

# Note: We use set -u (undefined variable check) but not -e (exit on error)
# because grep returns exit code 1 when no match is found, which would cause
# premature script exit in conditional statements
set -uo pipefail

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

# Detect pipeline type
detect_pipeline_type() {
    local file=$1

    # Remove comments and empty lines
    local first_meaningful=$(grep -v '^\s*//' "$file" | grep -v '^\s*$' | head -1)

    if echo "$first_meaningful" | grep -q '^\s*pipeline\s*{'; then
        echo "declarative"
    elif echo "$first_meaningful" | grep -qE '^\s*node\s*(\(|{)'; then
        echo "scripted"
    elif grep -q '^\s*pipeline\s*{' "$file"; then
        echo "declarative"
    elif grep -qE '^\s*node\s*(\(|{)' "$file"; then
        echo "scripted"
    else
        echo "unknown"
    fi
}

# Check for hardcoded credentials
check_credentials() {
    local file=$1
    local line_num=0

    echo -e "${BLUE}=== Checking for Hardcoded Credentials ===${NC}"

    while IFS= read -r line; do
        ((++line_num))

        # Skip comments
        if echo "$line" | grep -qE '^\s*//'; then
            continue
        fi

        # Skip lines that are just comment markers in multi-line comments
        if echo "$line" | grep -qE '^\s*\*'; then
            continue
        fi

        # ============================================
        # PASSWORD DETECTION
        # ============================================

        # Check for password variable assignments: password = "value"
        if echo "$line" | grep -qiE '(password|passwd|pwd)\s*=\s*["\047]' && ! echo "$line" | grep -qi 'credentials'; then
            log_error "$line_num" "Potential hardcoded password detected"
            log_error "$line_num" "  → Use credentials() or withCredentials instead"
        fi

        # Check for command-line password flags: -p password, --password=secret
        # Look for -p followed by a non-variable value (not starting with $)
        # Exclude common false positives: mkdir -p, cp -p, tar -p, install -p, etc.
        if echo "$line" | grep -qiE '\s-p\s+[a-zA-Z0-9_]+' && ! echo "$line" | grep -qE '\s-p\s+\$'; then
            # Skip common commands that use -p for other purposes
            if ! echo "$line" | grep -qiE '(mkdir|cp|tar|install|rsync|scp|chmod)\s+-p'; then
                log_error "$line_num" "Password passed as command-line argument (-p)"
                log_error "$line_num" "  → Use withCredentials to inject secrets securely"
            fi
        fi

        # Check for --password flag with value
        if echo "$line" | grep -qiE -e '--password[=\s]+[a-zA-Z0-9_]+' && ! echo "$line" | grep -qE '\$'; then
            log_error "$line_num" "Password passed as command-line argument (--password)"
            log_error "$line_num" "  → Use withCredentials to inject secrets securely"
        fi

        # ============================================
        # API KEY / TOKEN DETECTION
        # ============================================

        # Check for API key variable assignments
        if echo "$line" | grep -qiE '(api[_-]?key|apikey)\s*=\s*["\047]' && ! echo "$line" | grep -qi 'credentials'; then
            log_error "$line_num" "Potential hardcoded API key detected"
            log_error "$line_num" "  → Use credentials() or withCredentials instead"
        fi

        # Check for token/secret variable assignments with long values
        if echo "$line" | grep -qiE '(token|secret)\s*=\s*["\047][a-zA-Z0-9]{20,}'; then
            log_warning "$line_num" "Potential hardcoded token/secret detected"
            log_warning "$line_num" "  → Use Jenkins Credentials Manager"
        fi

        # ============================================
        # BEARER TOKEN / AUTH HEADER DETECTION
        # ============================================

        # Check for Bearer tokens in Authorization headers
        if echo "$line" | grep -qiE 'Bearer\s+[a-zA-Z0-9_.-]{10,}' && ! echo "$line" | grep -qE '\$'; then
            log_error "$line_num" "Hardcoded Bearer token detected"
            log_error "$line_num" "  → Use withCredentials for token management"
        fi

        # Check for Basic auth with inline credentials (base64 or plain)
        if echo "$line" | grep -qiE 'Basic\s+[a-zA-Z0-9+/=]{10,}' && ! echo "$line" | grep -qE '\$'; then
            log_error "$line_num" "Hardcoded Basic auth credentials detected"
            log_error "$line_num" "  → Use withCredentials([usernamePassword(...)]) instead"
        fi

        # Check for X-API-Key, X-Auth-Token, and similar headers with inline values
        if echo "$line" | grep -qiE '(X-API-Key|X-Auth-Token|X-Access-Token|Authorization):\s*[a-zA-Z0-9_.-]{8,}' && ! echo "$line" | grep -qE '\$'; then
            log_warning "$line_num" "Hardcoded auth header value detected"
            log_warning "$line_num" "  → Use withCredentials for secure header injection"
        fi

        # ============================================
        # CLOUD PROVIDER CREDENTIALS
        # ============================================

        # Check for AWS Access Key IDs
        if echo "$line" | grep -qE 'AKIA[0-9A-Z]{16}'; then
            log_error "$line_num" "AWS Access Key ID detected - NEVER hardcode AWS credentials!"
            log_error "$line_num" "  → Use withCredentials or AWS credentials plugin"
        fi

        # Check for AWS Secret Access Keys (40 char base64-like string after aws_secret)
        if echo "$line" | grep -qiE 'aws_secret[_-]?(access[_-]?key)?\s*=\s*["\047][A-Za-z0-9/+=]{40}'; then
            log_error "$line_num" "AWS Secret Access Key detected"
            log_error "$line_num" "  → Use withCredentials or AWS credentials plugin"
        fi

        # Check for Azure credentials patterns
        if echo "$line" | grep -qiE '(azure[_-]?client[_-]?secret|azure[_-]?tenant)\s*=\s*["\047][a-zA-Z0-9-]{20,}'; then
            log_error "$line_num" "Azure credential detected"
            log_error "$line_num" "  → Use Azure Credentials plugin with withCredentials"
        fi

        # Check for GCP service account key indicators
        if echo "$line" | grep -qE '"type"\s*:\s*"service_account"'; then
            log_error "$line_num" "GCP service account key detected"
            log_error "$line_num" "  → Use GCP Credentials plugin or secret file credentials"
        fi

        # ============================================
        # VERSION CONTROL TOKENS
        # ============================================

        # Check for GitHub tokens (ghp_, gho_, ghu_, ghs_, ghr_)
        if echo "$line" | grep -qE 'gh[pousr]_[a-zA-Z0-9]{36,}'; then
            log_error "$line_num" "GitHub token detected"
            log_error "$line_num" "  → Use credentials() with secret text"
        fi

        # Check for GitLab tokens (glpat-)
        if echo "$line" | grep -qE 'glpat-[a-zA-Z0-9_-]{20,}'; then
            log_error "$line_num" "GitLab personal access token detected"
            log_error "$line_num" "  → Use credentials() with secret text"
        fi

        # Check for Bitbucket app passwords
        if echo "$line" | grep -qiE 'bitbucket.*["\047][a-zA-Z0-9]{20,}["\047]'; then
            log_warning "$line_num" "Potential Bitbucket credential detected"
            log_warning "$line_num" "  → Use credentials() with username/password"
        fi

        # ============================================
        # DOCKER / REGISTRY CREDENTIALS
        # ============================================

        # Check for docker login with inline password
        if echo "$line" | grep -qiE 'docker\s+login.*-p\s+[^\$]' && ! echo "$line" | grep -qE '\$'; then
            log_error "$line_num" "Docker login with hardcoded password"
            log_error "$line_num" "  → Use withCredentials([usernamePassword(credentialsId: 'docker-creds', ...)])"
        fi

        # Check for docker login with --password
        if echo "$line" | grep -qiE 'docker\s+login.*--password[=\s]+[a-zA-Z0-9]' && ! echo "$line" | grep -qE '\$'; then
            log_error "$line_num" "Docker login with hardcoded password"
            log_error "$line_num" "  → Use docker.withRegistry() with credentials"
        fi

        # ============================================
        # SSH / PRIVATE KEY DETECTION
        # ============================================

        # Check for private key content (use -e to avoid -- being interpreted as option)
        if echo "$line" | grep -qE -e 'BEGIN.*(RSA\s+)?PRIVATE\s+KEY'; then
            log_error "$line_num" "Private key content detected in pipeline"
            log_error "$line_num" "  → Use SSH credentials in Jenkins Credentials Manager"
        fi

        # Check for SSH key file paths with hardcoded values
        if echo "$line" | grep -qiE 'ssh.*-i\s+["\047]?(/[^\$]+|~[^\$]+)["\047]?' && ! echo "$line" | grep -qE '\$'; then
            log_warning "$line_num" "Hardcoded SSH key path detected"
            log_warning "$line_num" "  → Use sshUserPrivateKey credentials"
        fi

        # ============================================
        # DATABASE CREDENTIALS
        # ============================================

        # Check for database connection strings with credentials
        if echo "$line" | grep -qiE '(mysql|postgresql|postgres|mongodb|redis|jdbc)://[a-zA-Z0-9_]+:[a-zA-Z0-9_]+@'; then
            log_error "$line_num" "Database connection string with embedded credentials"
            log_error "$line_num" "  → Use withCredentials to inject database credentials"
        fi

        # Check for database password parameters
        if echo "$line" | grep -qiE '(db[_-]?pass|database[_-]?password|mysql[_-]?pwd)\s*=\s*["\047][a-zA-Z0-9]'; then
            log_error "$line_num" "Hardcoded database password"
            log_error "$line_num" "  → Use credentials() or withCredentials"
        fi

        # ============================================
        # GENERIC PATTERNS
        # ============================================

        # Check for common credential variable names with suspicious values
        if echo "$line" | grep -qiE '(username|user)\s*=\s*["\047](admin|root|sa|administrator)'; then
            log_warning "$line_num" "Hardcoded username detected - consider using credentials"
        fi

        # Check for slack/webhook tokens
        if echo "$line" | grep -qE 'xox[baprs]-[0-9]{10,13}-[0-9]{10,13}-[a-zA-Z0-9]{24}'; then
            log_error "$line_num" "Slack token detected"
            log_error "$line_num" "  → Use credentials() with secret text"
        fi

        # Check for generic webhook URLs with tokens
        if echo "$line" | grep -qiE 'hooks\.(slack|discord)\.com/services/[A-Z0-9/]+'; then
            log_warning "$line_num" "Webhook URL with token detected"
            log_warning "$line_num" "  → Store webhook URL in credentials"
        fi

        # Check for npm tokens
        if echo "$line" | grep -qE 'npm_[a-zA-Z0-9]{36}'; then
            log_error "$line_num" "NPM token detected"
            log_error "$line_num" "  → Use credentials() with secret text"
        fi

        # Check for PyPI tokens
        if echo "$line" | grep -qE 'pypi-[a-zA-Z0-9_-]{50,}'; then
            log_error "$line_num" "PyPI token detected"
            log_error "$line_num" "  → Use credentials() with secret text"
        fi

        # Check for base64 encoded credentials (common mistake) - long base64 strings
        if echo "$line" | grep -qE '["\047][A-Za-z0-9+/]{40,}={0,2}["\047]'; then
            log_info "$line_num" "Potential base64 encoded value - ensure this is not a credential"
        fi

        # Check for hex-encoded secrets (32+ hex chars often indicate secrets)
        if echo "$line" | grep -qE '["\047][a-fA-F0-9]{32,}["\047]' && ! echo "$line" | grep -qiE '(commit|sha|hash|checksum|md5|sha1|sha256)'; then
            log_info "$line_num" "Long hex string detected - verify this is not a secret"
        fi

    done < "$file"

    echo ""
}

# Check variable usage
check_variable_usage() {
    local file=$1
    local line_num=0

    echo -e "${BLUE}=== Checking Variable Usage ===${NC}"

    declare -A defined_vars
    declare -A used_vars

    while IFS= read -r line; do
        ((++line_num))

        # Skip comments
        if echo "$line" | grep -qE '^\s*//'; then
            continue
        fi

        # Track variable definitions
        if echo "$line" | grep -qE '(def|String|Integer|Boolean)\s+[a-zA-Z_][a-zA-Z0-9_]*\s*='; then
            local var_name=$(echo "$line" | grep -oE '[a-zA-Z_][a-zA-Z0-9_]*\s*=' | sed 's/\s*=//')
            defined_vars["$var_name"]=$line_num
        fi

        # Track variable usage (simple heuristic)
        if echo "$line" | grep -qE '\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?'; then
            local vars=$(echo "$line" | grep -oE '\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?' | sed 's/[\${}]//g')
            for var in $vars; do
                used_vars["$var"]=$line_num
            done
        fi

        # Check for undefined variables being used
        if echo "$line" | grep -qE '\$[a-zA-Z_][a-zA-Z0-9_]*' && ! echo "$line" | grep -qE '(def|String|params\.|env\.)'; then
            local var=$(echo "$line" | grep -oE '\$[a-zA-Z_][a-zA-Z0-9_]*' | sed 's/\$//' | head -1)
            if [[ ! -v defined_vars["$var"] ]] && [[ "$var" != "WORKSPACE" ]] && [[ "$var" != "BUILD_NUMBER" ]] && [[ "$var" != "JOB_NAME" ]]; then
                log_info "$line_num" "Variable '\$$var' used but not explicitly defined - ensure it's set by environment"
            fi
        fi
    done < "$file"

    echo ""
}

# Detect plugin usage
detect_plugins() {
    local file=$1

    echo -e "${BLUE}=== Detecting Plugin Usage ===${NC}"

    declare -A plugins

    # Common plugin steps
    local plugin_patterns=(
        "docker\."
        "kubernetes\."
        "withCredentials"
        "git "
        "checkout"
        "junit"
        "archiveArtifacts"
        "publishHTML"
        "mail"
        "emailext"
        "slackSend"
        "build job:"
        "input "
        "timeout"
        "retry"
        "script"
    )

    for pattern in "${plugin_patterns[@]}"; do
        if grep -q "$pattern" "$file"; then
            local plugin_name=$(echo "$pattern" | sed 's/[\.\\].*$//' | sed 's/ $//')
            plugins["$plugin_name"]=1
        fi
    done

    if [ ${#plugins[@]} -gt 0 ]; then
        echo "Plugins detected:"
        for plugin in "${!plugins[@]}"; do
            echo "  - $plugin"
        done
    else
        echo "No common plugins detected"
    fi

    echo ""
}

# Check for multiple consecutive sh/bat steps
check_multiple_sh_steps() {
    local file=$1
    local line_num=0
    local consecutive_sh=0
    local first_sh_line=0

    echo -e "${BLUE}=== Checking for Multiple Shell Steps ===${NC}"

    while IFS= read -r line; do
        ((++line_num))

        # Check for sh/bat steps
        if echo "$line" | grep -qE '^\s*(sh|bat)\s+["\047]' || echo "$line" | grep -qE '^\s*(sh|bat)\s*\('; then
            if [ $consecutive_sh -eq 0 ]; then
                first_sh_line=$line_num
            fi
            ((consecutive_sh++))
        else
            # Not a sh/bat line
            if [ $consecutive_sh -gt 2 ]; then
                log_warning "$first_sh_line" "Found $consecutive_sh consecutive sh/bat steps"
                log_warning "$first_sh_line" "  → Combine into single sh step with triple-quoted string (sh '''...''')"
                log_warning "$first_sh_line" "  → See: references/best_practices.md#combine-shell-commands"
            fi
            consecutive_sh=0
        fi
    done < "$file"

    # Check at end of file
    if [ $consecutive_sh -gt 2 ]; then
        log_warning "$first_sh_line" "Found $consecutive_sh consecutive sh/bat steps"
        log_warning "$first_sh_line" "  → Combine into single sh step with triple-quoted string"
    fi

    echo ""
}

# Check for timeout usage
check_timeout_usage() {
    local file=$1

    echo -e "${BLUE}=== Checking Timeout Configuration ===${NC}"

    if ! grep -qE '(timeout|Timeout)' "$file"; then
        log_info 1 "No timeout configuration found - consider adding timeout to prevent hung builds"
        log_info 1 "  → Declarative: options { timeout(time: 1, unit: 'HOURS') }"
        log_info 1 "  → Scripted: timeout(time: 1, unit: 'HOURS') { ... }"
    fi

    echo ""
}

# Check for proper workspace cleanup
check_workspace_cleanup() {
    local file=$1

    echo -e "${BLUE}=== Checking Workspace Cleanup ===${NC}"

    if ! grep -qE '(cleanWs|deleteDir|ws)' "$file"; then
        log_info 1 "No workspace cleanup detected - consider cleaning workspace for reproducible builds"
        log_info 1 "  → Add cleanWs() in post section or use deleteDir()"
    fi

    echo ""
}

# Print validation results
print_results() {
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

# Main function - run all common checks
run_common_checks() {
    local file=$1

    echo -e "${BLUE}=== Running Common Validation Checks ===${NC}"
    echo "File: $file"
    echo ""

    check_credentials "$file" || true
    check_variable_usage "$file" || true
    detect_plugins "$file" || true
    check_multiple_sh_steps "$file" || true
    check_timeout_usage "$file" || true
    check_workspace_cleanup "$file" || true

    print_results
}

# If script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    if [ $# -lt 2 ]; then
        echo "Usage: $0 <command> <jenkinsfile>"
        echo "Commands:"
        echo "  detect_type       - Detect pipeline type (declarative/scripted)"
        echo "  check_credentials - Check for hardcoded credentials"
        echo "  check_all        - Run all common validation checks"
        exit 1
    fi

    COMMAND=$1
    JENKINSFILE=$2

    if [ ! -f "$JENKINSFILE" ]; then
        echo -e "${RED}Error: File '$JENKINSFILE' not found${NC}"
        exit 1
    fi

    case "$COMMAND" in
        detect_type)
            TYPE=$(detect_pipeline_type "$JENKINSFILE")
            echo "Pipeline type: $TYPE"
            ;;
        check_credentials)
            check_credentials "$JENKINSFILE"
            print_results
            ;;
        check_all)
            run_common_checks "$JENKINSFILE"
            ;;
        *)
            echo "Unknown command: $COMMAND"
            exit 1
            ;;
    esac
fi
