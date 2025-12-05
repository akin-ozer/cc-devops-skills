# Bash Script Patterns

Common patterns and templates for bash script generation.

## Table of Contents

1. [Argument Parsing Patterns](#argument-parsing-patterns)
2. [Configuration File Handling](#configuration-file-handling)
3. [Logging Frameworks](#logging-frameworks)
4. [Parallel Processing](#parallel-processing)
5. [Lock Files](#lock-files)
6. [Signal Handling](#signal-handling)
7. [Retry Logic](#retry-logic)

## Argument Parsing Patterns

### Simple getopts Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat << EOF
Usage: ${0##*/} [OPTIONS] FILE

Options:
    -h          Show this help
    -v          Verbose output
    -f FILE     Input file
    -o FILE     Output file
EOF
}

main() {
    local verbose=false
    local input_file=""
    local output_file=""

    while getopts ":hvf:o:" opt; do
        case ${opt} in
            h) usage; exit 0 ;;
            v) verbose=true ;;
            f) input_file="${OPTARG}" ;;
            o) output_file="${OPTARG}" ;;
            :) echo "Option -${OPTARG} requires an argument" >&2; exit 1 ;;
            \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    # Validation
    [[ -n "${input_file}" ]] || { echo "Error: -f required" >&2; exit 1; }

    # Process
    echo "Processing ${input_file}..."
}

main "$@"
```

### Long Options Pattern

```bash
# Parse both short and long options
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--file)
                INPUT_FILE="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Unknown option: $1" >&2
                exit 1
                ;;
            *)
                break
                ;;
        esac
    done

    # Remaining arguments
    REMAINING_ARGS=("$@")
}
```

### Subcommand Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

cmd_start() {
    echo "Starting service..."
}

cmd_stop() {
    echo "Stopping service..."
}

cmd_status() {
    echo "Checking status..."
}

usage() {
    cat << EOF
Usage: ${0##*/} COMMAND [OPTIONS]

Commands:
    start       Start the service
    stop        Stop the service
    status      Check service status

Options:
    -h, --help  Show this help
EOF
}

main() {
    [[ $# -lt 1 ]] && { usage; exit 1; }

    local command="$1"
    shift

    case "${command}" in
        start)  cmd_start "$@" ;;
        stop)   cmd_stop "$@" ;;
        status) cmd_status "$@" ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown command: ${command}" >&2; usage; exit 1 ;;
    esac
}

main "$@"
```

## Configuration File Handling

### Source-based Configuration

```bash
# config.conf file
CONFIG_VALUE="something"
MAX_RETRIES=3
API_URL="https://api.example.com"

# In script
load_config() {
    local config_file="${1:-config.conf}"

    if [[ -f "${config_file}" ]]; then
        # shellcheck source=/dev/null
        source "${config_file}"
    else
        echo "Warning: Config file not found: ${config_file}" >&2
    fi
}

load_config "/etc/myapp/config.conf"
```

### Key-Value Configuration Parser

```bash
# config.conf format:
# key=value
# # comments

load_config() {
    local config_file="$1"

    while IFS='=' read -r key value; do
        # Skip empty lines and comments
        [[ -z "${key}" || "${key}" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        key=$(echo "${key}" | tr -d '[:space:]')
        value=$(echo "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Export as variable
        declare -g "${key}=${value}"
    done < "${config_file}"
}
```

### INI-style Configuration Parser

```bash
# Parse INI format [section] key=value
parse_ini() {
    local file="$1"
    local section=""

    while IFS= read -r line; do
        # Skip empty lines and comments
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*[#;] ]] && continue

        # Section header
        if [[ "${line}" =~ ^\[([^]]+)\] ]]; then
            section="${BASH_REMATCH[1]}"
            continue
        fi

        # Key=value
        if [[ "${line}" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            key=$(echo "${key}" | tr -d '[:space:]')
            value=$(echo "${value}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # Store in associative array
            config["${section}.${key}"]="${value}"
        fi
    done < "${file}"
}
```

## Logging Frameworks

### Simple Logging with Levels

```bash
# Log level: DEBUG=0, INFO=1, WARN=2, ERROR=3
LOG_LEVEL=${LOG_LEVEL:-1}

log_debug() {
    [[ ${LOG_LEVEL} -le 0 ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_info() {
    [[ ${LOG_LEVEL} -le 1 ]] && echo "[INFO]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_warn() {
    [[ ${LOG_LEVEL} -le 2 ]] && echo "[WARN]  $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_error() {
    echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}
```

### File-based Logging

```bash
readonly LOG_FILE="${LOG_FILE:-/var/log/myscript.log}"

log_to_file() {
    local level="$1"
    shift
    echo "[${level}] $(date '+%Y-%m-%d %H:%M:%S') $*" >> "${LOG_FILE}"
}

log_info() {
    local msg="$*"
    echo "[INFO] ${msg}" >&2
    log_to_file "INFO" "${msg}"
}
```

### Structured JSON Logging

```bash
log_json() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    cat <<EOF
{"timestamp":"${timestamp}","level":"${level}","message":"${message}","script":"${SCRIPT_NAME}"}
EOF
}

log_info() {
    log_json "INFO" "$*" >&2
}
```

## Parallel Processing

### Using xargs for Parallel Execution

```bash
# Process files in parallel
find . -name "*.txt" -print0 | xargs -0 -P 4 -I {} process_file {}

# With function export
process_file() {
    echo "Processing $1..."
    # ... processing logic
}
export -f process_file

find . -name "*.txt" | xargs -P 4 -I {} bash -c 'process_file "$@"' _ {}
```

### Using GNU Parallel

```bash
# Requires: apt-get install parallel

# Simple parallel execution
parallel process_file ::: file1.txt file2.txt file3.txt

# From file list
cat files.txt | parallel process_file

# With progress bar
parallel --bar process_file ::: *.txt

# Control number of jobs
parallel -j 4 process_file ::: *.txt
```

### Background Jobs Pattern

```bash
# Track background jobs
pids=()

# Start jobs
for file in *.txt; do
    process_file "${file}" &
    pids+=($!)
done

# Wait for all jobs
for pid in "${pids[@]}"; do
    if wait "${pid}"; then
        echo "Job ${pid} completed successfully"
    else
        echo "Job ${pid} failed" >&2
    fi
done
```

## Lock Files

### Simple Lock File

```bash
readonly LOCK_FILE="/var/lock/myscript.lock"

acquire_lock() {
    if [[ -f "${LOCK_FILE}" ]]; then
        echo "Another instance is running (lock file exists)" >&2
        exit 1
    fi

    echo $$ > "${LOCK_FILE}"
    trap 'rm -f "${LOCK_FILE}"' EXIT
}

acquire_lock
```

### PID-based Lock with Stale Lock Detection

```bash
acquire_lock() {
    local lock_file="/var/lock/myscript.lock"

    if [[ -f "${lock_file}" ]]; then
        local old_pid=$(cat "${lock_file}")

        # Check if process is still running
        if kill -0 "${old_pid}" 2>/dev/null; then
            echo "Another instance (PID ${old_pid}) is running" >&2
            return 1
        else
            echo "Removing stale lock file" >&2
            rm -f "${lock_file}"
        fi
    fi

    echo $$ > "${lock_file}"
    trap 'rm -f "${lock_file}"' EXIT
}
```

### Using flock for Atomic Locking

```bash
# Requires flock command

exec 200>/var/lock/myscript.lock
flock -n 200 || { echo "Another instance is running" >&2; exit 1; }

# Script runs exclusively
# Lock is released when script exits
```

## Signal Handling

### Cleanup on Exit

```bash
cleanup() {
    local exit_code=$?
    echo "Cleaning up..." >&2

    # Remove temp files
    [[ -n "${temp_dir:-}" ]] && rm -rf "${temp_dir}"

    # Release locks
    [[ -f "${lock_file:-}" ]] && rm -f "${lock_file}"

    exit "${exit_code}"
}

trap cleanup EXIT
```

### Handling Multiple Signals

```bash
handle_sigint() {
    echo "Received SIGINT, cleaning up..." >&2
    cleanup
    exit 130  # Standard exit code for SIGINT
}

handle_sigterm() {
    echo "Received SIGTERM, cleaning up..." >&2
    cleanup
    exit 143  # Standard exit code for SIGTERM
}

trap handle_sigint INT
trap handle_sigterm TERM
trap cleanup EXIT ERR
```

### Graceful Shutdown

```bash
SHUTDOWN=false

handle_signal() {
    echo "Shutdown signal received, finishing current work..." >&2
    SHUTDOWN=true
}

trap handle_signal INT TERM

# Main processing loop
while [[ "${SHUTDOWN}" == "false" ]]; do
    process_next_item || break
done

echo "Graceful shutdown complete" >&2
```

## Retry Logic

### Simple Retry with Backoff

```bash
retry() {
    local max_attempts=3
    local delay=1
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        else
            echo "Attempt ${attempt} failed, retrying in ${delay}s..." >&2
            sleep "${delay}"
            ((attempt++))
            ((delay*=2))  # Exponential backoff
        fi
    done

    echo "All ${max_attempts} attempts failed" >&2
    return 1
}

# Usage
retry curl -f https://api.example.com/data
```

### Advanced Retry with Custom Parameters

```bash
retry_with_backoff() {
    local max_attempts="${1}"
    local delay="${2}"
    local max_delay="${3:-60}"
    shift 3
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        fi

        if [[ ${attempt} -lt ${max_attempts} ]]; then
            echo "Attempt ${attempt}/${max_attempts} failed" >&2
            echo "Retrying in ${delay}s..." >&2
            sleep "${delay}"

            # Exponential backoff with max cap
            delay=$((delay * 2))
            [[ ${delay} -gt ${max_delay} ]] && delay=${max_delay}
        fi

        ((attempt++))
    done

    echo "All ${max_attempts} attempts failed" >&2
    return 1
}

# Usage: retry_with_backoff MAX_ATTEMPTS INITIAL_DELAY MAX_DELAY command args...
retry_with_backoff 5 1 30 curl -f https://api.example.com/data
```

### Retry with Jitter

```bash
retry_with_jitter() {
    local max_attempts="$1"
    local base_delay="$2"
    shift 2
    local attempt=1

    while [[ ${attempt} -le ${max_attempts} ]]; do
        if "$@"; then
            return 0
        fi

        if [[ ${attempt} -lt ${max_attempts} ]]; then
            # Add random jitter (0-100% of delay)
            local jitter=$((RANDOM % base_delay))
            local delay=$((base_delay + jitter))

            echo "Attempt ${attempt} failed, retrying in ${delay}s..." >&2
            sleep "${delay}"

            # Exponential backoff
            ((base_delay*=2))
        fi

        ((attempt++))
    done

    return 1
}
```

---

## References

- [Advanced Bash-Scripting Guide](https://tldp.org/LDP/abs/html/)
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/)
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)