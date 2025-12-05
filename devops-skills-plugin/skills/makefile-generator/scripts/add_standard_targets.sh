#!/usr/bin/env bash
#
# add_standard_targets.sh
# Description: Add standard GNU targets to an existing Makefile
# Usage: bash add_standard_targets.sh [MAKEFILE] [TARGETS...]
#
# This script adds missing standard GNU Makefile targets to an existing Makefile.
# It will not overwrite existing targets.
#

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly NC=''
fi

# Print functions
print_error() {
    echo -e "${RED}ERROR:${NC} $*" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $*"
}

print_info() {
    echo -e "${YELLOW}INFO:${NC} $*"
}

print_added() {
    echo -e "${GREEN}+${NC} Added target: ${BLUE}$1${NC}"
}

print_skipped() {
    echo -e "${YELLOW}-${NC} Skipped (exists): ${BLUE}$1${NC}"
}

# Usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [MAKEFILE] [TARGETS...]

Add standard GNU targets to an existing Makefile.

Arguments:
    MAKEFILE    Path to Makefile (default: Makefile)
    TARGETS     Targets to add (default: all standard targets)

Available Targets:
    all         Build all targets (default target)
    install     Install built files to PREFIX
    uninstall   Remove installed files
    clean       Remove built files
    distclean   Remove all generated files
    test        Run tests
    check       Alias for test
    help        Show available targets
    dist        Create distribution tarball

Options:
    -h, --help  Show this help message
    -l, --list  List available targets
    -n, --dry-run  Show what would be added without modifying

Examples:
    ${SCRIPT_NAME}                          # Add all missing targets to ./Makefile
    ${SCRIPT_NAME} build.mk                 # Add all targets to build.mk
    ${SCRIPT_NAME} Makefile clean test      # Add only clean and test targets
    ${SCRIPT_NAME} -n Makefile install      # Preview install target addition

EOF
}

# List available targets
list_targets() {
    cat << EOF
Available standard GNU targets:

  all         - Build all targets (default target)
  install     - Install built files to PREFIX
  uninstall   - Remove installed files from PREFIX
  clean       - Remove built files (keep configuration)
  distclean   - Remove all generated files
  test        - Run tests
  check       - Alias for test (GNU convention)
  help        - Show available targets and usage
  dist        - Create distribution tarball

EOF
}

# Check if target exists in Makefile
target_exists() {
    local target="$1"
    local makefile="$2"
    # Match target at beginning of line, followed by : (not ::)
    grep -qE "^${target}[[:space:]]*:" "$makefile" 2>/dev/null
}

# Check if .PHONY already includes target
phony_includes() {
    local target="$1"
    local makefile="$2"
    grep -qE "^\.PHONY:.*\b${target}\b" "$makefile" 2>/dev/null
}

# Generate target code
generate_target() {
    local target="$1"

    case "$target" in
        all)
            cat << 'EOF'

## Build all targets (default)
.PHONY: all
all: $(TARGET)
EOF
            ;;
        install)
            cat << 'EOF'

## Install built files to PREFIX
.PHONY: install
install: all
	$(INSTALL) -d $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/
EOF
            ;;
        uninstall)
            cat << 'EOF'

## Remove installed files
.PHONY: uninstall
uninstall:
	$(RM) $(DESTDIR)$(PREFIX)/bin/$(TARGET)
EOF
            ;;
        clean)
            cat << 'EOF'

## Remove built files
.PHONY: clean
clean:
	$(RM) -r $(BUILDDIR)
	$(RM) $(TARGET)
	$(RM) *.o *.d
EOF
            ;;
        distclean)
            cat << 'EOF'

## Remove all generated files (including configuration)
.PHONY: distclean
distclean: clean
	$(RM) config.h config.log config.status
	$(RM) -r autom4te.cache/
EOF
            ;;
        test)
            cat << 'EOF'

## Run tests
.PHONY: test
test:
	@echo "Running tests..."
	# Add test commands here
	# Examples:
	# ./run_tests.sh
	# python -m pytest
	# go test ./...
EOF
            ;;
        check)
            cat << 'EOF'

## Alias for test (GNU convention)
.PHONY: check
check: test
EOF
            ;;
        help)
            cat << 'EOF'

## Show available targets
.PHONY: help
help:
	@echo "$(PROJECT) - Build System"
	@echo ""
	@echo "Available targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':' | sed 's/^/  /'
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  CC=$(CC)"
	@echo ""
	@echo "Examples:"
	@echo "  make                  # Build the project"
	@echo "  make install          # Install to PREFIX"
	@echo "  make clean            # Remove built files"
EOF
            ;;
        dist)
            cat << 'EOF'

## Create distribution tarball
.PHONY: dist
dist:
	@mkdir -p dist
	tar -czf dist/$(PROJECT)-$(VERSION).tar.gz \
		--transform 's,^,$(PROJECT)-$(VERSION)/,' \
		--exclude='.git*' \
		--exclude='*.o' \
		--exclude='$(BUILDDIR)' \
		.
EOF
            ;;
        *)
            print_error "Unknown target: $target"
            return 1
            ;;
    esac
}

# Add required variables if missing
add_missing_variables() {
    local makefile="$1"
    local added=0
    local vars_to_add=""

    # Check for essential variables
    if ! grep -qE '^(PROJECT|TARGET)\s*[:?]?=' "$makefile"; then
        vars_to_add+="
# Project configuration
PROJECT := myproject
TARGET := \$(PROJECT)
"
        added=1
    fi

    if ! grep -qE '^PREFIX\s*\?=' "$makefile"; then
        vars_to_add+="
# Installation prefix
PREFIX ?= /usr/local
"
        added=1
    fi

    if ! grep -qE '^INSTALL\s*\?=' "$makefile"; then
        vars_to_add+="
# Install command
INSTALL ?= install
"
        added=1
    fi

    if ! grep -qE '^RM\s*\?=' "$makefile"; then
        vars_to_add+="
# Remove command
RM ?= rm -f
"
        added=1
    fi

    if ! grep -qE '^BUILDDIR\s*[:?]?=' "$makefile"; then
        vars_to_add+="
# Build directory
BUILDDIR := build
"
        added=1
    fi

    if ! grep -qE '^VERSION\s*[:?]?=' "$makefile"; then
        vars_to_add+="
# Project version
VERSION := 1.0.0
"
        added=1
    fi

    if [[ $added -eq 1 ]]; then
        # Prepend variables to the file (after any header comments)
        local header=""
        local content=""

        # Extract header comments (lines starting with #)
        while IFS= read -r line; do
            if [[ "$line" =~ ^# ]] || [[ -z "$line" ]]; then
                header+="$line"$'\n'
            else
                break
            fi
        done < "$makefile"

        # Get the rest of the file
        content=$(tail -n +$(($(echo -n "$header" | grep -c $'\n') + 1)) "$makefile" 2>/dev/null || cat "$makefile")

        # Reconstruct file
        {
            echo -n "$header"
            echo "# ============================================"
            echo "# Added by add_standard_targets.sh"
            echo "# ============================================"
            echo "$vars_to_add"
            echo "$content"
        } > "${makefile}.tmp"
        mv "${makefile}.tmp" "$makefile"

        print_info "Added missing variable definitions"
    fi
}

# Main function
main() {
    local dry_run=0
    local list_only=0

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -l|--list)
                list_targets
                exit 0
                ;;
            -n|--dry-run)
                dry_run=1
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Get Makefile path
    MAKEFILE="${1:-Makefile}"
    shift 2>/dev/null || true

    # Get targets (default: all standard targets)
    if [[ $# -eq 0 ]]; then
        TARGETS=(all install uninstall clean distclean test check help dist)
    else
        TARGETS=("$@")
    fi

    # Check if Makefile exists
    if [[ ! -f "$MAKEFILE" ]]; then
        print_error "Makefile not found: $MAKEFILE"
        exit 1
    fi

    print_info "Processing: $MAKEFILE"
    echo ""

    # Track what we'll add
    local targets_added=0
    local targets_skipped=0
    local content_to_add=""

    # Check each target
    for target in "${TARGETS[@]}"; do
        if target_exists "$target" "$MAKEFILE"; then
            print_skipped "$target"
            ((targets_skipped++))
        else
            if [[ $dry_run -eq 1 ]]; then
                echo -e "${GREEN}+${NC} Would add: ${BLUE}$target${NC}"
            else
                content_to_add+="$(generate_target "$target")"
            fi
            ((targets_added++))
        fi
    done

    echo ""

    # Apply changes if not dry run
    if [[ $dry_run -eq 0 ]] && [[ $targets_added -gt 0 ]]; then
        # Add missing variables first
        add_missing_variables "$MAKEFILE"

        # Append targets to Makefile
        echo "$content_to_add" >> "$MAKEFILE"

        # Report results
        for target in "${TARGETS[@]}"; do
            if ! target_exists "$target" "$MAKEFILE" 2>/dev/null; then
                # This shouldn't happen, but just in case
                :
            elif [[ "$content_to_add" == *"$target"* ]]; then
                print_added "$target"
            fi
        done

        print_success "Added $targets_added target(s) to $MAKEFILE"
    elif [[ $dry_run -eq 1 ]]; then
        print_info "Dry run - no changes made"
        echo "Would add $targets_added target(s), skip $targets_skipped existing target(s)"
    else
        print_info "No targets to add (all requested targets already exist)"
    fi

    # Summary
    echo ""
    echo "Summary:"
    echo "  Targets added:   $targets_added"
    echo "  Targets skipped: $targets_skipped"

    if [[ $targets_added -gt 0 ]] && [[ $dry_run -eq 0 ]]; then
        echo ""
        print_info "Run 'make help' to see available targets"
        print_info "Run 'make -n <target>' to preview what a target does"
    fi
}

# Run main function
main "$@"
