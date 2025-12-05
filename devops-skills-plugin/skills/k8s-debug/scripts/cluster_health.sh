#!/bin/bash
# Kubernetes Cluster Health Check Script
# Performs comprehensive cluster health diagnostics

set -e

echo "========================================"
echo "Kubernetes Cluster Health Check"
echo "Timestamp: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "========================================"

# Cluster Info
echo -e "\n## CLUSTER INFO ##"
kubectl cluster-info
kubectl version --client=false 2>/dev/null || kubectl version

# Node Status
echo -e "\n## NODE STATUS ##"
kubectl get nodes -o wide
echo -e "\nNode Conditions:"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}'

# Node Resources
echo -e "\n## NODE RESOURCE USAGE ##"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

# All Namespaces Overview
echo -e "\n## NAMESPACE OVERVIEW ##"
kubectl get namespaces

# Pods Status Across All Namespaces
echo -e "\n## PODS STATUS (ALL NAMESPACES) ##"
kubectl get pods --all-namespaces -o wide

# Failed/Pending Pods
echo -e "\n## PROBLEMATIC PODS ##"
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded

# Recent Events (Last 50)
echo -e "\n## RECENT CLUSTER EVENTS ##"
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | tail -50

# Deployments Status
echo -e "\n## DEPLOYMENTS ##"
kubectl get deployments --all-namespaces

# Services Status
echo -e "\n## SERVICES ##"
kubectl get services --all-namespaces

# StatefulSets Status
echo -e "\n## STATEFULSETS ##"
kubectl get statefulsets --all-namespaces

# DaemonSets Status
echo -e "\n## DAEMONSETS ##"
kubectl get daemonsets --all-namespaces

# PersistentVolumeClaims
echo -e "\n## PERSISTENT VOLUME CLAIMS ##"
kubectl get pvc --all-namespaces

# PersistentVolumes
echo -e "\n## PERSISTENT VOLUMES ##"
kubectl get pv

# Component Status
echo -e "\n## COMPONENT STATUS ##"
kubectl get --raw='/readyz?verbose' 2>/dev/null || kubectl get --raw='/healthz?verbose' 2>/dev/null || kubectl get componentstatuses

# API Server Health
echo -e "\n## API SERVER HEALTH ##"
kubectl get --raw='/healthz?verbose' || echo "Unable to check API server health"

# Check for CrashLoopBackOff pods
echo -e "\n## CRASHLOOPBACKOFF PODS ##"
kubectl get pods --all-namespaces --field-selector=status.phase=Running -o json | \
  jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting?.reason=="CrashLoopBackOff") | "\(.metadata.namespace)/\(.metadata.name)"' || echo "None found"

# Check for ImagePullBackOff pods
echo -e "\n## IMAGEPULLBACKOFF PODS ##"
kubectl get pods --all-namespaces -o json | \
  jq -r '.items[] | select(.status.containerStatuses[]?.state.waiting?.reason=="ImagePullBackOff") | "\(.metadata.namespace)/\(.metadata.name)"' || echo "None found"

# Network Policies
echo -e "\n## NETWORK POLICIES ##"
kubectl get networkpolicies --all-namespaces 2>/dev/null || echo "No network policies or not available"

# Resource Quotas
echo -e "\n## RESOURCE QUOTAS ##"
kubectl get resourcequotas --all-namespaces

# Ingresses
echo -e "\n## INGRESSES ##"
kubectl get ingresses --all-namespaces

echo -e "\n========================================"
echo "Health check completed at $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
echo "========================================"
