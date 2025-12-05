---
name: makefile-validator
description: Comprehensive toolkit for validating, linting, and optimizing Makefiles. Use this skill when working with Makefiles (Makefile, makefile, *.mk files), validating build configurations, checking for best practices, identifying security issues, or debugging Makefile problems.
---

# Makefile Validator

## Overview

This skill provides comprehensive validation for Makefiles, checking for syntax errors, formatting consistency, best practices, security vulnerabilities, and optimization opportunities. It uses the mbake tool (Makefile formatter and linter) along with custom validation checks to ensure high-quality build configurations.

## When to Use This Skill

Use this skill when:
- Validating Makefiles (Makefile, makefile, *.mk files)
- Checking build configuration for syntax errors
- Ensuring consistent Makefile formatting
- Identifying security vulnerabilities in build recipes
- Finding optimization opportunities for build performance
- Debugging Makefile issues
- Enforcing .PHONY target declarations
- Verifying tab indentation in recipes
- Learning Makefile best practices
- Code review of build configurations
- CI/CD pipeline validation

## Validation Capabilities

### 1. Critical Best Practices
- **.DELETE_ON_ERROR validation**: Checks for this critical GNU Make declaration
- Ensures partially built files are deleted on recipe failure
- Prevents corrupt builds from being reused
- References: [GNU Make Special Targets](https://www.gnu.org/software/make/manual/html_node/Special-Targets.html)

### 2. Syntax Validation
- **GNU make validation**: Validates using `make -n --dry-run`
- Catches syntax errors before build time
- Reports line numbers for syntax issues
- Validates target dependencies and prerequisites

### 3. mbake Integration
- **Comprehensive formatting validation**
- Tab indentation verification for recipes
- Variable assignment consistency
- Line continuation normalization
- Trailing whitespace detection
- Smart .PHONY detection and organization
- Validates with GNU make before/after formatting

### 4. Format Checking
- Consistent spacing around assignments
- Proper spacing after colons
- Tab vs spaces verification (recipes MUST use tabs)
- Line continuation character cleanup
- Organized .PHONY declarations
- Professional formatting standards

### 5. Security Checks
- **Unsafe variable expansion** in dangerous commands (rm, sudo, curl, wget)
- **Hardcoded credentials** detection (passwords, API keys, tokens)
- **Command injection** vulnerabilities
- Unquoted variable usage in shell commands
- Unsafe shell command patterns
- **.EXPORT_ALL_VARIABLES** usage warning (potential data leakage)

### 6. Best Practices
- **.PHONY declarations** for non-file targets
- **Tab indentation** enforcement (not spaces)
- **Error handling** in recipes (set -e, ||, @ prefix)
- **Default target documentation**
- **Variable assignment operators** (=, :=, ?=, +=)
- **VPATH/vpath** usage for source organization
- Proper dependency specification
- **.ONESHELL safety**: Warns when .ONESHELL is used without proper error handling (-e flag)
- **$(MAKE) usage**: Warns when `make` is used directly instead of `$(MAKE)` for recursive calls

### 7. Optimization Opportunities
- **Parallel build safety** (.NOTPARALLEL usage)
- **Intermediate file cleanup** (.INTERMEDIATE, .SECONDARY)
- **Incremental build efficiency**
- **Unnecessary recompilation** prevention
- Dependency tracking optimization

## Quick Start

### Basic Validation

```bash
# Validate a Makefile
bash scripts/validate_makefile.sh Makefile

# The validator will:
# 1. Check dependencies (python3, pip3, make)
# 2. Create isolated venv and install mbake
# 3. Run syntax validation with GNU make
# 4. Run mbake validation
# 5. Check formatting consistency
# 6. Perform custom security/best practice checks
# 7. Auto-cleanup venv on exit
# 8. Generate detailed report
```

### Example Output

```
========================================
MAKEFILE VALIDATOR
========================================
File: Makefile

[ENVIRONMENT SETUP]
Creating temporary venv at: /tmp/makefile-validator-venv-12345
Installing mbake...
✓ Environment ready

[SYNTAX CHECK (GNU make)]
✓ No syntax errors found

[MBAKE VALIDATION]
Running mbake validate...
✓ mbake validation passed

[MBAKE FORMAT CHECK]
Checking formatting consistency...
⚠ Formatting issues found

Run 'mbake format Makefile' to fix formatting issues
Or run 'mbake format --diff Makefile' to preview changes

[CUSTOM CHECKS]
⚠ No .PHONY declarations found
   Consider adding .PHONY for targets that don't create files
   Example: .PHONY: clean test install

✗ Potential spaces instead of tabs in recipes detected
   Makefiles require TAB characters for recipe indentation

ℹ No VPATH/vpath declarations found
   Consider using VPATH for better source file organization

[CLEANUP]
Removing temporary venv...

========================================
VALIDATION SUMMARY
========================================
File: Makefile

Errors:   1
Warnings: 2
Info:     1

⚠ Validation PASSED with warnings
```

## Usage in Claude Code

When validating Makefiles, Claude will automatically:

1. **Invoke the validator** on Makefile files
2. **Analyze results** to identify issues
3. **Reference documentation** for detailed explanations
4. **Suggest fixes** with code examples
5. **Explain best practices** from included guides
6. **Format suggestions** using mbake

### Example Workflow

```
User: "Check this Makefile for issues"

Claude:
1. Runs validate_makefile.sh on the Makefile
2. Identifies issues (e.g., missing .PHONY, spaces instead of tabs)
3. References best-practices.md for standards
4. Suggests specific fixes with corrected code
5. Explains why each fix improves the build
6. Recommends mbake format for automatic fixes
```

## Comprehensive Documentation

### Core References

#### best-practices.md
- Makefile organization and structure
- Variable naming conventions
- .PHONY target usage
- Error handling in recipes
- Dependency specification
- Parallel build considerations
- VPATH and include usage
- Professional Makefile patterns

#### common-mistakes.md
- Spaces vs tabs in recipes
- Missing .PHONY declarations
- Improper dependency specification
- Variable expansion issues
- Hardcoded paths and credentials
- Inefficient build patterns
- Security vulnerabilities
- Portability problems

#### bake-tool.md
- mbake installation and configuration
- Format command options
- Validation capabilities
- CI/CD integration
- Configuration file setup (~/.bake.toml)
- Smart .PHONY detection
- Format disable comments
- Best practices for mbake usage

## Validation Script Features

### Automatic venv Isolation

The validator creates an isolated Python virtual environment:
- Unique temporary venv for each invocation
- Automatic mbake installation
- No system-wide package pollution
- Clean separation from project dependencies

### Trap-Based Cleanup

Robust cleanup mechanism:
- `trap cleanup EXIT INT TERM` ensures cleanup always runs
- Removes venv on normal exit
- Removes venv on script interruption (Ctrl+C)
- Removes venv on error termination
- Prevents leftover temporary directories

### Multi-Layer Validation

1. **Dependency Check**: Verifies python3, pip3, make availability
2. **File Validation**: Checks file existence and readability
3. **Syntax Check**: GNU make syntax validation
4. **mbake Validation**: Official mbake validator
5. **Format Check**: Formatting consistency verification
6. **Custom Checks**: Security and best practice patterns
7. **Report Generation**: Color-coded, detailed output

### Exit Codes

- **0**: No issues found (success)
- **1**: Warnings found (passed with warnings)
- **2**: Errors found (failed validation)

## Installation Requirements

### Required
- **python3**: For venv and mbake installation
- **pip3**: For installing mbake
- **bash**: For running validation script
- **GNU make**: For syntax validation (make -n)
  ```bash
  # macOS
  brew install make

  # Ubuntu/Debian
  apt-get install make

  # Fedora
  dnf install make
  ```

### Optional (Recommended)
- **checkmake**: For additional linting coverage
  ```bash
  # With Go (1.16+)
  go install github.com/checkmake/checkmake/cmd/checkmake@latest
  ```
  **checkmake rules include:**
  - `minphony`: Checks for minimum required phony targets (all, test, clean)
  - `phonydeclared`: Ensures targets are properly declared as .PHONY
  - Other configurable rules via `checkmake.ini`

- **unmake**: For POSIX portability checks
  ```bash
  # See: https://github.com/mcandre/unmake
  ```
  **unmake features:**
  - POSIX make compliance checking
  - Portability warnings (MAKEFILE_PRECEDENCE, SIMPLIFY_AT, STRICT_POSIX)
  - Dry-run validation with multiple make implementations (bmake, gmake)

### Automatic Installation
- **mbake**: Automatically installed in isolated venv
  - No manual installation required
  - Automatic cleanup after validation
  - Uses pip3 install mbake internally

## Common Validation Scenarios

### Scenario 1: Pre-commit Validation

```bash
# Validate Makefile before committing
bash .claude/skills/makefile-validator/scripts/validate_makefile.sh Makefile

# Fix any errors found
# Re-validate until clean
```

### Scenario 2: Formatting Consistency

```bash
# Check formatting
mbake format --check Makefile

# Preview formatting changes
mbake format --diff Makefile

# Apply formatting
mbake format Makefile

# Re-validate
bash .claude/skills/makefile-validator/scripts/validate_makefile.sh Makefile
```

### Scenario 3: Security Audit

The validator automatically checks for:
- Hardcoded credentials in variables
- Unsafe variable expansion in dangerous commands
- Command injection vulnerabilities
- Unvalidated user input in recipes

Reference `common-mistakes.md` for detailed explanations.

### Scenario 4: Build Optimization

Identifies:
- Missing .PHONY declarations (performance impact)
- Sequential targets that could be parallel
- Missing .INTERMEDIATE/.SECONDARY for temp files
- Inefficient dependency patterns

Reference `best-practices.md` for optimization techniques.

### Scenario 5: Converting Legacy Makefiles

```bash
# 1. Validate current Makefile
bash scripts/validate_makefile.sh legacy.mk

# 2. Fix critical errors (tabs, syntax)
# 3. Apply mbake formatting
mbake format legacy.mk

# 4. Add .PHONY declarations
mbake format --auto-insert-phony-declarations legacy.mk

# 5. Re-validate
bash scripts/validate_makefile.sh legacy.mk

# 6. Reference best-practices.md for modernization
```

## Integration with Development Workflow

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

for file in $(git diff --cached --name-only --diff-filter=ACM | grep -E '(Makefile|makefile|.*\.mk)$'); do
    if ! bash .claude/skills/makefile-validator/scripts/validate_makefile.sh "$file"; then
        echo "Validation failed for $file"
        exit 1
    fi
done
```

### CI/CD Integration

```yaml
# GitHub Actions example
name: Validate Makefiles
on: [push, pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.9'
      - name: Validate Makefiles
        run: |
          find . -type f \( -name "Makefile" -o -name "makefile" -o -name "*.mk" \) \
            -exec bash .claude/skills/makefile-validator/scripts/validate_makefile.sh {} \;
```

### Make Target for Self-Validation

```makefile
.PHONY: validate-makefile
validate-makefile:
	@bash .claude/skills/makefile-validator/scripts/validate_makefile.sh $(MAKEFILE_LIST)

.PHONY: format-makefile
format-makefile:
	@mbake format --diff $(MAKEFILE_LIST)
	@read -p "Apply formatting? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		mbake format $(MAKEFILE_LIST); \
	fi
```

## Learning Resources

Use the included documentation to:

1. **Learn Makefile syntax**: Start with `best-practices.md`
2. **Understand build systems**: Study GNU Make patterns
3. **Avoid common mistakes**: Review `common-mistakes.md`
4. **Master mbake tool**: Reference `bake-tool.md`
5. **Optimize builds**: Learn dependency management and parallel builds
6. **Secure builds**: Understand security implications

## Best Practices

### For Makefile Authors

1. **Always declare .PHONY** for non-file targets
2. **Use tabs** for recipe indentation (not spaces)
3. **Add error handling** with set -e or ||
4. **Document default target** and complex rules
5. **Use := for variables** to avoid recursive expansion
6. **Organize with VPATH** for multi-directory projects
7. **Validate before committing** to catch issues early
8. **Format consistently** using mbake

### For Reviewers

1. **Run validator** on all Makefiles
2. **Check security issues** first (credentials, injection)
3. **Verify .PHONY declarations** for performance
4. **Ensure proper dependencies** for incremental builds
5. **Look for optimization** opportunities
6. **Validate formatting** consistency
7. **Check error handling** in critical recipes

## Technical Details

### Directory Structure
```
makefile-validator/
├── skill.md                    # This file
├── scripts/
│   └── validate_makefile.sh    # Main validation script
├── docs/
│   ├── best-practices.md       # Makefile best practices
│   ├── common-mistakes.md      # Common Makefile mistakes
│   └── bake-tool.md            # mbake tool reference
└── examples/
    ├── good-makefile.mk        # Well-written example
    └── bad-makefile.mk         # Anti-patterns example
```

### Validation Logic Flow

1. **Argument parsing** → Validate input file path
2. **Dependency check** → Verify python3, pip3, make
3. **File validation** → Check existence and readability
4. **Venv setup** → Create isolated environment
5. **mbake installation** → Install in venv
6. **Syntax check** → GNU make -n --dry-run
7. **mbake validate** → Official validation
8. **mbake format check** → Consistency check
9. **Custom checks** → Security and best practices
10. **Summary generation** → Color-coded report
11. **Cleanup** → Remove venv via trap

### Custom Check Categories

**Security Checks:**
- Hardcoded credentials pattern matching
- Unsafe command variable expansion
- Shell injection vulnerability patterns

**Best Practice Checks:**
- .PHONY declaration presence
- Tab vs space indentation
- Error handling patterns
- Default target documentation
- Variable assignment operator usage

**Optimization Checks:**
- .NOTPARALLEL declaration
- .INTERMEDIATE/.SECONDARY for temp files
- VPATH/vpath usage
- Dependency specification patterns

## Advanced Features

### mbake Configuration

Create `~/.bake.toml` for project-wide settings:

```toml
space_around_assignment = true
space_after_colon = true
normalize_line_continuations = true
remove_trailing_whitespace = true
fix_missing_recipe_tabs = true
auto_insert_phony_declarations = true
group_phony_declarations = true
phony_at_top = false
```

### Format Disable Comments

```makefile
# bake-format off
legacy-target:
    # Preserve legacy formatting
    echo "custom spacing"
# bake-format on

modern-target:
	@echo "Standard formatting applies"
```

### Selective Validation

```bash
# Validate specific Makefile
bash scripts/validate_makefile.sh src/Makefile

# Validate all .mk files
find . -name "*.mk" -exec bash scripts/validate_makefile.sh {} \;

# Validate only in specific directories
find src/ -type f -name "Makefile" -exec bash scripts/validate_makefile.sh {} \;
```

## Known Limitations

### mbake Tool Limitations

The mbake tool has some known limitations that this validator handles:

1. **Unknown Special Targets**: mbake doesn't recognize some valid GNU Make special targets:
   - `.DELETE_ON_ERROR` - Reported as unknown but is valid and critical
   - `.SUFFIXES` - Reported as unknown but is valid
   - `.ONESHELL` - Reported as unknown but is valid
   - `.POSIX` - Reported as unknown but is valid

   **The validator filters these false positives** and shows them as informational messages instead of errors.

2. **format --check vs format inconsistency**: The `mbake format --check` command may report different issues than what `mbake format` actually fixes. This is a known upstream issue.

3. **POSIX Make compatibility**: mbake is designed for GNU Make and may not work correctly with pure POSIX make syntax.

For additional linting coverage, consider installing [checkmake](https://github.com/checkmake/checkmake) alongside mbake.

## Resources

### Official Documentation
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)
- [mbake GitHub Repository](https://github.com/EbodShojaei/bake)
- [mbake PyPI Package](https://pypi.org/project/mbake/)
- [checkmake GitHub](https://github.com/checkmake/checkmake)

### Web Resources
- [Makefile Best Practices](https://danyspin97.org/blog/makefiles-best-practices/)
- [Common Makefile Mistakes](https://moldstud.com/articles/p-makefile-madness-common-pitfalls-and-how-to-avoid-them)
- [Makefile Optimization](https://moldstud.com/articles/p-makefile-profiling-essentials-best-practices-every-developer-should-know)

### Internal References
All documentation is included in the `docs/` directory for offline reference and context loading.

---

**Note**: This skill automatically loads relevant documentation based on validation results, providing Claude with the necessary context to explain issues and suggest fixes effectively. The venv isolation and trap-based cleanup ensure clean, safe validation without affecting your system or project dependencies.