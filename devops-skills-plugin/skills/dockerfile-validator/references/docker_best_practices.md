# Docker Best Practices Reference

This document summarizes official Docker best practices based on current recommendations from Docker documentation and industry standards.

## General Principles

### 1. Create Ephemeral Containers
- Containers should be as stateless and ephemeral as possible
- Should be able to stop, destroy, and recreate with minimal setup
- Align with Twelve-Factor App methodology

### 2. Understand Build Context
- Use `.dockerignore` to exclude unnecessary files
- Keep context size minimal for faster builds
- Don't include secrets or sensitive data in context

### 3. Use Multi-Stage Builds
- Separate build dependencies from runtime
- Dramatically reduce final image size
- Improve security by minimizing attack surface

### 4. One Concern Per Container
- Each container should address a single concern
- Makes containers more reusable and easier to scale
- Simplifies debugging and updates

## Dockerfile Instructions Best Practices

### FROM

**Use specific tags, not :latest**
```dockerfile
# Bad
FROM node:latest

# Good
FROM node:21-alpine

# Better
FROM node:21-alpine@sha256:abc123...
```

**Choose minimal base images**
- Alpine Linux: ~5 MB base (vs ~80 MB for Ubuntu)
- Distroless: No shell, package manager (minimal attack surface)
- Scratch: Absolutely minimal (for static binaries)

**Prefer official images**
- Look for "Official Image" or "Verified Publisher" badges
- Official images are maintained and regularly updated

### RUN

**Chain commands to reduce layers**
```dockerfile
# Bad - creates 4 layers
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN curl -sL https://example.com/script.sh | bash

# Good - creates 1 layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    vim \
    && rm -rf /var/lib/apt/lists/* \
    && curl -sL https://example.com/script.sh | bash
```

**Clean up in same layer**
```dockerfile
# Package manager cache must be removed in same RUN
RUN apt-get update && apt-get install -y \
    package1 \
    package2 \
    && rm -rf /var/lib/apt/lists/*

# For Alpine
RUN apk add --no-cache package1 package2
```

**Use --no-install-recommends for apt**
```dockerfile
RUN apt-get install -y --no-install-recommends package
```

**Pin package versions**
```dockerfile
# For apt
RUN apt-get install -y package=1.2.3-1

# For apk
RUN apk add package=1.2.3-r0

# For pip
RUN pip install package==1.2.3
```

**Sort multi-line arguments**
```dockerfile
RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    wget \
    && rm -rf /var/lib/apt/lists/*
```

**Use pipefail for pipes**
```dockerfile
RUN set -o pipefail && wget -O - https://example.com | wc -l > /number
```

### COPY vs ADD

**Prefer COPY over ADD**
```dockerfile
# Use COPY for files and directories
COPY app.py /app/

# Only use ADD for auto-extraction or remote URLs
ADD https://example.com/file.tar.gz /tmp/
```

**Use COPY --chown to avoid extra layer**
```dockerfile
# Bad - creates extra layer
COPY app.py /app/
RUN chown user:user /app/app.py

# Good - single layer
COPY --chown=user:user app.py /app/
```

### WORKDIR

**Use absolute paths**
```dockerfile
# Bad
WORKDIR app

# Good
WORKDIR /app
```

**Don't use RUN cd**
```dockerfile
# Bad
RUN cd /app && npm install

# Good
WORKDIR /app
RUN npm install
```

### USER

**Don't run as root**
```dockerfile
# Create user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Or for Alpine
RUN addgroup -g 1001 -S appuser && adduser -S appuser -u 1001

# Switch to user
USER appuser
```

**Use high UID (>10000) for better security**
```dockerfile
RUN useradd -u 10001 -m appuser
USER appuser
```

### CMD and ENTRYPOINT

**Use exec form for proper signal handling**
```dockerfile
# Bad - shell form (doesn't handle signals)
CMD python app.py

# Good - exec form
CMD ["python", "app.py"]
```

**Combine ENTRYPOINT and CMD**
```dockerfile
# ENTRYPOINT defines the executable
ENTRYPOINT ["python"]

# CMD provides default arguments (can be overridden)
CMD ["app.py"]
```

### EXPOSE

**Document ports even though it doesn't publish**
```dockerfile
EXPOSE 8080
EXPOSE 443
```

### HEALTHCHECK

**Add health checks for services**
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1
```

### LABEL

**Add metadata**
```dockerfile
LABEL org.opencontainers.image.authors="team@example.com"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Application description"
```

## Build Optimization

### Layer Caching

**Order instructions from least to most frequently changing**
```dockerfile
# 1. Base image (rarely changes)
FROM node:21-alpine

# 2. System packages (rarely change)
RUN apk add --no-cache curl

# 3. Dependencies (change occasionally)
COPY package*.json ./
RUN npm ci

# 4. Source code (changes frequently)
COPY . .
```

### Multi-Stage Builds

**Separate build and runtime**
```dockerfile
# Build stage
FROM node:21 AS builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Runtime stage
FROM node:21-alpine
COPY --from=builder /app/dist /app
CMD ["node", "/app/index.js"]
```

### BuildKit Features

**Enable modern features**
```dockerfile
# syntax=docker/dockerfile:1

# Use cache mounts
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Use secret mounts (secrets not in final image)
RUN --mount=type=secret,id=aws,target=/root/.aws/credentials \
    aws s3 cp s3://bucket/file .
```

## Security Best Practices

### 1. Scan Images
```bash
docker scan myimage:tag
# or
trivy image myimage:tag
```

### 2. Use Minimal Base Images
- Fewer packages = fewer vulnerabilities
- Alpine, distroless, or scratch

### 3. Don't Store Secrets in Images
```dockerfile
# Bad
ENV DATABASE_PASSWORD=secret123

# Good - use runtime config or secrets
# Pass at runtime: docker run -e DATABASE_PASSWORD=...
```

### 4. Run as Non-Root
```dockerfile
USER appuser
```

### 5. Use Read-Only Filesystem
```bash
docker run --read-only myimage
```

### 6. Limit Capabilities
```bash
docker run --cap-drop=ALL --cap-add=NET_BIND_SERVICE myimage
```

## Common Anti-Patterns

### ❌ Using :latest tag
- Unpredictable
- Not reproducible
- Can break without warning

### ❌ Not cleaning package cache
```dockerfile
# Missing cleanup increases image by hundreds of MB
RUN apt-get update && apt-get install -y package
# Missing: && rm -rf /var/lib/apt/lists/*
```

### ❌ Running as root
- Security risk
- Violates principle of least privilege

### ❌ Installing unnecessary packages
```dockerfile
# Bloated image
RUN apt-get install -y vim nano emacs curl wget
```

### ❌ Using ADD instead of COPY
- ADD has implicit behavior
- Can extract archives unexpectedly

### ❌ Multiple FROM in non-multi-stage context
- Creates confusion
- Use multi-stage builds properly

## Resources

- [Official Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [Multi-Stage Builds](https://docs.docker.com/build/building/multi-stage/)