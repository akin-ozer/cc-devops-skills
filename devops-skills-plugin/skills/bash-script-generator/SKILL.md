---
name: bash-script-generator
description: Comprehensive toolkit for generating best practice bash scripts following current standards and conventions. Use this skill when creating new bash scripts, implementing shell automation, text processing workflows, or building production-ready command-line tools.
---

# Bash Script Generator

## Overview

This skill provides a comprehensive workflow for generating production-ready bash scripts with best practices built-in. Generate scripts for system administration, text processing, API clients, automation workflows, and more with robust error handling, logging, argument parsing, and validation.

## When to Use This Skill

Invoke this skill when:
- Creating new bash scripts from scratch
- Implementing shell automation or system administration tasks
- Building command-line tools and utilities
- Creating text processing workflows (log analysis, data transformation, etc.)
- Converting manual command sequences into reusable scripts
- Implementing deployment or build automation scripts
- Creating cron jobs or scheduled tasks
- The user asks to "create", "generate", "build", or "write" a bash script
- Implementing scripts that use grep, awk, sed, or other text processing tools

## Mandatory Steps (DO NOT SKIP)

The following steps are **REQUIRED** for every script generation. Skipping these steps will result in scripts that don't meet user needs or fail validation.

---

## MANDATORY: Pre-Generation Requirements

**BEFORE generating any script, you MUST complete these steps:**

### 1. Clarify Requirements with User (REQUIRED)

**Use AskUserQuestion tool** if ANY of the following are unclear or unspecified:

| Ambiguity | Question to Ask |
|-----------|-----------------|
| Log/data format unknown | "What format is the input data? (e.g., nginx combined log, JSON, CSV, custom)" |
| Large file handling | "Will this process large files (>100MB)? Should we optimize for memory/performance?" |
| Error handling preference | "How should errors be handled? (fail fast, continue with warnings, retry)" |
| Security context | "Will this script handle sensitive data or run with elevated privileges?" |
| Portability needs | "Does this need to run on different systems? (bash-specific vs POSIX sh)" |
| Output format unclear | "What format should the output be? (human-readable, JSON, CSV, etc.)" |

**DO NOT skip this step.** Assumptions lead to scripts that don't meet user needs.

### 2. Explain Your Approach (REQUIRED)

**Before writing code**, explain to the user:

1. **Script Architecture**: What components and functions you'll create
2. **Tool Selection**: Why you're choosing grep/awk/sed/etc. for specific tasks
   - Reference: `docs/text-processing-guide.md` for tool selection rationale
3. **Key Design Decisions**: Any tradeoffs or assumptions you're making
4. **Customization Points**: What the user might want to modify

**Example pre-generation explanation:**
```
I'll create a log analyzer with these components:

**Architecture:**
- Main function with argument parsing (getopts pattern)
- 4 analysis functions: analyze_ips(), analyze_status_codes(), etc.
- Logging functions for INFO/DEBUG/ERROR output
- Cleanup trap for signal handling

**Tool Selection:**
- awk for status code analysis (single-pass counting, as recommended in
  docs/text-processing-guide.md)
- grep for date filtering (simple pattern matching)
- sort | uniq -c for frequency counting

**Customization Points:**
- LOG_FORMAT variable for different nginx configurations
- TOP_N constant for number of results to show

Shall I proceed with this design?
```

### 3. Consider Using the Template (RECOMMENDED)

**When to use the template:**
- **Use template** for quick starts on standard scripts with typical structure (CLI tools, automation scripts)
- **Manual generation** is better for highly customized scripts with unique requirements or non-standard architectures

For standard scripts, invoke the template generator:
```bash
bash scripts/generate_script_template.sh standard output-script.sh
```

This ensures consistent structure with all required components pre-configured. The template includes:
- Proper shebang and strict mode
- Logging functions (debug, info, warn, error)
- Error handling (die, check_command, validate_file)
- Argument parsing boilerplate
- Cleanup trap handlers

Then customize the generated template for your specific use case.

---

## Script Generation Workflow

Follow this workflow when generating bash scripts. Adapt based on user needs:

### Stage 1: Understand Requirements

Gather information about what the script needs to do:

1. **Script purpose:**
   - What problem does it solve?
   - What tasks does it automate?
   - Who will use it (developers, ops, cron, CI/CD)?

2. **Functionality requirements:**
   - Input sources (files, stdin, arguments, APIs)
   - Processing steps (text manipulation, system operations, etc.)
   - Output destinations (stdout, files, logs, APIs)
   - Expected data formats

3. **Shell type:**
   - Bash-specific (modern systems, can use arrays, associative arrays, etc.)
   - POSIX sh (maximum portability, limited features)
   - Default to bash unless portability is explicitly required

4. **Argument parsing:**
   - Command-line options needed
   - Required vs optional arguments
   - Help/usage text requirements

5. **Error handling requirements:**
   - How should errors be handled? (fail fast, retry, graceful degradation)
   - Logging verbosity levels needed?
   - Exit codes required?

6. **Performance considerations:**
   - Large file processing requirements
   - Parallel processing needs
   - Resource constraints

7. **Security requirements:**
   - Input validation needs
   - Credential handling
   - Privilege requirements

Use AskUserQuestion if information is missing or unclear.

### Stage 2: Architecture Planning

Plan the script structure based on requirements:

1. **Determine script components:**
   - Functions needed
   - Configuration management approach
   - Logging strategy
   - Error handling approach

2. **Select appropriate tools:**
   - **grep** for pattern matching and filtering
   - **awk** for structured text processing (CSV, logs, columnar data)
   - **sed** for stream editing and substitution
   - **find** for file system operations
   - **curl/wget** for HTTP operations
   - Built-in bash features when possible

3. **Plan error handling:**
   - Use `set -euo pipefail` for strict mode (recommended)
   - Define error handling functions
   - Plan cleanup procedures (trap for EXIT, ERR signals)

4. **Plan logging:**
   - Log levels needed (DEBUG, INFO, WARN, ERROR)
   - Output destinations (stderr for logs, stdout for data)
   - Log formatting

### Stage 3: Generate Script Structure

Create the basic script structure:

1. **Shebang and header:**
```bash
#!/usr/bin/env bash
#
# Script Name: script-name.sh
# Description: Brief description of what the script does
# Author: Your Name
# Created: YYYY-MM-DD
#
```

2. **Strict mode (recommended for all scripts):**
```bash
set -euo pipefail
IFS=$'\n\t'
```

Explanation:
- `set -e`: Exit on error
- `set -u`: Exit on undefined variable
- `set -o pipefail`: Exit if any command in pipeline fails
- `IFS`: Set safe Internal Field Separator

3. **Script-level variables and constants:**
```bash
# Script directory and name
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Other constants
readonly DEFAULT_CONFIG_FILE="${SCRIPT_DIR}/config.conf"
readonly LOG_FILE="/var/log/myscript.log"
```

4. **Signal handlers for cleanup:**
```bash
# Cleanup function
cleanup() {
    local exit_code=$?
    # Add cleanup logic here
    # Remove temp files, release locks, etc.
    exit "${exit_code}"
}

# Set trap for cleanup
trap cleanup EXIT ERR INT TERM
```

### Stage 4: Generate Core Functions

Generate essential functions based on requirements:

#### Logging Functions

```bash
# Logging functions
log_debug() {
    if [[ "${LOG_LEVEL:-INFO}" == "DEBUG" ]]; then
        echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    fi
}

log_info() {
    echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_warn() {
    echo "[WARN] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
}

log_fatal() {
    echo "[FATAL] $(date '+%Y-%m-%d %H:%M:%S') - $*" >&2
    exit 1
}
```

#### Error Handling Functions

```bash
# Error handling
die() {
    log_error "$@"
    exit 1
}

# Check if command exists
check_command() {
    local cmd="$1"
    if ! command -v "${cmd}" &> /dev/null; then
        die "Required command '${cmd}' not found. Please install it and try again."
    fi
}

# Validate file exists and is readable
validate_file() {
    local file="$1"
    [[ -f "${file}" ]] || die "File not found: ${file}"
    [[ -r "${file}" ]] || die "File not readable: ${file}"
}
```

#### Argument Parsing Function

Using getopts for simple options:

```bash
# Parse command-line arguments
parse_args() {
    while getopts ":hvf:o:d" opt; do
        case ${opt} in
            h )
                usage
                exit 0
                ;;
            v )
                VERBOSE=true
                ;;
            f )
                INPUT_FILE="${OPTARG}"
                ;;
            o )
                OUTPUT_FILE="${OPTARG}"
                ;;
            d )
                LOG_LEVEL="DEBUG"
                ;;
            \? )
                echo "Invalid option: -${OPTARG}" >&2
                usage
                exit 1
                ;;
            : )
                echo "Option -${OPTARG} requires an argument" >&2
                usage
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))
}
```

#### Usage/Help Function

```bash
# Display usage information
usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} [OPTIONS] [ARGUMENTS]

Description:
    Brief description of what the script does

Options:
    -h          Show this help message and exit
    -v          Enable verbose output
    -f FILE     Input file path
    -o FILE     Output file path
    -d          Enable debug logging

Examples:
    ${SCRIPT_NAME} -f input.txt -o output.txt
    ${SCRIPT_NAME} -v -f data.log

EOF
}
```

### Stage 5: Generate Business Logic

Implement the core functionality based on requirements:

1. **For text processing tasks**, use appropriate tools:
   - **grep**: Pattern matching, line filtering
   - **awk**: Field extraction, calculations, formatted output
   - **sed**: Stream editing, substitutions, deletions

2. **For system administration**, include:
   - Validation of prerequisites
   - Backup procedures
   - Rollback capabilities
   - Progress indicators

3. **For API clients**, include:
   - HTTP error handling
   - Retry logic
   - Authentication handling
   - Response parsing

### Stage 6: Generate Main Function

Create the main execution flow:

```bash
# Main function
main() {
    # Parse arguments
    parse_args "$@"

    # Validate prerequisites
    check_command "grep"
    check_command "awk"

    # Validate inputs
    [[ -n "${INPUT_FILE:-}" ]] || die "Input file not specified. Use -f option."
    validate_file "${INPUT_FILE}"

    log_info "Starting processing..."

    # Main logic here
    # ...

    log_info "Processing completed successfully"
}

# Execute main function
main "$@"
```

### Stage 7: Add Documentation and Comments

Add comprehensive comments:

1. **Function documentation:**
```bash
#######################################
# Brief description of what function does
# Globals:
#   VARIABLE_NAME
# Arguments:
#   $1 - Description of first argument
#   $2 - Description of second argument
# Outputs:
#   Writes results to stdout
# Returns:
#   0 if successful, non-zero on error
#######################################
function_name() {
    # Implementation
}
```

2. **Inline comments** for complex logic
3. **Usage examples** in the header or usage function

### Stage 8: Validate Generated Script

**ALWAYS validate the generated script** using the devops-skills:bash-script-validator skill:

```
Steps:
1. Generate the bash script
2. Invoke devops-skills:bash-script-validator skill with the script file
3. Review validation results
4. Fix any issues identified (syntax, security, best practices, portability)
5. Re-validate until all checks pass
6. Provide summary of generated script and validation status
```

**Validation checklist:**
- Syntax is correct (bash -n passes)
- ShellCheck warnings addressed
- Security issues resolved (no command injection, eval with variables, etc.)
- Variables properly quoted
- Error handling implemented
- Functions follow single responsibility principle
- Script follows best practices from documentation

If validation fails, fix issues and re-validate until all checks pass.

## Text Processing Tool Selection Guide

Choose the right tool for the job:

### Use grep when:
- Searching for patterns in files
- Filtering lines that match/don't match patterns
- Counting matches
- Simple line extraction

**Examples:**
```bash
# Find error lines in log file
grep "ERROR" application.log

# Find lines NOT containing pattern
grep -v "DEBUG" application.log

# Case-insensitive search with line numbers
grep -in "warning" *.log

# Extended regex pattern
grep -E "(error|fail|critical)" app.log
```

### Use awk when:
- Processing structured data (CSV, TSV, logs with fields)
- Performing calculations on data
- Extracting specific fields
- Generating formatted reports
- Complex conditional logic

**Examples:**
```bash
# Extract specific fields (e.g., 2nd and 4th columns)
awk '{print $2, $4}' data.txt

# Sum values in a column
awk '{sum += $3} END {print sum}' numbers.txt

# Process CSV with custom delimiter
awk -F',' '{print $1, $3}' data.csv

# Conditional processing
awk '$3 > 100 {print $1, $3}' data.txt

# Formatted output
awk '{printf "Name: %-20s Age: %d\n", $1, $2}' people.txt
```

### Use sed when:
- Performing substitutions
- Deleting lines matching patterns
- In-place file editing
- Stream editing
- Simple transformations

**Examples:**
```bash
# Simple substitution (first occurrence)
sed 's/old/new/' file.txt

# Global substitution (all occurrences)
sed 's/old/new/g' file.txt

# In-place editing
sed -i 's/old/new/g' file.txt

# Delete lines matching pattern
sed '/pattern/d' file.txt

# Replace only on lines matching pattern
sed '/ERROR/s/old/new/g' log.txt

# Multiple commands
sed -e 's/foo/bar/g' -e 's/baz/qux/g' file.txt
```

### Combining tools in pipelines:

```bash
# grep to filter, awk to extract
grep "ERROR" app.log | awk '{print $1, $5}'

# sed to clean, awk to process
sed 's/[^[:print:]]//g' data.txt | awk '{sum += $2} END {print sum}'

# Multiple stages
cat access.log \
    | grep "GET" \
    | sed 's/.*HTTP\/[0-9.]*" //' \
    | awk '$1 >= 200 && $1 < 300 {count++} END {print count}'
```

## Best Practices for Generated Scripts

### Security

1. **Always quote variables:**
```bash
# Good
rm "${file}"
grep "${pattern}" "${input_file}"

# Bad - prone to word splitting and globbing
rm $file
grep $pattern $input_file
```

2. **Validate all inputs:**
```bash
# Validate file paths
[[ "${input_file}" =~ ^[a-zA-Z0-9/_.-]+$ ]] || die "Invalid file path"

# Validate numeric inputs
[[ "${count}" =~ ^[0-9]+$ ]] || die "Count must be numeric"
```

3. **Avoid eval with user input:**
```bash
# Never do this
eval "${user_input}"

# Instead, use case statements or validated inputs
case "${command}" in
    start) do_start ;;
    stop) do_stop ;;
    *) die "Invalid command" ;;
esac
```

4. **Use $() instead of backticks:**
```bash
# Good - more readable, can nest
result=$(command)
outer=$(inner $(another_command))

# Bad - hard to read, can't nest
result=`command`
```

### Performance

1. **Use built-ins when possible:**
```bash
# Good - uses bash built-in
if [[ -f "${file}" ]]; then

# Slower - spawns external process
if [ -f "${file}" ]; then
```

2. **Avoid useless use of cat (UUOC):**
```bash
# Good
grep "pattern" file.txt
awk '{print $1}' file.txt

# Bad - unnecessary cat
cat file.txt | grep "pattern"
cat file.txt | awk '{print $1}'
```

3. **Process in a single pass when possible:**
```bash
# Good - single awk call
awk '/ERROR/ {errors++} /WARN/ {warns++} END {print errors, warns}' log.txt

# Less efficient - multiple greps
errors=$(grep -c "ERROR" log.txt)
warns=$(grep -c "WARN" log.txt)
```

### Maintainability

1. **Use functions for reusable code**
2. **Keep functions focused (single responsibility)**
3. **Use meaningful variable names**
4. **Add comments for complex logic**
5. **Group related functionality**
6. **Use readonly for constants**

### Portability (when targeting POSIX sh)

1. **Avoid bash-specific features:**
```bash
# Bash-specific (arrays)
arr=(one two three)

# POSIX alternative
set -- one two three

# Bash-specific ([[ ]])
if [[ -f "${file}" ]]; then

# POSIX alternative
if [ -f "${file}" ]; then
```

2. **Test with sh:**
```bash
sh -n script.sh  # Syntax check
```

## Common Script Patterns

### Pattern 1: Simple Command-Line Tool

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] FILE

Process FILE and output results.

Options:
    -h        Show this help
    -v        Verbose output
    -o FILE   Output file (default: stdout)
EOF
}

main() {
    local verbose=false
    local output_file=""
    local input_file=""

    while getopts ":hvo:" opt; do
        case ${opt} in
            h) usage; exit 0 ;;
            v) verbose=true ;;
            o) output_file="${OPTARG}" ;;
            *) echo "Invalid option: -${OPTARG}" >&2; usage; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    input_file="${1:-}"
    [[ -n "${input_file}" ]] || { echo "Error: FILE required" >&2; usage; exit 1; }
    [[ -f "${input_file}" ]] || { echo "Error: File not found: ${input_file}" >&2; exit 1; }

    # Process file
    if [[ -n "${output_file}" ]]; then
        process_file "${input_file}" > "${output_file}"
    else
        process_file "${input_file}"
    fi
}

process_file() {
    local file="$1"
    # Processing logic here
    cat "${file}"
}

main "$@"
```

### Pattern 2: Text Processing Script

```bash
#!/usr/bin/env bash
set -euo pipefail

# Process log file: extract errors, count by type
process_log() {
    local log_file="$1"

    echo "Error Summary:"
    echo "=============="

    # Extract errors and count by type
    grep "ERROR" "${log_file}" \
        | sed 's/.*ERROR: //' \
        | sed 's/ -.*//' \
        | sort \
        | uniq -c \
        | sort -rn \
        | awk '{printf "  %-30s %d\n", $2, $1}'

    echo ""
    echo "Total errors: $(grep -c "ERROR" "${log_file}")"
}

main() {
    [[ $# -eq 1 ]] || { echo "Usage: $0 LOG_FILE" >&2; exit 1; }
    [[ -f "$1" ]] || { echo "Error: File not found: $1" >&2; exit 1; }

    process_log "$1"
}

main "$@"
```

### Pattern 3: Batch Processing with Parallel Execution

```bash
#!/usr/bin/env bash
set -euo pipefail

# Process a single file
process_file() {
    local file="$1"
    local output="${file}.processed"

    # Processing logic
    sed 's/old/new/g' "${file}" > "${output}"
    echo "Processed: ${file} -> ${output}"
}

# Export function for parallel execution
export -f process_file

main() {
    local input_dir="${1:-.}"
    local max_jobs="${2:-4}"

    # Find all files and process in parallel
    find "${input_dir}" -type f -name "*.txt" -print0 \
        | xargs -0 -P "${max_jobs}" -I {} bash -c 'process_file "$@"' _ {}
}

main "$@"
```

## Helper Scripts

The `scripts/` directory contains automation tools to assist with generation:

### generate_script_template.sh

Generates a bash script from the standard template with proper structure, error handling, and logging.

**Usage:**
```bash
bash scripts/generate_script_template.sh standard [SCRIPT_NAME]

Example:
  bash scripts/generate_script_template.sh standard myscript.sh
```

The script will copy the standard template and make it executable. You can then customize it for your specific needs.

## Documentation Resources

### Core Bash Scripting

#### docs/bash-scripting-guide.md
- Comprehensive bash scripting guide
- Bash vs POSIX sh differences
- Strict mode and error handling strategies
- Functions, scope, and variable handling
- Arrays and associative arrays
- Parameter expansion techniques
- Process substitution and command substitution
- Best practices and modern patterns

#### docs/script-patterns.md
- Common bash script patterns and templates
- Argument parsing patterns (getopts, manual)
- Configuration file handling
- Logging frameworks and approaches
- Parallel processing patterns
- Lock file management
- Signal handling and cleanup
- Retry logic and backoff strategies

#### docs/generation-best-practices.md
- Guidelines for generating quality scripts
- Code organization principles
- Naming conventions
- Documentation standards
- Testing approaches for bash scripts
- Portability considerations
- Security best practices
- Performance optimization techniques

### Text Processing Tools

#### docs/text-processing-guide.md
- When to use grep vs awk vs sed
- Combining tools effectively in pipelines
- Performance optimization for large files
- Common text processing patterns
- Real-world examples and use cases

### Tool-Specific References

**Note:** The following references are available in the devops-skills:bash-script-validator skill and are referenced by this skill:

- bash-reference.md - Bash features and syntax
- grep-reference.md - grep patterns and usage
- awk-reference.md - AWK text processing
- sed-reference.md - sed stream editing
- regex-reference.md - Regular expressions (BRE vs ERE)

## Example Scripts

Located in `examples/` directory:

### log-analyzer.sh
Demonstrates grep, awk, and sed usage for log file analysis. Shows pattern matching, field extraction, and statistical analysis. This example illustrates:
- Using grep to filter log entries
- Using awk for field extraction and formatting
- Using sed for text transformations
- Generating summary reports with proper error handling

## Template

Located in `assets/templates/` directory:

### standard-template.sh
Production-ready template with comprehensive features:
- Proper shebang (`#!/usr/bin/env bash`) and strict mode
- Logging functions (debug, info, warn, error)
- Error handling (die, check_command, validate_file)
- Argument parsing with getopts
- Cleanup trap handlers
- Usage documentation

Use this template as a starting point and customize based on your specific requirements.

## Integration with devops-skills:bash-script-validator

After generating any bash script, **automatically invoke the devops-skills:bash-script-validator skill** to ensure quality:

```
Steps:
1. Generate the bash script following the workflow above
2. Invoke devops-skills:bash-script-validator skill with the script file
3. Review validation results (syntax, ShellCheck, security, performance)
4. Fix any issues identified
5. Re-validate until all checks pass
6. Provide summary of generated script and validation status
```

This ensures all generated scripts:
- Have correct syntax
- Follow bash best practices
- Avoid common security issues
- Are optimized for performance
- Include proper error handling
- Are well-documented

## Communication Guidelines (MANDATORY)

**These are NOT optional.** Follow these guidelines for every script generation:

### Before Generation (see "MANDATORY: Pre-Generation Requirements" above)
1. ✅ Ask clarifying questions using AskUserQuestion
2. ✅ Explain your approach and get user confirmation
3. ✅ Consider using the standard template

### During Generation (REQUIRED)

**You MUST explicitly cite documentation** when using patterns or making tool selections. This helps users understand the rationale and learn best practices.

1. **In the approach explanation**, cite documentation for:
   - Tool selection rationale: "Using awk for field extraction (recommended in `docs/text-processing-guide.md` for structured data)"
   - Pattern choices: "Using getopts pattern from `docs/script-patterns.md`"
   - Best practices: "Following strict mode guidelines from `docs/bash-scripting-guide.md`"

2. **In generated code comments**, reference documentation:
   ```bash
   # Using single-pass awk processing (per docs/text-processing-guide.md)
   awk '{ip[$1]++} END {for (i in ip) print ip[i], i}' "${log_file}"
   ```

3. **Minimum citation requirement**: At least 2 documentation references must appear in:
   - The approach explanation (before code generation)
   - The Post-Generation Summary

### After Generation (REQUIRED)

Provide a **Post-Generation Summary** that includes:

```
## Generated Script Summary

**File:** path/to/script.sh

**Architecture:**
- [List main functions and their purposes]

**Tool Selection:**
- grep: [why used]
- awk: [why used]
- sed: [why used, or "not needed"]

**Key Features:**
- [Feature 1]
- [Feature 2]

**Customization Points:**
- `VARIABLE_NAME`: [what to change]
- `function_name()`: [when to modify]

**Usage Examples:**
```bash
./script.sh --help
./script.sh -v input.log
./script.sh -o report.txt input.log
```

**Validation Status:** ✅ Passed ShellCheck / ❌ Issues found (fixing...)

**Documentation References:**
- docs/text-processing-guide.md (tool selection)
- docs/script-patterns.md (argument parsing)
```

This summary ensures users understand what was generated and how to use it.

## Resources

### Official Documentation
- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/bash.html)
- [GNU grep Manual](https://www.gnu.org/software/grep/manual/grep.html)
- [GNU awk Manual](https://www.gnu.org/software/gawk/manual/gawk.html)
- [GNU sed Manual](https://www.gnu.org/software/sed/manual/sed.html)
- [POSIX Shell Specification](https://pubs.opengroup.org/onlinepubs/9699919799/)
- [ShellCheck](https://www.shellcheck.net/)

### Best Practices Guides
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Best Practices](https://bertvv.github.io/cheat-sheets/Bash.html)
- [Minimal Safe Bash Script Template](https://betterdev.blog/minimal-safe-bash-script-template/)

### Internal References
All documentation is included in the `docs/` directory for offline reference and context loading.

---

**Note**: This skill automatically validates generated scripts using the devops-skills:bash-script-validator skill, providing Claude with comprehensive feedback to ensure high-quality, production-ready bash scripts.