#!/usr/bin/env bash

# Comprehensive Ansible Role Validation Script
# Automatically installs ansible and ansible-lint in temporary venv if not available

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
echo -e "${COLOR_BLUE}Ansible Role Validation${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Validating: $ROLE_ABS_PATH"
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

# Stage 1: Role Structure Check
echo -e "${COLOR_BLUE}[1/5] Role Structure Check${COLOR_RESET}"
echo "-----------------------------------"

REQUIRED_DIRS=("tasks")
RECOMMENDED_DIRS=("defaults" "handlers" "meta" "templates" "vars")
OPTIONAL_DIRS=("files" "molecule")

echo "Checking required directories..."
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$ROLE_ABS_PATH/$dir" ]; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $dir/"
    else
        echo -e "  ${COLOR_RED}✗${COLOR_RESET} $dir/ - REQUIRED"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "Checking recommended directories..."
for dir in "${RECOMMENDED_DIRS[@]}"; do
    if [ -d "$ROLE_ABS_PATH/$dir" ]; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $dir/"
    else
        echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $dir/ - recommended"
        WARNINGS=$((WARNINGS + 1))
    fi
done

echo ""
echo "Checking optional directories..."
for dir in "${OPTIONAL_DIRS[@]}"; do
    if [ -d "$ROLE_ABS_PATH/$dir" ]; then
        echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $dir/"
    fi
done

echo ""

# Check for main.yml files
echo "Checking main.yml files..."
for dir in tasks defaults handlers vars meta; do
    if [ -d "$ROLE_ABS_PATH/$dir" ]; then
        if [ -f "$ROLE_ABS_PATH/$dir/main.yml" ] || [ -f "$ROLE_ABS_PATH/$dir/main.yaml" ]; then
            echo -e "  ${COLOR_GREEN}✓${COLOR_RESET} $dir/main.yml exists"
        else
            echo -e "  ${COLOR_YELLOW}⚠${COLOR_RESET} $dir/main.yml not found"
            WARNINGS=$((WARNINGS + 1))
        fi
    fi
done

echo ""

# Stage 2: YAML Syntax Check
echo -e "${COLOR_BLUE}[2/5] YAML Syntax Check (yamllint)${COLOR_RESET}"
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

    # Find all YAML files in the role
    YAML_FILES=$(find "$ROLE_ABS_PATH" -type f \( -name "*.yml" -o -name "*.yaml" \) ! -path "*/.git/*" ! -path "*/molecule/*" 2>/dev/null || true)

    if [ -n "$YAML_FILES" ]; then
        YAML_ERRORS=0
        for file in $YAML_FILES; do
            if ! $YAMLLINT_CMD $YAMLLINT_CONFIG "$file" 2>&1 | grep -v "warning  found forbidden document start"; then
                YAML_ERRORS=$((YAML_ERRORS + 1))
            fi
        done

        if [ $YAML_ERRORS -eq 0 ]; then
            echo -e "${COLOR_GREEN}✓ YAML syntax check passed${COLOR_RESET}"
        else
            echo -e "${COLOR_RED}✗ YAML syntax check failed on $YAML_ERRORS file(s)${COLOR_RESET}"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${COLOR_YELLOW}⚠ No YAML files found in role${COLOR_RESET}"
    fi
else
    echo -e "${COLOR_YELLOW}⚠ yamllint not available - skipping YAML syntax check${COLOR_RESET}"
    WARNINGS=$((WARNINGS + 1))
fi

echo ""

# Stage 3: Ansible Syntax Check
echo -e "${COLOR_BLUE}[3/5] Ansible Syntax Check${COLOR_RESET}"
echo "-----------------------------------"

if [ $USE_SYSTEM_ANSIBLE -eq 1 ] || [ -n "$TEMP_VENV" ]; then
    # Create a temporary test playbook
    TEMP_PLAYBOOK=$(mktemp)
    cat > "$TEMP_PLAYBOOK" <<EOF
---
- hosts: localhost
  gather_facts: no
  roles:
    - role: test_role
EOF

    ROLE_NAME=$(basename "$ROLE_ABS_PATH")

    # Create temporary roles directory
    TEMP_DIR=$(mktemp -d)
    ln -s "$ROLE_ABS_PATH" "$TEMP_DIR/test_role"

    # Run syntax check
    if ANSIBLE_ROLES_PATH="$TEMP_DIR" run_ansible_playbook --syntax-check "$TEMP_PLAYBOOK" >/dev/null 2>&1; then
        echo -e "${COLOR_GREEN}✓ Ansible syntax check passed${COLOR_RESET}"
    else
        echo -e "${COLOR_RED}✗ Ansible syntax check failed${COLOR_RESET}"
        echo "  Run manually for details:"
        echo "  ANSIBLE_ROLES_PATH=$TEMP_DIR ansible-playbook --syntax-check $TEMP_PLAYBOOK"
        ERRORS=$((ERRORS + 1))
    fi

    # Cleanup
    rm -f "$TEMP_PLAYBOOK"
    rm -rf "$TEMP_DIR"
else
    echo -e "${COLOR_RED}✗ ansible-playbook not available${COLOR_RESET}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Stage 4: Ansible Lint
echo -e "${COLOR_BLUE}[4/5] Ansible Lint (ansible-lint)${COLOR_RESET}"
echo "-----------------------------------"

if [ $USE_SYSTEM_ANSIBLE_LINT -eq 1 ] || [ -n "$TEMP_VENV" ]; then
    # Check if custom config exists
    if [ -f "$SKILL_DIR/assets/.ansible-lint" ]; then
        ANSIBLE_LINT_CONFIG="-c $SKILL_DIR/assets/.ansible-lint"
    else
        ANSIBLE_LINT_CONFIG=""
    fi

    # Run ansible-lint on the role
    if run_ansible_lint $ANSIBLE_LINT_CONFIG "$ROLE_ABS_PATH" 2>&1; then
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

# Stage 5: Molecule Check (if configured)
echo -e "${COLOR_BLUE}[5/5] Molecule Configuration Check${COLOR_RESET}"
echo "-----------------------------------"

if [ -d "$ROLE_ABS_PATH/molecule" ]; then
    echo -e "${COLOR_GREEN}✓ Molecule directory found${COLOR_RESET}"

    # List scenarios
    SCENARIOS=$(ls -1 "$ROLE_ABS_PATH/molecule" 2>/dev/null || true)
    if [ -n "$SCENARIOS" ]; then
        echo "  Available scenarios:"
        for scenario in $SCENARIOS; do
            echo "    - $scenario"
        done

        echo ""
        echo "  Run tests with: bash scripts/test_role.sh $ROLE_ABS_PATH"
        echo "  (Molecule will be automatically installed in a temporary venv if needed)"
    fi
else
    echo -e "${COLOR_YELLOW}⚠ Molecule not configured for this role${COLOR_RESET}"
    echo "  Initialize with: cd $ROLE_ABS_PATH && molecule init scenario"
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
