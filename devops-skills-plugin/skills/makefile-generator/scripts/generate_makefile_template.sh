#!/usr/bin/env bash
#
# generate_makefile_template.sh
# Description: Generate Makefile templates for different project types
# Usage: bash generate_makefile_template.sh [OPTIONS] [PROJECT_TYPE] [PROJECT_NAME] [OUTPUT_FILE]
#

set -euo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
FORCE=0
PROJECT_TYPE=""
PROJECT_NAME="myproject"
OUTPUT_FILE="Makefile"

# Colors for output
if [[ -t 1 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly NC='\033[0m' # No Color
else
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
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

# Usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [PROJECT_TYPE] [PROJECT_NAME] [OUTPUT_FILE]

Generate Makefile templates for different project types.

Options:
    -f, --force     Overwrite existing files without prompting
    -h, --help      Show this help message

Arguments:
    PROJECT_TYPE    Type of project (required)
    PROJECT_NAME    Name of the project (default: myproject)
    OUTPUT_FILE     Output file path (default: Makefile)

Project Types:
    c               Simple C project
    c-lib           C library project
    cpp             C++ project
    go              Go project
    python          Python project
    java            Java project
    generic         Generic project

Examples:
    ${SCRIPT_NAME} c myapp
    ${SCRIPT_NAME} go server Makefile
    ${SCRIPT_NAME} python mypackage build.mk
    ${SCRIPT_NAME} -f c myapp Makefile  # Force overwrite

EOF
}

# Parse command line options
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -*)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                # First positional argument is PROJECT_TYPE
                if [[ -z "${PROJECT_TYPE}" ]]; then
                    PROJECT_TYPE="$1"
                elif [[ "${PROJECT_NAME}" == "myproject" ]]; then
                    PROJECT_NAME="$1"
                else
                    OUTPUT_FILE="$1"
                fi
                shift
                ;;
        esac
    done
}

# Generate C project Makefile
generate_c_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Makefile for C project
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

PROJECT := PROJECT_NAME
VERSION := 1.0.0

CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
PREFIX ?= /usr/local

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
DEPENDS := $(OBJECTS:.o=.d)
TARGET := $(BUILDDIR)/$(PROJECT)

.PHONY: all clean install test help

## Build the application (default)
all: $(TARGET)

$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPENDS)

## Install to PREFIX
install: $(TARGET)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/$(PROJECT)

## Run tests
test: $(TARGET)
	@echo "Running tests..."
	@$(TARGET) --test

## Remove build artifacts
clean:
	$(RM) -r $(BUILDDIR)

## Show help
help:
	@echo "$(PROJECT) v$(VERSION)"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
EOF
}

# Generate C library Makefile
generate_c_lib_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Makefile for C library project
.DELETE_ON_ERROR:

PROJECT := PROJECT_NAME
VERSION := 1.0.0

CC ?= gcc
AR ?= ar
RANLIB ?= ranlib
CFLAGS ?= -Wall -Wextra -O2 -fPIC
PREFIX ?= /usr/local

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
HEADERS := $(wildcard $(SRCDIR)/*.h)

STATIC_LIB := $(BUILDDIR)/lib$(PROJECT).a
SHARED_LIB := $(BUILDDIR)/lib$(PROJECT).so.$(VERSION)

.PHONY: all static shared clean install help

## Build both static and shared libraries
all: static shared

## Build static library
static: $(STATIC_LIB)

## Build shared library
shared: $(SHARED_LIB)

$(STATIC_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	$(AR) rcs $@ $^
	$(RANLIB) $@

$(SHARED_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	$(CC) -shared -Wl,-soname,lib$(PROJECT).so.1 $^ -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

## Install libraries
install: all
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 644 $(STATIC_LIB) $(DESTDIR)$(PREFIX)/lib/
	install -m 755 $(SHARED_LIB) $(DESTDIR)$(PREFIX)/lib/
	install -d $(DESTDIR)$(PREFIX)/include/$(PROJECT)
	install -m 644 $(HEADERS) $(DESTDIR)$(PREFIX)/include/$(PROJECT)/

## Clean build artifacts
clean:
	$(RM) -r $(BUILDDIR)

## Show help
help:
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
EOF
}

# Generate Go project Makefile
generate_go_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Makefile for Go project
.PHONY: all build install test clean help

PROJECT := PROJECT_NAME
GO ?= go
PREFIX ?= /usr/local

VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-X main.version=$(VERSION)"

SOURCES := $(shell find . -name '*.go' -not -path './vendor/*')
TARGET := $(PROJECT)

## Build the application (default)
all: build

## Build binary
build: $(TARGET)

$(TARGET): $(SOURCES) go.mod go.sum
	$(GO) build $(LDFLAGS) -o $@ ./cmd/$(PROJECT)

## Install to PREFIX
install: $(TARGET)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/

## Run tests
test:
	$(GO) test -v ./...

## Clean build artifacts
clean:
	$(RM) $(TARGET)
	$(GO) clean

## Format code
fmt:
	$(GO) fmt ./...

## Run linter
lint:
	golangci-lint run

## Show help
help:
	@echo "$(PROJECT) - Go Project"
	@echo "Version: $(VERSION)"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
EOF
}

# Generate Python project Makefile
generate_python_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Makefile for Python project
.PHONY: all build install test clean help

PROJECT := PROJECT_NAME
PYTHON ?= python3
PIP ?= $(PYTHON) -m pip

## Build the package (default)
all: build

## Build Python package
build:
	$(PYTHON) -m build

## Install package
install:
	$(PIP) install .

## Install in development mode
develop:
	$(PIP) install -e .[dev]

## Run tests
test:
	$(PYTHON) -m pytest tests/ -v

## Format code
format:
	$(PYTHON) -m black src/ tests/
	$(PYTHON) -m isort src/ tests/

## Run linters
lint:
	$(PYTHON) -m flake8 src/ tests/
	$(PYTHON) -m pylint src/

## Clean build artifacts
clean:
	$(RM) -r build/ dist/ *.egg-info/
	$(RM) -r .pytest_cache/ .coverage htmlcov/
	find . -type d -name '__pycache__' -exec rm -r {} +

## Show help
help:
	@echo "$(PROJECT) - Python Project"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
EOF
}

# Generate Java project Makefile
generate_java_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Makefile for Java project
.DELETE_ON_ERROR:

PROJECT := PROJECT_NAME
VERSION := 1.0.0
MAIN_CLASS := Main

# Java tools
JAVAC ?= javac
JAVA ?= java
JAR ?= jar

# Compiler flags
JAVAC_FLAGS ?= -Xlint:all -encoding UTF-8
JAR_FLAGS := cvf

# Directories
SRCDIR := src
BUILDDIR := build
CLASSDIR := $(BUILDDIR)/classes
LIBDIR := lib
DOCDIR := $(BUILDDIR)/docs
DISTDIR := dist

# Source and class files
JAVA_SOURCES := $(shell find $(SRCDIR) -name '*.java')
JAVA_CLASSES := $(JAVA_SOURCES:$(SRCDIR)/%.java=$(CLASSDIR)/%.class)

# Classpath
CLASSPATH := $(CLASSDIR)
ifneq ($(wildcard $(LIBDIR)/*.jar),)
    CLASSPATH := $(CLASSPATH):$(LIBDIR)/*
endif

# Output JAR
TARGET := $(DISTDIR)/$(PROJECT)-$(VERSION).jar

.PHONY: all build compile jar run test clean distclean docs help

## Build the project (default)
all: build

## Compile and create JAR
build: jar

## Compile Java sources
compile: $(CLASSDIR)/.compiled

$(CLASSDIR)/.compiled: $(JAVA_SOURCES)
	@mkdir -p $(CLASSDIR)
	$(JAVAC) $(JAVAC_FLAGS) -d $(CLASSDIR) -cp "$(CLASSPATH)" $(JAVA_SOURCES)
	@touch $@

## Create JAR file
jar: compile
	@mkdir -p $(DISTDIR)
	@echo "Manifest-Version: 1.0" > $(BUILDDIR)/MANIFEST.MF
	@echo "Main-Class: $(MAIN_CLASS)" >> $(BUILDDIR)/MANIFEST.MF
	@echo "Created-By: Makefile" >> $(BUILDDIR)/MANIFEST.MF
	$(JAR) $(JAR_FLAGS)m $(TARGET) $(BUILDDIR)/MANIFEST.MF -C $(CLASSDIR) .
	@echo "Created: $(TARGET)"

## Run the application
run: compile
	$(JAVA) -cp "$(CLASSPATH)" $(MAIN_CLASS)

## Run with JAR
run-jar: jar
	$(JAVA) -jar $(TARGET)

## Run tests (requires JUnit in lib/)
test: compile
	@echo "Running tests..."
	@if [ -d "$(SRCDIR)/test" ]; then \
		$(JAVA) -cp "$(CLASSPATH):$(LIBDIR)/*" org.junit.runner.JUnitCore; \
	else \
		echo "No test directory found"; \
	fi

## Generate Javadoc
docs:
	@mkdir -p $(DOCDIR)
	javadoc -d $(DOCDIR) -sourcepath $(SRCDIR) -subpackages .
	@echo "Documentation generated: $(DOCDIR)/index.html"

## Remove build artifacts
clean:
	$(RM) -r $(BUILDDIR)
	@echo "Clean complete"

## Remove all generated files
distclean: clean
	$(RM) -r $(DISTDIR)
	@echo "Distclean complete"

## Show available targets
help:
	@echo "$(PROJECT) v$(VERSION) - Java Project"
	@echo ""
	@echo "Targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':' | sed 's/^/  /'
	@echo ""
	@echo "Variables:"
	@echo "  JAVAC=$(JAVAC)"
	@echo "  JAVAC_FLAGS=$(JAVAC_FLAGS)"
	@echo "  MAIN_CLASS=$(MAIN_CLASS)"
	@echo ""
	@echo "Directory Structure:"
	@echo "  $(SRCDIR)/          - Java source files"
	@echo "  $(LIBDIR)/          - External JAR dependencies"
	@echo "  $(BUILDDIR)/        - Build output"
	@echo "  $(DISTDIR)/         - Distribution JARs"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build the project"
	@echo "  make run                # Compile and run"
	@echo "  make jar                # Create JAR file"
	@echo "  make MAIN_CLASS=MyApp   # Set main class"
EOF
}

# Generate generic Makefile
generate_generic_makefile() {
    local project="$1"
    sed "s/PROJECT_NAME/${project}/g" << 'EOF'
# Generic Makefile
.PHONY: all build clean install test help

PROJECT := PROJECT_NAME
VERSION := 1.0.0

## Build the project (default)
all: build

## Build target
build:
	@echo "Building $(PROJECT)..."
	# Add build commands here

## Install target
install: build
	@echo "Installing $(PROJECT)..."
	# Add installation commands here

## Run tests
test:
	@echo "Running tests..."
	# Add test commands here

## Clean build artifacts
clean:
	@echo "Cleaning..."
	# Add cleanup commands here

## Show help
help:
	@echo "$(PROJECT) v$(VERSION)"
	@echo ""
	@echo "Available targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
EOF
}

# Main generation logic
generate_makefile() {
    local type="$1"
    local project="$2"
    local output="$3"

    # Check if output file exists
    if [[ -f "${output}" ]]; then
        if [[ "${FORCE}" -eq 1 ]]; then
            print_info "Overwriting existing file: ${output}"
        elif [[ -t 0 ]]; then
            # Interactive mode - prompt user
            print_error "File '${output}' already exists"
            read -p "Overwrite? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Aborted"
                exit 0
            fi
        else
            # Non-interactive mode - fail without --force
            print_error "File '${output}' already exists. Use -f/--force to overwrite."
            exit 1
        fi
    fi

    print_info "Generating ${type} Makefile for project '${project}'..."

    case "${type}" in
        c)
            generate_c_makefile "${project}" > "${output}"
            ;;
        c-lib)
            generate_c_lib_makefile "${project}" > "${output}"
            ;;
        cpp)
            generate_c_makefile "${project}" | sed 's/gcc/g++/g; s/\.c/.cpp/g' > "${output}"
            ;;
        go)
            generate_go_makefile "${project}" > "${output}"
            ;;
        python)
            generate_python_makefile "${project}" > "${output}"
            ;;
        java)
            generate_java_makefile "${project}" > "${output}"
            ;;
        generic)
            generate_generic_makefile "${project}" > "${output}"
            ;;
        *)
            print_error "Unknown project type: ${type}"
            echo ""
            usage
            exit 1
            ;;
    esac

    print_success "Makefile generated: ${output}"
    print_info "Edit the Makefile to customize for your project"
    print_info "Run 'make help' to see available targets"
}

# Parse arguments
parse_args "$@"

# Check required argument
if [[ -z "${PROJECT_TYPE}" ]]; then
    usage
    exit 0
fi

# Main execution
generate_makefile "${PROJECT_TYPE}" "${PROJECT_NAME}" "${OUTPUT_FILE}"