---
name: k8s-yaml-generator
description: Comprehensive toolkit for generating, validating, and managing Kubernetes YAML resources. Use this skill when creating Kubernetes manifests (Deployments, Services, ConfigMaps, StatefulSets, etc.), working with Custom Resource Definitions (CRDs), or generating production-ready K8s configurations.
---

# Kubernetes YAML Generator

Generate Kubernetes manifests with deterministic steps, bounded CRD research, and mandatory validation for full-resource output.

## Trigger Guidance

Use this skill when the user asks to create or update Kubernetes YAML, for example:

- "Generate a Deployment + Service manifest for my app."
- "Create an Argo CD Application CRD."
- "Write a StatefulSet with PVC templates."
- "Produce production-ready Kubernetes YAML with best practices."

Do not use this skill for validation-only requests. For validation-only work, use `k8s-yaml-validator`.

## Execution Model

Normative keywords:

- `MUST`: required
- `SHOULD`: default unless user requests otherwise
- `MAY`: optional

Deterministic sequence:

1. Preflight request and path/rendering sanity.
2. Capture minimum required inputs.
3. Resolve CRD references (bounded workflow only when CRD/custom API is involved).
4. Generate YAML with baseline quality checks.
5. Run mandatory validation (or documented fallback path when tooling is unavailable).
6. Deliver YAML plus explicit validation report and assumptions.

If one step is blocked by environment constraints, execute that step's fallback and continue.

## 1) Preflight

Before generation:

- Confirm whether output is full manifest(s) or snippet-only.
- Confirm target Kubernetes version when provided.
- Verify any referenced local file path exists before using it.
- Normalize resource naming to DNS-1123-compatible names where applicable.

Preflight stop condition:

- If required core inputs are missing (resource type, workload image for Pod-based resources, or CRD kind/apiVersion), ask for those first.

## 2) Capture Required Inputs

Collect:

- Resource types (`Deployment`, `Service`, `ConfigMap`, CRD kind, etc.)
- `apiVersion` + `kind`
- Namespace/scoping requirements
- Ports, replicas, images, probes, storage, and secret/config needs
- Environment assumptions (dev/staging/prod)
- For CRDs: project name and target CRD version if known

Safe defaults (state explicitly in output):

- Namespace: `default` (namespace-scoped resources)
- Deployment replicas: `2`
- Service type: `ClusterIP`
- Image pull policy: `IfNotPresent` (unless user needs forced pulls)

## 3) CRD Lookup Workflow (Bounded)

Run this step only for custom APIs outside Kubernetes built-in groups.

### 3.1 Identify CRD target

Extract:

- API group, version, kind (for example `argoproj.io/v1alpha1`, `Application`)
- Requested product/version (for example Argo CD `v2.9.x`)

### 3.2 Context7 primary path

Use the correct Context7 tools and payloads:

1. `mcp__context7__resolve-library-id`
2. `mcp__context7__query-docs`

Sample payloads:

```text
Tool: mcp__context7__resolve-library-id
libraryName: "argo-cd"
query: "Find Argo CD documentation for Application CRD schema compatibility"
```

```text
Tool: mcp__context7__query-docs
libraryId: "/argoproj/argo-cd/v2.9.0"
query: "Application CRD required spec fields for apiVersion argoproj.io/v1alpha1 with minimal valid example"
```

Selection rules:

- Prefer exact project/library name matches.
- Prefer versioned `libraryId` when user specifies a version.
- Otherwise use unversioned ID and note version uncertainty.

### 3.3 Thresholds and stop conditions

Bound the lookup to prevent unbounded retries:

- `resolve-library-id`: max 2 attempts (primary name + one alternate name).
- `query-docs`: max 3 focused queries total.
- Web fallback: max 2 version-specific searches.

Stop early when all are true:

- Required CRD fields are identified.
- At least one authoritative example is found.
- Version compatibility is known or explicitly marked unknown.

Hard stop when budgets are exhausted:

- Generate only fields verified by sources.
- Mark remaining fields as `Needs confirmation`.
- Report residual risk and request one of:
  - exact CRD docs URL, or
  - cluster introspection output (for example `kubectl explain <kind>.spec` when available).

### 3.4 Fallback order

Use this order:

1. Context7 (`resolve-library-id` -> `query-docs`)
2. Official project docs via web search
3. Cluster-local introspection (`kubectl explain`, if cluster access exists)

If none are available, provide a minimal, clearly marked draft and do not claim full CRD correctness.

## 4) YAML Generation Rules

Apply these checks:

- Use explicit, non-deprecated API versions.
- Include consistent labels (`app.kubernetes.io/*`) across related resources.
- Include namespace for namespace-scoped resources.
- Add resource requests/limits for Pod workloads unless user opts out.
- Add readiness/liveness probes for long-running services where applicable.
- Use `securityContext` to avoid root execution by default.
- Keep multi-resource ordering dependency-safe (for example ConfigMap before Deployment consumers).

Minimal label baseline:

```yaml
labels:
  app.kubernetes.io/name: myapp
  app.kubernetes.io/instance: myapp-prod
  app.kubernetes.io/part-of: myplatform
  app.kubernetes.io/managed-by: codex
```

## 5) Mandatory Validation and Contingencies

For full manifest generation, validation is mandatory.

Primary path:

- Invoke `k8s-yaml-validator`.
- Iterate fix -> revalidate until blocking issues are gone.

Required reporting after each validation pass:

- `Validation mode`: `k8s-yaml-validator` | `script fallback` | `manual fallback`
- `Syntax`: pass/fail
- `Schema`: pass/fail/partial
- `CRD check`: pass/fail/partial
- `Dry-run`: server/client/skipped
- `Blocking issues remaining`: yes/no

Contingency A: validator skill unavailable

Run direct commands:

```bash
bash devops-skills-plugin/skills/k8s-yaml-validator/scripts/setup_tools.sh
yamllint -c devops-skills-plugin/skills/k8s-yaml-validator/assets/.yamllint <file.yaml>
kubeconform -schema-location default -strict -ignore-missing-schemas -summary <file.yaml>
kubectl apply --dry-run=server -f <file.yaml> || kubectl apply --dry-run=client -f <file.yaml>
```

Contingency B: local tools partially unavailable

- Run available checks.
- Record skipped checks explicitly.
- Add residual risk for every skipped check.

Contingency C: repeated validation failure

- Maximum 3 fix/revalidate cycles.
- If still failing, stop and return:
  - current YAML,
  - exact failing errors,
  - smallest required user decision/input to unblock.

Validation exceptions:

- Snippet-only or docs-only requests MAY skip full validation, but the output MUST state `Validation status: Skipped (reason)`.

## 6) Delivery Contract

Final output MUST include:

1. Generated YAML.
2. What was generated (resource list, namespace/scoping).
3. Validation report in the required format.
4. Assumptions and defaults used.
5. References used:
   - Context7 IDs/queries used (for CRDs)
   - external docs/searches used
   - items skipped/missing and impact

Suggested next commands:

```bash
kubectl apply -f <filename>.yaml
kubectl get <resource-type> <name> -n <namespace>
kubectl describe <resource-type> <name> -n <namespace>
```

## 7) Canonical Example Flows

### Example A: Built-in resources (Deployment + Service)

1. Capture app image, ports, replicas, namespace.
2. Generate Deployment and Service with consistent labels/selectors.
3. Validate with `k8s-yaml-validator`.
4. Return YAML + validation report + assumptions.

### Example B: CRD resource (Argo CD Application)

1. Extract `argoproj.io/v1alpha1` + `Application`.
2. Run bounded Context7 lookup (`resolve-library-id` then `query-docs`).
3. If needed, perform bounded web fallback.
4. Generate CRD YAML only with verified fields.
5. Validate, report any partial verification, and return residual risks.

## 8) Definition of Done

Execution is complete only when all applicable checks pass:

- Trigger use case is correct (generation, not validation-only).
- Required inputs are captured or explicit assumptions are documented.
- CRD lookup follows bounded thresholds and stop conditions.
- Tool names and command paths are valid and consistent.
- Full manifests are validated (or fallback path is documented with residual risk).
- Final response includes YAML, validation report, assumptions, and references.
