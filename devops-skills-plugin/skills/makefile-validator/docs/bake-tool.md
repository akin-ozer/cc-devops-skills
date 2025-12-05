# mbake Tool Reference

Comprehensive guide to using mbake (Makefile formatter and linter) for Makefile validation and formatting.

## Overview

**mbake** is a modern Python-based tool designed to format and validate Makefiles with intelligent features. It's the first comprehensive Makefile formatter and linter, filling a 50-year gap in build tooling.

**Current Version**: See [PyPI](https://pypi.org/project/mbake/) for latest

### Known Limitations

While mbake is excellent for GNU Make formatting, be aware of these limitations:

- **POSIX Make**: mbake is designed for GNU Make; it may not recognize all POSIX make syntax
- **.SUFFIXES**: mbake doesn't understand `.SUFFIXES` special target
- **Format vs Check**: Some users report `mbake format --check` warns about different things than `mbake format` fixes

For additional linting coverage, consider using [checkmake](https://github.com/checkmake/checkmake) alongside mbake.

## Table of Contents

1. [Installation](#installation)
2. [Quick Start](#quick-start)
3. [Commands](#commands)
4. [Configuration](#configuration)
5. [Features](#features)
6. [CI/CD Integration](#cicd-integration)
7. [Editor Integration](#editor-integration)
8. [Advanced Usage](#advanced-usage)
9. [Troubleshooting](#troubleshooting)

## Installation

### PyPI Installation (Recommended)

```bash
# Install mbake
pip install mbake

# Upgrade to latest version
pip install --upgrade mbake

# Verify installation
mbake --version
```

### System Requirements

- **Python**: 3.9 or higher
- **GNU Make**: Required for validation (syntax checking)
- **pip**: For package management

### Virtual Environment (Isolated Installation)

```bash
# Create venv
python3 -m venv mbake-env

# Activate venv
source mbake-env/bin/activate  # Linux/macOS
# or
mbake-env\Scripts\activate  # Windows

# Install mbake
pip install mbake

# Use mbake
mbake format Makefile

# Deactivate when done
deactivate
```

**Note**: The makefile-validator skill automatically handles venv creation and cleanup.

### VS Code Extension

Install the "mbake Makefile Formatter" extension from the VS Code marketplace:

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "mbake Makefile Formatter"
4. Click Install

## Quick Start

### Basic Workflow

```bash
# 1. Check current formatting status
mbake format --check Makefile

# 2. Preview changes before applying
mbake format --diff Makefile

# 3. Apply formatting
mbake format Makefile

# 4. Validate syntax
mbake validate Makefile
```

### First-Time Usage

```bash
# Initialize configuration file
mbake init

# This creates ~/.bake.toml with default settings
# Edit the file to customize mbake behavior

# View current configuration
mbake config

# Format with current settings
mbake format Makefile
```

## Commands

### `mbake format`

Format and standardize Makefile structure.

```bash
# Basic formatting
mbake format Makefile

# Check formatting without modifying (CI/CD)
mbake format --check Makefile
# Exit code: 0 (properly formatted), 1 (needs formatting)

# Show diff of changes
mbake format --diff Makefile

# Backup before formatting
mbake format --backup Makefile
# Creates Makefile.bak

# Validate after formatting
mbake format --validate Makefile

# Specify custom config file
mbake format --config /path/to/.bake.toml Makefile

# Format multiple files
mbake format Makefile tests/*.mk build/*.mk
```

**Options:**
- `--check`: Check formatting without modifying (exit 0 if formatted, 1 if not)
- `--diff`: Display potential changes without applying
- `--backup`: Create .bak backup before modifying
- `--validate`: Run syntax validation after formatting
- `--config PATH`: Use custom configuration file

### `mbake validate`

Validate Makefile syntax using GNU Make.

```bash
# Validate syntax
mbake validate Makefile

# Validates with: make -f Makefile --dry-run
# Exit code: 0 (valid), 1 (invalid)

# Validate multiple files
mbake validate Makefile src/*.mk
```

**What it checks:**
- Syntax errors (missing colons, invalid characters)
- Target definition correctness
- Variable expansion syntax
- Recipe format
- Dependency chain validity

### `mbake init`

Create initial configuration file.

```bash
# Create ~/.bake.toml with defaults
mbake init

# The configuration file includes all formatting options
# Edit it to customize mbake behavior
```

### `mbake config`

Display current configuration settings.

```bash
# Show active configuration
mbake config

# Output includes:
# - Configuration file location
# - All active settings
# - Default values for unset options
```

### `mbake update`

Update mbake to the latest version.

```bash
# Update via pip
mbake update

# Equivalent to: pip install --upgrade mbake
```

## Configuration

### Configuration File: `~/.bake.toml`

Create and edit `~/.bake.toml` to customize mbake behavior:

```toml
# ~/.bake.toml - mbake configuration

# Add spaces around = in variable assignments
# Example: VAR = value  (instead of VAR=value)
space_around_assignment = true

# Add space after : in target definitions
# Example: target : prerequisites  (instead of target: prerequisites)
space_after_colon = true

# Normalize line continuation characters (backslashes)
# Removes trailing spaces before \ and ensures proper continuation
normalize_line_continuations = true

# Remove trailing whitespace from all lines
remove_trailing_whitespace = true

# Fix missing tabs in recipes (convert spaces to tabs)
# This is critical - Makefiles MUST use tabs for recipes
fix_missing_recipe_tabs = true

# Automatically detect and insert .PHONY declarations
# Analyzes recipes to identify phony targets (clean, test, etc.)
auto_insert_phony_declarations = true

# Group multiple .PHONY declarations into single declaration
# .PHONY: clean test  (instead of two separate lines)
group_phony_declarations = true

# Place .PHONY declarations at the top of the file
# If false, keeps them near their target definitions
phony_at_top = false
```

### Per-Project Configuration

Create `.bake.toml` in your project root:

```toml
# Project-specific mbake settings
# These override ~/.bake.toml for this project

space_around_assignment = false  # Compact style for this project
auto_insert_phony_declarations = true
phony_at_top = true
```

**Priority:**
1. `.bake.toml` in current directory (highest)
2. `~/.bake.toml` in home directory
3. Built-in defaults (lowest)

### Configuration Options Reference

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `space_around_assignment` | bool | `true` | Add spaces around `=` |
| `space_after_colon` | bool | `true` | Add space after `:` |
| `normalize_line_continuations` | bool | `true` | Clean backslash continuations |
| `remove_trailing_whitespace` | bool | `true` | Remove end-of-line spaces |
| `fix_missing_recipe_tabs` | bool | `true` | Convert spaces to tabs in recipes |
| `auto_insert_phony_declarations` | bool | `true` | Auto-detect and add .PHONY |
| `group_phony_declarations` | bool | `true` | Combine .PHONY lines |
| `phony_at_top` | bool | `false` | Place .PHONY at file start |

## Features

### 1. Tab Indentation Enforcement

Automatically converts spaces to tabs in recipe sections.

```makefile
# Before (spaces - invalid!)
build:
    echo "Building..."
    go build -o app

# After (tabs - correct!)
build:
	echo "Building..."
	go build -o app
```

### 2. Variable Assignment Formatting

Consistent spacing around assignments.

```makefile
# Before (inconsistent)
VAR1=value
VAR2 =value
VAR3= value
VAR4  =  value

# After (consistent)
VAR1 = value
VAR2 = value
VAR3 = value
VAR4 = value
```

### 3. Target Colon Spacing

Standardizes spacing after target colons.

```makefile
# Before
target1:prerequisites
target2 :prerequisites
target3: prerequisites

# After
target1: prerequisites
target2: prerequisites
target3: prerequisites
```

### 4. Intelligent .PHONY Detection

Automatically identifies phony targets by analyzing recipes.

```makefile
# Before
clean:
	rm -rf build

test:
	go test ./...

install:
	cp app /usr/local/bin/

# After
.PHONY: clean test install

clean:
	rm -rf build

test:
	go test ./...

install:
	cp app /usr/local/bin/
```

**Detection Logic:**
- Targets with `rm`, `mkdir`, `echo` commands → Phony
- Targets with `npm`, `go test`, `docker` commands → Phony
- Targets with `curl`, `ssh`, `scp` commands → Phony
- Targets producing actual files (*.o, *.a, binaries) → Not phony

### 5. Line Continuation Normalization

Cleans up line continuation characters.

```makefile
# Before (trailing space after \, inconsistent)
SOURCES = main.c \
          utils.c\
          config.c \

# After (consistent, no trailing spaces)
SOURCES = main.c \
          utils.c \
          config.c
```

### 6. Trailing Whitespace Removal

Removes all trailing spaces and tabs.

```makefile
# Before (invisible trailing spaces marked with ·)
VAR = value···
build:···
	echo "test"··

# After (clean)
VAR = value
build:
	echo "test"
```

### 7. Syntax Validation

Validates Makefile syntax before and after formatting.

```bash
mbake format --validate Makefile
```

**Validation Process:**
1. Validates original file with `make --dry-run`
2. Applies formatting changes
3. Validates formatted file
4. Only saves if both validations pass

### 8. Format Disable Comments

Selectively disable formatting for specific sections.

```makefile
# Standard formatting applies here
VAR1=value
target1:prerequisites

# bake-format off
# Preserve legacy formatting in this section
VAR2   =    value
target2   :   prerequisites
	    echo   "custom spacing"
# bake-format on

# Standard formatting resumes
VAR3=value
target3:prerequisites
```

**Use cases:**
- Legacy Makefiles with specific formatting
- Auto-generated sections
- Intentional custom spacing
- Compatibility with other tools

## CI/CD Integration

### GitHub Actions

```yaml
name: Validate Makefiles

on: [push, pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install mbake
        run: pip install mbake

      - name: Check Makefile formatting
        run: mbake format --check Makefile

      - name: Validate Makefile syntax
        run: mbake validate Makefile

      - name: Check all .mk files
        run: |
          for file in $(find . -name "*.mk" -o -name "Makefile"); do
            echo "Checking $file..."
            mbake format --check "$file"
            mbake validate "$file"
          done
```

### GitLab CI

```yaml
# .gitlab-ci.yml
validate-makefiles:
  image: python:3.11
  stage: test

  before_script:
    - pip install mbake

  script:
    - find . -name "Makefile" -o -name "*.mk" | while read file; do
        echo "Validating $file";
        mbake format --check "$file";
        mbake validate "$file";
      done

  only:
    - merge_requests
    - main
```

### Pre-commit Hook

Install as a pre-commit hook:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: mbake-format
        name: mbake format
        entry: mbake format --check
        language: system
        files: (Makefile|.*\.mk)$

      - id: mbake-validate
        name: mbake validate
        entry: mbake validate
        language: system
        files: (Makefile|.*\.mk)$
```

Install and use:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

### Make Target for Self-Validation

Add to your Makefile:

```makefile
# Self-validation targets
.PHONY: format-check format-fix validate-makefile

format-check:
	@echo "Checking Makefile formatting..."
	@mbake format --check $(MAKEFILE_LIST)

format-fix:
	@echo "Applying formatting to Makefile..."
	@mbake format $(MAKEFILE_LIST)

validate-makefile:
	@echo "Validating Makefile syntax..."
	@mbake validate $(MAKEFILE_LIST)

# Run all checks
.PHONY: check
check: format-check validate-makefile
	@echo "All checks passed!"
```

Usage:

```bash
# Check formatting and syntax
make check

# Auto-fix formatting
make format-fix

# Validate only
make validate-makefile
```

## Editor Integration

### VS Code

#### Extension

Install "mbake Makefile Formatter" from marketplace.

**Features:**
- Format on save
- Format on demand (Shift+Alt+F)
- Real-time validation
- Error highlighting

#### Manual Setup

Add to `.vscode/settings.json`:

```json
{
  "[makefile]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "mbake.mbake-formatter",
    "editor.insertSpaces": false,
    "editor.detectIndentation": false,
    "editor.tabSize": 8
  },
  "mbake.validateOnSave": true,
  "mbake.autoFixOnSave": false
}
```

#### Tasks

Add to `.vscode/tasks.json`:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "mbake: Format Makefile",
      "type": "shell",
      "command": "mbake",
      "args": ["format", "${file}"],
      "problemMatcher": []
    },
    {
      "label": "mbake: Validate Makefile",
      "type": "shell",
      "command": "mbake",
      "args": ["validate", "${file}"],
      "problemMatcher": []
    },
    {
      "label": "mbake: Check Format",
      "type": "shell",
      "command": "mbake",
      "args": ["format", "--check", "${file}"],
      "problemMatcher": []
    }
  ]
}
```

### Vim/Neovim

Add to `.vimrc` or `init.vim`:

```vim
" Format Makefile with mbake
autocmd FileType make nnoremap <buffer> <leader>f :!mbake format %<CR>:e<CR>

" Validate Makefile
autocmd FileType make nnoremap <buffer> <leader>v :!mbake validate %<CR>

" Check format
autocmd FileType make nnoremap <buffer> <leader>c :!mbake format --check %<CR>

" Ensure tabs in Makefiles
autocmd FileType make setlocal noexpandtab tabstop=8 shiftwidth=8
```

### Emacs

Add to `.emacs` or `init.el`:

```elisp
;; mbake formatting for Makefiles
(defun mbake-format-buffer ()
  "Format current Makefile with mbake."
  (interactive)
  (shell-command (format "mbake format %s" (buffer-file-name)))
  (revert-buffer t t t))

(defun mbake-validate-buffer ()
  "Validate current Makefile with mbake."
  (interactive)
  (compile (format "mbake validate %s" (buffer-file-name))))

;; Key bindings
(add-hook 'makefile-mode-hook
  (lambda ()
    (local-set-key (kbd "C-c f") 'mbake-format-buffer)
    (local-set-key (kbd "C-c v") 'mbake-validate-buffer)))
```

## Advanced Usage

### Batch Processing

```bash
# Format all Makefiles in project
find . -name "Makefile" -o -name "*.mk" | xargs mbake format

# Check all files without modifying
find . -name "Makefile" -o -name "*.mk" | xargs mbake format --check

# Create backups of all files
find . -name "Makefile" -o -name "*.mk" | while read file; do
    mbake format --backup "$file"
done
```

### Selective Formatting

```bash
# Format only specific files
mbake format Makefile build.mk test.mk

# Format with pattern
mbake format **/*.mk

# Exclude certain files
find . -name "*.mk" ! -name "legacy.mk" | xargs mbake format
```

### Diff Review Workflow

```bash
# 1. Review changes before applying
mbake format --diff Makefile > changes.diff

# 2. Review the diff
less changes.diff

# 3. If satisfied, apply
mbake format Makefile

# 4. Validate result
mbake validate Makefile
```

### Integration with Git

```bash
# Check if formatting is needed before commit
git diff --cached --name-only | grep -E '(Makefile|.*\.mk)$' | while read file; do
    if ! mbake format --check "$file"; then
        echo "Error: $file needs formatting"
        echo "Run: mbake format $file"
        exit 1
    fi
done
```

### Automated Refactoring

```bash
# Refactor entire codebase
#!/bin/bash

echo "Refactoring all Makefiles..."

find . -type f \( -name "Makefile" -o -name "*.mk" \) | while read file; do
    echo "Processing: $file"

    # Backup
    cp "$file" "$file.backup"

    # Format
    if mbake format "$file"; then
        echo "  ✓ Formatted"
    else
        echo "  ✗ Format failed"
        mv "$file.backup" "$file"
        continue
    fi

    # Validate
    if mbake validate "$file"; then
        echo "  ✓ Validated"
        rm "$file.backup"
    else
        echo "  ✗ Validation failed - reverting"
        mv "$file.backup" "$file"
    fi
done

echo "Refactoring complete!"
```

## Troubleshooting

### Common Issues

#### 1. mbake Command Not Found

```bash
# Problem: mbake not in PATH
$ mbake format Makefile
bash: mbake: command not found

# Solution: Ensure pip install directory is in PATH
export PATH="$HOME/.local/bin:$PATH"

# Or use python -m
python3 -m mbake format Makefile
```

#### 2. Syntax Errors After Formatting

```bash
# Problem: Validation fails after formatting
$ mbake format --validate Makefile
Error: Syntax validation failed

# Solution: Check format disable comments
# Look for unclosed # bake-format off sections
grep -n "bake-format" Makefile

# Or restore from backup
cp Makefile.bak Makefile
```

#### 3. Configuration Not Applied

```bash
# Problem: Settings in .bake.toml ignored
$ mbake format Makefile
# Formatting doesn't match config

# Solution: Verify config file location
mbake config

# Or specify config explicitly
mbake format --config .bake.toml Makefile
```

#### 4. Permission Denied

```bash
# Problem: Cannot write to file
$ mbake format Makefile
Error: Permission denied

# Solution: Check file permissions
ls -l Makefile
chmod u+w Makefile
```

#### 5. Python Version Incompatibility

```bash
# Problem: Wrong Python version
$ pip install mbake
ERROR: mbake requires Python '>=3.9'

# Solution: Use correct Python version
python3.11 -m pip install mbake

# Or use pyenv
pyenv install 3.11
pyenv local 3.11
pip install mbake
```

### Debug Mode

```bash
# Enable verbose output (if supported in future versions)
MBAKE_DEBUG=1 mbake format Makefile

# Check Python environment
python3 -c "import mbake; print(mbake.__version__)"

# Validate manually
make -f Makefile --dry-run
```

## Exit Codes

mbake uses standard exit codes:

| Code | Meaning | Commands |
|------|---------|----------|
| 0 | Success / No changes needed | All commands |
| 1 | Formatting needed / Validation failed | `format --check`, `validate` |
| 2 | Error occurred | All commands |

**Usage in Scripts:**

```bash
# Check formatting
if mbake format --check Makefile; then
    echo "Formatting OK"
else
    echo "Needs formatting"
    exit 1
fi

# Validate
mbake validate Makefile || {
    echo "Validation failed!"
    exit 1
}
```

## Best Practices

1. **Always use --check in CI/CD** to prevent automatic modifications
2. **Review diffs** with `--diff` before applying formatting
3. **Create backups** with `--backup` for important files
4. **Use configuration files** for consistent team formatting
5. **Combine with validation** using `--validate` flag
6. **Document exceptions** with `# bake-format off` comments
7. **Run in pre-commit hooks** to catch issues early
8. **Format incrementally** during refactoring, not all at once
9. **Test after formatting** to ensure builds still work
10. **Version control config** by committing `.bake.toml`

## Alternative Tool: checkmake

[checkmake](https://github.com/checkmake/checkmake) is a complementary linter that can be used alongside mbake for additional coverage.

### Installation

```bash
# With Go (1.16+)
go install github.com/checkmake/checkmake/cmd/checkmake@latest

# Docker
docker run --rm -v $(pwd):/data checkmake/checkmake Makefile
```

### Usage

```bash
# Basic linting
checkmake Makefile

# List available rules
checkmake list-rules

# JSON output
checkmake --output json Makefile

# With config file
checkmake --config checkmake.ini Makefile
```

### What checkmake Checks

- Missing required phony targets (all, test)
- Targets that should be declared PHONY
- Other configurable rules

### Using Both Tools Together

```makefile
# Makefile validation target
.PHONY: lint
lint:
	@echo "Running mbake..."
	mbake format --check Makefile
	mbake validate Makefile
	@echo "Running checkmake..."
	checkmake Makefile || true
	@echo "Lint complete!"
```

### CI/CD with Both Tools

```yaml
# GitHub Actions example
- name: Lint Makefile
  run: |
    pip install mbake
    go install github.com/checkmake/checkmake/cmd/checkmake@latest
    mbake format --check Makefile
    mbake validate Makefile
    checkmake Makefile
```

## Resources

- **mbake GitHub**: https://github.com/EbodShojaei/bake
- **mbake PyPI**: https://pypi.org/project/mbake/
- **mbake Issues**: https://github.com/EbodShojaei/bake/issues
- **mbake VS Code Extension**: Search "mbake" in Extensions marketplace
- **checkmake GitHub**: https://github.com/checkmake/checkmake

## Version Compatibility

- **mbake**: Latest stable version recommended
- **Python**: 3.9+ required
- **GNU Make**: Any version with `--dry-run` support
- **OS**: Linux, macOS, Windows (with GNU Make installed)

## License

mbake is released under the MIT License.

---

**Note**: This documentation covers mbake as used by the makefile-validator skill. For the latest features and updates, visit the official GitHub repository.