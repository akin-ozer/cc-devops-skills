---
name: helm-generator
description: Comprehensive toolkit for generating best practice Helm charts and resources following current standards and conventions. Use this skill when creating new Helm charts, implementing Helm templates, or building Helm projects from scratch.
---

# Helm Chart Generator

## Overview

Generate production-ready Helm charts with best practices built-in. Create complete charts or individual resources with standard helpers, proper templating, and automatic validation.

**Official Documentation:**
- [Helm Docs](https://helm.sh/docs/) - Main documentation
- [Chart Best Practices](https://helm.sh/docs/chart_best_practices/) - Official best practices guide
- [Template Functions](https://helm.sh/docs/chart_template_guide/function_list/) - Built-in functions
- [Sprig Functions](http://masterminds.github.io/sprig/) - Extended function library

## When to Use This Skill

| Use helm-generator | Use OTHER skill |
|-------------------|-----------------|
| Create new Helm charts | **devops-skills:helm-validator**: Validate/lint existing charts |
| Generate Helm templates | **k8s-generator**: Raw K8s YAML (no Helm) |
| Convert K8s manifests to Helm | **k8s-debug**: Debug deployed resources |
| Implement CRDs in Helm | **k8s-yaml-validator**: Validate K8s manifests |

**Trigger phrases:** "create", "generate", "build", "scaffold" Helm charts/templates

## Chart Generation Workflow

### Stage 1: Understand Requirements

Gather information about:
- **Scope**: Full chart, specific resources, or manifest conversion
- **Application**: Name, image, ports, env vars, resources, scaling, storage
- **CRDs/Operators**: cert-manager, Prometheus Operator, Istio, etc.
- **Security**: RBAC, security contexts, network policies

**REQUIRED: Use `AskUserQuestion`** if any of these are missing or ambiguous:

| Missing Information | Question to Ask |
|---------------------|-----------------|
| Image repository/tag | "What container image should be used? (e.g., nginx:1.25)" |
| Service port | "What port does the application listen on?" |
| Resource limits | "What CPU/memory limits should be set? (e.g., 500m CPU, 512Mi memory)" |
| Probe endpoints | "What health check endpoints does the app expose? (e.g., /health, /ready)" |
| Scaling requirements | "Should autoscaling be enabled? If yes, min/max replicas and target CPU%?" |
| Workload type | "What workload type: Deployment, StatefulSet, or DaemonSet?" |
| Storage requirements | "Does the application need persistent storage? Size and access mode?" |

**Do NOT assume values** for critical settings. Ask first, then proceed.

### Stage 2: CRD Documentation Lookup

If custom resources are needed:

1. **Try context7 MCP first:**
   ```
   mcp__context7__resolve-library-id with operator name
   mcp__context7__get-library-docs with topic for CRD kind
   ```

2. **Fallback to WebSearch:**
   ```
   "<operator>" "<CRD-kind>" "<version>" kubernetes documentation spec
   ```

See `references/crd_patterns.md` for common CRD examples.

### Stage 3: Create Chart Structure

Use the scaffolding script:
```bash
bash scripts/generate_chart_structure.sh <chart-name> <output-directory> [options]
```

**Script options:**
- `--image <repo>` - Image repository (default: nginx). **Note:** Pass only the repository name without tag (e.g., `redis` not `redis:7-alpine`)
- `--port <number>` - Service port (default: 80)
- `--type <type>` - Workload type: deployment, statefulset, daemonset (default: deployment)
- `--with-templates` - Generate resource templates (deployment.yaml, service.yaml, etc.)
- `--with-ingress` - Include ingress template
- `--with-hpa` - Include HPA template
- `--force` - Overwrite existing chart without prompting

**Important customization notes:**
- The script uses `http` as the default port name in templates. **Customize port names** for non-HTTP services (e.g., `redis`, `mysql`, `grpc`)
- Templates include checksum annotations for ConfigMap/Secret changes (conditionally enabled via `.Values.configMap.enabled` and `.Values.secret.enabled`)

**Standard structure:**
```
mychart/
  Chart.yaml           # Chart metadata (apiVersion: v2)
  values.yaml          # Default configuration
  values.schema.json   # Optional: JSON Schema validation
  templates/
    _helpers.tpl       # Standard helpers (ALWAYS create)
    NOTES.txt          # Post-install notes
    deployment.yaml    # Workloads
    service.yaml       # Services
    ingress.yaml       # Ingress (conditional)
    configmap.yaml     # ConfigMaps
    serviceaccount.yaml # RBAC
  .helmignore          # Ignore patterns
```

### Stage 4: Generate Standard Helpers

Use the helpers script or `assets/_helpers-template.tpl`:
```bash
bash scripts/generate_standard_helpers.sh <chart-name> <chart-directory>
```

**Required helpers:** `name`, `fullname`, `chart`, `labels`, `selectorLabels`, `serviceAccountName`

### Stage 5: Generate Templates

> **⚠️ CRITICAL REQUIREMENT: Read Reference Files NOW**
>
> You **MUST** use the `Read` tool to load these reference files **at this stage**, even if you read them earlier in the conversation:
>
> ```
> 1. Read references/resource_templates.md - for the specific resource type patterns
> 2. Read references/helm_template_functions.md - for template function usage
> 3. Read references/crd_patterns.md - if generating CRD resources (ServiceMonitor, Certificate, etc.)
> ```
>
> **Why:** Prior context may be incomplete or summarized. Reading reference files at generation time guarantees all patterns, functions, and examples are available for accurate template creation.
>
> **Do NOT skip this step.** Template quality depends on having current reference patterns loaded.

Reference templates for all resource types in `references/resource_templates.md`:
- Workloads: Deployment, StatefulSet, DaemonSet, Job, CronJob
- Services: Service, Ingress
- Config: ConfigMap, Secret
- RBAC: ServiceAccount, Role, RoleBinding, ClusterRole, ClusterRoleBinding
- Network: NetworkPolicy
- Autoscaling: HPA, PodDisruptionBudget

**Key patterns (MUST include in all templates):**
```yaml
# Use helpers for names and labels
metadata:
  name: {{ include "mychart.fullname" . }}
  labels: {{- include "mychart.labels" . | nindent 4 }}

# Conditional sections with 'with'
{{- with .Values.nodeSelector }}
nodeSelector: {{- toYaml . | nindent 2 }}
{{- end }}

# Config change restart trigger (ALWAYS add to workloads)
annotations:
  checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
```

**Checksum annotation is REQUIRED** for Deployments/StatefulSets/DaemonSets to trigger pod restarts when ConfigMaps or Secrets change. Add conditionally if ConfigMap is optional:
```yaml
{{- if .Values.configMap.enabled }}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
{{- end }}
```

### Stage 6: Create values.yaml

**Structure guidelines:**
- Group related settings logically
- Document every value with `# --` comments
- Provide sensible defaults
- Include security contexts, resource limits, probes

See `assets/values-schema-template.json` for JSON Schema validation.

### Stage 7: Validate

**ALWAYS validate** using devops-skills:helm-validator skill:
```
1. helm lint
2. helm template (render check)
3. YAML/schema validation
4. Dry-run if cluster available
```

Fix issues and re-validate until all checks pass.

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

**Conditional patterns:**
```yaml
{{- if .Values.enabled }}...{{- end }}
{{- if not .Values.autoscaling.enabled }}replicas: {{ .Values.replicaCount }}{{- end }}
```

**Iteration:**
```yaml
{{- range .Values.items }}
- {{ . }}
{{- end }}
```

## Working with CRDs

See `references/crd_patterns.md` for complete examples.

**Key points:**
- CRDs you ship → `crds/` directory (not templated, not deleted on uninstall)
- CR instances → `templates/` directory (fully templated)
- Always lookup documentation for CRD spec requirements
- Document operator dependencies in Chart.yaml annotations

## Converting Manifests to Helm

1. **Parameterize:** Names → helpers, values → `values.yaml`
2. **Apply patterns:** Labels, conditionals, `toYaml` for complex objects
3. **Add helpers:** Create `_helpers.tpl` with standard helpers
4. **Validate:** Use devops-skills:helm-validator, test with different values

## Error Handling

| Issue | Solution |
|-------|----------|
| Template syntax errors | Check `{{-` / `-}}` matching, use `helm template --debug` |
| Undefined values | Use `default` or `required` functions |
| Indentation issues | Use `nindent` consistently |
| CRD validation fails | Verify apiVersion, check docs for required fields |

## Resources

### Scripts
| Script | Usage |
|--------|-------|
| `scripts/generate_chart_structure.sh` | `bash <script> <chart-name> <output-dir>` |
| `scripts/generate_standard_helpers.sh` | `bash <script> <chart-name> <chart-dir>` |

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

## Integration with devops-skills:helm-validator

After generating charts, **automatically invoke devops-skills:helm-validator** to ensure quality:
1. Generate chart/templates
2. Invoke devops-skills:helm-validator skill
3. Fix identified issues
4. Re-validate until passing