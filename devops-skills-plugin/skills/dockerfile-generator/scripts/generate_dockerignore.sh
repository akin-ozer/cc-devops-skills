#!/usr/bin/env bash
# Generate a comprehensive .dockerignore file

set -euo pipefail

# Default values
OUTPUT_FILE="${OUTPUT_FILE:-.dockerignore}"
LANGUAGE="${LANGUAGE:-generic}"

# Usage
usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Generate a comprehensive .dockerignore file.

OPTIONS:
    -l, --language LANG      Language: nodejs, python, go, java, generic (default: generic)
    -o, --output FILE        Output file (default: .dockerignore)
    -h, --help               Show this help message

EXAMPLES:
    # Generic .dockerignore
    $0

    # Node.js specific
    $0 --language nodejs

    # Python specific
    $0 --language python

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--language)
            LANGUAGE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
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

# Generate base .dockerignore
cat > "$OUTPUT_FILE" <<'EOF'
# Git
.git
.gitignore
.gitattributes

# CI/CD
.github
.gitlab-ci.yml
.travis.yml
.circleci
Jenkinsfile

# Documentation
README.md
CHANGELOG.md
CONTRIBUTING.md
LICENSE
*.md
docs/

# Docker
Dockerfile*
docker-compose*.yml
.dockerignore

# Environment
.env
.env.*
*.local
.envrc

# Logs
logs/
*.log

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
*.iml

# Testing
coverage/
.coverage
test-results/
*.test

EOF

# Add language-specific patterns
case "$LANGUAGE" in
    nodejs)
        cat >> "$OUTPUT_FILE" <<'EOF'
# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
.yarn
.pnp.*
dist/
build/

EOF
        ;;
    python)
        cat >> "$OUTPUT_FILE" <<'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/
.venv/
env/
ENV/
pip-log.txt
pip-delete-this-directory.txt
.pytest_cache/
.tox/
*.egg-info/
dist/
build/

EOF
        ;;
    go)
        cat >> "$OUTPUT_FILE" <<'EOF'
# Go
vendor/
*.exe
*.test
*.out
go.work
go.work.sum

EOF
        ;;
    java)
        cat >> "$OUTPUT_FILE" <<'EOF'
# Java
target/
*.class
*.jar
*.war
*.ear
.gradle/
build/
.mvn/
!.mvn/wrapper/maven-wrapper.jar

EOF
        ;;
    generic)
        cat >> "$OUTPUT_FILE" <<'EOF'
# Build artifacts
dist/
build/
target/
out/

EOF
        ;;
esac

echo "✓ Generated .dockerignore: $OUTPUT_FILE"
echo "  Language: $LANGUAGE"
