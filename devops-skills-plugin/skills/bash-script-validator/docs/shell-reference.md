# POSIX Shell (sh) Reference Guide

## Overview

POSIX sh is the portable shell specification defined by POSIX standards. Scripts written for POSIX sh should work across different Unix-like systems (bash, dash, ksh, etc.).

**Official Specification:** https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html

## Why POSIX Shell Matters

- **Portability**: Works across different Unix systems and shells
- **Minimal dependencies**: Available in minimal environments (containers, embedded systems)
- **Faster**: Shells like dash are faster than bash for simple scripts
- **Compatibility**: /bin/sh may not be bash (Ubuntu/Debian use dash)

## Key Differences: sh vs bash

### Features NOT Available in POSIX sh

1. **Arrays**
   ```bash
   # Bash only - NOT POSIX
   array=(one two three)
   echo "${array[0]}"
   ```

2. **[[ ]] Test Construct**
   ```bash
   # Bash only - NOT POSIX
   if [[ "$var" == "value" ]]; then

   # POSIX sh - use [ ]
   if [ "$var" = "value" ]; then
   ```

3. **== Operator**
   ```bash
   # Bash style - NOT POSIX
   [ "$a" == "$b" ]

   # POSIX sh - use single =
   [ "$a" = "$b" ]
   ```

4. **Process Substitution**
   ```bash
   # Bash only - NOT POSIX
   diff <(ls dir1) <(ls dir2)
   ```

5. **Brace Expansion**
   ```bash
   # Bash only - NOT POSIX
   echo {1..10}
   ```

6. **function Keyword**
   ```bash
   # Bash style - NOT in original POSIX
   function myfunc {
       echo "hello"
   }

   # POSIX sh style
   myfunc() {
       echo "hello"
   }
   ```

7. **local Keyword**
   ```bash
   # Common but not in POSIX standard
   local var="value"

   # POSIX alternative: use function scope carefully
   # or use naming conventions
   _func_var="value"
   ```

8. **source Command**
   ```bash
   # Bash style - NOT POSIX
   source script.sh

   # POSIX sh
   . script.sh
   ```

## POSIX Shell Syntax

### Variables

```sh
# Assignment
var="value"
readonly CONST="constant"

# Reading variables
echo "$var"
echo "${var}"

# Command substitution (POSIX)
result=$(command)

# Old-style command substitution (works but deprecated)
result=`command`

# Arithmetic (POSIX way)
result=$((5 + 3))
```

### Quoting

```sh
# Double quotes: Preserve literal value except $, `, and \
echo "Value: $var"

# Single quotes: Preserve everything literally
echo 'Value: $var'

# Always quote variables
cp "$file" "$destination"
```

### Control Structures

```sh
# If statement
if [ condition ]; then
    # commands
elif [ condition ]; then
    # commands
else
    # commands
fi

# Case statement
case "$var" in
    pattern1)
        # commands
        ;;
    pattern2|pattern3)
        # commands
        ;;
    *)
        # default
        ;;
esac

# For loop
for item in list; do
    echo "$item"
done

# While loop
while [ condition ]; do
    # commands
done

# Until loop
until [ condition ]; do
    # commands
done
```

### Test Constructs

POSIX sh uses `[ ]` (also known as `test` command):

```sh
# String comparisons
[ "$a" = "$b" ]      # Equal
[ "$a" != "$b" ]     # Not equal
[ -z "$a" ]          # String is empty
[ -n "$a" ]          # String is not empty

# Numeric comparisons
[ "$a" -eq "$b" ]    # Equal
[ "$a" -ne "$b" ]    # Not equal
[ "$a" -lt "$b" ]    # Less than
[ "$a" -le "$b" ]    # Less than or equal
[ "$a" -gt "$b" ]    # Greater than
[ "$a" -ge "$b" ]    # Greater than or equal

# File tests
[ -e "$file" ]       # File exists
[ -f "$file" ]       # Regular file exists
[ -d "$file" ]       # Directory exists
[ -r "$file" ]       # File is readable
[ -w "$file" ]       # File is writable
[ -x "$file" ]       # File is executable
[ -s "$file" ]       # File is not empty

# Logical operators
[ condition1 ] && [ condition2 ]  # AND
[ condition1 ] || [ condition2 ]  # OR
[ ! condition ]                   # NOT
[ condition1 -a condition2 ]      # AND (inside test)
[ condition1 -o condition2 ]      # OR (inside test)
```

### Functions

```sh
# POSIX function definition
function_name() {
    # No 'local' in strict POSIX
    # Use careful scoping or naming conventions
    echo "$1"  # First argument
    return 0   # Exit status
}

# Call function
function_name arg1 arg2
```

### Input/Output Redirection

```sh
# Redirect stdout
command > file

# Redirect stderr
command 2> errors.txt

# Redirect both
command > output.txt 2>&1

# Append
command >> file

# Here document
cat <<EOF
multiple
lines
of text
EOF

# Read from stdin
while read -r line; do
    echo "$line"
done < file.txt
```

## POSIX Best Practices

### 1. Proper Shebang
```sh
#!/bin/sh
# Use /bin/sh for POSIX scripts, not /bin/bash
```

### 2. Quote All Variables
```sh
# Good
cp "$source" "$destination"

# Bad
cp $source $destination
```

### 3. Use = Not ==
```sh
# POSIX compliant
if [ "$var" = "value" ]; then

# NOT POSIX (bash-specific)
if [ "$var" == "value" ]; then
```

### 4. Use $() for Command Substitution
```sh
# Preferred (POSIX)
result=$(command)

# Old style (works but less readable)
result=`command`
```

### 5. Avoid Bashisms

Don't use:
- Arrays: `array=(one two)`
- `[[` test construct
- Process substitution: `<(command)`
- Brace expansion: `{1..10}`
- `function` keyword
- `source` command (use `.` instead)
- `==` operator (use `=`)
- `$RANDOM` variable

### 6. Check Command Existence
```sh
if command -v shellcheck >/dev/null 2>&1; then
    echo "ShellCheck is installed"
fi
```

### 7. Handle Errors
```sh
# Set errexit
set -e

# Or check manually
if ! command; then
    echo "Command failed" >&2
    exit 1
fi
```

### 8. Use set -u for Undefined Variables
```sh
set -u
# Now accessing undefined variables causes error
```

## Common Portability Issues

### 1. echo Command
```sh
# Portable way to echo without newline
printf '%s' "text without newline"

# echo -n is not portable
echo -n "text"  # Don't use in POSIX sh

# echo with backslashes
printf '%s\n' "text\twith\ttabs"
echo "text\twith\ttabs"  # Behavior varies
```

### 2. Array Alternatives
```sh
# Instead of arrays, use:

# 1. Positional parameters
set -- one two three
echo "$1"  # one

# 2. Delimited strings
items="one:two:three"
IFS=:
for item in $items; do
    echo "$item"
done
```

### 3. String Manipulation
```sh
# POSIX parameter expansion
${var#pattern}   # Remove shortest match from beginning
${var##pattern}  # Remove longest match from beginning
${var%pattern}   # Remove shortest match from end
${var%%pattern}  # Remove longest match from end

# NOT POSIX (bash-specific)
${var/pattern/replacement}
${var,,}  # lowercase
${var^^}  # uppercase
```

### 4. Arithmetic
```sh
# POSIX way
result=$((a + b))

# NOT POSIX (bash-specific)
((a++))
let "a = a + 1"
```

### 5. read Command
```sh
# POSIX
while IFS= read -r line; do
    echo "$line"
done < file

# Bash-specific flags to avoid:
read -p "prompt"     # Not in POSIX
read -a array        # Not in POSIX
read -t timeout      # Not in POSIX
```

## POSIX Parameter Expansion

```sh
${var}              # Value of var
${var:-default}     # Use default if var is unset or null
${var:=default}     # Assign default if var is unset or null
${var:?error}       # Error if var is unset or null
${var:+alternate}   # Use alternate if var is set and not null
${#var}             # Length of var
${var#pattern}      # Remove shortest match from beginning
${var##pattern}     # Remove longest match from beginning
${var%pattern}      # Remove shortest match from end
${var%%pattern}     # Remove longest match from end
```

## Special Variables (POSIX)

```sh
$0      # Script name
$1-$9   # Positional parameters
${10}   # Parameters beyond 9 (braces required)
$#      # Number of positional parameters
$*      # All positional parameters (as single word)
$@      # All positional parameters (as separate words)
$$      # Process ID of shell
$!      # PID of last background command
$?      # Exit status of last command
```

## Testing for POSIX Compliance

### Use checkbashisms
```sh
# Install checkbashisms (Debian/Ubuntu)
apt-get install devscripts

# Check script
checkbashisms script.sh
```

### Use ShellCheck with sh
```sh
# Validate as sh script
shellcheck -s sh script.sh
```

### Test with Different Shells
```sh
# Test with dash (common /bin/sh)
dash script.sh

# Test with ash
ash script.sh

# Test with ksh
ksh script.sh
```

## Common POSIX Utilities

These utilities are standardized and safe to use in POSIX scripts:

- `cat`, `echo`, `printf`
- `grep`, `sed`, `awk`
- `cut`, `sort`, `uniq`, `tr`
- `head`, `tail`, `wc`
- `find`, `xargs`
- `test` (same as `[ ]`)
- `cd`, `pwd`, `ls`
- `cp`, `mv`, `rm`, `mkdir`
- `chmod`, `chown`
- `read`, `shift`, `set`, `export`

## Resources

- [POSIX Shell Command Language](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html)
- [Dash as /bin/sh](https://wiki.ubuntu.com/DashAsBinSh)
- [Autoconf Portable Shell](https://www.gnu.org/software/autoconf/manual/autoconf.html#Portable-Shell)
- [Rich's sh (POSIX shell) tricks](http://www.etalabs.net/sh_tricks.html)