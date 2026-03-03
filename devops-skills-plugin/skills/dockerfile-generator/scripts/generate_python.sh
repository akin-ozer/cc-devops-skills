#!/usr/bin/env bash
# Generate a production-ready Python Dockerfile with multi-stage build

set -euo pipefail

# Default values
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"
PORT="${PORT:-8000}"
OUTPUT_FILE="${OUTPUT_FILE:-Dockerfile}"
APP_ENTRY="${APP_ENTRY:-app.py}"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate a production-ready Python Dockerfile with multi-stage build.

OPTIONS:
    -v, --version VERSION     Python version (default: 3.12)
    -p, --port PORT          Port to expose (default: 8000)
    -o, --output FILE        Output file (default: Dockerfile)
    -e, --entry COMMAND      Application entry point or full start command (default: app.py)
    -h, --help               Show this help message

EXAMPLES:
    # Basic Python app
    $0

    # FastAPI app
    $0 --version 3.12 --port 8000

    # Django app
    $0 --port 8080 --entry "python manage.py runserver 0.0.0.0:8080"

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -e|--entry)
            APP_ENTRY="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Escape values that are inserted into JSON-form CMD arrays.
escape_json_string() {
    local input="$1"
    input="${input//\\/\\\\}"
    input="${input//\"/\\\"}"
    printf '%s' "$input"
}

# Escape values that are inserted into sed replacement strings.
escape_sed_replacement() {
    local input="$1"
    input="${input//\\/\\\\}"
    input="${input//&/\\&}"
    input="${input//|/\\|}"
    printf '%s' "$input"
}

# Build CMD instruction.
# - Single token (no space): treat as a Python script file, prepend interpreter.
# - Multi-token (has space): tokenize into a proper exec-form JSON array so that
#   every word becomes its own element. This avoids sh -c wrapping, which adds
#   an extra process and breaks PID-1 signal handling.
#   Examples:
#     "app.py"                                -> CMD ["python", "app.py"]
#     "python app.py"                         -> CMD ["python", "app.py"]
#     "uvicorn main:app --host 0.0.0.0 --port 8000"
#                                             -> CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
if [[ "$APP_ENTRY" =~ [[:space:]] ]]; then
    read -ra _entry_tokens <<< "$APP_ENTRY"
    _json_parts=()
    for _token in "${_entry_tokens[@]}"; do
        _json_parts+=("\"$(escape_json_string "$_token")\"")
    done
    CMD_INSTRUCTION="CMD [$(IFS=', '; echo "${_json_parts[*]}")]"
else
    CMD_INSTRUCTION="CMD [\"python\", \"$(escape_json_string "$APP_ENTRY")\"]"
fi
CMD_INSTRUCTION_SED="$(escape_sed_replacement "$CMD_INSTRUCTION")"

# Generate Dockerfile
cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM python:PYTHON_VERSION-slim AS builder
WORKDIR /app

# Install build dependencies
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency files
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir --user -r requirements.txt

# Production stage
FROM python:PYTHON_VERSION-slim AS production
WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy dependencies from builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY --chown=appuser:appuser . .

# Update PATH and set Python production env vars
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Switch to non-root user
USER appuser

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:PORT_NUMBER/health').read()" || exit 1

# Start application
CMD_INSTRUCTION_PLACEHOLDER
EOF

# Replace placeholders
sed -i.bak "s/PYTHON_VERSION/$PYTHON_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"
sed -i.bak "s|CMD_INSTRUCTION_PLACEHOLDER|$CMD_INSTRUCTION_SED|g" "$OUTPUT_FILE"

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Python Dockerfile: $OUTPUT_FILE"
echo "  Python version: $PYTHON_VERSION"
echo "  Port: $PORT"
echo "  Entry point: $APP_ENTRY"
