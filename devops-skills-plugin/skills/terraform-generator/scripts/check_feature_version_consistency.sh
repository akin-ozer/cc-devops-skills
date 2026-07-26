#!/usr/bin/env bash
#
# Validate Terraform feature/version guidance consistency for terraform-generator.
# Supports overriding target files with SKILL_FILE, BEST_PRACTICES_FILE, VERSIONS_FILE.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DEFAULT_SKILL_FILE="$SKILL_DIR/references/extended-guide.md"
readonly SKILL_FILE="${SKILL_FILE:-$DEFAULT_SKILL_FILE}"
readonly BEST_PRACTICES_FILE="${BEST_PRACTICES_FILE:-$SKILL_DIR/references/terraform_best_practices.md}"
readonly VERSIONS_FILE="${VERSIONS_FILE:-$SKILL_DIR/assets/minimal-project/versions.tf}"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_file_exists() {
    local file="$1"
    if [[ -f "$file" ]]; then
        pass "file exists: $file"
    else
        fail "missing required file: $file"
    fi
}

assert_file_contains() {
    local label="$1"
    local file="$2"
    local text="$3"
    if grep -Fq -- "$text" "$file"; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_file_not_contains() {
    local label="$1"
    local file="$2"
    local text="$3"
    if grep -Fq -- "$text" "$file"; then
        fail "$label"
    else
        pass "$label"
    fi
}

assert_write_only_section_contains() {
    local label="$1"
    local text="$2"
    local section
    section="$(
        awk '
            /^### Write-Only Arguments/ {in_section=1}
            /^### / && in_section && $0 !~ /^### Write-Only Arguments/ {exit}
            in_section {print}
        ' "$SKILL_FILE"
    )"

    if echo "$section" | grep -Fq -- "$text"; then
        pass "$label"
    else
        fail "$label"
    fi
}

echo "Running terraform-generator feature/version consistency checks..."
echo ""

assert_file_exists "$SKILL_FILE"
assert_file_exists "$BEST_PRACTICES_FILE"
assert_file_exists "$VERSIONS_FILE"

if [[ "$FAIL" -gt 0 ]]; then
    echo ""
    echo "Passed: $PASS"
    echo "Failed: $FAIL"
    exit 1
fi

echo "[1] Canonical version matrix and decision rules"
assert_file_contains \
    "SKILL matrix keeps ephemeral at 1.10+" \
    "$SKILL_FILE" \
    "| Ephemeral resources | 1.10+ |"
assert_file_contains \
    "SKILL matrix keeps write-only at 1.11+" \
    "$SKILL_FILE" \
    "| Write-only arguments | 1.11+ |"
assert_file_contains \
    "SKILL decision rule sets write-only to >= 1.11" \
    "$SKILL_FILE" \
    'If generated configuration includes write-only arguments (`*_wo`): use `required_version = ">= 1.11, < 2.0"`.'
assert_file_contains \
    "SKILL decision rule sets ephemeral-only to >= 1.10" \
    "$SKILL_FILE" \
    'Else if it uses ephemeral constructs (`ephemeral` blocks, ephemeral variables/outputs) without write-only arguments: use `required_version = ">= 1.10, < 2.0"`.'
assert_file_contains \
    "SKILL includes negative guard example for write-only under 1.10" \
    "$SKILL_FILE" \
    "# Negative: reject this pattern (write-only with Terraform 1.10)"

echo ""
echo "[2] Write-only example guardrails"
assert_write_only_section_contains \
    "Write-only section includes required_version >= 1.11" \
    'required_version = ">= 1.11, < 2.0"'
assert_write_only_section_contains \
    "Write-only section still demonstrates password_wo usage" \
    "password_wo"

echo ""
echo "[3] Cross-file consistency"
assert_file_contains \
    "Best practices maps write-only to >= 1.11" \
    "$BEST_PRACTICES_FILE" \
    'Use `required_version = ">= 1.11, < 2.0"` when write-only arguments (`*_wo`) are used.'
assert_file_contains \
    "Best practices maps ephemeral-only to >= 1.10" \
    "$BEST_PRACTICES_FILE" \
    'Use `required_version = ">= 1.10, < 2.0"` for ephemeral-only configurations.'
assert_file_not_contains \
    "Legacy mixed modern-feature statement removed from SKILL" \
    "$SKILL_FILE" \
    "modern features (ephemeral resources, write-only)"
assert_file_not_contains \
    "Legacy mixed modern-feature statement removed from best practices" \
    "$BEST_PRACTICES_FILE" \
    "modern features (ephemeral resources, write-only)"

echo ""
echo "[4] Template baseline policy"
assert_file_contains \
    "Template keeps baseline required_version >= 1.10" \
    "$VERSIONS_FILE" \
    'required_version = ">= 1.10, < 2.0"'
assert_file_contains \
    "Template documents write-only bump to >= 1.11" \
    "$VERSIONS_FILE" \
    'If using write-only arguments (`*_wo`), bump to `>= 1.11, < 2.0`.'

echo ""
echo "Passed: $PASS"
echo "Failed: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

echo "All terraform-generator feature/version checks passed."
