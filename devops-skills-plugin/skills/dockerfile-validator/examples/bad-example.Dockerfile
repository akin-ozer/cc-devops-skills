# Bad Example - Demonstrates common mistakes and anti-patterns
# DO NOT USE THIS IN PRODUCTION

# Issue 1: Using :latest tag (unpredictable, not reproducible)
FROM ubuntu:latest

# Issue 2: Running as root (security risk)
# Issue 3: No WORKDIR set (unclear where commands run)

# Issue 4: Separate RUN commands (creates unnecessary layers)
RUN apt-get update
RUN apt-get install -y curl
RUN apt-get install -y vim
RUN apt-get install -y git
# Issue 5: No cache cleanup (increases image size)

# Issue 6: Using shell form instead of exec form
WORKDIR app

# Issue 7: Copying everything before installing dependencies (poor caching)
COPY . .

# Issue 8: No version pinning for packages
RUN pip install flask

# Issue 9: Potential secret exposure
ENV API_KEY=secret123
ENV PASSWORD=admin

# Issue 10: Exposing SSH port (security risk)
EXPOSE 22
EXPOSE 80

# Issue 11: No HEALTHCHECK defined
# Issue 12: No USER directive (runs as root)
# Issue 13: Shell form instead of exec form (poor signal handling)
CMD python app.py