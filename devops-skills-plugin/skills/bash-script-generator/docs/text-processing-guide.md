# Text Processing Guide

Guide for choosing and using grep, awk, sed, and other text processing tools effectively in bash scripts.

## Decision Tree: Which Tool to Use?

```
Is it a simple pattern match/filter?
├─ YES → Use grep
└─ NO
    ├─ Is it field/column-based data?
    │   └─ YES → Use awk
    └─ NO
        ├─ Is it find-and-replace or deletion?
        │   └─ YES → Use sed
        └─ NO
            └─ Complex processing → Use awk or consider Python/Perl
```

## grep: Pattern Matching and Filtering

### When to Use grep
- Searching for patterns in files
- Filtering lines by regex
- Simple line extraction
- Counting matches
- Finding files containing patterns

### Common grep Patterns

```bash
# Basic search
grep "pattern" file.txt

# Case-insensitive
grep -i "error" log.txt

# Invert match (lines NOT containing pattern)
grep -v "DEBUG" log.txt

# Count matches
grep -c "ERROR" log.txt

# Show line numbers
grep -n "TODO" *.sh

# Extended regex (ERE)
grep -E "(error|fail|critical)" log.txt

# Recursive directory search
grep -r "function_name" src/

# Show filename only
grep -l "pattern" *.txt

# Show context (lines before/after)
grep -A 2 -B 2 "ERROR" log.txt  # 2 lines after and before

# Multiple patterns
grep -e "error" -e "fail" log.txt

# Read patterns from file
grep -f patterns.txt input.txt

# Whole word match
grep -w "test" file.txt  # Matches "test" but not "testing"

# Fixed string (not regex)
grep -F "a.b" file.txt  # Matches literal "a.b", not regex

# Binary file handling
grep -a "pattern" binary_file  # Treat binary as text
```

### grep for Log Analysis

```bash
# Extract error messages from last hour
find /var/log -name "*.log" -mmin -60 -exec grep "ERROR" {} +

# Count errors by type
grep "ERROR" app.log | cut -d':' -f3 | sort | uniq -c | sort -rn

# Find errors excluding known issues
grep "ERROR" app.log | grep -v -f known_errors.txt
```

## awk: Field-Based Text Processing

### When to Use awk
- Processing structured data (CSV, logs, tables)
- Extracting specific fields
- Performing calculations
- Generating reports
- Complex conditional logic on fields

### awk Basics

```bash
# Print specific fields (space-delimited by default)
awk '{print $1, $3}' file.txt

# Custom delimiter
awk -F',' '{print $1, $3}' data.csv
awk -F':' '{print $1}' /etc/passwd

# Multiple delimiters
awk -F'[,:]' '{print $1}' file.txt

# Print last field
awk '{print $NF}' file.txt

# Print all but first field
awk '{$1=""; print $0}' file.txt
```

### awk Conditionals

```bash
# Print lines where field 3 > 100
awk '$3 > 100' data.txt

# Print lines where field matches pattern
awk '$2 ~ /error/' log.txt

# Print lines where field does NOT match
awk '$2 !~ /DEBUG/' log.txt

# Multiple conditions
awk '$3 > 100 && $4 < 500' data.txt

# If-else logic
awk '{if ($3 > 100) print "High:", $0; else print "Low:", $0}' data.txt
```

### awk Calculations

```bash
# Sum values in column 3
awk '{sum += $3} END {print sum}' numbers.txt

# Average
awk '{sum += $3; count++} END {print sum/count}' numbers.txt

# Find max value
awk 'BEGIN {max=0} {if ($1 > max) max=$1} END {print max}' numbers.txt

# Count lines matching condition
awk '$3 > 100 {count++} END {print count}' data.txt
```

### awk Formatted Output

```bash
# Printf-style formatting
awk '{printf "Name: %-20s Age: %3d\n", $1, $2}' people.txt

# Tab-separated output
awk 'BEGIN {OFS="\t"} {print $1, $2, $3}' file.txt

# Custom output formatting
awk '{printf "%s: %10.2f\n", $1, $2}' data.txt
```

### awk Built-in Variables

```bash
NF      # Number of fields in current line
NR      # Current line number
FNR     # Line number in current file
FS      # Input field separator
OFS     # Output field separator
RS      # Input record separator
ORS     # Output record separator
FILENAME # Current filename

# Examples
awk '{print NR, NF, $0}' file.txt  # Line number, field count, full line
awk 'NR==10' file.txt              # Print line 10
awk 'NF > 5' file.txt              # Lines with more than 5 fields
```

### awk for Log Analysis

```bash
# Apache/Nginx access log analysis
# Extract status codes and count
awk '{print $9}' access.log | sort | uniq -c | sort -rn

# Summarize traffic by IP
awk '{ip[$1]++} END {for (i in ip) print ip[i], i}' access.log | sort -rn

# Calculate average response time (field 11)
awk '{sum += $11; count++} END {print sum/count}' access.log

# Extract requests by hour
awk '{print substr($4, 2, 14)}' access.log | uniq -c
```

## sed: Stream Editing

### When to Use sed
- Find and replace operations
- Deleting specific lines
- In-place file editing
- Simple transformations

### sed Substitution

```bash
# Basic substitution (first occurrence per line)
sed 's/old/new/' file.txt

# Global substitution (all occurrences)
sed 's/old/new/g' file.txt

# Case-insensitive substitution
sed 's/old/new/gi' file.txt

# In-place editing
sed -i 's/old/new/g' file.txt

# Backup before in-place edit
sed -i.bak 's/old/new/g' file.txt

# Replace only on specific line
sed '5s/old/new/' file.txt

# Replace on lines matching pattern
sed '/ERROR/s/old/new/g' file.txt

# Use different delimiter
sed 's|/usr/local|/opt|g' file.txt

# Backreferences
sed 's/\([0-9]*\)-\([0-9]*\)/\2-\1/' file.txt

# Multiple substitutions
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt
```

### sed Deletion

```bash
# Delete specific line
sed '5d' file.txt

# Delete range of lines
sed '5,10d' file.txt

# Delete lines matching pattern
sed '/pattern/d' file.txt

# Delete empty lines
sed '/^$/d' file.txt

# Delete lines NOT matching pattern
sed '/pattern/!d' file.txt
```

### sed Line Operations

```bash
# Print specific line
sed -n '10p' file.txt

# Print range
sed -n '10,20p' file.txt

# Print lines matching pattern
sed -n '/ERROR/p' file.txt

# Insert line before match
sed '/pattern/i\New line before' file.txt

# Append line after match
sed '/pattern/a\New line after' file.txt

# Change entire line
sed '/pattern/c\Replacement line' file.txt
```

### sed Advanced Patterns

```bash
# Remove comments
sed 's/#.*//' file.txt

# Remove leading whitespace
sed 's/^[ \t]*//' file.txt

# Remove trailing whitespace
sed 's/[ \t]*$//' file.txt

# Remove HTML tags
sed 's/<[^>]*>//g' file.html

# Extract text between delimiters
sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' file.html
```

## Combining Tools: Pipeline Patterns

### grep + awk

```bash
# Filter then extract fields
grep "ERROR" log.txt | awk '{print $1, $5}'

# Filter multiple patterns, process
grep -E "ERROR|WARN" log.txt | awk '{count[$2]++} END {for (i in count) print i, count[i]}'
```

### sed + awk

```bash
# Clean then process
sed 's/[^[:print:]]//g' data.txt | awk '{sum += $2} END {print sum}'

# Remove comments, extract fields
sed 's/#.*//' config.txt | awk -F'=' '{print $1}'
```

### Complete Pipeline Example

```bash
# Analyze web server logs
cat access.log \
    | grep "GET" \
    | grep -v "robot" \
    | sed 's/.*HTTP\/[0-9.]*" //' \
    | awk '$1 >= 200 && $1 < 300 {success++} $1 >= 400 {fail++} END {print "Success:", success, "Fail:", fail}'
```

## Performance Tips

### grep Performance

```bash
# Use -F for fixed strings (faster than regex)
grep -F "literal.string" large_file.txt

# Use -m to stop after N matches
grep -m 10 "pattern" large_file.txt

# Parallel grep for large files
parallel -j4 grep "pattern" ::: chunk1 chunk2 chunk3 chunk4
```

### awk Performance

```bash
# Exit early if possible
awk '{if (condition) {print; exit}}' large_file.txt

# Process only needed lines
awk 'NR > 1000 {exit} {process}' large_file.txt

# Use built-in functions efficiently
awk '{count[$1]++} END {for (i in count) print i, count[i]}' file.txt
```

### sed Performance

```bash
# Minimize patterns
sed -e 's/a/b/g' -e 's/c/d/g' file.txt  # Better than multiple sed calls

# Use in-place editing for large files
sed -i 's/old/new/g' large_file.txt  # Avoids loading entire file
```

### Avoid Useless Use of cat

```bash
# Bad
cat file.txt | grep "pattern"
cat file.txt | awk '{print $1}'
cat file.txt | sed 's/old/new/g'

# Good
grep "pattern" file.txt
awk '{print $1}' file.txt
sed 's/old/new/g' file.txt
```

## Real-World Examples

### Example 1: CSV Processing

```bash
# Extract specific columns from CSV
awk -F',' '{print $1, $3, $5}' data.csv

# Filter rows by value
awk -F',' '$3 > 1000 {print $0}' data.csv

# Calculate sum per category
awk -F',' '{sum[$1] += $3} END {for (cat in sum) print cat, sum[cat]}' sales.csv
```

### Example 2: Log Analysis

```bash
# Error rate over time
grep "ERROR" app.log \
    | awk '{print $1}' \
    | uniq -c \
    | awk '{print $2, $1}'

# Top 10 error messages
grep "ERROR" app.log \
    | sed 's/.*ERROR: //' \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -10
```

### Example 3: Configuration File Processing

```bash
# Extract non-comment, non-empty lines
sed -e 's/#.*//' -e '/^$/d' config.txt

# Convert KEY=VALUE to JSON
awk -F'=' 'BEGIN {print "{"} {printf "  \"%s\": \"%s\",\n", $1, $2} END {print "}"}' config.txt
```

---

## References

- [GNU grep Manual](https://www.gnu.org/software/grep/manual/grep.html)
- [GNU awk Manual](https://www.gnu.org/software/gawk/manual/gawk.html)
- [GNU sed Manual](https://www.gnu.org/software/sed/manual/sed.html)
- [The Art of Command Line](https://github.com/jlevy/the-art-of-command-line)