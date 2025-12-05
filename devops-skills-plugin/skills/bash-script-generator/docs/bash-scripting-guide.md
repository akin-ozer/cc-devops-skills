# Bash Scripting Guide

## Table of Contents

1. [Introduction](#introduction)
2. [Bash vs POSIX sh](#bash-vs-posix-sh)
3. [Strict Mode and Error Handling](#strict-mode-and-error-handling)
4. [Variables and Parameter Expansion](#variables-and-parameter-expansion)
5. [Functions and Scope](#functions-and-scope)
6. [Arrays and Associative Arrays](#arrays-and-associative-arrays)
7. [Control Structures](#control-structures)
8. [Process and Command Substitution](#process-and-command-substitution)
9. [Best Practices](#best-practices)
10. [Common Pitfalls](#common-pitfalls)

## Introduction

Bash (Bourne Again Shell) is a powerful Unix shell and command language. This guide covers modern bash scripting practices and patterns for creating robust, maintainable scripts.

## Bash vs POSIX sh

### Key Differences

**Bash-specific features (not in POSIX sh):**
- Arrays: `arr=(one two three)`
- Associative arrays: `declare -A map=([key]=value)`
- `[[` conditional expressions
- `$(( ))` arithmetic expansion with more operators
- `${var//pattern/replacement}` parameter expansion
- Process substitution: `<(command)`
- `select` keyword for menus
- `**` recursive globbing with `shopt -s globstar`

**POSIX sh compatible:**
- Basic variable assignment and substitution
- `[` test command (single brackets)
- `case` statements
- Basic parameter expansion
- Command substitution with `$()`
- Functions (with different syntax)

### When to Choose

**Use Bash when:**
- Script runs on modern Linux/macOS systems
- Need arrays or associative arrays
- Want advanced string manipulation
- Targeting bash-specific environments

**Use POSIX sh when:**
- Maximum portability required
- Running on minimal systems (embedded, containers)
- Need to run on different Unix variants
- Following strict POSIX compliance requirements

## Strict Mode and Error Handling

### Essential: set -euo pipefail

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
```

**Explanation:**
- `set -e` (errexit): Exit immediately if a command exits with non-zero status
- `set -u` (nounset): Treat unset variables as an error
- `set -o pipefail`: Return value of pipeline is status of last command to exit with non-zero status
- `IFS=$'\n\t'`: Set Internal Field Separator to newline and tab only (prevents word splitting issues)

### When to Disable Strict Mode Temporarily

```bash
# Disable errexit for commands that are expected to fail
set +e
command_that_might_fail
exit_code=$?
set -e

# Or use || true for single commands
command_that_might_fail || true

# Or handle error explicitly
if ! command_that_might_fail; then
    echo "Command failed, but continuing..."
fi
```

### Signal Handling with trap

```bash
# Cleanup function
cleanup() {
    local exit_code=$?
    echo "Cleaning up..." >&2
    rm -f "${temp_file}"
    exit "${exit_code}"
}

# Set traps
trap cleanup EXIT      # Always run cleanup on exit
trap cleanup ERR       # Run cleanup on error
trap cleanup INT TERM  # Run cleanup on interrupt or termination

# Create temp file
temp_file=$(mktemp)

# Rest of script...
```

### Error Handling Patterns

```bash
# Pattern 1: Die function
die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ -f "${file}" ]] || die "File not found: ${file}"

# Pattern 2: Check function return values
if ! do_something; then
    echo "do_something failed" >&2
    return 1
fi

# Pattern 3: Command substitution with error handling
output=$(command 2>&1) || {
    echo "Command failed: ${output}" >&2
    exit 1
}

# Pattern 4: Validate prerequisites
check_command() {
    command -v "$1" &> /dev/null || die "Required command not found: $1"
}

check_command "jq"
check_command "curl"
```

## Variables and Parameter Expansion

### Variable Naming Conventions

```bash
# Constants - uppercase with readonly
readonly MAX_RETRIES=3
readonly CONFIG_FILE="/etc/myapp/config.conf"

# Environment variables - uppercase
export PATH="${HOME}/bin:${PATH}"
export LOG_LEVEL="INFO"

# Local variables - lowercase
local counter=0
local temp_file=""

# Function names - lowercase with underscores
process_data() {
    local input="$1"
    # ...
}
```

### Always Quote Variables

```bash
# Good - properly quoted
rm "${file}"
cp "${source}" "${destination}"
echo "Value: ${variable}"

# Bad - unquoted (prone to word splitting and globbing)
rm $file
cp $source $destination
echo "Value: $variable"
```

### Parameter Expansion

```bash
# Default values
${var:-default}          # Use default if var is unset or empty
${var:=default}          # Set var to default if unset or empty
${var:?error message}    # Exit with error message if var is unset or empty
${var:+alternative}      # Use alternative if var is set

# String manipulation
${var#pattern}           # Remove shortest match from beginning
${var##pattern}          # Remove longest match from beginning
${var%pattern}           # Remove shortest match from end
${var%%pattern}          # Remove longest match from end
${var/pattern/replacement}    # Replace first match
${var//pattern/replacement}   # Replace all matches
${var^}                  # Uppercase first character
${var^^}                 # Uppercase all characters
${var,}                  # Lowercase first character
${var,,}                 # Lowercase all characters

# Length and substring
${#var}                  # Length of var
${var:offset}            # Substring from offset to end
${var:offset:length}     # Substring from offset with length

# Examples
file="/path/to/file.txt"
${file##*/}              # file.txt (basename)
${file%.*}               # /path/to/file (remove extension)
${file##*.}              # txt (extension only)
${file%/*}               # /path/to (dirname)
```

## Functions and Scope

### Function Definition

```bash
# POSIX style (portable)
function_name() {
    # function body
}

# Bash-specific (not portable to sh)
function function_name {
    # function body
}

# Recommended: POSIX style with local variables
process_file() {
    local input_file="$1"
    local output_file="$2"

    # Process file
    grep "pattern" "${input_file}" > "${output_file}"
}
```

### Variable Scope

```bash
# Global variable
GLOBAL_VAR="global"

my_function() {
    # Local variable - only visible in function
    local local_var="local"

    # Modifying global variable
    GLOBAL_VAR="modified"

    # Function parameter access
    local param1="$1"
    local param2="$2"

    echo "Params: ${param1} ${param2}"
}

my_function "arg1" "arg2"
```

### Return Values

```bash
# Functions return exit status (0-255)
check_file() {
    local file="$1"
    [[ -f "${file}" ]] && return 0 || return 1
}

# Use function return status
if check_file "data.txt"; then
    echo "File exists"
fi

# Return data via stdout
get_value() {
    echo "computed value"
}

# Capture output
result=$(get_value)

# Return data via variable (using nameref in bash 4.3+)
get_data() {
    local -n result_var=$1
    result_var="computed value"
}

get_data my_result
echo "${my_result}"
```

## Arrays and Associative Arrays

### Indexed Arrays (Bash-specific)

```bash
# Array creation
arr=()                          # Empty array
arr=(one two three)             # Initialize with values
arr[0]="first"                  # Assign to specific index

# Array operations
arr+=("four")                   # Append
${arr[0]}                       # Access element
${arr[@]}                       # All elements (as separate words)
${arr[*]}                       # All elements (as single word)
${#arr[@]}                      # Number of elements
${!arr[@]}                      # Indices

# Iterating over array
for item in "${arr[@]}"; do
    echo "${item}"
done

# Iterating with indices
for i in "${!arr[@]}"; do
    echo "Index $i: ${arr[i]}"
done

# Array slicing
${arr[@]:offset:length}         # Slice array

# Remove element
unset 'arr[1]'                  # Remove specific element
```

### Associative Arrays (Bash 4.0+)

```bash
# Declaration required
declare -A map

# Assignment
map[key1]="value1"
map[key2]="value2"

# Or initialize
declare -A map=([key1]="value1" [key2]="value2")

# Access
${map[key1]}                    # Get value
${map[@]}                       # All values
${!map[@]}                      # All keys
${#map[@]}                      # Number of elements

# Check if key exists
if [[ -v map[key1] ]]; then
    echo "key1 exists"
fi

# Iterate over keys and values
for key in "${!map[@]}"; do
    echo "${key}: ${map[${key}]}"
done
```

### POSIX Alternative to Arrays

```bash
# Use positional parameters
set -- one two three

# Access
echo "$1"  # one
echo "$2"  # two
echo "$#"  # count: 3

# Iterate
for item in "$@"; do
    echo "${item}"
done

# Add item
set -- "$@" "four"

# Remove first item
shift
```

## Control Structures

### Conditional Expressions

```bash
# Bash [[ ... ]] (recommended for bash)
if [[ -f "${file}" ]]; then
    echo "File exists"
fi

if [[ "${var}" == "value" ]]; then
    echo "Match"
fi

if [[ "${var}" =~ ^[0-9]+$ ]]; then
    echo "Numeric"
fi

# POSIX [ ... ] (portable)
if [ -f "${file}" ]; then
    echo "File exists"
fi

# File tests
[[ -e file ]]    # Exists
[[ -f file ]]    # Regular file
[[ -d file ]]    # Directory
[[ -L file ]]    # Symbolic link
[[ -r file ]]    # Readable
[[ -w file ]]    # Writable
[[ -x file ]]    # Executable
[[ -s file ]]    # Not empty

# String tests
[[ -z "${var}" ]]        # Empty string
[[ -n "${var}" ]]        # Non-empty string
[[ "${a}" == "${b}" ]]   # Equal
[[ "${a}" != "${b}" ]]   # Not equal
[[ "${a}" < "${b}" ]]    # Lexicographically less (bash only)

# Numeric tests
[[ "${a}" -eq "${b}" ]]  # Equal
[[ "${a}" -ne "${b}" ]]  # Not equal
[[ "${a}" -lt "${b}" ]]  # Less than
[[ "${a}" -le "${b}" ]]  # Less than or equal
[[ "${a}" -gt "${b}" ]]  # Greater than
[[ "${a}" -ge "${b}" ]]  # Greater than or equal

# Logical operators
[[ condition1 && condition2 ]]  # AND
[[ condition1 || condition2 ]]  # OR
[[ ! condition ]]                # NOT
```

### case Statements

```bash
case "${var}" in
    pattern1)
        # commands
        ;;
    pattern2|pattern3)
        # Multiple patterns
        ;;
    *)
        # Default case
        ;;
esac

# Example with patterns
case "${file}" in
    *.txt)
        echo "Text file"
        ;;
    *.jpg|*.png)
        echo "Image file"
        ;;
    *)
        echo "Unknown type"
        ;;
esac
```

### Loops

```bash
# while loop
while condition; do
    # commands
done

# until loop
until condition; do
    # commands
done

# for loop (C-style, bash only)
for ((i=0; i<10; i++)); do
    echo "${i}"
done

# for loop (iterating over values)
for item in one two three; do
    echo "${item}"
done

# for loop (iterating over files)
for file in *.txt; do
    echo "${file}"
done

# for loop (iterating over command output)
while IFS= read -r line; do
    echo "${line}"
done < file.txt

# Or with command substitution (avoid for large output)
for file in $(find . -name "*.txt"); do
    echo "${file}"
done
```

## Process and Command Substitution

### Command Substitution

```bash
# Recommended: $( ... )
result=$(command)
result=$(command arg1 arg2)

# Nested command substitution
outer=$(echo "Inner: $(echo "value")")

# Not recommended: backticks (legacy)
result=`command`
```

### Process Substitution (Bash-specific)

```bash
# <( ... ) creates a named pipe/file descriptor
# Treat command output as a file

# Compare output of two commands
diff <(ls dir1) <(ls dir2)

# Use multiple inputs
paste <(cut -f1 file1) <(cut -f2 file2)

# Output redirection with process substitution
command > >(tee stdout.log) 2> >(tee stderr.log >&2)
```

## Best Practices

### Script Structure

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# Script Name: example.sh
# Description: Brief description
# Author: Your Name
# Created: 2025-01-23
# ============================================================================

# Constants
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Global variables
VERBOSE=false
DRY_RUN=false

# Functions
usage() {
    # ...
}

cleanup() {
    # ...
}

main() {
    # ...
}

# Signal handlers
trap cleanup EXIT ERR INT TERM

# Execute main
main "$@"
```

### Always Use Quotes

```bash
# Good
echo "${variable}"
cp "${source}" "${dest}"
[[ -f "${file}" ]]

# Bad (unsafe)
echo $variable
cp $source $dest
[[ -f $file ]]
```

### Use readonly for Constants

```bash
readonly MAX_RETRIES=3
readonly CONFIG_FILE="/etc/config"
```

### Prefer $() Over Backticks

```bash
# Good
output=$(command)
result=$(first $(second))

# Bad
output=`command`
result=`first \`second\``  # Hard to read
```

### Check Command Existence

```bash
if ! command -v required_cmd &> /dev/null; then
    echo "Error: required_cmd not found" >&2
    exit 1
fi
```

### Validate Inputs

```bash
# Check argument count
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <file>" >&2
    exit 1
fi

# Validate file exists
[[ -f "${file}" ]] || { echo "File not found: ${file}" >&2; exit 1; }

# Validate numeric input
[[ "${count}" =~ ^[0-9]+$ ]] || { echo "Count must be numeric" >&2; exit 1; }
```

## Common Pitfalls

### Word Splitting

```bash
# Problem: Filename with spaces
file="my file.txt"
rm $file           # Tries to remove "my" and "file.txt"

# Solution: Quote variables
rm "${file}"       # Correctly removes "my file.txt"
```

### Globbing

```bash
# Problem: Pattern in variable
pattern="*.txt"
echo $pattern      # Expands to list of .txt files

# Solution: Quote to prevent globbing
echo "${pattern}"  # Prints "*.txt"
```

### Useless Use of Cat (UUOC)

```bash
# Bad: Unnecessary cat
cat file.txt | grep "pattern"

# Good: Direct input
grep "pattern" file.txt

# Bad: cat in loop
cat file.txt | while read line; do
    echo "${line}"
done

# Good: redirect to while
while read -r line; do
    echo "${line}"
done < file.txt
```

### Not Handling Spaces in Filenames

```bash
# Bad: Will break on filenames with spaces
for file in $(find . -name "*.txt"); do
    process "${file}"
done

# Good: Use while read
find . -name "*.txt" -print0 | while IFS= read -r -d '' file; do
    process "${file}"
done

# Or use globbing
for file in ./**/*.txt; do
    process "${file}"
done
```

### Ignoring Command Exit Status

```bash
# Bad: Ignoring failure
command_that_might_fail
next_command

# Good: Check exit status
if command_that_might_fail; then
    next_command
else
    echo "Command failed" >&2
    exit 1
fi

# Or with errexit
command_that_might_fail || { echo "Failed" >&2; exit 1; }
```

---

## References

- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/) - Script analysis tool
- [Bash Guide for Beginners](https://tldp.org/LDP/Bash-Beginners-Guide/html/)