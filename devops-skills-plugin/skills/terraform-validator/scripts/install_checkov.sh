#!/bin/bash

# Checkov Installation Script with Virtual Environment
# This script installs Checkov in an isolated virtual environment and provides
# a wrapper script for easy execution, with automatic cleanup capabilities.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default installation directory
DEFAULT_INSTALL_DIR="${HOME}/.local/checkov-venv"
INSTALL_DIR="${CHECKOV_INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
WRAPPER_LINK="${HOME}/.local/bin/checkov"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "$0")"

AUTO_YES="false"
FORCE_RECREATE="false"

# Help message
show_help() {
    cat << EOF
Checkov Installation Script with Virtual Environment

Usage: $(basename "$0") <command> [--yes] [--force]

This script installs Checkov in an isolated Python virtual environment,
creating a wrapper script for easy execution.

COMMANDS:
    install         Install Checkov in a virtual environment
    uninstall       Remove Checkov virtual environment and wrapper
    upgrade         Upgrade Checkov to the latest version
    status          Check installation status
    -h, --help      Show this help message

FLAGS:
    -y, --yes       Non-interactive mode; accept confirmation prompts
    --force         Recreate install dir during install if it already exists

ENVIRONMENT VARIABLES:
    CHECKOV_INSTALL_DIR    Custom installation directory (default: ~/.local/checkov-venv)

EXAMPLES:
    # Install Checkov
    $(basename "$0") install --yes

    # Check installation status
    $(basename "$0") status

    # Upgrade Checkov
    $(basename "$0") upgrade

    # Uninstall Checkov
    $(basename "$0") uninstall --yes

NOTES:
    - Requires Python 3.9 or higher
    - Creates a wrapper script at ~/.local/bin/checkov
    - Isolated installation prevents dependency conflicts

EOF
}

# Check Python version
check_python() {
    if ! command -v python3 &> /dev/null; then
        echo -e "${RED}ERROR: python3 is not installed${NC}" >&2
        echo "Install Python 3.9 or higher and try again" >&2
        exit 1
    fi

    local python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
    local major=$(echo "$python_version" | cut -d. -f1)
    local minor=$(echo "$python_version" | cut -d. -f2)

    if [ "$major" -lt 3 ] || ([ "$major" -eq 3 ] && [ "$minor" -lt 9 ]); then
        echo -e "${RED}ERROR: Python 3.9 or higher is required${NC}" >&2
        echo "Current version: $python_version" >&2
        echo "Please upgrade Python and try again" >&2
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Python version: $python_version"
}

# Create virtual environment
create_venv() {
    echo -e "${BLUE}Creating virtual environment at: ${INSTALL_DIR}${NC}"

    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}Virtual environment already exists${NC}"
        if [ "$FORCE_RECREATE" = "true" ] || [ "$AUTO_YES" = "true" ]; then
            rm -rf "$INSTALL_DIR"
        else
            read -p "Remove and recreate? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$INSTALL_DIR"
            else
                echo "Installation cancelled"
                exit 0
            fi
        fi
    fi

    python3 -m venv "$INSTALL_DIR"
    echo -e "${GREEN}✓${NC} Virtual environment created"
}

# Install Checkov
install_checkov() {
    echo -e "${BLUE}Installing Checkov...${NC}"

    # Activate virtual environment and install
    source "$INSTALL_DIR/bin/activate"

    # Upgrade pip and setuptools
    echo "Upgrading pip and setuptools..."
    pip install --upgrade pip setuptools wheel --quiet

    # Install checkov
    echo "Installing checkov..."
    pip install checkov --quiet

    deactivate

    # Get installed version
    local version=$("$INSTALL_DIR/bin/checkov" --version 2>&1 | head -n 1)
    echo -e "${GREEN}✓${NC} Checkov installed: $version"
}

# Create wrapper script
create_wrapper() {
    echo -e "${BLUE}Creating wrapper script...${NC}"

    # Ensure ~/.local/bin exists
    mkdir -p "$(dirname "$WRAPPER_LINK")"

    # Create wrapper script
    cat > "$WRAPPER_LINK" << WRAPPER_EOF
#!/bin/bash
# Checkov wrapper script - executes checkov from virtual environment

VENV_DIR="\${CHECKOV_INSTALL_DIR:-\$HOME/.local/checkov-venv}"
INSTALL_SCRIPT_PATH="$SCRIPT_PATH"

if [ ! -d "\$VENV_DIR" ]; then
    echo "ERROR: Checkov virtual environment not found at: \$VENV_DIR" >&2
    if [ -f "$INSTALL_SCRIPT_PATH" ]; then
        echo "Run: bash \"$INSTALL_SCRIPT_PATH\" install" >&2
    else
        echo "Run install_checkov.sh install from terraform-validator/scripts" >&2
    fi
    exit 1
fi

exec "\$VENV_DIR/bin/checkov" "\$@"
WRAPPER_EOF

    chmod +x "$WRAPPER_LINK"
    echo -e "${GREEN}✓${NC} Wrapper created at: $WRAPPER_LINK"
}

# Check if wrapper is in PATH
check_path() {
    local bin_dir=$(dirname "$WRAPPER_LINK")

    if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
        echo ""
        echo -e "${YELLOW}WARNING: $bin_dir is not in your PATH${NC}"
        echo ""
        echo "Add it to your PATH by adding this line to your shell profile:"
        echo ""
        echo -e "${BLUE}export PATH=\"$bin_dir:\$PATH\"${NC}"
        echo ""
        echo "Shell profiles: ~/.bashrc, ~/.zshrc, ~/.bash_profile"
    fi
}

# Install command
do_install() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Checkov Installation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    check_python
    create_venv
    install_checkov
    create_wrapper

    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${GREEN}Installation Complete!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "Checkov is installed at: $INSTALL_DIR"
    echo "Wrapper script: $WRAPPER_LINK"
    echo ""

    check_path

    echo ""
    echo "Test the installation:"
    echo -e "${BLUE}checkov --version${NC}"
    echo ""
}

# Uninstall command
do_uninstall() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Checkov Uninstallation${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ ! -d "$INSTALL_DIR" ] && [ ! -f "$WRAPPER_LINK" ]; then
        echo "Checkov is not installed"
        exit 0
    fi

    echo "This will remove:"
    [ -d "$INSTALL_DIR" ] && echo "  - Virtual environment: $INSTALL_DIR"
    [ -f "$WRAPPER_LINK" ] && echo "  - Wrapper script: $WRAPPER_LINK"
    echo ""

    if [ "$AUTO_YES" != "true" ]; then
        read -p "Continue with uninstallation? (y/N): " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Uninstallation cancelled"
            exit 0
        fi
    fi

    # Remove virtual environment
    if [ -d "$INSTALL_DIR" ]; then
        echo "Removing virtual environment..."
        rm -rf "$INSTALL_DIR"
        echo -e "${GREEN}✓${NC} Virtual environment removed"
    fi

    # Remove wrapper
    if [ -f "$WRAPPER_LINK" ]; then
        echo "Removing wrapper script..."
        rm -f "$WRAPPER_LINK"
        echo -e "${GREEN}✓${NC} Wrapper script removed"
    fi

    echo ""
    echo -e "${GREEN}Uninstallation complete${NC}"
}

# Upgrade command
do_upgrade() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Checkov Upgrade${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    if [ ! -d "$INSTALL_DIR" ]; then
        echo -e "${RED}ERROR: Checkov is not installed${NC}" >&2
        echo "Run: $(basename "$0") install" >&2
        exit 1
    fi

    # Get current version
    local current_version=$("$INSTALL_DIR/bin/checkov" --version 2>&1 | head -n 1)
    echo "Current version: $current_version"
    echo ""
    echo "Upgrading checkov..."

    # Activate and upgrade
    source "$INSTALL_DIR/bin/activate"
    pip install --upgrade checkov --quiet
    deactivate

    # Get new version
    local new_version=$("$INSTALL_DIR/bin/checkov" --version 2>&1 | head -n 1)

    echo ""
    echo -e "${GREEN}✓${NC} Upgrade complete"
    echo "New version: $new_version"
}

# Status command
do_status() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Checkov Installation Status${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Check Python
    if command -v python3 &> /dev/null; then
        local python_version=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:2])))')
        echo -e "Python: ${GREEN}✓${NC} $python_version"
    else
        echo -e "Python: ${RED}✗${NC} Not installed"
    fi

    # Check virtual environment
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "Virtual Environment: ${GREEN}✓${NC} $INSTALL_DIR"
    else
        echo -e "Virtual Environment: ${RED}✗${NC} Not found"
    fi

    # Check wrapper
    if [ -f "$WRAPPER_LINK" ]; then
        echo -e "Wrapper Script: ${GREEN}✓${NC} $WRAPPER_LINK"
    else
        echo -e "Wrapper Script: ${RED}✗${NC} Not found"
    fi

    # Check if checkov is accessible
    if command -v checkov &> /dev/null; then
        local version=$(checkov --version 2>&1 | head -n 1)
        echo -e "Checkov Command: ${GREEN}✓${NC} $version"
    else
        echo -e "Checkov Command: ${RED}✗${NC} Not in PATH"
    fi

    echo ""

    # Installation status summary
    if [ -d "$INSTALL_DIR" ] && [ -f "$WRAPPER_LINK" ]; then
        echo -e "${GREEN}Status: Installed${NC}"
        check_path
    else
        echo -e "${YELLOW}Status: Not installed or incomplete${NC}"
        echo ""
        echo "To install, run:"
        echo -e "${BLUE}$(basename "$0") install${NC}"
    fi
}

# Main execution
main() {
    local command=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            install|uninstall|upgrade|status|-h|--help|help)
                if [ -n "$command" ]; then
                    echo "ERROR: Multiple commands specified: $command and $1" >&2
                    exit 1
                fi
                command="$1"
                shift
                ;;
            -y|--yes)
                AUTO_YES="true"
                shift
                ;;
            --force)
                FORCE_RECREATE="true"
                shift
                ;;
            *)
                echo "ERROR: Unknown argument: $1" >&2
                echo ""
                show_help
                exit 1
                ;;
        esac
    done

    case "$command" in
        install)
            do_install
            ;;
        uninstall)
            do_uninstall
            ;;
        upgrade)
            do_upgrade
            ;;
        status)
            do_status
            ;;
        -h|--help|help)
            show_help
            ;;
        "")
            echo "ERROR: No command specified" >&2
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
