#!/usr/bin/env bash
# Generate a production-ready Node.js Dockerfile with multi-stage build

set -euo pipefail

# Default values
NODE_VERSION="${NODE_VERSION:-20}"
PORT="${PORT:-3000}"
OUTPUT_FILE="${OUTPUT_FILE:-Dockerfile}"
APP_ENTRY="${APP_ENTRY:-index.js}"
BUILD_STAGE="${BUILD_STAGE:-false}"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate a production-ready Node.js Dockerfile with multi-stage build.

OPTIONS:
    -v, --version VERSION     Node.js version (default: 20)
    -p, --port PORT          Port to expose (default: 3000)
    -o, --output FILE        Output file (default: Dockerfile)
    -e, --entry FILE         Application entry point (default: index.js)
    -b, --build              Include build stage for compilation
    -h, --help               Show this help message

EXAMPLES:
    # Basic Node.js app
    $0

    # Next.js app with build stage
    $0 --version 20 --port 3000 --build --entry "npm start"

    # Custom port and entry point
    $0 --port 8080 --entry "server.js"

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            NODE_VERSION="$2"
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
        -b|--build)
            BUILD_STAGE="true"
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

# Generate Dockerfile
cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM node:NODE_VERSION-alpine AS builder
WORKDIR /app

# Copy dependency files for caching
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

BUILD_COMMANDS

# Production stage
FROM node:NODE_VERSION-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application from builder
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:PORT_NUMBER/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Start application
CMD ["node", "APP_ENTRY_POINT"]
EOF

# Replace placeholders
sed -i.bak "s/NODE_VERSION/$NODE_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"
sed -i.bak "s/APP_ENTRY_POINT/$APP_ENTRY/g" "$OUTPUT_FILE"

# Handle build stage
if [ "$BUILD_STAGE" = "true" ]; then
    sed -i.bak 's/BUILD_COMMANDS/# Build application\nRUN npm run build/' "$OUTPUT_FILE"
else
    sed -i.bak '/BUILD_COMMANDS/d' "$OUTPUT_FILE"
fi

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Node.js Dockerfile: $OUTPUT_FILE"
echo "  Node version: $NODE_VERSION"
echo "  Port: $PORT"
echo "  Entry point: $APP_ENTRY"
echo "  Build stage: $BUILD_STAGE"
