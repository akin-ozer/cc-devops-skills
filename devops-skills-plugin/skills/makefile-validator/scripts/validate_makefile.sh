#!/usr/bin/env bash

# Makefile Validator Script
# Validates Makefile syntax, best practices, security, and optimization using mbake tool
# Features: venv isolation, automatic cleanup via trap, comprehensive validation

set -euo pipefail

# Colors for output (supports NO_COLOR standard: https://no-color.org/)
if [ -n "${NO_COLOR:-}" ]; then
    RED=''
    YELLOW=''
    GREEN=''
    BLUE=''
    NC=''
else
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
fi

# Counters
ERRORS=0
WARNINGS=0
INFO=0

# Temporary venv directory (unique per invocation, respects TMPDIR)
VENV_DIR="${TMPDIR:-/tmp}/makefile-validator-venv-$$"
CLEANUP_DONE=0

# Cleanup function - always runs on exit
cleanup() {
    if [ "$CLEANUP_DONE" -eq 0 ]; then
        CLEANUP_DONE=1
        # Safety check: only remove if it's our temp venv (works with custom TMPDIR)
        if [ -d "$VENV_DIR" ] && [[ "$VENV_DIR" == */makefile-validator-venv-* ]]; then
            echo -e "${BLUE}[CLEANUP]${NC} Removing temporary venv..."
            rm -rf "$VENV_DIR"
        fi
    fi
}

# Register cleanup trap for all exit scenarios
trap cleanup EXIT INT TERM

# Print error and exit
error_exit() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Print section header
print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Print sub-header
print_subheader() {
    echo -e "\n${BLUE}[$1]${NC}"
}

# Check dependencies
check_dependencies() {
    if ! command -v python3 &> /dev/null; then
        error_exit "python3 is required but not installed"
    fi

    if ! command -v pip3 &> /dev/null; then
        error_exit "pip3 is required but not installed"
    fi

    if ! command -v make &> /dev/null; then
        echo -e "${YELLOW}[WARNING]${NC} GNU make not found - syntax validation will be limited"
        ((WARNINGS++))
    fi
}

# Setup virtual environment and install mbake
setup_venv() {
    print_subheader "ENVIRONMENT SETUP"
    echo "Creating temporary venv at: $VENV_DIR"

    python3 -m venv "$VENV_DIR" 2>&1 || error_exit "Failed to create virtual environment"

    # Activate venv
    # shellcheck source=/dev/null
    source "$VENV_DIR/bin/activate"

    echo "Installing mbake..."
    pip3 install --quiet mbake 2>&1 || error_exit "Failed to install mbake"

    echo -e "${GREEN}✓${NC} Environment ready"
}

# Validate Makefile exists and is readable
validate_file() {
    local file=$1

    if [ ! -f "$file" ]; then
        error_exit "File not found: $file"
    fi

    if [ ! -r "$file" ]; then
        error_exit "File not readable: $file"
    fi
}

# Basic syntax check using GNU make
syntax_check() {
    local file=$1
    print_subheader "SYNTAX CHECK (GNU make)"

    if ! command -v make &> /dev/null; then
        echo -e "${YELLOW}⚠${NC} Skipped - GNU make not installed"
        return 0
    fi

    # Get absolute path to Makefile
    local abs_file
    abs_file=$(cd "$(dirname "$file")" && pwd)/$(basename "$file")
    local makefile_dir
    makefile_dir=$(dirname "$abs_file")
    local makefile_name
    makefile_name=$(basename "$abs_file")

    # Run make from the Makefile's directory to resolve relative paths correctly
    if (cd "$makefile_dir" && make -f "$makefile_name" -n --dry-run) &> /dev/null; then
        echo -e "${GREEN}✓${NC} No syntax errors found"
        return 0
    else
        echo -e "${RED}✗${NC} Syntax errors detected:"
        (cd "$makefile_dir" && make -f "$makefile_name" -n --dry-run) 2>&1 || true
        ((ERRORS++))
        return 1
    fi
}

# Run mbake validation
mbake_validation() {
    local file=$1
    print_subheader "MBAKE VALIDATION"

    echo "Running mbake validate..."
    if mbake validate "$file" 2>&1; then
        echo -e "${GREEN}✓${NC} mbake validation passed"
    else
        echo -e "${RED}✗${NC} mbake validation failed"
        ((ERRORS++))
    fi
}

# Run mbake format check
mbake_format_check() {
    local file=$1
    print_subheader "MBAKE FORMAT CHECK"

    echo "Checking formatting consistency..."
    # Capture output - mbake may wrap long lines
    local format_output
    format_output=$(mbake format --check "$file" 2>&1)
    local format_exit=$?

    # Join multi-line output for easier pattern matching (mbake wraps at ~80 chars)
    # Also normalize whitespace (collapse multiple spaces to single space)
    local format_oneline
    format_oneline=$(echo "$format_output" | tr '\n' ' ' | tr -s ' ')

    # Check for known false positives (mbake limitation with GNU Make special targets)
    # mbake doesn't recognize .DELETE_ON_ERROR, .SUFFIXES, .ONESHELL, .POSIX
    local has_unknown_special_target=0
    if echo "$format_oneline" | grep -qE "Unknown special target '\.(DELETE_ON_ERROR|SUFFIXES|ONESHELL|POSIX)'"; then
        has_unknown_special_target=1
    fi

    # Check if there are real formatting issues ("Would reformat:" indicates changes needed)
    local has_reformat=0
    if echo "$format_oneline" | grep -q "Would reformat:"; then
        has_reformat=1
    fi

    # Check for other errors (not related to unknown special targets)
    local has_other_errors=0
    # Remove known false positive patterns completely (including "Error:" before them)
    # Pattern matches: "some_file.mk:0: Error: Unknown special target '.DELETE_ON_ERROR'"
    local cleaned_output
    cleaned_output=$(echo "$format_oneline" | sed -E "s/[^ ]*:[0-9]+: Error: Unknown special target '\.[A-Z_]+'//g")
    if echo "$cleaned_output" | grep -qE "Error:|Fatal error"; then
        has_other_errors=1
    fi

    # Decision logic
    if [ $format_exit -eq 0 ]; then
        echo -e "${GREEN}✓${NC} Formatting is consistent"
    elif [ $has_unknown_special_target -eq 1 ] && [ $has_reformat -eq 0 ] && [ $has_other_errors -eq 0 ]; then
        # Only false positive about unknown special targets - treat as success
        echo -e "${GREEN}✓${NC} Formatting is consistent"
        echo -e "${BLUE}ℹ${NC} mbake reported unknown special targets (this is a known mbake limitation)"
    elif [ $has_reformat -eq 1 ] || [ $has_other_errors -eq 1 ]; then
        # Real formatting issues or other errors exist
        echo "$format_output" | grep -v "Unknown special target" | grep -v "^$" || true
        echo -e "${YELLOW}⚠${NC} Formatting issues found"
        echo ""
        echo "Run 'mbake format $file' to fix formatting issues"
        echo "Or run 'mbake format --diff $file' to preview changes"
        ((WARNINGS++))
    else
        # Unknown case - show as info, don't warn
        echo -e "${GREEN}✓${NC} Formatting is consistent"
        if [ $has_unknown_special_target -eq 1 ]; then
            echo -e "${BLUE}ℹ${NC} mbake reported unknown special targets (this is a known mbake limitation)"
        fi
    fi
}

# Custom security and best practice checks
custom_checks() {
    local file=$1
    print_subheader "CUSTOM CHECKS"

    local found_issues=0

    # ============================================================
    # CRITICAL: Check for .DELETE_ON_ERROR (GNU Make best practice)
    # ============================================================
    if ! grep -q "^\.DELETE_ON_ERROR:" "$file"; then
        echo -e "${YELLOW}⚠${NC} Missing .DELETE_ON_ERROR declaration"
        echo "   GNU Make recommends this to delete targets on recipe failure"
        echo "   Add '.DELETE_ON_ERROR:' at the top of your Makefile"
        echo "   See: https://www.gnu.org/software/make/manual/html_node/Special-Targets.html"
        ((WARNINGS++))
        found_issues=1
    fi

    # ============================================================
    # Check for explicit SHELL setting (modern best practice)
    # ============================================================
    if ! grep -qE "^SHELL\s*:?=\s*(bash|/bin/bash|/usr/bin/bash)" "$file"; then
        echo -e "${BLUE}ℹ${NC} No explicit SHELL setting"
        echo "   Consider 'SHELL := bash' for predictable behavior"
        echo "   See: https://tech.davis-hansson.com/p/make/"
        ((INFO++))
        found_issues=1
    fi

    # ============================================================
    # Check for recommended MAKEFLAGS settings
    # ============================================================
    if ! grep -q "MAKEFLAGS.*--warn-undefined-variables" "$file"; then
        echo -e "${BLUE}ℹ${NC} Consider 'MAKEFLAGS += --warn-undefined-variables'"
        echo "   This alerts you to undefined Make variable references"
        ((INFO++))
        found_issues=1
    fi
    if ! grep -q "MAKEFLAGS.*--no-builtin-rules" "$file"; then
        echo -e "${BLUE}ℹ${NC} Consider 'MAKEFLAGS += --no-builtin-rules'"
        echo "   This disables built-in implicit rules for faster builds"
        ((INFO++))
        found_issues=1
    fi

    # Check for .PHONY declarations
    if ! grep -q "^\.PHONY:" "$file"; then
        echo -e "${YELLOW}⚠${NC} No .PHONY declarations found"
        echo "   Consider adding .PHONY for targets that don't create files"
        echo "   Example: .PHONY: clean test install"
        ((WARNINGS++))
        found_issues=1
    fi

    # Check for tabs vs spaces in recipes (improved regex)
    # Catches 2, 4, or 8 space indentation that should be tabs
    local space_lines
    space_lines=$(grep -nE "^(  |    |        )[a-zA-Z@\$\(]" "$file" 2>/dev/null | head -5) || true
    if [ -n "$space_lines" ]; then
        echo -e "${RED}✗${NC} Potential spaces instead of tabs in recipes detected:"
        echo "$space_lines"
        echo "   Makefiles require TAB characters for recipe indentation"
        ((ERRORS++))
        found_issues=1
    fi

    # Check for hardcoded credentials (expanded pattern for common credential names)
    local cred_lines
    cred_lines=$(grep -niE '(password|secret|api[_-]?key|apikey|token|private[_-]?key|aws_access_key|aws_secret_access_key|github_token|auth_token|credentials|azure_client_secret|database_url|db_password|ssh_key|ssl_key|encryption_key)\s*[:?]?=' "$file" 2>/dev/null | grep -v "^\s*#" | head -3) || true
    if [ -n "$cred_lines" ]; then
        echo -e "${RED}✗${NC} Potential hardcoded credentials detected:"
        echo "$cred_lines"
        echo "   Use environment variables or secret management instead"
        ((ERRORS++))
        found_issues=1
    fi

    # Check for TRULY unsafe variable expansion patterns
    # Only flag variables that are NOT defined with defaults in the same file
    # Look for rm/sudo/curl/wget with variables that could be empty or user-controlled
    local unsafe_vars=""
    while IFS= read -r line; do
        # Extract variable name from $(VAR) pattern
        var_name=$(echo "$line" | grep -oE '\$\([A-Z_]+\)' | head -1 | tr -d '$()')
        if [ -n "$var_name" ]; then
            # Check if variable has a default value with := or ?=
            if ! grep -qE "^${var_name}\s*[:?]=" "$file"; then
                # Variable has no default, this is potentially unsafe
                unsafe_vars="${unsafe_vars}${line}\n"
            fi
        fi
    done < <(grep -E '\$\([A-Z_]+\)' "$file" | grep -E '(rm -rf|sudo|curl|wget)')

    if [ -n "$unsafe_vars" ]; then
        echo -e "${YELLOW}⚠${NC} Variables without defaults used in dangerous commands:"
        echo -e "$unsafe_vars" | head -3
        echo "   Consider adding default values (VAR := value) or validation"
        ((WARNINGS++))
        found_issues=1
    fi

    # Check for missing error handling in recipes
    if grep -E "^\t[^@#-]" "$file" | grep -vE "set -e|pipefail|\|\||&&" | grep -q .; then
        echo -e "${BLUE}ℹ${NC} Some recipe commands may lack error handling"
        echo "   Consider using 'set -e', '||', '&&' or '-' prefix for error control"
        ((INFO++))
        found_issues=1
    fi

    # Check for missing .INTERMEDIATE or .SECONDARY for temporary files
    if grep -E "\.o|\.tmp|\.temp" "$file" | grep -q ":"; then
        if ! grep -qE "^\.(INTERMEDIATE|SECONDARY):" "$file"; then
            echo -e "${BLUE}ℹ${NC} Intermediate files detected (.o, .tmp, .temp)"
            echo "   Consider using .INTERMEDIATE or .SECONDARY for automatic cleanup"
            ((INFO++))
            found_issues=1
        fi
    fi

    # Check for missing default target documentation
    # Look for various patterns: "Default target", "(default)", "Main target", "default:" before all:
    if ! grep -qE "^##?.*(([Dd]efault|[Mm]ain|[Ff]irst).*target|target.*(default|main)|^\s*all:.*#.*default|\(default\))" "$file"; then
        # Also check if there's a ## comment right before "all:" target
        if ! grep -B1 "^all:" "$file" | grep -qE "^##"; then
            echo -e "${BLUE}ℹ${NC} No documentation for default target"
            echo "   Consider adding a comment explaining the default target"
            ((INFO++))
            found_issues=1
        fi
    fi

    # Check for recursive variable expansion with shell commands (performance issue)
    local shell_lines
    shell_lines=$(grep -nE "^\s*[A-Z_]+\s*=\s*\$\(shell" "$file" 2>/dev/null | head -3) || true
    if [ -n "$shell_lines" ]; then
        echo -e "${YELLOW}⚠${NC} Shell commands with recursive expansion '=' found:"
        echo "$shell_lines"
        echo "   Use ':=' for immediate expansion to avoid repeated shell calls"
        ((WARNINGS++))
        found_issues=1
    fi

    # Check for .SUFFIXES (optimization for disabling built-in rules)
    # This is informational - not all Makefiles need this
    if grep -qE "^%\." "$file" || grep -qE "^\.[a-z]+\.[a-z]+:" "$file"; then
        if ! grep -q "^\.SUFFIXES:" "$file"; then
            echo -e "${BLUE}ℹ${NC} Pattern/suffix rules found but no .SUFFIXES declaration"
            echo "   Consider adding '.SUFFIXES:' to disable built-in rules for faster builds"
            ((INFO++))
            found_issues=1
        fi
    fi

    # Check for using 'make' instead of '$(MAKE)' in recursive calls
    # Exclude: echo statements, comments, and string literals
    local make_lines
    make_lines=$(grep -nE "^\t[^#@]*\bmake\s" "$file" 2>/dev/null | grep -vE '(echo|printf|MAKE\)|".*make.*"|'"'"'.*make.*'"'"')' | head -3) || true
    if [ -n "$make_lines" ]; then
        echo -e "${YELLOW}⚠${NC} Direct 'make' call in recipe (should use \$(MAKE)):"
        echo "$make_lines"
        echo "   Use '\$(MAKE)' for recursive make calls to preserve flags and options"
        ((WARNINGS++))
        found_issues=1
    fi

    # Check for .SUFFIXES recommendation for large Makefiles
    local target_count
    target_count=$(grep -cE "^[a-zA-Z_][a-zA-Z0-9_-]*:" "$file" 2>/dev/null) || target_count=0
    if [ "$target_count" -gt 10 ] && ! grep -q "^\.SUFFIXES:" "$file"; then
        echo -e "${BLUE}ℹ${NC} Large Makefile ($target_count targets) without .SUFFIXES"
        echo "   Consider adding '.SUFFIXES:' to disable built-in rules for faster builds"
        ((INFO++))
        found_issues=1
    fi

    # ============================================================
    # Check for .ONESHELL without proper error handling
    # ============================================================
    if grep -q "^\.ONESHELL:" "$file"; then
        # .ONESHELL is used - check if .SHELLFLAGS includes recommended flags
        local has_shellflags=0
        local has_e_flag=0
        local has_u_flag=0
        local has_pipefail=0

        if grep -qE "^\.?SHELLFLAGS\s*:?=" "$file"; then
            has_shellflags=1
            local shellflags_line
            shellflags_line=$(grep -E "^\.?SHELLFLAGS\s*:?=" "$file" | head -1)
            # Check for -e flag (can be standalone -e or combined like -eu, -euo, etc.)
            # Match: -e, -eu, -euo, -eux, etc. (e after dash, possibly with other letters)
            if [[ "$shellflags_line" =~ -[a-zA-Z]*e[a-zA-Z]* ]] || [[ "$shellflags_line" == *"-e "* ]] || [[ "$shellflags_line" == *"-e\""* ]]; then
                has_e_flag=1
            fi
            # Check for -u flag (can be standalone -u or combined like -eu, -euo, etc.)
            if [[ "$shellflags_line" =~ -[a-zA-Z]*u[a-zA-Z]* ]] || [[ "$shellflags_line" == *"-u "* ]] || [[ "$shellflags_line" == *"-u\""* ]]; then
                has_u_flag=1
            fi
            # Check for pipefail (always as -o pipefail)
            [[ "$shellflags_line" == *"pipefail"* ]] && has_pipefail=1
        fi

        if [ "$has_shellflags" -eq 0 ]; then
            # No SHELLFLAGS at all, check if recipes commonly use set -e
            local oneshell_recipes
            oneshell_recipes=$(grep -cE "^\t" "$file" 2>/dev/null) || oneshell_recipes=0
            local set_e_count
            set_e_count=$(grep -cE "^\t.*set -e" "$file" 2>/dev/null) || set_e_count=0

            # If less than 33% of recipe blocks have set -e, warn
            if [ "$oneshell_recipes" -gt 0 ] && [ "$set_e_count" -lt $((oneshell_recipes / 3)) ]; then
                echo -e "${YELLOW}⚠${NC} .ONESHELL used without .SHELLFLAGS"
                echo "   With .ONESHELL, recipe errors (except the last line) are silently ignored"
                echo "   Fix: Add '.SHELLFLAGS := -eu -o pipefail -c'"
                echo "   See: https://www.gnu.org/software/make/manual/html_node/One-Shell.html"
                ((WARNINGS++))
                found_issues=1
            fi
        elif [ "$has_e_flag" -eq 0 ]; then
            echo -e "${YELLOW}⚠${NC} .ONESHELL with SHELLFLAGS missing -e flag"
            echo "   Without -e, errors in recipe commands are ignored"
            echo "   Consider: .SHELLFLAGS := -eu -o pipefail -c"
            ((WARNINGS++))
            found_issues=1
        else
            # Has -e, but recommend full flags as info
            if [ "$has_u_flag" -eq 0 ] || [ "$has_pipefail" -eq 0 ]; then
                echo -e "${BLUE}ℹ${NC} .SHELLFLAGS could include additional safety flags"
                echo "   Recommended: .SHELLFLAGS := -eu -o pipefail -c"
                echo "   -u: error on undefined variables, -o pipefail: catch pipe failures"
                ((INFO++))
                found_issues=1
            fi
        fi
    fi

    # ============================================================
    # Check for .EXPORT_ALL_VARIABLES (security concern)
    # ============================================================
    if grep -q "^\.EXPORT_ALL_VARIABLES:" "$file"; then
        echo -e "${YELLOW}⚠${NC} .EXPORT_ALL_VARIABLES used - security consideration"
        echo "   This exports ALL Make variables to subprocesses, potentially leaking sensitive data"
        echo "   Consider using 'export VAR' for specific variables instead"
        ((WARNINGS++))
        found_issues=1
    fi

    # ============================================================
    # Check for order-only prerequisites (directory best practice)
    # ============================================================
    # If mkdir -p is used in recipes and order-only | syntax is not used
    if grep -qE "^\t.*mkdir.*-p" "$file"; then
        if ! grep -qE '\| \$\(' "$file"; then
            echo -e "${BLUE}ℹ${NC} mkdir in recipes without order-only prerequisites"
            echo "   Consider using order-only prerequisites for directories:"
            echo "   Example: \$(BUILD_DIR)/app: \$(SOURCES) | \$(BUILD_DIR)"
            echo "   This prevents unnecessary rebuilds when only timestamps change"
            ((INFO++))
            found_issues=1
        fi
    fi

    # ============================================================
    # Check for parallel-unsafe patterns without .NOTPARALLEL
    # ============================================================
    if grep -qE "^\t.*(docker build|npm install|pip install|yarn install|bundle install)" "$file"; then
        if ! grep -q "^\.NOTPARALLEL:" "$file"; then
            echo -e "${BLUE}ℹ${NC} Parallel-sensitive commands detected (npm/docker/pip install)"
            echo "   Consider using .NOTPARALLEL for targets with these commands"
            echo "   Or add proper dependencies to prevent race conditions"
            ((INFO++))
            found_issues=1
        fi
    fi

    if [ "$found_issues" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} No additional issues found"
    fi
}

# Run checkmake if available
checkmake_validation() {
    local file=$1
    print_subheader "CHECKMAKE VALIDATION (optional)"

    if ! command -v checkmake &> /dev/null; then
        echo -e "${BLUE}ℹ${NC} checkmake not installed - skipping additional linting"
        echo "   Install with: go install github.com/checkmake/checkmake/cmd/checkmake@latest"
        return 0
    fi

    echo "Running checkmake..."
    local checkmake_output
    checkmake_output=$(checkmake "$file" 2>&1) || true
    if [ -n "$checkmake_output" ]; then
        echo "$checkmake_output"
        # Count warnings from checkmake
        local cm_warnings
        cm_warnings=$(echo "$checkmake_output" | grep -c "WARN" 2>/dev/null) || cm_warnings=0
        if [ "$cm_warnings" -gt 0 ]; then
            ((WARNINGS+=cm_warnings))
        fi
    else
        echo -e "${GREEN}✓${NC} checkmake validation passed"
    fi
}

# Run unmake if available (for POSIX portability checks)
unmake_validation() {
    local file=$1
    print_subheader "UNMAKE VALIDATION (optional)"

    if ! command -v unmake &> /dev/null; then
        echo -e "${BLUE}ℹ${NC} unmake not installed - skipping POSIX portability checks"
        echo "   See: https://github.com/mcandre/unmake"
        return 0
    fi

    echo "Running unmake for POSIX portability..."
    local unmake_output
    unmake_output=$(unmake "$file" 2>&1) || true
    if [ -n "$unmake_output" ]; then
        echo "$unmake_output"
        # Count warnings from unmake
        local um_warnings
        um_warnings=$(echo "$unmake_output" | grep -cE "(warning|Warning)" 2>/dev/null) || um_warnings=0
        if [ "$um_warnings" -gt 0 ]; then
            ((WARNINGS+=um_warnings))
        fi
    else
        echo -e "${GREEN}✓${NC} unmake validation passed (POSIX compatible)"
    fi
}

# Print summary
print_summary() {
    local file=$1
    print_header "VALIDATION SUMMARY"
    echo "File: $file"
    echo ""
    echo -e "${RED}Errors:  ${NC} $ERRORS"
    echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
    echo -e "${BLUE}Info:    ${NC} $INFO"
    echo ""

    if [ "$ERRORS" -gt 0 ]; then
        echo -e "${RED}⚠ Validation FAILED - errors must be fixed${NC}"
        return 2
    elif [ "$WARNINGS" -gt 0 ]; then
        echo -e "${YELLOW}⚠ Validation PASSED with warnings${NC}"
        return 1
    else
        echo -e "${GREEN}✓ Validation PASSED${NC}"
        return 0
    fi
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <Makefile>"
        echo ""
        echo "Validates Makefile for syntax errors, best practices, security issues,"
        echo "and optimization opportunities using mbake and custom checks."
        echo ""
        echo "Examples:"
        echo "  $0 Makefile"
        echo "  $0 path/to/Makefile"
        echo "  $0 project.mk"
        exit 1
    fi

    local makefile=$1

    print_header "MAKEFILE VALIDATOR"
    echo "File: $makefile"

    # Validation pipeline
    check_dependencies
    validate_file "$makefile"
    setup_venv

    # Run syntax check (continue even if it fails)
    syntax_check "$makefile" || true

    # Run mbake validation (continue even if it fails)
    mbake_validation "$makefile" || true

    # Run format check (continue even if it fails)
    mbake_format_check "$makefile" || true

    # Run custom checks (continue even if it fails)
    custom_checks "$makefile" || true

    # Run checkmake if available (optional, continue even if it fails)
    checkmake_validation "$makefile" || true

    # Run unmake if available (optional, continue even if it fails)
    unmake_validation "$makefile" || true

    # Print summary and return appropriate exit code
    print_summary "$makefile"
    local exit_code=$?

    return $exit_code
}

# Run main with all arguments and exit with its return code
main "$@"
exit $?