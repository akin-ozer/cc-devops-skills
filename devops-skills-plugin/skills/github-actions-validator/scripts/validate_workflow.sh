#!/bin/bash
# GitHub Actions Validator - Workflow Validation Script
# Validates GitHub Actions workflows using actionlint and act
# Includes version checking and reference file hints

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${SCRIPT_DIR}/.tools"
SKILL_DIR="$(dirname "${SCRIPT_DIR}")"
REFERENCES_DIR="${SKILL_DIR}/references"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
    echo ""
}

log_reference() {
    echo -e "${CYAN}[REF]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! docker info &> /dev/null 2>&1; then
        return 1
    fi
    return 0
}

# Pre-check Docker status and inform user early
precheck_docker() {
    if ! check_docker; then
        log_warn "Docker is not running - act testing will be skipped"
        log_info "To enable full validation, start Docker Desktop or Docker daemon"
        log_info "Continuing with actionlint validation only..."
        echo ""
        return 1
    fi
    return 0
}

# Current recommended action versions (December 2025)
# Format: action_name:current_version:minimum_version
declare -A ACTION_VERSIONS=(
    ["actions/checkout"]="v6:v4"
    ["actions/setup-node"]="v6:v4"
    ["actions/setup-python"]="v5:v4"
    ["actions/setup-java"]="v4:v4"
    ["actions/setup-go"]="v5:v4"
    ["actions/cache"]="v4:v4"
    ["actions/upload-artifact"]="v4:v4"
    ["actions/download-artifact"]="v4:v4"
    ["docker/setup-buildx-action"]="v3:v3"
    ["docker/login-action"]="v3:v3"
    ["docker/build-push-action"]="v6:v5"
    ["docker/metadata-action"]="v5:v5"
    ["aws-actions/configure-aws-credentials"]="v4:v4"
)

# Extract major version from version string (v4.1.1 -> 4, v4 -> 4)
get_major_version() {
    local version=$1
    # Remove 'v' prefix and get first number
    echo "$version" | sed 's/^v//' | cut -d'.' -f1
}

# Check action versions in workflow files
check_action_versions() {
    local workflow_path=$1
    log_section "Action Version Check"

    local files_to_check=()

    if [ -f "$workflow_path" ]; then
        files_to_check+=("$workflow_path")
    elif [ -d "$workflow_path" ]; then
        while IFS= read -r -d '' file; do
            files_to_check+=("$file")
        done < <(find "$workflow_path" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null)
    fi

    if [ ${#files_to_check[@]} -eq 0 ]; then
        log_warn "No workflow files found to check"
        return 0
    fi

    local has_issues=0
    local outdated_count=0
    local deprecated_count=0
    local uptodate_count=0

    for file in "${files_to_check[@]}"; do
        log_info "Checking: $file"

        # Extract all 'uses:' statements
        while IFS= read -r line; do
            # Skip empty lines and comments
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue

            # Extract action reference (e.g., actions/checkout@v4 or actions/checkout@sha)
            if [[ "$line" =~ uses:[[:space:]]*([^@]+)@([^[:space:]#]+) ]]; then
                local action="${BASH_REMATCH[1]}"
                local version="${BASH_REMATCH[2]}"

                # Clean up action name (remove quotes if present)
                action=$(echo "$action" | tr -d '"' | tr -d "'" | xargs)

                # Check if this action is in our version database
                if [[ -v ACTION_VERSIONS["$action"] ]]; then
                    local version_info="${ACTION_VERSIONS[$action]}"
                    local current_version="${version_info%%:*}"
                    local minimum_version="${version_info##*:}"

                    local current_major=$(get_major_version "$current_version")
                    local minimum_major=$(get_major_version "$minimum_version")

                    # Handle SHA pinning - extract version from comment if present
                    local used_major=""
                    if [[ "$version" =~ ^[0-9a-f]{40}$ ]] || [[ "$version" =~ ^[0-9a-f]{7,}$ ]]; then
                        # SHA pinning - try to find version in the same line or comment
                        if [[ "$line" =~ v([0-9]+) ]]; then
                            used_major="${BASH_REMATCH[1]}"
                        else
                            # Can't determine version from SHA, skip
                            echo "  ⚪ ${action}@${version:0:12}... - SHA pinned (version unknown)"
                            continue
                        fi
                    else
                        used_major=$(get_major_version "$version")
                    fi

                    if [ -z "$used_major" ] || ! [[ "$used_major" =~ ^[0-9]+$ ]]; then
                        echo "  ⚪ ${action}@${version} - Unable to parse version"
                        continue
                    fi

                    if [ "$used_major" -lt "$minimum_major" ]; then
                        echo -e "  ${RED}❌${NC} ${action}@${version} - ${RED}DEPRECATED${NC} (minimum: ${minimum_version}, using: v${used_major})"
                        ((deprecated_count++))
                        has_issues=1
                    elif [ "$used_major" -lt "$current_major" ]; then
                        echo -e "  ${YELLOW}⚠️${NC}  ${action}@${version} - ${YELLOW}OUTDATED${NC} (current: ${current_version}, using: v${used_major})"
                        ((outdated_count++))
                    else
                        echo -e "  ${GREEN}✅${NC} ${action}@${version} - UP-TO-DATE (current: ${current_version})"
                        ((uptodate_count++))
                    fi
                fi
            fi
        done < "$file"
    done

    echo ""
    log_info "Version Check Summary:"
    log_info "  Up-to-date: $uptodate_count"
    if [ $outdated_count -gt 0 ]; then
        log_warn "  Outdated: $outdated_count"
    fi
    if [ $deprecated_count -gt 0 ]; then
        log_error "  Deprecated: $deprecated_count"
    fi

    if [ $outdated_count -gt 0 ] || [ $deprecated_count -gt 0 ]; then
        echo ""
        log_info "Recommendations:"
        if [ $deprecated_count -gt 0 ]; then
            log_error "  - Update deprecated actions immediately (v3 -> v4)"
        fi
        if [ $outdated_count -gt 0 ]; then
            log_warn "  - Consider updating outdated actions for latest features"
        fi
        log_info "  - Use SHA pinning for security: action@SHA # vX.Y.Z"
    fi

    return $has_issues
}

# Show reference file hints based on error type
show_reference_hints() {
    local error_output=$1
    echo ""
    log_section "Reference Documentation"

    local showed_hint=0

    # Check for various error patterns and suggest references
    if echo "$error_output" | grep -qi "syntax\|yaml\|unexpected"; then
        log_reference "Syntax errors detected - see references/common_errors.md (Syntax Errors section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "expression\|\${{"; then
        log_reference "Expression errors detected - see references/common_errors.md (Expression Errors section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "cron\|schedule"; then
        log_reference "Schedule errors detected - see references/common_errors.md (Schedule Errors section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "runner\|runs-on\|ubuntu\|macos\|windows"; then
        log_reference "Runner label issues - see references/runners.md"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "action\|uses:"; then
        log_reference "Action issues detected - see references/common_errors.md (Action Errors section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "docker\|container"; then
        log_reference "Docker/container issues - see references/act_usage.md (Troubleshooting section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "needs:\|dependency\|job"; then
        log_reference "Job dependency issues - see references/common_errors.md (Job Configuration Errors section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "injection\|security\|secret\|untrusted"; then
        log_reference "Security issues detected - see references/common_errors.md (Security section)"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "workflow_call\|reusable\|oidc\|id-token\|attestation\|environment:\|permissions:"; then
        log_reference "Modern features - see references/modern_features.md"
        showed_hint=1
    fi

    if echo "$error_output" | grep -qi "version\|deprecated\|outdated\|v[0-9]"; then
        log_reference "Action versions - see references/action_versions.md"
        showed_hint=1
    fi

    if [ $showed_hint -eq 0 ]; then
        log_reference "General troubleshooting - see references/common_errors.md"
    fi
}

# Check if tools are installed
check_tools() {
    local missing_tools=0

    if [ ! -f "${TOOLS_DIR}/actionlint" ] && ! command -v actionlint &> /dev/null; then
        log_error "actionlint not found. Please run install_tools.sh first."
        missing_tools=1
    fi

    if [ ! -f "${TOOLS_DIR}/act" ] && ! command -v act &> /dev/null; then
        log_error "act not found. Please run install_tools.sh first."
        missing_tools=1
    fi

    if [ $missing_tools -eq 1 ]; then
        log_info "Run: bash ${SCRIPT_DIR}/install_tools.sh"
        exit 1
    fi
}

# Get the appropriate tool path
get_tool_path() {
    local tool_name=$1

    if [ -f "${TOOLS_DIR}/${tool_name}" ]; then
        echo "${TOOLS_DIR}/${tool_name}"
    elif command -v "${tool_name}" &> /dev/null; then
        command -v "${tool_name}"
    else
        log_error "${tool_name} not found"
        exit 1
    fi
}

# Validate workflow with actionlint
validate_with_actionlint() {
    local workflow_path=$1
    log_section "Running actionlint"

    local actionlint_path=$(get_tool_path "actionlint")

    if [ -f "$workflow_path" ]; then
        log_info "Validating: $workflow_path"
        if "${actionlint_path}" "$workflow_path" 2>&1; then
            log_info "✓ actionlint validation passed"
            return 0
        else
            log_error "✗ actionlint found issues"
            return 1
        fi
    elif [ -d "$workflow_path" ]; then
        log_info "Validating all workflows in: $workflow_path"

        # Find all .yml and .yaml files
        local workflow_files=()
        while IFS= read -r -d '' file; do
            workflow_files+=("$file")
        done < <(find "$workflow_path" -maxdepth 1 -type f \( -name "*.yml" -o -name "*.yaml" \) -print0 2>/dev/null)

        if [ ${#workflow_files[@]} -eq 0 ]; then
            log_warn "No workflow files found in: $workflow_path"
            return 0
        fi

        if "${actionlint_path}" "${workflow_files[@]}" 2>&1; then
            log_info "✓ actionlint validation passed for ${#workflow_files[@]} file(s)"
            return 0
        else
            log_error "✗ actionlint found issues"
            return 1
        fi
    else
        log_error "Path not found: $workflow_path"
        return 1
    fi
}

# Test workflow with act
test_with_act() {
    local workflow_path=$1
    log_section "Running act (validation)"

    # Check if Docker is running
    if ! check_docker; then
        log_error "Docker is not running!"
        log_warn "act requires Docker to validate and test workflows."
        log_warn ""
        log_warn "Solutions:"
        log_warn "  1. Start Docker Desktop or Docker daemon"
        log_warn "  2. Use --lint-only flag to skip act testing"
        log_warn ""
        return 1
    fi

    local act_path=$(get_tool_path "act")

    # Convert workflow_path to absolute path
    local abs_workflow_path="$workflow_path"
    if [[ ! "$abs_workflow_path" = /* ]]; then
        abs_workflow_path="$(cd "$(dirname "$workflow_path")" 2>/dev/null && pwd)/$(basename "$workflow_path")" || abs_workflow_path="$workflow_path"
    fi

    # Find the repository root (where .github/workflows exists)
    local repo_root=""
    local search_path="$abs_workflow_path"

    # If workflow_path is a file, get its directory for searching
    if [ -f "$search_path" ]; then
        search_path="$(dirname "$search_path")"
    fi

    # Search upwards for .github/workflows directory
    local current_dir="$search_path"
    while [ "$current_dir" != "/" ]; do
        if [ -d "$current_dir/.github/workflows" ]; then
            repo_root="$current_dir"
            break
        fi
        # Also check if we're inside .github/workflows
        if [[ "$current_dir" == *"/.github/workflows"* ]] || [[ "$current_dir" == *"/.github/workflows" ]]; then
            # Extract the part before .github
            repo_root="${current_dir%%/.github/workflows*}"
            if [ -d "$repo_root/.github/workflows" ]; then
                break
            fi
        fi
        current_dir="$(dirname "$current_dir")"
    done

    # Fallback to current directory
    if [ -z "$repo_root" ] && [ -d "./.github/workflows" ]; then
        repo_root="$(pwd)"
    fi

    if [ -z "$repo_root" ]; then
        log_warn "No .github/workflows directory found in path hierarchy"
        log_warn "Skipping act validation - workflows must be in .github/workflows/ directory"
        log_info "Searched from: $workflow_path"
        return 0
    fi

    log_info "Repository root: $repo_root"

    # Determine the workflow file(s) to validate with act
    # act requires workflows to be in .github/workflows/ directory
    local workflow_flag=""
    local target_description=""

    if [ -f "$abs_workflow_path" ]; then
        # Check if the file is inside .github/workflows
        if [[ "$abs_workflow_path" == *"/.github/workflows/"* ]]; then
            # File is in .github/workflows - use -W flag with relative path
            workflow_flag="-W ${abs_workflow_path#$repo_root/}"
            target_description="workflow: $(basename "$abs_workflow_path")"
        else
            # File is outside .github/workflows (e.g., examples/)
            # act cannot directly validate files outside .github/workflows
            log_warn "Target file is outside .github/workflows/: $abs_workflow_path"
            log_warn "act can only validate workflows in .github/workflows/ directory"
            log_info "Skipping act validation for this file"
            log_info "Note: actionlint validation still applies to this file"
            return 0
        fi
    elif [ -d "$abs_workflow_path" ]; then
        # Directory specified
        if [[ "$abs_workflow_path" == *"/.github/workflows"* ]] || [[ "$abs_workflow_path" == "$repo_root/.github/workflows" ]]; then
            # It's the .github/workflows directory - validate all workflows
            workflow_flag=""
            target_description="all workflows in .github/workflows/"
        else
            # Directory outside .github/workflows
            log_warn "Target directory is outside .github/workflows/: $abs_workflow_path"
            log_warn "act can only validate workflows in .github/workflows/ directory"
            log_info "Skipping act validation for this directory"
            return 0
        fi
    fi

    # Save current directory
    local original_dir="$(pwd)"

    # Change to repository root for act
    cd "$repo_root" || {
        log_error "Failed to change to repository root: $repo_root"
        return 1
    }

    log_info "Target: $target_description"
    log_info "Step 1: Listing workflows..."
    echo ""

    # Define default runner images to avoid interactive prompts
    # Using medium-sized images for good compatibility without huge downloads
    local runner_images=(
        "-P" "ubuntu-latest=catthehacker/ubuntu:act-latest"
        "-P" "ubuntu-22.04=catthehacker/ubuntu:act-22.04"
        "-P" "ubuntu-20.04=catthehacker/ubuntu:act-20.04"
    )

    # Use --list to show available workflows
    # This validates that workflows can be parsed
    local list_cmd="${act_path} --list ${workflow_flag} ${runner_images[*]}"
    log_info "Running: act --list ${workflow_flag}"
    if ! eval "${list_cmd}" 2>&1 | head -30; then
        log_warn "Could not list workflows - this may indicate parsing issues"
        echo ""
    else
        echo ""
        log_info "✓ Workflow listing successful"
    fi

    echo ""
    log_info "Step 2: Validating workflow syntax with dry-run..."
    log_info "Note: This validates workflow structure without executing jobs"
    log_info "Using medium-sized runner images (catthehacker/ubuntu:act-*)"
    echo ""

    # Run act in dry-run mode
    # --dryrun: validates without executing
    # --container-architecture: ensures consistent platform
    # -W: specifies the workflow file to validate
    # -P: specifies runner images to avoid interactive prompt
    # 2>&1: capture both stdout and stderr
    local act_output
    local act_exit_code

    local dryrun_cmd="${act_path} --dryrun ${workflow_flag} --container-architecture linux/amd64 ${runner_images[*]}"
    log_info "Running: act --dryrun ${workflow_flag} --container-architecture linux/amd64"
    act_output=$(eval "${dryrun_cmd}" 2>&1)
    act_exit_code=$?

    # Display output
    echo "$act_output"
    echo ""

    # Interpret results
    if [ $act_exit_code -eq 0 ]; then
        log_info "✓ act validation passed"
        cd "$original_dir"
        return 0
    else
        # Check for specific error conditions
        if echo "$act_output" | grep -qi "EOF"; then
            log_error "✗ act encountered EOF error"
            log_warn "This should not happen with -P flags set"
            log_info "Try running: act --list manually to diagnose"
            cd "$original_dir"
            return 1
        elif echo "$act_output" | grep -q "unable to get git repo"; then
            log_warn "Not a git repository - some act features limited"
            log_info "act validation completed with warnings"
            cd "$original_dir"
            return 0
        elif echo "$act_output" | grep -qi "pull access denied\|image.*not found"; then
            log_error "✗ Docker image pull failed"
            log_warn "Cannot pull runner images. This may be due to:"
            log_warn "  - Docker registry connectivity issues"
            log_warn "  - Rate limiting"
            log_warn "First-time run will download ~500MB of images"
            cd "$original_dir"
            return 1
        elif echo "$act_output" | grep -qi "error\|failed"; then
            log_error "✗ act validation failed (exit code: $act_exit_code)"
            log_warn "This may indicate:"
            log_warn "  - Workflow syntax errors"
            log_warn "  - Invalid action references"
            log_warn "  - Docker image issues"
            log_warn "  - Configuration problems"
            cd "$original_dir"
            return 1
        else
            log_warn "act completed with warnings (exit code: $act_exit_code)"
            cd "$original_dir"
            return 0
        fi
    fi
}

# Display usage
usage() {
    echo "Usage: $0 [OPTIONS] <workflow-file-or-directory>"
    echo ""
    echo "Options:"
    echo "  --lint-only       Run only actionlint validation"
    echo "  --test-only       Run only act testing (requires Docker)"
    echo "  --check-versions  Check action versions against recommended versions"
    echo "  --help            Display this help message"
    echo ""
    echo "Examples:"
    echo "  $0 .github/workflows/ci.yml"
    echo "  $0 .github/workflows/"
    echo "  $0 --lint-only .github/workflows/ci.yml"
    echo "  $0 --test-only .github/workflows/"
    echo "  $0 --check-versions .github/workflows/ci.yml"
    echo ""
    echo "Requirements:"
    echo "  - actionlint: For static analysis (installed via install_tools.sh)"
    echo "  - act: For workflow testing (installed via install_tools.sh)"
    echo "  - Docker: Required for act to run (must be running)"
    echo ""
    exit 0
}

# Main validation
main() {
    local workflow_path=""
    local lint_only=false
    local test_only=false
    local check_versions=false
    local docker_available=true

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --lint-only)
                lint_only=true
                shift
                ;;
            --test-only)
                test_only=true
                shift
                ;;
            --check-versions)
                check_versions=true
                shift
                ;;
            --help)
                usage
                ;;
            *)
                workflow_path=$1
                shift
                ;;
        esac
    done

    if [ -z "$workflow_path" ]; then
        log_error "No workflow file or directory specified"
        echo ""
        usage
    fi

    log_section "GitHub Actions Validator"
    log_info "Target: $workflow_path"

    check_tools

    # Pre-check Docker status (early warning)
    if [ "$lint_only" = false ] && [ "$check_versions" = false ]; then
        if ! precheck_docker; then
            docker_available=false
            lint_only=true  # Force lint-only mode if Docker unavailable
        fi
    fi

    local exit_code=0
    local validation_output=""

    # Run version check if requested
    if [ "$check_versions" = true ]; then
        if ! check_action_versions "$workflow_path"; then
            exit_code=1
        fi
        # If only checking versions, exit here
        if [ "$lint_only" = false ] && [ "$test_only" = false ]; then
            log_section "Version Check Complete"
            exit $exit_code
        fi
    fi

    # Run actionlint
    if [ "$test_only" = false ]; then
        # Capture output for reference hints (use local actionlint first, then fallback to PATH)
        local actionlint_cmd="${TOOLS_DIR}/actionlint"
        if [ ! -f "$actionlint_cmd" ]; then
            actionlint_cmd="actionlint"
        fi
        validation_output=$("$actionlint_cmd" "$workflow_path" 2>&1) || true

        if ! validate_with_actionlint "$workflow_path"; then
            exit_code=1
        fi
    fi

    # Run act (if Docker available and not lint-only)
    if [ "$lint_only" = false ] && [ "$docker_available" = true ]; then
        if ! test_with_act "$workflow_path"; then
            exit_code=1
        fi
    fi

    log_section "Validation Summary"
    if [ $exit_code -eq 0 ]; then
        log_info "✓ All validations passed"
    else
        log_error "✗ Some validations failed"

        # Show reference hints based on errors
        if [ -n "$validation_output" ]; then
            show_reference_hints "$validation_output"
        fi

        echo ""
        log_info "Tips:"
        log_info "  - Review error messages above"
        log_info "  - Use --lint-only to skip Docker-dependent tests"
        log_info "  - Use --check-versions to check for outdated actions"
        log_info "  - Check references/common_errors.md for solutions"
    fi

    exit $exit_code
}

main "$@"
