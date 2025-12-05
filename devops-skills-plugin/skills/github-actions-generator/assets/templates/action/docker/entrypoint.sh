#!/bin/bash
set -e

# Action entrypoint script
# Arguments are passed from action.yml

[INPUT_1]="$1"
[INPUT_2]="$2"

# Validate inputs
if [ -z "$[INPUT_1]" ]; then
  echo "::error::[INPUT_1] is required"
  exit 1
fi

echo "::group::Running [ACTION_NAME]"
echo "Input 1: $[INPUT_1]"
echo "Input 2: $[INPUT_2]"

# Main action logic
[MAIN_COMMAND]

# Set outputs
echo "[output-name]=[OUTPUT_VALUE]" >> "$GITHUB_OUTPUT"

echo "::endgroup::"
echo "✅ Action completed successfully"
