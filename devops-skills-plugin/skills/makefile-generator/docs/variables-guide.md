# Makefile Variables Guide

## Overview

This guide covers variable definition, assignment operators, automatic variables, standard GNU variables, and best practices for variable management in Makefiles.

## Variable Assignment Operators

Make supports four assignment operators, each with different behavior:

### 1. Recursive Assignment (=)

```makefile
# Evaluated every time the variable is used
FILES = $(wildcard *.c)
OBJECTS = $(FILES:.c=.o)

# Each use of $(OBJECTS) re-expands $(FILES) and re-runs wildcard
target: $(OBJECTS)
	$(CC) $(OBJECTS) -o target
```

**Characteristics:**
- Right-hand side evaluated every time variable is used
- Can reference variables defined later
- Can cause infinite recursion
- Less efficient for frequently-used variables

**When to use:**
- Variables that reference other variables that might change
- Simple string values
- When you need delayed evaluation

### 2. Simple Assignment (:=)

```makefile
# Evaluated once when defined
FILES := $(wildcard *.c)
OBJECTS := $(FILES:.c=.o)

# $(OBJECTS) contains the fixed list from definition time
target: $(OBJECTS)
	$(CC) $(OBJECTS) -o target
```

**Characteristics:**
- Right-hand side evaluated immediately
- More efficient for computed values
- Cannot reference variables defined later
- Prevents infinite recursion

**When to use:**
- Variables with computed values (wildcards, substitutions)
- Frequently-referenced variables
- Most project-specific variables (SOURCES, OBJECTS, TARGET)

### 3. Conditional Assignment (?=)

```makefile
# Only assigns if variable is not already defined
CC ?= gcc
CFLAGS ?= -Wall -O2
PREFIX ?= /usr/local

# Users can override:
# make CC=clang
# export CC=clang; make
```

**Characteristics:**
- Assigns only if variable undefined or empty
- Respects environment variables
- Respects command-line overrides
- Essential for user-configurable variables

**When to use:**
- User-overridable variables (CC, CFLAGS, PREFIX)
- Default values that users might want to change
- All tool and configuration variables

### 4. Append Assignment (+=)

```makefile
# Append to existing value
CFLAGS ?= -Wall -O2
CFLAGS += -I./include
CFLAGS += -DDEBUG

# Result: CFLAGS = -Wall -O2 -I./include -DDEBUG
```

**Characteristics:**
- Adds to existing variable value
- Preserves type of original assignment (= vs :=)
- Automatically adds space between values

**When to use:**
- Adding project-specific flags to user flags
- Building lists incrementally
- Extending default values

## Comparison of Assignment Operators

```makefile
# Recursive (=): Re-evaluated each use
VAR1 = $(shell date)
# VAR1 changes every time it's used!

# Simple (:=): Evaluated once
VAR2 := $(shell date)
# VAR2 is fixed to the date when defined

# Conditional (?=): Only if undefined
VAR3 ?= default
# VAR3 = "default" unless already set

# Append (+=): Add to existing
VAR4 := first
VAR4 += second
# VAR4 = "first second"
```

## Standard GNU Variables

GNU Coding Standards define standard variable names that should be used:

### Compiler and Tools

```makefile
# C Compiler
CC ?= gcc

# C++ Compiler
CXX ?= g++

# Linker (usually same as CC)
LD ?= $(CC)

# Archiver (for creating .a libraries)
AR ?= ar

# Ranlib (for indexing .a libraries)
RANLIB ?= ranlib

# Install program
INSTALL ?= install

# Install program for data files
INSTALL_DATA ?= $(INSTALL) -m 644

# Install program for executables
INSTALL_PROGRAM ?= $(INSTALL) -m 755

# Remove files
RM ?= rm -f

# Yacc/Bison
YACC ?= bison -y

# Lex/Flex
LEX ?= flex

# pkg-config
PKG_CONFIG ?= pkg-config
```

### Compiler Flags

```makefile
# C Preprocessor flags (for includes, defines)
CPPFLAGS ?=

# C Compiler flags
CFLAGS ?= -Wall -Wextra -O2

# C++ Compiler flags
CXXFLAGS ?= -Wall -Wextra -O2

# Linker flags (for library paths, etc.)
LDFLAGS ?=

# Libraries to link (-lname)
LDLIBS ?=

# Yacc/Bison flags
YFLAGS ?=

# Lex/Flex flags
LFLAGS ?=
```

**Best practices for flags:**

```makefile
# Preserve user-defined flags
CFLAGS ?= -Wall -Wextra -O2
# Add project-specific flags
CFLAGS += -I./include -I./src
CFLAGS += -DPROJECT_VERSION=\"$(VERSION)\"

# Use pkg-config for libraries
CFLAGS += $(shell $(PKG_CONFIG) --cflags openssl)
LDLIBS += $(shell $(PKG_CONFIG) --libs openssl)
```

### Installation Directories

```makefile
# Installation prefix
PREFIX ?= /usr/local

# Executable prefix (usually same as PREFIX)
EXEC_PREFIX ?= $(PREFIX)

# Binary directory
BINDIR ?= $(EXEC_PREFIX)/bin

# Library directory
LIBDIR ?= $(EXEC_PREFIX)/lib

# Include directory
INCLUDEDIR ?= $(PREFIX)/include

# Data root directory
DATAROOTDIR ?= $(PREFIX)/share

# Read-only data directory
DATADIR ?= $(DATAROOTDIR)

# System configuration directory
SYSCONFDIR ?= $(PREFIX)/etc

# Variable data directory
LOCALSTATEDIR ?= $(PREFIX)/var

# Man pages directory
MANDIR ?= $(DATAROOTDIR)/man
MAN1DIR ?= $(MANDIR)/man1
MAN2DIR ?= $(MANDIR)/man2
# ... etc

# Info pages directory
INFODIR ?= $(DATAROOTDIR)/info

# Documentation directory
DOCDIR ?= $(DATAROOTDIR)/doc/$(PROJECT)

# DESTDIR for staged installations (package building)
DESTDIR ?=
```

**Usage in install target:**

```makefile
install: $(TARGET)
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL_PROGRAM) $(TARGET) $(DESTDIR)$(BINDIR)/
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL_DATA) lib$(PROJECT).a $(DESTDIR)$(LIBDIR)/
	$(INSTALL) -d $(DESTDIR)$(MAN1DIR)
	$(INSTALL_DATA) docs/$(PROJECT).1 $(DESTDIR)$(MAN1DIR)/
```

## Automatic Variables

Automatic variables are set by make for each rule:

### Basic Automatic Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `$@` | Target file name | `hello` in rule for `hello` |
| `$<` | First prerequisite | `hello.c` in `hello.o: hello.c` |
| `$^` | All prerequisites (no duplicates) | `hello.o utils.o` |
| `$+` | All prerequisites (with duplicates) | Rarely needed |
| `$?` | Prerequisites newer than target | For conditional rebuild |
| `$*` | Stem of pattern match | `hello` in `%.o: %.c` |

### Directory and File Components

| Variable | Description |
|----------|-------------|
| `$(@D)` | Directory part of `$@` |
| `$(@F)` | File part of `$@` |
| `$(<D)` | Directory part of `$<` |
| `$(<F)` | File part of `$<` |
| `$(*D)` | Directory part of `$*` |
| `$(*F)` | File part of `$*` |
| `$(^D)` | Directory parts of `$^` |
| `$(^F)` | File parts of `$^` |

### Examples

```makefile
# Basic usage
hello: hello.o utils.o
	$(CC) $(LDFLAGS) $^ -o $@
	# Expands to: gcc -o hello hello.o utils.o

# Pattern rule
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@
	# For hello.c: gcc -Wall -c hello.c -o hello.o

# Creating output directory
build/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@
	# $(@D) = "build"
```

### Advanced Automatic Variables Usage

```makefile
# Dependency generation with automatic variables
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) \
		-MMD -MP \
		-MF $(@:.o=.d) \
		-c $< -o $@
	# $@ = build/obj/main.o
	# $< = src/main.c
	# $(@:.o=.d) = build/obj/main.d
```

## Variable Substitution and Functions

### Pattern Substitution

```makefile
# $(var:pattern=replacement)
SOURCES := src/main.c src/utils.c src/helper.c
OBJECTS := $(SOURCES:.c=.o)
# OBJECTS = src/main.o src/utils.o src/helper.o

OBJECTS := $(SOURCES:src/%.c=build/%.o)
# OBJECTS = build/main.o build/utils.o build/helper.o
```

### Text Functions

```makefile
# $(wildcard pattern)
SOURCES := $(wildcard src/*.c)

# $(patsubst pattern,replacement,text)
OBJECTS := $(patsubst %.c,%.o,$(SOURCES))

# $(filter pattern...,text)
C_FILES := $(filter %.c,$(SOURCES))

# $(filter-out pattern...,text)
NO_TEST := $(filter-out %_test.c,$(SOURCES))

# $(sort list)
SORTED := $(sort $(SOURCES))

# $(dir names...)
DIRS := $(dir $(SOURCES))

# $(notdir names...)
FILES := $(notdir $(SOURCES))

# $(basename names...)
NAMES := $(basename $(SOURCES))

# $(suffix names...)
EXTS := $(suffix $(SOURCES))

# $(addprefix prefix,names...)
FULL_PATHS := $(addprefix $(SRCDIR)/,$(FILES))

# $(addsuffix suffix,names...)
OBJ_FILES := $(addsuffix .o,$(NAMES))
```

### Shell Function

```makefile
# $(shell command)
GIT_VERSION := $(shell git describe --tags --always 2>/dev/null)
DATE := $(shell date +%Y-%m-%d)
CPU_COUNT := $(shell nproc 2>/dev/null || echo 1)

# Use := to evaluate once
VERSION := $(shell cat VERSION.txt)
```

### Conditional Functions

```makefile
# $(if condition,then-part,else-part)
DEBUG := 1
CFLAGS := $(if $(DEBUG),-g -O0,-O2)

# $(or conditions...)
CC := $(or $(CC),gcc)

# $(and conditions...)
BUILD_TESTS := $(and $(ENABLE_TESTS),$(HAVE_CHECK))
```

## Environment Variables

### Interaction with Environment

```makefile
# Make variables override environment by default
CC = gcc  # Overrides CC from environment

# Use ?= to respect environment
CC ?= gcc  # Uses environment CC if set

# Export variables to recipes
export CC
export CFLAGS

# Unexport variables
unexport INTERNAL_VAR
```

### Checking Environment Variables

```makefile
# Check if variable is defined
ifndef CC
CC := gcc
endif

# Check if variable is empty
ifeq ($(strip $(CC)),)
$(error CC is not defined)
endif
```

## Target-Specific Variables

```makefile
# Variables can be set for specific targets
debug: CFLAGS += -g -O0 -DDEBUG
debug: $(TARGET)

release: CFLAGS += -O3 -DNDEBUG
release: $(TARGET)

# Pattern-specific variables
tests/%: CFLAGS += -DTESTING
tests/%: LDLIBS += -lcheck
```

## Best Practices

### 1. Variable Naming

```makefile
# Use UPPERCASE for user-overridable variables
CC ?= gcc
PREFIX ?= /usr/local

# Use lowercase or mixed case for internal variables
sources := $(wildcard src/*.c)
target_name := myapp

# Use descriptive names
SOURCES := $(wildcard src/*.c)  # Good
S := $(wildcard src/*.c)         # Bad
```

### 2. Variable Organization

```makefile
# Group related variables
# ============================================
# User Configuration
# ============================================
CC ?= gcc
CFLAGS ?= -Wall -O2
PREFIX ?= /usr/local

# ============================================
# Project Configuration
# ============================================
PROJECT := myapp
VERSION := 1.0.0
SOURCES := $(wildcard src/*.c)
```

### 3. Preserve User Flags

```makefile
# WRONG: Overwrites user flags
CFLAGS = -Wall -O2

# RIGHT: Provides default, respects user override
CFLAGS ?= -Wall -O2

# Add project-specific flags
CFLAGS += -I./include
```

### 4. Use pkg-config

```makefile
# WRONG: Hardcoded paths
CFLAGS += -I/usr/include/openssl
LDLIBS += -L/usr/lib -lssl -lcrypto

# RIGHT: Use pkg-config
PKG_CONFIG ?= pkg-config
CFLAGS += $(shell $(PKG_CONFIG) --cflags openssl)
LDLIBS += $(shell $(PKG_CONFIG) --libs openssl)
```

### 5. Use := for Computed Values

```makefile
# WRONG: Re-computes every use (slow)
SOURCES = $(wildcard src/*.c)
OBJECTS = $(SOURCES:.c=.o)

# RIGHT: Computes once (fast)
SOURCES := $(wildcard src/*.c)
OBJECTS := $(SOURCES:.c=.o)
```

## Complete Example

```makefile
# ============================================
# User-Overridable Variables
# ============================================
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
LDFLAGS ?=
LDLIBS ?=
PREFIX ?= /usr/local
DESTDIR ?=

# ============================================
# pkg-config Dependencies
# ============================================
PKG_CONFIG ?= pkg-config
PACKAGES := openssl zlib

CFLAGS += $(shell $(PKG_CONFIG) --cflags $(PACKAGES))
LDLIBS += $(shell $(PKG_CONFIG) --libs $(PACKAGES))

# ============================================
# Project Configuration
# ============================================
PROJECT := myapp
VERSION := 1.0.0
SRCDIR := src
BUILDDIR := build

# Computed values (use :=)
SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)
DEPENDS := $(OBJECTS:.o=.d)
TARGET := $(BUILDDIR)/$(PROJECT)

# Git version
GIT_VERSION := $(shell git describe --tags --always 2>/dev/null || echo "unknown")
CFLAGS += -DVERSION=\"$(GIT_VERSION)\"

# ============================================
# Build Rules
# ============================================
all: $(TARGET)

$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPENDS)

# ============================================
# Target-Specific Variables
# ============================================
debug: CFLAGS += -g -O0 -DDEBUG
debug: $(TARGET)

release: CFLAGS += -O3 -DNDEBUG -s
release: $(TARGET)
```

## References

- [GNU Make Manual - Variables](https://www.gnu.org/software/make/manual/html_node/Using-Variables.html)
- [GNU Make Manual - Automatic Variables](https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html)
- [GNU Coding Standards - Makefile Conventions](https://www.gnu.org/prep/standards/html_node/Makefile-Conventions.html)