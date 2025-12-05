#!/usr/bin/env bash

# Ansible Secret Scanner
# Scans Ansible files for hardcoded secrets that Checkov may miss
# This complements Checkov security scanning with grep-based detection

set -e

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'

# Usage check
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <playbook.yml|role-directory|directory>"
    echo ""
    echo "Scans Ansible files for hardcoded secrets including:"
    echo "  - Passwords"
    echo "  - API keys"
    echo "  - Tokens"
    echo "  - Private keys"
    echo "  - AWS credentials"
    echo "  - Database connection strings"
    exit 1
fi

if [ ! -f "$TARGET" ] && [ ! -d "$TARGET" ]; then
    echo -e "${COLOR_RED}Error: Target not found: $TARGET${COLOR_RESET}"
    exit 1
fi

# Get absolute path
if [ -f "$TARGET" ]; then
    TARGET_ABS=$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")
    SCAN_TYPE="file"
else
    TARGET_ABS=$(cd "$TARGET" && pwd)
    SCAN_TYPE="directory"
fi

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Ansible Hardcoded Secret Scanner${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Scanning: $TARGET_ABS"
echo ""

SECRETS_FOUND=0
WARNINGS_FOUND=0

# Function to scan for patterns
scan_pattern() {
    local pattern="$1"
    local description="$2"
    local severity="$3"  # ERROR or WARNING
    local results=""

    if [ "$SCAN_TYPE" = "file" ]; then
        results=$(grep -n -i "$pattern" "$TARGET_ABS" 2>/dev/null || true)
    else
        results=$(grep -r -n -i "$pattern" "$TARGET_ABS" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -v ".git/" || true)
    fi

    if [ -n "$results" ]; then
        if [ "$severity" = "ERROR" ]; then
            echo -e "${COLOR_RED}[SECRET DETECTED]${COLOR_RESET} $description"
            SECRETS_FOUND=$((SECRETS_FOUND + 1))
        else
            echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $description"
            WARNINGS_FOUND=$((WARNINGS_FOUND + 1))
        fi
        echo "$results" | while read -r line; do
            echo "  $line"
        done
        echo ""
    fi
}

# Function to check for non-vaulted password values
check_password_values() {
    local results=""

    if [ "$SCAN_TYPE" = "file" ]; then
        # Look for password: followed by a non-variable value (not {{ }})
        results=$(grep -n -E "password:\s*['\"]?[^{'\"][^'\"]*['\"]?\s*$" "$TARGET_ABS" 2>/dev/null || true)
        results+=$(grep -n -E "password:\s*['\"][^{][^'\"]+['\"]" "$TARGET_ABS" 2>/dev/null || true)
    else
        results=$(grep -r -n -E "password:\s*['\"]?[^{'\"][^'\"]*['\"]?\s*$" "$TARGET_ABS" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -v ".git/" || true)
        results+=$(grep -r -n -E "password:\s*['\"][^{][^'\"]+['\"]" "$TARGET_ABS" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -v ".git/" | grep -v "password_hash" || true)
    fi

    # Filter out false positives (empty values, variable references, vault references)
    if [ -n "$results" ]; then
        filtered=$(echo "$results" | grep -v "password:\s*$" | grep -v "password:\s*\"\s*\"" | grep -v "password:\s*'\s*'" | grep -v "{{" | grep -v "vault_" | grep -v "!vault" || true)
        if [ -n "$filtered" ]; then
            echo -e "${COLOR_RED}[SECRET DETECTED]${COLOR_RESET} Hardcoded password value found"
            SECRETS_FOUND=$((SECRETS_FOUND + 1))
            echo "$filtered" | while read -r line; do
                echo "  $line"
            done
            echo ""
        fi
    fi
}

echo -e "${COLOR_BLUE}Scanning for hardcoded secrets...${COLOR_RESET}"
echo ""

# High severity - likely secrets
scan_pattern "password:\s*['\"]" "Potential hardcoded password" "ERROR"
scan_pattern "api_key:\s*['\"]" "Potential hardcoded API key" "ERROR"
scan_pattern "apikey:\s*['\"]" "Potential hardcoded API key" "ERROR"
scan_pattern "secret:\s*['\"]" "Potential hardcoded secret" "ERROR"
scan_pattern "secret_key:\s*['\"]" "Potential hardcoded secret key" "ERROR"
scan_pattern "private_key:\s*['\"]" "Potential hardcoded private key" "ERROR"
scan_pattern "token:\s*['\"]" "Potential hardcoded token" "ERROR"
scan_pattern "auth_token:\s*['\"]" "Potential hardcoded auth token" "ERROR"
scan_pattern "access_token:\s*['\"]" "Potential hardcoded access token" "ERROR"

# AWS credentials
scan_pattern "aws_access_key_id:\s*['\"]?[A-Z0-9]" "Potential hardcoded AWS Access Key" "ERROR"
scan_pattern "aws_secret_access_key:\s*['\"]" "Potential hardcoded AWS Secret Key" "ERROR"
scan_pattern "AKIA[A-Z0-9]{16}" "AWS Access Key ID pattern detected" "ERROR"

# Database connection strings
scan_pattern "mysql://.*:.*@" "Potential database connection string with credentials" "ERROR"
scan_pattern "postgres://.*:.*@" "Potential database connection string with credentials" "ERROR"
scan_pattern "mongodb://.*:.*@" "Potential database connection string with credentials" "ERROR"

# Private key content
scan_pattern "BEGIN RSA PRIVATE KEY" "Private key content detected" "ERROR"
scan_pattern "BEGIN OPENSSH PRIVATE KEY" "OpenSSH private key content detected" "ERROR"
scan_pattern "BEGIN EC PRIVATE KEY" "EC private key content detected" "ERROR"
scan_pattern "BEGIN DSA PRIVATE KEY" "DSA private key content detected" "ERROR"

# Medium severity - may be secrets
scan_pattern "credentials:\s*['\"]" "Potential hardcoded credentials" "WARNING"
scan_pattern "db_password:\s*['\"]" "Potential hardcoded database password" "WARNING"
scan_pattern "database_password:\s*['\"]" "Potential hardcoded database password" "WARNING"
scan_pattern "admin_password:\s*['\"]" "Potential hardcoded admin password" "WARNING"
scan_pattern "root_password:\s*['\"]" "Potential hardcoded root password" "WARNING"
scan_pattern "ssh_pass:\s*['\"]" "Potential hardcoded SSH password" "WARNING"

# Check for password values that are not variable references
check_password_values

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}Secret Scan Summary${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

if [ $SECRETS_FOUND -eq 0 ] && [ $WARNINGS_FOUND -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ No hardcoded secrets detected${COLOR_RESET}"
    echo ""
    echo "Note: This scan uses pattern matching and may not catch all secrets."
    echo "Always use Ansible Vault for sensitive data."
    exit 0
elif [ $SECRETS_FOUND -eq 0 ]; then
    echo -e "${COLOR_YELLOW}⚠ Found $WARNINGS_FOUND potential secret(s) requiring review${COLOR_RESET}"
    echo ""
    echo "Recommendations:"
    echo "  1. Review the warnings above to determine if they contain actual secrets"
    echo "  2. Use Ansible Vault to encrypt sensitive values"
    echo "  3. Use environment variables or external secret management"
    echo ""
    echo "For secure secret management, see:"
    echo "  $SKILL_DIR/references/security_checklist.md"
    exit 0
else
    echo -e "${COLOR_RED}✗ Found $SECRETS_FOUND secret(s) and $WARNINGS_FOUND warning(s)${COLOR_RESET}"
    echo ""
    echo "CRITICAL: Hardcoded secrets were detected!"
    echo ""
    echo "Remediation steps:"
    echo "  1. Never commit hardcoded secrets to version control"
    echo "  2. Use Ansible Vault to encrypt sensitive data:"
    echo "     ansible-vault encrypt_string 'secret_value' --name 'variable_name'"
    echo "  3. Use lookup plugins for external secrets:"
    echo "     password: \"{{ lookup('env', 'DB_PASSWORD') }}\""
    echo "  4. Use HashiCorp Vault or similar for production:"
    echo "     password: \"{{ lookup('hashi_vault', 'secret=secret/data/db:password') }}\""
    echo ""
    echo "For detailed guidance, see:"
    echo "  $SKILL_DIR/references/security_checklist.md"
    exit 1
fi