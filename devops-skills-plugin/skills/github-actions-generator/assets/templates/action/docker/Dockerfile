# Base image
FROM [BASE_IMAGE]:[TAG]

# Install required tools
RUN [PACKAGE_MANAGER] update && \
    [PACKAGE_MANAGER] install -y \
    [PACKAGE_1] \
    [PACKAGE_2] \
    && [CLEANUP_COMMAND]

# Set working directory
WORKDIR /app

# Copy application files
COPY entrypoint.sh /entrypoint.sh

# Make entrypoint executable
RUN chmod +x /entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]
