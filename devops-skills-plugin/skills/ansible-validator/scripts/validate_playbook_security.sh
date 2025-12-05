#!/usr/bin/env bash

# Ansible Playbook Security Validation Script using Checkov
# Automatically installs checkov in temporary venv if not available

set -e

PLAYBOOK="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Usage check
if [ -z "$PLAYBOOK" ]; then
    echo "Usage: $0 <playbook.yml|playbook-directory>"
    exit 1
fi

if [ ! -f "$PLAYBOOK" ] && [ ! -d "$PLAYBOOK" ]; then
    echo -e "${COLOR_RED}Error: Playbook or directory not found: $PLAYBOOK${COLOR_RESET}"
    exit 1
fi

# Get absolute path
if [ -f "$PLAYBOOK" ]; then
    PLAYBOOK_ABS=$(cd "$(dirname "$PLAYBOOK")" && pwd)/$(basename "$PLAYBOOK")
    SCAN_TYPE="file"
else
    PLAYBOOK_ABS=$(cd "$PLAYBOOK" && pwd)
    SCAN_TYPE="directory"
fi

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Ansible Security Validation (Checkov)${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Scanning: $PLAYBOOK_ABS"
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

# Prepare checkov command based on scan type
if [ "$SCAN_TYPE" = "file" ]; then
    # For single file, scan the directory containing it
    SCAN_DIR=$(dirname "$PLAYBOOK_ABS")
    CHECKOV_ARGS=("-d" "$SCAN_DIR" "--framework" "ansible" "--compact" "--quiet")
else
    # For directory, scan it directly
    CHECKOV_ARGS=("-d" "$PLAYBOOK_ABS" "--framework" "ansible" "--compact" "--quiet")
fi

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
        echo -e "${COLOR_RED}✗ Security issues detected${COLOR_RESET}"
        echo ""
        echo "Failed Checks:"
        echo "$CHECKOV_OUTPUT" | grep -A 3 "Check:" | grep -v "^--$" || true
        echo ""
        echo "Common Security Issues:"
        echo "  - CKV_ANSIBLE_1: URI module disabling certificate validation"
        echo "  - CKV_ANSIBLE_2: get_url disabling certificate validation"
        echo "  - CKV_ANSIBLE_3: yum disabling certificate validation"
        echo "  - CKV_ANSIBLE_5: apt installing packages without GPG signature"
        echo "  - CKV2_ANSIBLE_1/2: Using HTTP instead of HTTPS"
        echo ""
        echo "For detailed policy documentation, visit:"
        echo "  https://www.checkov.io/5.Policy%20Index/ansible.html"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${COLOR_GREEN}✓ All security checks passed${COLOR_RESET}"
    fi
elif echo "$CHECKOV_OUTPUT" | grep -q "No Ansible files found"; then
    echo -e "${COLOR_YELLOW}⚠ No Ansible files found to scan${COLOR_RESET}"
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
    echo "Recommendations:"
    echo "  1. Review failed security checks above"
    echo "  2. Consult Checkov policy documentation for remediation"
    echo "  3. Use HTTPS URLs for downloads and enable certificate validation"
    echo "  4. Ensure package signatures are verified (GPG)"
    echo "  5. Follow security best practices from references/security_checklist.md"
    exit 1
fi