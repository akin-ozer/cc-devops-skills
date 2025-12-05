#!/bin/bash
# Check for required Helm validation tools and provide installation instructions

set -e

echo "Checking for Helm chart validation tools..."
echo

MISSING_TOOLS=()
OPTIONAL_TOOLS=()

# Check for helm (required)
if ! command -v helm &> /dev/null; then
    echo "❌ helm not found (REQUIRED)"
    MISSING_TOOLS+=("helm")
else
    HELM_VERSION=$(helm version --short 2>/dev/null || helm version)
    echo "✅ helm found: $HELM_VERSION"

    # Check if Helm 3+
    if [[ ! "$HELM_VERSION" =~ v3\. ]]; then
        echo "⚠️  Warning: Helm 3+ is required. Found: $HELM_VERSION"
    fi
fi

# Check for yamllint (required)
if ! command -v yamllint &> /dev/null; then
    echo "❌ yamllint not found (REQUIRED)"
    MISSING_TOOLS+=("yamllint")
else
    echo "✅ yamllint found: $(yamllint --version)"
fi

# Check for kubeconform (required)
if ! command -v kubeconform &> /dev/null; then
    echo "❌ kubeconform not found (REQUIRED)"
    MISSING_TOOLS+=("kubeconform")
else
    echo "✅ kubeconform found: $(kubeconform -v)"
fi

# Check for kubectl (optional but recommended)
if ! command -v kubectl &> /dev/null; then
    echo "⚠️  kubectl not found (OPTIONAL - needed for cluster dry-run)"
    OPTIONAL_TOOLS+=("kubectl")
else
    echo "✅ kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"
fi

# Check for yq (optional but helpful)
if ! command -v yq &> /dev/null; then
    echo "⚠️  yq not found (OPTIONAL - helpful for YAML manipulation)"
    OPTIONAL_TOOLS+=("yq")
else
    echo "✅ yq found: $(yq --version)"
fi

# Check for helm-diff plugin (optional but helpful for upgrades)
if helm plugin list 2>/dev/null | grep -q "diff"; then
    echo "✅ helm-diff plugin found"
else
    echo "⚠️  helm-diff plugin not found (OPTIONAL - helpful for upgrade validation)"
    OPTIONAL_TOOLS+=("helm-diff")
fi

echo

if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo "✅ All required tools are installed!"

    if [ ${#OPTIONAL_TOOLS[@]} -gt 0 ]; then
        echo
        echo "⚠️  Optional tools missing: ${OPTIONAL_TOOLS[*]}"
        echo "   These tools provide additional functionality but are not required."
    fi

    exit 0
else
    echo "❌ Missing required tools: ${MISSING_TOOLS[*]}"
    echo
    echo "Installation instructions:"
    echo

    for tool in "${MISSING_TOOLS[@]}"; do
        case $tool in
            helm)
                echo "📦 helm:"
                echo "  macOS:    brew install helm"
                echo "  Linux:    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
                echo "  Windows:  choco install kubernetes-helm"
                echo "  Manual:   https://helm.sh/docs/intro/install/"
                echo
                ;;
            yamllint)
                echo "📦 yamllint:"
                echo "  macOS:    brew install yamllint"
                echo "  Linux:    pip install yamllint"
                echo "  Ubuntu:   apt-get install yamllint"
                echo "  Windows:  pip install yamllint"
                echo
                ;;
            kubeconform)
                echo "📦 kubeconform:"
                echo "  macOS:    brew install kubeconform"
                echo "  Linux:    Download from https://github.com/yannh/kubeconform/releases"
                echo "  Windows:  Download from https://github.com/yannh/kubeconform/releases"
                echo "  Or use:   go install github.com/yannh/kubeconform/cmd/kubeconform@latest"
                echo
                ;;
        esac
    done

    if [ ${#OPTIONAL_TOOLS[@]} -gt 0 ]; then
        echo
        echo "Optional tools installation:"
        echo

        for tool in "${OPTIONAL_TOOLS[@]}"; do
            case $tool in
                kubectl)
                    echo "📦 kubectl:"
                    echo "  macOS:    brew install kubectl"
                    echo "  Linux:    https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
                    echo "  Windows:  choco install kubernetes-cli"
                    echo
                    ;;
                yq)
                    echo "📦 yq:"
                    echo "  macOS:    brew install yq"
                    echo "  Linux:    Download from https://github.com/mikefarah/yq/releases"
                    echo "  Windows:  choco install yq"
                    echo
                    ;;
                helm-diff)
                    echo "📦 helm-diff plugin:"
                    echo "  helm plugin install https://github.com/databus23/helm-diff"
                    echo
                    ;;
            esac
        done
    fi

    exit 1
fi
