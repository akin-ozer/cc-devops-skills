---
name: bash-script-validator
description: Comprehensive toolkit for validating, linting, and optimizing bash and shell scripts. Use this skill when working with shell scripts (.sh, .bash), validating script syntax, checking for best practices, identifying security issues, or debugging shell script problems.
---

# Bash Script Validator

## Overview

This skill provides comprehensive validation for bash and shell scripts, checking for syntax errors, best practices, security vulnerabilities, and performance optimizations. It automatically detects whether a script is bash or POSIX sh based on the shebang and applies appropriate validation rules.

## When to Use This Skill

Use this skill when:
- Validating bash or shell scripts (.sh, .bash files)
- Checking scripts for syntax errors before deployment
- Identifying bashisms in POSIX sh scripts
- Finding security vulnerabilities (unsafe eval, command injection)
- Optimizing script performance
- Ensuring POSIX compliance
- Debugging shell script issues
- Learning shell scripting best practices
- Code review of shell scripts

## Validation Capabilities

### 1. Syntax Validation
- **Bash scripts**: Validates using `bash -n`
- **POSIX sh scripts**: Validates using `sh -n`
- Catches syntax errors before runtime
- Reports line numbers for syntax issues

### 2. ShellCheck Integration
- Comprehensive static analysis
- Hundreds of built-in checks
- Severity levels: error, warning, info, style
- Shell-specific validation (bash, sh, zsh, ksh)
- Links to detailed documentation for each issue

### 3. Security Checks
- Unsafe use of `eval` with variables
- Command injection vulnerabilities
- Dangerous `rm -rf` usage
- Unquoted variables in dangerous contexts
- Missing input validation

### 4. Performance Optimizations
- Useless use of cat (UUOC)
- Inefficient loops
- Unnecessary subshells
- Multiple pipelines that could be combined
- Suggesting built-ins over external commands

### 5. Portability Checks (for sh scripts)
- Bashisms detection (arrays, [[ ]], etc.)
- Non-POSIX constructs
- Shell-specific features in sh scripts
- Recommends POSIX alternatives

### 6. Best Practices
- Missing error handling
- Unquoted variables
- Deprecated syntax (backticks)
- Proper use of `set -e`, `set -u`, `set -o pipefail`
- Function definition order

## Quick Start

### Basic Validation

```bash
# Validate a script
bash scripts/validate.sh path/to/script.sh

# The validator will:
# 1. Detect shell type from shebang
# 2. Run syntax validation
# 3. Run ShellCheck (if installed)
# 4. Run custom security/optimization checks
# 5. Generate detailed report
```

### Example Output

```
========================================
BASH/SHELL SCRIPT VALIDATOR
========================================
File: myscript.sh
Detected Shell: bash

[SYNTAX CHECK]
✓ No syntax errors found (bash -n)

[SHELLCHECK]
myscript.sh:15:5: warning: Quote to prevent word splitting [SC2086]
myscript.sh:23:9: error: Use || exit to handle cd failure [SC2164]

[CUSTOM CHECKS]
⚠ Potential command injection: eval with variable found
  Line 42: eval $user_input

ℹ Useless use of cat detected
  Line 18: cat file.txt | grep pattern

========================================
VALIDATION SUMMARY
========================================
Errors:   2
Warnings: 3
Info:     1
```

## Usage in Claude Code

When validating shell scripts, Claude MUST follow these steps:

1. **Invoke the validator** on shell script files:
   ```bash
   bash scripts/validate.sh <script-path>
   ```

2. **Analyze results** to identify issues:
   - Review errors, warnings, and info messages from the validator output
   - Note ShellCheck error codes (SC####) for lookup

3. **Reference documentation** for detailed explanations:
   - For ShellCheck codes: Read `docs/shellcheck-reference.md`
   - For common mistakes: Read `docs/common-mistakes.md`
   - For bash-specific issues: Read `docs/bash-reference.md`
   - For POSIX sh issues: Read `docs/shell-reference.md`

4. **Suggest fixes** with code examples:
   - For each issue found, provide the corrected code
   - Show before/after comparisons when helpful
   - Reference the specific line numbers from the validation output

5. **Explain best practices** from the included guides:
   - Explain WHY each fix improves the script
   - Reference specific sections from the documentation files

### Required Workflow

```
User: "Check this bash script for issues"

Claude MUST:
1. Run: bash scripts/validate.sh <script-path>
2. Read the validation output and identify all issues
3. Read docs/common-mistakes.md for fix patterns
4. Read docs/shellcheck-reference.md for SC error explanations (if needed)
5. For EACH issue found:
   a. Show the problematic code
   b. Explain the issue (referencing documentation)
   c. Provide the corrected code
   d. Explain why the fix improves the script
```

### Example Response Format

After running the validator, Claude should respond with:

```markdown
## Validation Results

Found X errors, Y warnings, Z info issues.

### Issue 1: Unquoted Variable (Line 25)

**Problem:**
\`\`\`bash
if [ ! -f $file ]; then  # Word splitting risk
\`\`\`

**Reference:** See `common-mistakes.md` section "1. Unquoted Variables"

**Fix:**
\`\`\`bash
if [ ! -f "$file" ]; then  # Properly quoted
\`\`\`

**Why:** Unquoted variables undergo word splitting and glob expansion,
causing unexpected behavior with filenames containing spaces or special characters.

### Issue 2: ...
```

## Comprehensive Documentation

### Core References

#### bash-reference.md
- Bash-specific features vs POSIX sh
- Parameter expansion
- Arrays and associative arrays
- Control structures
- Functions and scope
- Best practices
- Common pitfalls

#### shell-reference.md
- POSIX sh compliance
- Portable constructs
- Differences from bash
- Character classes
- POSIX utilities
- Testing for compliance

#### shellcheck-reference.md
- ShellCheck error codes explained
- Severity levels
- Configuration options
- Disabling checks
- CI/CD integration
- Editor integration

### Tool References

#### grep-reference.md
- Basic and extended regex (BRE/ERE)
- Common grep patterns
- Performance tips
- Character classes
- Practical examples for scripts

#### awk-reference.md
- Field processing
- Built-in variables
- Pattern matching
- Arrays and functions
- Log analysis examples
- CSV/text processing

#### sed-reference.md
- Stream editing basics
- Substitution patterns
- Address ranges
- In-place editing
- Backreferences
- Common one-liners

#### regex-reference.md
- BRE vs ERE comparison
- POSIX character classes
- Metacharacters and escaping
- Backreferences
- Common patterns (IP, email, phone, etc.)
- Shell script regex examples

#### common-mistakes.md
- 25+ common shell scripting mistakes
- Real-world examples
- Consequences of each mistake
- Correct solutions
- Quick checklist

## Example Scripts

Located in `examples/` directory:

- **good-bash.sh**: Well-written bash script demonstrating best practices
- **bad-bash.sh**: Poorly-written bash script with common mistakes
- **good-shell.sh**: POSIX-compliant sh script
- **bad-shell.sh**: sh script with bashisms and errors

Use these for reference when learning or teaching shell scripting.

## Validation Script Features

### Automatic Shell Detection

The validator detects shell type from shebang:
- `#!/bin/bash`, `#!/usr/bin/env bash` → bash
- `#!/bin/sh`, `#!/usr/bin/sh` → POSIX sh
- `#!/bin/zsh` → zsh
- `#!/bin/ksh` → ksh
- `#!/bin/dash` → dash

### Multi-Layer Validation

1. **Syntax Check**: Fast basic validation
2. **ShellCheck**: Comprehensive static analysis (if installed)
3. **Custom Checks**: Security and optimization patterns
4. **Report Generation**: Color-coded, detailed output

### Exit Codes

- **0**: No issues found
- **1**: Warnings found
- **2**: Errors found

## Installation Requirements

### Required
- bash or sh (for running scripts)

### ShellCheck Installation Options

The validator automatically detects and uses the best available ShellCheck installation:

**Option 1: System-wide (Recommended - fastest)**
```bash
# macOS
brew install shellcheck

# Ubuntu/Debian
apt-get install shellcheck

# Fedora
dnf install shellcheck
```

**Option 2: Automatic via Wrapper (Python required)**
```bash
# The wrapper automatically installs shellcheck-py in a venv
# Requires: python3 and pip3
./scripts/shellcheck_wrapper.sh --cache script.sh

# Cache location: ~/.cache/bash-script-validator/shellcheck-venv
# Clear cache: ./scripts/shellcheck_wrapper.sh --clear-cache
```

**Option 3: Manual Python install**
```bash
pip3 install shellcheck-py
```

The validator works without ShellCheck but provides enhanced validation when it's available. The wrapper provides automatic installation with caching for faster subsequent runs.

## Common Validation Scenarios

### Scenario 1: Converting Bash Script to POSIX sh

```bash
# 1. Validate current bash script
bash scripts/validate.sh myscript.sh

# 2. Change shebang to #!/bin/sh
# 3. Re-validate - catches bashisms
bash scripts/validate.sh myscript.sh

# 4. Reference shell-reference.md for POSIX alternatives
# 5. Fix bashisms (arrays → set --, [[ ]] → [ ], etc.)
# 6. Re-validate until clean
```

### Scenario 2: Security Audit

The validator automatically checks for:
- Unsafe `eval` usage
- Command injection risks
- Dangerous `rm -rf` patterns
- Unquoted variables in dangerous contexts

Reference `common-mistakes.md` for detailed explanations.

### Scenario 3: Performance Optimization

Identifies:
- Useless use of cat (UUOC)
- Inefficient file reading loops
- Unnecessary external commands
- Pipeline inefficiencies

Reference tool-specific docs (grep, awk, sed) for better patterns.

## Integration with Development Workflow

### Pre-commit Hook
```bash
#!/bin/bash
for file in $(git diff --cached --name-only --diff-filter=ACM | grep '\.sh$'); do
    if ! bash .claude/skills/bash-script-validator/scripts/validate.sh "$file"; then
        echo "Validation failed for $file"
        exit 1
    fi
done
```

### CI/CD Integration
```yaml
# Example for GitHub Actions
- name: Validate Shell Scripts
  run: |
    find . -name "*.sh" -exec bash .claude/skills/bash-script-validator/scripts/validate.sh {} \;
```

## Learning Resources

Use the included documentation to:

1. **Learn bash scripting**: Start with `bash-reference.md`
2. **Write portable scripts**: Read `shell-reference.md`
3. **Master text processing**: Study `grep`, `awk`, and `sed` references
4. **Understand regex**: Reference `regex-reference.md`
5. **Avoid mistakes**: Review `common-mistakes.md`
6. **Fix issues**: Look up error codes in `shellcheck-reference.md`

## Best Practices

### For Script Authors

1. Always include a shebang
2. Use `set -euo pipefail` for strict mode
3. Quote all variable expansions
4. Check return codes for critical commands
5. Use meaningful variable names
6. Add comments for complex logic
7. Validate scripts before committing

### For Reviewers

1. Run the validator on all scripts
2. Check for security issues first
3. Verify POSIX compliance if required
4. Look for performance optimizations
5. Ensure proper error handling
6. Validate documentation/comments

## Technical Details

### Directory Structure
```
bash-script-validator/
├── SKILL.md                    # This file
├── scripts/
│   └── validate.sh             # Main validation script
├── docs/
│   ├── bash-reference.md       # Bash features and syntax
│   ├── shell-reference.md      # POSIX sh reference
│   ├── shellcheck-reference.md # ShellCheck error codes
│   ├── grep-reference.md       # grep patterns and usage
│   ├── awk-reference.md        # AWK text processing
│   ├── sed-reference.md        # sed stream editing
│   ├── regex-reference.md      # Regular expressions
│   └── common-mistakes.md      # Common pitfalls
└── examples/
    ├── good-bash.sh            # Best practices example
    ├── bad-bash.sh             # Anti-patterns example
    ├── good-shell.sh           # POSIX sh example
    └── bad-shell.sh            # Bashisms example
```

### Validation Logic

The validator performs checks in this order:

1. **File existence and readability check**
2. **Shebang detection** → determines shell type
3. **Syntax validation** → shell-specific (`bash -n` or `sh -n`)
4. **ShellCheck validation** → if installed, with appropriate shell dialect
5. **Custom security checks** → pattern matching for vulnerabilities
6. **Custom portability checks** → bashisms in sh scripts
7. **Summary generation** → color-coded report with counts

## Resources

### Official Documentation
- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/)
- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/)
- [ShellCheck](https://www.shellcheck.net/)
- [GNU grep](https://www.gnu.org/software/grep/manual/)
- [GNU awk](https://www.gnu.org/software/gawk/manual/)
- [GNU sed](https://www.gnu.org/software/sed/manual/)

### Internal References
All documentation is included in the `docs/` directory for offline reference and context loading.

---

**Note**: This skill automatically loads relevant documentation based on the validation results, providing Claude with the necessary context to explain issues and suggest fixes effectively.
