#!/usr/bin/env bash

# Ansible Role Security Validation Script using Checkov
# Automatically installs checkov in temporary venv if not available

set -e

ROLE_DIR="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Usage check
if [ -z "$ROLE_DIR" ]; then
    echo "Usage: $0 <role-directory>"
    exit 1
fi

if [ ! -d "$ROLE_DIR" ]; then
    echo -e "${COLOR_RED}Error: Role directory not found: $ROLE_DIR${COLOR_RESET}"
    exit 1
fi

# Get absolute path to role
ROLE_ABS_PATH=$(cd "$ROLE_DIR" && pwd)

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Ansible Role Security Validation${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Scanning: $ROLE_ABS_PATH"
echo ""

# Check for checkov and setup venv if needed
TEMP_VENV=""
CLEANUP_VENV=0
USE_SYSTEM_CHECKOV=1

# Function to run checkov command
run_checkov() {
    if [ -n "$TEMP_VENV" ]; then
        "$TEMP_VENV/bin/checkov" "$@"
    else
        checkov "$@"
    fi
}

# Check if checkov is available
if ! command -v checkov >/dev/null 2>&1; then
    USE_SYSTEM_CHECKOV=0
fi

# Create temp venv if checkov is missing
if [ $USE_SYSTEM_CHECKOV -eq 0 ]; then
    echo -e "${COLOR_YELLOW}⚠ checkov not found in system${COLOR_RESET}"
    echo ""
    echo "Creating temporary environment with checkov..."
    echo ""

    # Create temporary venv
    TEMP_VENV=$(mktemp -d -t checkov-validator.XXXXXX)
    CLEANUP_VENV=1

    # Setup cleanup trap
    cleanup() {
        if [ $CLEANUP_VENV -eq 1 ] && [ -n "$TEMP_VENV" ]; then
            echo ""
            echo "Cleaning up temporary environment..."
            rm -rf "$TEMP_VENV"
        fi
    }
    trap cleanup EXIT INT TERM

    # Create venv and install checkov
    echo "Installing checkov (this may take a minute)..."
    python3 -m venv "$TEMP_VENV" >/dev/null 2>&1

    # Activate venv and install
    source "$TEMP_VENV/bin/activate"

    # Install checkov
    pip install --quiet --upgrade pip setuptools wheel
    pip install --quiet checkov

    echo -e "${COLOR_GREEN}✓ Temporary environment ready${COLOR_RESET}"
    echo ""
else
    echo -e "${COLOR_GREEN}✓ Using system checkov${COLOR_RESET}"
    echo ""
fi

ERRORS=0
WARNINGS=0

# Security Scan with Checkov
echo -e "${COLOR_BLUE}[1/1] Security Scan (Checkov)${COLOR_RESET}"
echo "-----------------------------------"

# Run checkov on the role directory
CHECKOV_ARGS=("-d" "$ROLE_ABS_PATH" "--framework" "ansible" "--compact" "--quiet")

# Run checkov and capture output
if CHECKOV_OUTPUT=$(run_checkov "${CHECKOV_ARGS[@]}" 2>&1); then
    CHECKOV_EXIT=0
else
    CHECKOV_EXIT=$?
fi

# Parse checkov output
if echo "$CHECKOV_OUTPUT" | grep -q "Passed checks:"; then
    # Extract statistics (macOS compatible - using awk instead of grep -P)
    PASSED=$(echo "$CHECKOV_OUTPUT" | grep "Passed checks:" | awk -F': ' '{print $2}' | awk -F',' '{print $1}' || echo "0")
    FAILED=$(echo "$CHECKOV_OUTPUT" | grep "Failed checks:" | awk -F': ' '{print $2}' | awk -F',' '{print $1}' || echo "0")
    SKIPPED=$(echo "$CHECKOV_OUTPUT" | grep "Skipped checks:" | awk -F': ' '{print $2}' | awk -F',' '{print $1}' || echo "0")

    echo -e "Security Scan Results:"
    echo -e "  ${COLOR_GREEN}Passed:${COLOR_RESET}  $PASSED checks"
    echo -e "  ${COLOR_RED}Failed:${COLOR_RESET}  $FAILED checks"
    echo -e "  ${COLOR_YELLOW}Skipped:${COLOR_RESET} $SKIPPED checks"
    echo ""

    if [ "$FAILED" -gt 0 ]; then
        echo -e "${COLOR_RED}✗ Security issues detected in role${COLOR_RESET}"
        echo ""
        echo "Failed Checks:"
        echo "$CHECKOV_OUTPUT" | grep -A 3 "Check:" | grep -v "^--$" || true
        echo ""
        echo "Common Security Issues in Roles:"
        echo "  - Certificate validation disabled in uri, get_url, yum modules"
        echo "  - Using HTTP instead of HTTPS for downloads"
        echo "  - Installing packages without GPG signature verification"
        echo "  - Insecure privilege escalation patterns"
        echo "  - Missing error handling in critical tasks"
        echo ""
        echo "Recommendations:"
        echo "  1. Enable SSL/TLS certificate validation in all modules"
        echo "  2. Use HTTPS URLs for all downloads and package repositories"
        echo "  3. Verify GPG signatures for packages (apt, yum, dnf)"
        echo "  4. Implement proper error handling with block/rescue"
        echo "  5. Follow principle of least privilege for become/sudo"
        echo ""
        echo "For detailed policy documentation, visit:"
        echo "  https://www.checkov.io/5.Policy%20Index/ansible.html"
        echo ""
        echo "For security best practices, see:"
        echo "  $SKILL_DIR/references/security_checklist.md"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${COLOR_GREEN}✓ All security checks passed${COLOR_RESET}"
    fi
elif echo "$CHECKOV_OUTPUT" | grep -q "No Ansible files found"; then
    echo -e "${COLOR_YELLOW}⚠ No Ansible files found in role${COLOR_RESET}"
    echo "  Make sure the role has tasks/ directory with YAML files"
    WARNINGS=$((WARNINGS + 1))
else
    echo -e "${COLOR_RED}✗ Checkov scan failed${COLOR_RESET}"
    echo "$CHECKOV_OUTPUT"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Security Validation Summary${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ No security issues detected!${COLOR_RESET}"
    echo ""
    echo "The role follows security best practices."
    if [ -n "$TEMP_VENV" ]; then
        echo ""
        echo "Note: checkov was installed in a temporary environment."
        echo "To install permanently: pip3 install checkov"
    fi
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${COLOR_YELLOW}⚠ Scan completed with $WARNINGS warning(s)${COLOR_RESET}"
    if [ -n "$TEMP_VENV" ]; then
        echo ""
        echo "Note: checkov was installed in a temporary environment."
        echo "To install permanently: pip3 install checkov"
    fi
    exit 0
else
    echo -e "${COLOR_RED}✗ Security validation failed with $FAILED security issue(s)${COLOR_RESET}"
    echo ""
    echo "Next Steps:"
    echo "  1. Review the failed checks listed above"
    echo "  2. Update role tasks to address security issues"
    echo "  3. Re-run this security scan to verify fixes"
    echo "  4. Run full validation: bash scripts/validate_role.sh $ROLE_ABS_PATH"
    exit 1
fi