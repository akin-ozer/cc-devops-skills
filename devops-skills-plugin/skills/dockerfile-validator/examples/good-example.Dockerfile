# syntax=docker/dockerfile:1

# Example of a well-structured, secure, and optimized Dockerfile
# This demonstrates Docker best practices for a Node.js application

# Build stage - includes all build dependencies
FROM node:21-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first for better layer caching
COPY package.json package-lock.json ./

# Install dependencies with cache mount for faster rebuilds
RUN --mount=type=cache,target=/root/.cache/npm \
    npm ci --only=production

# Copy application source
COPY . .

# Build the application (if needed)
RUN npm run build

# Runtime stage - minimal image with only necessary runtime dependencies
FROM node:21-alpine AS runtime

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Set working directory
WORKDIR /app

# Copy built application and dependencies from builder stage
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/dist ./dist
COPY --from=builder --chown=nodejs:nodejs /app/package.json ./

# Switch to non-root user
USER nodejs

# Expose application port
EXPOSE 3000

# Add healthcheck for container monitoring
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); })"

# Use exec form for better signal handling
ENTRYPOINT ["node"]
CMD ["dist/index.js"]