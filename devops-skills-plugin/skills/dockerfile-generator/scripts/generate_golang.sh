#!/usr/bin/env bash
# Generate a production-ready Go Dockerfile with multi-stage build

set -euo pipefail

# Default values
GO_VERSION="${GO_VERSION:-1.21}"
PORT="${PORT:-8080}"
OUTPUT_FILE="${OUTPUT_FILE:-Dockerfile}"
BINARY_NAME="${BINARY_NAME:-app}"
USE_DISTROLESS="${USE_DISTROLESS:-true}"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate a production-ready Go Dockerfile with multi-stage build.

OPTIONS:
    -v, --version VERSION     Go version (default: 1.21)
    -p, --port PORT          Port to expose (default: 8080)
    -o, --output FILE        Output file (default: Dockerfile)
    -b, --binary NAME        Binary name (default: app)
    --alpine                 Use Alpine instead of distroless
    -h, --help               Show this help message

EXAMPLES:
    # Basic Go app with distroless
    $0

    # Go app with Alpine base
    $0 --alpine --port 8080

    # Custom binary name
    $0 --binary myapp --version 1.22

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            GO_VERSION="$2"
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
        -b|--binary)
            BINARY_NAME="$2"
            shift 2
            ;;
        --alpine)
            USE_DISTROLESS="false"
            shift
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

# Generate Dockerfile based on base image choice
if [ "$USE_DISTROLESS" = "true" ]; then
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM golang:GO_VERSION-alpine AS builder
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o /BINARY_NAME .

# Production stage (using distroless for minimal image)
FROM gcr.io/distroless/static-debian12 AS production
WORKDIR /

# Copy binary from builder
COPY --from=builder /BINARY_NAME /BINARY_NAME

# Expose port
EXPOSE PORT_NUMBER

# Switch to non-root user (distroless runs as nonroot by default)
USER nonroot:nonroot

# Start application
ENTRYPOINT ["/BINARY_NAME"]
EOF
else
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM golang:GO_VERSION-alpine AS builder
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o /BINARY_NAME .

# Production stage (using Alpine)
FROM alpine:3.21 AS production
WORKDIR /app

# Install ca-certificates for HTTPS
RUN apk --no-cache add ca-certificates

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

# Copy binary from builder
COPY --from=builder /BINARY_NAME /app/BINARY_NAME

# Switch to non-root user
USER appuser

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:PORT_NUMBER/health || exit 1

# Start application
ENTRYPOINT ["/app/BINARY_NAME"]
EOF
fi

# Replace placeholders
sed -i.bak "s/GO_VERSION/$GO_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"
sed -i.bak "s/BINARY_NAME/$BINARY_NAME/g" "$OUTPUT_FILE"

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Go Dockerfile: $OUTPUT_FILE"
echo "  Go version: $GO_VERSION"
echo "  Port: $PORT"
echo "  Binary name: $BINARY_NAME"
echo "  Base image: $([ "$USE_DISTROLESS" = "true" ] && echo "distroless" || echo "alpine")"
