# Container Security Checklist

A comprehensive security checklist for Dockerfiles and container images.

## Build-Time Security

### Base Image Security

- [ ] Use official or verified base images
- [ ] Pin base image to specific tag (not :latest)
- [ ] Consider digest pinning for critical applications
- [ ] Prefer minimal base images (Alpine, distroless, scratch)
- [ ] Scan base images for known vulnerabilities
- [ ] Keep base images updated regularly

### Secrets Management

- [ ] Never hardcode secrets in Dockerfile
- [ ] Don't use ENV or ARG for sensitive data
- [ ] Use Docker build secrets (--secret flag)
- [ ] Use runtime configuration for secrets
- [ ] Scan for accidentally committed secrets
- [ ] Use .dockerignore to exclude secret files

### Package Management

- [ ] Pin package versions for reproducibility
- [ ] Only install necessary packages (--no-install-recommends)
- [ ] Clean package manager cache in same layer
- [ ] Verify package signatures when possible
- [ ] Use official package repositories
- [ ] Audit dependencies for known vulnerabilities

### User and Permissions

- [ ] Create and use non-root user
- [ ] Set USER directive before CMD/ENTRYPOINT
- [ ] Use high UID (>10000) for better isolation
- [ ] Set proper file ownership with COPY --chown
- [ ] Don't use sudo in containers
- [ ] Avoid privileged operations

### Layer and File Security

- [ ] Use .dockerignore to exclude sensitive files
- [ ] Don't copy unnecessary files (use specific COPY)
- [ ] Remove secrets after use in same layer
- [ ] Don't log sensitive information
- [ ] Minimize number of layers
- [ ] Use multi-stage builds to exclude build secrets

## Common Vulnerabilities

### SSH/Remote Access

- [ ] Don't install or expose SSH (port 22)
- [ ] Don't install telnet, FTP, or other insecure protocols
- [ ] Use `docker exec` for debugging instead of SSH
- [ ] Don't run sshd in containers

### Network Exposure

- [ ] Only EXPOSE necessary ports
- [ ] Don't bind to 0.0.0.0 in development images
- [ ] Use internal networks for inter-container communication
- [ ] Implement proper firewall rules
- [ ] Use TLS for network communications

### File System Security

- [ ] Consider read-only root filesystem
- [ ] Use tmpfs for temporary files
- [ ] Set proper file permissions
- [ ] Don't store secrets in environment variables
- [ ] Use volume mounts for sensitive data

## Runtime Security

### Container Configuration

- [ ] Run with --read-only flag when possible
- [ ] Drop unnecessary capabilities (--cap-drop)
- [ ] Use security profiles (AppArmor, SELinux)
- [ ] Set resource limits (CPU, memory)
- [ ] Use user namespaces
- [ ] Enable content trust (DOCKER_CONTENT_TRUST)

### Health and Monitoring

- [ ] Implement HEALTHCHECK in Dockerfile
- [ ] Monitor container logs
- [ ] Set up security scanning in CI/CD
- [ ] Use runtime security tools
- [ ] Monitor for anomalous behavior
- [ ] Implement proper logging without secrets

### Network Security

- [ ] Use custom bridge networks
- [ ] Implement network segmentation
- [ ] Use encrypted overlays for swarm
- [ ] Configure DNS properly
- [ ] Use service mesh for microservices
- [ ] Implement network policies

## Image Registry Security

### Registry Configuration

- [ ] Use private registries for internal images
- [ ] Enable image scanning in registry
- [ ] Implement access controls
- [ ] Use image signing (Docker Content Trust)
- [ ] Scan for vulnerabilities before pull
- [ ] Regularly update registry software

### Image Distribution

- [ ] Sign images before distribution
- [ ] Verify image signatures on pull
- [ ] Use TLS for registry communication
- [ ] Implement role-based access control
- [ ] Audit image pull/push events
- [ ] Use image provenance metadata

## Security Scanning Tools

### Static Analysis
- **hadolint** - Dockerfile linting
- **Checkov** - Policy-as-code scanning
- **dockerfilelint** - Best practices checker

### Vulnerability Scanning
- **Trivy** - Comprehensive vulnerability scanner
- **Snyk** - Dependency vulnerability scanner
- **Clair** - Container vulnerability analysis
- **Anchore** - Deep image inspection

### Runtime Security
- **Falco** - Runtime threat detection
- **Aqua Security** - Container security platform
- **Sysdig** - Container monitoring and security

## Compliance and Standards

### Industry Standards

- [ ] Follow CIS Docker Benchmark
- [ ] Comply with NIST guidelines
- [ ] Adhere to OWASP Container Security
- [ ] Meet PCI DSS requirements (if applicable)
- [ ] Follow SOC 2 controls (if applicable)

### Security Policies

- [ ] Document security requirements
- [ ] Implement security review process
- [ ] Define incident response procedures
- [ ] Regular security audits
- [ ] Security training for developers
- [ ] Maintain security documentation

## Quick Security Wins

### Easy Fixes

1. **Use specific base image tags**
   ```dockerfile
   FROM alpine:3.21  # Not alpine:latest
   ```

2. **Run as non-root**
   ```dockerfile
   USER appuser
   ```

3. **Clean package cache**
   ```dockerfile
   RUN apk add --no-cache package
   ```

4. **Don't expose unnecessary ports**
   ```dockerfile
   # Only expose what's needed
   EXPOSE 8080
   ```

5. **Add health checks**
   ```dockerfile
   HEALTHCHECK CMD curl -f http://localhost/ || exit 1
   ```

## Security Checklist Summary

| Category | Critical | High | Medium |
|----------|----------|------|--------|
| Base Image | Use official, pin version | Scan for CVEs | Update regularly |
| Secrets | Never in code | Use secrets mgmt | Scan commits |
| Users | Run as non-root | High UID | Proper permissions |
| Network | TLS only | Minimal exposure | Firewall rules |
| Runtime | Drop capabilities | Read-only FS | Resource limits |

## Resources

- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [OWASP Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [NIST Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [Docker Security Best Practices](https://docs.docker.com/develop/security-best-practices/)