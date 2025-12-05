#!/usr/bin/env bash

# Comprehensive Ansible Playbook Validation Script
# Automatically installs ansible and ansible-lint in temporary venv if not available

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
    echo "Usage: $0 <playbook.yml>"
    exit 1
fi

if [ ! -f "$PLAYBOOK" ]; then
    echo -e "${COLOR_RED}Error: Playbook not found: $PLAYBOOK${COLOR_RESET}"
    exit 1
fi

# Get absolute path to playbook
PLAYBOOK_ABS=$(cd "$(dirname "$PLAYBOOK")" && pwd)/$(basename "$PLAYBOOK")

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Ansible Playbook Validation${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Validating: $PLAYBOOK_ABS"
echo ""

# Check for required tools and setup venv if needed
TEMP_VENV=""
CLEANUP_VENV=0
USE_SYSTEM_ANSIBLE=1
USE_SYSTEM_ANSIBLE_LINT=1

# Function to run ansible-playbook command
run_ansible_playbook() {
    if [ -n "$TEMP_VENV" ]; then
        "$TEMP_VENV/bin/ansible-playbook" "$@"
    else
        ansible-playbook "$@"
    fi
}

# Function to run ansible-lint command
run_ansible_lint() {
    if [ -n "$TEMP_VENV" ]; then
        "$TEMP_VENV/bin/ansible-lint" "$@"
    else
        ansible-lint "$@"
    fi
}

# Check if ansible-playbook is available
if ! command -v ansible-playbook >/dev/null 2>&1; then
    USE_SYSTEM_ANSIBLE=0
fi

# Check if ansible-lint is available
if ! command -v ansible-lint >/dev/null 2>&1; then
    USE_SYSTEM_ANSIBLE_LINT=0
fi

# Create temp venv if either tool is missing
if [ $USE_SYSTEM_ANSIBLE -eq 0 ] || [ $USE_SYSTEM_ANSIBLE_LINT -eq 0 ]; then
    echo -e "${COLOR_YELLOW}⚠ Some tools not found in system${COLOR_RESET}"

    if [ $USE_SYSTEM_ANSIBLE -eq 0 ]; then
        echo "  - ansible-playbook: not found"
    else
        echo "  - ansible-playbook: using system version"
    fi

    if [ $USE_SYSTEM_ANSIBLE_LINT -eq 0 ]; then
        echo "  - ansible-lint: not found"
    else
        echo "  - ansible-lint: using system version"
    fi

    echo ""
    echo "Creating temporary environment with missing tools..."
    echo ""

    # Create temporary venv
    TEMP_VENV=$(mktemp -d -t ansible-validator.XXXXXX)
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

    # Create venv and install tools
    echo "Installing ansible tools (this may take a minute)..."
    python3 -m venv "$TEMP_VENV" >/dev/null 2>&1

    # Activate venv and install
    source "$TEMP_VENV/bin/activate"

    # Install required tools
    pip install --quiet --upgrade pip setuptools wheel
    pip install --quiet ansible-core ansible-lint yamllint

    echo -e "${COLOR_GREEN}✓ Temporary environment ready${COLOR_RESET}"
    echo ""
else
    echo -e "${COLOR_GREEN}✓ Using system ansible tools${COLOR_RESET}"
    echo ""
fi

ERRORS=0
WARNINGS=0

# Stage 1: YAML Syntax Check
echo -e "${COLOR_BLUE}[1/3] YAML Syntax Check (yamllint)${COLOR_RESET}"
echo "-----------------------------------"

# yamllint - prefer system, fallback to venv
YAMLLINT_CMD=""
if command -v yamllint >/dev/null 2>&1; then
    YAMLLINT_CMD="yamllint"
elif [ -n "$TEMP_VENV" ] && [ -f "$TEMP_VENV/bin/yamllint" ]; then
    YAMLLINT_CMD="$TEMP_VENV/bin/yamllint"
fi

if [ -n "$YAMLLINT_CMD" ]; then
    # Check if custom config exists
    if [ -f "$SKILL_DIR/assets/.yamllint" ]; then
        YAMLLINT_CONFIG="-c $SKILL_DIR/assets/.yamllint"
    else
        YAMLLINT_CONFIG=""
    fi

    if $YAMLLINT_CMD $YAMLLINT_CONFIG "$PLAYBOOK_ABS"; then
        echo -e "${COLOR_GREEN}✓ YAML syntax check passed${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}✗ YAML syntax check failed${COLOR_RESET}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${COLOR_YELLOW}⚠ yamllint not available - skipping YAML syntax check${COLOR_RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Stage 2: Ansible Syntax Check
echo -e "${COLOR_BLUE}[2/3] Ansible Syntax Check${COLOR_RESET}"
echo "-----------------------------------"

if [ $USE_SYSTEM_ANSIBLE -eq 1 ] || [ -n "$TEMP_VENV" ]; then
    if run_ansible_playbook --syntax-check "$PLAYBOOK_ABS"; then
        echo -e "${COLOR_GREEN}✓ Ansible syntax check passed${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}✗ Ansible syntax check failed${COLOR_RESET}"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${COLOR_RED}✗ ansible-playbook not available${COLOR_RESET}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Stage 3: Ansible Lint
echo -e "${COLOR_BLUE}[3/3] Ansible Lint (ansible-lint)${COLOR_RESET}"
echo "-----------------------------------"

if [ $USE_SYSTEM_ANSIBLE_LINT -eq 1 ] || [ -n "$TEMP_VENV" ]; then
    # Check if custom config exists
    if [ -f "$SKILL_DIR/assets/.ansible-lint" ]; then
        ANSIBLE_LINT_CONFIG="-c $SKILL_DIR/assets/.ansible-lint"
    else
        ANSIBLE_LINT_CONFIG=""
    fi

    # Run ansible-lint and capture exit code
    if run_ansible_lint $ANSIBLE_LINT_CONFIG "$PLAYBOOK_ABS"; then
        echo -e "${COLOR_GREEN}✓ Ansible lint check passed${COLOR_RESET}"
    else
        LINT_EXIT=$?
        if [ $LINT_EXIT -eq 2 ]; then
            echo -e "${COLOR_RED}✗ Ansible lint found errors${COLOR_RESET}"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${COLOR_YELLOW}⚠ Ansible lint found warnings${COLOR_RESET}"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
else
    echo -e "${COLOR_YELLOW}⚠ ansible-lint not available - skipping lint check${COLOR_RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Validation Summary${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ All checks passed successfully!${COLOR_RESET}"
    echo ""
    echo "For best practices, see: $SKILL_DIR/references/best_practices.md"
    if [ -n "$TEMP_VENV" ]; then
        echo ""
        echo "Note: Some tools were installed in a temporary environment."
        echo "To install permanently: pip install ansible ansible-lint yamllint"
    fi
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${COLOR_YELLOW}⚠ Validation completed with $WARNINGS warning(s)${COLOR_RESET}"
    echo ""
    echo "For best practices, see: $SKILL_DIR/references/best_practices.md"
    if [ -n "$TEMP_VENV" ]; then
        echo ""
        echo "Note: Some tools were installed in a temporary environment."
        echo "To install permanently: pip install ansible ansible-lint yamllint"
    fi
    exit 0
else
    echo -e "${COLOR_RED}✗ Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${COLOR_RESET}"
    echo ""
    echo "For troubleshooting, see: $SKILL_DIR/references/common_errors.md"
    echo "For best practices, see: $SKILL_DIR/references/best_practices.md"
    exit 1
fi
