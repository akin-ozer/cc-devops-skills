#!/usr/bin/env bash

# Ansible Role Testing Script with Molecule
# Automatically installs molecule in temporary venv if not available

set -e

ROLE_DIR="$1"
SCENARIO="${2:-default}"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Usage check
if [ -z "$ROLE_DIR" ]; then
    echo "Usage: $0 <role-directory> [scenario]"
    echo ""
    echo "Arguments:"
    echo "  role-directory  Path to the Ansible role"
    echo "  scenario        Molecule scenario name (default: default)"
    exit 1
fi

if [ ! -d "$ROLE_DIR" ]; then
    echo -e "${COLOR_RED}Error: Role directory not found: $ROLE_DIR${COLOR_RESET}"
    exit 1
fi

# Get absolute path to role
ROLE_ABS_PATH=$(cd "$ROLE_DIR" && pwd)

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Ansible Role Testing with Molecule${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Role: $ROLE_ABS_PATH"
echo "Scenario: $SCENARIO"
echo ""

# Check if molecule is configured
if [ ! -d "$ROLE_ABS_PATH/molecule/$SCENARIO" ]; then
    echo -e "${COLOR_YELLOW}⚠ Molecule scenario '$SCENARIO' not found${COLOR_RESET}"
    echo ""
    echo "Available scenarios:"
    if [ -d "$ROLE_ABS_PATH/molecule" ]; then
        ls -1 "$ROLE_ABS_PATH/molecule/"
    else
        echo "  None - molecule not initialized"
    fi
    echo ""
    echo "Initialize molecule with:"
    echo "  cd $ROLE_ABS_PATH"
    echo "  molecule init scenario --driver-name docker"
    exit 1
fi

# Function to run molecule command
run_molecule() {
    if [ -n "$TEMP_VENV" ]; then
        # Using temporary venv
        "$TEMP_VENV/bin/molecule" "$@"
    else
        # Using system molecule
        molecule "$@"
    fi
}

# Check if molecule is available in system
TEMP_VENV=""
CLEANUP_VENV=0

if command -v molecule >/dev/null 2>&1; then
    echo -e "${COLOR_GREEN}✓ Using system molecule${COLOR_RESET}"
    echo ""
else
    echo -e "${COLOR_YELLOW}⚠ Molecule not found in system${COLOR_RESET}"
    echo "Creating temporary environment with molecule..."
    echo ""

    # Create temporary venv
    TEMP_VENV=$(mktemp -d -t ansible-molecule.XXXXXX)
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

    # Create venv and install molecule
    echo "Installing molecule and dependencies (this may take a minute)..."
    python3 -m venv "$TEMP_VENV" >/dev/null 2>&1

    # Activate venv and install
    source "$TEMP_VENV/bin/activate"

    # Install molecule with docker driver and ansible
    pip install --quiet --upgrade pip setuptools wheel
    pip install --quiet molecule molecule-docker ansible-core ansible-lint yamllint

    echo -e "${COLOR_GREEN}✓ Temporary molecule environment ready${COLOR_RESET}"
    echo ""
fi

cd "$ROLE_ABS_PATH"

# List molecule scenarios
echo -e "${COLOR_BLUE}Available Scenarios:${COLOR_RESET}"
run_molecule list -s "$SCENARIO"
echo ""

# Run molecule test
echo -e "${COLOR_BLUE}Running Molecule Test Sequence...${COLOR_RESET}"
echo ""

# Full test sequence with better error handling
STAGE_ERRORS=0

run_stage() {
    local stage=$1
    local description=$2

    echo -e "${COLOR_BLUE}[$stage] $description${COLOR_RESET}"
    echo "-----------------------------------"

    if run_molecule "$stage" -s "$SCENARIO"; then
        echo -e "${COLOR_GREEN}✓ $description completed${COLOR_RESET}"
        echo ""
        return 0
    else
        echo -e "${COLOR_RED}✗ $description failed${COLOR_RESET}"
        echo ""
        STAGE_ERRORS=$((STAGE_ERRORS + 1))
        return 1
    fi
}

# Run test stages
# Note: molecule lint was removed in v5+, linting is now done separately
# run_stage "lint" "Lint Check"
run_stage "syntax" "Syntax Check"
run_stage "create" "Create Test Instances"
run_stage "converge" "Run Role (Converge)"

# Idempotence test (critical for Ansible roles)
echo -e "${COLOR_BLUE}[Idempotence] Idempotence Test${COLOR_RESET}"
echo "-----------------------------------"
if run_molecule converge -s "$SCENARIO" 2>&1 | grep -q "changed=0"; then
    echo -e "${COLOR_GREEN}✓ Idempotence test passed${COLOR_RESET}"
else
    echo -e "${COLOR_RED}✗ Idempotence test failed - role is not idempotent${COLOR_RESET}"
    STAGE_ERRORS=$((STAGE_ERRORS + 1))
fi
echo ""

# Verify stage
run_stage "verify" "Verification Tests"

# Cleanup
echo -e "${COLOR_BLUE}[Cleanup] Destroying Test Instances${COLOR_RESET}"
echo "-----------------------------------"
run_molecule destroy -s "$SCENARIO" || true
echo ""

# Summary
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Test Summary${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

if [ $STAGE_ERRORS -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ All tests passed successfully!${COLOR_RESET}"
    echo ""
    echo "The role is ready for use."
    echo ""
    if [ -n "$TEMP_VENV" ]; then
        echo "Note: Molecule was installed in a temporary environment for this test."
        echo "To install permanently: pip install molecule molecule-docker"
    fi
    exit 0
else
    echo -e "${COLOR_RED}✗ Tests failed with $STAGE_ERRORS error(s)${COLOR_RESET}"
    echo ""
    echo "Debug with:"
    echo "  cd $ROLE_ABS_PATH"
    if [ -n "$TEMP_VENV" ]; then
        echo "  # Using temporary venv:"
        echo "  source $TEMP_VENV/bin/activate"
        echo "  molecule converge -s $SCENARIO  # Run without cleanup"
        echo "  molecule login -s $SCENARIO     # SSH into test instance"
        echo "  molecule verify -s $SCENARIO    # Re-run verification"
        echo "  molecule destroy -s $SCENARIO   # Clean up when done"
        echo "  deactivate"
        echo ""
        echo "Or install molecule permanently:"
        echo "  pip install molecule molecule-docker"
    else
        echo "  molecule converge -s $SCENARIO  # Run without cleanup"
        echo "  molecule login -s $SCENARIO     # SSH into test instance"
        echo "  molecule verify -s $SCENARIO    # Re-run verification"
        echo "  molecule destroy -s $SCENARIO   # Clean up when done"
    fi
    exit 1
fi
