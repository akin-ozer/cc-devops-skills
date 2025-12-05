# Common Shell Scripting Mistakes

This guide covers frequent mistakes made in bash and shell scripts, their consequences, and how to fix them.

## 1. Unquoted Variables

### Problem
```bash
# Wrong
file=/path/with spaces/file.txt
cat $file  # Breaks into multiple arguments
```

### Consequence
Word splitting and glob expansion cause unexpected behavior.

### Solution
```bash
# Right
file="/path/with spaces/file.txt"
cat "$file"
```

### Rule
**Always quote variable expansions** unless you explicitly need word splitting.

---

## 2. Not Checking Command Success

### Problem
```bash
# Wrong
cd /some/directory
rm -rf *  # DANGEROUS if cd fails!
```

### Consequence
Commands execute even if previous commands fail, potentially catastrophic.

### Solution
```bash
# Right
cd /some/directory || exit 1
rm -rf *

# Or use set -e
set -e
cd /some/directory
rm -rf *

# Or check explicitly
if ! cd /some/directory; then
    echo "Failed to change directory" >&2
    exit 1
fi
rm -rf *
```

---

## 3. Using [ ] with Bash Features

### Problem
```bash
# Wrong (== not POSIX, may fail in sh)
if [ "$var" == "value" ]; then
    echo "match"
fi
```

### Solution
```bash
# POSIX sh - use single =
if [ "$var" = "value" ]; then
    echo "match"
fi

# Or use bash [[ ]] (bash only)
if [[ "$var" == "value" ]]; then
    echo "match"
fi
```

---

## 4. Useless Use of cat (UUOC)

### Problem
```bash
# Wrong - unnecessary cat
cat file.txt | grep pattern
cat file.txt | awk '{print $1}'
```

### Consequence
Wastes a process, less efficient.

### Solution
```bash
# Right
grep pattern file.txt
awk '{print $1}' file.txt

# Or use redirection
< file.txt grep pattern
```

---

## 5. Not Using -r with read

### Problem
```bash
# Wrong
while read line; do
    echo "$line"
done < file
```

### Consequence
Backslashes are interpreted, leading character may be removed.

### Solution
```bash
# Right
while IFS= read -r line; do
    echo "$line"
done < file
```

- `-r` prevents backslash interpretation
- `IFS=` prevents leading/trailing whitespace trimming

---

## 6. Testing $? After Multiple Commands

### Problem
```bash
# Wrong
command1
command2
if [ $? -eq 0 ]; then  # Tests command2, not command1!
    echo "Success"
fi
```

### Solution
```bash
# Right - test immediately
command1
if [ $? -eq 0 ]; then
    echo "command1 succeeded"
fi

# Better - test directly
if command1; then
    echo "Success"
fi
```

---

## 7. Arrays in POSIX sh Scripts

### Problem
```bash
#!/bin/sh
# Wrong - arrays not in POSIX sh
array=(one two three)
echo "${array[0]}"
```

### Solution
```bash
# Use bash
#!/bin/bash
array=(one two three)
echo "${array[0]}"

# Or use POSIX alternatives
set -- one two three
echo "$1"
```

---

## 8. Not Declaring Functions Before Use

### Problem
```bash
# Wrong - function not defined yet
my_function

my_function() {
    echo "Hello"
}
```

### Solution
```bash
# Right - define first
my_function() {
    echo "Hello"
}

my_function
```

---

## 9. Using eval Unsafely

### Problem
```bash
# DANGEROUS
user_input="$1"
eval "$user_input"  # Command injection risk!
```

### Consequence
Security vulnerability - arbitrary code execution.

### Solution
```bash
# Avoid eval when possible
# If necessary, sanitize input thoroughly
# Or use safer alternatives

# Example: dynamic variable names
var_name="my_var"
# Don't: eval "echo \$$var_name"
# Do: Use indirect expansion (bash)
echo "${!var_name}"
```

---

## 10. Forgetting set -u

### Problem
```bash
# Wrong - typo goes unnoticed
nmae="John"  # Typo
echo "Hello, $name"  # Prints "Hello, " (empty)
```

### Solution
```bash
# Right - use set -u
set -u
nmae="John"  # Typo
echo "Hello, $name"  # Error: name: unbound variable
```

---

## 11. Incorrect String Comparison

### Problem
```bash
# Wrong - numeric comparison on strings
if [ "$version" -gt "2.0" ]; then
    echo "New version"
fi
```

### Solution
```bash
# Right - string comparison
if [ "$version" = "2.0" ]; then
    echo "Exact match"
fi

# Or use proper version comparison
if [[ "$version" > "2.0" ]]; then
    echo "Greater"
fi
```

---

## 12. Not Handling Spaces in Filenames

### Problem
```bash
# Wrong
for file in $(ls *.txt); do
    echo "$file"
done
```

### Consequence
Files with spaces break into multiple items.

### Solution
```bash
# Right - use glob directly
for file in *.txt; do
    echo "$file"
done

# Or use find with -print0
while IFS= read -r -d '' file; do
    echo "$file"
done < <(find . -name "*.txt" -print0)
```

---

## 13. Backticks Instead of $()

### Problem
```bash
# Deprecated
result=`command arg1 arg2`
```

### Solution
```bash
# Modern
result=$(command arg1 arg2)
```

### Why
- Better nesting: `$(cmd1 $(cmd2))`
- Better readability
- Fewer escaping issues

---

## 14. Using = Instead of == in [[ ]]

Not really a mistake, but inconsistent:

```bash
# Both work in [[ ]]
[[ "$var" = "value" ]]   # POSIX style (works)
[[ "$var" == "value" ]]  # Bash style (also works)

# Only = works in [ ]
[ "$var" = "value" ]     # Works
[ "$var" == "value" ]    # May fail in POSIX sh
```

**Recommendation**: Use `=` for portability, or stick to `==` in bash with `[[ ]]`.

---

## 15. Not Quoting $@

### Problem
```bash
# Wrong
script.sh "$@"  # Right
command $@      # Wrong if args have spaces
```

### Solution
```bash
# Right
command "$@"  # Preserves argument boundaries
```

---

## 16. Using ls to Process Files

### Problem
```bash
# Wrong
files=$(ls *.txt)
for file in $files; do
    process "$file"
done
```

### Issues
- Breaks on spaces
- Breaks on newlines in filenames
- Breaks on glob characters

### Solution
```bash
# Right
for file in *.txt; do
    process "$file"
done

# Or with find
find . -name "*.txt" -exec process {} \;
```

---

## 17. Incorrect Exit Codes

### Problem
```bash
# Wrong
function check_file() {
    if [ -f "$1" ]; then
        echo "File exists"
        return 1  # Success should be 0!
    fi
    return 0
}
```

### Solution
```bash
# Right - 0 is success, non-zero is failure
function check_file() {
    if [ -f "$1" ]; then
        echo "File exists"
        return 0
    fi
    return 1
}
```

---

## 18. Using -a and -o in [ ]

### Problem
```bash
# Deprecated and error-prone
[ "$a" = "x" -a "$b" = "y" ]
[ "$a" = "x" -o "$b" = "y" ]
```

### Solution
```bash
# Right - use && and ||
[ "$a" = "x" ] && [ "$b" = "y" ]
[ "$a" = "x" ] || [ "$b" = "y" ]

# Or use [[ ]] in bash
[[ "$a" = "x" && "$b" = "y" ]]
[[ "$a" = "x" || "$b" = "y" ]]
```

---

## 19. Not Making Scripts Executable

### Problem
```bash
# Wrong
bash script.sh  # Works but not ideal
```

### Solution
```bash
# Right
chmod +x script.sh
./script.sh
```

And include proper shebang:
```bash
#!/usr/bin/env bash
```

---

## 20. Forgetting Final Newline

### Problem
Some tools expect files to end with a newline.

### Solution
Ensure your editor adds a final newline, or:
```bash
echo "" >> file
```

---

## 21. Using grep -q Without Knowing Implications

### Problem
```bash
# Potentially inefficient
if [ "$(grep pattern file)" ]; then
    echo "Found"
fi
```

### Solution
```bash
# Better - grep -q exits on first match
if grep -q pattern file; then
    echo "Found"
fi
```

---

## 22. Incorrect glob Pattern

### Problem
```bash
# Wrong - doesn't match hidden files
for file in *; do
    process "$file"
done
```

### Solution
```bash
# Include hidden files (bash)
shopt -s dotglob
for file in *; do
    process "$file"
done
shopt -u dotglob

# Or explicitly
for file in * .[!.]* ..?*; do
    [ -e "$file" ] && process "$file"
done
```

---

## 23. Not Handling Empty Globs

### Problem
```bash
# Fails if no .txt files
for file in *.txt; do
    process "$file"  # Processes literal "*.txt"
done
```

### Solution
```bash
# Bash - fail gracefully
shopt -s nullglob
for file in *.txt; do
    process "$file"
done
shopt -u nullglob

# POSIX - check existence
for file in *.txt; do
    [ -e "$file" ] || continue
    process "$file"
done
```

---

## 24. Not Sanitizing Input

### Problem
```bash
# Dangerous
rm -rf "/$1"  # What if $1 is empty or manipulated?
```

### Solution
```bash
# Safer
if [ -z "$1" ]; then
    echo "Error: No argument provided" >&2
    exit 1
fi

# Validate
case "$1" in
    /*)
        echo "Error: Absolute paths not allowed" >&2
        exit 1
        ;;
esac

rm -rf "$1"
```

---

## 25. Using -e for File Existence

Not a mistake, but be specific:

```bash
[ -e "$file" ]  # Exists (any type)
[ -f "$file" ]  # Regular file
[ -d "$file" ]  # Directory
[ -L "$file" ]  # Symbolic link
[ -r "$file" ]  # Readable
[ -w "$file" ]  # Writable
[ -x "$file" ]  # Executable
```

---

## Quick Checklist

Before running a script, verify:

- [ ] Proper shebang (#!/bin/bash or #!/bin/sh)
- [ ] set -euo pipefail (strict mode)
- [ ] All variables quoted
- [ ] Error handling for critical commands
- [ ] Using $() not backticks
- [ ] Not using ls for file processing
- [ ] Functions defined before use
- [ ] Proper exit codes (0 = success)
- [ ] Input validation
- [ ] ShellCheck passes

---

## Resources

- [ShellCheck](https://www.shellcheck.net/) - Catches most of these
- [Bash Pitfalls](https://mywiki.wooledge.org/BashPitfalls)
- [POSIX Shell](https://pubs.opengroup.org/onlinepubs/9699919799/)