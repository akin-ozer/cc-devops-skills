#!/usr/bin/env bash

#
# GitLab CI/CD Validator - Main Orchestrator Script
#
# This script runs all validation checks on GitLab CI/CD configuration files:
# 1. Syntax validation (YAML + GitLab CI schema)
# 2. Best practices check
# 3. Security scanning
#
# Usage: validate_gitlab_ci.sh <gitlab-ci.yml> [options]
#
# Options:
#   --syntax-only      Run only syntax validation
#   --best-practices   Run only best practices check
#   --security-only    Run only security scan
#   --no-best-practices  Skip best practices check
#   --no-security      Skip security scan
#   --strict           Exit with error on any warnings
#   --json             Output results in JSON format
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
RUN_SYNTAX=true
RUN_BEST_PRACTICES=true
RUN_SECURITY=true
RUN_TEST=false
STRICT_MODE=false
JSON_OUTPUT=false

# Parse arguments
FILE_PATH=""

usage() {
    echo "Usage: $0 <gitlab-ci.yml> [options]"
    echo ""
    echo "Options:"
    echo "  --syntax-only           Run only syntax validation"
    echo "  --best-practices        Run only best practices check"
    echo "  --security-only         Run only security scan"
    echo "  --test-only             Run only local pipeline testing with gitlab-ci-local"
    echo "  --no-best-practices     Skip best practices check"
    echo "  --no-security           Skip security scan"
    echo "  --strict                Exit with error on any warnings"
    echo "  --json                  Output results in JSON format"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 .gitlab-ci.yml"
    echo "  $0 .gitlab-ci.yml --syntax-only"
    echo "  $0 .gitlab-ci.yml --no-security"
    echo "  $0 .gitlab-ci.yml --strict"
    echo "  $0 .gitlab-ci.yml --test-only"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            ;;
        --syntax-only)
            RUN_BEST_PRACTICES=false
            RUN_SECURITY=false
            shift
            ;;
        --best-practices)
            RUN_SYNTAX=false
            RUN_SECURITY=false
            shift
            ;;
        --security-only)
            RUN_SYNTAX=false
            RUN_BEST_PRACTICES=false
            shift
            ;;
        --test-only)
            RUN_SYNTAX=false
            RUN_BEST_PRACTICES=false
            RUN_SECURITY=false
            RUN_TEST=true
            shift
            ;;
        --no-best-practices)
            RUN_BEST_PRACTICES=false
            shift
            ;;
        --no-security)
            RUN_SECURITY=false
            shift
            ;;
        --strict)
            STRICT_MODE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            if [ -z "$FILE_PATH" ]; then
                FILE_PATH="$1"
            else
                echo "Error: Multiple file paths provided"
                usage
            fi
            shift
            ;;
    esac
done

# Validate file path
if [ -z "$FILE_PATH" ]; then
    echo "Error: No file path provided"
    usage
fi

if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File not found: $FILE_PATH"
    exit 1
fi

# Check for Python (PyYAML is handled by wrapper script)
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed"
    echo "Install with: brew install python3"
    exit 1
fi

# Python wrapper script for handling venv
PYTHON_WRAPPER="$SCRIPT_DIR/python_wrapper.sh"

# Create temporary files for JSON output (if needed)
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'gitlab-ci-validator')
TEMP_SYNTAX_JSON="$TEMP_DIR/syntax.json"
TEMP_BEST_PRACTICES_JSON="$TEMP_DIR/best-practices.json"
TEMP_SECURITY_JSON="$TEMP_DIR/security.json"

# Cleanup function for temp files
cleanup_temp_files() {
    rm -rf "$TEMP_DIR"
}

# Register cleanup on exit
trap cleanup_temp_files EXIT

# Results tracking
SYNTAX_RESULT=0
BEST_PRACTICES_RESULT=0
SECURITY_RESULT=0
TOTAL_ERRORS=0
TOTAL_WARNINGS=0

# Print header
if [ "$JSON_OUTPUT" = false ]; then
    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "  GitLab CI/CD Validator"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "File: $FILE_PATH"
    echo ""
fi

# Run syntax validation
if [ "$RUN_SYNTAX" = true ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[1/3]${NC} Running syntax validation..."
        echo ""
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        # Run with JSON output and capture (use set +e to allow non-zero exit)
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/validate_syntax.py" "$FILE_PATH" --json > "$TEMP_SYNTAX_JSON"
        SYNTAX_RESULT=$?
        set -e
    else
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/validate_syntax.py" "$FILE_PATH"
        SYNTAX_RESULT=$?
        set -e
        if [ $SYNTAX_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Syntax validation passed"
        else
            echo -e "${RED}✗${NC} Syntax validation failed"
        fi
        echo ""
    fi

    if [ $SYNTAX_RESULT -ne 0 ]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
fi

# Run best practices check
if [ "$RUN_BEST_PRACTICES" = true ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[2/3]${NC} Running best practices check..."
        echo ""
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        # Run with JSON output and capture (use set +e to allow non-zero exit)
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_best_practices.py" "$FILE_PATH" --json > "$TEMP_BEST_PRACTICES_JSON"
        BEST_PRACTICES_RESULT=$?
        set -e
    else
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_best_practices.py" "$FILE_PATH"
        BEST_PRACTICES_RESULT=$?
        set -e
        if [ $BEST_PRACTICES_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Best practices check completed"
        else
            echo -e "${YELLOW}⚠${NC} Best practices check found issues"
        fi
        echo ""
    fi

    if [ $BEST_PRACTICES_RESULT -ne 0 ] && [ "$STRICT_MODE" = true ]; then
        TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
    fi
fi

# Run security scan
if [ "$RUN_SECURITY" = true ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[3/3]${NC} Running security scan..."
        echo ""
    fi

    if [ "$JSON_OUTPUT" = true ]; then
        # Run with JSON output and capture (use set +e to allow non-zero exit)
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_security.py" "$FILE_PATH" --json > "$TEMP_SECURITY_JSON"
        SECURITY_RESULT=$?
        set -e
    else
        set +e
        bash "$PYTHON_WRAPPER" "$SCRIPT_DIR/check_security.py" "$FILE_PATH"
        SECURITY_RESULT=$?
        set -e
        if [ $SECURITY_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Security scan passed"
        else
            echo -e "${RED}✗${NC} Security scan found issues"
        fi
        echo ""
    fi

    if [ $SECURITY_RESULT -ne 0 ]; then
        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
    fi
fi

# Run local pipeline testing with gitlab-ci-local
TEST_RESULT=0
if [ "$RUN_TEST" = true ]; then
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${BLUE}[TEST]${NC} Running local pipeline testing with gitlab-ci-local..."
        echo ""
    fi

    # Check if gitlab-ci-local is installed
    if command -v gitlab-ci-local &> /dev/null; then
        GITLAB_CI_LOCAL_VERSION=$(gitlab-ci-local --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} gitlab-ci-local found: $GITLAB_CI_LOCAL_VERSION"
        echo ""

        # Get the directory containing the config file for proper execution
        CONFIG_DIR=$(dirname "$FILE_PATH")
        CONFIG_FILE=$(basename "$FILE_PATH")

        echo "Listing jobs in pipeline:"
        echo "─────────────────────────────────────────────────────────────────────────────────"

        # Run gitlab-ci-local to list jobs
        set +e
        if [ "$CONFIG_DIR" != "." ]; then
            (cd "$CONFIG_DIR" && gitlab-ci-local --file "$CONFIG_FILE" --list 2>&1)
        else
            gitlab-ci-local --file "$FILE_PATH" --list 2>&1
        fi
        TEST_RESULT=$?
        set -e

        echo ""
        echo "─────────────────────────────────────────────────────────────────────────────────"

        if [ $TEST_RESULT -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Pipeline structure validated successfully"
            echo ""
            echo "To run the full pipeline locally, use:"
            echo "  gitlab-ci-local --file $FILE_PATH"
            echo ""
            echo "To run a specific job:"
            echo "  gitlab-ci-local --file $FILE_PATH <job-name>"
        else
            echo -e "${YELLOW}⚠${NC} gitlab-ci-local encountered issues"
            echo "This may be due to missing variables or external dependencies."
        fi
    elif command -v npx &> /dev/null && npx --no-install gitlab-ci-local --version &> /dev/null 2>&1; then
        # Try with npx (local installation)
        echo -e "${GREEN}✓${NC} gitlab-ci-local found via npx"
        echo ""

        echo "Listing jobs in pipeline:"
        echo "─────────────────────────────────────────────────────────────────────────────────"

        set +e
        npx gitlab-ci-local --file "$FILE_PATH" --list 2>&1
        TEST_RESULT=$?
        set -e

        echo ""
        echo "─────────────────────────────────────────────────────────────────────────────────"
    else
        echo -e "${YELLOW}⚠${NC} gitlab-ci-local is not installed"
        echo ""
        echo "To install gitlab-ci-local, run:"
        echo "  bash $SCRIPT_DIR/install_tools.sh"
        echo ""
        echo "Or install manually:"
        echo "  npm install -g gitlab-ci-local"
        echo ""
        echo "Requirements:"
        echo "  - Node.js (for gitlab-ci-local)"
        echo "  - Docker (for running jobs locally)"
        TEST_RESULT=1
    fi
    echo ""
fi

# Print summary
if [ "$JSON_OUTPUT" = true ]; then
    # Combine JSON results from all validators
    echo "{"
    echo "  \"file\": \"$FILE_PATH\","
    echo "  \"validators\": ["

    FIRST=true
    if [ "$RUN_SYNTAX" = true ] && [ -f "$TEMP_SYNTAX_JSON" ]; then
        cat "$TEMP_SYNTAX_JSON"
        FIRST=false
    fi

    if [ "$RUN_BEST_PRACTICES" = true ] && [ -f "$TEMP_BEST_PRACTICES_JSON" ]; then
        if [ "$FIRST" = false ]; then echo ","; fi
        cat "$TEMP_BEST_PRACTICES_JSON"
        FIRST=false
    fi

    if [ "$RUN_SECURITY" = true ] && [ -f "$TEMP_SECURITY_JSON" ]; then
        if [ "$FIRST" = false ]; then echo ","; fi
        cat "$TEMP_SECURITY_JSON"
    fi

    echo "  ],"
    echo "  \"summary\": {"

    # Generate summary with proper null handling for skipped validators
    SUMMARY_PARTS=()

    if [ "$RUN_SYNTAX" = true ]; then
        if [ $SYNTAX_RESULT -eq 0 ]; then
            SUMMARY_PARTS+=("\"syntax_validation\": \"PASSED\"")
        else
            SUMMARY_PARTS+=("\"syntax_validation\": \"FAILED\"")
        fi
    else
        SUMMARY_PARTS+=("\"syntax_validation\": null")
    fi

    if [ "$RUN_BEST_PRACTICES" = true ]; then
        if [ $BEST_PRACTICES_RESULT -eq 0 ]; then
            SUMMARY_PARTS+=("\"best_practices\": \"PASSED\"")
        else
            SUMMARY_PARTS+=("\"best_practices\": \"WARNINGS\"")
        fi
    else
        SUMMARY_PARTS+=("\"best_practices\": null")
    fi

    if [ "$RUN_SECURITY" = true ]; then
        if [ $SECURITY_RESULT -eq 0 ]; then
            SUMMARY_PARTS+=("\"security_scan\": \"PASSED\"")
        else
            SUMMARY_PARTS+=("\"security_scan\": \"FAILED\"")
        fi
    else
        SUMMARY_PARTS+=("\"security_scan\": null")
    fi

    # Join array elements with commas
    FIRST_SUMMARY=true
    for part in "${SUMMARY_PARTS[@]}"; do
        if [ "$FIRST_SUMMARY" = true ]; then
            echo -n "    $part"
            FIRST_SUMMARY=false
        else
            echo ","
            echo -n "    $part"
        fi
    done
    echo ""

    echo "  }"
    echo "}"

    # Temporary files are automatically cleaned up by trap EXIT
else
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo "  Validation Summary"
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""

    # Syntax validation
    if [ "$RUN_SYNTAX" = true ]; then
        if [ $SYNTAX_RESULT -eq 0 ]; then
            echo -e "Syntax Validation:      ${GREEN}PASSED${NC}"
        else
            echo -e "Syntax Validation:      ${RED}FAILED${NC}"
        fi
    fi

    # Best practices
    if [ "$RUN_BEST_PRACTICES" = true ]; then
        if [ $BEST_PRACTICES_RESULT -eq 0 ]; then
            echo -e "Best Practices:         ${GREEN}PASSED${NC}"
        else
            echo -e "Best Practices:         ${YELLOW}WARNINGS${NC}"
        fi
    fi

    # Security scan
    if [ "$RUN_SECURITY" = true ]; then
        if [ $SECURITY_RESULT -eq 0 ]; then
            echo -e "Security Scan:          ${GREEN}PASSED${NC}"
        else
            echo -e "Security Scan:          ${RED}FAILED${NC}"
        fi
    fi

    # Local testing
    if [ "$RUN_TEST" = true ]; then
        if [ $TEST_RESULT -eq 0 ]; then
            echo -e "Local Testing:          ${GREEN}PASSED${NC}"
        else
            echo -e "Local Testing:          ${YELLOW}WARNINGS${NC}"
        fi
    fi

    echo ""
    echo "════════════════════════════════════════════════════════════════════════════════"
    echo ""
fi

# Determine exit code
EXIT_CODE=0

if [ $SYNTAX_RESULT -ne 0 ] || [ $SECURITY_RESULT -ne 0 ]; then
    EXIT_CODE=1
fi

if [ "$STRICT_MODE" = true ] && [ $BEST_PRACTICES_RESULT -ne 0 ]; then
    EXIT_CODE=1
fi

# Final message
if [ "$JSON_OUTPUT" = false ]; then
    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}✓ All validation checks passed${NC}"
    else
        echo -e "${RED}✗ Validation failed with errors${NC}"
    fi
    echo ""
fi

exit $EXIT_CODE
