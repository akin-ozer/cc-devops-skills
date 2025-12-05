# Makefile Security Guide

## Overview

This guide covers security best practices for Makefiles, including secrets management, input validation, shell injection prevention, and CI/CD security considerations.

## Secrets Management

### Never Commit Secrets

**DO NOT** hardcode credentials, API keys, or passwords in Makefiles:

```makefile
# WRONG: Hardcoded credentials
DB_PASSWORD := mysecretpassword
AWS_SECRET := AKIAIOSFODNN7EXAMPLE
```

### Use Environment Variables

Pass secrets via environment variables:

```makefile
# CORRECT: Environment variable with validation
DB_PASSWORD ?= $(error DB_PASSWORD is not set)
AWS_SECRET_KEY ?= $(error AWS_SECRET_KEY is not set)

deploy:
	@echo "Deploying with credentials from environment..."
	./deploy.sh
```

### Use .env Files (Not in Git)

```makefile
# Include .env file if it exists (never commit .env!)
-include .env
export

# Ensure .gitignore contains .env
.PHONY: check-env
check-env:
	@grep -q '^\.env$$' .gitignore || echo "WARNING: Add .env to .gitignore!"
```

### Secrets from External Sources

**AWS Secrets Manager:**

```makefile
# Fetch secret at runtime, don't cache in Makefile variables
deploy:
	@DB_PASSWORD=$$(aws secretsmanager get-secret-value \
		--secret-id prod/db/password \
		--query SecretString --output text) && \
	./deploy.sh
```

**HashiCorp Vault:**

```makefile
deploy:
	@DB_PASSWORD=$$(vault kv get -field=password secret/database) && \
	./deploy.sh
```

## Shell Injection Prevention

### Input Validation

Always validate user-provided variables:

```makefile
# Validate PROJECT_NAME contains only safe characters
PROJECT_NAME := $(strip $(PROJECT_NAME))
ifneq ($(PROJECT_NAME),$(shell echo '$(PROJECT_NAME)' | tr -cd 'a-zA-Z0-9_-'))
$(error PROJECT_NAME contains invalid characters. Use only [a-zA-Z0-9_-])
endif
```

### Quote Variables in Shell Commands

```makefile
# WRONG: Unquoted variables - vulnerable to injection
process:
	./script.sh $(USER_INPUT)

# CORRECT: Quoted variables
process:
	./script.sh '$(USER_INPUT)'
```

### Avoid Shell Expansion of User Input

```makefile
# WRONG: Shell will interpret special characters
echo-input:
	@echo $(MESSAGE)

# SAFER: Use printf with proper quoting
echo-input:
	@printf '%s\n' '$(MESSAGE)'
```

### Dangerous Patterns to Avoid

```makefile
# NEVER do this - allows arbitrary command execution
run-command:
	$(USER_COMMAND)

# NEVER pipe untrusted input to shell
execute:
	echo $(INPUT) | sh

# NEVER use eval with user input
eval-input:
	@eval $(USER_INPUT)
```

## Variable Expansion Security

### Simple vs Recursive Expansion

```makefile
# Use := for values that shouldn't be re-evaluated
SAFE_VALUE := $(shell whoami)

# = causes re-evaluation each time - potential for injection
# if EXTERNAL_VAR changes after assignment
UNSAFE_VALUE = $(EXTERNAL_VAR)
```

### Dollar Sign Escaping

When working with passwords containing `$`:

```makefile
# Password with $ sign - double the $ to escape
# If password is "pa$$word", set it as:
PASSWORD := pa$$$$word

# Or read from file where $ is already escaped
PASSWORD := $(shell cat .password | sed 's/\$$/\$\$\$\$/g')
```

## File System Security

### Path Traversal Prevention

```makefile
# WRONG: User can specify "../../../etc/passwd"
read-file:
	cat $(FILE_PATH)

# SAFER: Validate path is within expected directory
SAFE_DIR := ./data
read-file:
	@case "$(FILE_PATH)" in \
		$(SAFE_DIR)/*) cat "$(FILE_PATH)" ;; \
		*) echo "ERROR: Invalid path" >&2; exit 1 ;; \
	esac
```

### Secure Temporary Files

```makefile
# Use mktemp for secure temporary files
process:
	@TMPFILE=$$(mktemp) && \
	trap 'rm -f "$$TMPFILE"' EXIT && \
	./generate-config > "$$TMPFILE" && \
	./process-config "$$TMPFILE"
```

### File Permission Handling

```makefile
# Set restrictive permissions on sensitive files
install-config:
	install -m 600 config.secret $(DESTDIR)/etc/myapp/

# Create directories with appropriate permissions
install-dirs:
	install -d -m 700 $(DESTDIR)/var/lib/myapp/secrets
```

## CI/CD Security

### Avoid Logging Secrets

```makefile
# WRONG: Password visible in logs
deploy:
	curl -u user:$(PASSWORD) https://api.example.com

# CORRECT: Suppress command echo
deploy:
	@curl -u user:$(PASSWORD) https://api.example.com

# BEST: Use credential helper
deploy:
	@curl --netrc-file ~/.netrc https://api.example.com
```

### Fail Securely

```makefile
# Use strict mode
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

# Ensure sensitive operations fail closed
deploy:
	@test -n "$(API_KEY)" || { echo "ERROR: API_KEY not set" >&2; exit 1; }
	@./deploy.sh
```

### Environment Isolation

```makefile
# Don't inherit all environment variables
# Only export what's needed
unexport HISTFILE
unexport AWS_SESSION_TOKEN

# Explicitly export required variables
export PATH
export HOME
```

### Audit Logging

```makefile
AUDIT_LOG := /var/log/makefile-audit.log

audit-log = @echo "$$(date -Iseconds) [$(1)] $(2)" >> $(AUDIT_LOG)

deploy: check-permissions
	$(call audit-log,DEPLOY,Starting deployment by $$USER)
	./deploy.sh
	$(call audit-log,DEPLOY,Deployment completed)
```

## Network Security

### Secure Downloads

```makefile
# Always verify downloads
CHECKSUM_FILE := checksums.sha256

download:
	curl -fsSL -o package.tar.gz https://example.com/package.tar.gz
	sha256sum -c $(CHECKSUM_FILE)

# Or use GPG verification
download-verified:
	curl -fsSL -o package.tar.gz https://example.com/package.tar.gz
	curl -fsSL -o package.tar.gz.asc https://example.com/package.tar.gz.asc
	gpg --verify package.tar.gz.asc package.tar.gz
```

### TLS/HTTPS Only

```makefile
# Force HTTPS for all downloads
CURL_OPTS := --proto '=https' --tlsv1.2

download:
	curl $(CURL_OPTS) -fsSL -o file.txt https://example.com/file.txt
```

## Container Security

### Don't Build as Root

```makefile
docker-build:
	docker build --build-arg USER_ID=$$(id -u) --build-arg GROUP_ID=$$(id -g) -t myapp .

# In Dockerfile, create non-root user
```

### Scan Images for Vulnerabilities

```makefile
IMAGE := myapp:latest

.PHONY: docker-scan
docker-scan: docker-build
	@if command -v trivy >/dev/null 2>&1; then \
		trivy image --exit-code 1 --severity HIGH,CRITICAL $(IMAGE); \
	else \
		echo "WARNING: trivy not found, skipping security scan"; \
	fi
```

### Don't Pass Secrets as Build Args

```makefile
# WRONG: Secret visible in image layers
docker-build:
	docker build --build-arg API_KEY=$(API_KEY) -t myapp .

# CORRECT: Use build secrets (BuildKit)
docker-build:
	DOCKER_BUILDKIT=1 docker build \
		--secret id=api_key,src=.api_key \
		-t myapp .
```

## Secure Defaults

### Modern Makefile Preamble

```makefile
# Secure and strict Makefile configuration
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# Prevent accidental exposure
unexport HISTFILE
```

### Require Explicit Targets

```makefile
# Prevent running all targets by accident
.PHONY: all
all:
	@echo "Please specify a target. Run 'make help' for options."
	@exit 1
```

## Security Checklist

Before committing a Makefile:

- [ ] No hardcoded credentials, API keys, or passwords
- [ ] Secrets loaded from environment or secret manager
- [ ] `.env` file listed in `.gitignore`
- [ ] User input is validated before use
- [ ] Shell commands use proper quoting
- [ ] No use of `eval` with external input
- [ ] Downloads verified with checksums or signatures
- [ ] Sensitive commands prefixed with `@` to hide from logs
- [ ] Temporary files created securely and cleaned up
- [ ] File permissions are appropriately restrictive
- [ ] Container builds don't expose secrets in layers

## References

- [OWASP Command Injection](https://owasp.org/www-community/attacks/Command_Injection)
- [CWE-78: Improper Neutralization of Special Elements](https://cwe.mitre.org/data/definitions/78.html)
- [GNU Make Security Considerations](https://www.gnu.org/software/make/manual/html_node/Environment.html)
- [Passing Credentials in GNU Make - Security Stack Exchange](https://security.stackexchange.com/questions/278120/passing-credentials-in-gnu-make)
- [GitGuardian - Secure Your Secrets with .env](https://blog.gitguardian.com/secure-your-secrets-with-env/)