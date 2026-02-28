#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$SKILL_DIR/scripts"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

cat > "$TMP_DIR/main.tf" <<'TF'
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "random_id" "id" {
  byte_length = 8
}

data "http" "example" {
  url = "https://example.com"
}
TF

cat > "$TMP_DIR/bad.tf" <<'TF'
resource "aws_instance" "broken" {
  ami =
}
TF

# 1) Parser error case should exit non-zero and report parse_errors.
set +e
bash "$SCRIPTS_DIR/extract_tf_info_wrapper.sh" "$TMP_DIR/bad.tf" > "$TMP_DIR/bad.json" 2> "$TMP_DIR/bad.err"
rc=$?
set -e
if [[ $rc -ne 2 ]]; then
  echo "FAIL: expected extract_tf_info_wrapper.sh bad.tf exit 2, got $rc"
  exit 1
fi
python3 - "$TMP_DIR/bad.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
if payload.get('summary', {}).get('parse_error_count', 0) < 1:
    raise SystemExit('FAIL: expected parse_error_count >= 1')
PY

# 2) Implicit provider detection should include random/http in docs provider set.
bash "$SCRIPTS_DIR/extract_tf_info_wrapper.sh" "$TMP_DIR/main.tf" > "$TMP_DIR/info.json"
python3 - "$TMP_DIR/info.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1], encoding='utf-8'))
providers = set(payload.get('provider_analysis', {}).get('all_provider_names_for_docs', []))
required = {'aws', 'random', 'http'}
missing = required - providers
if missing:
    raise SystemExit(f'FAIL: missing providers in docs set: {sorted(missing)}')
PY

# 3) Wrapper argument handling.
if bash "$SCRIPTS_DIR/extract_tf_info_wrapper.sh" >/dev/null 2>&1; then
  echo "FAIL: wrapper should fail with missing path argument"
  exit 1
fi
if bash "$SCRIPTS_DIR/extract_tf_info_wrapper.sh" "$TMP_DIR/does-not-exist" >/dev/null 2>&1; then
  echo "FAIL: wrapper should fail for nonexistent path"
  exit 1
fi

# 4) Checkov wrapper should preserve scanner exit code.
mkdir -p "$TMP_DIR/bin"
cat > "$TMP_DIR/bin/checkov" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
exit "${CHECKOV_STUB_EXIT:-0}"
SH
chmod +x "$TMP_DIR/bin/checkov"

PATH="$TMP_DIR/bin:$PATH" bash "$SCRIPTS_DIR/run_checkov.sh" -q "$TMP_DIR/main.tf" >/dev/null

set +e
CHECKOV_STUB_EXIT=3 PATH="$TMP_DIR/bin:$PATH" bash "$SCRIPTS_DIR/run_checkov.sh" -q "$TMP_DIR/main.tf" >/dev/null 2>&1
rc=$?
set -e
if [[ $rc -ne 3 ]]; then
  echo "FAIL: expected run_checkov.sh to return scanner exit 3, got $rc"
  exit 1
fi

set +e
PATH="$TMP_DIR/bin:$PATH" bash "$SCRIPTS_DIR/run_checkov.sh" -f invalid "$TMP_DIR/main.tf" >/dev/null 2>&1
rc=$?
set -e
if [[ $rc -ne 1 ]]; then
  echo "FAIL: expected invalid format handling to exit 1, got $rc"
  exit 1
fi

echo "PASS: terraform-validator regression tests"
