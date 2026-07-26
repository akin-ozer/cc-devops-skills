---
name: helm-validator
description: "Use when linting, rendering, schema-checking, security-reviewing, or troubleshooting Helm charts, values, templates, and CRDs."
---

# Helm Validator

## Purpose

Validate chart structure, metadata, values, rendered Kubernetes resources, security posture, and CRD compatibility.

## Workflow

1. Resolve the chart and representative values files; inspect dependencies and target Kubernetes versions.
2. Run Helm lint and render paths described by the local scripts, then schema-check the rendered output.
3. Detect CRDs with `scripts/detect_crd_wrapper.sh` and consult authoritative version-matched schemas only for detected custom resources.
4. Read a focused file in `docs/` or `references/` only when a finding needs explanation; use `references/extended-guide.md` for advanced modes.
5. Apply fixes only when requested and rerun lint, render, and affected schema checks.

## Resources

- `scripts/validate_chart_structure.sh`: structural validation
- `scripts/detect_crd_wrapper.sh`: CRD discovery
- `docs/`, `references/`: focused Helm, security, and CRD guidance
- `references/extended-guide.md`: complete validation pipeline

## Safety and gotchas

- Rendering does not contact the cluster; server dry-run does. Do not use cluster access without authorization.
- Test meaningful values combinations because a chart can lint while conditional templates remain broken.
- Distinguish CRD schema unavailability from a valid custom resource.
- Redact rendered Secret data and sensitive values.

## Validation

Run `test/test_regression.sh` and `test/test_stage9_workload.sh` where dependencies are available. Report Helm, kubeconform, kubectl, schema, and cluster coverage separately.

## Output

Report chart/value inputs, findings by severity and template location, rendered-resource coverage, skipped checks, and post-fix results.
