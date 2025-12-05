# syntax=docker/dockerfile:1

# Build stage
FROM golang:1.21-alpine AS builder
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the application with optimizations
RUN CGO_ENABLED=0 GOOS=linux go build -a -ldflags="-s -w" -o /app/main .

# Production stage (using distroless for minimal image)
FROM gcr.io/distroless/static-debian12 AS production
WORKDIR /

# Copy binary from builder
COPY --from=builder /app/main /main

# Expose port
EXPOSE 8080

# Switch to non-root user (distroless runs as nonroot by default)
USER nonroot:nonroot

# Start application
ENTRYPOINT ["/main"]