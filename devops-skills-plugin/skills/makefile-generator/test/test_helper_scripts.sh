#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADD_TARGETS_SCRIPT="$SKILL_DIR/scripts/add_standard_targets.sh"
GENERATE_SCRIPT="$SKILL_DIR/scripts/generate_makefile_template.sh"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

require_line() {
    local file="$1"
    local pattern="$2"
    grep -qE "$pattern" "$file" || fail "Expected pattern '$pattern' in $file"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Case 1: dry-run mode should not modify the Makefile.
mkdir -p "$TMP_DIR/dry_run"
cat > "$TMP_DIR/dry_run/Makefile" <<'EOF'
TARGET := demo

all:
	@echo "demo"
EOF

before_sum="$(shasum "$TMP_DIR/dry_run/Makefile" | awk '{print $1}')"
dry_output="$(cd "$TMP_DIR/dry_run" && bash "$ADD_TARGETS_SCRIPT" -n Makefile clean test)"
after_sum="$(shasum "$TMP_DIR/dry_run/Makefile" | awk '{print $1}')"
[[ "$dry_output" == *"Would add"* ]] || fail "Dry run output did not report planned additions"
[[ "$before_sum" == "$after_sum" ]] || fail "Dry run modified Makefile contents"

# Case 2: explicit-target mode should use ./Makefile when no file path is passed.
mkdir -p "$TMP_DIR/explicit_targets"
cat > "$TMP_DIR/explicit_targets/Makefile" <<'EOF'
TARGET := demo

all:
	@echo "demo"
EOF

(cd "$TMP_DIR/explicit_targets" && bash "$ADD_TARGETS_SCRIPT" clean test >/dev/null)
require_line "$TMP_DIR/explicit_targets/Makefile" '^clean:'
require_line "$TMP_DIR/explicit_targets/Makefile" '^test:'

# Case 3: positional parsing with explicit Makefile path should keep the first target.
mkdir -p "$TMP_DIR/explicit_path"
cat > "$TMP_DIR/explicit_path/custom.mk" <<'EOF'
TARGET := demo

all:
	@echo "demo"
EOF

bash "$ADD_TARGETS_SCRIPT" "$TMP_DIR/explicit_path/custom.mk" clean test >/dev/null
require_line "$TMP_DIR/explicit_path/custom.mk" '^clean:'
require_line "$TMP_DIR/explicit_path/custom.mk" '^test:'

# Case 4: output-file argument mapping (TYPE NAME OUTPUT) should be deterministic.
mkdir -p "$TMP_DIR/template_output"
(cd "$TMP_DIR/template_output" && bash "$GENERATE_SCRIPT" generic myproject out.mk >/dev/null)
[[ -f "$TMP_DIR/template_output/out.mk" ]] || fail "Output file argument was not honored"
require_line "$TMP_DIR/template_output/out.mk" '^PROJECT := myproject$'

# Case 5: generated Go template should include hardened defaults.
(cd "$TMP_DIR/template_output" && bash "$GENERATE_SCRIPT" go service go.mk >/dev/null)
require_line "$TMP_DIR/template_output/go.mk" '^\.PHONY: all build install test clean fmt lint help$'
require_line "$TMP_DIR/template_output/go.mk" '^GO_MAIN \?= \./cmd/\$\(PROJECT\)$'
require_line "$TMP_DIR/template_output/go.mk" '^GO_SUM := \$\(wildcard go\.sum\)$'
require_line "$TMP_DIR/template_output/go.mk" '^\$\(TARGET\): \$\(SOURCES\) go\.mod \$\(GO_SUM\)$'

echo "PASS: makefile-generator helper script regression tests"
