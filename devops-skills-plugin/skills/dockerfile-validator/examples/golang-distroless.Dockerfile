# syntax=docker/dockerfile:1

# Multi-stage Go Dockerfile with distroless runtime
# Demonstrates minimal attack surface and optimal size

# Build stage
FROM golang:1.21-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates

WORKDIR /src

# Copy go mod files for dependency caching
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags='-w -s -extldflags "-static"' \
    -a \
    -o /app/server \
    ./cmd/server

# Runtime stage - distroless (minimal, secure)
FROM gcr.io/distroless/static-debian11:nonroot

# Copy CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary from builder
COPY --from=builder /app/server /server

# Expose port
EXPOSE 8080

# Already running as non-root (distroless:nonroot)
# User is automatically set to uid:gid 65532:65532

# Health check (limited in distroless, use external checks)
# HEALTHCHECK not available in distroless

# Exec form entrypoint
ENTRYPOINT ["/server"]
