#!/usr/bin/env bash
#
# Regression test suite for validate.sh
#
# Runs the validator against each example file and asserts the expected exit code.
# Exit 0 when all assertions pass; non-zero on the first failure.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
VALIDATOR="$SCRIPT_DIR/validate.sh"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"

# Counters
PASS=0
FAIL=0

# ─── helpers ────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Run the validator and return its exit code without aborting this script.
# Uses || to prevent set -e from treating a non-zero validator exit as fatal.
run_validator() {
    local exit_code=0
    bash "$VALIDATOR" "$1" >/dev/null 2>&1 || exit_code=$?
    echo "$exit_code"
}

# Assert that the validator exits with a specific code for the given file.
assert_exit_code() {
    local label="$1"
    local file="$2"
    local expected="$3"

    local actual
    actual=$(run_validator "$file")

    if [[ "$actual" -eq "$expected" ]]; then
        pass "$label (exit $actual)"
    else
        fail "$label — expected exit $expected, got $actual"
        # Re-run with output visible so the failure is diagnosable.
        echo "    --- validator output ---"
        bash "$VALIDATOR" "$file" 2>&1 | sed 's/^/    /' || true
        echo "    --- end output ---"
    fi
}

# Assert that a pattern IS found in the validator output for a given file.
assert_output_contains() {
    local label="$1"
    local file="$2"
    local pattern="$3"

    local output
    output=$(bash "$VALIDATOR" "$file" 2>&1 || true)

    if echo "$output" | grep -qE "$pattern"; then
        pass "$label"
    else
        fail "$label — pattern not found: $pattern"
        echo "    --- validator output ---"
        echo "$output" | sed 's/^/    /'
        echo "    --- end output ---"
    fi
}

# Assert that a pattern is NOT found in the validator output for a given file.
assert_output_not_contains() {
    local label="$1"
    local file="$2"
    local pattern="$3"

    local output
    output=$(bash "$VALIDATOR" "$file" 2>&1 || true)

    if echo "$output" | grep -qE "$pattern"; then
        fail "$label — unexpected pattern found: $pattern"
        echo "    --- validator output ---"
        echo "$output" | sed 's/^/    /'
        echo "    --- end output ---"
    else
        pass "$label"
    fi
}

# ─── test cases ─────────────────────────────────────────────────────────────

echo "Running bash-script-validator tests..."
echo ""

# --- good-bash.sh: well-written bash, must exit 0 ---
echo "[good-bash.sh]"
assert_exit_code \
    "exits cleanly (code 0)" \
    "$EXAMPLES_DIR/good-bash.sh" \
    0

assert_output_not_contains \
    "no false-positive errors" \
    "$EXAMPLES_DIR/good-bash.sh" \
    "✗"

# --- good-shell.sh: well-written POSIX sh, must exit 0 ---
echo ""
echo "[good-shell.sh]"
assert_exit_code \
    "exits cleanly (code 0)" \
    "$EXAMPLES_DIR/good-shell.sh" \
    0

assert_output_not_contains \
    "no false-positive [[ ]] error from comment on line 31" \
    "$EXAMPLES_DIR/good-shell.sh" \
    "\[\["

assert_output_not_contains \
    "no false-positive errors" \
    "$EXAMPLES_DIR/good-shell.sh" \
    "✗"

# --- bad-bash.sh: intentionally bad bash, must exit 2 ---
echo ""
echo "[bad-bash.sh]"
assert_exit_code \
    "exits with errors (code 2)" \
    "$EXAMPLES_DIR/bad-bash.sh" \
    2

assert_output_contains \
    "detects eval with variable" \
    "$EXAMPLES_DIR/bad-bash.sh" \
    "eval with variable"

assert_output_contains \
    "detects useless cat" \
    "$EXAMPLES_DIR/bad-bash.sh" \
    "Useless use of cat"

# --- bad-shell.sh: intentionally bad POSIX sh, must exit 2 ---
echo ""
echo "[bad-shell.sh]"
assert_exit_code \
    "exits with errors (code 2)" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    2

assert_output_contains \
    "detects [[ ]] in sh script (line 7, actual code)" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "Bash-specific \[\[ \]\]"

assert_output_contains \
    "detects bash arrays in sh script" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "Bash-specific arrays"

assert_output_contains \
    "detects function keyword in sh script" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "function.*keyword"

assert_output_contains \
    "detects source command in sh script" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "source.*command"

assert_output_contains \
    "detects eval with variable" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "eval with variable"

assert_output_contains \
    "detects useless cat" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "Useless use of cat"

# Only real code lines flagged — not comment lines for [[ check
assert_output_not_contains \
    "[[ check does not flag comment lines in bad-shell.sh" \
    "$EXAMPLES_DIR/bad-shell.sh" \
    "Line [0-9]*:# Bad: using bash-specific"

# --- edge cases ---
echo ""
echo "[edge cases]"

# Missing file → exit 1 from the validator's own error path
assert_exit_code \
    "missing file exits non-zero" \
    "/nonexistent/path/script.sh" \
    1

# ─── summary ────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
