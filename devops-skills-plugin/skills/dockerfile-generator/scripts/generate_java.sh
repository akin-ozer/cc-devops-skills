#!/usr/bin/env bash
# Generate a production-ready Java Dockerfile with multi-stage build

set -euo pipefail

# Default values
JAVA_VERSION="${JAVA_VERSION:-21}"
PORT="${PORT:-8080}"
OUTPUT_FILE="${OUTPUT_FILE:-Dockerfile}"
BUILD_TOOL="${BUILD_TOOL:-maven}"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate a production-ready Java Dockerfile with multi-stage build.

OPTIONS:
    -v, --version VERSION     Java version (default: 21)
    -p, --port PORT          Port to expose (default: 8080)
    -o, --output FILE        Output file (default: Dockerfile)
    -t, --tool TOOL          Build tool: maven or gradle (default: maven)
    -h, --help               Show this help message

EXAMPLES:
    # Spring Boot with Maven
    $0

    # Spring Boot with Gradle
    $0 --tool gradle --version 21

    # Custom port
    $0 --port 9090 --tool maven

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            JAVA_VERSION="$2"
            shift 2
            ;;
        -p|--port)
            PORT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -t|--tool)
            BUILD_TOOL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate build tool
if [ "$BUILD_TOOL" != "maven" ] && [ "$BUILD_TOOL" != "gradle" ]; then
    echo "Error: Build tool must be 'maven' or 'gradle'"
    exit 1
fi

# Generate Dockerfile based on build tool
if [ "$BUILD_TOOL" = "maven" ]; then
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM eclipse-temurin:JAVA_VERSION-jdk-jammy AS builder
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
FROM eclipse-temurin:JAVA_VERSION-jre-jammy AS production
WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy JAR from builder
COPY --from=builder --chown=appuser:appuser /app/target/app.jar ./app.jar

# Switch to non-root user
USER appuser

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:PORT_NUMBER/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
else
    cat > "$OUTPUT_FILE" <<'EOF'
# syntax=docker/dockerfile:1

# Build stage
FROM eclipse-temurin:JAVA_VERSION-jdk-jammy AS builder
WORKDIR /app

# Copy Gradle wrapper and build files
COPY gradlew ./
COPY gradle gradle
COPY build.gradle settings.gradle ./

# Download dependencies (cached layer)
RUN ./gradlew dependencies --no-daemon

# Copy source code
COPY src ./src

# Build application
RUN ./gradlew build -x test --no-daemon && \
    mv build/libs/*.jar build/libs/app.jar

# Production stage (using JRE instead of JDK)
FROM eclipse-temurin:JAVA_VERSION-jre-jammy AS production
WORKDIR /app

# Create non-root user
RUN useradd -m -u 1001 appuser

# Copy JAR from builder
COPY --from=builder --chown=appuser:appuser /app/build/libs/app.jar ./app.jar

# Switch to non-root user
USER appuser

# Expose port
EXPOSE PORT_NUMBER

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:PORT_NUMBER/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF
fi

# Replace placeholders
sed -i.bak "s/JAVA_VERSION/$JAVA_VERSION/g" "$OUTPUT_FILE"
sed -i.bak "s/PORT_NUMBER/$PORT/g" "$OUTPUT_FILE"

# Clean up backup files
rm -f "${OUTPUT_FILE}.bak"

echo "✓ Generated Java Dockerfile: $OUTPUT_FILE"
echo "  Java version: $JAVA_VERSION"
echo "  Port: $PORT"
echo "  Build tool: $BUILD_TOOL"
