# Regular Expressions Reference Guide

## Overview

Regular expressions (regex) are patterns used to match character combinations in strings. POSIX defines two flavors: Basic (BRE) and Extended (ERE).

**POSIX Specification:** https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html

## BRE vs ERE

| Feature | BRE | ERE |
|---------|-----|-----|
| One or more | `\+` | `+` |
| Zero or one | `\?` | `?` |
| Alternation | `\|` | `|` |
| Grouping | `\(...\)` | `(...)` |
| Quantifiers | `\{m,n\}` | `{m,n}` |

### Tool Usage

```bash
# BRE (Basic)
grep 'pattern' file          # BRE by default
sed 's/pattern/repl/' file   # BRE by default
awk '/pattern/' file         # ERE by default

# ERE (Extended)
grep -E 'pattern' file       # ERE
egrep 'pattern' file         # ERE (deprecated, use grep -E)
sed -E 's/pattern/repl/' file # ERE
```

## Basic Metacharacters (Both BRE and ERE)

### Single Character Matchers
```regex
.           # Any single character except newline
[abc]       # Any character in set (a, b, or c)
[^abc]      # Any character NOT in set
[a-z]       # Any character in range
[0-9]       # Any digit
```

### Anchors
```regex
^           # Start of line
$           # End of line
\<          # Start of word (GNU extension)
\>          # End of word (GNU extension)
\b          # Word boundary (some tools)
\B          # Not a word boundary (some tools)
```

### Quantifiers (Zero or More)
```regex
*           # Zero or more of previous (both BRE and ERE)
```

## Extended Metacharacters

### ERE Quantifiers
```regex
+           # One or more (ERE: +) (BRE: \+)
?           # Zero or one (ERE: ?) (BRE: \?)
{n}         # Exactly n (ERE: {n}) (BRE: \{n\})
{n,}        # n or more (ERE: {n,}) (BRE: \{n,\})
{n,m}       # Between n and m (ERE: {n,m}) (BRE: \{n,m\})
```

### Grouping and Alternation
```regex
# ERE
(pattern)   # Group
pattern1|pattern2  # Alternation (OR)

# BRE (requires backslashes)
\(pattern\)        # Group
pattern1\|pattern2  # Alternation (OR)
```

## POSIX Character Classes

Must be used inside bracket expressions `[[:class:]]`:

```regex
[:alnum:]   # Alphanumeric [A-Za-z0-9]
[:alpha:]   # Alphabetic [A-Za-z]
[:digit:]   # Digits [0-9]
[:lower:]   # Lowercase [a-z]
[:upper:]   # Uppercase [A-Z]
[:space:]   # Whitespace [ \t\n\r\f\v]
[:blank:]   # Space and tab [ \t]
[:punct:]   # Punctuation
[:xdigit:]  # Hexadecimal [0-9A-Fa-f]
[:word:]    # Word characters [A-Za-z0-9_] (GNU extension)
[:graph:]   # Visible characters (not space)
[:print:]   # Printable characters (including space)
[:cntrl:]   # Control characters
```

### Usage
```bash
# Match any digit
grep '[[:digit:]]' file

# Match any whitespace
grep '[[:space:]]' file

# Match alphanumeric
grep '[[:alnum:]]' file

# Negation
grep '[^[:digit:]]' file    # Not a digit
```

## Common Patterns

### Numbers
```bash
# BRE
[0-9]                       # Single digit
[0-9]\+                     # One or more digits
[0-9]\{3\}                  # Exactly 3 digits
[0-9]\{3,5\}                # 3 to 5 digits

# ERE
[0-9]                       # Single digit
[0-9]+                      # One or more digits
[0-9]{3}                    # Exactly 3 digits
[0-9]{3,5}                  # 3 to 5 digits
```

### IP Addresses
```bash
# Simple (BRE)
grep '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' file

# Simple (ERE)
grep -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' file

# More strict (ERE)
grep -E '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' file
```

### Email Addresses
```bash
# Simple (ERE)
grep -E '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' file

# BRE
grep '[a-zA-Z0-9._%+-]\+@[a-zA-Z0-9.-]\+\.[a-zA-Z]\{2,\}' file
```

### URLs
```bash
# Simple HTTP/HTTPS (ERE)
grep -E 'https?://[a-zA-Z0-9./?=_-]+' file

# BRE
grep 'https\?://[a-zA-Z0-9./?=_-]\+' file
```

### Phone Numbers
```bash
# Format: 123-456-7890 (ERE)
grep -E '[0-9]{3}-[0-9]{3}-[0-9]{4}' file

# Format: (123) 456-7890 (ERE)
grep -E '\([0-9]{3}\) [0-9]{3}-[0-9]{4}' file

# BRE
grep '\([0-9]\{3\}\) [0-9]\{3\}-[0-9]\{4\}' file
```

### Dates
```bash
# YYYY-MM-DD (ERE)
grep -E '[0-9]{4}-[0-9]{2}-[0-9]{2}' file

# MM/DD/YYYY (ERE)
grep -E '[0-9]{2}/[0-9]{2}/[0-9]{4}' file

# BRE
grep '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' file
```

## Shell Script Patterns

### Variable Names
```bash
# Valid bash variable name (ERE)
grep -E '^[a-zA-Z_][a-zA-Z0-9_]*=' file

# Find variable usage
grep -E '\$[a-zA-Z_][a-zA-Z0-9_]*' file
grep -E '\$\{[a-zA-Z_][a-zA-Z0-9_]*\}' file
```

### Function Definitions
```bash
# POSIX function (ERE)
grep -E '^[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)' file

# Bash function keyword (ERE)
grep -E '^function [a-zA-Z_][a-zA-Z0-9_]*' file
```

### Comments
```bash
# Shell comments
grep '^[[:space:]]*#' file

# Uncommented lines
grep -v '^[[:space:]]*#' file
```

## Escaping Special Characters

Characters that need escaping (context-dependent):

```regex
.  *  [  ]  ^  $  \  (  )  {  }  +  ?  |
```

### Literal Matching
```bash
# Match literal dot (BRE and ERE)
grep '\.' file

# Match literal asterisk
grep '\*' file

# Match literal dollar sign
grep '\$' file

# Match literal brackets
grep '\[' file
grep '\]' file
```

## Backreferences

### Capture and Reuse
```bash
# BRE - capture with \(...\), reference with \1, \2, etc.
sed 's/\([0-9]\+\)-\([0-9]\+\)/\2-\1/' file  # Swap numbers

# ERE - capture with (...), reference with \1, \2, etc.
sed -E 's/([0-9]+)-([0-9]+)/\2-\1/' file

# Find duplicate words
grep -E '\b([a-z]+) \1\b' file
```

### Examples
```bash
# Extract and rearrange (BRE)
sed 's/\([A-Z][a-z]*\), \([A-Z][a-z]*\)/\2 \1/' file

# ERE
sed -E 's/([A-Z][a-z]*), ([A-Z][a-z]*)/\2 \1/' file

# Find repeated lines
grep -E '^(.*)$\n\1$' file
```

## Greedy vs Non-Greedy

POSIX regex is always greedy (matches longest possible string):

```bash
# Always greedy in POSIX
echo "foo bar baz" | grep -o 'f.*b'  # Matches "foo bar b"

# For non-greedy, you need to be creative
echo "foo bar baz" | grep -o 'f[^b]*b'  # Matches "foo b"
```

## Lookahead and Lookbehind

**NOT supported in POSIX BRE/ERE**. Only available in PCRE (Perl-Compatible Regular Expressions):

```bash
# PCRE only (not POSIX)
grep -P '(?<=foo)bar' file      # Lookbehind
grep -P 'foo(?=bar)' file       # Lookahead
```

## Common Mistakes

### 1. Forgetting to Escape in BRE
```bash
# Wrong (BRE)
grep '(foo|bar)' file

# Right (BRE)
grep '\(foo\|bar\)' file

# Or use ERE
grep -E '(foo|bar)' file
```

### 2. Using + in BRE Without Escape
```bash
# Wrong (BRE)
grep '[0-9]+' file

# Right (BRE)
grep '[0-9]\+' file

# Or use ERE
grep -E '[0-9]+' file
```

### 3. Not Escaping Dots for Literal Match
```bash
# Wrong - matches any character
grep '192.168.1.1' file

# Right - matches literal dots
grep '192\.168\.1\.1' file
```

### 4. Greedy Matching Issues
```bash
# Matches too much
echo '<tag>content</tag>' | sed 's/<.*>//'  # Empty!

# Better
echo '<tag>content</tag>' | sed 's/<[^>]*>//'
```

### 5. Character Class Mistakes
```bash
# Wrong - not a range
grep '[a-Z]' file  # Undefined behavior

# Right
grep '[a-zA-Z]' file

# Or use POSIX class
grep '[[:alpha:]]' file
```

## Testing Regex

### Online Tools
- regex101.com (supports PCRE, not POSIX)
- regexr.com
- regexpal.com

### Command Line Testing
```bash
# Test with echo
echo "test string" | grep 'pattern'

# Show matches only
echo "test string" | grep -o 'pattern'

# Test with multiple lines
printf 'line1\nline2\nline3\n' | grep 'pattern'

# Color highlighting
grep --color=always 'pattern' file | less -R
```

## Quick Reference Table

| Pattern | BRE | ERE | Matches |
|---------|-----|-----|---------|
| Literal | `abc` | `abc` | abc |
| Any char | `.` | `.` | any single character |
| Start | `^` | `^` | start of line |
| End | `$` | `$` | end of line |
| Zero or more | `*` | `*` | 0+ of previous |
| One or more | `\+` | `+` | 1+ of previous |
| Zero or one | `\?` | `?` | 0 or 1 of previous |
| Exactly n | `\{n\}` | `{n}` | exactly n |
| n or more | `\{n,\}` | `{n,}` | n or more |
| n to m | `\{n,m\}` | `{n,m}` | between n and m |
| Group | `\(...\)` | `(...)` | capture group |
| Alternation | `\|` | `|` | OR |
| Character class | `[abc]` | `[abc]` | a, b, or c |
| Negated class | `[^abc]` | `[^abc]` | not a, b, or c |
| Range | `[a-z]` | `[a-z]` | lowercase letters |

## Resources

- [POSIX Regular Expressions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap09.html)
- [Regular-Expressions.info](https://www.regular-expressions.info/posix.html)
- [GNU grep Manual - Regular Expressions](https://www.gnu.org/software/grep/manual/html_node/Regular-Expressions.html)