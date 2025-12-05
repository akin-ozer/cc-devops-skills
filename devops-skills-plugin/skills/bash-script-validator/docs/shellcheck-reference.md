# ShellCheck Reference Guide

## Overview

ShellCheck is a static analysis tool for shell scripts that provides warnings and suggestions for syntax and semantic issues to improve script quality and prevent errors.

**Official Website:** https://www.shellcheck.net/
**GitHub:** https://github.com/koalaman/shellcheck
**Wiki:** https://github.com/koalaman/shellcheck/wiki

## Installation

```bash
# macOS
brew install shellcheck

# Ubuntu/Debian
apt-get install shellcheck

# Fedora
dnf install shellcheck

# From source/binary
# See: https://github.com/koalaman/shellcheck#installing
```

## Basic Usage

```bash
# Check a script
shellcheck script.sh

# Specify shell dialect
shellcheck -s bash script.sh
shellcheck -s sh script.sh
shellcheck -s ksh script.sh
shellcheck -s zsh script.sh

# Different output formats
shellcheck -f gcc script.sh       # GCC-style (for editors)
shellcheck -f checkstyle script.sh # Checkstyle XML
shellcheck -f json script.sh      # JSON
shellcheck -f tty script.sh       # TTY (default, with colors)

# Check multiple files
shellcheck *.sh

# Exclude specific warnings
shellcheck -e SC2086,SC2046 script.sh

# Set minimum severity
shellcheck -S error script.sh    # Only errors
shellcheck -S warning script.sh  # Warnings and above
```

## Severity Levels

ShellCheck categorizes issues into four severity levels:

1. **error** - Critical issues that will cause failures
2. **warning** - Potential bugs or problematic patterns
3. **info** - Suggestions for improvement
4. **style** - Stylistic improvements

```bash
# Show only errors
shellcheck -S error script.sh

# Show errors and warnings
shellcheck -S warning script.sh

# Show everything (default)
shellcheck script.sh
```

## Common Error Codes

### Critical Errors (SC2xxx series)

#### SC2086: Quote Variables to Prevent Word Splitting
```bash
# Problematic
cp $file $destination

# Fixed
cp "$file" "$destination"
```

#### SC2046: Quote Command Substitutions
```bash
# Problematic
for file in $(ls *.txt); do

# Fixed
for file in *.txt; do
```

#### SC2006: Use $() Instead of Backticks
```bash
# Problematic
result=`command`

# Fixed
result=$(command)
```

#### SC2155: Declare and Assign Separately
```bash
# Problematic
local result=$(command)  # Masks return value

# Fixed
local result
result=$(command)
```

#### SC2164: Use || exit After cd
```bash
# Problematic
cd /some/directory
rm -rf *

# Fixed
cd /some/directory || exit
rm -rf *
```

#### SC2181: Check Exit Code Directly
```bash
# Problematic
command
if [ $? -eq 0 ]; then

# Fixed
if command; then
```

#### SC2068: Quote Array Expansions
```bash
# Problematic
command $@

# Fixed
command "$@"
```

#### SC2116: Useless echo with $()
```bash
# Problematic
var=$(echo $value)

# Fixed
var=$value
```

#### SC2162: read Without -r
```bash
# Problematic
while read line; do

# Fixed
while IFS= read -r line; do
```

#### SC2005: Useless echo Piped to Command
```bash
# Problematic
echo "$var" | grep pattern

# Fixed
grep pattern <<< "$var"
# Or
printf '%s\n' "$var" | grep pattern
```

### Bashisms (SC3xxx series)

These warn about bash-specific features used in sh scripts:

#### SC3001: Using Bash [[ ]] in sh Script
```bash
# In #!/bin/sh script
if [[ condition ]]; then  # Wrong

# Fixed
if [ condition ]; then
```

#### SC3037: Using Bash Arrays in sh Script
```bash
# In #!/bin/sh script
array=(one two)  # Wrong

# No direct fix - arrays not in POSIX sh
# Use alternatives like positional parameters
```

## Disabling Checks

### Disable Specific Line
```bash
# shellcheck disable=SC2086
variable=$unquoted
```

### Disable for Entire File
```bash
# At top of file
# shellcheck disable=SC2086,SC2046
```

### Disable Next Line
```bash
# shellcheck disable=SC2086
variable=$unquoted
```

### Disable for Block
```bash
# shellcheck disable=SC2086
{
    var1=$unquoted1
    var2=$unquoted2
}
# shellcheck enable=SC2086
```

## ShellCheck Directives

### Shell Directive
```bash
# Specify shell dialect (overrides shebang)
# shellcheck shell=bash
# or
# shellcheck shell=sh
```

### Source Directive
```bash
# Tell ShellCheck where to find sourced files
# shellcheck source=./lib/common.sh
. ./lib/common.sh
```

### External Sources
```bash
# For dynamically sourced files
# shellcheck source=/dev/null
. "$config_file"
```

## Configuration File

Create `.shellcheckrc` in project root or `~/.shellcheckrc`:

```bash
# Disable specific checks globally
disable=SC2086,SC2046,SC2068

# Enable optional checks
enable=all
enable=avoid-nullary-conditions

# Specify shell
shell=bash
```

## Integration with CI/CD

### GitHub Actions
```yaml
- name: Run ShellCheck
  uses: ludeeus/action-shellcheck@master
  with:
    severity: warning
```

### GitLab CI
```yaml
shellcheck:
  script:
    - shellcheck **/*.sh
```

### Pre-commit Hook
```yaml
# .pre-commit-config.yaml
- repo: https://github.com/shellcheck-py/shellcheck-py
  rev: v0.9.0.2
  hooks:
    - id: shellcheck
```

## Common Patterns and Best Practices

### 1. Always Quote Variables
ShellCheck will flag unquoted variables in most contexts.

### 2. Use -r Flag with read
```bash
# Good
while IFS= read -r line; do
    echo "$line"
done < file
```

### 3. Check Command Existence
```bash
if command -v shellcheck >/dev/null 2>&1; then
    echo "Found"
fi
```

### 4. Use || exit After cd
```bash
cd /directory || exit 1
```

### 5. Use [[ ]] in Bash, [ ] in sh
ShellCheck knows your shell and will warn appropriately.

### 6. Proper Array Usage
```bash
# Good (bash)
args=("first arg" "second arg")
command "${args[@]}"
```

### 7. Avoid Useless cat
```bash
# Instead of
cat file | grep pattern

# Use
grep pattern file
# or
< file grep pattern
```

## Advanced Features

### Optional Checks
Some checks are not enabled by default:

```bash
# Enable all optional checks
# shellcheck enable=all

# Or specific ones
# shellcheck enable=avoid-nullary-conditions
# shellcheck enable=quote-safe-variables
# shellcheck enable=require-variable-braces
```

### Custom Severity
```bash
# Change severity of specific check
# shellcheck severity=warning SC2086
```

## Exit Codes

- **0**: No issues found
- **1**: Some issues found
- **2**: Syntax errors that prevent parsing
- **3**: ShellCheck error (bad options, missing files)
- **4**: ShellCheck not installed

## Editor Integration

ShellCheck integrates with most editors:

- **VS Code**: ShellCheck extension
- **Vim**: via ALE, Syntastic, or vim-shellcheck
- **Emacs**: flycheck-shellcheck
- **Sublime Text**: SublimeLinter-shellcheck
- **Atom**: linter-shellcheck

## Resources

- **Main Website**: https://www.shellcheck.net/
- **Wiki with Error Codes**: https://github.com/koalaman/shellcheck/wiki
- **Try Online**: https://www.shellcheck.net/
- **GitHub Issues**: https://github.com/koalaman/shellcheck/issues

## Quick Reference Table

| Code | Issue | Fix |
|------|-------|-----|
| SC2086 | Unquoted variable | Add quotes: `"$var"` |
| SC2046 | Unquoted $() | Quote command substitution |
| SC2006 | Backticks | Use `$()` instead |
| SC2155 | Declare and assign together | Separate into two lines |
| SC2164 | cd without error check | Add `|| exit` |
| SC2181 | Checking $? | Check command directly |
| SC2068 | Unquoted $@ | Quote: `"$@"` |
| SC2162 | read without -r | Add `-r` flag |
| SC3001 | [[ in sh script | Use [ ] instead |
| SC3037 | Arrays in sh script | Use POSIX alternatives |
