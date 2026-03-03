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

# ─── add_standard_targets.sh ──────────────────────────────────────────────────

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

# Case 11: idempotency — targets that already exist must not be duplicated.
mkdir -p "$TMP_DIR/idempotent"
bash "$GENERATE_SCRIPT" go myservice "$TMP_DIR/idempotent/Makefile" >/dev/null 2>&1
bash "$ADD_TARGETS_SCRIPT" "$TMP_DIR/idempotent/Makefile" clean test >/dev/null
clean_count="$(grep -c '^clean:' "$TMP_DIR/idempotent/Makefile")"
test_count="$(grep -c '^test:' "$TMP_DIR/idempotent/Makefile")"
[[ "$clean_count" -eq 1 ]] || fail "clean target duplicated ($clean_count occurrences after add on existing Makefile)"
[[ "$test_count" -eq 1 ]] || fail "test target duplicated ($test_count occurrences after add on existing Makefile)"

# Case 12: add_missing_variables must inject required variables without duplicating the header.
mkdir -p "$TMP_DIR/add_vars"
cat > "$TMP_DIR/add_vars/Makefile" <<'EOF'
# My project header
# Author: test

CC := gcc
EOF
bash "$ADD_TARGETS_SCRIPT" "$TMP_DIR/add_vars/Makefile" install >/dev/null
require_line "$TMP_DIR/add_vars/Makefile" '^PROJECT :='
require_line "$TMP_DIR/add_vars/Makefile" '^PREFIX \?= /usr/local$'
require_line "$TMP_DIR/add_vars/Makefile" '^VERSION :='
require_line "$TMP_DIR/add_vars/Makefile" '^install:'
header_count="$(grep -c '^# My project header$' "$TMP_DIR/add_vars/Makefile")"
[[ "$header_count" -eq 1 ]] || fail "Header comment duplicated ($header_count occurrences) by add_missing_variables"

# ─── generate_makefile_template.sh ───────────────────────────────────────────

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

# Case 6: C template should use gcc, enable dependency tracking, and include modern header.
bash "$GENERATE_SCRIPT" c myapp "$TMP_DIR/template_output/c.mk" >/dev/null 2>&1
require_line "$TMP_DIR/template_output/c.mk" '^CC \?= gcc$'
require_line "$TMP_DIR/template_output/c.mk" '^\.DELETE_ON_ERROR:$'
require_line "$TMP_DIR/template_output/c.mk" '^-include \$\(DEPENDS\)$'
require_line "$TMP_DIR/template_output/c.mk" '^\$\(OBJDIR\)/%.o: \$\(SRCDIR\)/%.c$'

# Case 7: C library template should declare both static and shared library targets.
bash "$GENERATE_SCRIPT" c-lib mylib "$TMP_DIR/template_output/c-lib.mk" >/dev/null 2>&1
require_line "$TMP_DIR/template_output/c-lib.mk" '^AR \?= ar$'
require_line "$TMP_DIR/template_output/c-lib.mk" '^STATIC_LIB :='
require_line "$TMP_DIR/template_output/c-lib.mk" '^SHARED_LIB :='
require_line "$TMP_DIR/template_output/c-lib.mk" '^\.PHONY: all static shared clean install help$'

# Case 8: C++ template must not corrupt project names that contain "gcc".
bash "$GENERATE_SCRIPT" cpp gcc-wrapper "$TMP_DIR/template_output/cpp.mk" >/dev/null 2>&1
require_line "$TMP_DIR/template_output/cpp.mk" '^PROJECT := gcc-wrapper$'
require_line "$TMP_DIR/template_output/cpp.mk" '^CXX \?= g\+\+$'
require_line "$TMP_DIR/template_output/cpp.mk" '\$\(SRCDIR\)/%.cpp'

# Case 9: Python template should use python3 and include a develop (editable-install) target.
bash "$GENERATE_SCRIPT" python mypkg "$TMP_DIR/template_output/python.mk" >/dev/null 2>&1
require_line "$TMP_DIR/template_output/python.mk" '^PYTHON \?= python3$'
require_line "$TMP_DIR/template_output/python.mk" '^develop:'
require_line "$TMP_DIR/template_output/python.mk" '\$\(PYTHON\) -m build'

# Case 10: Java template should include JAR creation, correct toolchain variables, and distclean.
bash "$GENERATE_SCRIPT" java myapp "$TMP_DIR/template_output/java.mk" >/dev/null 2>&1
require_line "$TMP_DIR/template_output/java.mk" '^JAVAC \?= javac$'
require_line "$TMP_DIR/template_output/java.mk" '^MAIN_CLASS := Main$'
require_line "$TMP_DIR/template_output/java.mk" '^jar:'
require_line "$TMP_DIR/template_output/java.mk" '^distclean: clean$'

echo "PASS: makefile-generator helper script regression tests"
