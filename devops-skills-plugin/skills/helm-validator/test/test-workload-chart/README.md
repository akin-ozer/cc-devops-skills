# test-workload-chart

A test Helm chart with **intentional Stage 9 security violations** for use with the `helm-validator` skill.

## Purpose

This chart exists to exercise and demonstrate the **mandatory Stage 9 Security Best Practices Check** in the `helm-validator` skill workflow. It renders a valid `Deployment` that deliberately omits every security control the skill is expected to flag.

**Do NOT deploy this chart to any environment.**

## Intentional Violations

| Violation | Location | Expected Finding |
|-----------|----------|-----------------|
| `:latest` image tag | `values.yaml` → `image.tag` | Stage 9: image tag issue |
| Missing pod-level `securityContext` | `templates/deployment.yaml` → `spec.template.spec` | Stage 9: missing `runAsNonRoot`, `runAsUser`, `fsGroup` |
| Missing container-level `securityContext` | `templates/deployment.yaml` → `spec.template.spec.containers[0]` | Stage 9: missing `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` |
| Missing `resources` block | `templates/deployment.yaml` → `spec.template.spec.containers[0]` | Stage 9: no CPU/memory limits or requests |
| Missing `livenessProbe` | `templates/deployment.yaml` → `spec.template.spec.containers[0]` | Stage 9: no liveness probe |
| Missing `readinessProbe` | `templates/deployment.yaml` → `spec.template.spec.containers[0]` | Stage 9: no readiness probe |

## Running the Validation

```bash
# From the helm-validator skill directory:

# Stage 2: Structure check
bash scripts/validate_chart_structure.sh test/test-workload-chart

# Stage 3: Helm lint
helm lint test/test-workload-chart --strict

# Stage 4: Render templates
helm template test-release test/test-workload-chart --output-dir /tmp/workload-rendered

# Stage 5: YAML lint
find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec yamllint -c assets/.yamllint {} +

# Stage 6: CRD detection (expect: no CRDs)
find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec bash scripts/detect_crd_wrapper.sh {} +

# Stage 7: Schema validation
find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) -exec \
  kubeconform \
    -schema-location default \
    -summary -verbose \
    {} +

# Stage 9: Security check — all of the following should flag issues:
find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec grep -l "securityContext" {} +
# Expected: no output (no securityContext in any file)

find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec grep -l "resources:" {} +
# Expected: no output (no resources block)

find /tmp/workload-rendered -type f \( -name "*.yaml" -o -name "*.yml" \) \
  -exec grep "image:.*:latest" {} +
# Expected: matches nginx:latest in deployment.yaml
```

## Expected Stage 9 Report

```
| Check | Status | Detail |
|-------|--------|--------|
| Pod securityContext | ❌ Missing | runAsNonRoot, runAsUser, fsGroup absent |
| Container securityContext | ❌ Missing | allowPrivilegeEscalation, readOnlyRootFilesystem, capabilities.drop absent |
| Resource limits/requests | ❌ Missing | No cpu/memory limits or requests defined |
| Image tag | ❌ Warning | nginx:latest — pin to a specific version |
| Liveness probe | ❌ Missing | No livenessProbe defined |
| Readiness probe | ❌ Missing | No readinessProbe defined |
```
