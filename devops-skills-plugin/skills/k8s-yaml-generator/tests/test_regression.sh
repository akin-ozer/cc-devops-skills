#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILL_GUIDE="$SKILL_DIR/references/extended-guide.md"
RBAC_DEFAULT="$SKILL_DIR/examples/rbac.yaml"
RBAC_OPTIONAL="$SKILL_DIR/examples/rbac-cluster-reader-optional.yaml"
INGRESS_EXAMPLE="$SKILL_DIR/examples/ingress.yaml"
RESOURCE_PATTERNS="$SKILL_DIR/references/resource_patterns.md"

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

assert_file_contains_literal() {
  local label="$1"
  local file="$2"
  local expected="$3"
  if grep -Fq -- "$expected" "$file"; then
    pass "$label"
  else
    fail "$label (missing literal: $expected)"
  fi
}

assert_file_contains_regex() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then
    pass "$label"
  else
    fail "$label (missing regex: $pattern)"
  fi
}

assert_file_not_contains_regex() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then
    fail "$label (unexpected regex match: $pattern)"
  else
    pass "$label"
  fi
}

assert_count_equals() {
  local label="$1"
  local file="$2"
  local pattern="$3"
  local expected_count="$4"
  local actual_count
  actual_count=$(grep -Ec -- "$pattern" "$file" || true)
  if [[ "$actual_count" -eq "$expected_count" ]]; then
    pass "$label"
  else
    fail "$label (expected $expected_count, got $actual_count)"
  fi
}

echo "Running k8s-yaml-generator regression tests..."
echo ""

echo "[P0] Dry-run fallback is guarded"
assert_file_not_contains_regex \
  "unsafe server||client fallback removed" \
  "$SKILL_GUIDE" \
  'kubectl apply --dry-run=server -f <file\.yaml> \|\| kubectl apply --dry-run=client -f <file\.yaml>'
assert_file_contains_literal \
  "server validation status reports passed" \
  "$SKILL_GUIDE" \
  'echo "server_validation=passed"'
assert_file_contains_literal \
  "server validation status reports skipped" \
  "$SKILL_GUIDE" \
  'echo "server_validation=skipped"'
assert_file_contains_literal \
  "server validation status reports failed" \
  "$SKILL_GUIDE" \
  'echo "server_validation=failed"'
assert_file_contains_literal \
  "client validation status reports passed" \
  "$SKILL_GUIDE" \
  'echo "client_validation=passed"'
assert_file_contains_literal \
  "client validation status reports failed" \
  "$SKILL_GUIDE" \
  'echo "client_validation=failed"'
assert_file_contains_regex \
  "fallback is gated on connectivity-like failures" \
  "$SKILL_GUIDE" \
  'grep -Eqi "connection refused\|no such host\|i/o timeout\|tls handshake timeout\|unable to connect to the server'

echo ""
echo "[P1] RBAC default is least-privilege"
assert_file_contains_regex \
  "default RBAC keeps namespaced Role" \
  "$RBAC_DEFAULT" \
  '^kind: Role$'
assert_file_contains_regex \
  "default RBAC keeps namespaced RoleBinding" \
  "$RBAC_DEFAULT" \
  '^kind: RoleBinding$'
assert_file_not_contains_regex \
  "default RBAC excludes ClusterRole" \
  "$RBAC_DEFAULT" \
  '^kind: ClusterRole$'
assert_file_not_contains_regex \
  "default RBAC excludes ClusterRoleBinding" \
  "$RBAC_DEFAULT" \
  '^kind: ClusterRoleBinding$'
assert_file_contains_literal \
  "optional cluster-reader example is explicitly warned" \
  "$RBAC_OPTIONAL" \
  "# WARNING: Optional high-privilege RBAC example."
assert_file_contains_regex \
  "optional file defines ClusterRole" \
  "$RBAC_OPTIONAL" \
  '^kind: ClusterRole$'
assert_file_contains_regex \
  "optional file defines ClusterRoleBinding" \
  "$RBAC_OPTIONAL" \
  '^kind: ClusterRoleBinding$'

echo ""
echo "[P1] Ingress rewrite behavior is explicit"
assert_count_equals \
  "ingress example has separate web and api resources" \
  "$INGRESS_EXAMPLE" \
  '^kind: Ingress$' \
  2
assert_file_not_contains_regex \
  "no global rewrite to root remains" \
  "$INGRESS_EXAMPLE" \
  'nginx\.ingress\.kubernetes\.io/rewrite-target:[[:space:]]*/$'
assert_file_contains_regex \
  "api ingress uses regex mode intentionally" \
  "$INGRESS_EXAMPLE" \
  'nginx\.ingress\.kubernetes\.io/use-regex:[[:space:]]*"true"'
assert_file_contains_regex \
  "api ingress rewrite uses capture group" \
  "$INGRESS_EXAMPLE" \
  'nginx\.ingress\.kubernetes\.io/rewrite-target:[[:space:]]*/\$2'
assert_file_contains_regex \
  "api ingress regex path is explicit" \
  "$INGRESS_EXAMPLE" \
  'path:[[:space:]]*/api\(/\|\$\)\(\.\*\)'

echo ""
echo "[P2] HPA version guidance is corrected"
assert_file_contains_literal \
  "resource patterns mention autoscaling/v2 availability since v1.23" \
  "$RESOURCE_PATTERNS" \
  "available since Kubernetes v1.23"
assert_file_not_contains_regex \
  "stale GA in 1.26 claim removed" \
  "$RESOURCE_PATTERNS" \
  'GA since K8s 1\.26'

echo ""
echo "Regression summary: PASS=$PASS FAIL=$FAIL"
if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi

echo "PASS: k8s-yaml-generator regression tests"
