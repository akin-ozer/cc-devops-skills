# Makefile Patterns Guide

## Overview

This guide covers pattern rules, static pattern rules, implicit rules, dependency generation, and common Makefile patterns for various project types.

## Pattern Rules

Pattern rules use `%` to match filenames and create generic build rules.

### Basic Pattern Rules

```makefile
# Compile .c files to .o files
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Generate assembly from C
%.s: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -S $< -o $@

# Preprocess C files
%.i: %.c
	$(CC) $(CPPFLAGS) -E $< -o $@
```

### Pattern Rules with Directories

```makefile
# Source in src/, objects in build/obj/
build/obj/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Multiple source directories
build/obj/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) -c $< -o $@

build/obj/%.o: lib/%.c
	@mkdir -p $(@D)
	$(CC) -c $< -o $@
```

### Pattern Rule Variables

```makefile
# Use stem ($*) in pattern rules
%.pdf: %.tex
	pdflatex $*
	# Runs: pdflatex report (for report.tex -> report.pdf)

# Multiple transformations
%.html: %.md
	pandoc $< -o $@

%.pdf: %.md
	pandoc $< -o $@
```

## Static Pattern Rules

More efficient and explicit than pattern rules for known file lists.

### Syntax

```makefile
$(targets): target-pattern: prereq-pattern
	recipe
```

### Basic Example

```makefile
OBJECTS := main.o utils.o helper.o

# Static pattern rule
$(OBJECTS): %.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Equivalent to:
# main.o: main.c
#     $(CC) $(CFLAGS) -c main.c -o main.o
# utils.o: utils.c
#     $(CC) $(CFLAGS) -c utils.c -o utils.o
# helper.o: helper.c
#     $(CC) $(CFLAGS) -c helper.c -o helper.o
```

### With Directories

```makefile
SOURCES := $(wildcard src/*.c)
OBJECTS := $(SOURCES:src/%.c=build/obj/%.o)

$(OBJECTS): build/obj/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@
```

### Multiple Dependencies

```makefile
# All objects depend on config.h
$(OBJECTS): %.o: %.c config.h
	$(CC) $(CFLAGS) -c $< -o $@

# Specific objects depend on additional headers
$(NETWORK_OBJS): %.o: %.c network.h common.h
	$(CC) $(CFLAGS) -c $< -o $@
```

## Implicit Rules

GNU Make has built-in implicit rules. You can use or override them.

### Common Built-in Rules

```makefile
# These rules are built into make:
# %.o: %.c
#     $(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# %.o: %.cpp
#     $(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

# %: %.o
#     $(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@
```

### Disabling Implicit Rules

```makefile
# Disable all built-in rules (recommended for explicit Makefiles)
.SUFFIXES:

# Re-enable specific patterns
.SUFFIXES: .c .o .h

# Or disable specific rules
%.o: %.c
# Empty recipe disables the built-in rule
```

### Custom Implicit Rules

```makefile
# Add your own implicit rules
%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Language-specific rules
%.o: %.cpp
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

%.o: %.s
	$(AS) $(ASFLAGS) -c $< -o $@
```

## Dependency Generation

### Manual Dependencies (Avoid)

```makefile
# Tedious and error-prone
main.o: main.c common.h utils.h
utils.o: utils.c utils.h common.h
helper.o: helper.c helper.h common.h
```

### Automatic Dependency Generation

**Method 1: Embedded in compilation:**

```makefile
SOURCES := $(wildcard src/*.c)
OBJECTS := $(SOURCES:src/%.c=build/obj/%.o)
DEPENDS := $(OBJECTS:.o=.d)

# Generate dependencies during compilation
build/obj/%.o: src/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Include generated dependency files
-include $(DEPENDS)
```

**Flags explained:**
- `-MMD`: Generate dependency file (.d)
- `-MP`: Add phony targets for headers (prevents errors if header deleted)
- `-MF file`: Specify dependency file name (optional)

**Method 2: Separate dependency generation:**

```makefile
# Generate dependencies separately
%.d: %.c
	@$(CC) $(CPPFLAGS) -MM $< | sed 's,\($*\)\.o[ :]*,\1.o $@ : ,g' > $@

-include $(DEPENDS)
```

**Generated .d file example:**

```makefile
# main.d (generated from main.c)
build/obj/main.o build/obj/main.d: src/main.c include/common.h \
  include/utils.h
include/common.h:
include/utils.h:
```

## Common Project Patterns

### Pattern 1: Simple Single-Directory C Project

```makefile
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

TARGET := myapp
SOURCES := $(wildcard *.c)
OBJECTS := $(SOURCES:.c=.o)
DEPENDS := $(OBJECTS:.o=.d)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

%.o: %.c
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPENDS)

clean:
	$(RM) $(TARGET) $(OBJECTS) $(DEPENDS)
```

### Pattern 2: Multi-Directory C Project

```makefile
PROJECT := myapp
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2 -Iinclude

SRCDIR := src
INCDIR := include
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
DEPENDS := $(OBJECTS:.o=.d)
TARGET := $(BUILDDIR)/$(PROJECT)

.PHONY: all clean

all: $(TARGET)

$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(DEPENDS)

clean:
	$(RM) -r $(BUILDDIR)
```

### Pattern 3: C++ Project with Libraries

```makefile
PROJECT := myapp
CXX ?= g++
CXXFLAGS ?= -Wall -Wextra -std=c++17 -O2

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

# Source files
SOURCES := $(wildcard $(SRCDIR)/*.cpp)
OBJECTS := $(SOURCES:$(SRCDIR)/%.cpp=$(OBJDIR)/%.o)
DEPENDS := $(OBJECTS:.o=.d)

# Library
LIBNAME := $(PROJECT)
STATIC_LIB := $(BUILDDIR)/lib$(LIBNAME).a
SHARED_LIB := $(BUILDDIR)/lib$(LIBNAME).so

# Executable
TARGET := $(BUILDDIR)/$(PROJECT)

.PHONY: all static shared executable clean

all: executable

executable: $(TARGET)

static: $(STATIC_LIB)

shared: $(SHARED_LIB)

# Link executable
$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

# Create static library
$(STATIC_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	$(AR) rcs $@ $^

# Create shared library
$(SHARED_LIB): $(OBJECTS)
	@mkdir -p $(@D)
	$(CXX) -shared $^ -o $@

# Compile with -fPIC for libraries
$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -fPIC -MMD -MP -c $< -o $@

-include $(DEPENDS)

clean:
	$(RM) -r $(BUILDDIR)
```

### Pattern 4: Mixed C/C++ Project

```makefile
PROJECT := mixed
CC ?= gcc
CXX ?= g++
CFLAGS ?= -Wall -O2
CXXFLAGS ?= -Wall -O2 -std=c++17

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

# Separate C and C++ sources
C_SOURCES := $(wildcard $(SRCDIR)/*.c)
CXX_SOURCES := $(wildcard $(SRCDIR)/*.cpp)

# Separate object files
C_OBJECTS := $(C_SOURCES:$(SRCDIR)/%.c=$(OBJDIR)/%.o)
CXX_OBJECTS := $(CXX_SOURCES:$(SRCDIR)/%.cpp=$(OBJDIR)/%.o)

ALL_OBJECTS := $(C_OBJECTS) $(CXX_OBJECTS)
DEPENDS := $(ALL_OBJECTS:.o=.d)

TARGET := $(BUILDDIR)/$(PROJECT)

.PHONY: all clean

all: $(TARGET)

# Link with C++ compiler (for C++ standard library)
$(TARGET): $(ALL_OBJECTS)
	@mkdir -p $(@D)
	$(CXX) $(LDFLAGS) $^ $(LDLIBS) -o $@

# Compile C sources
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

# Compile C++ sources
$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	@mkdir -p $(@D)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -MMD -MP -c $< -o $@

-include $(DEPENDS)

clean:
	$(RM) -r $(BUILDDIR)
```

### Pattern 5: Go Project

```makefile
PROJECT := myapp
GO ?= go
GOFLAGS ?=
PREFIX ?= /usr/local

# Version from git
VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS := -ldflags "-X main.version=$(VERSION)"

# Source files
SOURCES := $(shell find . -name '*.go' -not -path './vendor/*')
TARGET := $(PROJECT)

.PHONY: all build install test clean fmt lint mod-tidy

all: build

build: $(TARGET)

$(TARGET): $(SOURCES) go.mod go.sum
	$(GO) build $(GOFLAGS) $(LDFLAGS) -o $@ ./cmd/$(PROJECT)

install: $(TARGET)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/

test:
	$(GO) test -v ./...

clean:
	$(RM) $(TARGET)
	$(GO) clean

fmt:
	$(GO) fmt ./...

lint:
	golangci-lint run

mod-tidy:
	$(GO) mod tidy
```

### Pattern 6: Python Project

```makefile
PROJECT := mypackage
PYTHON ?= python3
PIP ?= $(PYTHON) -m pip

.PHONY: all build install develop test lint format clean

all: build

build:
	$(PYTHON) -m build

install:
	$(PIP) install .

develop:
	$(PIP) install -e .[dev]

test:
	$(PYTHON) -m pytest tests/ -v

lint:
	$(PYTHON) -m flake8 src/ tests/
	$(PYTHON) -m pylint src/

format:
	$(PYTHON) -m black src/ tests/
	$(PYTHON) -m isort src/ tests/

clean:
	$(RM) -r build/ dist/ *.egg-info/
	$(RM) -r .pytest_cache/ .coverage htmlcov/
	find . -type d -name '__pycache__' -exec rm -r {} +
	find . -type f -name '*.pyc' -delete
```

### Pattern 7: Multi-Binary Project

```makefile
PROJECT := tools
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2

SRCDIR := src
BUILDDIR := build
OBJDIR := $(BUILDDIR)/obj

# Multiple programs
PROGRAMS := tool1 tool2 tool3
TARGETS := $(addprefix $(BUILDDIR)/,$(PROGRAMS))

# Common library
LIBSRC := $(wildcard $(SRCDIR)/common/*.c)
LIBOBJ := $(LIBSRC:$(SRCDIR)/%.c=$(OBJDIR)/%.o)

.PHONY: all clean $(PROGRAMS)

all: $(TARGETS)

# Individual program targets
tool1: $(BUILDDIR)/tool1
tool2: $(BUILDDIR)/tool2
tool3: $(BUILDDIR)/tool3

# Build each program
$(BUILDDIR)/tool1: $(OBJDIR)/tool1.o $(LIBOBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILDDIR)/tool2: $(OBJDIR)/tool2.o $(LIBOBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILDDIR)/tool3: $(OBJDIR)/tool3.o $(LIBOBJ)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

# Compile pattern
$(OBJDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -c $< -o $@

clean:
	$(RM) -r $(BUILDDIR)
```

### Pattern 8: Docker Integration

```makefile
PROJECT := myapp
VERSION := 1.0.0
REGISTRY := docker.io
IMAGE := $(REGISTRY)/$(PROJECT):$(VERSION)
IMAGE_LATEST := $(REGISTRY)/$(PROJECT):latest

.PHONY: all build docker-build docker-push docker-run docker-clean

all: build

build:
	$(MAKE) -f Makefile.app

docker-build:
	docker build -t $(IMAGE) -t $(IMAGE_LATEST) .

docker-push: docker-build
	docker push $(IMAGE)
	docker push $(IMAGE_LATEST)

docker-run: docker-build
	docker run --rm -it $(IMAGE)

docker-clean:
	docker rmi $(IMAGE) $(IMAGE_LATEST) 2>/dev/null || true
```

## Advanced Patterns

### Pattern: Recursive Directory Processing

```makefile
# Find all .c files recursively
SOURCES := $(shell find src -name '*.c')

# Mirror directory structure in build/
OBJECTS := $(SOURCES:src/%.c=build/obj/%.o)

# Create all necessary directories
OBJDIRS := $(sort $(dir $(OBJECTS)))

$(OBJDIRS):
	@mkdir -p $@

# Order-only prerequisite: directories must exist
$(OBJECTS): | $(OBJDIRS)

build/obj/%.o: src/%.c
	$(CC) $(CFLAGS) -c $< -o $@
```

### Pattern: Multiple Build Configurations

```makefile
BUILD_TYPES := debug release profile

.PHONY: all $(BUILD_TYPES) clean

all: release

# Target-specific variables
debug: CFLAGS += -g -O0 -DDEBUG
debug: TARGET := build/debug/$(PROJECT)
debug: $(TARGET)

release: CFLAGS += -O3 -DNDEBUG
release: TARGET := build/release/$(PROJECT)
release: $(TARGET)

profile: CFLAGS += -pg -O2
profile: TARGET := build/profile/$(PROJECT)
profile: $(TARGET)

# Generic build rule
$(TARGET): $(OBJECTS)
	@mkdir -p $(@D)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@
```

### Pattern: Parallel Sub-Builds

```makefile
SUBDIRS := lib1 lib2 lib3

.PHONY: all $(SUBDIRS)

# Build subdirs in parallel: make -j4
all: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

# Dependencies between subdirs
lib2: lib1
lib3: lib1 lib2
```

## Best Practices

1. **Use static pattern rules** for known file lists (more efficient)
2. **Generate dependencies automatically** (-MMD -MP)
3. **Create directories with order-only prerequisites**
4. **Disable built-in rules** (.SUFFIXES:) for explicit Makefiles
5. **Use pattern rules** for generic transformations
6. **Mirror source structure** in build directory
7. **Separate C and C++ compilation** in mixed projects
8. **Use -fPIC** when building shared libraries
9. **Include generated dependencies** with -include
10. **Test patterns** with make -n (dry run)

## References

- [GNU Make Manual - Pattern Rules](https://www.gnu.org/software/make/manual/html_node/Pattern-Rules.html)
- [GNU Make Manual - Static Pattern Rules](https://www.gnu.org/software/make/manual/html_node/Static-Pattern.html)
- [GNU Make Manual - Automatic Prerequisites](https://www.gnu.org/software/make/manual/html_node/Automatic-Prerequisites.html)