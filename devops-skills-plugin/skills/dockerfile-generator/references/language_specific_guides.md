# Language-Specific Dockerfile Guides

## Overview

This guide provides best practices and optimized Dockerfile templates for popular programming languages and frameworks.

## Node.js

### Basic Node.js Application

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS base
WORKDIR /app

# Dependencies stage
FROM base AS deps
COPY package.json package-lock.json ./
RUN npm ci --only=production && npm cache clean --force

# Production stage
FROM base AS production
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs
EXPOSE 3000
HEALTHCHECK CMD node -e "require('http').get('http://localhost:3000/health',(r)=>{process.exit(r.statusCode===200?0:1)})"
CMD ["node", "server.js"]
```

### Next.js Application

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

FROM node:20-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs
COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./package.json
USER nextjs
EXPOSE 3000
CMD ["npm", "start"]
```

### Express.js API

```dockerfile
# syntax=docker/dockerfile:1
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD node -e "require('http').get('http://localhost:3000/health',(r)=>{process.exit(r.statusCode===200?0:1)})"
CMD ["node", "server.js"]
```

**Best Practices:**
- Use `npm ci` instead of `npm install` for deterministic builds
- Always use `package-lock.json` for version locking
- Run `npm cache clean --force` after install
- Use `--only=production` to exclude dev dependencies
- Set `NODE_ENV=production`

## Python

### Basic Python Application

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
CMD ["python", "app.py"]
```

### FastAPI Application

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
HEALTHCHECK CMD python -c "import urllib.request;urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Django Application

```dockerfile
# syntax=docker/dockerfile:1
FROM python:3.12-slim AS builder
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc postgresql-client libpq-dev && \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip wheel --no-cache-dir --no-deps --wheel-dir /wheels -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends \
    postgresql-client libpq-dev && \
    rm -rf /var/lib/apt/lists/*
COPY --from=builder /wheels /wheels
RUN pip install --no-cache /wheels/* && rm -rf /wheels
RUN useradd -m -u 1001 appuser
COPY --chown=appuser:appuser . .
RUN python manage.py collectstatic --noinput
USER appuser
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "project.wsgi:application"]
```

**Best Practices:**
- Use `pip install --no-cache-dir` to reduce image size
- Install build dependencies in builder stage only
- Use wheels for compiled dependencies
- Set `PYTHONUNBUFFERED=1` for real-time logs
- Use `--user` flag for pip install (non-root)

## Go

### Basic Go Application

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o main .

FROM alpine:3.21
RUN apk --no-cache add ca-certificates
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
COPY --from=builder /app/main .
USER appuser
EXPOSE 8080
HEALTHCHECK CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["./main"]
```

### Go with Distroless (Minimal)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o /main .

FROM gcr.io/distroless/static-debian12
COPY --from=builder /main /main
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/main"]
```

### Go with Scratch (Absolute Minimal)

```dockerfile
# syntax=docker/dockerfile:1
FROM golang:1.21-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o /main .

FROM scratch
COPY --from=builder /main /main
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
USER 1001:1001
ENTRYPOINT ["/main"]
```

**Best Practices:**
- Use `CGO_ENABLED=0` for static binaries
- Use `-ldflags="-s -w"` to strip debug symbols
- Use scratch or distroless for minimal images
- Include ca-certificates if making HTTPS requests
- Use go modules (go.mod) for dependency management

## Java

### Spring Boot with Maven

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw clean package -DskipTests && mv target/*.jar target/app.jar

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN useradd -m -u 1001 appuser
COPY --from=builder --chown=appuser:appuser /app/target/app.jar ./app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Spring Boot with Gradle

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /app
COPY gradlew ./
COPY gradle gradle
COPY build.gradle settings.gradle ./
RUN ./gradlew dependencies --no-daemon
COPY src ./src
RUN ./gradlew build -x test --no-daemon && \
    mv build/libs/*.jar build/libs/app.jar

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN useradd -m -u 1001 appuser
COPY --from=builder --chown=appuser:appuser /app/build/libs/app.jar ./app.jar
USER appuser
EXPOSE 8080
HEALTHCHECK CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### Spring Boot Layered (Optimized)

```dockerfile
# syntax=docker/dockerfile:1
FROM eclipse-temurin:21-jdk-jammy AS builder
WORKDIR /app
COPY mvnw pom.xml ./
COPY .mvn .mvn
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw clean package -DskipTests
RUN java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
RUN useradd -m -u 1001 appuser
USER appuser
COPY --from=builder /app/target/extracted/dependencies/ ./
COPY --from=builder /app/target/extracted/spring-boot-loader/ ./
COPY --from=builder /app/target/extracted/snapshot-dependencies/ ./
COPY --from=builder /app/target/extracted/application/ ./
EXPOSE 8080
HEALTHCHECK CMD curl -f http://localhost:8080/actuator/health || exit 1
ENTRYPOINT ["java", "org.springframework.boot.loader.launch.JarLauncher"]
```

**Best Practices:**
- Use JRE instead of JDK for runtime (smaller)
- Use layered JARs for better caching
- Run `./mvnw dependency:go-offline` to cache dependencies
- Use `--no-daemon` with Gradle to avoid background processes
- Set appropriate Java heap size with `-Xmx` and `-Xms`

## Rust

### Rust Application

```dockerfile
# syntax=docker/dockerfile:1
FROM rust:1.75-alpine AS builder
WORKDIR /app
RUN apk add --no-cache musl-dev
COPY Cargo.toml Cargo.lock ./
# Cache dependencies
RUN mkdir src && echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src
COPY src ./src
RUN touch src/main.rs && cargo build --release

FROM alpine:3.21
RUN apk --no-cache add ca-certificates
WORKDIR /app
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
COPY --from=builder /app/target/release/app ./
USER appuser
EXPOSE 8080
CMD ["./app"]
```

## Ruby

### Ruby on Rails

```dockerfile
# syntax=docker/dockerfile:1
FROM ruby:3.3-alpine AS builder
WORKDIR /app
RUN apk add --no-cache build-base postgresql-dev nodejs yarn
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test
COPY package.json yarn.lock ./
RUN yarn install --production
COPY . .
RUN bundle exec rake assets:precompile

FROM ruby:3.3-alpine
WORKDIR /app
RUN apk add --no-cache postgresql-client nodejs
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup
COPY --from=builder /usr/local/bundle /usr/local/bundle
COPY --from=builder --chown=appuser:appgroup /app ./
USER appuser
EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

## PHP

### PHP with Laravel

```dockerfile
# syntax=docker/dockerfile:1
FROM composer:2 AS composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

FROM php:8.3-fpm-alpine
WORKDIR /app
RUN apk add --no-cache postgresql-dev && \
    docker-php-ext-install pdo pdo_pgsql
COPY --from=composer /app/vendor ./vendor
COPY . .
RUN composer dump-autoload --optimize --classmap-authoritative
RUN addgroup -g 1001 -S appgroup && adduser -S appuser -u 1001 -G appgroup && \
    chown -R appuser:appgroup /app
USER appuser
EXPOSE 9000
CMD ["php-fpm"]
```

## .NET

### ASP.NET Core

```dockerfile
# syntax=docker/dockerfile:1
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS builder
WORKDIR /app
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o out

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
RUN useradd -m -u 1001 appuser
COPY --from=builder --chown=appuser:appuser /app/out ./
USER appuser
EXPOSE 8080
HEALTHCHECK CMD curl -f http://localhost:8080/health || exit 1
ENTRYPOINT ["dotnet", "MyApp.dll"]
```

## Common Patterns Across Languages

### Development vs Production

```dockerfile
# syntax=docker/dockerfile:1
ARG NODE_ENV=production

FROM node:20-alpine AS development
ENV NODE_ENV=development
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["npm", "run", "dev"]

FROM node:20-alpine AS production
ENV NODE_ENV=production
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER nodejs
CMD ["node", "server.js"]

FROM ${NODE_ENV} AS final
```

### With Database Migrations

```dockerfile
# Add entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["python", "app.py"]
```

**docker-entrypoint.sh:**
```bash
#!/bin/sh
set -e

# Run migrations
python manage.py migrate

# Start application
exec "$@"
```

## Framework-Specific Tips

### Next.js
- Use standalone output mode for smaller images
- Set `NEXT_TELEMETRY_DISABLED=1`
- Copy only `.next/standalone` and `.next/static`

### Django
- Run `collectstatic` during build
- Use gunicorn or uvicorn for production
- Include database client libraries

### Spring Boot
- Use layered JARs for better caching
- Include actuator for health checks
- Set appropriate JVM memory limits

### FastAPI
- Use uvicorn with workers for production
- Include health check endpoint
- Use `--proxy-headers` if behind proxy

## References

- [Official Docker Samples](https://github.com/docker/awesome-compose)
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md)
- [Python Docker Best Practices](https://docs.python-guide.org/shipping/docker/)
- [Go Docker Best Practices](https://docs.docker.com/language/golang/build-images/)