# Dockerfile Optimization Guide

Comprehensive guide for optimizing Docker images for size, build time, and runtime performance.

## Image Size Optimization

### 1. Choose Minimal Base Images

**Size Comparison:**
```
ubuntu:22.04          ~80 MB
alpine:3.21           ~5 MB
distroless/base       ~20 MB
scratch               ~0 MB (empty)
```

**When to use each:**

**Alpine** - General purpose minimal Linux
```dockerfile
FROM alpine:3.21
RUN apk add --no-cache python3
```
- ✅ Very small (5 MB)
- ✅ Has package manager
- ✅ Good for interpreted languages
- ⚠️  Uses musl libc (compatibility issues with some C libraries)

**Distroless** - Production containers
```dockerfile
FROM gcr.io/distroless/python3
COPY --from=builder /app /app
```
- ✅ No shell, package manager (secure)
- ✅ Minimal attack surface
- ✅ Small size
- ⚠️  Cannot exec into container for debugging
- ⚠️  Must use multi-stage builds

**Scratch** - Static binaries only
```dockerfile
FROM scratch
COPY --from=builder /app/binary /
```
- ✅ Absolutely minimal
- ✅ Perfect for Go, Rust static binaries
- ⚠️  No OS utilities
- ⚠️  No debug capabilities

### 2. Multi-Stage Builds

**Problem: Build tools bloat production images**

**Single-stage (bloated):**
```dockerfile
FROM golang:1.21
WORKDIR /app
COPY . .
RUN go build -o server
CMD ["./server"]

# Result: ~1 GB (includes Go toolchain)
```

**Multi-stage (optimized):**
```dockerfile
# Build stage
FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN go build -o server

# Production stage
FROM alpine:3.21
COPY --from=builder /app/server /server
CMD ["/server"]

# Result: ~10 MB (100x smaller!)
```

### 3. Layer Optimization

**Combine RUN commands:**

```dockerfile
# Bad - 4 layers, poor caching
RUN apt-get update
RUN apt-get install -y curl
RUN curl -O https://example.com/file
RUN rm -f file

# Good - 1 layer, cache cleaned
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && curl -O https://example.com/file \
    && rm -rf /var/lib/apt/lists/*
```

### 4. Package Manager Cache Cleanup

**APT (Debian/Ubuntu):**
```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*
```
- Saves ~100-200 MB per layer
- Must be in same RUN command

**APK (Alpine):**
```dockerfile
RUN apk add --no-cache package1 package2
```
- Doesn't create cache at all
- Or: `apk add package && rm -rf /var/cache/apk/*`

**YUM/DNF (RHEL/Fedora):**
```dockerfile
RUN yum install -y package \
    && yum clean all \
    && rm -rf /var/cache/yum
```

**Pip (Python):**
```dockerfile
RUN pip install --no-cache-dir package
```

**NPM (Node.js):**
```dockerfile
RUN npm ci --only=production
# Or with cache mount:
RUN --mount=type=cache,target=/root/.npm \
    npm ci --only=production
```

### 5. Use .dockerignore

**Problem: Entire project copied into image**

```
.dockerignore contents:
.git/
node_modules/
*.log
.env
tests/
docs/
README.md
```

**Impact:**
- Faster builds (smaller context)
- Smaller images (fewer files)
- Prevents accidental secret leaks

## Build Time Optimization

### 1. Leverage Build Cache

**Order matters - least to most frequently changing:**

```dockerfile
# 1. Base image (rarely changes)
FROM node:21-alpine

# 2. System dependencies (rarely change)
RUN apk add --no-cache curl

# 3. Application dependencies (change occasionally)
COPY package*.json ./
RUN npm ci

# 4. Application code (changes frequently)
COPY . .
RUN npm run build
```

**Why this works:**
- Docker caches each layer
- Layers rebuild when files change
- Putting frequently-changing files last preserves cache for earlier layers

### 2. BuildKit Cache Mounts

**Enable BuildKit:**
```bash
export DOCKER_BUILDKIT=1
```

**Use cache mounts:**
```dockerfile
# syntax=docker/dockerfile:1

# Python with pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Node.js with npm cache
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go with module cache
RUN --mount=type=cache,target=/go/pkg/mod \
    go build -o app
```

**Benefits:**
- Persistent cache across builds
- Dramatically faster dependency installation
- Shared cache between projects

### 3. Parallel Multi-Stage Builds

```dockerfile
# These stages run in parallel
FROM alpine AS fetch-1
RUN wget https://example.com/file1

FROM alpine AS fetch-2
RUN wget https://example.com/file2

# This stage waits for both
FROM alpine
COPY --from=fetch-1 /file1 .
COPY --from=fetch-2 /file2 .
```

## Runtime Performance Optimization

### 1. Exec Form for CMD/ENTRYPOINT

```dockerfile
# Bad - shell form (extra shell process)
CMD python app.py

# Good - exec form (direct execution)
CMD ["python", "app.py"]
```

**Benefits:**
- Faster startup (no shell)
- Proper signal handling (SIGTERM)
- Lower memory usage

### 2. Health Checks

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
    CMD curl -f http://localhost:8080/health || exit 1
```

**Benefits:**
- Container orchestrators can detect unhealthy containers
- Automatic restarts
- Better uptime

### 3. Resource Awareness

```dockerfile
# Use all available CPUs
ENV GOMAXPROCS=0

# Or limit to specific count
ENV GOMAXPROCS=4
```

## Language-Specific Optimizations

### Node.js

```dockerfile
FROM node:21-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM node:21-alpine
COPY --from=builder /app/node_modules ./node_modules
COPY . .
USER node
CMD ["node", "server.js"]
```

**Tips:**
- Use `npm ci` instead of `npm install`
- Install only production dependencies
- Use Alpine variant (node:21-alpine vs node:21 = 150MB vs 900MB)

### Python

```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH
COPY . .
USER nobody
CMD ["python", "app.py"]
```

**Tips:**
- Use slim variant (python:3.12-slim vs python:3.12 = 50MB vs 1GB)
- Install to --user to copy to final stage
- Use --no-cache-dir to avoid pip cache

### Go

```dockerfile
FROM golang:1.21-alpine AS builder
WORKDIR /src
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /app

FROM scratch
COPY --from=builder /app /app
ENTRYPOINT ["/app"]
```

**Tips:**
- Use scratch for static binaries
- Disable CGO for static linking
- Use `-ldflags="-s -w"` to strip debug info (smaller binary)

### Java

```dockerfile
FROM eclipse-temurin:21-jdk AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline
COPY src ./src
RUN mvn package

FROM eclipse-temurin:21-jre-alpine
COPY --from=builder /app/target/*.jar /app.jar
CMD ["java", "-jar", "/app.jar"]
```

**Tips:**
- Use JRE instead of JDK for runtime (smaller)
- Download dependencies separately for caching
- Consider custom JRE with jlink for minimal image

## Advanced Techniques

### 1. Multi-Architecture Builds

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t myapp .
```

### 2. Build Secrets

```dockerfile
# syntax=docker/dockerfile:1
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm ci
```

```bash
docker build --secret id=npmrc,src=$HOME/.npmrc .
```

**Benefits:**
- Secrets not in final image
- Not in build history
- Secure credential usage

### 3. SSH Mounts

```dockerfile
RUN --mount=type=ssh \
    git clone git@github.com:private/repo.git
```

```bash
docker build --ssh default .
```

### 4. Layer Squashing

```bash
docker build --squash -t myapp .
```

**Benefits:**
- Single layer in final image
- Smaller size if cleanup commands are separate

**Drawbacks:**
- Loses layer caching benefits
- Slower rebuilds

## Optimization Checklist

- [ ] Use minimal base image (Alpine, distroless, scratch)
- [ ] Implement multi-stage builds
- [ ] Combine RUN commands
- [ ] Clean package manager cache
- [ ] Order layers by change frequency
- [ ] Use BuildKit cache mounts
- [ ] Create .dockerignore file
- [ ] Use exec form for CMD/ENTRYPOINT
- [ ] Add HEALTHCHECK for services
- [ ] Pin dependency versions
- [ ] Remove development dependencies
- [ ] Use --no-install-recommends for apt
- [ ] Consider language-specific optimizations
- [ ] Enable BuildKit features

## Measuring Optimization

### Before Optimization
```bash
docker images myapp
# REPOSITORY   TAG       SIZE
# myapp        latest    1.2GB
```

### After Optimization
```bash
docker images myapp-optimized
# REPOSITORY        TAG       SIZE
# myapp-optimized   latest    50MB
```

### Build Time Comparison
```bash
time docker build -t myapp .
# real    5m30s

time docker build -t myapp-optimized .
# real    0m45s (with cache)
```

## Tools for Analysis

### dive - Layer Analysis
```bash
dive myapp:latest
```
- Shows layer-by-layer size
- Identifies wasted space
- Suggests optimizations

### docker history
```bash
docker history myapp:latest
```
- Shows each layer's size
- Identifies large layers

### docker scout
```bash
docker scout cves myapp:latest
```
- Scans for vulnerabilities
- Recommends base image updates

## Resources

- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [BuildKit Documentation](https://docs.docker.com/build/buildkit/)
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)
- [dive - Layer Explorer](https://github.com/wagoodman/dive)