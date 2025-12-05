#!/bin/bash

################################################################################
# Dockerfile Validator - Complete Lifecycle Management
#
# Single self-contained script that handles:
# - Tool installation (hadolint + Checkov in Python venvs)
# - Syntax validation (hadolint)
# - Security scanning (Checkov)
# - Best practices validation (custom checks)
# - Optimization analysis (custom checks)
# - Automatic cleanup on exit (success or failure)
#
# Usage: ./dockerfile-validate [Dockerfile]
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
DOCKERFILE="${1:-Dockerfile}"
VENV_BASE_DIR="${HOME}/.local/share/dockerfile-validator-temp"
HADOLINT_VENV="${VENV_BASE_DIR}/hadolint-venv"
CHECKOV_VENV="${VENV_BASE_DIR}/checkov-venv"
TEMP_INSTALL=false

# Environment variable to force temporary installation (for testing cleanup)
# Usage: FORCE_TEMP_INSTALL=true bash scripts/dockerfile-validate.sh Dockerfile
FORCE_TEMP_INSTALL="${FORCE_TEMP_INSTALL:-false}"

# Exit codes
EXIT_CODE=0

# Counters for custom checks
BP_ERRORS=0
BP_WARNINGS=0
BP_INFO=0

################################################################################
# Cleanup Function - Called on EXIT
################################################################################
cleanup() {
    local exit_code=$?

    if [ "$TEMP_INSTALL" = true ]; then
        echo ""
        echo -e "${YELLOW}Cleaning up temporary installation...${NC}"

        if [ -d "$VENV_BASE_DIR" ]; then
            rm -rf "$VENV_BASE_DIR"
            echo -e "${GREEN}✓ Removed temporary venvs${NC}"
        fi

        echo -e "${GREEN}✓ Cleanup complete${NC}"
    fi

    exit $exit_code
}

# Set trap for cleanup on any exit
trap cleanup EXIT INT TERM

################################################################################
# Tool Installation Functions
################################################################################

check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo -e "${RED}ERROR: Python 3 is required but not installed${NC}" >&2
        exit 2
    fi

    # Verify Python version (need 3.8+)
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$MAJOR" -lt 3 ] || ([ "$MAJOR" -eq 3 ] && [ "$MINOR" -lt 8 ]); then
        echo -e "${RED}ERROR: Python 3.8+ required (found $PYTHON_VERSION)${NC}" >&2
        exit 2
    fi
}

check_tools() {
    # If FORCE_TEMP_INSTALL is set, skip tool check and force installation
    if [ "$FORCE_TEMP_INSTALL" = "true" ]; then
        echo -e "${YELLOW}FORCE_TEMP_INSTALL=true: Forcing temporary tool installation for testing${NC}"
        return 1
    fi

    local hadolint_found=false
    local checkov_found=false

    # Check for hadolint (system-installed or from this script's temp venv)
    if command -v hadolint &> /dev/null; then
        HADOLINT_CMD="hadolint"
        hadolint_found=true
    elif [ -f "$HADOLINT_VENV/bin/hadolint" ]; then
        HADOLINT_CMD="$HADOLINT_VENV/bin/hadolint"
        hadolint_found=true
    fi

    # Check for Checkov (system-installed or from this script's temp venv)
    if command -v checkov &> /dev/null; then
        CHECKOV_CMD="checkov"
        checkov_found=true
    elif [ -f "$CHECKOV_VENV/bin/checkov" ]; then
        CHECKOV_CMD="$CHECKOV_VENV/bin/checkov"
        checkov_found=true
    fi

    # Return 0 if both found, 1 if need installation
    [ "$hadolint_found" = true ] && [ "$checkov_found" = true ]
}

install_hadolint() {
    echo -e "${BLUE}Installing hadolint...${NC}"

    mkdir -p "$HADOLINT_VENV"
    $PYTHON_CMD -m venv "$HADOLINT_VENV" 2>&1 | grep -v "upgrade pip" || true

    "$HADOLINT_VENV/bin/pip" install --quiet --upgrade pip
    "$HADOLINT_VENV/bin/pip" install --quiet hadolint-bin

    if "$HADOLINT_VENV/bin/hadolint" --version &> /dev/null; then
        HADOLINT_CMD="$HADOLINT_VENV/bin/hadolint"
        VERSION=$("$HADOLINT_VENV/bin/hadolint" --version | head -n1)
        echo -e "${GREEN}✓ hadolint installed: $VERSION${NC}"
    else
        echo -e "${RED}✗ hadolint installation failed${NC}" >&2
        exit 2
    fi
}

install_checkov() {
    echo -e "${BLUE}Installing Checkov...${NC}"

    mkdir -p "$CHECKOV_VENV"
    $PYTHON_CMD -m venv "$CHECKOV_VENV" 2>&1 | grep -v "upgrade pip" || true

    "$CHECKOV_VENV/bin/pip" install --quiet --upgrade pip
    "$CHECKOV_VENV/bin/pip" install --quiet checkov

    if "$CHECKOV_VENV/bin/checkov" --version &> /dev/null; then
        CHECKOV_CMD="$CHECKOV_VENV/bin/checkov"
        VERSION=$("$CHECKOV_VENV/bin/checkov" --version 2>&1)
        echo -e "${GREEN}✓ Checkov installed: $VERSION${NC}"
    else
        echo -e "${RED}✗ Checkov installation failed${NC}" >&2
        exit 2
    fi
}

install_tools() {
    echo -e "${YELLOW}${BOLD}Installing validation tools...${NC}"
    echo ""

    TEMP_INSTALL=true

    check_python
    install_hadolint
    install_checkov

    echo ""
}

################################################################################
# Dockerfile Preprocessing - Handle Multi-line Instructions
################################################################################

# Normalize Dockerfile by joining continuation lines (lines ending with \)
# This allows accurate counting of multi-line instructions
normalize_dockerfile() {
    local dockerfile="$1"
    # Use awk to join lines that end with backslash
    awk '
        /\\$/ {
            sub(/\\$/, "")
            printf "%s", $0
            next
        }
        { print }
    ' "$dockerfile"
}

################################################################################
# Validation Functions
################################################################################

run_hadolint() {
    echo -e "${CYAN}${BOLD}[1/4] Syntax Validation (hadolint)${NC}"
    echo "====================================="
    echo ""

    if $HADOLINT_CMD "$DOCKERFILE" 2>&1; then
        echo ""
        echo -e "${GREEN}✓ Syntax validation passed${NC}"
        return 0
    else
        local hadolint_exit=$?
        echo ""
        echo -e "${YELLOW}⚠ Syntax issues found${NC}"
        EXIT_CODE=1
        return $hadolint_exit
    fi
}

run_checkov() {
    echo -e "${CYAN}${BOLD}[2/4] Security Scan (Checkov)${NC}"
    echo "================================"
    echo ""

    if $CHECKOV_CMD -f "$DOCKERFILE" --framework dockerfile --compact 2>&1; then
        echo ""
        echo -e "${GREEN}✓ Security scan passed${NC}"
        return 0
    else
        local checkov_exit=$?
        echo ""
        echo -e "${YELLOW}⚠ Security issues found${NC}"
        EXIT_CODE=1
        return $checkov_exit
    fi
}

run_best_practices() {
    echo -e "${CYAN}${BOLD}[3/4] Best Practices Validation${NC}"
    echo "===================================="
    echo ""

    # Reset counters
    BP_ERRORS=0
    BP_WARNINGS=0
    BP_INFO=0

    # Create normalized version for accurate multi-line instruction counting
    NORMALIZED_CONTENT=$(normalize_dockerfile "$DOCKERFILE")

    # Check for :latest tag
    if grep -qE "^FROM[[:space:]]+[^[:space:]]+:latest" "$DOCKERFILE"; then
        echo -e "${YELLOW}[WARNING] Base image using :latest tag${NC}"
        echo "  → Use specific version tags for reproducibility"
        ((BP_WARNINGS++))
    fi

    # Check for USER directive
    if ! grep -q "^USER" "$DOCKERFILE"; then
        echo -e "${YELLOW}[WARNING] No USER directive - container will run as root${NC}"
        echo "  → Add 'USER <non-root-user>' before CMD/ENTRYPOINT"
        ((BP_WARNINGS++))
    else
        LAST_USER=$(grep "^USER" "$DOCKERFILE" | tail -n1 | awk '{print $2}')
        if [[ "$LAST_USER" == "root" ]] || [[ "$LAST_USER" == "0" ]]; then
            echo -e "${RED}[ERROR] Last USER directive sets user to root${NC}"
            echo "  → Container should not run as root user"
            ((BP_ERRORS++))
            EXIT_CODE=1
        fi
    fi

    # Check for HEALTHCHECK
    if ! grep -q "^HEALTHCHECK" "$DOCKERFILE"; then
        if grep -qE "^EXPOSE|CMD.*server|ENTRYPOINT.*server" "$DOCKERFILE"; then
            echo -e "${PURPLE}[INFO] No HEALTHCHECK defined for service container${NC}"
            echo "  → Consider adding HEALTHCHECK for monitoring"
            ((BP_INFO++))
        fi
    fi

    # Check RUN command efficiency (using normalized content for accurate counting)
    RUN_COUNT=$(echo "$NORMALIZED_CONTENT" | grep -c "^RUN" || echo "0")
    if [ "$RUN_COUNT" -gt "5" ]; then
        echo -e "${PURPLE}[INFO] High number of RUN commands ($RUN_COUNT)${NC}"
        echo "  → Consider combining related commands to reduce layers"
        ((BP_INFO++))
    fi

    # Check for apt-get cache cleanup (using normalized content)
    if echo "$NORMALIZED_CONTENT" | grep -q "^RUN.*apt-get install"; then
        if ! echo "$NORMALIZED_CONTENT" | grep -q "rm -rf /var/lib/apt/lists"; then
            echo -e "${YELLOW}[WARNING] apt-get used but cache not cleaned${NC}"
            echo "  → Add '&& rm -rf /var/lib/apt/lists/*' to same RUN"
            ((BP_WARNINGS++))
        fi
    fi

    # Check for apk --no-cache (using normalized content)
    if echo "$NORMALIZED_CONTENT" | grep -q "^RUN.*apk add"; then
        if ! echo "$NORMALIZED_CONTENT" | grep -qE "apk add --no-cache|apk add.*--no-cache"; then
            echo -e "${YELLOW}[WARNING] apk add without --no-cache flag${NC}"
            echo "  → Use 'apk add --no-cache' to avoid cache in image"
            ((BP_WARNINGS++))
        fi
    fi

    # Check for hardcoded secrets
    if grep -qiE "ENV.*(password|secret|api_key|token).*=" "$DOCKERFILE" || \
       grep -qiE "ARG.*(password|secret|api_key|token).*=" "$DOCKERFILE"; then
        echo -e "${RED}[ERROR] Potential hardcoded secrets in ENV/ARG${NC}"
        echo "  → Never hardcode secrets in Dockerfiles"
        ((BP_ERRORS++))
        EXIT_CODE=1
    fi

    # Check for poor COPY ordering (COPY . before dependency installation)
    # This hurts build cache efficiency - dependencies should be copied first
    COPY_ALL_LINE=$(echo "$NORMALIZED_CONTENT" | grep -n "^COPY \. " | head -1 | cut -d: -f1)
    if [ -n "$COPY_ALL_LINE" ]; then
        # Check if there's a RUN with package install AFTER the COPY .
        INSTALL_AFTER_COPY=false
        while IFS= read -r line; do
            LINE_NUM=$(echo "$line" | cut -d: -f1)
            if [ "$LINE_NUM" -gt "$COPY_ALL_LINE" ]; then
                if echo "$line" | grep -qiE "pip install|npm install|npm ci|yarn|go mod|apt-get install|apk add"; then
                    INSTALL_AFTER_COPY=true
                    break
                fi
            fi
        done <<< "$(echo "$NORMALIZED_CONTENT" | grep -n "^RUN")"

        if [ "$INSTALL_AFTER_COPY" = true ]; then
            echo -e "${YELLOW}[WARNING] COPY . appears before dependency installation${NC}"
            echo "  → Copy dependency files (package.json, requirements.txt) first for better cache"
            echo "  → Then install dependencies, then COPY . for source code"
            ((BP_WARNINGS++))
        fi
    fi

    echo ""
    echo "Best Practices Summary:"
    echo -e "  Errors:   ${RED}$BP_ERRORS${NC}"
    echo -e "  Warnings: ${YELLOW}$BP_WARNINGS${NC}"
    echo -e "  Info:     ${PURPLE}$BP_INFO${NC}"
    echo ""

    if [ $BP_ERRORS -eq 0 ] && [ $BP_WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ Best practices validation passed${NC}"
        return 0
    elif [ $BP_ERRORS -eq 0 ]; then
        echo -e "${YELLOW}⚠ Best practices completed with warnings${NC}"
        return 0
    else
        echo -e "${RED}✗ Best practices validation failed${NC}"
        return 1
    fi
}

run_optimization() {
    echo -e "${CYAN}${BOLD}[4/4] Optimization Analysis${NC}"
    echo "=============================="
    echo ""

    # Create normalized version for accurate multi-line instruction counting
    NORMALIZED_CONTENT=$(normalize_dockerfile "$DOCKERFILE")

    # Analyze base images
    BASE_IMAGES=$(grep "^FROM" "$DOCKERFILE" | awk '{print $2}' | sed 's/[[:space:]]*AS.*//')

    echo -e "${BLUE}Base Image Analysis:${NC}"
    for image in $BASE_IMAGES; do
        if echo "$image" | grep -qiE "ubuntu|debian|centos|fedora"; then
            echo -e "  ${PURPLE}[OPTIMIZATION] Consider Alpine alternative for: $image${NC}"
            echo "    → Alpine images are 10-100x smaller"
        fi
    done
    echo ""

    # Multi-stage analysis (using normalized content)
    FROM_COUNT=$(echo "$NORMALIZED_CONTENT" | grep -c "^FROM" || echo "0")

    echo -e "${BLUE}Build Structure:${NC}"
    if [ "$FROM_COUNT" -eq "1" ]; then
        if echo "$NORMALIZED_CONTENT" | grep -qE "apt-get install.*(gcc|make|build)" || \
           echo "$NORMALIZED_CONTENT" | grep -qE "apk add.*(gcc|make|build)"; then
            echo -e "  ${PURPLE}[OPTIMIZATION] Build tools detected in single-stage build${NC}"
            echo "    → Consider multi-stage build to exclude build tools from final image"
        fi
    else
        FINAL_FROM=$(echo "$NORMALIZED_CONTENT" | grep "^FROM" | tail -n1 | awk '{print $2}')
        if echo "$FINAL_FROM" | grep -qiE "distroless|alpine|scratch"; then
            echo -e "  ${GREEN}✓ Using minimal base for final stage: $FINAL_FROM${NC}"
        else
            echo -e "  ${PURPLE}[OPTIMIZATION] Final stage could use smaller base image${NC}"
            echo "    → Consider: alpine, distroless, or scratch"
        fi
    fi
    echo ""

    # Layer count (reuse RUN_COUNT from best practices if available, otherwise calculate)
    if [ -z "$RUN_COUNT" ]; then
        RUN_COUNT=$(echo "$NORMALIZED_CONTENT" | grep -c "^RUN" || echo "0")
    fi

    echo -e "${BLUE}Layer Optimization:${NC}"
    echo "  RUN commands: $RUN_COUNT"
    if [ "$RUN_COUNT" -gt "7" ]; then
        echo -e "  ${PURPLE}[OPTIMIZATION] Consider combining RUN commands${NC}"
        echo "    → Reduces layer count and image size"
    fi
    echo ""

    # .dockerignore check
    DOCKERFILE_DIR=$(dirname "$DOCKERFILE")
    if [ ! -f "$DOCKERFILE_DIR/.dockerignore" ]; then
        echo -e "${YELLOW}[INFO] No .dockerignore file found${NC}"
        echo "  → Create .dockerignore to optimize build context"
        echo ""
    fi

    echo -e "${GREEN}✓ Optimization analysis complete${NC}"
    return 0
}

################################################################################
# Main Execution
################################################################################

show_help() {
    cat << EOF
${BOLD}Dockerfile Validator - Complete Lifecycle${NC}

Validates Dockerfiles with automatic tool management and cleanup.

${BOLD}Usage:${NC}
    $(basename "$0") [Dockerfile]

${BOLD}Validation Stages:${NC}
    1. Syntax validation (hadolint)
    2. Security scanning (Checkov)
    3. Best practices validation
    4. Optimization analysis

${BOLD}Features:${NC}
    • Auto-installs tools if not found
    • Runs all validation stages
    • Auto-cleanup on exit

${BOLD}Examples:${NC}
    $(basename "$0")                    # Validate ./Dockerfile
    $(basename "$0") Dockerfile.prod    # Validate specific file

${BOLD}Exit Codes:${NC}
    0    All validations passed
    1    One or more validations failed
    2    Critical error

EOF
}

# Check for help
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

# Validate input
if [ ! -f "$DOCKERFILE" ]; then
    echo -e "${RED}ERROR: Dockerfile not found: $DOCKERFILE${NC}" >&2
    echo ""
    echo "Usage: $(basename "$0") [Dockerfile]"
    exit 2
fi

# Print header
echo ""
echo -e "${CYAN}${BOLD}========================================${NC}"
echo -e "${CYAN}${BOLD}  Dockerfile Validator${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"
echo ""
echo -e "${BOLD}Target:${NC} $DOCKERFILE"
echo -e "${BOLD}Date:${NC}   $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check and install tools if needed
if ! check_tools; then
    install_tools
fi

echo -e "${CYAN}${BOLD}Running Validations...${NC}"
echo ""

# Track results
HADOLINT_RESULT="SKIP"
CHECKOV_RESULT="SKIP"
BEST_PRACTICES_RESULT="SKIP"
OPTIMIZATION_RESULT="SKIP"

# Run all validations
run_hadolint && HADOLINT_RESULT="PASS" || HADOLINT_RESULT="FAIL"
echo ""

run_checkov && CHECKOV_RESULT="PASS" || CHECKOV_RESULT="FAIL"
echo ""

run_best_practices && BEST_PRACTICES_RESULT="PASS" || BEST_PRACTICES_RESULT="FAIL"
echo ""

run_optimization && OPTIMIZATION_RESULT="INFO"
echo ""

# Print summary
echo -e "${CYAN}${BOLD}========================================${NC}"
echo -e "${CYAN}${BOLD}  Validation Summary${NC}"
echo -e "${CYAN}${BOLD}========================================${NC}"
echo ""

# Print results
[ "$HADOLINT_RESULT" = "PASS" ] && echo -e "  Syntax (hadolint):     ${GREEN}✓ PASSED${NC}" || echo -e "  Syntax (hadolint):     ${RED}✗ FAILED${NC}"
[ "$CHECKOV_RESULT" = "PASS" ] && echo -e "  Security (Checkov):    ${GREEN}✓ PASSED${NC}" || echo -e "  Security (Checkov):    ${RED}✗ FAILED${NC}"
[ "$BEST_PRACTICES_RESULT" = "PASS" ] && echo -e "  Best Practices:        ${GREEN}✓ PASSED${NC}" || echo -e "  Best Practices:        ${RED}✗ FAILED${NC}"
echo -e "  Optimization:          ${BLUE}ℹ INFORMATIONAL${NC}"

echo ""
echo -e "${CYAN}${BOLD}========================================${NC}"
echo ""

# Overall result
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓ Overall Result: PASSED${NC}"
    echo ""
    echo "Your Dockerfile meets validation requirements."
else
    echo -e "${RED}${BOLD}✗ Overall Result: FAILED${NC}"
    echo ""
    echo "Please address the issues identified above."
fi

echo ""

# Exit (cleanup trap will run automatically)
exit $EXIT_CODE
