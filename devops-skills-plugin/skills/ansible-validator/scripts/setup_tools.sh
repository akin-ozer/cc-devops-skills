#!/usr/bin/env bash

# Setup and validation tool for Ansible Validator
# Checks for required tools and provides installation instructions

set -e

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_RESET='\033[0m'

echo "Checking Ansible validation tools..."
echo ""

MISSING_TOOLS=()
INSTALLED_TOOLS=()

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to get version
get_version() {
    $1 --version 2>/dev/null | head -n 1
}

# Check ansible
echo -n "Checking ansible... "
if command_exists ansible; then
    VERSION=$(ansible --version | head -n 1)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("ansible")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("ansible")
fi

# Check ansible-playbook
echo -n "Checking ansible-playbook... "
if command_exists ansible-playbook; then
    VERSION=$(ansible-playbook --version | head -n 1)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("ansible-playbook")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("ansible-playbook")
fi

# Check ansible-lint
echo -n "Checking ansible-lint... "
if command_exists ansible-lint; then
    VERSION=$(ansible-lint --version)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("ansible-lint")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("ansible-lint")
fi

# Check yamllint
echo -n "Checking yamllint... "
if command_exists yamllint; then
    VERSION=$(yamllint --version)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("yamllint")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("yamllint")
fi

# Check checkov (recommended for security scanning)
echo -n "Checking checkov (recommended)... "
if command_exists checkov; then
    VERSION=$(checkov --version 2>/dev/null | head -n 1)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("checkov")
else
    echo -e "${COLOR_YELLOW}⚠ Not found${COLOR_RESET} (recommended for security scanning)"
fi

# Check molecule (optional but recommended)
echo -n "Checking molecule (optional)... "
if command_exists molecule; then
    VERSION=$(molecule --version | head -n 1)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("molecule")
else
    echo -e "${COLOR_YELLOW}⚠ Not found${COLOR_RESET} (optional)"
fi

# Check ansible-galaxy
echo -n "Checking ansible-galaxy... "
if command_exists ansible-galaxy; then
    VERSION=$(ansible-galaxy --version | head -n 1)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("ansible-galaxy")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("ansible-galaxy")
fi

# Check python3
echo -n "Checking python3... "
if command_exists python3; then
    VERSION=$(python3 --version)
    echo -e "${COLOR_GREEN}✓ Found${COLOR_RESET} - $VERSION"
    INSTALLED_TOOLS+=("python3")
else
    echo -e "${COLOR_RED}✗ Not found${COLOR_RESET}"
    MISSING_TOOLS+=("python3")
fi

echo ""
echo "========================================"

# Summary
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo -e "${COLOR_GREEN}All required tools are installed!${COLOR_RESET}"
    exit 0
else
    echo -e "${COLOR_YELLOW}Missing tools detected${COLOR_RESET}"
    echo ""
    echo "Installation instructions:"
    echo ""

    # Check OS and provide appropriate installation commands
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "macOS detected - Install with Homebrew or pip:"
        echo ""
        echo "  # Install with pip (recommended):"
        echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
        echo ""
        echo "  # Or with Homebrew:"
        echo "  brew install ansible ansible-lint yamllint"
        echo "  pip3 install checkov  # checkov not available via brew"
        echo ""
        echo "  # Optional: Install molecule for role testing"
        echo "  pip3 install molecule molecule-docker"

    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command_exists apt-get; then
            # Debian/Ubuntu
            echo "Debian/Ubuntu detected - Install with apt and pip:"
            echo ""
            echo "  sudo apt-get update"
            echo "  sudo apt-get install -y python3-pip"
            echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
            echo ""
            echo "  # Optional: Install molecule for role testing"
            echo "  pip3 install molecule molecule-docker"

        elif command_exists yum; then
            # RHEL/CentOS
            echo "RHEL/CentOS detected - Install with yum and pip:"
            echo ""
            echo "  sudo yum install -y python3-pip"
            echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
            echo ""
            echo "  # Optional: Install molecule for role testing"
            echo "  pip3 install molecule molecule-docker"

        elif command_exists dnf; then
            # Fedora
            echo "Fedora detected - Install with dnf and pip:"
            echo ""
            echo "  sudo dnf install -y python3-pip"
            echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
            echo ""
            echo "  # Optional: Install molecule for role testing"
            echo "  pip3 install molecule molecule-docker"
        else
            echo "Linux detected - Install with pip:"
            echo ""
            echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
            echo ""
            echo "  # Optional: Install molecule for role testing"
            echo "  pip3 install molecule molecule-docker"
        fi
    else
        # Generic
        echo "Install with pip:"
        echo ""
        echo "  pip3 install --upgrade ansible ansible-lint yamllint checkov"
        echo ""
        echo "  # Optional: Install molecule for role testing"
        echo "  pip3 install molecule molecule-docker"
    fi

    echo ""
    echo "After installation, run this script again to verify."
    exit 1
fi
