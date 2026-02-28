---
name: helm-generator
description: Comprehensive toolkit for generating best practice Helm charts and resources following current standards and conventions. Use this skill when creating new Helm charts, implementing Helm templates, or building Helm projects from scratch.
---

# Helm Chart Generator

## Overview

Generate production-ready Helm charts with deterministic scaffolding, standard helpers, reusable templates, and validation loops.

**Official Documentation:**
- [Helm Docs](https://helm.sh/docs/) - Main documentation
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/) - Official best practices guide
- [Template Functions](https://helm.sh/docs/chart_template_guide/function_list/) - Built-in functions
- [Sprig Functions](http://masterminds.github.io/sprig/) - Extended function library

## When to Use This Skill

| Use helm-generator | Use OTHER skill |
|-------------------|-----------------|
| Create new Helm charts | **helm-validator**: Validate/lint existing charts |
| Generate Helm templates | **k8s-yaml-generator**: Raw K8s YAML (no Helm) |
| Convert K8s manifests to Helm | **k8s-debug**: Debug deployed resources |
| Implement CRDs in Helm | **k8s-yaml-validator**: Validate K8s manifests |

### Trigger Phrases

Use this skill when prompts include phrases like:
- "create Helm chart"
- "scaffold Helm chart"
- "generate Helm templates"
- "convert manifests to Helm chart"
- "build chart with Deployment/Service/Ingress"

## Execution Flow

Follow these stages in order. Do not skip required stages.

### Stage 1: Gather Requirements (Required)

Collect:
- Scope: full chart, specific templates, or conversion from manifests
- Workload: `deployment`, `statefulset`, or `daemonset`
- Image reference: repository, optional tag, or digest
- Ports: service port and container target port (separate values)
- Runtime settings: resources, probes, autoscaling, ingress, storage
- Security: service account, security contexts, optional RBAC/network policies

Use `request_user_input` when critical fields are missing.

If `request_user_input` is unavailable, ask in normal chat and continue with explicit assumptions.

| Missing Information | Question to Ask |
|---------------------|-----------------|
| Image repository/tag | "What container image should be used? (e.g., nginx:1.25)" |
| Service port | "What service port should be exposed?" |
| Container target port | "What container port should traffic be forwarded to?" |
| Resource limits | "What CPU/memory limits should be set? (e.g., 500m CPU, 512Mi memory)" |
| Probe endpoints | "What health check endpoints does the app expose? (e.g., /health, /ready)" |
| Scaling requirements | "Should autoscaling be enabled? If yes, min/max replicas and target CPU%?" |
| Workload type | "What workload type: Deployment, StatefulSet, or DaemonSet?" |
| Storage requirements | "Does the application need persistent storage? Size and access mode?" |

Do not silently assume critical settings.

### Stage 2: Lookup CRD Documentation (Only if CRDs Are In Scope)

1. Try Context7 first:
   - `mcp__context7__resolve-library-id`
   - `mcp__context7__query-docs`
2. Fallback chain if Context7 is unavailable or incomplete:
   - Operator official docs (preferred)
   - General web search

Also consult `references/crd_patterns.md` for example patterns.

### Stage 3: Scaffold Chart Structure (Required)

Run:
```bash
bash scripts/generate_chart_structure.sh <chart-name> <output-directory> [options]
```

Options:
- `--image <repo>` - Supports repo-only, tagged image, registry ports, and digest refs
- `--port <number>` - Service port (default: 80)
- `--target-port <number>` - Container target port (default: 8080)
- `--type <type>` - Workload type: deployment, statefulset, daemonset (default: deployment)
- `--with-templates` - Generate resource templates (deployment.yaml, service.yaml, etc.)
- `--with-ingress` - Include ingress template
- `--with-hpa` - Include HPA template
- `--force` - Overwrite existing chart without prompting

Image parsing behavior:
- `--image nginx:1.27` -> repository `nginx`, tag `1.27`
- `--image registry.local:5000/team/app` -> repository kept intact
- `--image ghcr.io/org/app@sha256:...` -> digest mode (no tag concatenation)
- `--tag` cannot be combined with digest image references

Idempotency and overwrite behavior:
- `generate_chart_structure.sh`: prompts before overwrite; `--force` overwrites non-interactively.
- `generate_standard_helpers.sh`: prompts before replacing `templates/_helpers.tpl`; `--force` bypasses prompt.

Expected scaffold shape:
```
mychart/
  Chart.yaml
  values.yaml
  templates/
    _helpers.tpl
    NOTES.txt
    serviceaccount.yaml
    service.yaml
    configmap.yaml
    secret.yaml
    deployment.yaml|statefulset.yaml|daemonset.yaml
    ingress.yaml (optional)
    hpa.yaml (optional)
  .helmignore
```

### Stage 4: Generate Standard Helpers

Run:
```bash
bash scripts/generate_standard_helpers.sh <chart-name> <chart-directory>
```

Required helpers: `name`, `fullname`, `chart`, `labels`, `selectorLabels`, `serviceAccountName`.

Fallback:
- If script execution is blocked, copy `assets/_helpers-template.tpl` and replace `CHARTNAME` with the chart name.

### Stage 5: Consult References and Generate Templates (Required)

Consult relevant references once at this stage:
- `references/resource_templates.md` for the resource patterns being generated
- `references/helm_template_functions.md` for templating function usage
- `references/crd_patterns.md` only when CRDs are in scope

Example file-open commands:
```bash
sed -n '1,220p' references/resource_templates.md
sed -n '1,220p' references/helm_template_functions.md
```

Resource coverage from `references/resource_templates.md`:
- Workloads: Deployment, StatefulSet, DaemonSet, Job, CronJob
- Services: Service, Ingress
- Config: ConfigMap, Secret
- RBAC: ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding
- Network: NetworkPolicy
- Autoscaling: HPA, PodDisruptionBudget

Required template patterns:
```yaml
metadata:
  name: {{ include "mychart.fullname" . }}
  labels: {{- include "mychart.labels" . | nindent 4 }}

{{- with .Values.nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}

annotations:
  {{- if and .Values.configMap .Values.configMap.enabled }}
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
  {{- end }}
```

Checksum annotations are required for workloads, but must be conditional and only reference generated templates (`configmap.yaml`, `secret.yaml`).

### Stage 6: Create values.yaml

Structure guidelines:
- Group related settings logically
- Document every value with `# --` comments
- Provide sensible defaults
- Include security contexts, resource limits, probes
- Keep `service.port` and `service.targetPort` separate and explicit
- Keep `configMap.enabled` / `secret.enabled` aligned with generated templates

See `assets/values-schema-template.json` for JSON Schema validation.

### Stage 7: Validate

Preferred path: run the `helm-validator` skill.

If skill invocation is unavailable, run local commands directly:
```bash
helm lint <chart-dir>
helm template test <chart-dir>
```

If `helm` is unavailable, report the block clearly and perform partial checks:
- `bash -n scripts/generate_chart_structure.sh`
- `bash -n scripts/generate_standard_helpers.sh`
- Verify generated files and key fields manually

Re-run validation after any fixes.

## Template Functions Quick Reference

See `references/helm_template_functions.md` for complete guide.

| Function | Purpose | Example |
|----------|---------|---------|
| `required` | Enforce required values | `{{ required "msg" .Values.x }}` |
| `default` | Fallback value | `{{ .Values.x \| default 1 }}` |
| `quote` | Quote strings | `{{ .Values.x \| quote }}` |
| `include` | Use helpers | `{{ include "name" . \| nindent 4 }}` |
| `toYaml` | Convert to YAML | `{{ toYaml .Values.x \| nindent 2 }}` |
| `tpl` | Render as template | `{{ tpl .Values.config . }}` |
| `nindent` | Newline + indent | `{{- include "x" . \| nindent 4 }}` |

## Working with CRDs

See `references/crd_patterns.md` for complete examples.

Key points:
- CRDs you ship -> `crds/` directory (not templated, not deleted on uninstall)
- CR instances -> `templates/` directory (fully templated)
- Always look up documentation for CRD spec requirements
- Document operator dependencies in Chart.yaml annotations

## Converting Manifests to Helm

1. **Parameterize:** Names -> helpers, values -> `values.yaml`
2. **Apply patterns:** Labels, conditionals, `toYaml` for complex objects
3. **Add helpers:** Create `_helpers.tpl` with standard helpers
4. **Validate:** Run `helm-validator` (or local lint/template fallback), then test with different values

## Error Handling

| Issue | Solution |
|-------|----------|
| Template syntax errors | `helm template test <chart-dir> --debug --show-only templates/<file>.yaml` |
| Undefined values | `helm lint <chart-dir> --strict` and add `default`/`required` |
| Checksum include errors | Ensure `templates/configmap.yaml` and `templates/secret.yaml` exist and `configMap.enabled` / `secret.enabled` are set correctly |
| Port mismatch (Service vs container) | Set both `service.port` and `service.targetPort`, then re-run `helm template test <chart-dir>` |
| CRD validation fails | Verify apiVersion/spec fields with Context7 or operator docs, then re-render |
| Script argument failures | Run `bash scripts/generate_chart_structure.sh --help` and pass required values for option flags |

## Example Flows

Full scaffold with templates, ingress, HPA, and explicit port mapping:
```bash
bash scripts/generate_chart_structure.sh webapp ./charts \
  --image ghcr.io/acme/webapp:2.3.1 \
  --port 80 \
  --target-port 8080 \
  --type deployment \
  --with-templates \
  --with-ingress \
  --with-hpa
```

Digest-based image scaffold:
```bash
bash scripts/generate_chart_structure.sh api ./charts \
  --image ghcr.io/acme/api@sha256:0123456789abcdef \
  --with-templates
```

Minimal scaffold without templates:
```bash
bash scripts/generate_chart_structure.sh starter ./charts
```

## Scaffold Success Criteria

Mark complete only when all checks pass:
- [ ] `Chart.yaml`, `values.yaml`, `.helmignore`, `templates/NOTES.txt`, and `templates/_helpers.tpl` exist
- [ ] `values.yaml` contains explicit `service.port` and `service.targetPort`
- [ ] If `--with-templates` was used, `serviceaccount.yaml`, `service.yaml`, `configmap.yaml`, `secret.yaml`, and one workload template exist
- [ ] Generated workload template uses conditional checksum annotations for config/secret
- [ ] Image rendering logic supports tag and digest modes
- [ ] Validation completed (`helm-validator` skill or local fallback commands) and outcomes reported

## Resources

### Scripts
| Script | Usage |
|--------|-------|
| `scripts/generate_chart_structure.sh` | `bash scripts/generate_chart_structure.sh <chart-name> <output-dir> [options]` |
| `scripts/generate_standard_helpers.sh` | `bash scripts/generate_standard_helpers.sh <chart-name> <chart-dir> [--force]` |

### References
| File | Content |
|------|---------|
| `references/helm_template_functions.md` | Complete template function guide |
| `references/resource_templates.md` | All K8s resource templates |
| `references/crd_patterns.md` | CRD patterns (cert-manager, Prometheus, Istio, ArgoCD) |

### Assets
| File | Purpose |
|------|---------|
| `assets/_helpers-template.tpl` | Standard helpers template |
| `assets/values-schema-template.json` | JSON Schema for values validation |

## Integration with helm-validator

After generating charts, invoke `helm-validator` and close the loop:
1. Generate chart/templates
2. Run `helm-validator` (or local fallback commands)
3. Fix identified issues
4. Re-validate until passing
