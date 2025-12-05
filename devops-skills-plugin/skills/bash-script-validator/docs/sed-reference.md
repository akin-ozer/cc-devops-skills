# GNU sed Reference Guide

## Overview

sed (Stream EDitor) is a powerful text processing tool that performs basic text transformations on an input stream (file or pipeline).

**Official Manual:** https://www.gnu.org/software/sed/manual/
**Man Page:** `man sed`

## Basic Syntax

```bash
sed [OPTIONS] 'command' file
sed [OPTIONS] -e 'command1' -e 'command2' file
sed [OPTIONS] -f script.sed file
```

## Common Options

```bash
-n, --quiet, --silent    # Suppress automatic output
-e SCRIPT               # Add script to commands
-f FILE                 # Add contents of FILE as commands
-i[SUFFIX]              # Edit files in-place
-r, -E                  # Use extended regular expressions
--debug                 # Annotate program execution
```

## Basic Commands

### Substitution (s)
```bash
# Basic substitution
sed 's/old/new/' file              # Replace first occurrence
sed 's/old/new/g' file             # Replace all occurrences
sed 's/old/new/2' file             # Replace second occurrence
sed 's/old/new/gi' file            # Case-insensitive, all

# With different delimiter
sed 's|/old/path|/new/path|g' file
sed 's#old#new#g' file
```

### Deletion (d)
```bash
# Delete lines
sed '5d' file                       # Delete line 5
sed '5,10d' file                    # Delete lines 5-10
sed '/pattern/d' file               # Delete matching lines
sed '/^$/d' file                    # Delete empty lines
sed '/^#/d' file                    # Delete comment lines
```

### Print (p)
```bash
# Print lines
sed -n '5p' file                    # Print only line 5
sed -n '5,10p' file                 # Print lines 5-10
sed -n '/pattern/p' file            # Print matching lines
```

### Append (a), Insert (i), Change (c)
```bash
# Append after line
sed '5a\New line' file

# Insert before line
sed '5i\New line' file

# Change line
sed '5c\Replacement line' file

# With pattern
sed '/pattern/a\New line after match' file
```

## Address Ranges

### Line Numbers
```bash
sed '5s/old/new/' file              # Line 5 only
sed '5,10s/old/new/' file           # Lines 5-10
sed '5,$s/old/new/' file            # Line 5 to end
sed '1,5d' file                     # Delete first 5 lines
```

### Patterns
```bash
sed '/start/,/end/d' file           # Delete from start to end pattern
sed '/pattern/s/old/new/' file      # Substitute in matching lines
sed '1,/pattern/d' file             # Delete from line 1 to first match
```

### Special Addresses
```bash
sed '$d' file                       # Delete last line
sed '1d' file                       # Delete first line
sed '$s/old/new/' file              # Substitute in last line
```

## Advanced Substitution

### Backreferences
```bash
# Capture and reuse
sed 's/\([0-9]\+\)/Number: \1/' file

# Multiple captures
sed 's/\([a-z]\+\) \([0-9]\+\)/\2 \1/' file

# With ERE (-E or -r)
sed -E 's/([0-9]+)/Number: \1/' file
sed -E 's/([a-z]+) ([0-9]+)/\2 \1/' file
```

### Flags
```bash
s/old/new/      # Replace first
s/old/new/g     # Replace all (global)
s/old/new/2     # Replace 2nd occurrence
s/old/new/i     # Case-insensitive
s/old/new/I     # Case-insensitive (same as i)
s/old/new/p     # Print if substitution made
s/old/new/w file # Write if substitution made
```

### Special Characters in Replacement
```bash
&               # Matched string
\1, \2, etc     # Backreferences
\L, \U          # Convert to lower/upper (GNU sed)
\n              # Newline (in replacement)
\\              # Literal backslash
```

## Multiple Commands

### Multiple -e Options
```bash
sed -e 's/old/new/g' -e 's/foo/bar/g' file
```

### Semicolon Separator
```bash
sed 's/old/new/g; s/foo/bar/g' file
```

### Multi-line Script
```bash
sed '
s/old/new/g
s/foo/bar/g
/pattern/d
' file
```

## In-place Editing

```bash
# Edit file in-place
sed -i 's/old/new/g' file

# Create backup
sed -i.bak 's/old/new/g' file

# Multiple files
sed -i 's/old/new/g' *.txt
```

## Pattern Matching

### BRE (Basic Regular Expressions) - Default
```bash
sed 's/^/#/' file                  # Add # at beginning
sed 's/$/;/' file                  # Add ; at end
sed 's/[0-9]\+/X/g' file          # Replace numbers (BRE)
sed 's/\<word\>/WORD/g' file      # Word boundaries (BRE)
```

### ERE (Extended Regular Expressions)
```bash
sed -E 's/[0-9]+/X/g' file        # Replace numbers (ERE)
sed -E 's/(foo|bar)/baz/g' file   # Alternation
sed -E 's/\s+/ /g' file           # Multiple spaces to one
```

## Practical Examples for Shell Scripts

### Configuration File Editing
```bash
# Change a config value
sed -i 's/^Port .*/Port 2222/' /etc/ssh/sshd_config

# Uncomment a line
sed -i 's/^#\(.*option.*\)/\1/' config.file

# Comment out a line
sed -i 's/^\(.*dangerous.*\)/#\1/' config.file

# Add line after pattern
sed -i '/\[section\]/a new_setting = value' config.ini
```

### Text Processing
```bash
# Remove trailing whitespace
sed 's/[[:space:]]*$//' file

# Remove leading whitespace
sed 's/^[[:space:]]*//' file

# Remove empty lines
sed '/^$/d' file

# Remove comments and empty lines
sed '/^#/d; /^$/d' file

# Double-space file
sed 'G' file

# Remove duplicate lines (consecutive)
sed '$!N; /^\(.*\)\n\1$/!P; D' file
```

### Path Manipulation
```bash
# Change paths
sed 's|/old/path|/new/path|g' file

# Extract filename from path
echo "/path/to/file.txt" | sed 's|.*/||'

# Extract directory from path
echo "/path/to/file.txt" | sed 's|/[^/]*$||'
```

### Log File Processing
```bash
# Extract IP addresses
sed -n 's/.*\([0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\).*/\1/p' log

# Filter by date
sed -n '/2025-01-01/,/2025-01-31/p' log

# Remove timestamp
sed 's/^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\} [0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\} //' log
```

### Code Refactoring
```bash
# Rename function
sed -i 's/\boldFunctionName\b/newFunctionName/g' *.sh

# Change variable
sed -i 's/\$old_var/\$new_var/g' script.sh

# Update shebang
sed -i '1s|^#!/bin/sh|#!/bin/bash|' *.sh
```

## Advanced Features

### Hold Space
```bash
# Hold space commands
h               # Copy pattern space to hold space
H               # Append pattern space to hold space
g               # Copy hold space to pattern space
G               # Append hold space to pattern space
x               # Exchange pattern and hold spaces
```

### Hold Space Examples
```bash
# Reverse file
sed '1!G;h;$!d' file

# Print last line
sed -n '$p' file
sed -n 'h;$p' file

# Append next line to current
sed 'N;s/\n/ /' file
```

### Branching
```bash
# Label and branch
:label          # Define label
b label         # Branch to label
t label         # Branch if substitution succeeded
T label         # Branch if substitution failed
```

### Branching Examples
```bash
# Remove C-style comments
sed -n '
/\/\*/ {
    :loop
    /\*\// {
        s|/\*.*\*/||g
        p
        b
    }
    N
    b loop
}
p
' file
```

## Common Patterns

### Join Lines
```bash
# Join all lines
sed ':a;N;$!ba;s/\n/ /g' file

# Join lines ending with backslash
sed -e :a -e '/\\$/N; s/\\\n//; ta' file
```

### Number Lines
```bash
sed = file | sed 'N;s/\n/\t/'
```

### Reverse Lines
```bash
sed '1!G;h;$!d' file
```

### Print Specific Lines
```bash
# Print line 5
sed -n '5p' file

# Print first 10 lines
sed -n '1,10p' file

# Print last 10 lines
sed -n -e :a -e '1,10!{P;N;D;};N;ba' file
```

## Common Pitfalls in Shell Scripts

### 1. Special Characters in Pattern
```bash
# Wrong - . matches any character
sed 's/192.168.1.1/new/' file

# Right - escape dots
sed 's/192\.168\.1\.1/new/' file

# Or use different delimiter
sed 's|192.168.1.1|new|' file
```

### 2. Not Escaping Backreferences in BRE
```bash
# Wrong (BRE)
sed 's/([0-9]+)/\1/' file

# Right (BRE)
sed 's/\([0-9]\+\)/\1/' file

# Right (ERE)
sed -E 's/([0-9]+)/\1/' file
```

### 3. In-place Editing Without Backup
```bash
# Dangerous
sed -i 's/old/new/' important_file

# Safer
sed -i.backup 's/old/new/' important_file
```

### 4. Using sed for Line Counting
```bash
# Inefficient
sed -n '$=' file

# Better
wc -l < file
```

### 5. Not Quoting Variables Properly
```bash
# Wrong
sed "s/$old/$new/g" file  # Dangerous if vars contain /

# Better
old_escaped=$(printf '%s\n' "$old" | sed 's:[\\/&]:\\&:g')
new_escaped=$(printf '%s\n' "$new" | sed 's:[\\/&]:\\&:g')
sed "s/$old_escaped/$new_escaped/g" file

# Or use different delimiter
sed "s|$old|$new|g" file
```

## Performance Tips

### 1. Use Appropriate Tools
```bash
# For simple replacements, consider using other tools
# sed is great for complex patterns, but for simple tasks:

# Instead of
sed 's/old/new/g' file

# Consider
tr 'old' 'new' < file  # For single-character replacement
```

### 2. Minimize Pattern Matching
```bash
# Less efficient
sed '/pattern/s/old/new/g' large_file

# More efficient if pattern is rare
grep 'pattern' large_file | sed 's/old/new/g'
```

### 3. Combine Commands
```bash
# Less efficient
sed 's/old/new/g' file | sed 's/foo/bar/g'

# More efficient
sed 's/old/new/g; s/foo/bar/g' file
```

## Testing sed Commands

```bash
# Test before in-place edit
sed 's/old/new/g' file | head

# Show only changes
sed -n 's/old/new/gp' file

# Count changes
sed -n 's/old/new/gp' file | wc -l
```

## Resources

- [GNU sed Manual](https://www.gnu.org/software/sed/manual/)
- [sed(1) Man Page](https://man7.org/linux/man-pages/man1/sed.1.html)
- [sed One-Liners](http://sed.sourceforge.net/sed1line.txt)
- [Grymoire sed Tutorial](https://www.grymoire.com/Unix/Sed.html)