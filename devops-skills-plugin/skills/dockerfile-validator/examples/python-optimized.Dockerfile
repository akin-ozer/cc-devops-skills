# syntax=docker/dockerfile:1

# Multi-stage Python Dockerfile with best practices
# Optimized for size and security

# Build stage
FROM python:3.12-slim AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for layer caching
COPY requirements.txt ./

# Install Python dependencies with cache mount
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --user --no-cache-dir -r requirements.txt

# Runtime stage - minimal
FROM python:3.12-slim AS runtime

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local

# Copy application code
COPY --chown=appuser:appuser . .

# Add local bin to PATH
ENV PATH=/root/.local/bin:$PATH

# Switch to non-root user
USER appuser

# Expose application port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s \
    CMD python -c "import requests; requests.get('http://localhost:8000/health')" || exit 1

# Use exec form
ENTRYPOINT ["python"]
CMD ["-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
