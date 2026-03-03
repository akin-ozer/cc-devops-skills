#!/usr/bin/env bash
#
# Regression test suite for validate_makefile.sh
#
# Runs the validator against fixture files and asserts expected exit codes and
# output patterns.  Each fixture file is validated once; all assertions on it
# share that single run so mbake is only installed once per fixture.
#
# Exit 0 when all assertions pass; exit 1 on the first failure.
#
# Usage:
#   bash scripts/test_validate.sh          # from makefile-validator/ directory
#   bash devops-skills-plugin/skills/makefile-validator/scripts/test_validate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
VALIDATOR="$SCRIPT_DIR/validate_makefile.sh"
EXAMPLES_DIR="$SCRIPT_DIR/../examples"

PASS=0
FAIL=0
TMPFILES=()

# ─── cleanup ────────────────────────────────────────────────────────────────

cleanup() {
    local f
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup EXIT INT TERM

# ─── helpers ────────────────────────────────────────────────────────────────

pass() { printf "  PASS  %s\n" "$1"; PASS=$((PASS + 1)); }
fail() { printf "  FAIL  %s\n" "$1"; FAIL=$((FAIL + 1)); }

# Run the validator once; populate OUTPUT and EXIT_CODE globals.
# The || true prevents set -e from aborting on a non-zero validator exit.
_run() {
    EXIT_CODE=0
    OUTPUT=$(NO_COLOR=1 bash "$VALIDATOR" "$1" 2>&1) || EXIT_CODE=$?
}

# Assert the exit code stored in EXIT_CODE equals $1.
assert_exit() {
    local label="$1" expected="$2"
    if [[ "$EXIT_CODE" -eq "$expected" ]]; then
        pass "$label (exit $EXIT_CODE)"
    else
        fail "$label — expected exit $expected, got $EXIT_CODE"
        printf '%s\n' "$OUTPUT" | sed 's/^/    /'
    fi
}

# Assert that OUTPUT matches an ERE pattern.
assert_contains() {
    local label="$1" pattern="$2"
    if printf '%s\n' "$OUTPUT" | grep -qE "$pattern"; then
        pass "$label"
    else
        fail "$label — pattern not found: $pattern"
        printf '%s\n' "$OUTPUT" | sed 's/^/    /'
    fi
}

# Assert that OUTPUT does NOT match an ERE pattern.
assert_not_contains() {
    local label="$1" pattern="$2"
    if printf '%s\n' "$OUTPUT" | grep -qE "$pattern"; then
        fail "$label — unexpected pattern found: $pattern"
        printf '%s\n' "$OUTPUT" | grep -E "$pattern" | sed 's/^/    /'
    else
        pass "$label"
    fi
}

# Create a named temp fixture (.mk extension) and register it for cleanup.
# macOS mktemp requires Xs to be at the very end of the template, so we create
# a plain temp file and rename it with a .mk suffix.
mktemp_mk() {
    local base f
    base=$(mktemp "${TMPDIR:-/tmp}/test-mk-XXXXXX")
    f="${base}.mk"
    mv "$base" "$f"
    TMPFILES+=("$f")
    echo "$f"
}

# ─── Test Groups ────────────────────────────────────────────────────────────

echo ""
echo "Running validate_makefile.sh regression tests..."

# ── good-makefile.mk ────────────────────────────────────────────────────────
echo ""
echo "── good-makefile.mk ──────────────────────────────────────────────────"
_run "$EXAMPLES_DIR/good-makefile.mk"
assert_exit         "exits cleanly"                          0
assert_not_contains "no credential false positive"           "hardcoded credentials"
assert_not_contains "no tab false positive"                  "spaces instead of tabs"
assert_not_contains "no validation-failed summary"           "Validation FAILED"
assert_contains     "passes summary printed"                 "Validation PASSED"

# ── bad-makefile.mk ─────────────────────────────────────────────────────────
echo ""
echo "── bad-makefile.mk ───────────────────────────────────────────────────"
_run "$EXAMPLES_DIR/bad-makefile.mk"
assert_exit         "exits with error code"                  2
assert_contains     "catches spaces-as-tabs"                 "spaces instead of tabs"
assert_contains     "catches hardcoded credentials"          "hardcoded credentials"
assert_contains     "catches missing .DELETE_ON_ERROR"       "Missing .DELETE_ON_ERROR"
assert_contains     "catches missing .PHONY"                 "No .PHONY declarations"
assert_contains     "catches unsafe variable expansion"      "without defaults"
assert_contains     "catches recursive = with shell"         "Shell commands with recursive expansion"
assert_contains     "failed summary printed"                 "Validation FAILED"

# ── Edge: commented-out credentials must NOT be flagged ─────────────────────
echo ""
echo "── edge: commented credentials ───────────────────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PHONY: deploy

# Documentation example (not a real secret):
# API_KEY = sk-example-1234567890abcdef
# DB_PASSWORD = super_secret_password
  # github_token = ghp_example_token

deploy:
	@echo "Deploying..."
MKEOF
_run "$F"
assert_not_contains "commented creds not flagged"            "hardcoded credentials"

# ── Edge: actual credentials after comment lines must still be caught ────────
echo ""
echo "── edge: real credentials are still caught ───────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PHONY: deploy

# This is a comment about the key below
API_KEY = sk-1234567890abcdef

deploy:
	@echo "Deploying..."
MKEOF
_run "$F"
assert_contains     "real creds after comments still caught" "hardcoded credentials"

# ── Edge: lowercase variable in dangerous command ────────────────────────────
echo ""
echo "── edge: lowercase variable in rm -rf ────────────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PHONY: clean

clean:
	rm -rf $(build_dir)
MKEOF
_run "$F"
assert_contains     "lowercase unsafe var detected"          "without defaults"

# ── Edge: bare make call at end of line (no args) ────────────────────────────
echo ""
echo "── edge: bare make call (no args at end of line) ─────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PHONY: recurse

recurse:
	make
MKEOF
_run "$F"
assert_contains     "bare make call detected"                "Direct.*call"

# ── Edge: make with args is also caught ──────────────────────────────────────
echo ""
echo "── edge: make with args ──────────────────────────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PHONY: recurse

recurse:
	make build
MKEOF
_run "$F"
assert_contains     "make-with-args detected"                "Direct.*call"

# ── Edge: $(MAKE) must NOT be flagged as a bare make call ───────────────────
echo ""
echo "── edge: \$(MAKE) is not flagged ─────────────────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: recurse

## Default target
recurse:
	$(MAKE) build
MKEOF
_run "$F"
assert_not_contains "MAKE macro not flagged"                 "Direct.*call"

# ── Edge: syntax_check single make invocation (output present on error) ──────
echo ""
echo "── edge: syntax error output is shown ────────────────────────────────"
F=$(mktemp_mk)
# Write a Makefile with a deliberate syntax error (spaces instead of tabs)
printf 'build:\n    echo broken\n' > "$F"
_run "$F"
assert_contains     "syntax error output shown"              "missing separator|Syntax errors detected"

# ── Edge: graceful degradation when python3 is absent ───────────────────────
# Shadow python3 with a stub that exits 127 so the validator cannot set up mbake.
# The script should warn, skip mbake stages, still run custom/syntax checks,
# and exit with warnings (1) rather than a hard error.
echo ""
echo "── edge: graceful degradation (no python3) ────────────────────────────"
FAKEBINDIR=$(mktemp -d "${TMPDIR:-/tmp}/test-fakebin-XXXXXX")
TMPFILES+=("$FAKEBINDIR")
printf '#!/usr/bin/env bash\necho "python3: not found" >&2; exit 127\n' > "$FAKEBINDIR/python3"
chmod +x "$FAKEBINDIR/python3"

F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: build

## Default target
build:
	@echo "ok"
MKEOF

PATH="$FAKEBINDIR:$PATH" _run "$F"
assert_not_contains  "no hard exit on missing python3"       "ERROR.*python3"
assert_contains      "warns about missing python3"           "python3 not found|mbake.*skipped"
assert_contains      "mbake stages shown as skipped"         "Skipped.*mbake"
assert_not_contains  "custom checks still ran"               "Validation FAILED"

# ── Edge: .PRECIOUS (non-list special target) not flagged by format check ────
# When mbake reports "Unknown special target '.PRECIOUS'", it should be treated
# as a known mbake false-positive (not a real error or warning).
echo ""
echo "── edge: .PRECIOUS not flagged as mbake error ─────────────────────────"
F=$(mktemp_mk)
cat > "$F" << 'MKEOF'
SHELL := bash
.DELETE_ON_ERROR:
.PRECIOUS: %.tar.gz
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
.PHONY: build

## Default target
build:
	@echo "ok"
MKEOF
_run "$F"
# .PRECIOUS is valid GNU Make but mbake may not know it; should be info, not warning/error
assert_not_contains  ".PRECIOUS not counted as error"        "Errors:[[:space:]]+[1-9]"

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════════════"
printf "  Results: %d passed, %d failed\n" "$PASS" "$FAIL"
echo "══════════════════════════════════════════════════════════════════════"
echo ""

[[ "$FAIL" -eq 0 ]]
