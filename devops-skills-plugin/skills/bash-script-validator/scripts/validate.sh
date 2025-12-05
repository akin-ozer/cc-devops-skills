#!/usr/bin/env bash
#
# Bash/Shell Script Validator
# Validates bash and shell scripts for syntax errors, best practices, security issues, and optimizations
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
ERROR_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0
STYLE_COUNT=0

# Script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 <script-file>

Validates bash and shell scripts for:
  - Syntax errors
  - ShellCheck warnings
  - Security issues
  - Performance optimizations
  - Portability concerns

Options:
  -h, --help    Show this help message

Examples:
  $0 myscript.sh
  $0 /path/to/script.bash
EOF
    exit 0
}

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}[$1]${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
    ((ERROR_COUNT++))
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
    ((WARNING_COUNT++))
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
    ((INFO_COUNT++))
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Detect shell type from shebang (returns shell:status format)
detect_shell() {
    local file="$1"
    local shebang

    shebang=$(head -n 1 "$file")

    # Check if shebang is present
    if [[ ! "$shebang" =~ ^#! ]]; then
        echo "bash:no-shebang"
        return
    fi

    if [[ "$shebang" =~ ^#!.*bash ]]; then
        echo "bash"
    elif [[ "$shebang" =~ ^#!/bin/sh([[:space:]]|$) ]] || \
         [[ "$shebang" =~ ^#!/usr/bin/sh([[:space:]]|$) ]] || \
         [[ "$shebang" =~ /env[[:space:]]+sh([[:space:]]|$) ]]; then
        echo "sh"
    elif [[ "$shebang" =~ ^#!.*zsh ]]; then
        echo "zsh"
    elif [[ "$shebang" =~ ^#!.*ksh ]]; then
        echo "ksh"
    elif [[ "$shebang" =~ ^#!.*dash ]]; then
        echo "dash"
    else
        # Unknown shebang
        echo "bash:unknown-shebang:$shebang"
    fi
}

# Run syntax validation
validate_syntax() {
    local file="$1"
    local shell_type="$2"

    print_section "SYNTAX CHECK"

    case "$shell_type" in
        bash)
            if bash -n "$file" 2>/dev/null; then
                print_success "No syntax errors found (bash -n)"
                return 0
            else
                local errors
                errors=$(bash -n "$file" 2>&1)
                print_error "Syntax errors found:"
                echo "$errors" | sed 's/^/  /'
                return 1
            fi
            ;;
        sh|dash)
            if sh -n "$file" 2>/dev/null; then
                print_success "No syntax errors found (sh -n)"
                return 0
            else
                local errors
                errors=$(sh -n "$file" 2>&1)
                print_error "Syntax errors found:"
                echo "$errors" | sed 's/^/  /'
                return 1
            fi
            ;;
        *)
            print_info "Syntax check skipped for shell type: $shell_type"
            return 0
            ;;
    esac
}

# Run shellcheck validation
run_shellcheck() {
    local file="$1"
    local shell_type="$2"

    print_section "SHELLCHECK"

    local shell_arg=""
    case "$shell_type" in
        bash) shell_arg="-s bash" ;;
        sh|dash) shell_arg="-s sh" ;;
        zsh) shell_arg="-s zsh" ;;
        ksh) shell_arg="-s ksh" ;;
    esac

    # Determine which shellcheck to use
    local shellcheck_cmd=""

    if command -v shellcheck &>/dev/null; then
        # System shellcheck available
        shellcheck_cmd="shellcheck"
    elif [[ -x "$SCRIPT_DIR/shellcheck_wrapper.sh" ]]; then
        # Use wrapper with cache
        shellcheck_cmd="$SCRIPT_DIR/shellcheck_wrapper.sh --cache"
    else
        # Neither available
        print_warning "ShellCheck not installed. Install options:"
        echo "  1. System-wide: brew install shellcheck (macOS)"
        echo "                  apt-get install shellcheck (Debian/Ubuntu)"
        echo "                  dnf install shellcheck (Fedora)"
        echo "  2. Python venv: pip3 install shellcheck-py"
        echo "  3. Wrapper will auto-install if python3 available"
        return 0
    fi

    local output
    if output=$($shellcheck_cmd $shell_arg -f gcc "$file" 2>&1); then
        print_success "No ShellCheck issues found"
        return 0
    else
        local error_lines warning_lines info_lines style_lines

        error_lines=$(echo "$output" | grep -c ": error:" || true)
        warning_lines=$(echo "$output" | grep -c ": warning:" || true)
        info_lines=$(echo "$output" | grep -c ": note:" || true)
        style_lines=$(echo "$output" | grep -c ": style:" || true)

        ERROR_COUNT=$((ERROR_COUNT + error_lines))
        WARNING_COUNT=$((WARNING_COUNT + warning_lines))
        INFO_COUNT=$((INFO_COUNT + info_lines))
        STYLE_COUNT=$((STYLE_COUNT + style_lines))

        echo "$output"
        echo ""
        print_info "See https://www.shellcheck.net/wiki/ for detailed explanations"
        return 1
    fi
}

# Run custom security and optimization checks
run_custom_checks() {
    local file="$1"
    local shell_type="$2"

    print_section "CUSTOM CHECKS"

    local found_issues=0

    # Security: Check for eval with variables
    if grep -E -n 'eval.*\$' "$file" >/dev/null 2>&1; then
        print_warning "Potential command injection: eval with variable found"
        grep -E -n 'eval.*\$' "$file" | sed 's/^/  Line /'
        found_issues=1
    fi

    # Security: Check for unsafe use of rm -rf
    if grep -E -n '(rm -(rf|fr).*\$|rm -(rf|fr) /)' "$file" >/dev/null 2>&1; then
        print_warning "Dangerous rm -rf usage detected"
        grep -E -n '(rm -(rf|fr).*\$|rm -(rf|fr) /)' "$file" | sed 's/^/  Line /'
        found_issues=1
    fi

    # Performance: Useless use of cat (UUOC)
    # Match: cat <filename> | grep/awk/sed
    # Use [^|]+ to match one or more non-pipe characters (the filename)
    if grep -E -n 'cat[[:space:]]+[^|]+[[:space:]]*\|[[:space:]]*(grep|awk|sed)' "$file" >/dev/null 2>&1; then
        print_info "Useless use of cat detected. Consider using redirection instead:"
        grep -E -n 'cat[[:space:]]+[^|]+[[:space:]]*\|[[:space:]]*(grep|awk|sed)' "$file" | sed 's/^/  Line /'
        found_issues=1
    fi

    # Portability: Bash-specific features in sh scripts
    if [[ "$shell_type" == "sh" ]]; then
        # Check for [[ ]] (bash-specific)
        if grep -n "\[\[" "$file" >/dev/null 2>&1; then
            print_error "Bash-specific [[ ]] found in sh script. Use [ ] instead"
            grep -n "\[\[" "$file" | sed 's/^/  Line /'
            found_issues=1
        fi

        # Check for arrays (bash-specific)
        if grep -E -n '(declare -a|array=\()' "$file" >/dev/null 2>&1; then
            print_error "Bash-specific arrays found in sh script"
            grep -E -n '(declare -a|array=\()' "$file" | sed 's/^/  Line /'
            found_issues=1
        fi

        # Check for function keyword (bash-specific)
        if grep -E -n '^function[[:space:]]' "$file" >/dev/null 2>&1; then
            print_warning "Bash-specific 'function' keyword in sh script"
            grep -E -n '^function[[:space:]]' "$file" | sed 's/^/  Line /'
            found_issues=1
        fi

        # Check for source command (bash-specific, use . instead)
        if grep -E -n '^source[[:space:]]' "$file" >/dev/null 2>&1; then
            print_warning "Bash-specific 'source' command in sh script. Use '.' instead"
            grep -E -n '^source[[:space:]]' "$file" | sed 's/^/  Line /'
            found_issues=1
        fi
    fi

    # Check for missing error handling
    if ! grep -E -q '(set -e|set -o errexit)' "$file" && ! grep -E -q 'trap.*ERR' "$file"; then
        print_info "Consider adding error handling (set -e or trap)"
        found_issues=1
    fi

    # Check for missing quotes around variables in dangerous contexts
    if grep -E -n '\$[A-Za-z_][A-Za-z0-9_]*[[:space:]]*>' "$file" >/dev/null 2>&1; then
        print_warning "Unquoted variables in redirection context"
        grep -E -n '\$[A-Za-z_][A-Za-z0-9_]*[[:space:]]*>' "$file" | sed 's/^/  Line /'
        found_issues=1
    fi

    if [[ $found_issues -eq 0 ]]; then
        print_success "No custom issues found"
    fi

    return 0
}

# Print summary
print_summary() {
    local file="$1"
    local shell_type="$2"

    echo ""
    print_header "VALIDATION SUMMARY"
    echo "File: $file"
    echo "Detected Shell: $shell_type"
    echo ""

    if [[ $ERROR_COUNT -eq 0 && $WARNING_COUNT -eq 0 ]]; then
        print_success "All checks passed! ✓"
    else
        echo -e "${RED}Errors:${NC}   $ERROR_COUNT"
        echo -e "${YELLOW}Warnings:${NC} $WARNING_COUNT"
        echo -e "${BLUE}Info:${NC}     $INFO_COUNT"
        echo -e "Style:    $STYLE_COUNT"
    fi

    echo ""
}

# Main validation function
validate_script() {
    local file="$1"

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        echo "Error: File '$file' not found"
        exit 1
    fi

    # Check if file is readable
    if [[ ! -r "$file" ]]; then
        echo "Error: File '$file' is not readable"
        exit 1
    fi

    # Check if file is a text file (not binary)
    # Using file command to detect binary files, or grep -I as fallback
    if command -v file &>/dev/null; then
        local file_type
        file_type=$(file -b --mime-encoding "$file")
        if [[ "$file_type" == "binary" ]]; then
            echo "Error: File '$file' appears to be a binary file, not a text script"
            exit 1
        fi
    elif ! grep -qI . "$file" 2>/dev/null; then
        # Fallback: grep -I skips binary files, if it fails the file is likely binary
        echo "Error: File '$file' appears to be a binary file, not a text script"
        exit 1
    fi

    local shell_type_raw shell_type shell_status
    shell_type_raw=$(detect_shell "$file")

    # Parse shell type and status
    shell_type="${shell_type_raw%%:*}"
    shell_status="${shell_type_raw#*:}"

    print_header "BASH/SHELL SCRIPT VALIDATOR"
    echo "File: $file"
    echo "Detected Shell: $shell_type"

    # Print warnings for special cases
    if [[ "$shell_status" == "no-shebang" ]]; then
        print_warning "No shebang found. Defaulting to bash validation."
    elif [[ "$shell_status" =~ ^unknown-shebang ]]; then
        local unknown_shebang="${shell_status#unknown-shebang:}"
        print_warning "Unknown shebang: $unknown_shebang. Defaulting to bash validation."
    fi

    echo ""

    # Run validations
    validate_syntax "$file" "$shell_type" || true
    run_shellcheck "$file" "$shell_type" || true
    run_custom_checks "$file" "$shell_type" || true

    # Print summary
    print_summary "$file" "$shell_type"

    # Exit with appropriate code
    if [[ $ERROR_COUNT -gt 0 ]]; then
        exit 2
    elif [[ $WARNING_COUNT -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Parse arguments
if [[ $# -eq 0 ]]; then
    usage
fi

case "${1:-}" in
    -h|--help)
        usage
        ;;
    *)
        validate_script "$1"
        ;;
esac
