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
    -e, --entry COMMAND      Application entry point or full start command (default: index.js)
    -b, --build              Include build stage for compilation (installs all deps, runs npm run build, prunes dev deps)
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
# - Single token (no space): treat as a script file, prepend node interpreter.
# - Multi-token (has space): tokenize into a proper exec-form JSON array so that
#   every word becomes its own element. This avoids sh -c wrapping, which adds
#   an extra process and breaks PID-1 signal handling.
#   Examples:
#     "index.js"               -> CMD ["node", "index.js"]
#     "node server.js"         -> CMD ["node", "server.js"]
#     "npm start"              -> CMD ["npm", "start"]
#     "uvicorn main:app --host 0.0.0.0 --port 8000"
#                              -> CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
if [[ "$APP_ENTRY" =~ [[:space:]] ]]; then
    read -ra _entry_tokens <<< "$APP_ENTRY"
    _json_parts=()
    for _token in "${_entry_tokens[@]}"; do
        _json_parts+=("\"$(escape_json_string "$_token")\"")
    done
    CMD_INSTRUCTION="CMD [$(IFS=', '; echo "${_json_parts[*]}")]"
else
    CMD_INSTRUCTION="CMD [\"node\", \"$(escape_json_string "$APP_ENTRY")\"]"
fi
CMD_INSTRUCTION_SED="$(escape_sed_replacement "$CMD_INSTRUCTION")"

# Generate Dockerfile — two templates to avoid complex sed escaping around &&.
# The build template installs ALL deps (including dev) so that build tools like
# tsc, vite, webpack etc. are available, then prunes dev deps after the build so
# the production stage receives a clean node_modules.
if [ "$BUILD_STAGE" = "true" ]; then
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage — install all deps (including devDependencies) required by the
# build step, compile the application, then prune to production-only deps.
FROM node:NODE_VERSION-alpine AS builder
WORKDIR /app

# Copy dependency files for caching
COPY package*.json ./

# Install all dependencies (including devDependencies needed for build)
RUN npm ci && \
    npm cache clean --force

# Copy application code
COPY . .

# Build application and prune dev dependencies so the production stage
# receives only what is needed at runtime.
RUN npm run build && \
    npm prune --production

# Production stage
FROM node:NODE_VERSION-alpine AS production
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy pruned node_modules and built application from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:PORT_NUMBER/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})" || exit 1

# Start application
CMD_INSTRUCTION_PLACEHOLDER
EOF
else
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM node:NODE_VERSION-alpine AS builder
WORKDIR /app

# Copy dependency files for caching
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Production stage
FROM node:NODE_VERSION-alpine AS production
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

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
CMD_INSTRUCTION_PLACEHOLDER
EOF
fi

# Replace placeholders
sed -i.bak "s/NODE_VERSION/$NODE_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"
sed -i.bak "s|CMD_INSTRUCTION_PLACEHOLDER|$CMD_INSTRUCTION_SED|g" "$OUTPUT_FILE"

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Node.js Dockerfile: $OUTPUT_FILE"
echo "  Node version: $NODE_VERSION"
echo "  Port: $PORT"
echo "  Entry point: $APP_ENTRY"
echo "  Build stage: $BUILD_STAGE"
