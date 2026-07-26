---
name: k8s-yaml-generator
description: "Use when creating or updating Kubernetes manifests for workloads, services, ingress, configuration, RBAC, autoscaling, disruption budgets, or CRDs."
---

# Kubernetes YAML Generator

## Purpose

Generate Kubernetes manifests appropriate to the workload and target cluster. Use `k8s-yaml-validator` for review-only requests.

## Workflow

1. Inspect application/container metadata and existing manifests; determine namespace, workload kind, ports, probes, resources, config, storage, identity, and target Kubernetes version.
2. Clarify only material deployment and exposure choices.
3. Read `resource_patterns.md` for the requested kinds and `security_patterns.md` for workload/RBAC decisions. Reuse the closest `examples/` file; open `extended-guide.md` for CRD and edge-case flows.
4. Generate the smallest cohesive manifest set with stable labels/selectors and explicit namespace boundaries.
5. Run `k8s-yaml-validator`, fix generator-owned findings, and rerun.

## Resources

- `references/resource_patterns.md`: resource composition
- `references/security_patterns.md`: pod and RBAC hardening
- `examples/`: known-good multi-resource patterns
- `references/extended-guide.md`: detailed generation and CRD lookup

## Safety and gotchas

- Never embed real Secret values; use placeholders or external-secret references.
- Avoid cluster-wide RBAC unless the requirement truly spans namespaces.
- Match selectors exactly and use immutable label choices.
- Verify deprecated API versions and CRD fields against the target cluster/operator.
- Do not apply generated manifests unless explicitly requested.

## Validation

Run `k8s-yaml-validator` and `tests/test_regression.sh`. Report schema, kubectl dry-run, CRD, and live-cluster coverage separately.

## Output

List resources/files, required images/config/secrets, assumptions, apply ordering if relevant, and validation results.
