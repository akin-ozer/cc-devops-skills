# Base image
FROM [BASE_IMAGE]:[TAG]

# Install required tools with minimal packages, then clean package caches
RUN [PACKAGE_MANAGER] update && \
    [PACKAGE_MANAGER] install -y --no-install-recommends \
    [PACKAGE_1] \
    [PACKAGE_2] \
    && [CLEANUP_COMMAND]

# Set working directory
WORKDIR /app

# Copy application files
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Create and switch to a non-root runtime user (replace placeholders per base image)
RUN [CREATE_NON_ROOT_USER_COMMAND]
USER [RUNTIME_USER]

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
