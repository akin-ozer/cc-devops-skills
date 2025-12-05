# GNU AWK (gawk) Reference Guide

## Overview

AWK is a powerful text processing language designed for pattern scanning and processing. It's particularly useful for field-based data manipulation.

**Official Manual:** https://www.gnu.org/software/gawk/manual/
**Man Page:** `man awk`

## Basic Syntax

```bash
awk 'pattern { action }' file
awk -F delimiter 'pattern { action }' file
awk -f script.awk file
```

## Structure

```awk
BEGIN { # Executed before processing }
pattern { # Executed for matching lines }
END { # Executed after processing }
```

## Built-in Variables

### Field Variables
```awk
$0      # Entire line
$1      # First field
$2      # Second field
$NF     # Last field
$(NF-1) # Second to last field
```

### Control Variables
```awk
NF      # Number of fields in current record
NR      # Current record number (line number)
FNR     # Record number in current file
FS      # Input field separator (default: whitespace)
OFS     # Output field separator (default: space)
RS      # Input record separator (default: newline)
ORS     # Output record separator (default: newline)
FILENAME # Current filename
```

## Common Usage Patterns

### Basic Field Processing
```bash
# Print specific fields
awk '{print $1}' file.txt                # First field
awk '{print $1, $3}' file.txt            # First and third fields
awk '{print $NF}' file.txt               # Last field

# Print with custom separator
awk '{print $1 ":" $2}' file.txt         # Custom separator
awk -v OFS='\t' '{print $1, $2}' file    # Tab-separated

# Print entire line with line number
awk '{print NR, $0}' file.txt
```

### Custom Field Separator
```bash
# Use comma as separator
awk -F',' '{print $1}' file.csv

# Use colon as separator (like /etc/passwd)
awk -F':' '{print $1}' /etc/passwd

# Multiple character separator
awk -F'::' '{print $2}' file.txt

# Regex as separator
awk -F'[,:]' '{print $1}' file.txt       # Comma or colon
```

### Pattern Matching
```bash
# Match lines containing pattern
awk '/pattern/ {print}' file.txt
awk '/error/ {print $0}' logfile.txt

# Case-insensitive match
awk 'tolower($0) ~ /pattern/' file.txt

# Regex on specific field
awk '$2 ~ /pattern/' file.txt
awk '$2 !~ /pattern/' file.txt  # Not matching

# Exact match
awk '$1 == "value"' file.txt
awk '$2 != "value"' file.txt
```

### Numeric Comparisons
```bash
# Greater than
awk '$3 > 100' file.txt

# Less than or equal
awk '$2 <= 50' file.txt

# Range
awk '$1 >= 10 && $1 <= 20' file.txt

# Complex conditions
awk '$1 > 100 && $2 == "active"' file.txt
awk '$1 > 100 || $2 > 200' file.txt
```

### BEGIN and END Blocks
```bash
# Header and footer
awk 'BEGIN {print "Name\tAge"} {print $1, $2} END {print "---"}' file

# Initialize variables
awk 'BEGIN {count=0} {count++} END {print count}' file

# Set field separator in BEGIN
awk 'BEGIN {FS=","} {print $1}' file.csv
```

### Calculations
```bash
# Sum a column
awk '{sum += $1} END {print sum}' file.txt

# Average
awk '{sum += $1; count++} END {print sum/count}' file

# Count records
awk 'END {print NR}' file.txt

# Max value
awk 'BEGIN {max=0} {if ($1 > max) max=$1} END {print max}' file

# Count occurrences
awk '{count[$1]++} END {for (key in count) print key, count[key]}' file
```

### Conditional Processing
```bash
# If-else
awk '{if ($1 > 100) print "High"; else print "Low"}' file

# Ternary operator
awk '{print ($1 > 100) ? "High" : "Low"}' file

# Multiple conditions
awk '{
    if ($1 > 100) print "High"
    else if ($1 > 50) print "Medium"
    else print "Low"
}' file
```

## Arrays

### Associative Arrays
```awk
# Count occurrences
awk '{count[$1]++} END {for (key in count) print key, count[key]}' file

# Group by key
awk '{sum[$1] += $2} END {for (key in sum) print key, sum[key]}' file

# Check if key exists
awk '{if ($1 in array) print "Duplicate"}' file
```

### Array Examples
```bash
# Count unique values
awk '{a[$1]++} END {print length(a)}' file

# Find duplicates
awk '{count[$1]++} END {for (k in count) if (count[k] > 1) print k}' file

# Store and print in order
awk '{lines[NR] = $0} END {for (i=1; i<=NR; i++) print lines[i]}' file
```

## Functions

### Built-in String Functions
```awk
length(string)           # String length
substr(string, start, len) # Substring
index(string, substring) # Find substring position
split(string, array, sep) # Split string into array
sub(regex, replacement, string) # Replace first match
gsub(regex, replacement, string) # Replace all matches
tolower(string)          # Convert to lowercase
toupper(string)          # Convert to uppercase
match(string, regex)     # Test regex match
```

### String Function Examples
```bash
# String length
awk '{print length($1)}' file

# Substring
awk '{print substr($1, 1, 3)}' file  # First 3 characters

# Replace
awk '{gsub(/old/, "new"); print}' file

# Convert case
awk '{print toupper($1)}' file

# Split and process
awk '{split($0, a, ":"); print a[1]}' /etc/passwd
```

### Math Functions
```awk
int(x)      # Integer part
sqrt(x)     # Square root
sin(x)      # Sine
cos(x)      # Cosine
atan2(y,x)  # Arctangent
log(x)      # Natural logarithm
exp(x)      # Exponential
rand()      # Random number [0,1)
srand()     # Seed random number generator
```

## Practical Examples for Shell Scripts

### Log File Analysis
```bash
# Count HTTP status codes
awk '{print $9}' access.log | sort | uniq -c

# Sum response times
awk '{sum += $10; count++} END {print sum/count}' access.log

# Filter by time range
awk '$4 > "[01/Jan/2025:10:00:00" && $4 < "[01/Jan/2025:11:00:00"' access.log

# Extract and count IPs
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head -10
```

### CSV Processing
```bash
# Print specific columns from CSV
awk -F',' '{print $1, $3}' file.csv

# Skip header
awk -F',' 'NR > 1 {print $1, $2}' file.csv

# Convert CSV to tab-separated
awk -F',' -v OFS='\t' '{print $1, $2, $3}' file.csv

# Filter rows
awk -F',' '$3 > 100 {print $0}' file.csv
```

### System Administration
```bash
# Parse /etc/passwd
awk -F':' '{print $1, $6}' /etc/passwd  # username, home directory
awk -F':' '$3 >= 1000 {print $1}' /etc/passwd  # Regular users

# Disk usage analysis
df -h | awk '$5 > 80 {print $0}'  # > 80% full

# Process monitoring
ps aux | awk '$3 > 50 {print $2, $11}'  # High CPU processes

# Network stats
netstat -an | awk '/ESTABLISHED/ {print $5}' | cut -d: -f1 | sort | uniq -c
```

### Data Transformation
```bash
# Swap columns
awk '{print $2, $1}' file

# Add line numbers
awk '{print NR ":", $0}' file

# Remove duplicates (keeping first occurrence)
awk '!seen[$0]++' file

# Join lines
awk '{printf "%s ", $0} END {print ""}' file

# Transpose rows to columns
awk '{for (i=1; i<=NF; i++) a[NR,i]=$i; max=(NF>max?NF:max)}
     END {for (i=1; i<=max; i++) {
         for (j=1; j<=NR; j++) printf "%s ", a[j,i]
         print ""
     }}' file
```

## Multi-line AWK Scripts

### In Shell Script
```bash
awk '
BEGIN {
    FS = ","
    print "Processing..."
}
{
    sum += $2
    count++
}
END {
    print "Average:", sum/count
}
' file.csv
```

### External AWK File
```bash
# script.awk
BEGIN {
    FS = ","
}
{
    sum += $2
}
END {
    print "Total:", sum
}

# Execute
awk -f script.awk file.csv
```

## Common Patterns

### Skip Empty Lines
```bash
awk 'NF > 0' file
awk '/./' file
```

### Print Line Range
```bash
awk 'NR>=10 && NR<=20' file  # Lines 10-20
```

### Print Unique Lines
```bash
awk '!seen[$0]++' file
```

### Count Pattern Occurrences
```bash
awk '/pattern/ {count++} END {print count}' file
```

### Format Output
```bash
# Fixed-width columns
awk '{printf "%-20s %10s\n", $1, $2}' file

# Align numbers
awk '{printf "%s: %8.2f\n", $1, $2}' file
```

## Performance Tips

### 1. Use Built-in Variables
```bash
# Faster
awk '{print $NF}' file

# Slower
awk '{print $length($0)}' file
```

### 2. Avoid Unnecessary Operations
```bash
# Good
awk '$1 > 100' file

# Wasteful
awk '{if ($1 > 100) print $0}' file
```

### 3. Use Regex Efficiently
```bash
# Compile regex once
awk 'BEGIN {pattern = /error/} $0 ~ pattern' file
```

## Common Pitfalls in Shell Scripts

### 1. Not Quoting AWK Scripts
```bash
# Wrong - shell expands $1
awk {print $1} file

# Right
awk '{print $1}' file
```

### 2. Division by Zero
```bash
# Dangerous
awk '{print $1/$2}' file

# Safe
awk '{if ($2 != 0) print $1/$2; else print "N/A"}' file
```

### 3. Floating Point Comparison
```bash
# Problematic
awk '$1 == 0.1' file

# Better
awk 'function abs(x){return x<0?-x:x} abs($1 - 0.1) < 0.001' file
```

### 4. Not Handling Missing Fields
```bash
# Check field existence
awk 'NF >= 3 {print $3}' file
```

## Combining with Other Tools

```bash
# awk with grep
grep "error" log | awk '{print $1, $NF}'

# awk with sort
awk '{print $2}' file | sort -n

# Pipeline
cat file | awk '$1 > 100' | sort | uniq
```

## Resources

- [GNU AWK Manual](https://www.gnu.org/software/gawk/manual/)
- [AWK Programming Language](https://www.amazon.com/AWK-Programming-Language-Alfred-Aho/dp/020107981X)
- [gawk(1) Man Page](https://man7.org/linux/man-pages/man1/gawk.1.html)