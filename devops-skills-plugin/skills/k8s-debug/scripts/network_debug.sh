#!/usr/bin/env bash
# Kubernetes Network Debugging Script
# Diagnoses pod/service connectivity with graceful fallbacks.

set -uo pipefail

REQUEST_TIMEOUT="${K8S_REQUEST_TIMEOUT:-15s}"
NAMESPACE="default"
POD_NAME=""

usage() {
    echo "Usage: $0 [namespace] <pod-name>"
    echo "Examples:"
    echo "  $0 my-pod"
    echo "  $0 default my-pod"
}

case "$#" in
    1)
        POD_NAME="$1"
        ;;
    2)
        NAMESPACE="$1"
        POD_NAME="$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac

timestamp_utc() {
    date -u +"%Y-%m-%d %H:%M:%S UTC"
}

section() {
    printf "\n## %s ##\n" "$1"
}

warn() {
    printf "WARN: %s\n" "$1" >&2
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

can_i() {
    local result
    result="$(kubectl_cmd auth can-i "$@" 2>/dev/null || true)"
    [ "$result" = "yes" ]
}

run_or_warn() {
    local description="$1"
    shift
    if ! "$@"; then
        warn "${description} failed; continuing."
        return 1
    fi
    return 0
}

run_pipe_or_warn() {
    local description="$1"
    local cmd="$2"
    if ! bash -o pipefail -c "$cmd"; then
        warn "${description} failed; continuing."
        return 1
    fi
    return 0
}

pod_exec() {
    kubectl_cmd exec "$POD_NAME" -n "$NAMESPACE" -- "$@"
}

if ! have_cmd kubectl; then
    echo "ERROR: kubectl is not installed or not in PATH." >&2
    exit 1
fi

if ! kubectl_cmd config current-context >/dev/null 2>&1; then
    echo "ERROR: No active Kubernetes context. Run 'kubectl config current-context' to troubleshoot." >&2
    exit 1
fi

if ! kubectl_cmd get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "ERROR: Namespace '$NAMESPACE' was not found or is not accessible." >&2
    exit 1
fi

if ! kubectl_cmd get pod "$POD_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "ERROR: Pod '$POD_NAME' in namespace '$NAMESPACE' was not found or is not accessible." >&2
    exit 1
fi

echo "========================================"
echo "Network Debugging for Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(timestamp_utc)"
echo "========================================"

section "PREFLIGHT"
run_or_warn "Current context check" kubectl_cmd config current-context
if ! can_i get pods -n "$NAMESPACE"; then
    warn "RBAC may block pod metadata reads in namespace '$NAMESPACE'."
fi
if ! can_i create pods/exec -n "$NAMESPACE"; then
    warn "RBAC may block 'kubectl exec'; in-pod checks may fail."
fi

section "POD NETWORK INFORMATION"
POD_IP="$(kubectl_cmd get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.podIP}' 2>/dev/null || true)"
HOST_IP="$(kubectl_cmd get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.hostIP}' 2>/dev/null || true)"
echo "Pod IP: ${POD_IP:-Unavailable}"
echo "Host IP: ${HOST_IP:-Unavailable}"
run_or_warn "Pod wide status query" kubectl_cmd get pod "$POD_NAME" -n "$NAMESPACE" -o wide

section "DNS CONFIGURATION"
run_or_warn "Pod DNS config read" pod_exec cat /etc/resolv.conf

section "DNS RESOLUTION TEST"
echo "Testing kubernetes.default.svc.cluster.local:"
if pod_exec nslookup kubernetes.default.svc.cluster.local 2>/dev/null; then
    :
elif pod_exec getent hosts kubernetes.default.svc.cluster.local 2>/dev/null; then
    :
else
    warn "DNS utilities are unavailable in the container or DNS lookup failed."
fi

section "NETWORK CONNECTIVITY TESTS"
echo "Testing connection to kubernetes.default.svc.cluster.local:"
if pod_exec wget --spider --timeout=5 https://kubernetes.default.svc.cluster.local 2>&1; then
    :
elif pod_exec curl -k -m 5 https://kubernetes.default.svc.cluster.local 2>&1; then
    :
else
    warn "Unable to test API connectivity from pod (missing curl/wget or blocked egress)."
fi

section "SERVICES IN NAMESPACE"
run_or_warn "Service list query" kubectl_cmd get svc -n "$NAMESPACE"

section "ENDPOINTS"
run_or_warn "Endpoint list query" kubectl_cmd get endpoints -n "$NAMESPACE"

section "NETWORK POLICIES"
run_or_warn "Network policy list query" kubectl_cmd get networkpolicies -n "$NAMESPACE"

section "POD NETWORK DETAILS"
run_pipe_or_warn "Pod describe network details query" "kubectl --request-timeout=\"$REQUEST_TIMEOUT\" describe pod \"$POD_NAME\" -n \"$NAMESPACE\" | grep -A 20 '^IP:'"

section "POD LABELS (FOR NETWORKPOLICY MATCHING)"
run_or_warn "Pod label query" kubectl_cmd get pod "$POD_NAME" -n "$NAMESPACE" --show-labels

section "IPTABLES RULES (IF ACCESSIBLE)"
if ! pod_exec iptables -L -n 2>/dev/null; then
    info "iptables output not available (requires privileged container/tools)."
fi

section "NETWORK INTERFACES"
if pod_exec ip addr 2>/dev/null; then
    :
elif pod_exec ifconfig 2>/dev/null; then
    :
else
    info "Network interface tools are not available in this container."
fi

section "ROUTING TABLE"
if pod_exec ip route 2>/dev/null; then
    :
elif pod_exec route 2>/dev/null; then
    :
else
    info "Routing table tools are not available in this container."
fi

section "COREDNS LOGS (LAST 20 LINES)"
if kubectl_cmd logs -n kube-system -l k8s-app=kube-dns --tail=20 2>/dev/null; then
    :
elif kubectl_cmd logs -n kube-system -l k8s-app=coredns --tail=20 2>/dev/null; then
    :
else
    warn "CoreDNS logs are not accessible."
fi

echo -e "\n========================================"
echo "Network debugging completed at $(timestamp_utc)"
echo "========================================"
