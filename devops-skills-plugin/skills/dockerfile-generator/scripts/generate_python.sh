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
    -e, --entry FILE         Application entry point (default: app.py)
    -h, --help               Show this help message

EXAMPLES:
    # Basic Python app
    $0

    # FastAPI app
    $0 --version 3.12 --port 8000

    # Django app
    $0 --port 8080 --entry "manage.py runserver 0.0.0.0:8080"

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

# Generate Dockerfile
cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM python:PYTHON_VERSION-slim AS builder
WORKDIR /app

# Install build dependencies
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

# Update PATH
ENV PATH=/home/appuser/.local/bin:$PATH

# Switch to non-root user
USER appuser

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:PORT_NUMBER/health').read()" || exit 1

# Start application
CMD ["python", "APP_ENTRY_POINT"]
EOF

# Replace placeholders
sed -i.bak "s/PYTHON_VERSION/$PYTHON_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"
sed -i.bak "s/APP_ENTRY_POINT/$APP_ENTRY/g" "$OUTPUT_FILE"

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Python Dockerfile: $OUTPUT_FILE"
echo "  Python version: $PYTHON_VERSION"
echo "  Port: $PORT"
echo "  Entry point: $APP_ENTRY"
