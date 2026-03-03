#!/usr/bin/env bash
set -euo pipefail

UPSTREAM_REF="${UPSTREAM_REF:-v1}"
UPSTREAM_ACTION_URL="${UPSTREAM_ACTION_URL:-https://raw.githubusercontent.com/anthropics/claude-code-action/${UPSTREAM_REF}/action.yml}"
LOCAL_ACTION_PATH="${LOCAL_ACTION_PATH:-action.yml}"

if [[ ! -f "$LOCAL_ACTION_PATH" ]]; then
  echo "[ERROR] Local action file not found: $LOCAL_ACTION_PATH" >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

upstream_action="$tmp_dir/upstream-action.yml"
upstream_inputs="$tmp_dir/upstream-inputs.tsv"
local_inputs="$tmp_dir/local-inputs.tsv"
local_core_inputs="$tmp_dir/local-core-inputs.tsv"
upstream_outputs="$tmp_dir/upstream-outputs.txt"
local_outputs="$tmp_dir/local-outputs.txt"

curl -fsSL "$UPSTREAM_ACTION_URL" -o "$upstream_action"

extract_inputs() {
  local file_path="$1"
  awk '
    function trim(s) {
      gsub(/^[ \t]+|[ \t]+$/, "", s)
      return s
    }
    function unquote(s) {
      s = trim(s)
      if (s ~ /^".*"$/ || s ~ /^'"'"'.*'"'"'$/) {
        s = substr(s, 2, length(s) - 2)
      }
      return s
    }
    function emit_record() {
      if (key != "") {
        if (required == "") {
          required = "false"
        }
        if (!has_default) {
          default_value = "__NO_DEFAULT__"
        }
        print key "\t" required "\t" default_value
      }
    }
    BEGIN {
      in_inputs = 0
      key = ""
      required = ""
      default_value = ""
      has_default = 0
    }
    /^inputs:[[:space:]]*$/ {
      in_inputs = 1
      next
    }
    in_inputs && /^outputs:[[:space:]]*$/ {
      emit_record()
      key = ""
      required = ""
      default_value = ""
      has_default = 0
      in_inputs = 0
      next
    }
    !in_inputs {
      next
    }
    /^  [a-zA-Z0-9_-]+:[[:space:]]*$/ {
      emit_record()
      key = $1
      sub(/:$/, "", key)
      required = ""
      default_value = ""
      has_default = 0
      next
    }
    key != "" && /^    required:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*required:[[:space:]]*/, "", line)
      sub(/[[:space:]]+#.*/, "", line)
      required = unquote(line)
      next
    }
    key != "" && /^    default:[[:space:]]*/ {
      line = $0
      sub(/^[[:space:]]*default:[[:space:]]*/, "", line)
      sub(/[[:space:]]+#.*/, "", line)
      default_value = unquote(line)
      has_default = 1
      next
    }
    END {
      emit_record()
    }
  ' "$file_path" | LC_ALL=C sort -u
}

extract_outputs() {
  local file_path="$1"
  awk '
    BEGIN {
      in_outputs = 0
    }
    /^outputs:[[:space:]]*$/ {
      in_outputs = 1
      next
    }
    in_outputs && /^runs:[[:space:]]*$/ {
      in_outputs = 0
      exit
    }
    in_outputs && /^  [a-zA-Z0-9_-]+:[[:space:]]*$/ {
      key = $1
      sub(/:$/, "", key)
      print key
    }
  ' "$file_path" | LC_ALL=C sort -u
}

extract_inputs "$upstream_action" > "$upstream_inputs"
extract_inputs "$LOCAL_ACTION_PATH" > "$local_inputs"

awk -F'\t' '$1 != "inject_devops_skills" && $1 != "devops_marketplace_url" && $1 != "devops_plugin_name"' \
  "$local_inputs" > "$local_core_inputs"

extract_outputs "$upstream_action" > "$upstream_outputs"
extract_outputs "$LOCAL_ACTION_PATH" > "$local_outputs"

missing_inputs="$(join -t $'\t' -v 1 "$upstream_inputs" "$local_core_inputs" || true)"
input_mismatches="$(join -t $'\t' "$upstream_inputs" "$local_core_inputs" | awk -F'\t' '$2 != $4 || $3 != $5 {print $1 "\tupstream(required=" $2 ",default=" $3 ")\tlocal(required=" $4 ",default=" $5 ")"}' || true)"
unexpected_inputs="$(join -t $'\t' -v 2 "$upstream_inputs" "$local_core_inputs" || true)"

missing_outputs="$(comm -23 "$upstream_outputs" "$local_outputs" || true)"
unexpected_outputs="$(comm -13 "$upstream_outputs" "$local_outputs" || true)"

status=0

echo "[INFO] Upstream action source: $UPSTREAM_ACTION_URL"

echo "[INFO] Checking input compatibility"
if [[ -n "$missing_inputs" ]]; then
  status=1
  echo "[ERROR] Missing upstream inputs in local wrapper:"
  echo "$missing_inputs" | cut -f1
fi

if [[ -n "$input_mismatches" ]]; then
  status=1
  echo "[ERROR] Input required/default mismatches:"
  echo "$input_mismatches"
fi

if [[ -n "$unexpected_inputs" ]]; then
  status=1
  echo "[ERROR] Unexpected non-extension local inputs:"
  echo "$unexpected_inputs" | cut -f1
fi

echo "[INFO] Checking output compatibility"
if [[ -n "$missing_outputs" ]]; then
  status=1
  echo "[ERROR] Missing upstream outputs in local wrapper:"
  echo "$missing_outputs"
fi

if [[ -n "$unexpected_outputs" ]]; then
  status=1
  echo "[ERROR] Unexpected local outputs:"
  echo "$unexpected_outputs"
fi

if [[ "$status" -ne 0 ]]; then
  echo "[FAIL] Wrapper surface is not compatible with upstream $UPSTREAM_REF"
  exit 1
fi

echo "[OK] Wrapper surface matches upstream $UPSTREAM_REF (plus allowed extension inputs)."
