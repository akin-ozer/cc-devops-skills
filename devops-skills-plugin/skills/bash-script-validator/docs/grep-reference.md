# GNU grep Reference Guide

## Overview

grep (Global Regular Expression Print) searches for patterns in text files. It's one of the most commonly used Unix tools.

**Official Manual:** https://www.gnu.org/software/grep/manual/
**Man Page:** `man grep`

## Basic Syntax

```bash
grep [OPTIONS] PATTERN [FILE...]
grep [OPTIONS] -e PATTERN ... [FILE...]
grep [OPTIONS] -f PATTERN_FILE ... [FILE...]
```

## Common Options

### Basic Options
```bash
-i, --ignore-case          # Case-insensitive search
-v, --invert-match         # Invert match (select non-matching lines)
-w, --word-regexp          # Match whole words only
-x, --line-regexp          # Match whole lines only
-c, --count                # Count matching lines
-n, --line-number          # Show line numbers
-H, --with-filename        # Print filename with matches
-h, --no-filename          # Suppress filename output
-l, --files-with-matches   # Print only filenames with matches
-L, --files-without-match  # Print only filenames without matches
```

### Context Options
```bash
-A NUM, --after-context=NUM     # Print NUM lines after match
-B NUM, --before-context=NUM    # Print NUM lines before match
-C NUM, --context=NUM           # Print NUM lines before and after
```

### Regular Expression Options
```bash
-E, --extended-regexp      # Use Extended Regular Expressions (ERE)
-F, --fixed-strings        # Treat PATTERN as fixed strings, not regex
-G, --basic-regexp         # Use Basic Regular Expressions (BRE) - default
-P, --perl-regexp          # Use Perl-compatible regex (PCRE)
```

### Output Options
```bash
-o, --only-matching        # Print only matched parts
-q, --quiet, --silent      # Suppress output, just return exit code
--color[=WHEN]             # Colorize output (auto, always, never)
-s, --no-messages          # Suppress error messages
```

### File Selection
```bash
-r, --recursive            # Recursive search
-R, --dereference-recursive # Recursive, following symlinks
--include=PATTERN          # Search only files matching PATTERN
--exclude=PATTERN          # Skip files matching PATTERN
--exclude-dir=PATTERN      # Skip directories matching PATTERN
```

## Common Usage Patterns

### Basic Searches
```bash
# Simple string search
grep "error" logfile.txt

# Case-insensitive search
grep -i "error" logfile.txt

# Search for whole word
grep -w "error" logfile.txt

# Count matches
grep -c "error" logfile.txt

# Show line numbers
grep -n "error" logfile.txt
```

### Multiple Files
```bash
# Search in multiple files
grep "pattern" file1.txt file2.txt

# Search in all txt files
grep "pattern" *.txt

# Recursive search
grep -r "pattern" /path/to/dir

# Recursive with file pattern
grep -r --include="*.log" "error" /var/log
```

### Context Display
```bash
# Show 3 lines after match
grep -A 3 "error" logfile.txt

# Show 3 lines before match
grep -B 3 "error" logfile.txt

# Show 3 lines before and after
grep -C 3 "error" logfile.txt
```

### Invert Match
```bash
# Show lines that DON'T contain pattern
grep -v "debug" logfile.txt

# Exclude multiple patterns
grep -v "debug\|info" logfile.txt
```

### Multiple Patterns
```bash
# Match any pattern (OR)
grep -e "error" -e "warning" file.txt
grep "error\|warning" file.txt

# Match all patterns (AND) - requires pipeline
grep "error" file.txt | grep "critical"
```

### File Selection
```bash
# List files containing match
grep -l "pattern" *.txt

# List files NOT containing match
grep -L "pattern" *.txt

# Recursive with excludes
grep -r --exclude-dir=".git" "pattern" .
grep -r --exclude="*.min.js" "pattern" .
```

## Regular Expressions in grep

### Basic Regular Expressions (BRE) - Default

```bash
# BRE Metacharacters (no escaping needed)
.       # Any single character
^       # Start of line
$       # End of line
[...]   # Character class
[^...]  # Negated character class
*       # Zero or more of previous

# BRE Metacharacters (MUST be escaped)
\+      # One or more (requires \)
\?      # Zero or one (requires \)
\{m,n\} # Between m and n occurrences (requires \)
\(...\) # Group (requires \)
\|      # Alternation (requires \)
```

### BRE Examples
```bash
# Match lines starting with "Error"
grep "^Error" file.txt

# Match lines ending with "failed"
grep "failed$" file.txt

# Match any character
grep "a.c" file.txt  # Matches abc, aXc, a5c

# Character class
grep "[0-9]" file.txt  # Match any digit
grep "[A-Za-z]" file.txt  # Match any letter

# One or more (escaped)
grep "a\+b" file.txt  # Matches ab, aab, aaab

# Groups and alternation (escaped)
grep "\(error\|warning\)" file.txt
```

### Extended Regular Expressions (ERE) - grep -E

```bash
# ERE - No escaping needed for +, ?, |, (), {}
+       # One or more
?       # Zero or one
{m,n}   # Between m and n occurrences
(...)   # Group
|       # Alternation
```

### ERE Examples
```bash
# One or more (no escape)
grep -E "a+b" file.txt

# Zero or one
grep -E "colou?r" file.txt  # Matches color or colour

# Alternation
grep -E "(error|warning)" file.txt

# Quantifiers
grep -E "[0-9]{3}-[0-9]{4}" file.txt  # Phone: 123-4567
grep -E "[0-9]{1,3}" file.txt  # 1 to 3 digits

# Groups
grep -E "(http|https)://[^ ]+" file.txt  # URLs
```

## Character Classes

### POSIX Character Classes
```bash
[:alnum:]   # Alphanumeric [A-Za-z0-9]
[:alpha:]   # Alphabetic [A-Za-z]
[:digit:]   # Digits [0-9]
[:lower:]   # Lowercase [a-z]
[:upper:]   # Uppercase [A-Z]
[:space:]   # Whitespace [ \t\n\r\f\v]
[:blank:]   # Space and tab [ \t]
[:punct:]   # Punctuation
[:xdigit:]  # Hex digits [0-9A-Fa-f]
[:word:]    # Word characters [A-Za-z0-9_]
```

### Usage
```bash
# Match any digit
grep "[[:digit:]]" file.txt

# Match any whitespace
grep "[[:space:]]" file.txt

# Match uppercase letters
grep "[[:upper:]]" file.txt
```

## Practical Examples for Shell Scripts

### Log File Analysis
```bash
# Find errors in last hour
grep "$(date -d '1 hour ago' '+%Y-%m-%d %H')" /var/log/app.log | grep -i error

# Count error types
grep -i "error" logfile.log | cut -d: -f2 | sort | uniq -c | sort -rn

# Extract IP addresses
grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' access.log
```

### Configuration Validation
```bash
# Find uncommented lines in config
grep -v "^#" config.file | grep -v "^$"

# Check for specific settings
if grep -q "debug = true" config.ini; then
    echo "Debug mode is enabled"
fi
```

### Code Search
```bash
# Find function definitions
grep -n "^function " script.sh

# Find TODO comments
grep -rn "TODO" --include="*.sh" .

# Find unquoted variables (simple check)
grep -n '\$[A-Za-z_][A-Za-z0-9_]*\s' script.sh
```

## Performance Tips

### 1. Use -F for Fixed Strings
```bash
# Faster when not using regex
grep -F "literal string" large_file.txt
```

### 2. Use -q When Only Checking Existence
```bash
# Don't need output, just exit code
if grep -q "pattern" file.txt; then
    echo "Found"
fi
```

### 3. Limit Search Depth
```bash
# Don't recurse too deep
grep -r --max-depth=2 "pattern" /path
```

### 4. Exclude Unnecessary Directories
```bash
grep -r --exclude-dir={.git,.svn,node_modules} "pattern" .
```

## Exit Codes

- **0**: Match found
- **1**: No match found
- **2**: Error occurred

## Common Pitfalls in Shell Scripts

### 1. Not Quoting Patterns with Spaces
```bash
# Wrong
grep $pattern file.txt

# Right
grep "$pattern" file.txt
```

### 2. Using grep in Tests Without -q
```bash
# Inefficient
if [ "$(grep pattern file)" ]; then

# Better
if grep -q pattern file; then
```

### 3. Useless Use of cat
```bash
# Wrong (UUOC)
cat file | grep pattern

# Right
grep pattern file
# or
< file grep pattern
```

### 4. Not Handling No Match Case
```bash
# grep returns 1 if no match, can cause set -e to exit
grep "pattern" file || true

# Or check explicitly
if grep -q "pattern" file; then
    echo "Found"
else
    echo "Not found"
fi
```

### 5. Forgetting to Escape Regex Metacharacters
```bash
# Wrong - . matches any character
grep "192.168.1.1" file

# Right - escape the dots
grep "192\.168\.1\.1" file

# Or use -F for literal match
grep -F "192.168.1.1" file
```

## Useful Combinations

```bash
# Case-insensitive recursive search with line numbers
grep -rni "pattern" /path

# Count total matches across files
grep -r "pattern" . | wc -l

# Find and highlight matches
grep --color=always "pattern" file.txt | less -R

# Search compressed files
zgrep "pattern" file.gz

# Search with extended regex and only show matches
grep -Eo "pattern" file.txt
```

## Resources

- [GNU grep Manual](https://www.gnu.org/software/grep/manual/)
- [grep(1) Linux Man Page](https://man7.org/linux/man-pages/man1/grep.1.html)
- [Regular Expressions in grep](https://www.gnu.org/software/grep/manual/html_node/Regular-Expressions.html)
