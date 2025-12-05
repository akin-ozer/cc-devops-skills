# Dockerfile with Intentional Security Issues
# FOR TESTING VALIDATION ONLY - DO NOT USE IN PRODUCTION

# Issue: Using :latest tag
FROM python:latest

# Issue: Running as root user throughout

WORKDIR /app

# Issue: Hardcoded secrets
ENV DATABASE_PASSWORD=super_secret_password
ENV API_TOKEN=abc123xyz789
ARG SECRET_KEY=my_secret_key

# Issue: Installing unnecessary packages, no version pinning
RUN apt-get update && apt-get install -y \
    openssh-server \
    telnet \
    ftp \
    vim \
    nano

# Issue: No cache cleanup
# (apt lists remain, increasing image size)

# Issue: Using ADD instead of COPY
ADD . /app

# Issue: Installing packages without version pins
RUN pip install flask requests sqlalchemy

# Issue: Exposing SSH port
EXPOSE 22
EXPOSE 23
EXPOSE 5000

# Issue: No USER directive - will run as root
# Issue: No HEALTHCHECK

# Issue: Shell form (doesn't handle signals properly)
CMD python app.py