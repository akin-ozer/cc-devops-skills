#!/usr/bin/env bash
#
# Regression tests for terraform-generator feature/version consistency checks.
#
# Covers:
#   1. Checker script shell syntax
#   2. Baseline repo files pass consistency checks
#   3. Intentional fixture regressions fail with expected diagnostics
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly CHECK_SCRIPT="$SKILL_DIR/scripts/check_feature_version_consistency.sh"
SKILL_DOC="$SKILL_DIR/references/extended-guide.md"
readonly SKILL_DOC

PASS=0
FAIL=0
OUTPUT=""
EXIT_CODE=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

run_capture() {
    EXIT_CODE=0
    OUTPUT=$("$@" 2>&1) || EXIT_CODE=$?
}

assert_exit() {
    local label="$1"
    local expected="$2"
    if [[ "$EXIT_CODE" -eq "$expected" ]]; then
        pass "$label (exit $EXIT_CODE)"
    else
        fail "$label - expected exit $expected, got $EXIT_CODE"
        echo "$OUTPUT" | sed 's/^/    /'
    fi
}

assert_output_contains() {
    local label="$1"
    local pattern="$2"
    if echo "$OUTPUT" | grep -qE -- "$pattern"; then
        pass "$label"
    else
        fail "$label - pattern not found: $pattern"
        echo "$OUTPUT" | sed 's/^/    /'
    fi
}

make_fixture() {
    local fixture_dir="$1"
    mkdir -p "$fixture_dir/references"
    mkdir -p "$fixture_dir/assets/minimal-project"
    cp "$SKILL_DOC" "$fixture_dir/SKILL.md"
    cp "$SKILL_DIR/references/terraform_best_practices.md" "$fixture_dir/references/terraform_best_practices.md"
    cp "$SKILL_DIR/assets/minimal-project/versions.tf" "$fixture_dir/assets/minimal-project/versions.tf"
}

run_checker_with_fixture() {
    local fixture_dir="$1"
    run_capture \
        env \
        SKILL_FILE="$fixture_dir/SKILL.md" \
        BEST_PRACTICES_FILE="$fixture_dir/references/terraform_best_practices.md" \
        VERSIONS_FILE="$fixture_dir/assets/minimal-project/versions.tf" \
        bash "$CHECK_SCRIPT"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Running terraform-generator feature/version regression tests..."
echo ""

echo "[1] Script syntax"
run_capture bash -n "$CHECK_SCRIPT"
assert_exit "checker script passes bash -n" 0

echo ""
echo "[2] Baseline should pass"
run_capture bash "$CHECK_SCRIPT"
assert_exit "baseline consistency check passes" 0
assert_output_contains "baseline success message appears" "All terraform-generator feature/version checks passed\\."

echo ""
echo "[3] Broken fixture: matrix drift"
FIXTURE_MATRIX="$TMP_DIR/fixture-matrix-drift"
make_fixture "$FIXTURE_MATRIX"
grep -Fv "| Write-only arguments | 1.11+ |" "$SKILL_DOC" > "$FIXTURE_MATRIX/SKILL.md"
run_checker_with_fixture "$FIXTURE_MATRIX"
assert_exit "missing write-only matrix line fails check" 1
assert_output_contains "matrix drift failure message appears" "FAIL: SKILL matrix keeps write-only at 1.11\\+"

echo ""
echo "[4] Broken fixture: best-practices write-only gate downgraded"
FIXTURE_REFERENCE="$TMP_DIR/fixture-reference-drift"
make_fixture "$FIXTURE_REFERENCE"
awk '{gsub(/>= 1.11, < 2.0/, ">= 1.10, < 2.0"); print}' \
    "$SKILL_DIR/references/terraform_best_practices.md" \
    > "$FIXTURE_REFERENCE/references/terraform_best_practices.md"
run_checker_with_fixture "$FIXTURE_REFERENCE"
assert_exit "write-only gate downgrade in reference fails check" 1
assert_output_contains "reference drift failure message appears" "FAIL: Best practices maps write-only to >= 1.11"

echo ""
echo "[5] Broken fixture: template write-only note removed"
FIXTURE_TEMPLATE="$TMP_DIR/fixture-template-drift"
make_fixture "$FIXTURE_TEMPLATE"
grep -Fv 'If using write-only arguments (`*_wo`), bump to `>= 1.11, < 2.0`.' \
    "$SKILL_DIR/assets/minimal-project/versions.tf" \
    > "$FIXTURE_TEMPLATE/assets/minimal-project/versions.tf"
run_checker_with_fixture "$FIXTURE_TEMPLATE"
assert_exit "template guidance removal fails check" 1
assert_output_contains "template drift failure message appears" "FAIL: Template documents write-only bump to >= 1.11"

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

echo "All terraform-generator regression tests passed."
