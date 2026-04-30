#!/usr/bin/env bash
# Kubernetes Cluster Health Check Script
# Performs comprehensive cluster diagnostics with graceful fallbacks.

set -uo pipefail

REQUEST_TIMEOUT="${K8S_REQUEST_TIMEOUT:-15s}"
STRICT_MODE=0

WARN_COUNT=0
CHECK_FAIL_COUNT=0
BLOCKED_COUNT=0

usage() {
    echo "Usage: $0 [--strict]"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --strict)
            STRICT_MODE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "ERROR: Unknown option '$1'." >&2
            usage
            exit 1
            ;;
        *)
            echo "ERROR: Unexpected positional argument '$1'." >&2
            usage
            exit 1
            ;;
    esac
done

timestamp_utc() {
    date -u +"%Y-%m-%d %H:%M:%S UTC"
}

section() {
    printf "\n## %s ##\n" "$1"
}

warn_raw() {
    printf "WARN: %s\n" "$1" >&2
}

warn() {
    warn_raw "$1"
    WARN_COUNT=$((WARN_COUNT + 1))
}

info() {
    printf "INFO: %s\n" "$1"
}

have_cmd() {
    command -v "$1" >/dev/null 2>&1
}

kubectl_cmd() {
    kubectl --request-timeout="$REQUEST_TIMEOUT" "$@"
}

run_or_warn() {
    local description="$1"
    shift
    if ! "$@"; then
        warn_raw "${description} failed; continuing."
        CHECK_FAIL_COUNT=$((CHECK_FAIL_COUNT + 1))
        return 1
    fi
    return 0
}

run_pipe_or_warn() {
    local description="$1"
    local cmd="$2"
    if ! bash -o pipefail -c "$cmd"; then
        warn_raw "${description} failed; continuing."
        CHECK_FAIL_COUNT=$((CHECK_FAIL_COUNT + 1))
        return 1
    fi
    return 0
}

blocked_exit() {
    local message="$1"
    BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
    printf "ERROR: %s\n" "$message" >&2
    exit 2
}

find_waiting_reason_pods() {
    local reason="$1"

    if have_cmd jq; then
        local output
        if ! output="$(
            kubectl_cmd get pods --all-namespaces -o json 2>/dev/null | \
                jq -r --arg reason "$reason" \
                    '.items[] | select(any(.status.containerStatuses[]?; .state.waiting?.reason == $reason)) | "\(.metadata.namespace)/\(.metadata.name)"'
        )"; then
            warn "Unable to query pods in waiting reason ${reason}."
            return 1
        fi
        if [ -n "$output" ]; then
            printf "%s\n" "$output"
        else
            echo "None found"
        fi
        return 0
    fi

    warn "jq is not installed; showing all non-running pods as fallback for ${reason}."
    kubectl_cmd get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
}

finalize_exit() {
    if [ "$BLOCKED_COUNT" -gt 0 ]; then
        return 2
    fi
    if [ "$CHECK_FAIL_COUNT" -gt 0 ]; then
        return 1
    fi
    if [ "$STRICT_MODE" -eq 1 ] && [ "$WARN_COUNT" -gt 0 ]; then
        return 1
    fi
    return 0
}

if ! have_cmd kubectl; then
    blocked_exit "kubectl is not installed or not in PATH."
fi

if ! kubectl_cmd config current-context >/dev/null 2>&1; then
    blocked_exit "No active Kubernetes context. Run 'kubectl config current-context' to troubleshoot."
fi

echo "========================================"
echo "Kubernetes Cluster Health Check"
echo "Timestamp: $(timestamp_utc)"
echo "========================================"

section "PREFLIGHT"
run_or_warn "Current context check" kubectl_cmd config current-context
if ! have_cmd jq; then
    info "jq is optional. Error-state filtering will use a broader fallback."
    warn "jq is not installed; waiting-reason filtering will fall back to non-running pod lists."
fi

section "CLUSTER INFO"
run_or_warn "Cluster info" kubectl_cmd cluster-info
run_pipe_or_warn "Cluster version" "kubectl --request-timeout=\"$REQUEST_TIMEOUT\" version --client=false 2>/dev/null || kubectl --request-timeout=\"$REQUEST_TIMEOUT\" version"

section "NODE STATUS"
run_or_warn "Node list" kubectl_cmd get nodes -o wide
echo -e "\nNode Conditions:"
run_or_warn "Node readiness condition query" kubectl_cmd get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

section "NODE RESOURCE USAGE"
run_or_warn "Node metrics (requires metrics-server)" kubectl_cmd top nodes

section "NAMESPACE OVERVIEW"
run_or_warn "Namespace list" kubectl_cmd get namespaces

section "PODS STATUS (ALL NAMESPACES)"
run_or_warn "Pod list" kubectl_cmd get pods --all-namespaces -o wide

section "PROBLEMATIC PODS"
run_or_warn "Non-running/non-succeeded pod list" kubectl_cmd get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

section "RECENT CLUSTER EVENTS"
run_pipe_or_warn "Recent events query" "kubectl --request-timeout=\"$REQUEST_TIMEOUT\" get events --all-namespaces --sort-by='.lastTimestamp' | tail -50"

section "DEPLOYMENTS"
run_or_warn "Deployment list" kubectl_cmd get deployments --all-namespaces

section "SERVICES"
run_or_warn "Service list" kubectl_cmd get services --all-namespaces

section "STATEFULSETS"
run_or_warn "StatefulSet list" kubectl_cmd get statefulsets --all-namespaces

section "DAEMONSETS"
run_or_warn "DaemonSet list" kubectl_cmd get daemonsets --all-namespaces

section "PERSISTENT VOLUME CLAIMS"
run_or_warn "PVC list" kubectl_cmd get pvc --all-namespaces

section "PERSISTENT VOLUMES"
run_or_warn "PV list" kubectl_cmd get pv

section "COMPONENT STATUS"
# componentstatuses is deprecated since k8s 1.19 but kept as the third fallback:
# /readyz and /healthz are unauthenticated on some restricted clusters, and on
# very old clusters (pre-1.19) componentstatuses is the only signal available.
run_pipe_or_warn "Component readiness endpoint query" "kubectl --request-timeout=\"$REQUEST_TIMEOUT\" get --raw='/readyz?verbose' 2>/dev/null || kubectl --request-timeout=\"$REQUEST_TIMEOUT\" get --raw='/healthz?verbose' 2>/dev/null || kubectl --request-timeout=\"$REQUEST_TIMEOUT\" get componentstatuses"

section "API SERVER HEALTH"
run_or_warn "API server health check" kubectl_cmd get '--raw=/healthz?verbose'

section "CRASHLOOPBACKOFF PODS"
run_or_warn "CrashLoopBackOff pod query" find_waiting_reason_pods "CrashLoopBackOff"

section "IMAGEPULLBACKOFF PODS"
run_or_warn "ImagePullBackOff pod query" find_waiting_reason_pods "ImagePullBackOff"

section "NETWORK POLICIES"
run_or_warn "Network policy list" kubectl_cmd get networkpolicies --all-namespaces

section "RESOURCE QUOTAS"
run_or_warn "Resource quota list" kubectl_cmd get resourcequotas --all-namespaces

section "INGRESSES"
run_or_warn "Ingress list" kubectl_cmd get ingresses --all-namespaces

echo -e "\n========================================"
echo "Health check completed at $(timestamp_utc)"
echo "Warnings: $WARN_COUNT | Check failures: $CHECK_FAIL_COUNT | Blocked checks: $BLOCKED_COUNT"
echo "========================================"

finalize_exit
exit $?
