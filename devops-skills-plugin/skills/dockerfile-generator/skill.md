---
name: dockerfile-generator
description: Comprehensive toolkit for generating production-ready Dockerfiles following current standards and best practices. Use this skill when creating new Dockerfiles, implementing containerization for applications, or optimizing existing Docker builds.
---

# Dockerfile Generator

## Overview

This skill provides a comprehensive workflow for generating production-ready Dockerfiles with security, optimization, and best practices built-in. Generates multi-stage builds, security-hardened configurations, and optimized layer structures with automatic validation and iterative error fixing.

**Key Features:**
- Multi-stage builds for optimal image size (50-85% reduction)
- Security hardening (non-root users, minimal base images, no secrets)
- Layer caching optimization for faster builds
- Language-specific templates (Node.js, Python, Go, Java)
- Automatic .dockerignore generation
- Integration with devops-skills:dockerfile-validator for validation
- Iterative validation and error fixing (minimum 1 iteration if errors found)
- WebSearch and context7 integration for framework-specific patterns

## When to Use This Skill

Invoke this skill when:
- Creating new Dockerfiles from scratch
- Containerizing applications (Node.js, Python, Go, Java, or other languages)
- Implementing multi-stage builds for size optimization
- Converting existing Dockerfiles to best practices
- Generating production-ready container configurations
- Optimizing Docker builds for security and performance
- The user asks to "create", "generate", "build", or "write" a Dockerfile
- Implementing containerization for microservices
- Setting up CI/CD pipeline container builds

## Do NOT Use This Skill For

- Validating existing Dockerfiles (use devops-skills:dockerfile-validator instead)
- Building or running containers (use docker build/run commands)
- Debugging running containers (use docker logs, docker exec)
- Managing Docker images or registries

## Dockerfile Generation Workflow

Follow this workflow when generating Dockerfiles. Adapt based on user needs:

### Stage 1: Gather Requirements

**Objective:** Understand what needs to be containerized and gather all necessary information.

**Information to Collect:**

1. **Application Details:**
   - Programming language and version (Node.js 18/20, Python 3.11/3.12, Go 1.21+, Java 17/21, etc.)
   - Application type (web server, API, CLI tool, batch job, etc.)
   - Framework (Express, FastAPI, Spring Boot, etc.)
   - Entry point (main file, command to run)

2. **Dependencies:**
   - Package manager (npm/yarn/pnpm, pip/poetry, go mod, maven/gradle)
   - System dependencies (build tools, libraries, etc.)
   - Build-time vs runtime dependencies

3. **Application Configuration:**
   - Port(s) to expose
   - Environment variables needed
   - Configuration files
   - Health check endpoint (for web services)
   - Volume mounts (if any)

4. **Build Requirements:**
   - Build commands
   - Test commands (optional)
   - Compilation needs (for compiled languages)
   - Static asset generation

5. **Production Requirements:**
   - Expected image size constraints
   - Security requirements
   - Scaling needs
   - Resource constraints (CPU, memory)

**Use AskUserQuestion if information is missing or unclear.**

**Example Questions:**
```
- What programming language and version is your application using?
- What is the main entry point to run your application?
- Does your application expose any ports? If so, which ones?
- Do you need any system dependencies beyond the base language runtime?
- Does your application need a health check endpoint?
```

### Stage 2: Framework/Library Documentation Lookup (if needed)

**Objective:** Research framework-specific containerization patterns and best practices.

**When to Perform This Stage:**
- User mentions a specific framework (Next.js, Django, FastAPI, Spring Boot, etc.)
- Application has complex build requirements
- Need guidance on framework-specific optimization

**Research Process:**

1. **Try context7 MCP first (preferred):**
   ```
   Use mcp__context7__resolve-library-id with the framework name
   Examples:
   - "next.js" for Next.js applications
   - "django" for Django applications
   - "fastapi" for FastAPI applications
   - "spring-boot" for Spring Boot applications
   - "express" for Express.js applications

   Then use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID from resolve step
   - topic: "docker deployment production build"
   - page: 1 (fetch additional pages if needed)
   ```

2. **Fallback to WebSearch if context7 fails:**
   ```
   Search query pattern:
   "<framework>" "<version>" dockerfile best practices production 2025

   Examples:
   - "Next.js 14 dockerfile best practices production 2025"
   - "FastAPI dockerfile best practices production 2025"
   - "Spring Boot 3 dockerfile best practices production 2025"
   ```

3. **Extract key information:**
   - Recommended base images
   - Build optimization techniques
   - Framework-specific environment variables
   - Production vs development configurations
   - Security considerations

### Stage 3: Generate Dockerfile

**Objective:** Create a production-ready, multi-stage Dockerfile following best practices.

**Core Principles:**

1. **Multi-Stage Builds (REQUIRED for compiled languages, RECOMMENDED for all):**
   - Separate build stage from runtime stage
   - Keep build tools out of final image
   - Copy only necessary artifacts
   - Results in 50-85% smaller images

2. **Security Hardening (REQUIRED):**
   - Use specific version tags (NEVER use :latest)
   - Run as non-root user (create dedicated user)
   - Use minimal base images (alpine, distroless)
   - No hardcoded secrets
   - Scan base images for vulnerabilities

3. **Layer Optimization (REQUIRED):**
   - Order instructions from least to most frequently changing
   - Copy dependency files before application code
   - Combine related RUN commands with &&
   - Clean up package manager caches in same layer
   - Leverage build cache effectively

4. **Production Readiness (REQUIRED):**
   - Add HEALTHCHECK for services
   - Use exec form for ENTRYPOINT/CMD
   - Set WORKDIR to absolute paths
   - Document exposed ports with EXPOSE

**Language-Specific Templates:**

#### Node.js Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependency files for caching
COPY package*.json ./
# Use npm ci for deterministic builds
RUN npm ci --only=production && \
    npm cache clean --force

# Copy application code
COPY . .

# Build application (if needed)
# RUN npm run build

# Production stage
FROM node:20-alpine AS production
WORKDIR /app

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Copy dependencies and application from builder
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start application
CMD ["node", "index.js"]
```

#### Python Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# Build stage
FROM python:3.12-slim AS builder
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
FROM python:3.12-slim AS production
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
EXPOSE 8000

# Health check (adjust endpoint as needed)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health').read()" || exit 1

# Start application
CMD ["python", "app.py"]
```

#### Go Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o main .

# Production stage (using distroless for minimal image)
FROM gcr.io/distroless/static-debian12 AS production
WORKDIR /

# Copy binary from builder
COPY --from=builder /app/main /main

# Expose port
EXPOSE 8080

# Health check (distroless doesn't have shell, so this is commented)
# HEALTHCHECK not supported in distroless without shell

# Switch to non-root user (distroless runs as nonroot by default)
USER nonroot:nonroot

# Start application
ENTRYPOINT ["/main"]
```

#### Java Multi-Stage Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

# Build stage
FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /app

# Copy Maven wrapper and pom.xml
COPY mvnw pom.xml ./
COPY .mvn .mvn

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline

# Copy source code
COPY src ./src

# Build application
RUN ./mvnw clean package -DskipTests && \
    mv target/*.jar target/app.jar

# Production stage (using JRE instead of JDK)
FROM eclipse-temurin:21-jre-jammy AS production
WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy JAR from builder
COPY --from=builder --chown=appuser:appuser /app/target/app.jar ./app.jar

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]
```

**Selection Logic:**
- Node.js: Use for JavaScript/TypeScript applications
- Python: Use for Python applications (web, API, scripts)
- Go: Use for Go applications (excellent for minimal images)
- Java: Use for Spring Boot, Quarkus, or other Java frameworks
- Generic: Create custom Dockerfile for other languages

**Always Include:**
1. Syntax directive: `# syntax=docker/dockerfile:1`
2. Multi-stage build (build + production stages)
3. Non-root user creation and usage
4. HEALTHCHECK for services (if applicable)
5. Proper WORKDIR settings
6. EXPOSE for documented ports
7. Clean package manager caches
8. exec form for CMD/ENTRYPOINT

### Stage 4: Generate .dockerignore

**Objective:** Create comprehensive .dockerignore to reduce build context and prevent secret leaks.

**Always create .dockerignore with generated Dockerfile.**

**Standard .dockerignore Template:**

```
# Git
.git
.gitignore
.gitattributes

# CI/CD
.github
.gitlab-ci.yml
.travis.yml
.circleci

# Documentation
README.md
CHANGELOG.md
CONTRIBUTING.md
LICENSE
*.md
docs/

# Docker
Dockerfile*
docker-compose*.yml
.dockerignore

# Environment
.env
.env.*
*.local

# Logs
logs/
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Dependencies (language-specific - add as needed)
node_modules/
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
venv/
.venv/
target/
*.class

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Testing
coverage/
.coverage
*.cover
.pytest_cache/
.tox/
test-results/

# Build artifacts
dist/
build/
*.egg-info/
```

**Customize based on language:**
- Node.js: Add `node_modules/`, `npm-debug.log`, `yarn-error.log`
- Python: Add `__pycache__/`, `*.pyc`, `.venv/`, `.pytest_cache/`
- Go: Add `vendor/`, `*.exe`, `*.test`
- Java: Add `target/`, `*.class`, `*.jar` (except final artifact)

### Stage 5: Validate with devops-skills:dockerfile-validator

**Objective:** Ensure generated Dockerfile follows best practices and has no issues.

**REQUIRED: Always validate after generation.**

**Validation Process:**

1. **Invoke devops-skills:dockerfile-validator skill:**
   ```
   Use the Skill tool to invoke devops-skills:dockerfile-validator
   This will run:
   - hadolint (syntax and best practices)
   - Checkov (security scanning)
   - Custom validation (layer optimization, etc.)
   ```

2. **Parse validation results:**
   - Categorize issues by severity (error, warning, info)
   - Identify actionable fixes
   - Prioritize security issues

3. **Expected validation output:**
   ```
   [1/4] Syntax Validation (hadolint)
   [2/4] Security Scan (Checkov)
   [3/4] Best Practices Validation
   [4/4] Optimization Analysis
   ```

### Stage 6: Iterate on Validation Errors

**Objective:** Fix any validation errors and re-validate.

**REQUIRED: Iterate at least ONCE if validation finds errors.**

**Iteration Process:**

1. **If validation finds errors:**
   - Analyze each error
   - Apply fixes to Dockerfile
   - Re-run validation
   - Repeat until clean OR maximum 3 iterations

2. **If validation finds warnings:**
   - Assess if warnings are acceptable
   - Apply fixes for critical warnings
   - Document suppressed warnings with justification

3. **Common fixes:**
   - Add version tags to base images
   - Add USER directive before CMD
   - Add HEALTHCHECK for services
   - Combine RUN commands
   - Clean up package caches
   - Use COPY instead of ADD

**Example iteration:**
```
Iteration 1:
- Error: DL3006 - Missing version tag
- Fix: Change FROM node:alpine to FROM node:20-alpine
- Re-validate

Iteration 2:
- Warning: DL3059 - Multiple consecutive RUN commands
- Fix: Combine RUN commands with &&
- Re-validate

Iteration 3:
- All checks passed ✓
```

### Stage 7: Final Review and Recommendations

**Objective:** Provide comprehensive summary and next steps.

**Deliverables:**

1. **Generated Files:**
   - Dockerfile (validated and optimized)
   - .dockerignore (comprehensive)

2. **Validation Summary:**
   - All validation results
   - Any remaining warnings (with justification)
   - Security scan results

3. **Usage Instructions:**
   ```bash
   # Build the image
   docker build -t myapp:1.0 .

   # Run the container
   docker run -p 3000:3000 myapp:1.0

   # Test health check (if applicable)
   curl http://localhost:3000/health
   ```

4. **Optimization Metrics (REQUIRED - provide explicit estimates):**

   Always include a summary like this:
   ```
   ## Optimization Metrics

   | Metric | Estimate |
   |--------|----------|
   | Image Size | ~150MB (vs ~500MB without multi-stage, 70% reduction) |
   | Build Cache | Layer caching enabled for dependencies |
   | Security | Non-root user, minimal base image, no secrets |
   ```

   **Language-specific size estimates:**
   - **Node.js**: ~50-150MB with Alpine (vs ~1GB with full node image)
   - **Python**: ~150-250MB with slim (vs ~900MB with full python image)
   - **Go**: ~5-20MB with distroless/scratch (vs ~800MB with full golang image)
   - **Java**: ~200-350MB with JRE (vs ~500MB+ with JDK)

5. **Next Steps (REQUIRED - always include as bulleted list):**

   Always provide explicit next steps:
   ```
   ## Next Steps

   - [ ] Test the build locally: `docker build -t myapp:1.0 .`
   - [ ] Run and verify the container works as expected
   - [ ] Update CI/CD pipeline to use the new Dockerfile
   - [ ] Consider BuildKit cache mounts for faster builds (see Modern Docker Features)
   - [ ] Set up automated vulnerability scanning with `docker scout` or `trivy`
   - [ ] Add to container registry and deploy
   ```

## Generation Scripts (Optional Reference)

The `scripts/` directory contains standalone bash scripts for manual Dockerfile generation outside of this skill:

- `generate_nodejs.sh` - CLI tool for Node.js Dockerfiles
- `generate_python.sh` - CLI tool for Python Dockerfiles
- `generate_golang.sh` - CLI tool for Go Dockerfiles
- `generate_java.sh` - CLI tool for Java Dockerfiles
- `generate_dockerignore.sh` - CLI tool for .dockerignore generation

**Purpose:** These scripts are reference implementations and manual tools for users who want to generate Dockerfiles via command line without using Claude Code. They demonstrate the same best practices embedded in this skill.

**When using this skill:** Claude generates Dockerfiles directly using the templates and patterns documented in this skill.md, rather than invoking these scripts. The templates in this document are the authoritative source.

**Script usage example:**
```bash
# Manual Dockerfile generation
cd .claude/skills/dockerfile-generator/scripts
./generate_nodejs.sh --version 20 --port 3000 --output Dockerfile
```

## Best Practices Reference

### Security Best Practices

1. **Use Specific Tags:**
   ```dockerfile
   # Bad
   FROM node:alpine

   # Good
   FROM node:20-alpine

   # Better (with digest for reproducibility)
   FROM node:20-alpine@sha256:abc123...
   ```

2. **Run as Non-Root:**
   ```dockerfile
   # Create user
   RUN addgroup -g 1001 -S appgroup && \
       adduser -S appuser -u 1001 -G appgroup

   # Switch to user before CMD
   USER appuser
   ```

3. **Use Minimal Base Images:**
   - Alpine Linux (small, secure)
   - Distroless (no shell, minimal attack surface)
   - Specific runtime images (node:alpine vs node:latest)

4. **Never Hardcode Secrets:**
   ```dockerfile
   # Bad
   ENV API_KEY=secret123

   # Good - use build secrets
   # docker build --secret id=api_key,src=.env
   RUN --mount=type=secret,id=api_key \
       API_KEY=$(cat /run/secrets/api_key) ./configure
   ```

### Optimization Best Practices

1. **Layer Caching:**
   ```dockerfile
   # Copy dependency files first
   COPY package.json package-lock.json ./
   RUN npm ci

   # Copy application code last
   COPY . .
   ```

2. **Combine RUN Commands:**
   ```dockerfile
   # Bad (creates 3 layers)
   RUN apt-get update
   RUN apt-get install -y curl
   RUN rm -rf /var/lib/apt/lists/*

   # Good (creates 1 layer)
   RUN apt-get update && \
       apt-get install -y --no-install-recommends curl && \
       rm -rf /var/lib/apt/lists/*
   ```

3. **Multi-Stage Builds:**
   ```dockerfile
   # Build stage - can be large
   FROM node:20 AS builder
   WORKDIR /app
   COPY . .
   RUN npm install && npm run build

   # Production stage - minimal
   FROM node:20-alpine
   COPY --from=builder /app/dist ./dist
   CMD ["node", "dist/index.js"]
   ```

### Production Readiness

1. **Health Checks:**
   ```dockerfile
   HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
       CMD curl -f http://localhost:3000/health || exit 1
   ```

2. **Proper Signals:**
   ```dockerfile
   # Use exec form for proper signal handling
   CMD ["node", "server.js"]  # Good
   CMD node server.js         # Bad (no signal forwarding)
   ```

3. **Metadata:**
   ```dockerfile
   LABEL maintainer="team@example.com" \
         version="1.0.0" \
         description="My application"
   ```

## Common Patterns

### Pattern 1: Node.js with Next.js

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nextjs -u 1001
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
USER nextjs
EXPOSE 3000
CMD ["npm", "start"]
```

### Pattern 2: Python with FastAPI

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
RUN useradd -m -u 1001 appuser
COPY --from=builder /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .
ENV PATH=/home/appuser/.local/bin:$PATH
USER appuser
EXPOSE 8000
HEALTHCHECK CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Pattern 3: Go CLI Tool

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.* ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-s -w" -o /bin/app

FROM scratch
COPY --from=builder /bin/app /app
ENTRYPOINT ["/app"]
```

## Modern Docker Features (2025)

### Multi-Platform Builds with BuildX

**Use Case:** Build images that work on both AMD64 and ARM64 architectures (e.g., x86 servers and Apple Silicon Macs).

**Enable BuildX:**
```bash
# BuildX is included in Docker Desktop by default
# For Linux, ensure BuildX is installed
docker buildx version
```

**Create Multi-Platform Images:**
```bash
# Build for multiple platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:latest \
  --push \
  .

# Build and load for current platform (testing)
docker buildx build \
  --platform linux/amd64 \
  -t myapp:latest \
  --load \
  .
```

**Dockerfile Considerations:**
```dockerfile
# Most Dockerfiles work across platforms automatically
# Use platform-specific base images when needed
FROM --platform=$BUILDPLATFORM node:20-alpine AS builder

# Access build arguments for platform info
ARG TARGETPLATFORM
ARG BUILDPLATFORM
RUN echo "Building on $BUILDPLATFORM for $TARGETPLATFORM"
```

**When to Use:**
- Deploying to mixed infrastructure (x86 + ARM)
- Supporting Apple Silicon Macs in development
- Optimizing for AWS Graviton (ARM-based) instances
- Building cross-platform CLI tools

### Software Bill of Materials (SBOM)

**Use Case:** Generate SBOM for supply chain security and compliance (increasingly required in 2025).

**Generate SBOM During Build:**
```bash
# Generate SBOM with BuildKit (Docker 24.0+)
docker buildx build \
  --sbom=true \
  -t myapp:latest \
  .

# SBOM is attached as attestation to the image
# View SBOM
docker buildx imagetools inspect myapp:latest --format "{{ json .SBOM }}"
```

**Generate SBOM from Existing Image:**
```bash
# Using Syft
syft myapp:latest -o json > sbom.json

# Using Docker Scout
docker scout sbom myapp:latest
```

**SBOM Benefits:**
- Vulnerability tracking across supply chain
- License compliance verification
- Dependency transparency
- Audit trail for security reviews
- Required for government/enterprise contracts

**Integration with CI/CD:**
```yaml
# GitHub Actions example
- name: Build with SBOM
  run: |
    docker buildx build \
      --sbom=true \
      --provenance=true \
      -t myapp:latest \
      --push \
      .
```

### BuildKit Cache Mounts (Advanced)

**Use Case:** Dramatically faster builds by persisting package manager caches across builds.

**Already covered in detail in `references/optimization_patterns.md` (lines 98-125).**

**Quick reference:**
```dockerfile
# syntax=docker/dockerfile:1

# NPM cache mount (30-50% faster builds)
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go module cache
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download

# Pip cache
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt
```

## Error Handling

### Common Generation Issues

1. **Missing dependency files:**
   - Ensure package.json, requirements.txt, go.mod, pom.xml exist
   - Ask user to provide or generate template

2. **Unknown framework:**
   - Use WebSearch or context7 to research
   - Fall back to generic template
   - Ask user for specific requirements

3. **Validation failures:**
   - Apply fixes automatically
   - Iterate until clean
   - Document any suppressions

## Integration with Other Skills

This skill works well in combination with:
- **devops-skills:dockerfile-validator** - Validates generated Dockerfiles (REQUIRED)
- **k8s-generator** - Generate Kubernetes deployments for the container
- **helm-generator** - Create Helm charts with the container image

## Notes

- **Always use multi-stage builds** for compiled languages
- **Always create non-root user** for security
- **Always generate .dockerignore** to prevent secret leaks
- **Always validate** with devops-skills:dockerfile-validator
- **Iterate at least once** if validation finds errors
- Use alpine or distroless base images when possible
- Pin all version tags (never use :latest)
- Clean up package manager caches in same layer
- Order Dockerfile instructions from least to most frequently changing
- Use BuildKit features for advanced optimization
- Test builds locally before committing
- Keep Dockerfiles simple and maintainable
- Document any non-obvious patterns with comments

## Sources

This skill is based on comprehensive research from authoritative sources:

**Official Docker Documentation:**
- [Docker Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Multi-stage Builds](https://docs.docker.com/get-started/docker-concepts/building-images/multi-stage-builds/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)

**Security Guidelines:**
- [Dockerfile Best Practices 2025](https://blog.bytescrum.com/dockerfile-best-practices-2025-secure-fast-and-modern)
- [Docker Security Best Practices](https://betterstack.com/community/guides/scaling-docker/docker-build-best-practices/)

**Optimization Resources:**
- [Docker Multistage Builds Guide](https://spacelift.io/blog/docker-multistage-builds)
- [Building Optimized Docker Images](https://developers-heaven.net/blog/building-optimized-docker-images-dockerfile-best-practices-multi-stage-builds/)
