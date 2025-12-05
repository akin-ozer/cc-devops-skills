#!/usr/bin/env bash

# Ansible FQCN (Fully Qualified Collection Name) Checker
# Identifies modules using short names instead of FQCN format
# Recommends migration to ansible.builtin.* or appropriate collection

set -e

TARGET="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_RESET='\033[0m'

# Usage check
if [ -z "$TARGET" ]; then
    echo "Usage: $0 <playbook.yml|role-directory|directory>"
    echo ""
    echo "Scans Ansible files for modules using short names instead of FQCN."
    echo "Recommends migration to fully qualified collection names for better"
    echo "clarity and future compatibility."
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
echo -e "${COLOR_BLUE}Ansible FQCN Module Checker${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo ""
echo "Scanning: $TARGET_ABS"
echo ""

# Common ansible.builtin modules that are often used with short names
BUILTIN_MODULES=(
    "apt"
    "yum"
    "dnf"
    "package"
    "pip"
    "copy"
    "file"
    "template"
    "lineinfile"
    "blockinfile"
    "replace"
    "fetch"
    "stat"
    "get_url"
    "uri"
    "service"
    "systemd"
    "user"
    "group"
    "command"
    "shell"
    "raw"
    "script"
    "debug"
    "set_fact"
    "assert"
    "fail"
    "include"
    "include_tasks"
    "include_vars"
    "import_tasks"
    "import_playbook"
    "import_role"
    "include_role"
    "pause"
    "wait_for"
    "wait_for_connection"
    "meta"
    "add_host"
    "group_by"
    "cron"
    "git"
    "setup"
    "gather_facts"
    "ping"
    "reboot"
    "hostname"
    "sysctl"
    "mount"
    "unarchive"
    "archive"
    "find"
    "slurp"
    "known_hosts"
    "authorized_key"
    "firewalld"
    "iptables"
    "selinux"
    "seboolean"
)

# Modules from common collections
COMMUNITY_GENERAL_MODULES=(
    "ufw"
    "homebrew"
    "zypper"
    "apk"
    "npm"
    "gem"
    "composer"
    "docker_container"
    "docker_image"
    "docker_network"
    "docker_volume"
    "docker_compose"
    "timezone"
    "locale_gen"
    "alternatives"
    "sysvinit"
    "jenkins_job"
    "jenkins_plugin"
    "nagios"
    "zabbix_host"
    "grafana_dashboard"
    "htpasswd"
    "lvol"
    "lvg"
    "parted"
    "filesystem"
)

ANSIBLE_POSIX_MODULES=(
    "synchronize"
    "acl"
    "authorized_key"
    "firewalld"
    "selinux"
    "seboolean"
    "at"
    "mount"
    "sysctl"
)

NON_FQCN_FOUND=0
declare -A FOUND_MODULES

# Function to check for non-FQCN module usage
check_module() {
    local module="$1"
    local fqcn="$2"
    local collection="$3"
    local results=""

    if [ "$SCAN_TYPE" = "file" ]; then
        # Match module at start of line with optional leading whitespace and dash
        results=$(grep -n -E "^\s*-?\s*${module}:" "$TARGET_ABS" 2>/dev/null | grep -v "${fqcn}" || true)
    else
        results=$(grep -r -n -E "^\s*-?\s*${module}:" "$TARGET_ABS" --include="*.yml" --include="*.yaml" 2>/dev/null | grep -v ".git/" | grep -v "${fqcn}" || true)
    fi

    if [ -n "$results" ]; then
        # Store unique occurrences
        if [ -z "${FOUND_MODULES[$module]}" ]; then
            FOUND_MODULES[$module]="$fqcn|$collection"
            NON_FQCN_FOUND=$((NON_FQCN_FOUND + 1))
            echo -e "${COLOR_YELLOW}[NON-FQCN]${COLOR_RESET} ${COLOR_CYAN}$module${COLOR_RESET} → ${COLOR_GREEN}$fqcn${COLOR_RESET}"
            echo "$results" | head -5 | while read -r line; do
                echo "  $line"
            done
            local count=$(echo "$results" | wc -l | tr -d ' ')
            if [ "$count" -gt 5 ]; then
                echo "  ... and $((count - 5)) more occurrences"
            fi
            echo ""
        fi
    fi
}

echo -e "${COLOR_BLUE}Checking for non-FQCN module usage...${COLOR_RESET}"
echo ""

# Check ansible.builtin modules
echo -e "${COLOR_BLUE}Checking ansible.builtin modules:${COLOR_RESET}"
echo ""
for module in "${BUILTIN_MODULES[@]}"; do
    check_module "$module" "ansible.builtin.${module}" "ansible.builtin"
done

# Check community.general modules
echo -e "${COLOR_BLUE}Checking community.general modules:${COLOR_RESET}"
echo ""
for module in "${COMMUNITY_GENERAL_MODULES[@]}"; do
    check_module "$module" "community.general.${module}" "community.general"
done

# Check ansible.posix modules
echo -e "${COLOR_BLUE}Checking ansible.posix modules:${COLOR_RESET}"
echo ""
for module in "${ANSIBLE_POSIX_MODULES[@]}"; do
    check_module "$module" "ansible.posix.${module}" "ansible.posix"
done

echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
echo -e "${COLOR_BLUE}FQCN Check Summary${COLOR_RESET}"
echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"

if [ $NON_FQCN_FOUND -eq 0 ]; then
    echo -e "${COLOR_GREEN}✓ All modules use FQCN format${COLOR_RESET}"
    echo ""
    echo "Great! Your Ansible code follows the recommended practice of using"
    echo "Fully Qualified Collection Names for all modules."
    exit 0
else
    echo -e "${COLOR_YELLOW}⚠ Found $NON_FQCN_FOUND module(s) using short names instead of FQCN${COLOR_RESET}"
    echo ""
    echo "Migration Summary:"
    echo "===================="
    for module in "${!FOUND_MODULES[@]}"; do
        IFS='|' read -r fqcn collection <<< "${FOUND_MODULES[$module]}"
        echo -e "  ${COLOR_CYAN}$module${COLOR_RESET} → ${COLOR_GREEN}$fqcn${COLOR_RESET}"
    done
    echo ""
    echo "Why migrate to FQCN?"
    echo "  1. Clarity: Explicitly shows which collection provides the module"
    echo "  2. Conflict Prevention: Avoids naming conflicts between collections"
    echo "  3. Future-Proofing: Prevents breakage when modules move between collections"
    echo "  4. Best Practice: Recommended by Ansible for all new playbooks"
    echo ""
    echo "Required Collections:"
    echo "  If using community.general modules:"
    echo "    ansible-galaxy collection install community.general"
    echo "  If using ansible.posix modules:"
    echo "    ansible-galaxy collection install ansible.posix"
    echo ""
    echo "For detailed migration guidance, see:"
    echo "  $SKILL_DIR/references/module_alternatives.md"
    echo ""
    echo "Note: This is a recommendation, not an error. Short names still work"
    echo "but may cause issues in future Ansible versions."
    exit 0
fi