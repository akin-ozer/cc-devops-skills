# Makefile Targets Guide

## Overview

This guide covers target definitions, standard GNU targets, .PHONY declarations, dependencies, pattern rules, and best practices for organizing targets in Makefiles.

## Target Basics

### Target Syntax

```makefile
target: prerequisites
	recipe
	recipe
	...
```

- **target**: File to create or action to perform
- **prerequisites**: Files/targets that must exist or be up-to-date
- **recipe**: Shell commands to run (must be indented with TAB)

### Simple Example

```makefile
hello: hello.c
	gcc hello.c -o hello
```

**How it works:**
1. Check if `hello` exists and is newer than `hello.c`
2. If not, run the recipe
3. Recipe creates `hello`

## .PHONY Targets

### What are .PHONY Targets?

Phony targets don't represent actual files. They represent actions:

```makefile
.PHONY: clean
clean:
	rm -f *.o myprogram
```

**Without .PHONY:**
- If a file named "clean" exists, `make clean` won't run
- make thinks the target is already up-to-date

**With .PHONY:**
- make always runs the recipe
- Performance improvement (skips unnecessary file system checks)

### Common .PHONY Targets

```makefile
.PHONY: all clean install uninstall test check help
.PHONY: build dist distclean format lint docs
```

### Multiple .PHONY Declarations

```makefile
# Option 1: All at once (recommended)
.PHONY: all clean install test help

# Option 2: Separate declarations
.PHONY: all
.PHONY: clean
.PHONY: install
```

## Standard GNU Targets

GNU Coding Standards define standard targets that users expect:

### Essential Targets

#### all (Default Target)

```makefile
## Build all targets
.PHONY: all
all: $(TARGET)
```

**Requirements:**
- Should be the first target (default)
- Should compile the entire program
- Should NOT install, clean, or run tests
- Should create the primary output (executable, library, etc.)

#### install

```makefile
## Install built files to PREFIX
.PHONY: install
install: all
	$(INSTALL) -d $(DESTDIR)$(BINDIR)
	$(INSTALL_PROGRAM) $(TARGET) $(DESTDIR)$(BINDIR)/
	$(INSTALL) -d $(DESTDIR)$(LIBDIR)
	$(INSTALL_DATA) lib$(PROJECT).a $(DESTDIR)$(LIBDIR)/
	$(INSTALL) -d $(DESTDIR)$(INCLUDEDIR)
	$(INSTALL_DATA) $(PROJECT).h $(DESTDIR)$(INCLUDEDIR)/
	$(INSTALL) -d $(DESTDIR)$(MAN1DIR)
	$(INSTALL_DATA) docs/$(PROJECT).1 $(DESTDIR)$(MAN1DIR)/
```

**Requirements:**
- Should depend on `all` to build first
- Should respect `DESTDIR` and `PREFIX`
- Should create necessary directories
- Should set appropriate permissions
- Should be idempotent (safe to run multiple times)

#### uninstall

```makefile
## Remove installed files
.PHONY: uninstall
uninstall:
	$(RM) $(DESTDIR)$(BINDIR)/$(TARGET)
	$(RM) $(DESTDIR)$(LIBDIR)/lib$(PROJECT).a
	$(RM) $(DESTDIR)$(INCLUDEDIR)/$(PROJECT).h
	$(RM) $(DESTDIR)$(MAN1DIR)/$(PROJECT).1
```

#### clean

```makefile
## Remove built files (keep configuration)
.PHONY: clean
clean:
	$(RM) $(OBJECTS) $(TARGET)
	$(RM) -r $(BUILDDIR)
	$(RM) *.o *.a *.so
```

**Requirements:**
- Remove object files, executables, libraries
- Keep configuration files and Makefile
- Should allow rebuilding without reconfiguring

#### distclean

```makefile
## Remove all generated files (including configuration)
.PHONY: distclean
distclean: clean
	$(RM) config.h config.log config.status
	$(RM) Makefile
	$(RM) -r autom4te.cache/
```

**Requirements:**
- Should depend on `clean`
- Remove configure-generated files
- Leave only source files
- After distclean, only `./configure` should work

### Testing Targets

#### test

```makefile
## Run tests
.PHONY: test
test: $(TARGET)
	@echo "Running tests..."
	./run_tests.sh
	$(TARGET) --self-test
	@echo "All tests passed!"
```

#### check

```makefile
## Alias for test (GNU convention)
.PHONY: check
check: test
```

### Distribution Targets

#### dist

```makefile
## Create distribution tarball
.PHONY: dist
dist:
	@mkdir -p dist
	tar -czf dist/$(PROJECT)-$(VERSION).tar.gz \
		--transform 's,^,$(PROJECT)-$(VERSION)/,' \
		--exclude='.git*' \
		--exclude='*.o' \
		--exclude='*.a' \
		--exclude='$(BUILDDIR)' \
		.
```

#### distcheck

```makefile
## Create and verify distribution tarball
.PHONY: distcheck
distcheck: dist
	@echo "Verifying distribution..."
	@mkdir -p $(BUILDDIR)/distcheck
	tar -xzf dist/$(PROJECT)-$(VERSION).tar.gz -C $(BUILDDIR)/distcheck
	cd $(BUILDDIR)/distcheck/$(PROJECT)-$(VERSION) && ./configure && make && make check
	@echo "Distribution verified successfully!"
	$(RM) -r $(BUILDDIR)/distcheck
```

### Documentation Targets

#### help

```makefile
## Show available targets and usage
.PHONY: help
help:
	@echo "$(PROJECT) - version $(VERSION)"
	@echo ""
	@echo "Available targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':' | sed 's/^/  /'
	@echo ""
	@echo "Variables:"
	@echo "  PREFIX=$(PREFIX)"
	@echo "  CC=$(CC)"
	@echo "  CFLAGS=$(CFLAGS)"
	@echo ""
	@echo "Examples:"
	@echo "  make                    # Build the project"
	@echo "  make install            # Install to PREFIX"
	@echo "  make PREFIX=/opt/local  # Install to custom location"
	@echo "  make clean              # Remove built files"
```

**Self-documenting pattern:**
```makefile
## Build the application
.PHONY: build
build: $(TARGET)

## Run all tests
.PHONY: test
test:
	./run_tests.sh
```

The `##` comments are parsed by the help target.

## Target Dependencies

### Simple Dependencies

```makefile
# program depends on main.o and utils.o
program: main.o utils.o
	$(CC) $^ -o $@

# main.o depends on main.c
main.o: main.c
	$(CC) -c $< -o $@
```

### Multiple Targets

```makefile
# Multiple targets with same recipe
main.o utils.o helper.o: common.h
	$(CC) -c $*.c -o $@
```

### Order-Only Prerequisites

```makefile
# Normal prerequisites: update target if prerequisite changes
# Order-only prerequisites (|): only check existence, not timestamp

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) -c $< -o $@

# $(OBJDIR) must exist, but changes to it don't trigger rebuild
$(OBJDIR):
	mkdir -p $@
```

**Use cases:**
- Directory creation (directory timestamp changes don't matter)
- Lock files
- State files

### Circular Dependencies

```makefile
# WRONG: Circular dependency
a: b
b: a
# Error: Circular a <- b dependency dropped

# RIGHT: Break the cycle
a: c
b: c
c:
	touch c
```

## Pattern Rules

### Basic Pattern Rules

```makefile
# Compile .c to .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Compile .c to .s (assembly)
%.s: %.c
	$(CC) $(CFLAGS) -S $< -o $@

# Create .c from .y (yacc)
%.c: %.y
	$(YACC) $(YFLAGS) -o $@ $<
```

### Pattern Rules with Directories

```makefile
# Match files in specific directories
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@

# Multiple directory patterns
build/obj/%.o: src/%.c
	$(CC) -c $< -o $@

build/obj/%.o: lib/%.c
	$(CC) -c $< -o $@
```

### Static Pattern Rules

More efficient than pattern rules for specific files:

```makefile
OBJECTS := main.o utils.o helper.o

# Static pattern: $(targets): target-pattern: prereq-pattern
$(OBJECTS): %.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Equivalent to:
# main.o: main.c
# utils.o: utils.c
# helper.o: helper.c
```

**Advantages:**
- More explicit than pattern rules
- Faster (make knows exact targets)
- Easier to debug

### Multiple Pattern Rules

```makefile
# First matching rule is used
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

%.o: %.s
	$(AS) $(ASFLAGS) -c $< -o $@

%.o: %.asm
	$(NASM) $(NASMFLAGS) -f elf64 $< -o $@
```

## Target-Specific Variables

```makefile
# Set variable only for specific target and its prerequisites
debug: CFLAGS += -g -O0 -DDEBUG
debug: $(TARGET)

release: CFLAGS += -O3 -DNDEBUG
release: $(TARGET)

# Pattern-specific variables
test_%: CFLAGS += -DTESTING
test_%: LDLIBS += -lcheck
```

## Advanced Target Patterns

### Double-Colon Rules

```makefile
# Double-colon allows multiple recipes for same target
install::
	@echo "Installing binaries..."
	$(INSTALL) $(TARGET) $(BINDIR)/

install::
	@echo "Installing libraries..."
	$(INSTALL) lib$(PROJECT).a $(LIBDIR)/

# Each recipe runs independently
```

**Use cases:**
- Modular Makefiles with independent install steps
- Plugin systems
- Rarely needed

### Intermediate Files

```makefile
# Mark files as intermediate (deleted after use)
.INTERMEDIATE: $(OBJECTS)

# Keep specific intermediate files
.SECONDARY: important.o

# Never delete these intermediate files
.PRECIOUS: %.o
```

### Automatic Prerequisites

```makefile
# Generate dependencies automatically
DEPENDS := $(OBJECTS:.o=.d)

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Include generated dependencies
-include $(DEPENDS)
```

## Complete Examples

### Example 1: Simple C Project

```makefile
.DELETE_ON_ERROR:

CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
PREFIX ?= /usr/local

TARGET := hello
SOURCES := hello.c
OBJECTS := $(SOURCES:.c=.o)

.PHONY: all clean install uninstall help

## Build the program (default)
all: $(TARGET)

## Compile and link
$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

## Install to PREFIX
install: $(TARGET)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/

## Remove installed files
uninstall:
	$(RM) $(DESTDIR)$(PREFIX)/bin/$(TARGET)

## Remove built files
clean:
	$(RM) $(OBJECTS) $(TARGET)

## Show this help
help:
	@echo "Available targets:"
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
```

### Example 2: Multi-Directory Project

```makefile
.DELETE_ON_ERROR:

PROJECT := myapp
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

## Build everything (default)
all: $(TARGET)

## Link executable
$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	@echo "  LD      $@"
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

## Compile source files
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	@echo "  CC      $<"
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

## Show available targets
help:
	@sed -n 's/^## //p' $(MAKEFILE_LIST)
```

### Example 3: Library Project

```makefile
.DELETE_ON_ERROR:

PROJECT := mylib
VERSION := 1.0.0
CC ?= gcc
AR ?= ar
RANLIB ?= ranlib
PREFIX ?= /usr/local

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
HEADERS := $(wildcard $(SRCDIR)/*.h)

STATIC_LIB := $(BUILDDIR)/lib$(PROJECT).a
SHARED_LIB := $(BUILDDIR)/lib$(PROJECT).so.$(VERSION)

.PHONY: all static shared clean install install-static install-shared

## Build both static and shared libraries
all: static shared

## Build static library
static: $(STATIC_LIB)

## Build shared library
shared: $(SHARED_LIB)

## Create static library
$(STATIC_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	@echo "  AR      $@"
	$(AR) rcs $@ $^
	$(RANLIB) $@

## Create shared library
$(SHARED_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	@echo "  LD      $@"
	$(CC) -shared -Wl,-soname,lib$(PROJECT).so.1 $^ -o $@
	ln -sf lib$(PROJECT).so.$(VERSION) $(BUILDDIR)/lib$(PROJECT).so.1
	ln -sf lib$(PROJECT).so.1 $(BUILDDIR)/lib$(PROJECT).so

## Compile with -fPIC for shared library
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	@echo "  CC      $<"
	$(CC) $(CPPFLAGS) $(CFLAGS) -fPIC -c $< -o $@

## Install both libraries
install: install-static install-shared

## Install static library
install-static: $(STATIC_LIB)
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 644 $(STATIC_LIB) $(DESTDIR)$(PREFIX)/lib/
	install -d $(DESTDIR)$(PREFIX)/include/$(PROJECT)
	install -m 644 $(HEADERS) $(DESTDIR)$(PREFIX)/include/$(PROJECT)/

## Install shared library
install-shared: $(SHARED_LIB)
	install -d $(DESTDIR)$(PREFIX)/lib
	install -m 755 $(SHARED_LIB) $(DESTDIR)$(PREFIX)/lib/
	ln -sf lib$(PROJECT).so.$(VERSION) $(DESTDIR)$(PREFIX)/lib/lib$(PROJECT).so.1
	ln -sf lib$(PROJECT).so.1 $(DESTDIR)$(PREFIX)/lib/lib$(PROJECT).so
	ldconfig

## Clean build artifacts
clean:
	$(RM) -r $(BUILDDIR)
```

## Best Practices

1. **Use .PHONY for non-file targets**
2. **Implement standard GNU targets** (all, install, clean, test)
3. **Make 'all' the default target** (first target)
4. **Use automatic variables** ($@, $<, $^) for concise rules
5. **Create directories automatically** (@mkdir -p $(@D))
6. **Document targets with ## comments**
7. **Use static pattern rules** for better performance
8. **Include .DELETE_ON_ERROR** to prevent corrupted builds
9. **Use order-only prerequisites** for directory creation
10. **Generate dependencies automatically** (-MMD -MP)

## References

- [GNU Make Manual - Rules](https://www.gnu.org/software/make/manual/html_node/Rules.html)
- [GNU Make Manual - Phony Targets](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html)
- [GNU Coding Standards - Standard Targets](https://www.gnu.org/prep/standards/html_node/Standard-Targets.html)