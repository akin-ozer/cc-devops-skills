# Script Generation Best Practices

Guidelines for generating high-quality, maintainable bash scripts.

## Core Principles

1. **Security First** - Validate inputs, quote variables, avoid injection
2. **Fail Fast** - Use strict mode, check errors immediately
3. **Self-Documenting** - Clear names, usage text, comments for complex logic
4. **Testable** - Modular functions, predictable behavior
5. **Maintainable** - Consistent style, organized structure

## Script Structure Template

```bash
#!/usr/bin/env bash
#
# Script Name: descriptive-name.sh
# Description: What it does in one line
# Usage: script.sh [OPTIONS] ARGUMENTS
# Author: Name
# Created: Date
#

set -euo pipefail
IFS=$'\n\t'

# Constants (UPPERCASE, readonly)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Global variables (lowercase or Mixed_Case)
verbose=false
dry_run=false

# Functions (lowercase_with_underscores)
usage() { }
cleanup() { }
main() { }

# Signal handlers
trap cleanup EXIT ERR INT TERM

# Execute
main "$@"
```

## Naming Conventions

```bash
# Constants - UPPERCASE with readonly
readonly MAX_RETRIES=3
readonly CONFIG_FILE="/etc/app.conf"

# Environment variables - UPPERCASE
export PATH="${HOME}/bin:${PATH}"
export LOG_LEVEL="INFO"

# Global variables - lowercase or Mixed_Case
script_version="1.0.0"
temp_directory=""

# Functions - lowercase_with_underscores
process_file() { }
send_notification() { }

# Local variables - lowercase
local count=0
local file_path=""
```

## Security Best Practices

```bash
# 1. Always quote variables
rm "${file}"                    # Good
rm $file                        # Bad

# 2. Validate all inputs
[[ "${input}" =~ ^[a-zA-Z0-9_-]+$ ]] || die "Invalid input"

# 3. Never use eval with user input
eval "${user_command}"          # Dangerous!

# 4. Validate file paths
[[ "${file}" =~ /etc ]] && die "Cannot modify /etc"
[[ -f "${file}" ]] || die "File not found"

# 5. Use $() instead of backticks
output=$(command)               # Good
output=`command`                # Bad

# 6. Set safe IFS
IFS=$'\n\t'
```

## Error Handling Patterns

```bash
# Pattern 1: Die function
die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Pattern 2: Check prerequisites
check_command() {
    command -v "$1" &> /dev/null || die "Required: $1"
}

# Pattern 3: Validate inputs
[[ $# -ge 1 ]] || die "Usage: $0 FILE"
[[ -f "$1" ]] || die "File not found: $1"

# Pattern 4: Cleanup on exit
cleanup() {
    [[ -n "${temp_dir:-}" ]] && rm -rf "${temp_dir}"
}
trap cleanup EXIT
```

## Function Design

```bash
# Good function design
#######################################
# Process a log file and extract errors
# Globals:
#   LOG_LEVEL
# Arguments:
#   $1 - Path to log file
#   $2 - Output file (optional)
# Outputs:
#   Writes errors to stdout or file
# Returns:
#   0 on success, 1 on error
#######################################
process_log_file() {
    local log_file="$1"
    local output_file="${2:-}"

    # Validate
    [[ -f "${log_file}" ]] || return 1

    # Process
    local errors
    errors=$(grep "ERROR" "${log_file}")

    # Output
    if [[ -n "${output_file}" ]]; then
        echo "${errors}" > "${output_file}"
    else
        echo "${errors}"
    fi

    return 0
}
```

## Code Organization

```bash
# Recommended order:
1. Shebang and header comments
2. Strict mode settings
3. Constants
4. Global variables
5. Helper functions (general → specific)
6. Main logic functions
7. Main function
8. Signal handlers
9. Main execution
```

## Generated Code Quality Checklist

- [ ] Proper shebang: `#!/usr/bin/env bash`
- [ ] Strict mode enabled: `set -euo pipefail`
- [ ] All variables quoted: `"${var}"`
- [ ] Constants marked readonly
- [ ] Functions documented
- [ ] Error handling implemented
- [ ] Usage/help function included
- [ ] Input validation present
- [ ] Cleanup on exit (trap)
- [ ] No ShellCheck warnings
- [ ] Comments for complex logic
- [ ] Consistent formatting

## References

- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [ShellCheck](https://www.shellcheck.net/)