#!/usr/bin/env bash
#
# Regression test suite for bash-script-generator
#
# Tests:
#   1. generate_script_template.sh — argument handling and file generation
#   2. log-analyzer.sh             — functional behaviour
#
# Exit 0 when all assertions pass; non-zero on any failure.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
GENERATOR="$SCRIPT_DIR/generate_script_template.sh"
LOG_ANALYZER="$SCRIPT_DIR/../examples/log-analyzer.sh"

PASS=0
FAIL=0

# ─── helpers ────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Run a command silently and return its exit code without aborting this script.
run_exit_code() {
    local exit_code=0
    "$@" >/dev/null 2>&1 || exit_code=$?
    echo "$exit_code"
}

assert_exit_code() {
    local label="$1"
    local expected="$2"
    shift 2

    local actual
    actual=$(run_exit_code "$@")

    if [[ "$actual" -eq "$expected" ]]; then
        pass "$label (exit $actual)"
    else
        fail "$label — expected exit $expected, got $actual"
        echo "    --- command output ---"
        "$@" 2>&1 | sed 's/^/    /' || true
        echo "    --- end output ---"
    fi
}

# Assert that a pattern IS present in the combined stdout+stderr of a command.
assert_output_contains() {
    local label="$1"
    local pattern="$2"
    shift 2

    local output
    output=$("$@" 2>&1 || true)

    if echo "$output" | grep -qE "$pattern"; then
        pass "$label"
    else
        fail "$label — pattern not found: $pattern"
        echo "    --- command output ---"
        echo "$output" | sed 's/^/    /'
        echo "    --- end output ---"
    fi
}

# Assert that a pattern is NOT present in the combined stdout+stderr of a command.
assert_output_not_contains() {
    local label="$1"
    local pattern="$2"
    shift 2

    local output
    output=$("$@" 2>&1 || true)

    if echo "$output" | grep -qE "$pattern"; then
        fail "$label — unexpected pattern found: $pattern"
        echo "    --- command output ---"
        echo "$output" | sed 's/^/    /'
        echo "    --- end output ---"
    else
        pass "$label"
    fi
}

# ─── setup ──────────────────────────────────────────────────────────────────

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "${TEMP_DIR}"' EXIT

# Fixture log file used by log-analyzer tests
LOG_FILE="${TEMP_DIR}/app.log"
cat > "$LOG_FILE" << 'EOF'
2024-01-15 10:00:01 INFO: App started
2024-01-15 10:00:02 DEBUG: Loading config
2024-01-15 10:00:03 ERROR: Connection refused to database
2024-01-15 10:00:04 ERROR: Connection refused to database
2024-01-15 10:00:05 WARN: Retry attempt
2024-01-15 10:00:06 ERROR: Timeout on upstream request
2024-01-15 10:00:07 INFO: Request complete
2024-01-15 10:00:08 FATAL: Critical failure
EOF

echo "Running bash-script-generator tests..."

# ─── generate_script_template.sh: argument handling ─────────────────────────

echo ""
echo "[generate_script_template.sh — argument handling]"

assert_exit_code \
    "no args exits non-zero" \
    1 \
    bash "$GENERATOR"

assert_exit_code \
    "--help exits 0" \
    0 \
    bash "$GENERATOR" --help

assert_exit_code \
    "-h exits 0" \
    0 \
    bash "$GENERATOR" -h

assert_exit_code \
    "unknown template exits non-zero" \
    1 \
    bash "$GENERATOR" nonexistent-template

assert_exit_code \
    "too many args exits non-zero" \
    1 \
    bash "$GENERATOR" standard out.sh extra-arg

assert_output_contains \
    "no-args error mentions TEMPLATE_TYPE" \
    "TEMPLATE_TYPE" \
    bash "$GENERATOR"

assert_output_contains \
    "unknown template error lists available templates" \
    "Available templates" \
    bash "$GENERATOR" nonexistent-template

# ─── generate_script_template.sh: file generation ───────────────────────────

echo ""
echo "[generate_script_template.sh — file generation]"

OUTPUT="${TEMP_DIR}/generated.sh"
assert_exit_code \
    "standard template with explicit output exits 0" \
    0 \
    bash "$GENERATOR" standard "$OUTPUT"

if [[ -f "$OUTPUT" ]]; then
    pass "output file was created"
else
    fail "output file was not created"
fi

if [[ -x "$OUTPUT" ]]; then
    pass "output file is executable (chmod u+x applied)"
else
    fail "output file is not executable"
fi

assert_output_contains \
    "generated file has bash shebang" \
    "#!/usr/bin/env bash" \
    cat "$OUTPUT"

assert_output_contains \
    "generated file has strict mode" \
    "set -euo pipefail" \
    cat "$OUTPUT"

assert_output_contains \
    "generated file has numeric LOG_LEVEL" \
    "LOG_LEVEL=1" \
    cat "$OUTPUT"

# Syntax check: the generated script must be parseable by bash
if bash -n "$OUTPUT" 2>/dev/null; then
    pass "generated file passes bash -n syntax check"
else
    fail "generated file has syntax errors"
fi

# Overwrite: generating into an existing path must succeed silently
assert_exit_code \
    "overwriting existing output file exits 0" \
    0 \
    bash "$GENERATOR" standard "$OUTPUT"

# Nested directories must be created automatically
NESTED="${TEMP_DIR}/a/b/c/nested.sh"
assert_exit_code \
    "output into non-existent nested directory exits 0" \
    0 \
    bash "$GENERATOR" standard "$NESTED"

if [[ -f "$NESTED" ]]; then
    pass "nested output file was created"
else
    fail "nested output file was not created"
fi

# Default output path: when no OUTPUT_FILE is given the file lands in CWD
ORIG_DIR="$(pwd)"
cd "$TEMP_DIR"
assert_exit_code \
    "default output path (no output arg) exits 0" \
    0 \
    bash "$GENERATOR" standard
if [[ -f "${TEMP_DIR}/standard-script.sh" ]]; then
    pass "default output file ./standard-script.sh was created"
else
    fail "default output file ./standard-script.sh was not created"
fi
cd "$ORIG_DIR"

# ─── log-analyzer.sh: argument handling ─────────────────────────────────────

echo ""
echo "[log-analyzer.sh — argument handling]"

assert_exit_code \
    "no file arg exits non-zero" \
    1 \
    bash "$LOG_ANALYZER"

assert_exit_code \
    "-h exits 0" \
    0 \
    bash "$LOG_ANALYZER" -h

assert_exit_code \
    "nonexistent file exits non-zero" \
    1 \
    bash "$LOG_ANALYZER" /nonexistent/file.log

assert_exit_code \
    "invalid report type exits non-zero" \
    1 \
    bash "$LOG_ANALYZER" -t badtype "$LOG_FILE"

# ─── log-analyzer.sh: functional behaviour ──────────────────────────────────

echo ""
echo "[log-analyzer.sh — functional behaviour]"

assert_exit_code \
    "summary report exits 0" \
    0 \
    bash "$LOG_ANALYZER" "$LOG_FILE"

assert_output_contains \
    "summary report shows total lines" \
    "Total lines" \
    bash "$LOG_ANALYZER" "$LOG_FILE"

assert_output_contains \
    "summary shows ERROR count" \
    "ERROR" \
    bash "$LOG_ANALYZER" "$LOG_FILE"

assert_output_contains \
    "summary shows FATAL count" \
    "FATAL" \
    bash "$LOG_ANALYZER" "$LOG_FILE"

assert_exit_code \
    "errors report exits 0" \
    0 \
    bash "$LOG_ANALYZER" -t errors "$LOG_FILE"

assert_output_contains \
    "errors report shows total errors" \
    "Total errors" \
    bash "$LOG_ANALYZER" -t errors "$LOG_FILE"

# Multi-word error messages must not be truncated
assert_output_contains \
    "errors report preserves multi-word message (Connection refused to database)" \
    "Connection refused to database" \
    bash "$LOG_ANALYZER" -t errors "$LOG_FILE"

assert_output_contains \
    "errors report preserves multi-word message (Timeout on upstream request)" \
    "Timeout on upstream request" \
    bash "$LOG_ANALYZER" -t errors "$LOG_FILE"

# Repeated errors should show correct count (2 for "Connection refused to database")
assert_output_contains \
    "errors report shows count 2 for repeated error" \
    "Connection refused to database.*2" \
    bash "$LOG_ANALYZER" -t errors "$LOG_FILE"

# Output to file
REPORT="${TEMP_DIR}/report.txt"
assert_exit_code \
    "output-to-file exits 0" \
    0 \
    bash "$LOG_ANALYZER" -o "$REPORT" "$LOG_FILE"

if [[ -f "$REPORT" ]]; then
    pass "report file was created by -o flag"
else
    fail "report file was not created by -o flag"
fi

assert_output_contains \
    "-o flag prints confirmation message to stdout" \
    "Report saved to" \
    bash "$LOG_ANALYZER" -o "${TEMP_DIR}/report2.txt" "$LOG_FILE"

assert_output_not_contains \
    "report file content excludes confirmation message" \
    "Report saved to" \
    cat "$REPORT"

# ─── summary ────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
