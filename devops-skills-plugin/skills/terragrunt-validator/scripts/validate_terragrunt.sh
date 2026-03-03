#!/bin/bash

# Terragrunt Validation Script
# This script performs comprehensive validation of Terragrunt configurations including:
# - HCL formatting checks
# - HCL input validation (new in 0.93+)
# - Terragrunt validation
# - Terraform validation
# - Linting with tflint
# - Security scanning with Trivy (preferred) or tfsec (legacy)
# - Dependency graph validation
#
# Designed for Terragrunt 0.93+ with the new CLI redesign

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_DIR_INPUT="${1:-.}"
# Convert to absolute path when target exists, keep input value otherwise
# so main() can print a friendly, consistent error message.
if [[ -d "$TARGET_DIR_INPUT" ]]; then
    TARGET_DIR=$(cd "$TARGET_DIR_INPUT" && pwd)
else
    TARGET_DIR="$TARGET_DIR_INPUT"
fi
SKIP_PLAN="${SKIP_PLAN:-false}"
SKIP_SECURITY="${SKIP_SECURITY:-false}"
SKIP_LINT="${SKIP_LINT:-false}"
SKIP_INPUT_VALIDATION="${SKIP_INPUT_VALIDATION:-false}"
SKIP_INIT="${SKIP_INIT:-false}"
SKIP_BACKEND_INIT="${SKIP_BACKEND_INIT:-false}"
SOFT_FAIL_SECURITY="${SOFT_FAIL_SECURITY:-false}"

# Security scanner preference (trivy, tfsec, checkov, or auto)
SECURITY_SCANNER="${SECURITY_SCANNER:-auto}"

# Build strict mode flag
STRICT_FLAG=""
if [[ "${TG_STRICT_MODE:-false}" == "true" ]]; then
    STRICT_FLAG="--strict-mode"
fi

print_header() {
    echo -e "\n${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Detect execution mode from Terragrunt files in target directory.
# Modes:
# - multi: nested terragrunt units exist
# - single: current dir is a single Terragrunt unit
# - root-only: root.hcl exists but no unit in current directory
# - none: no recognizable Terragrunt config found
detect_target_mode() {
    local has_direct_terragrunt=false
    local has_nested_terragrunt=false

    if [[ -f "$TARGET_DIR/terragrunt.hcl" || -f "$TARGET_DIR/terragrunt.stack.hcl" ]]; then
        has_direct_terragrunt=true
    fi

    if find "$TARGET_DIR" -mindepth 2 -type f \
        \( -name "terragrunt.hcl" -o -name "terragrunt.stack.hcl" \) \
        ! -path "*/.terragrunt-cache/*" | grep -q .; then
        has_nested_terragrunt=true
    fi

    if [[ "$has_nested_terragrunt" == "true" ]]; then
        echo "multi"
    elif [[ "$has_direct_terragrunt" == "true" ]]; then
        echo "single"
    elif [[ -f "$TARGET_DIR/root.hcl" ]]; then
        echo "root-only"
    else
        echo "none"
    fi
}

# Check if required tools are installed
check_dependencies() {
    print_header "Checking Dependencies"

    local missing_tools=()

    if ! command -v terragrunt &> /dev/null; then
        missing_tools+=("terragrunt")
    else
        local tg_version
        tg_version=$(terragrunt --version | head -n1)
        print_success "terragrunt $tg_version"

        # Check if version is >= 0.93 for new CLI
        if [[ "$tg_version" =~ v0\.([0-9]+) ]]; then
            local minor_version="${BASH_REMATCH[1]}"
            if (( minor_version < 93 )); then
                print_warning "Terragrunt version < 0.93 detected. Some new CLI features may not work."
                print_info "Consider upgrading to 0.93+ for best compatibility."
            fi
        fi
    fi

    if ! command -v terraform &> /dev/null; then
        if command -v tofu &> /dev/null; then
            print_success "opentofu $(tofu version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || tofu --version | head -n1)"
        else
            missing_tools+=("terraform or opentofu")
        fi
    else
        print_success "terraform $(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform --version | head -n1)"
    fi

    if [[ "$SKIP_LINT" != "true" ]] && ! command -v tflint &> /dev/null; then
        print_warning "tflint not found - skipping lint checks"
        SKIP_LINT=true
    elif [[ "$SKIP_LINT" != "true" ]]; then
        print_success "tflint $(tflint --version | head -n1)"
    fi

    # Check for security scanners
    if [[ "$SKIP_SECURITY" != "true" ]]; then
        local found_scanner=false

        if [[ "$SECURITY_SCANNER" == "auto" ]] || [[ "$SECURITY_SCANNER" == "trivy" ]]; then
            if command -v trivy &> /dev/null; then
                print_success "trivy $(trivy --version 2>&1 | head -n1)"
                SECURITY_SCANNER="trivy"
                found_scanner=true
            fi
        fi

        if [[ "$found_scanner" == "false" ]] && { [[ "$SECURITY_SCANNER" == "auto" ]] || [[ "$SECURITY_SCANNER" == "checkov" ]]; }; then
            if command -v checkov &> /dev/null; then
                print_success "checkov $(checkov --version 2>&1 | head -n1)"
                SECURITY_SCANNER="checkov"
                found_scanner=true
            fi
        fi

        if [[ "$found_scanner" == "false" ]] && { [[ "$SECURITY_SCANNER" == "auto" ]] || [[ "$SECURITY_SCANNER" == "tfsec" ]]; }; then
            if command -v tfsec &> /dev/null; then
                print_warning "tfsec found but is deprecated - consider migrating to Trivy"
                print_success "tfsec $(tfsec --version 2>&1 | head -n1)"
                SECURITY_SCANNER="tfsec"
                found_scanner=true
            fi
        fi

        if [[ "$found_scanner" == "false" ]]; then
            print_warning "No security scanner found (trivy, checkov, or tfsec) - skipping security checks"
            print_info "Install trivy: brew install trivy (macOS) or see https://trivy.dev"
            SKIP_SECURITY=true
        fi
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo -e "\nInstallation instructions:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                terragrunt)
                    echo "  - terragrunt: https://terragrunt.gruntwork.io/docs/getting-started/install/"
                    ;;
                "terraform or opentofu")
                    echo "  - terraform: https://developer.hashicorp.com/terraform/downloads"
                    echo "  - opentofu: https://opentofu.org/docs/intro/install/"
                    ;;
            esac
        done
        exit 1
    fi
}

# Format check
format_check() {
    print_header "HCL Format Check"

    cd "$TARGET_DIR"

    # Try new command first, fall back to old if needed
    if terragrunt hcl fmt --check 2>/dev/null; then
        print_success "All HCL files are properly formatted"
    elif terragrunt hcl format --check 2>/dev/null; then
        print_success "All HCL files are properly formatted"
    else
        print_error "HCL files are not properly formatted"
        echo -e "\nRun 'terragrunt hcl fmt' to fix formatting issues"
        return 1
    fi
}

# Validate HCL inputs (new in Terragrunt 0.93+)
validate_inputs() {
    print_header "HCL Input Validation"

    cd "$TARGET_DIR"

    local mode
    mode=$(detect_target_mode)
    local -a validate_cmd=()

    if [[ "$mode" == "multi" ]]; then
        validate_cmd=(terragrunt hcl validate --inputs --all)
        print_info "Running input validation across all units..."
    elif [[ "$mode" == "single" ]]; then
        validate_cmd=(terragrunt hcl validate --inputs)
        print_info "Running input validation on single unit..."
    elif [[ "$mode" == "root-only" ]]; then
        print_warning "No terragrunt.hcl in current directory for input validation"
        print_info "Root-only directory detected (root.hcl). Run this script in a unit directory or keep multi-unit layout."
        return 0
    else
        print_warning "No terragrunt.hcl files found for input validation"
        return 0
    fi

    # Run the validation command
    local output
    if output=$("${validate_cmd[@]}" 2>&1); then
        print_success "All inputs validated successfully"
    else
        local exit_code=$?
        # Check if it's a "command not found" error (127) or actual validation failure
        if [[ $exit_code -eq 127 ]]; then
            print_warning "Input validation command not available"
            print_info "This feature requires Terragrunt 0.93+"
        elif echo "$output" | grep -q "unknown command\|unknown flag"; then
            print_warning "Input validation not supported in this Terragrunt version"
            print_info "This feature requires Terragrunt 0.93+"
        else
            # Show the actual error for debugging
            echo "$output" | head -20
            print_warning "Input validation completed with warnings or errors"
            # Don't fail the entire validation for input warnings
        fi
    fi
}

# Validate Terragrunt configuration syntax
# Uses 'terragrunt hcl validate' which checks HCL structure without requiring
# Terraform providers or remote credentials.  This is distinct from format_check()
# (whitespace/indentation) and validate_inputs() (variable alignment).
validate_terragrunt() {
    print_header "Terragrunt Configuration Check"

    cd "$TARGET_DIR"

    # Check if .hcl files exist (exclude cache dirs to avoid false positives)
    if ! find . -name "*.hcl" -type f ! -path "*/.terragrunt-cache/*" | grep -q .; then
        print_error "No .hcl files found in $TARGET_DIR"
        return 1
    fi

    local output
    if output=$(terragrunt hcl validate 2>&1); then
        print_success "Terragrunt HCL syntax is valid"
    else
        local hcl_exit=$?
        # Command not found (127) or unknown command means pre-0.93 Terragrunt.
        # Fall back to format check as a best-effort proxy — it at least catches
        # structural HCL errors even though it is not a pure syntax validator.
        if [[ $hcl_exit -eq 127 ]] || echo "$output" | grep -q "unknown command"; then
            print_warning "terragrunt hcl validate not available (requires 0.93+), using format check as proxy"
            if terragrunt hcl fmt --check > /dev/null 2>&1 || terragrunt hcl format --check > /dev/null 2>&1; then
                print_success "Terragrunt configuration syntax appears valid (format check passed)"
            else
                print_warning "Configuration files may have formatting or syntax issues"
            fi
        else
            print_error "Terragrunt HCL syntax validation failed"
            echo "$output" | head -20
            return 1
        fi
    fi
}

# Validate Terraform configuration
validate_terraform() {
    print_header "Terraform Validation"

    cd "$TARGET_DIR"

    local mode
    mode=$(detect_target_mode)

    # For multi-unit directories, run init+validate across all units.
    if [[ "$mode" == "multi" ]]; then
        print_info "Multi-unit directory detected, using 'run --all validate'"

        if [[ "$SKIP_INIT" != "true" ]]; then
            local -a multi_init_cmd=(terragrunt)
            if [[ -n "$STRICT_FLAG" ]]; then
                multi_init_cmd+=("$STRICT_FLAG")
            fi
            multi_init_cmd+=(run --all init)

            if [[ "$SKIP_BACKEND_INIT" == "true" ]]; then
                multi_init_cmd+=("-backend=false")
                print_info "Backend initialization disabled for multi-unit init"
            fi

            if ! "${multi_init_cmd[@]}" 2>&1; then
                print_error "Terraform initialization failed across one or more units"
                return 1
            fi
        else
            print_info "Skipping terraform init step (SKIP_INIT=true)"
        fi

        local -a multi_validate_cmd=(terragrunt)
        if [[ -n "$STRICT_FLAG" ]]; then
            multi_validate_cmd+=("$STRICT_FLAG")
        fi
        multi_validate_cmd+=(run --all validate)

        if "${multi_validate_cmd[@]}" 2>&1; then
            print_success "Terraform configuration is valid across all units"
        else
            print_error "Terraform validation failed across one or more units"
            return 1
        fi
        return 0
    fi

    # For single unit directories
    if [[ "$mode" == "single" ]]; then
        # Initialize if needed unless explicitly skipped.
        if [[ "$SKIP_INIT" != "true" ]] && [ ! -d ".terraform" ] && [ ! -d ".terragrunt-cache" ]; then
            echo "Initializing Terraform..."
            local -a single_init_cmd=(terragrunt)
            if [[ -n "$STRICT_FLAG" ]]; then
                single_init_cmd+=("$STRICT_FLAG")
            fi
            single_init_cmd+=(init)
            if [[ "$SKIP_BACKEND_INIT" == "true" ]]; then
                single_init_cmd+=("-backend=false")
                print_info "Backend initialization disabled for single-unit init"
            fi

            if ! "${single_init_cmd[@]}" 2>&1; then
                print_error "Terraform initialization failed"
                return 1
            fi
        elif [[ "$SKIP_INIT" == "true" ]]; then
            print_info "Skipping terraform init step (SKIP_INIT=true)"
        fi

        local -a single_validate_cmd=(terragrunt)
        if [[ -n "$STRICT_FLAG" ]]; then
            single_validate_cmd+=("$STRICT_FLAG")
        fi
        single_validate_cmd+=(validate)

        if "${single_validate_cmd[@]}" 2>&1; then
            print_success "Terraform configuration is valid"
        else
            print_error "Terraform validation failed"
            return 1
        fi
    elif [[ "$mode" == "root-only" ]]; then
        print_warning "No terragrunt.hcl found for Terraform validation"
        print_info "Root-only directory detected (root.hcl). Run this script from a unit directory or a multi-unit parent."
    else
        print_error "No Terragrunt configuration files found in $TARGET_DIR"
        return 1
    fi
}

# Run tflint
run_tflint() {
    print_header "TFLint Analysis"

    cd "$TARGET_DIR"

    # Initialize tflint if .tflint.hcl exists
    if [ -f ".tflint.hcl" ]; then
        tflint --init 2>/dev/null || true
    fi

    if tflint --recursive 2>&1; then
        print_success "No linting issues found"
    else
        print_error "Linting issues detected"
        return 1
    fi
}

# Run security scan with the available scanner
run_security_scan() {
    print_header "Security Scan ($SECURITY_SCANNER)"

    cd "$TARGET_DIR"

    case "$SECURITY_SCANNER" in
        trivy)
            print_info "Using Trivy (recommended) for security scanning"
            if trivy config . --severity HIGH,CRITICAL --exit-code 1 2>&1; then
                print_success "No critical security issues found"
            else
                if [[ "$SOFT_FAIL_SECURITY" == "true" ]]; then
                    print_warning "Security issues detected but not failing build (SOFT_FAIL_SECURITY=true)"
                else
                    print_error "Security issues detected"
                    return 1
                fi
            fi
            ;;
        checkov)
            print_info "Using Checkov for security scanning"
            if checkov -d . --framework terraform 2>&1; then
                print_success "No critical security issues found"
            else
                if [[ "$SOFT_FAIL_SECURITY" == "true" ]]; then
                    print_warning "Security issues detected but not failing build (SOFT_FAIL_SECURITY=true)"
                else
                    print_error "Security issues detected"
                    return 1
                fi
            fi
            ;;
        tfsec)
            print_warning "Using tfsec (deprecated) - consider migrating to Trivy"
            print_info "Migration guide: https://github.com/aquasecurity/tfsec/blob/master/tfsec-to-trivy-migration-guide.md"
            if tfsec . 2>&1; then
                print_success "No critical security issues found"
            else
                if [[ "$SOFT_FAIL_SECURITY" == "true" ]]; then
                    print_warning "Security issues detected but not failing build (SOFT_FAIL_SECURITY=true)"
                else
                    print_error "Security issues detected"
                    return 1
                fi
            fi
            ;;
        *)
            print_warning "Unknown security scanner: $SECURITY_SCANNER"
            return 1
            ;;
    esac
}

# Generate and validate dependency graph
validate_dependencies() {
    print_header "Dependency Graph Validation"

    cd "$TARGET_DIR"

    # Check if dependencies are properly configured
    if find . -name "*.hcl" -type f ! -path "*/.terragrunt-cache/*" -exec grep -l "dependency" {} \; | grep -q .; then
        print_success "Dependency blocks found in configuration"

        # Try to generate DAG graph (new in 0.93+)
        if terragrunt dag graph > /dev/null 2>&1; then
            print_success "Dependency graph is valid (no cycles detected)"
        else
            print_info "Could not generate dependency graph"
            print_info "Use 'terragrunt run --all plan' to validate dependency resolution"
        fi
    else
        print_success "No dependencies to validate"
    fi
}

# Dry-run plan
run_plan() {
    print_header "Terragrunt Plan (Dry-Run)"

    cd "$TARGET_DIR"

    if [[ -n "$STRICT_FLAG" ]]; then
        print_info "Running with strict mode enabled"
    fi

    local mode
    mode=$(detect_target_mode)

    if [[ "$mode" == "multi" ]]; then
        echo "Running terragrunt run --all plan..."
        local -a plan_cmd=(terragrunt)
        if [[ -n "$STRICT_FLAG" ]]; then
            plan_cmd+=("$STRICT_FLAG")
        fi
        plan_cmd+=(run --all plan)

        if "${plan_cmd[@]}" 2>&1; then
            print_success "Plan generated successfully across all units"
        else
            print_error "Plan generation failed across one or more units"
            return 1
        fi
    elif [[ "$mode" == "single" ]]; then
        echo "Running terragrunt plan..."
        local -a plan_cmd=(terragrunt)
        if [[ -n "$STRICT_FLAG" ]]; then
            plan_cmd+=("$STRICT_FLAG")
        fi
        plan_cmd+=(plan -out=tfplan)

        if "${plan_cmd[@]}" 2>&1; then
            print_success "Plan generated successfully"
            echo -e "\nTo review the plan, run:"
            echo "  terragrunt show tfplan"
        else
            print_error "Plan generation failed"
            return 1
        fi
    else
        print_warning "No unit terragrunt.hcl found for plan step"
        print_info "Skipping plan in non-unit directory"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║   Terragrunt Validation Suite         ║${NC}"
    echo -e "${BLUE}║   (Designed for Terragrunt 0.93+)     ║${NC}"
    echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"

    if [[ -n "$STRICT_FLAG" ]]; then
        print_info "Strict mode enabled - deprecated features will cause errors"
    fi

    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Target directory does not exist: $TARGET_DIR"
        exit 1
    fi

    check_dependencies

    local exit_code=0

    # Run all checks
    format_check || exit_code=$?

    if [[ "$SKIP_INPUT_VALIDATION" != "true" ]]; then
        validate_inputs || true  # Don't fail on input validation (may not be available)
    fi

    validate_terragrunt || exit_code=$?
    validate_terraform || exit_code=$?

    if [[ "$SKIP_LINT" != "true" ]]; then
        run_tflint || exit_code=$?
    fi

    if [[ "$SKIP_SECURITY" != "true" ]]; then
        run_security_scan || exit_code=$?
    fi

    validate_dependencies || exit_code=$?

    if [[ "$SKIP_PLAN" != "true" ]]; then
        run_plan || exit_code=$?
    fi

    # Summary
    print_header "Validation Summary"
    if [ $exit_code -eq 0 ]; then
        print_success "All validation checks passed!"
    else
        print_error "Some validation checks failed. Please review the output above."
    fi

    exit $exit_code
}

# Show usage if --help is passed
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [TARGET_DIR]"
    echo ""
    echo "Validates Terragrunt configurations with comprehensive checks."
    echo "Designed for Terragrunt 0.93+ with the new CLI redesign."
    echo ""
    echo "Options:"
    echo "  TARGET_DIR              Directory containing Terragrunt files (default: current directory)"
    echo ""
    echo "Environment Variables:"
    echo "  SKIP_PLAN=true          Skip the terragrunt plan step"
    echo "  SKIP_SECURITY=true      Skip security scanning"
    echo "  SKIP_LINT=true          Skip linting with tflint"
    echo "  SKIP_INPUT_VALIDATION=true  Skip HCL input validation"
    echo "  SKIP_INIT=true          Skip terraform init step before validate"
    echo "  SKIP_BACKEND_INIT=true  Run terraform init with -backend=false"
    echo "  SOFT_FAIL_SECURITY=true Do not fail on scanner findings"
    echo "  SECURITY_SCANNER=X      Force specific scanner: trivy, checkov, tfsec, or auto (default)"
    echo "  TG_STRICT_MODE=true     Enable Terragrunt strict mode (errors on deprecated features)"
    echo ""
    echo "Security Scanners (in order of preference):"
    echo "  trivy   - Recommended, actively maintained (replaces tfsec)"
    echo "  checkov - Alternative with 750+ built-in policies"
    echo "  tfsec   - Legacy, deprecated (merged into Trivy)"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Validate current directory"
    echo "  $0 ./infrastructure                   # Validate specific directory"
    echo "  SKIP_PLAN=true $0                     # Skip plan generation"
    echo "  SECURITY_SCANNER=trivy $0             # Force Trivy for security"
    echo "  SKIP_BACKEND_INIT=true $0             # Avoid remote backend auth during init"
    echo "  TG_STRICT_MODE=true $0                # Enable strict mode"
    exit 0
fi

main
