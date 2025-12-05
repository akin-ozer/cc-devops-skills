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

# Health check (Spring Boot Actuator)
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Start application
ENTRYPOINT ["java", "-jar", "app.jar"]