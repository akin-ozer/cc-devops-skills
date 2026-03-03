#!/usr/bin/env bash
#
# Regression test suite for github-actions-generator
#
# Tests:
#   1. YAML syntax validity   — all templates and examples parse without errors
#   2. SHA pinning compliance — no unpinned @vN action refs in positive examples
#   3. EOF newlines           — all YAML files end with a newline
#   4. SHA consistency        — templates/examples use the canonical SHAs from
#                               references/common-actions.md
#   5. Required workflow keys — example workflows contain mandatory top-level keys
#   6. Template placeholder   — basic_workflow.yml has no raw YAML-breaking brackets
#
# Prerequisites: yamllint must be installed (pip install yamllint)
#
# Exit 0 when all assertions pass; non-zero on any failure.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0

# ─── helpers ────────────────────────────────────────────────────────────────

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_true() {
    local label="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_false() {
    local label="$1"
    shift
    if ! "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label"
    fi
}

assert_file_contains() {
    local label="$1"
    local file="$2"
    local pattern="$3"
    if grep -qE "$pattern" "$file"; then
        pass "$label"
    else
        fail "$label — pattern '$pattern' not found in $file"
    fi
}

assert_file_not_contains() {
    local label="$1"
    local file="$2"
    local pattern="$3"
    if ! grep -qE "$pattern" "$file"; then
        pass "$label"
    else
        fail "$label — unexpected pattern '$pattern' found in $file"
        grep -nE "$pattern" "$file" | sed 's/^/    /' || true
    fi
}

assert_file_ends_with_newline() {
    local label="$1"
    local file="$2"
    if [ -z "$(tail -c1 "$file")" ]; then
        pass "$label"
    else
        fail "$label — $file is missing a trailing newline"
    fi
}

# ─── discovery ──────────────────────────────────────────────────────────────

# Collect all YAML files under templates and examples
TEMPLATE_FILES=()
while IFS= read -r f; do
    TEMPLATE_FILES+=("$f")
done < <(find "$SKILL_DIR/assets/templates" -name "*.yml" -type f)

EXAMPLE_FILES=()
while IFS= read -r f; do
    EXAMPLE_FILES+=("$f")
done < <(find "$SKILL_DIR/examples" -name "*.yml" -type f)

ALL_YAML_FILES=("${TEMPLATE_FILES[@]}" "${EXAMPLE_FILES[@]}")

echo "Discovered ${#TEMPLATE_FILES[@]} template file(s) and ${#EXAMPLE_FILES[@]} example file(s)."
echo ""

# ─── canonical SHAs (sourced from references/common-actions.md) ─────────────

# These are the authoritative SHAs the generator must use.
# If common-actions.md is updated, update these constants to match.
readonly SHA_CHECKOUT="de0fac2e4500dabe0009e67214ff5f5447ce83dd"          # v6.0.2
readonly SHA_SETUP_NODE="6044e13b5dc448c55e2357c09f80417699197238"         # v6.2.0
readonly SHA_CACHE="cdf6c1fa76f9f475f3d7449005a359c84ca0f306"              # v5.0.3
readonly SHA_UPLOAD_ARTIFACT="5d5d22a31266ced268874388b861e4b58bb5c2f3"    # v4.3.1
readonly SHA_DOWNLOAD_ARTIFACT="c850b930e6ba138125429b7e5c93fc707a7f8427" # v4.1.4
readonly SHA_GITHUB_SCRIPT="60a0d83039c74a4aee543508d2ffcb1c3799cdea"     # v7.0.1

# ─── 1. YAML syntax validity ─────────────────────────────────────────────────

echo "[1] YAML syntax validity"

if ! command -v yamllint >/dev/null 2>&1; then
    fail "yamllint not installed — skipping YAML syntax checks"
else
    for f in "${ALL_YAML_FILES[@]}"; do
        rel="${f#"$SKILL_DIR/"}"
        errors=$(yamllint -d relaxed "$f" 2>&1 | grep "error" | grep -v "line-length" || true)
        if [ -z "$errors" ]; then
            pass "valid YAML: $rel"
        else
            fail "YAML error in: $rel"
            echo "$errors" | sed 's/^/    /'
        fi
    done
fi
echo ""

# ─── 2. SHA pinning compliance ───────────────────────────────────────────────

echo "[2] SHA pinning compliance (no bare @vN refs in positive examples)"

# Pattern matches unpinned action refs like @v1, @v2, ... @v99
# We check examples and templates — NOT reference .md files
# (reference .md files use @vN intentionally in anti-pattern sections)
UNPINNED_PATTERN='uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@v[0-9]'

# Actions whose SHAs are not yet documented in references/common-actions.md.
# These are flagged as warnings, not failures, until their SHAs are added.
# TODO: Add SHAs for these actions to references/common-actions.md and
#       update the examples to pin them.
NEEDS_SHA_ACTIONS=(
    "actions/dependency-review-action"    # listed in common-actions.md without SHA
    "actions/attest-sbom"                 # listed in common-actions.md without SHA
    "actions/attest-build-provenance"     # not in common-actions.md; needs docs + SHA
)

for f in "${TEMPLATE_FILES[@]}" "${EXAMPLE_FILES[@]}"; do
    rel="${f#"$SKILL_DIR/"}"
    all_unpinned=$(grep -nE "$UNPINNED_PATTERN" "$f" || true)

    if [ -z "$all_unpinned" ]; then
        pass "no unpinned refs: $rel"
        continue
    fi

    # Separate into known-undocumented (warning) vs actual violations (failure)
    unresolved_violations=""
    while IFS= read -r line; do
        is_known=false
        for known in "${NEEDS_SHA_ACTIONS[@]}"; do
            if echo "$line" | grep -qF "$known"; then
                is_known=true
                break
            fi
        done
        if ! $is_known; then
            unresolved_violations+="$line"$'\n'
        fi
    done <<< "$all_unpinned"

    known_count=$(echo "$all_unpinned" | wc -l)
    violation_count=0
    if [ -n "$unresolved_violations" ]; then
        violation_count=$(echo "$unresolved_violations" | grep -c . || true)
    fi

    if [ "$violation_count" -eq 0 ]; then
        pass "no unpinned refs (known-undocumented actions skipped): $rel"
        echo "    NOTE: $(echo "$all_unpinned" | grep -c . || true) action(s) need SHA pinning in common-actions.md"
        echo "$all_unpinned" | sed 's/^/    WARN: /'
    else
        fail "unpinned action ref(s) in: $rel"
        echo "$unresolved_violations" | sed 's/^/    /'
    fi
done
echo ""

# ─── 3. EOF newlines ─────────────────────────────────────────────────────────

echo "[3] EOF newlines (all YAML files must end with a newline)"

for f in "${ALL_YAML_FILES[@]}"; do
    rel="${f#"$SKILL_DIR/"}"
    assert_file_ends_with_newline "EOF newline: $rel" "$f"
done
echo ""

# ─── 4. SHA consistency ──────────────────────────────────────────────────────

echo "[4] SHA consistency (templates and examples match canonical SHAs)"

# Check that wherever a well-known action is used, it uses the canonical SHA.
# This catches version drift between common-actions.md and the rest of the files.

check_sha_consistency() {
    local action="$1"
    local expected_sha="$2"
    local file="$3"
    local rel="${file#"$SKILL_DIR/"}"

    # Extract all @<sha-or-tag> references for this action
    local wrong
    wrong=$(grep -nE "uses: ${action}@" "$file" 2>/dev/null \
        | grep -v "$expected_sha" \
        | grep -v "# .*BAD\|# .*UNSAFE\|# .*AVOID\|#.*-.*uses:" \
        || true)

    if [ -z "$wrong" ]; then
        pass "SHA consistent for ${action}: $rel"
    else
        fail "Wrong SHA for ${action} in: $rel"
        echo "$wrong" | sed 's/^/    /'
        echo "    Expected SHA: $expected_sha"
    fi
}

for f in "${TEMPLATE_FILES[@]}" "${EXAMPLE_FILES[@]}"; do
    if grep -qE "uses: actions/checkout@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/checkout" "$SHA_CHECKOUT" "$f"
    fi
    if grep -qE "uses: actions/setup-node@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/setup-node" "$SHA_SETUP_NODE" "$f"
    fi
    if grep -qE "uses: actions/cache@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/cache" "$SHA_CACHE" "$f"
    fi
    if grep -qE "uses: actions/upload-artifact@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/upload-artifact" "$SHA_UPLOAD_ARTIFACT" "$f"
    fi
    if grep -qE "uses: actions/download-artifact@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/download-artifact" "$SHA_DOWNLOAD_ARTIFACT" "$f"
    fi
    if grep -qE "uses: actions/github-script@" "$f" 2>/dev/null; then
        check_sha_consistency "actions/github-script" "$SHA_GITHUB_SCRIPT" "$f"
    fi
done
echo ""

# ─── 5. Required workflow keys ───────────────────────────────────────────────

echo "[5] Required workflow keys (name, on, permissions, jobs)"

WORKFLOW_EXAMPLES=()
while IFS= read -r f; do
    WORKFLOW_EXAMPLES+=("$f")
done < <(find "$SKILL_DIR/examples/workflows" "$SKILL_DIR/assets/templates/workflow" \
    -name "*.yml" -type f)

for f in "${WORKFLOW_EXAMPLES[@]}"; do
    rel="${f#"$SKILL_DIR/"}"
    assert_file_contains "has 'name:' key: $rel"        "$f" "^name:"
    assert_file_contains "has 'on:' trigger: $rel"      "$f" "^on:"
    assert_file_contains "has 'permissions:' key: $rel" "$f" "permissions:"
    assert_file_contains "has 'jobs:' key: $rel"        "$f" "^jobs:"
done
echo ""

# ─── 6. Template placeholder integrity ───────────────────────────────────────

echo "[6] Template placeholder integrity"

BASIC_TEMPLATE="$SKILL_DIR/assets/templates/workflow/basic_workflow.yml"

# Verify the step name with brackets is quoted (prevents YAML parse error)
assert_file_contains \
    "basic_workflow.yml: bracketed step name is quoted" \
    "$BASIC_TEMPLATE" \
    'name: "\[SETUP_STEP_NAME\]'

# Verify the file has no raw YAML syntax errors (already covered in test 1,
# but surfaced here explicitly for the template that had the known bug)
if command -v yamllint >/dev/null 2>&1; then
    errors=$(yamllint -d relaxed "$BASIC_TEMPLATE" 2>&1 | grep "error" | grep -v "line-length" || true)
    if [ -z "$errors" ]; then
        pass "basic_workflow.yml: no YAML syntax errors"
    else
        fail "basic_workflow.yml: YAML syntax errors found"
        echo "$errors" | sed 's/^/    /'
    fi
fi
echo ""

# ─── summary ─────────────────────────────────────────────────────────────────

echo "Results: $PASS passed, $FAIL failed"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
