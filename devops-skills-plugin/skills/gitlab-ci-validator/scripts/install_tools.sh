#!/usr/bin/env bash

#
# GitLab CI Validator - Tool Installation Script
#
# This script installs the required tools for local pipeline testing:
# - gitlab-ci-local: For local GitLab CI pipeline execution (similar to act for GitHub Actions)
#
# Usage: bash scripts/install_tools.sh
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$SCRIPT_DIR/.tools"

# Create tools directory if it doesn't exist
mkdir -p "$TOOLS_DIR"

echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  GitLab CI Validator - Tool Installation${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Function to get OS type
get_os() {
    case "$(uname -s)" in
        Darwin*)    echo "darwin" ;;
        Linux*)     echo "linux" ;;
        *)          echo "unknown" ;;
    esac
}

# Function to get architecture
get_arch() {
    case "$(uname -m)" in
        x86_64)     echo "x64" ;;
        aarch64)    echo "arm64" ;;
        arm64)      echo "arm64" ;;
        *)          echo "unknown" ;;
    esac
}

#
# Install gitlab-ci-local
#
install_gitlab_ci_local() {
    echo -e "${BLUE}[1/1]${NC} Checking for gitlab-ci-local..."

    # Check if already installed globally
    if command_exists gitlab-ci-local; then
        CURRENT_VERSION=$(gitlab-ci-local --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} gitlab-ci-local is already installed: $CURRENT_VERSION"
        echo ""
        return 0
    fi

    # Check if installed in tools directory
    if [ -f "$TOOLS_DIR/gitlab-ci-local" ]; then
        CURRENT_VERSION=$("$TOOLS_DIR/gitlab-ci-local" --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} gitlab-ci-local is installed in .tools: $CURRENT_VERSION"
        echo ""
        return 0
    fi

    echo -e "${YELLOW}→${NC} gitlab-ci-local not found. Installing..."
    echo ""

    # Check for Node.js (required for gitlab-ci-local)
    if ! command_exists node; then
        echo -e "${RED}✗${NC} Node.js is not installed but is required for gitlab-ci-local"
        echo ""
        echo "Please install Node.js first:"
        echo "  - macOS:   brew install node"
        echo "  - Linux:   Install from https://nodejs.org/ or use your package manager"
        echo ""
        echo "After installing Node.js, run this script again."
        return 1
    fi

    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✓${NC} Node.js is installed: $NODE_VERSION"

    # Install gitlab-ci-local using npm
    echo ""
    echo -e "${YELLOW}→${NC} Installing gitlab-ci-local via npm..."
    echo "  Note: This requires Docker to be installed for pipeline execution"
    echo ""

    # Try to install globally if user has permissions
    if npm install -g gitlab-ci-local 2>/dev/null; then
        INSTALLED_VERSION=$(gitlab-ci-local --version 2>/dev/null || echo "unknown")
        echo ""
        echo -e "${GREEN}✓${NC} gitlab-ci-local installed successfully: $INSTALLED_VERSION"
        echo "  Location: $(which gitlab-ci-local)"
    else
        echo -e "${YELLOW}⚠${NC} Could not install globally. Trying local installation..."
        echo ""

        # Install locally in project
        cd "$SCRIPT_DIR/.."
        if npm install --save-dev gitlab-ci-local 2>/dev/null; then
            echo ""
            echo -e "${GREEN}✓${NC} gitlab-ci-local installed locally in node_modules"
            echo "  Use: npx gitlab-ci-local --help"
        else
            echo -e "${RED}✗${NC} Failed to install gitlab-ci-local"
            echo ""
            echo "Manual installation options:"
            echo "  1. Global install:  npm install -g gitlab-ci-local"
            echo "  2. Project install: npm install --save-dev gitlab-ci-local"
            echo ""
            echo "For more information: https://github.com/firecow/gitlab-ci-local"
            return 1
        fi
    fi

    echo ""
}

#
# Verify Docker installation (required for gitlab-ci-local)
#
check_docker() {
    echo -e "${BLUE}Checking Docker installation...${NC}"
    echo ""

    if command_exists docker; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || echo "unknown")
        echo -e "${GREEN}✓${NC} Docker is installed: $DOCKER_VERSION"

        # Check if Docker daemon is running
        if docker ps &> /dev/null; then
            echo -e "${GREEN}✓${NC} Docker daemon is running"
        else
            echo -e "${YELLOW}⚠${NC} Docker is installed but daemon is not running"
            echo "  Start Docker Desktop or run: sudo systemctl start docker"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Docker is not installed"
        echo ""
        echo "Docker is required for gitlab-ci-local to execute pipelines locally."
        echo ""
        echo "Installation options:"
        echo "  - macOS:   Install Docker Desktop from https://www.docker.com/products/docker-desktop"
        echo "  - Linux:   Install Docker Engine from https://docs.docker.com/engine/install/"
        echo ""
    fi

    echo ""
}

#
# Main installation process
#
main() {
    # Install gitlab-ci-local
    if ! install_gitlab_ci_local; then
        echo -e "${RED}✗ Installation failed${NC}"
        exit 1
    fi

    # Check Docker
    check_docker

    # Summary
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Installation Summary${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # gitlab-ci-local status
    if command_exists gitlab-ci-local; then
        echo -e "${GREEN}✓${NC} gitlab-ci-local: $(gitlab-ci-local --version)"
    elif [ -f "$TOOLS_DIR/gitlab-ci-local" ]; then
        echo -e "${GREEN}✓${NC} gitlab-ci-local: installed in .tools"
    elif command_exists npx && npx --no-install gitlab-ci-local --version &> /dev/null; then
        echo -e "${GREEN}✓${NC} gitlab-ci-local: installed locally (use npx gitlab-ci-local)"
    else
        echo -e "${YELLOW}⚠${NC} gitlab-ci-local: not installed"
    fi

    # Docker status
    if command_exists docker && docker ps &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: running"
    elif command_exists docker; then
        echo -e "${YELLOW}⚠${NC} Docker: installed but not running"
    else
        echo -e "${YELLOW}⚠${NC} Docker: not installed"
    fi

    echo ""
    echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Usage information
    echo -e "${GREEN}✓ Installation complete!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Ensure Docker is running"
    echo "  2. Test with: gitlab-ci-local --help"
    echo "  3. Run local pipeline: gitlab-ci-local"
    echo "  4. Validate with: bash scripts/validate_gitlab_ci.sh --test-only .gitlab-ci.yml"
    echo ""
    echo "For more information:"
    echo "  - gitlab-ci-local: https://github.com/firecow/gitlab-ci-local"
    echo "  - GitLab CI Docs: https://docs.gitlab.com/ci/"
    echo ""
}

# Run main installation
main
