---
name: k8s-debug
description: "Use when diagnosing Kubernetes pods, workloads, services, DNS, networking, storage, scheduling, CrashLoopBackOff, Pending, or rollout failures."
---

# Kubernetes Debugging

## Purpose

Investigate a Kubernetes symptom from evidence to likely cause and propose the least risky remediation.

## Workflow

1. Confirm cluster context, namespace, affected resource, time window, and symptom. Start read-only.
2. Collect a narrow snapshot with `kubectl get/describe/logs/events` or the scripts in `scripts/`; expand only when evidence points to another layer.
3. Follow `references/troubleshooting_workflow.md`; open `common_issues.md` or `extended-guide.md` only for the observed failure class.
4. Correlate status, events, current and previous logs, owner references, endpoints, policies, nodes, and storage as relevant.
5. State the supported root cause, confidence, and a reversible remediation. Validate recovery only after an authorized change.

## Resources

- `scripts/pod_diagnostics.py`: pod evidence bundle
- `scripts/cluster_health.sh`, `network_debug.sh`: focused cluster/network snapshots
- `references/troubleshooting_workflow.md`: investigation order
- `references/common_issues.md`, `references/extended-guide.md`: symptom-specific detail

## Safety and gotchas

- Confirm context and namespace before every command; avoid broad all-namespace collection unless needed.
- Do not delete, restart, scale, cordon, drain, patch, exec, or expose resources without explicit authorization.
- Redact Secret data, tokens, environment values, and sensitive log lines.
- Treat a recent event list as incomplete; correlate timestamps and previous container logs.

## Validation

Validate conclusions against at least two independent signals where practical. Run `tests/test_regressions.sh` and `tests/test_pod_diagnostics.py` when changing helpers.

## Output

Provide symptom, scope/context, evidence, likely cause with confidence, safe remediation, verification commands, and remaining unknowns.
