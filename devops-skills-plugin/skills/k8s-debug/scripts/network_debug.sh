#!/bin/bash
# Kubernetes Network Debugging Script
# Helps diagnose network connectivity issues between pods and services

set -e

NAMESPACE="${1:-default}"
POD_NAME="${2}"

if [ -z "$POD_NAME" ]; then
    echo "Usage: $0 [namespace] <pod-name>"
    echo "Example: $0 default my-pod"
    exit 1
fi

echo "========================================"
echo "Network Debugging for Pod: $POD_NAME"
echo "Namespace: $NAMESPACE"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "========================================"

# Pod Network Info
echo -e "\n## POD NETWORK INFORMATION ##"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.podIP}{"\n"}'
POD_IP=$(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
echo "Host IP: $(kubectl get pod "$POD_NAME" -n "$NAMESPACE" -o jsonpath='{.status.hostIP}')"

# DNS Configuration
echo -e "\n## DNS CONFIGURATION ##"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- cat /etc/resolv.conf 2>/dev/null || echo "Unable to read DNS config"

# Test DNS Resolution
echo -e "\n## DNS RESOLUTION TEST ##"
echo "Testing kubernetes.default.svc.cluster.local:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- nslookup kubernetes.default.svc.cluster.local 2>/dev/null || \
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- getent hosts kubernetes.default.svc.cluster.local 2>/dev/null || \
echo "DNS resolution tools not available in pod"

# Network connectivity tests
echo -e "\n## NETWORK CONNECTIVITY TESTS ##"
echo "Testing connection to Kubernetes API:"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- wget --spider --timeout=5 https://kubernetes.default.svc.cluster.local 2>&1 || \
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- curl -k -m 5 https://kubernetes.default.svc.cluster.local 2>&1 || \
echo "Unable to test API connectivity"

# Service endpoints
echo -e "\n## SERVICES IN NAMESPACE ##"
kubectl get svc -n "$NAMESPACE"

echo -e "\n## ENDPOINTS ##"
kubectl get endpoints -n "$NAMESPACE"

# Network Policies affecting the pod
echo -e "\n## NETWORK POLICIES ##"
kubectl get networkpolicies -n "$NAMESPACE"

# Describe the pod's network setup
echo -e "\n## POD NETWORK DETAILS ##"
kubectl describe pod "$POD_NAME" -n "$NAMESPACE" | grep -A 20 "IP:"

# Check if pod has required labels for network policies
echo -e "\n## POD LABELS (for NetworkPolicy matching) ##"
kubectl get pod "$POD_NAME" -n "$NAMESPACE" --show-labels

# Iptables rules (if accessible)
echo -e "\n## IPTABLES RULES (if accessible) ##"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- iptables -L -n 2>/dev/null || echo "iptables not accessible (requires privileged pod)"

# Network interfaces
echo -e "\n## NETWORK INTERFACES ##"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- ip addr 2>/dev/null || \
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- ifconfig 2>/dev/null || \
echo "Network interface tools not available"

# Routing table
echo -e "\n## ROUTING TABLE ##"
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- ip route 2>/dev/null || \
kubectl exec "$POD_NAME" -n "$NAMESPACE" -- route 2>/dev/null || \
echo "Routing tools not available"

# CoreDNS logs (if accessible)
echo -e "\n## COREDNS LOGS (last 20 lines) ##"
kubectl logs -n kube-system -l k8s-app=kube-dns --tail=20 2>/dev/null || \
kubectl logs -n kube-system -l k8s-app=coredns --tail=20 2>/dev/null || \
echo "CoreDNS logs not accessible"

echo -e "\n========================================"
echo "Network debugging completed"
echo "========================================"
