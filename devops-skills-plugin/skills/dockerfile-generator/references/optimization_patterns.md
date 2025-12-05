# Dockerfile Optimization Patterns

## Overview

This guide provides comprehensive optimization techniques for reducing Docker image size, improving build times, and enhancing runtime performance.

## Image Size Optimization

### Use Multi-Stage Builds

**Impact:** 50-85% size reduction

```dockerfile
# Before: Single stage (500MB)
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
CMD ["node", "dist/server.js"]

# After: Multi-stage (150MB)
FROM node:20 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/server.js"]
```

### Choose Minimal Base Images

**Size Comparison:**
```
ubuntu:22.04          → 77MB
node:20               → 996MB
node:20-slim          → 239MB
node:20-alpine        → 132MB
alpine:3.21           → 7.8MB
distroless/static     → 2MB
scratch               → 0MB
```

**Selection Guide:**
- **Full OS (ubuntu, debian):** When you need many system tools
- **Slim variants:** Good balance of size and compatibility
- **Alpine:** Minimal size, may have glibc compatibility issues
- **Distroless:** Highest security, minimal attack surface
- **Scratch:** For static binaries only (Go, Rust)

### Remove Unnecessary Files

```dockerfile
# Clean up in same RUN layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Remove build artifacts
RUN npm run build && \
    rm -rf src/ tests/ docs/

# Use .dockerignore
# (prevents files from being sent to build context)
```

## Build Time Optimization

### Layer Caching Strategy

**Order instructions from least to most frequently changing:**

```dockerfile
# Bad - Invalidates cache on any code change
COPY . /app
RUN npm install

# Good - Cache dependencies separately
COPY package*.json /app/
RUN npm install
COPY . /app
```

**Optimal Layer Order:**
1. Base image (FROM)
2. System packages (RUN apt-get)
3. Application dependencies (package.json, requirements.txt)
4. Application code (COPY . .)
5. Build commands (RUN build)
6. Runtime configuration (CMD, ENTRYPOINT)

### BuildKit Cache Mounts

**Mount external caches to persist across builds:**

```dockerfile
# syntax=docker/dockerfile:1

# NPM cache mount
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go module cache
FROM golang:1.21-alpine
WORKDIR /app
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Pip cache
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

**Enable BuildKit:**
```bash
export DOCKER_BUILDKIT=1
docker build .
```

### Parallel Stage Execution

```dockerfile
# syntax=docker/dockerfile:1

FROM alpine AS fetch-1
RUN wget https://example.com/file1

FROM alpine AS fetch-2
RUN wget https://example.com/file2

FROM alpine AS final
COPY --from=fetch-1 /file1 .
COPY --from=fetch-2 /file2 .
```

BuildKit automatically parallelizes independent stages.

## Layer Optimization

### Combine RUN Commands

```dockerfile
# Bad - Creates 5 layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y git
RUN apt-get install -y vim
RUN rm -rf /var/lib/apt/lists/*

# Good - Creates 1 layer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        vim && \
    rm -rf /var/lib/apt/lists/*
```

### Minimize Layer Count

**Each instruction creates a layer:**
- FROM, RUN, COPY, ADD create layers
- ENV, WORKDIR, EXPOSE, USER do not create significant layers
- Combine related operations

```dockerfile
# Bad - Many layers
COPY package.json .
COPY package-lock.json .
COPY tsconfig.json .
COPY src/ ./src/
COPY tests/ ./tests/

# Good - Fewer layers (use .dockerignore)
COPY . .
```

### Layer Size Analysis

```bash
# Inspect layer sizes
docker history myimage:latest

# Find large layers
docker history --no-trunc --format "table {{.Size}}\t{{.CreatedBy}}" myimage:latest | sort -hr | head -10
```

## Dependency Optimization

### Install Only Production Dependencies

**Node.js:**
```dockerfile
# Development dependencies excluded
RUN npm ci --only=production

# Or use package.json scripts
RUN npm ci --omit=dev
```

**Python:**
```dockerfile
# Create separate requirements files
# requirements.txt (production)
# requirements-dev.txt (development)
RUN pip install --no-cache-dir -r requirements.txt
```

**Java (Maven):**
```dockerfile
# Skip tests during build
RUN ./mvnw clean package -DskipTests
```

### Remove Development Tools

```dockerfile
# Multi-stage: Keep build tools in builder stage
FROM golang:1.21 AS builder
RUN apk add --no-cache git make
RUN make build

FROM alpine:3.21
# No build tools in final image
COPY --from=builder /app/binary /app/
```

## .dockerignore Optimization

**Reduces build context size and build time:**

```dockerignore
# Version control
.git
.gitignore

# Dependencies (installed during build)
node_modules
vendor
__pycache__

# IDE files
.vscode
.idea
*.swp

# Build artifacts
dist
build
target

# Documentation
*.md
docs/

# CI/CD
.github
.gitlab-ci.yml

# Environment files
.env
.env.*

# Logs
*.log
logs/

# Tests
tests/
*.test
coverage/
```

**Impact:**
- Smaller build context → Faster upload to Docker daemon
- Fewer files → Faster COPY operations
- No accidental secret leaks

## Runtime Performance

### Use Exec Form for CMD/ENTRYPOINT

```dockerfile
# Bad - Shell form (spawns extra sh process)
CMD node server.js

# Good - Exec form (direct process execution)
CMD ["node", "server.js"]

# Benefits:
# - Proper signal handling (SIGTERM, SIGINT)
# - Faster startup
# - Lower memory usage
```

### Optimize Application

```dockerfile
# Node.js: Use production mode
ENV NODE_ENV=production

# Python: Use optimized bytecode
ENV PYTHONOPTIMIZE=1

# Java: Set heap size
ENV JAVA_OPTS="-Xms512m -Xmx2048m"

# Go: Build with optimizations
RUN go build -ldflags="-s -w" -o app
```

### Health Checks

```dockerfile
# Efficient health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Avoid heavy health checks
# Bad: HEALTHCHECK CMD curl http://localhost/full-db-check
```

## Build Optimization Checklist

- [ ] Use multi-stage builds
- [ ] Choose minimal base images (Alpine, distroless)
- [ ] Order layers from least to most frequently changing
- [ ] Combine RUN commands where logical
- [ ] Use BuildKit cache mounts
- [ ] Create comprehensive .dockerignore
- [ ] Install only production dependencies
- [ ] Clean package manager caches in same layer
- [ ] Remove development tools from final image
- [ ] Use exec form for CMD/ENTRYPOINT
- [ ] Optimize application for production
- [ ] Add efficient health checks

## Advanced Techniques

### Squash Layers (Use with Caution)

```bash
# Squash all layers into one (loses layer caching)
docker build --squash -t myapp:latest .
```

**Use Cases:**
- Final production images
- When layer caching isn't important
- To hide sensitive information in layers (better: use multi-stage)

**Drawbacks:**
- Loses layer caching benefits
- Larger initial download
- Less transparent image history

### BuildKit Secrets (Zero-Copy Secrets)

```dockerfile
# syntax=docker/dockerfile:1
FROM alpine
RUN --mount=type=secret,id=aws_credentials \
    aws configure set credentials $(cat /run/secrets/aws_credentials)
```

```bash
docker build --secret id=aws_credentials,src=$HOME/.aws/credentials .
```

### Cross-Platform Builds

```dockerfile
# Build for multiple platforms
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    -t myapp:latest \
    .
```

## Measuring Optimization Impact

### Before and After Comparison

```bash
# Build original
docker build -t myapp:before .
docker images myapp:before

# Build optimized
docker build -t myapp:after .
docker images myapp:after

# Compare sizes
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep myapp
```

### Build Time Measurement

```bash
# Measure build time
time docker build -t myapp:latest .

# Measure with cache
docker build -t myapp:cached .

# Measure without cache
docker build --no-cache -t myapp:no-cache .
```

### Dive Tool (Layer Analysis)

```bash
# Install dive
brew install dive  # macOS
# or download from https://github.com/wagoodman/dive

# Analyze image
dive myapp:latest
```

## Real-World Examples

### Node.js Optimization

**Before (996MB):**
```dockerfile
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
CMD ["node", "server.js"]
```

**After (50MB, 95% reduction):**
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/server.js ./
CMD ["node", "server.js"]
```

### Go Optimization

**Before (800MB):**
```dockerfile
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o app
CMD ["./app"]
```

**After (8MB, 99% reduction):**
```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o app

FROM scratch
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]
```

## References

- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [Multi-stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [Docker Image Size Optimization](https://betterstack.com/community/guides/scaling-docker/docker-build-best-practices/)