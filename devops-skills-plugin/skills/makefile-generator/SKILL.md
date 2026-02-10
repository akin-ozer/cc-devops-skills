---
name: makefile-generator
description: Comprehensive toolkit for generating best practice Makefiles following current standards and conventions. Use this skill when creating new Makefiles, implementing build automation, or building production-ready build systems.
---

# Makefile Generator

## Overview

Generate production-ready Makefiles with best practices for C/C++, Python, Go, Java, and generic projects. Features GNU Coding Standards compliance, standard targets, security hardening, and automatic validation via devops-skills:makefile-validator skill.

## When to Use

- Creating new Makefiles from scratch
- Setting up build systems for projects (C/C++, Python, Go, Java)
- Implementing build automation and CI/CD integration
- Converting manual build processes to Makefiles
- The user asks to "create", "generate", or "write" a Makefile

**Do NOT use for:** Validating existing Makefiles (use devops-skills:makefile-validator), debugging (use `make -d`), or running builds.

## Generation Workflow

### Stage 1: Gather Requirements

Collect information for the following categories. **Use AskUserQuestion when information is missing or ambiguous:**

| Category | Information Needed |
|----------|-------------------|
| **Project** | Language (C/C++/Python/Go/Java), structure (single/multi-directory) |
| **Build** | Source files, output artifacts, dependencies, build order |
| **Install** | PREFIX location, directories (bin/lib/share), files to install |
| **Targets** | all, install, clean, test, dist, help (which are needed?) |
| **Config** | Compiler, flags, pkg-config dependencies, cross-compilation |

**When to Use AskUserQuestion (MUST ask if any apply):**

| Condition | Example Question |
|-----------|------------------|
| Language not specified | "What programming language is this project? (C/C++/Go/Python/Java)" |
| Project structure unclear | "Is this a single-directory or multi-directory project?" |
| Docker requested but registry unknown | "Which container registry should be used? (docker.io/ghcr.io/custom)" |
| Multiple binaries possible | "Should this build a single binary or multiple executables?" |
| Install targets needed but paths unclear | "Where should binaries be installed? (default: /usr/local/bin)" |
| Cross-compilation mentioned | "What is the target platform/architecture?" |

**When to Skip AskUserQuestion (proceed with defaults):**
- User explicitly provides all required information
- Standard project type with obvious defaults (e.g., "Go project with Docker" → use standard Go+Docker patterns)
- User says "use defaults" or "standard setup"

**Default Assumptions (when not asking):**
- Single-directory project structure
- PREFIX=/usr/local
- Standard targets: all, build, test, clean, install, help
- No cross-compilation

### Stage 2: Documentation Lookup

**When REQUIRED (MUST perform lookup):**
- User requests integration with unfamiliar tools, frameworks, or build systems
- Complex build patterns not covered in Stage 3 examples (e.g., Bazel, Meson, custom toolchains)
- **Docker/container integration** (Dockerfile builds, multi-stage, registry push)
- CI/CD platform-specific integration (GitHub Actions, GitLab CI, Jenkins)
- Cross-compilation for unusual targets or embedded systems
- Package manager integration (Conan, vcpkg, Homebrew formulas)
- **Multi-binary or multi-library projects**
- **Version embedding via ldflags or build-time variables**

**When OPTIONAL (may skip external lookup):**
- Standard language patterns already covered in Stage 3 (C/C++, Go, Python, Java)
- Simple single-binary projects with no external dependencies
- User provides complete requirements with no ambiguity
- Internal docs already cover the required pattern comprehensively

**Lookup Process (follow in order):**

1. **ALWAYS consult internal docs/ FIRST using the Read tool** (primary source of truth):

   | Requirement | Read This Doc |
   |-------------|---------------|
   | Docker/container targets | `docs/patterns-guide.md` (Pattern 8: Docker Integration) |
   | Multi-binary projects | `docs/patterns-guide.md` (Pattern 7: Multi-Binary Project) |
   | Go projects with version embedding | `docs/patterns-guide.md` (Pattern 5: Go Project) |
   | Parallel builds, caching, ccache | `docs/optimization-guide.md` |
   | Credentials, secrets, API keys | `docs/security-guide.md` |
   | Complex dependencies, pattern rules | `docs/patterns-guide.md` |
   | Order-only prerequisites | `docs/optimization-guide.md` or `docs/targets-guide.md` |
   | Variables, assignment operators | `docs/variables-guide.md` |

   **CRITICAL:** You MUST explicitly use the Read tool to consult relevant docs during generation, even if you have prior knowledge. Do NOT rely on context from earlier in the conversation. This ensures patterns are always current and correctly applied.

   **Required Workflow Example (Docker + Go with version embedding):**
   ```
   # Step 1: Use Read tool to get Go pattern
   Read: docs/patterns-guide.md (find Pattern 5: Go Project)

   # Step 2: Use Read tool to get Docker pattern
   Read: docs/patterns-guide.md (find Pattern 8: Docker Integration)

   # Step 3: Use Read tool for security considerations
   Read: docs/security-guide.md (credential handling for docker-push)

   # Step 4: Generate Makefile combining patterns
   # Step 5: Document which docs were consulted in Makefile header
   ```

   **Important:** Internal docs contain vetted, production-ready patterns. Always read the relevant docs before external lookups.

2. **Try context7 for external tool documentation** (when internal docs don't cover a specific tool):
   ```
   # Only needed for tools/frameworks NOT covered in internal docs
   mcp__context7__resolve-library-id: "<tool-name>"
   mcp__context7__get-library-docs: topic="<integration-topic>"

   # Example topics:
   # - For Docker: topic="dockerfile best practices"
   # - For Go: topic="go build ldflags"
   # - For specific tools: topic="<tool> makefile integration"
   ```
   **Note:** Context7 may not have GNU Make-specific documentation. Skip if internal docs provide sufficient patterns.

3. **Fallback to WebSearch** (only if pattern not found in internal docs OR context7):
   ```
   "<specific-feature>" makefile best practices 2025
   Example: "docker makefile best practices 2025"
   Example: "go ldflags version makefile 2025"
   ```
   **Trigger WebSearch when:** Internal docs don't cover the specific integration AND context7 returns no relevant results.

**Note:** Document which internal docs you consulted in your response (add comment in generated Makefile header).

### Stage 3: Generate Makefile

#### Header (choose one style)

**Traditional (POSIX-compatible):**
```makefile
.DELETE_ON_ERROR:
.SUFFIXES:
```

**Modern (GNU Make 4.0+, recommended):**
```makefile
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
.SUFFIXES:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
```

#### Standard Variables

```makefile
# User-overridable (use ?=)
CC ?= gcc
CFLAGS ?= -Wall -Wextra -O2
PREFIX ?= /usr/local
DESTDIR ?=

# GNU installation directories
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
INCLUDEDIR ?= $(PREFIX)/include

# Project-specific (use :=)
PROJECT := myproject
VERSION := 1.0.0
SRCDIR := src
BUILDDIR := build
SOURCES := $(wildcard $(SRCDIR)/*.c)
OBJECTS := $(SOURCES:$(SRCDIR)/%.c=$(BUILDDIR)/%.o)
```

#### Language-Specific Build Rules

**C/C++:**
```makefile
$(TARGET): $(OBJECTS)
	$(CC) $(LDFLAGS) $^ $(LDLIBS) -o $@

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CPPFLAGS) $(CFLAGS) -MMD -MP -c $< -o $@

-include $(OBJECTS:.o=.d)
```

**Go:**
```makefile
$(TARGET): $(shell find . -name '*.go') go.mod
	go build -o $@ ./cmd/$(PROJECT)
```

**Python:**
```makefile
.PHONY: build
build:
	python -m build

.PHONY: develop
develop:
	pip install -e .[dev]
```

**Java:**
```makefile
$(BUILDDIR)/%.class: $(SRCDIR)/%.java
	@mkdir -p $(@D)
	javac -d $(BUILDDIR) -sourcepath $(SRCDIR) $<
```

#### Standard Targets

```makefile
.PHONY: all clean install uninstall test help

## Build all targets
all: $(TARGET)

## Install to PREFIX
install: all
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(TARGET) $(DESTDIR)$(BINDIR)/

## Remove built files
clean:
	$(RM) -r $(BUILDDIR) $(TARGET)

## Run tests
test:
	# Add test commands

## Show help
help:
	@echo "$(PROJECT) v$(VERSION)"
	@echo "Targets: all, install, clean, test, help"
	@echo "Override: make CC=clang PREFIX=/opt"
```

### Stage 4: Validate and Format

**CRITICAL: Always validate using devops-skills:makefile-validator skill.**

```
1. Generate Makefile following stages above
2. Invoke devops-skills:makefile-validator skill
3. Fix any errors identified (MUST have 0 errors)
4. Apply formatting fixes (see "Formatting Step" below)
5. Fix warnings (SHOULD fix; explain if skipped)
6. Address info items for large/production projects
7. Re-validate until checks pass
8. Output structured validation report (REQUIRED - see format below)
```

#### Formatting Step (REQUIRED)

When mbake reports formatting issues, you MUST either:

1. **Auto-apply formatting** (preferred for minor issues):
   ```bash
   mbake format <Makefile>
   ```

2. **Explain why not applied** (if formatting would break functionality):
   ```
   Formatting not applied because:
   - [specific reason, e.g., "heredoc syntax would be corrupted"]
   - Manual review recommended for: [specific lines]
   ```

**Formatting Decision Guide:**

| mbake Report | Action |
|--------------|--------|
| "Would reformat" with no specific issues | Auto-apply with `mbake format` |
| Specific whitespace/indentation issues | Auto-apply with `mbake format` |
| Issues in complex heredocs or multi-line strings | Skip formatting, explain in output |
| Issues in `# bake-format off` sections | Skip (intentionally disabled) |

**Validation Pass Criteria:**

| Level | Requirement | Action |
|-------|-------------|--------|
| **Errors (0 required)** | Syntax errors, missing tabs, invalid targets | MUST fix before completion |
| **Warnings (fix if feasible)** | Formatting issues, missing optimizations | SHOULD fix; explain if skipped |
| **Info (address for production)** | Enhancement suggestions, style preferences | SHOULD address for production Makefiles |

**Known mbake False Positives (can be safely ignored):**

The mbake validator may report warnings for valid GNU Make special targets. These are false positives and can be ignored:

| mbake Warning | Actual Status | Explanation |
|---------------|---------------|-------------|
| "Unknown special target '.DELETE_ON_ERROR'" | ✅ Valid | Critical GNU Make target that deletes failed build artifacts |
| "Unknown special target '.SUFFIXES'" | ✅ Valid | Standard GNU Make target for disabling/setting suffix rules |
| "Unknown special target '.ONESHELL'" | ✅ Valid | GNU Make 3.82+ feature for single-shell recipe execution |
| "Unknown special target '.POSIX'" | ✅ Valid | POSIX compliance declaration |

#### Validation Report Output (REQUIRED)

After validation completes, you MUST output a structured report in the following format. This is not optional.

**Required Report Format:**

```
## Validation Report

**Result:** [PASSED / PASSED with warnings / FAILED]
**Errors:** [count]
**Warnings:** [count]
**Info:** [count]

### Errors Fixed
- [List each error and how it was fixed, or "None" if 0 errors]

### Warnings Addressed
- [List each warning that was fixed]

### Warnings Skipped (with reasons)
- [List each warning that was NOT fixed and explain why]
- Example: "mbake reports '.DELETE_ON_ERROR' as unknown - this is a valid GNU Make
  special target (false positive)"

### Formatting Applied
- [Yes/No] - [If No, explain why formatting was skipped]

### Info Items Addressed
- [List info items that were addressed for production Makefiles]
- [Or "N/A - simple project" if not applicable]

### Remaining Issues (if any)
- [List any issues requiring user attention]
- [Or "None - Makefile is production-ready"]
```

**Example Complete Report:**

```
## Validation Report

**Result:** PASSED with warnings
**Errors:** 0
**Warnings:** 2
**Info:** 1

### Errors Fixed
- None

### Warnings Addressed
- Fixed: Added error handling to install target (|| exit 1)

### Warnings Skipped (with reasons)
- mbake reports ".DELETE_ON_ERROR" as unknown - this is a valid and critical
  GNU Make special target that ensures failed builds don't leave corrupt files.
  See: https://www.gnu.org/software/make/manual/html_node/Special-Targets.html

### Formatting Applied
- Yes - Applied `mbake format` to fix whitespace issues

### Info Items Addressed
- Added .NOTPARALLEL for Docker targets (parallel safety)
- Added error handling for docker-push target

### Remaining Issues
- None - Makefile is production-ready
```

**Common Info Items to Address:**

| Info Item | When to Fix | How to Fix |
|-----------|-------------|------------|
| "mkdir without order-only prerequisites" | Large projects (>10 targets) | Use `target: prereqs \| $(BUILDDIR)` pattern |
| "recipe commands lack error handling" | Critical operations (install, deploy) | Add `set -e` in .SHELLFLAGS or use `&&` chaining |
| "consider using ccache" | Long compile times | Add `CC := ccache $(CC)` pattern |
| "parallel-sensitive commands detected" | Docker/npm/pip targets | Add `.NOTPARALLEL:` for affected targets or proper dependencies |

**Production-Quality Requirements (MUST address for Docker/deploy targets):**

When generating Makefiles with Docker or deployment targets, you MUST apply these production patterns:

1. **Error Handling for docker-push:**
   ```makefile
   ## Push Docker image to registry (with error handling)
   docker-push: docker-build
   	@echo "Pushing $(IMAGE)..."
   	docker push $(IMAGE) || { echo "Failed to push $(IMAGE)"; exit 1; }
   	docker push $(IMAGE_LATEST) || { echo "Failed to push $(IMAGE_LATEST)"; exit 1; }
   ```

2. **Parallel Safety for Docker targets:**
   ```makefile
   # Prevent parallel execution of Docker targets (race conditions)
   .NOTPARALLEL: docker-build docker-push docker-run
   ```
   Or use proper dependencies to serialize:
   ```makefile
   docker-push: docker-build  # Ensures build completes before push
   docker-run: docker-build   # Ensures build completes before run
   ```

3. **Install target error handling:**
   ```makefile
   install: $(TARGET)
   	install -d $(DESTDIR)$(PREFIX)/bin || exit 1
   	install -m 755 $(TARGET) $(DESTDIR)$(PREFIX)/bin/ || exit 1
   ```

**Note:** When validation shows info items about error handling or parallel safety, you MUST address them for any Makefile containing Docker, deploy, or install targets. Explain in your response which patterns were applied.

**Validation Checklist:**
- [ ] Syntax correct (`make -n` passes)
- [ ] All non-file targets have .PHONY
- [ ] Tab indentation (not spaces)
- [ ] No hardcoded credentials
- [ ] User-overridable variables use `?=`
- [ ] .DELETE_ON_ERROR present
- [ ] MAKEFLAGS optimizations included (Modern header)
- [ ] Order-only prerequisites for build directories (large projects)
- [ ] Error handling in critical recipes (install, deploy, docker-push)

## Best Practices

### Variables
- `?=` for user-overridable (CC, CFLAGS, PREFIX)
- `:=` for project-specific (SOURCES, OBJECTS)
- Use pkg-config: `CFLAGS += $(shell pkg-config --cflags lib)`

### Targets
- Always declare `.PHONY` for non-file targets
- Default target should be `all`
- Use `.DELETE_ON_ERROR` for safety
- Document with `##` comments for help target

### Directory Creation
Two approaches for creating build directories:

**Simple (inline mkdir):**
```makefile
$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	@mkdir -p $(@D)
	$(CC) $(CFLAGS) -c $< -o $@
```

**Optimized (order-only prerequisites):** Prevents unnecessary rebuilds when directory timestamps change.
```makefile
$(BUILDDIR):
	@mkdir -p $@

$(BUILDDIR)/%.o: $(SRCDIR)/%.c | $(BUILDDIR)
	$(CC) $(CFLAGS) -c $< -o $@
```
Use order-only prerequisites (`|`) for large projects with many targets.

### Recipes
- Use tabs, never spaces
- Quote variables in shell: `$(RM) "$(TARGET)"`
- Use `@` prefix for quiet commands
- Test with `make -n` first

## Helper Scripts (Optional)

These scripts are **optional convenience tools** for quick template generation.

### When to Use Scripts vs Manual Generation

| Scenario | Recommendation |
|----------|----------------|
| Simple, standard project (single binary, no special features) | ✅ Use `generate_makefile_template.sh` for speed |
| Complex project (Docker, multi-binary, custom patterns) | ❌ Use manual generation for full control |
| Adding targets to existing Makefile | ✅ Use `add_standard_targets.sh` |
| User has specific formatting/style requirements | ❌ Use manual generation |
| Rapid prototyping / proof-of-concept | ✅ Use scripts, customize later |
| Production-ready Makefile | ⚠️ Start with script, then customize manually |

### generate_makefile_template.sh

Generates a complete Makefile template for a specific project type.

```bash
bash scripts/generate_makefile_template.sh [TYPE] [NAME]

Types: c, c-lib, cpp, go, python, java, generic
```

**Example:**
```bash
bash scripts/generate_makefile_template.sh go myservice
# Creates Makefile with Go patterns, version embedding, standard targets
```

### add_standard_targets.sh

Adds missing standard GNU targets to an existing Makefile.

```bash
bash scripts/add_standard_targets.sh [MAKEFILE] [TARGETS...]

Targets: all, install, uninstall, clean, distclean, test, check, help
```

**Example:**
```bash
bash scripts/add_standard_targets.sh Makefile install uninstall help
# Adds install, uninstall, help targets if they don't exist
```

**Note:** Manual generation following the Stage 3 patterns produces equivalent results but allows for more customization.

## Documentation

Detailed guides in `docs/`:
- **makefile-structure.md** - Organization, layout, includes
- **variables-guide.md** - Assignment operators, automatic variables
- **targets-guide.md** - Standard targets, .PHONY, prerequisites
- **patterns-guide.md** - Pattern rules, dependencies
- **optimization-guide.md** - Parallel builds, caching
- **security-guide.md** - Safe expansion, credential handling

## Resources

- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- [GNU Coding Standards](https://www.gnu.org/prep/standards/standards.html)
- [Makefile Conventions](https://www.gnu.org/prep/standards/html_node/Makefile-Conventions.html)