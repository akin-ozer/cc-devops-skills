#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$SKILL_DIR/scripts/validate_terragrunt.sh"

cleanup() {
  if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
    python3 - "$TMP_DIR" <<'PY'
import shutil
import sys
from pathlib import Path

target = Path(sys.argv[1])
if target.exists():
    shutil.rmtree(target)
PY
  fi
}
trap cleanup EXIT

create_common_stubs() {
  local bin_dir="$1"

  cat > "$bin_dir/terraform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "version" && "${2:-}" == "-json" ]]; then
  echo '{"terraform_version":"1.6.0"}'
  exit 0
fi
echo "Terraform v1.6.0"
EOF
  chmod +x "$bin_dir/terraform"
}

setup_multi_failure_case() {
  local root_dir="$1"
  local bin_dir="$root_dir/bin"
  mkdir -p "$bin_dir" "$root_dir/infra/dev/vpc"
  cat > "$root_dir/infra/dev/vpc/terragrunt.hcl" <<'EOF'
locals {}
EOF

  cat > "$bin_dir/terragrunt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--strict-mode" ]]; then
  shift
fi

case "${1:-}" in
  --version)
    echo "terragrunt version v0.99.4"
    exit 0
    ;;
  hcl)
    exit 0
    ;;
  dag)
    exit 0
    ;;
  run)
    if [[ "${2:-}" == "--all" && "${3:-}" == "init" ]]; then
      exit 0
    fi
    if [[ "${2:-}" == "--all" && "${3:-}" == "validate" ]]; then
      exit 1
    fi
    if [[ "${2:-}" == "--all" && "${3:-}" == "plan" ]]; then
      exit 0
    fi
    ;;
esac

exit 0
EOF
  chmod +x "$bin_dir/terragrunt"

  create_common_stubs "$bin_dir"
}

setup_security_failure_case() {
  local root_dir="$1"
  local bin_dir="$root_dir/bin"
  mkdir -p "$bin_dir" "$root_dir/single"
  cat > "$root_dir/single/terragrunt.hcl" <<'EOF'
locals {}
EOF

  cat > "$bin_dir/terragrunt" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "--strict-mode" ]]; then
  shift
fi

case "${1:-}" in
  --version)
    echo "terragrunt version v0.99.4"
    exit 0
    ;;
  hcl)
    exit 0
    ;;
  init)
    exit 0
    ;;
  validate)
    exit 0
    ;;
  dag)
    exit 0
    ;;
  plan)
    exit 0
    ;;
esac

exit 0
EOF
  chmod +x "$bin_dir/terragrunt"

  cat > "$bin_dir/trivy" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# Simulate HIGH/CRITICAL findings.
exit 1
EOF
  chmod +x "$bin_dir/trivy"

  create_common_stubs "$bin_dir"
}

# Test 1: multi-unit terraform validation failure must return non-zero.
TMP_DIR="$(mktemp -d)"
setup_multi_failure_case "$TMP_DIR"
if PATH="$TMP_DIR/bin:$PATH" SKIP_PLAN=true SKIP_SECURITY=true SKIP_LINT=true SKIP_INPUT_VALIDATION=true bash "$VALIDATOR" "$TMP_DIR/infra" >/dev/null 2>&1; then
  echo "FAIL: expected non-zero exit for multi-unit validate failure"
  exit 1
fi
cleanup

# Test 2: security findings must fail by default.
TMP_DIR="$(mktemp -d)"
setup_security_failure_case "$TMP_DIR"
if PATH="$TMP_DIR/bin:$PATH" SKIP_PLAN=true SKIP_LINT=true SKIP_INPUT_VALIDATION=true SECURITY_SCANNER=trivy bash "$VALIDATOR" "$TMP_DIR/single" >/dev/null 2>&1; then
  echo "FAIL: expected non-zero exit on security findings"
  exit 1
fi
cleanup

# Test 3: security findings may be soft-failed when explicitly requested.
TMP_DIR="$(mktemp -d)"
setup_security_failure_case "$TMP_DIR"
PATH="$TMP_DIR/bin:$PATH" SKIP_PLAN=true SKIP_LINT=true SKIP_INPUT_VALIDATION=true SECURITY_SCANNER=trivy SOFT_FAIL_SECURITY=true bash "$VALIDATOR" "$TMP_DIR/single" >/dev/null
cleanup

echo "PASS: validate_terragrunt.sh regression tests"
