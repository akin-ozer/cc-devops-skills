# Dockerfile Security Best Practices

## Overview

This guide provides comprehensive security best practices for writing secure Dockerfiles. Security should be a primary consideration when containerizing applications.

## Table of Contents

1. [Base Image Security](#base-image-security)
2. [User Management](#user-management)
3. [Secrets Management](#secrets-management)
4. [Dependency Management](#dependency-management)
5. [Attack Surface Reduction](#attack-surface-reduction)
6. [Vulnerability Scanning](#vulnerability-scanning)

## Base Image Security

### Use Specific Tags

**Problem:** Using `:latest` tag can lead to unpredictable builds and security vulnerabilities.

```dockerfile
# Bad - Unpredictable, may pull vulnerable versions
FROM node:latest

# Good - Specific version
FROM node:20-alpine

# Better - Specific version with digest for reproducibility
FROM node:20-alpine@sha256:2c6c59cf4d34d4f937ddfcf33bab9d8bbad8658d1b9de7b97622566a52167f5b
```

### Use Minimal Base Images

**Principle:** Smaller images have fewer attack vectors.

```dockerfile
# Large attack surface (>1GB)
FROM ubuntu:22.04

# Medium attack surface (~200MB)
FROM node:20

# Small attack surface (~50MB)
FROM node:20-alpine

# Minimal attack surface (~2MB for Go apps)
FROM gcr.io/distroless/static-debian12
```

**Recommended Base Images:**
- **Alpine Linux:** Minimal Linux distribution (~5MB base)
- **Distroless:** Google's minimal container images (no shell, package managers)
- **Scratch:** Empty base image (for static binaries only)

### Scan Base Images

```bash
# Use Trivy to scan base images
trivy image node:20-alpine

# Use Snyk
snyk container test node:20-alpine

# Use Docker Scout
docker scout cves node:20-alpine
```

## User Management

### Never Run as Root

**Problem:** Running as root gives attackers full system access if container is compromised.

```dockerfile
# Bad - Runs as root (default)
FROM node:20-alpine
COPY . /app
CMD ["node", "server.js"]

# Good - Creates and uses non-root user
FROM node:20-alpine
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001
COPY --chown=nodejs:nodejs . /app
USER nodejs
CMD ["node", "server.js"]
```

### User Creation Patterns

**Alpine Linux:**
```dockerfile
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup
USER appuser
```

**Debian/Ubuntu:**
```dockerfile
RUN useradd -m -u 1001 appuser
USER appuser
```

**Distroless (built-in nonroot user):**
```dockerfile
FROM gcr.io/distroless/static-debian12
USER nonroot:nonroot
```

### Set Proper File Permissions

```dockerfile
# Copy with ownership
COPY --chown=appuser:appuser . /app

# Ensure executables have correct permissions
RUN chmod +x /app/entrypoint.sh
```

## Secrets Management

### Never Hardcode Secrets

```dockerfile
# Bad - Hardcoded secrets
ENV API_KEY=sk_live_abc123
ENV DATABASE_PASSWORD=password123

# Good - Use runtime environment variables
ENV API_KEY=""
ENV DATABASE_PASSWORD=""
```

### Use Build Secrets (BuildKit)

```dockerfile
# Mount secrets during build (never stored in image layers)
# syntax=docker/dockerfile:1
FROM alpine
RUN --mount=type=secret,id=api_key \
    API_KEY=$(cat /run/secrets/api_key) && \
    echo "Configuring with API key..." && \
    # Use API_KEY here
    rm -f /run/secrets/api_key
```

**Build command:**
```bash
docker build --secret id=api_key,src=.env .
```

### Avoid Secrets in Layers

```dockerfile
# Bad - Secret remains in image history
FROM alpine
RUN echo "SECRET_KEY=abc123" > /app/config
RUN rm /app/config  # Secret still in previous layer!

# Good - Use multi-stage builds or build secrets
FROM alpine
RUN --mount=type=secret,id=config \
    cat /run/secrets/config > /app/config && \
    process_config && \
    rm /app/config
```

## Dependency Management

### Pin Dependency Versions

```dockerfile
# Bad - Unpinned versions
RUN apt-get install -y curl git

# Good - Pinned versions
RUN apt-get install -y \
    curl=7.81.0-1ubuntu1.16 \
    git=1:2.34.1-1ubuntu1.11
```

**Node.js:**
```dockerfile
# Use package-lock.json or yarn.lock
COPY package*.json ./
RUN npm ci  # Uses lock file
```

**Python:**
```dockerfile
# Pin versions in requirements.txt
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
```

**Go:**
```dockerfile
# go.sum ensures reproducible builds
COPY go.mod go.sum ./
RUN go mod download
```

### Clean Package Manager Caches

```dockerfile
# Alpine (apk)
RUN apk add --no-cache curl

# Debian/Ubuntu (apt)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Node.js (npm)
RUN npm ci && npm cache clean --force

# Python (pip)
RUN pip install --no-cache-dir -r requirements.txt
```

## Attack Surface Reduction

### Minimize Installed Packages

```dockerfile
# Bad - Installs unnecessary packages
RUN apt-get install -y \
    curl \
    wget \
    vim \
    sudo \
    ssh

# Good - Only essential packages
RUN apt-get install -y --no-install-recommends \
    curl \
    ca-certificates
```

### Use Multi-Stage Builds

```dockerfile
# Build stage - can include build tools
FROM golang:1.21-alpine AS builder
RUN apk add --no-cache git make
COPY . .
RUN make build

# Production stage - minimal runtime
FROM alpine:3.21
COPY --from=builder /app/binary /app/binary
CMD ["/app/binary"]
```

### Remove Build Dependencies

```dockerfile
# Install, use, and remove in same layer
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    musl-dev \
    && pip install --no-cache-dir -r requirements.txt \
    && apk del .build-deps
```

### Disable Unnecessary Services

```dockerfile
# Don't include SSH, telnet, or other services
# Use docker exec for debugging instead
```

## Network Security

### Expose Only Necessary Ports

```dockerfile
# Document exposed ports
EXPOSE 8080

# Don't expose unnecessary ports
# Bad: EXPOSE 22 (SSH)
# Bad: EXPOSE 3306 (MySQL in app container)
```

### Use Non-Privileged Ports

```dockerfile
# Good - Use port > 1024 (doesn't require root)
EXPOSE 8080

# Avoid privileged ports (< 1024)
# EXPOSE 80  # Requires root
```

## Vulnerability Scanning

### Integrate Scanning into CI/CD

```yaml
# GitHub Actions example
- name: Scan Docker image
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: myapp:latest
    format: 'sarif'
    output: 'trivy-results.sarif'
```

### Regular Image Updates

```dockerfile
# Rebuild images regularly to get security patches
FROM node:20-alpine  # Alpine releases security updates frequently
```

### Scan for Secrets

```bash
# Use gitleaks or trufflehog
docker run -v $(pwd):/path zricethezav/gitleaks:latest detect --source=/path

# Use hadolint to detect some secret patterns
hadolint Dockerfile
```

## Security Checklist

- [ ] Use specific base image tags (no `:latest`)
- [ ] Use minimal base images (Alpine, distroless)
- [ ] Create and use non-root user
- [ ] Never hardcode secrets
- [ ] Use build secrets for sensitive data
- [ ] Pin dependency versions
- [ ] Clean package manager caches
- [ ] Minimize installed packages
- [ ] Use multi-stage builds
- [ ] Expose only necessary ports
- [ ] Scan images for vulnerabilities
- [ ] Update base images regularly
- [ ] Use HEALTHCHECK for services
- [ ] Validate with hadolint and Checkov

## Common Vulnerabilities

### CVE-Related Issues

1. **Outdated base images:** Rebuild regularly
2. **Known vulnerable packages:** Scan and update
3. **Missing security patches:** Use latest patch versions

### Configuration Issues

1. **Running as root:** Create non-root user
2. **Exposed secrets:** Use build secrets or runtime config
3. **Unnecessary packages:** Minimize attack surface
4. **Missing health checks:** Add HEALTHCHECK directive

## Tools for Security

- **Trivy:** Comprehensive vulnerability scanner
- **Snyk:** Security scanning and monitoring
- **Checkov:** Policy-as-code security scanning
- **hadolint:** Dockerfile linting with security rules
- **Docker Scout:** Docker's official security tool
- **Clair:** Container vulnerability analysis
- **Anchore:** Container security and compliance

## References

- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Snyk Docker Security Best Practices](https://snyk.io/learn/docker-security/)