# Multi-Stage Docker Builds

## Overview

Multi-stage builds allow you to use multiple FROM statements in your Dockerfile. Each FROM instruction can use a different base, and each begins a new stage of the build. You can selectively copy artifacts from one stage to another, leaving behind everything you don't want in the final image.

**Benefits:**
- **Smaller images:** 50-85% size reduction
- **Separation of concerns:** Build vs runtime environments
- **Better security:** No build tools in production images
- **Faster deployments:** Smaller images transfer faster
- **Cleaner builds:** No manual cleanup scripts needed

## Basic Syntax

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Named "builder"
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY . .
RUN go build -o myapp

# Stage 2: Final production image
FROM alpine:3.21
COPY --from=builder /app/myapp /usr/local/bin/
CMD ["myapp"]
```

## Stage Naming

### Explicit Names (Recommended)

```dockerfile
# Name stages explicitly for clarity
FROM node:20 AS dependencies
RUN npm install

FROM node:20 AS builder
COPY --from=dependencies /app/node_modules ./node_modules
RUN npm run build

FROM node:20-alpine AS production
COPY --from=builder /app/dist ./dist
```

### Numeric References (Less Clear)

```dockerfile
# Reference previous stages by number (0-indexed)
FROM node:20
RUN npm install

FROM node:20
COPY --from=0 /app/node_modules ./node_modules
RUN npm run build

FROM node:20-alpine
COPY --from=1 /app/dist ./dist
```

## Common Patterns

### Pattern 1: Build and Runtime Separation

**Use Case:** Compiled languages (Go, Rust, C++, Java)

```dockerfile
# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o main .

# Runtime stage
FROM scratch
COPY --from=builder /app/main /main
ENTRYPOINT ["/main"]
```

**Size Impact:**
- Builder stage: ~300MB
- Final image: ~8MB
- **Reduction: 97%**

### Pattern 2: Dependency Installation

**Use Case:** Separate dependency installation from application code

```dockerfile
# Dependency stage
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# Build stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS runner
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=deps /app/node_modules ./node_modules
CMD ["node", "dist/index.js"]
```

**Benefits:**
- Cached dependency layer (only rebuilds when package.json changes)
- Production dependencies only in final image
- Faster builds with layer caching

### Pattern 3: Test Stage

**Use Case:** Run tests without including test dependencies in final image

```dockerfile
# Dependency stage
FROM python:3.12-slim AS deps
WORKDIR /app
COPY requirements.txt requirements-dev.txt ./
RUN pip install --user -r requirements.txt

# Test stage
FROM deps AS test
RUN pip install --user -r requirements-dev.txt
COPY . .
RUN pytest tests/

# Production stage
FROM python:3.12-slim AS production
WORKDIR /app
COPY --from=deps /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]
```

**Build with tests:**
```bash
docker build --target test -t myapp:test .
```

**Build production (tests automatically run before this stage):**
```bash
docker build -t myapp:latest .
```

### Pattern 4: Multi-Architecture

**Use Case:** Build for different platforms

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.21-alpine AS builder
ARG TARGETARCH
ARG TARGETOS
WORKDIR /app
COPY . .
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o app

FROM alpine:3.21
COPY --from=builder /app/app /app
ENTRYPOINT ["/app"]
```

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t myapp:latest .
```

### Pattern 5: Development vs Production

**Use Case:** Different images for dev and prod

```dockerfile
# Base stage with common dependencies
FROM node:20-alpine AS base
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Development stage
FROM base AS development
ENV NODE_ENV=development
COPY . .
CMD ["npm", "run", "dev"]

# Build stage
FROM base AS builder
COPY . .
RUN npm run build

# Production stage
FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
CMD ["node", "dist/server.js"]
```

**Build for development:**
```bash
docker build --target development -t myapp:dev .
```

**Build for production:**
```bash
docker build --target production -t myapp:prod .
```

## Language-Specific Examples

### Node.js (Next.js)

```dockerfile
# syntax=docker/dockerfile:1

# Dependencies stage
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

# Builder stage
FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Runner stage
FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/public ./public
USER nextjs
EXPOSE 3000
CMD ["npm", "start"]
```

### Python (Django/FastAPI)

```dockerfile
# syntax=docker/dockerfile:1

# Builder stage
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    postgresql-dev \
    && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /app/wheels -r requirements.txt

# Runner stage
FROM python:3.12-slim AS runner
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/wheels /wheels
RUN pip install --no-cache /wheels/*
COPY . .
RUN useradd -m -u 1001 appuser
USER appuser
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
```

### Go (Minimal)

```dockerfile
# syntax=docker/dockerfile:1

# Builder stage
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -ldflags="-s -w" -o main .

# Runner stage (scratch = 0 bytes base)
FROM scratch
COPY --from=builder /app/main /main
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 1001:1001
ENTRYPOINT ["/main"]
```

### Java (Spring Boot)

```dockerfile
# syntax=docker/dockerfile:1

# Dependencies stage
FROM eclipse-temurin:21-jdk-jammy AS deps
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline

# Builder stage
FROM deps AS builder
COPY src ./src
RUN ./mvnw clean package -DskipTests

# Extractor stage (for layered JAR)
FROM builder AS extractor
WORKDIR /app
RUN java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# Runner stage
FROM eclipse-temurin:21-jre-jammy AS runner
WORKDIR /app
RUN useradd -m -u 1001 appuser
USER appuser
COPY --from=extractor /app/target/extracted/dependencies/ ./
COPY --from=extractor /app/target/extracted/spring-boot-loader/ ./
COPY --from=extractor /app/target/extracted/snapshot-dependencies/ ./
COPY --from=extractor /app/target/extracted/application/ ./
EXPOSE 8080
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

## Advanced Techniques

### Copying from External Images

```dockerfile
# Copy from official images
FROM alpine:3.21 AS production
COPY --from=nginx:alpine /usr/share/nginx/html /usr/share/nginx/html
COPY --from=myregistry/common:latest /app/lib /app/lib
```

### Conditional Stages (BuildKit)

```dockerfile
# syntax=docker/dockerfile:1
ARG BUILD_ENV=production

FROM node:20 AS development
ENV NODE_ENV=development
CMD ["npm", "run", "dev"]

FROM node:20-alpine AS production
ENV NODE_ENV=production
CMD ["node", "dist/server.js"]

FROM ${BUILD_ENV} AS final
```

```bash
docker build --build-arg BUILD_ENV=development -t myapp:dev .
docker build --build-arg BUILD_ENV=production -t myapp:prod .
```

### Parallel Stages

```dockerfile
# syntax=docker/dockerfile:1

# Independent stages run in parallel
FROM alpine AS fetch-config
RUN wget https://example.com/config.json -O /config.json

FROM alpine AS fetch-data
RUN wget https://example.com/data.csv -O /data.csv

# Final stage waits for both
FROM alpine AS final
COPY --from=fetch-config /config.json /app/
COPY --from=fetch-data /data.csv /app/
```

## Build Optimization

### Target Specific Stage

```bash
# Build only up to specific stage
docker build --target builder -t myapp:builder .

# Useful for debugging
docker run -it myapp:builder /bin/sh
```

### Cache Mounts with Multi-Stage

```dockerfile
# syntax=docker/dockerfile:1

FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod \
    go mod download
COPY . .
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o app

FROM alpine:3.21
COPY --from=builder /app/app /app
CMD ["/app"]
```

## Best Practices

### 1. Order Stages Logically

```dockerfile
# dependencies → builder → test → production
FROM node:20 AS deps
# Install dependencies

FROM deps AS builder
# Build application

FROM builder AS test
# Run tests

FROM node:20-alpine AS production
# Minimal runtime
```

### 2. Name Stages Clearly

```dockerfile
# Good
FROM golang:1.21 AS compiler
FROM alpine:3.21 AS runtime

# Bad
FROM golang:1.21 AS stage1
FROM alpine:3.21 AS stage2
```

### 3. Minimize Final Stage

```dockerfile
# Copy only what's needed
COPY --from=builder /app/binary /app/binary

# Don't copy unnecessary files
# Bad: COPY --from=builder /app /app
```

### 4. Use Specific Base Images per Stage

```dockerfile
# JDK for building
FROM eclipse-temurin:21-jdk-jammy AS builder

# JRE for running (smaller)
FROM eclipse-temurin:21-jre-jammy AS runner
```

### 5. Document Stages

```dockerfile
# syntax=docker/dockerfile:1

# Stage 1: Install and cache dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci

# Stage 2: Build application with dependencies
FROM deps AS builder
COPY . .
RUN npm run build

# Stage 3: Production runtime with minimal footprint
FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
COPY --from=builder /app/dist ./dist
CMD ["node", "dist/server.js"]
```

## Common Pitfalls

### 1. Not Using Stage Names

```dockerfile
# Hard to maintain
FROM node:20
COPY --from=0 /app/node_modules ./node_modules

# Better
FROM node:20 AS deps
COPY --from=deps /app/node_modules ./node_modules
```

### 2. Copying Entire Stage

```dockerfile
# Bad - copies everything including build tools
COPY --from=builder /app /app

# Good - copy only artifacts
COPY --from=builder /app/dist /app/dist
```

### 3. Not Leveraging Cache

```dockerfile
# Bad - copy all before installing
COPY . .
RUN npm install

# Good - install dependencies first (cached)
COPY package*.json ./
RUN npm install
COPY . .
```

## Troubleshooting

### Check Stage Sizes

```bash
# Build with specific target
docker build --target builder -t myapp:builder .
docker build --target production -t myapp:production .

# Compare sizes
docker images | grep myapp
```

### Debug Intermediate Stages

```bash
# Build up to specific stage
docker build --target builder -t debug:builder .

# Run and inspect
docker run -it debug:builder /bin/sh
```

### View Build Process

```bash
# Enable BuildKit with progress
DOCKER_BUILDKIT=1 docker build --progress=plain .

# See all stages and their timing
```

## References

- [Docker Multi-stage Builds Documentation](https://docs.docker.com/build/building/multi-stage/)
- [Multi-stage Build Examples](https://docs.docker.com/get-started/docker-concepts/building-images/multi-stage-builds/)
- [BuildKit Features](https://docs.docker.com/build/buildkit/)