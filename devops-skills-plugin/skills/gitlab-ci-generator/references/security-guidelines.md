# GitLab CI/CD Security Guidelines

Comprehensive security guidelines for creating secure GitLab CI/CD pipelines. Follow these practices to protect your code, credentials, and infrastructure.

## Table of Contents

1. [Secrets Management](#secrets-management)
2. [Image Security](#image-security)
3. [Script Security](#script-security)
4. [Artifact Security](#artifact-security)
5. [Network Security](#network-security)
6. [Access Control](#access-control)
7. [Supply Chain Security](#supply-chain-security)
8. [Compliance and Auditing](#compliance-and-auditing)

---

## Secrets Management

### 1. Never Hardcode Secrets

**❌ BAD:**
```yaml
deploy:
  script:
    - deploy --api-key sk_live_abc123xyz
    - mysql -u admin -ppassword123 -h db.example.com
```

**✅ GOOD:**
```yaml
deploy:
  script:
    - deploy --api-key $API_KEY
    - mysql -u $DB_USER -p$DB_PASSWORD -h $DB_HOST
```

### 2. Use Masked and Protected Variables

**Settings for sensitive variables:**
- ✅ **Masked** - Hides value in job logs
- ✅ **Protected** - Only available in protected branches/tags
- ✅ **Expanded** - Controls variable expansion

**Example configuration in GitLab UI:**
```
Settings → CI/CD → Variables
Key: API_KEY
Value: sk_live_abc123xyz
Flags: [x] Mask variable
       [x] Protect variable
       [ ] Expand variable reference (disable for JSON/special chars)
```

### 3. Scope Variables Appropriately

```yaml
# Environment-specific variables
deploy-staging:
  environment:
    name: staging
  variables:
    API_ENDPOINT: https://api-staging.example.com
  script:
    - deploy --endpoint $API_ENDPOINT

deploy-production:
  environment:
    name: production
  variables:
    API_ENDPOINT: https://api.example.com
  script:
    - deploy --endpoint $API_ENDPOINT
```

### 4. Use GitLab Secrets Management

```yaml
deploy:
  secrets:
    DATABASE_PASSWORD:
      vault: production/db/password@secret
      token: $VAULT_TOKEN
  script:
    - deploy --db-password $DATABASE_PASSWORD
```

### 5. Rotate Secrets Regularly

- Set expiration for tokens and credentials
- Implement automated rotation where possible
- Remove unused credentials immediately
- Audit secret usage regularly

### 6. Avoid Secrets in Artifacts

```yaml
build:
  script:
    - make build
  artifacts:
    paths:
      - dist/
    exclude:
      - "**/*.env"
      - "**/*.pem"
      - "**/*.key"
      - "**/credentials.*"
      - "**/.env.*"
      - "**/config.production.*"
```

---

## Image Security

### 1. Pin Images to Specific Versions

**❌ BAD:**
```yaml
test:
  image: node:latest  # Unpredictable, security risk
```

**✅ GOOD:**
```yaml
test:
  image: node:20.11-alpine3.19  # Pinned version
```

**Best practice:**
- Use specific major.minor.patch versions
- Consider using SHA256 digests for maximum security
- Document why specific versions are chosen

### 2. Use Official and Trusted Images

```yaml
# ✅ GOOD: Official images
build:
  image: node:20-alpine  # Official Node.js image

test:
  image: postgres:15-alpine  # Official PostgreSQL image

# ⚠️ CAUTION: Third-party images (verify trust)
scan:
  image: aquasec/trivy:0.49.0  # Verify publisher reputation
```

### 3. Scan Images for Vulnerabilities

```yaml
stages:
  - build
  - scan

build-image:
  stage: build
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA .

scan-image:
  stage: scan
  image: aquasec/trivy:latest
  script:
    - trivy image --severity HIGH,CRITICAL --exit-code 1 $CI_REGISTRY_IMAGE:$CI_COMMIT_SHORT_SHA
  needs: [build-image]
  allow_failure: false  # Fail pipeline on vulnerabilities
```

### 4. Use Minimal Base Images

```dockerfile
# ✅ GOOD: Alpine-based images (smaller attack surface)
FROM node:20-alpine

# ⚠️ LARGER: Full images have more packages
FROM node:20-bookworm
```

### 5. Don't Run Containers as Root

```dockerfile
# Dockerfile best practice
FROM node:20-alpine

# Create non-root user
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# Change ownership
COPY --chown=nodejs:nodejs . .

# Switch to non-root user
USER nodejs

CMD ["node", "server.js"]
```

---

## Script Security

### 1. Avoid Dangerous Script Patterns

**❌ DANGEROUS PATTERNS:**

```yaml
# Piping to bash
install:
  script:
    - curl https://install.sh | bash  # ❌ Dangerous

# Using eval
deploy:
  script:
    - eval "$COMMAND"  # ❌ Code injection risk

# Overly permissive permissions
setup:
  script:
    - chmod 777 /app  # ❌ Security risk
```

**✅ SECURE PATTERNS:**

```yaml
# Download and verify before execution
install:
  script:
    - curl -o install.sh https://install.sh
    - sha256sum -c install.sh.sha256  # Verify integrity
    - bash install.sh

# Avoid eval, use explicit commands
deploy:
  script:
    - ./deploy.sh $ENVIRONMENT

# Minimal permissions
setup:
  script:
    - chmod 755 /app
    - chmod 600 /app/config.yml
```

### 2. Validate and Sanitize Inputs

```yaml
deploy:
  script:
    - |
      # Validate branch name
      if [[ ! "$CI_COMMIT_BRANCH" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Invalid branch name"
        exit 1
      fi

      # Validate version format
      if [[ ! "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Invalid version format"
        exit 1
      fi

      ./deploy.sh "$CI_COMMIT_BRANCH" "$VERSION"
```

### 3. Use `set -e` for Error Handling

```yaml
deploy:
  script:
    - |
      set -e  # Exit on first error
      set -o pipefail  # Exit on pipe failures

      echo "Starting deployment"
      ./build.sh
      ./test.sh
      ./deploy.sh
```

### 4. Avoid Exposing Secrets in Logs

```yaml
# ❌ BAD: Secret might appear in logs
deploy:
  script:
    - echo "Deploying with token $API_TOKEN"

# ✅ GOOD: Don't echo secrets
deploy:
  script:
    - echo "Starting deployment"
    - deploy --token $API_TOKEN  # Token won't appear if masked

# ✅ GOOD: Use GitLab's masking
deploy:
  before_script:
    - echo "::add-mask::$API_TOKEN"  # Mask custom secrets
  script:
    - deploy --token $API_TOKEN
```

### 5. Disable Debug Mode in Production

```yaml
# ❌ BAD: Debug mode exposes information
deploy-production:
  variables:
    CI_DEBUG_TRACE: "true"  # ❌ Don't use in production
  script:
    - deploy production

# ✅ GOOD: Only debug in non-production
test:
  variables:
    CI_DEBUG_TRACE: "true"  # ✅ OK for testing
  script:
    - npm test
```

---

## Artifact Security

### 1. Use Specific Artifact Paths

**❌ BAD:**
```yaml
build:
  artifacts:
    paths:
      - ./**  # Includes everything, might expose secrets
```

**✅ GOOD:**
```yaml
build:
  artifacts:
    paths:
      - dist/
      - build/
    exclude:
      - "**/*.env"
      - "**/*.pem"
      - "**/*.key"
      - "**/node_modules/"
```

### 2. Set Appropriate Expiration

```yaml
# Short-lived artifacts for builds
build:
  artifacts:
    paths:
      - dist/
    expire_in: 1 hour  # ✅ Minimize exposure window

# Longer retention for releases
release:
  artifacts:
    paths:
      - release/
    expire_in: 1 month  # ✅ Appropriate for releases
```

### 3. Don't Include Sensitive Dependencies

```yaml
build:
  artifacts:
    paths:
      - dist/
    exclude:
      - node_modules/  # ✅ Don't include dependencies
      - vendor/  # ✅ Don't include vendor code
      - .git/  # ✅ Don't include git history
```

### 4. Use Access Controls for Artifacts

Configure in **Settings → CI/CD → General pipelines:**
- Limit artifact downloads to project members
- Require authentication for artifact access
- Set appropriate visibility levels

---

## Network Security

### 1. Use TLS/SSL for All Connections

```yaml
deploy:
  script:
    # ✅ HTTPS
    - curl -X POST https://api.example.com/deploy

    # ❌ HTTP (only for local development)
    # - curl -X POST http://api.example.com/deploy
```

### 2. Don't Disable SSL Verification

**❌ BAD:**
```yaml
test:
  script:
    - curl -k https://api.example.com  # ❌ Disables verification
    - git config --global http.sslVerify false  # ❌ Dangerous
```

**✅ GOOD:**
```yaml
test:
  script:
    - curl --cacert /etc/ssl/certs/ca-bundle.crt https://api.example.com
    - git config --global http.sslCAInfo /etc/ssl/certs/ca-bundle.crt
```

### 3. Use Private Registries for Internal Images

```yaml
variables:
  # ✅ Use private registry for internal images
  INTERNAL_REGISTRY: registry.internal.example.com

build:
  image: $INTERNAL_REGISTRY/build-tools:latest
  script:
    - make build
```

### 4. Restrict Outbound Connections

```yaml
# Configure runner to limit outbound connections
# Only allow specific domains/IPs in firewall rules

deploy:
  script:
    # Whitelist specific endpoints
    - curl https://api.allowed-service.com/deploy
```

---

## Access Control

### 1. Use Protected Branches

**Settings → Repository → Protected branches:**
- Protect `main` and `production` branches
- Require merge request approvals
- Restrict who can push
- Restrict who can merge

```yaml
deploy-production:
  script:
    - deploy production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"  # Only on protected branch
  when: manual
```

### 2. Use Protected Environments

**Settings → CI/CD → Environments:**
- Mark production environments as protected
- Define deployment approvals
- Restrict access to authorized users

```yaml
deploy-production:
  environment:
    name: production  # Protected environment
    url: https://example.com
  script:
    - deploy production
  when: manual  # Requires manual approval
```

### 3. Use Protected Tags for Releases

```yaml
release:
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+$/  # Only on version tags
  script:
    - make release
  when: manual
```

### 4. Limit Runner Access

**Settings → CI/CD → Runners:**
- Use specific runners for sensitive operations
- Tag runners appropriately
- Disable shared runners for security-sensitive projects

```yaml
deploy-production:
  tags:
    - production-runner  # Specific runner for production
    - secured
  script:
    - deploy production
```

### 5. Use Resource Groups

```yaml
deploy-production:
  resource_group: production  # ✅ Prevents concurrent deployments
  script:
    - deploy production

deploy-staging:
  resource_group: staging  # ✅ Independent resource group
  script:
    - deploy staging
```

---

## Supply Chain Security

### 1. Pin All Dependencies

```yaml
# ✅ GOOD: Lock file ensures reproducibility
build:
  script:
    - npm ci  # Uses package-lock.json
    # - npm install  # ❌ Don't use in CI
```

### 2. Verify Dependency Integrity

```yaml
build:
  script:
    - npm ci --audit  # Check for vulnerabilities
    - npm audit --audit-level=high  # Fail on high severity issues
```

### 3. Use Dependency Scanning

```yaml
include:
  - template: Security/Dependency-Scanning.gitlab-ci.yml

gemnasium-dependency_scanning:
  variables:
    DS_EXCLUDED_PATHS: "node_modules,vendor"
  artifacts:
    reports:
      dependency_scanning: gl-dependency-scanning-report.json
```

### 4. Scan for Secrets in Code

```yaml
include:
  - template: Security/Secret-Detection.gitlab-ci.yml

secret_detection:
  variables:
    SECRET_DETECTION_EXCLUDED_PATHS: "tests/"
```

### 5. Use SBOM (Software Bill of Materials)

```yaml
sbom-generation:
  image: anchore/syft:latest
  script:
    - syft packages dir:. -o cyclonedx-json > sbom.json
  artifacts:
    paths:
      - sbom.json
    expire_in: 1 year
```

---

## Compliance and Auditing

### 1. Enable Audit Logging

- Enable audit events in GitLab
- Monitor pipeline execution logs
- Track variable changes
- Review access patterns

### 2. Implement Compliance Pipelines

```yaml
include:
  - template: 'Workflows/MergeRequest-Pipelines.gitlab-ci.yml'
  - template: Security/SAST.gitlab-ci.yml
  - template: Security/Dependency-Scanning.gitlab-ci.yml
  - template: Security/Secret-Detection.gitlab-ci.yml
  - template: Security/Container-Scanning.gitlab-ci.yml

compliance-check:
  stage: .pre
  script:
    - echo "Running compliance checks"
    - ./scripts/compliance-audit.sh
  allow_failure: false
```

### 3. Implement Separation of Duties

```yaml
# Different teams/roles for different stages
deploy-staging:
  rules:
    - if: $CI_COMMIT_BRANCH == "develop"
  # Can be triggered by developers

deploy-production:
  rules:
    - if: $CI_COMMIT_TAG =~ /^v\d+/
  when: manual  # Requires ops team approval
  environment:
    name: production
```

### 4. Maintain Audit Trails

```yaml
deploy:
  before_script:
    - echo "Deploy initiated by $GITLAB_USER_LOGIN at $(date)"
    - echo "Commit: $CI_COMMIT_SHORT_SHA"
    - echo "Branch: $CI_COMMIT_BRANCH"
  script:
    - deploy production
  after_script:
    - echo "Deploy completed at $(date)"
    - ./scripts/log-audit-event.sh
```

### 5. Regular Security Reviews

- Review CI/CD configurations quarterly
- Audit access controls monthly
- Scan for exposed secrets weekly
- Update dependencies regularly
- Review runner security monthly

---

## Security Checklist

When creating or reviewing GitLab CI/CD pipelines, ensure:

### Secrets & Credentials
- [ ] No hardcoded secrets in `.gitlab-ci.yml`
- [ ] Sensitive variables are masked
- [ ] Production variables are protected
- [ ] Secrets are scoped to appropriate environments
- [ ] Regular secret rotation schedule exists

### Images & Containers
- [ ] All images pinned to specific versions
- [ ] Images from trusted sources only
- [ ] Container vulnerability scanning enabled
- [ ] Containers run as non-root users
- [ ] Minimal base images used where possible

### Scripts & Commands
- [ ] No `curl | bash` patterns
- [ ] No use of `eval` with external input
- [ ] Input validation implemented
- [ ] Proper error handling (`set -e`)
- [ ] No secrets echoed to logs

### Artifacts & Cache
- [ ] Specific artifact paths (not `./**`)
- [ ] Sensitive files excluded from artifacts
- [ ] Appropriate expiration times set
- [ ] No credentials in cached files

### Network & Communication
- [ ] HTTPS/TLS used for all external calls
- [ ] SSL verification enabled
- [ ] Private registries for internal images
- [ ] Outbound connections restricted

### Access Control
- [ ] Protected branches configured
- [ ] Protected environments for production
- [ ] Protected tags for releases
- [ ] Specific runners for sensitive operations
- [ ] Resource groups for deployments

### Supply Chain
- [ ] Dependencies pinned/locked
- [ ] Dependency scanning enabled
- [ ] SAST scanning enabled
- [ ] Secret detection enabled
- [ ] Regular dependency updates scheduled

### Compliance
- [ ] Audit logging enabled
- [ ] Compliance pipelines implemented
- [ ] Separation of duties enforced
- [ ] Audit trails maintained
- [ ] Regular security reviews scheduled

---

## Security Incident Response

### If Secrets Are Exposed

1. **Immediate Actions:**
   - Rotate the compromised credentials immediately
   - Revoke exposed tokens/keys
   - Review access logs for unauthorized usage
   - Notify security team

2. **Investigation:**
   - Identify scope of exposure
   - Review pipeline logs
   - Check for unauthorized access
   - Document timeline

3. **Remediation:**
   - Remove secrets from code/logs
   - Update `.gitlab-ci.yml` with proper secret management
   - Implement additional controls
   - Update security documentation

4. **Prevention:**
   - Enable secret scanning
   - Implement pre-commit hooks
   - Conduct security training
   - Review secret management practices

---

## Additional Resources

- GitLab Security Best Practices: https://docs.gitlab.com/ee/security/
- OWASP CI/CD Security: https://owasp.org/www-project-ci-cd-security/
- CIS Docker Benchmark: https://www.cisecurity.org/benchmark/docker
- NIST Supply Chain Security: https://www.nist.gov/itl/executive-order-improving-nations-cybersecurity/software-security-supply-chains

---

**Always prioritize security in your GitLab CI/CD pipelines. When in doubt, choose the more secure option.**