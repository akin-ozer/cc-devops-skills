---
name: azure-pipelines-generator
description: Comprehensive toolkit for generating best practice Azure DevOps Pipelines following current standards and conventions. Use this skill when creating new Azure Pipelines, implementing CI/CD workflows, or building deployment pipelines.
---

# Azure Pipelines Generator

Generate production-ready Azure DevOps pipeline YAML with deterministic steps, explicit fallbacks, and clear completion criteria.

## Trigger Guidance

Use this skill when the user asks to generate or redesign Azure Pipelines YAML, for example:

- "Create `azure-pipelines.yml` for my Node service."
- "Build a multi-stage Azure DevOps pipeline with staging and production."
- "Generate Azure pipeline templates for reuse across repos."
- "Convert this CI flow to Azure Pipelines."

Do not use this skill for validation-only requests. For validation-only work, use `azure-pipelines-validator`.

## Execution Model

Normative keywords:

- `MUST`: required
- `SHOULD`: default unless user asks otherwise
- `MAY`: optional

Deterministic sequence:

1. Classify request mode.
2. Capture minimum required inputs.
3. Load minimum references (progressive disclosure).
4. Generate YAML using the quality checklist.
5. Validate (validator skill, script fallback, or manual fallback).
6. Return output in the required report format.

If a step cannot run due to environment limits, use the fallback in that step and continue.

## 1) Classify Request Mode

Choose exactly one primary mode:

- **Basic CI:** build/test/lint for one stack.
- **Multi-stage CI/CD:** build -> test -> deploy with environment tracking.
- **Docker:** image build/push and optional deploy.
- **Kubernetes:** image build/push plus Kubernetes deployment.
- **Language-specific:** .NET, Node.js, Python, Go, Java focused.
- **Template-based:** reusable templates plus thin root pipeline.
- **Snippet-only:** partial YAML requested, not full pipeline.

Mode-to-example mapping:

- Basic CI -> `examples/basic-ci.yml`
- Multi-stage CI/CD -> `examples/multi-stage-cicd.yml`
- .NET -> `examples/dotnet-cicd.yml`
- Python -> `examples/python-cicd.yml`
- Go -> `examples/go-cicd.yml`
- Kubernetes -> `examples/kubernetes-deploy.yml`
- Template-based -> `examples/template-usage.yml` + `examples/templates/*.yml`

## 2) Capture Required Inputs

Collect these before generation:

- App stack and package manager
- Build/test commands and report expectations
- Deployment target (none, Azure service, Docker registry, Kubernetes)
- Environment flow (dev/staging/prod) and branch gates
- Service connections, variable groups, secret handling
- Template requirement (yes/no)

Safe defaults when missing:

- CI branches: `main`, `develop`
- Production deploy branch: `main` only
- Agent image: pinned image (for example `ubuntu-22.04`)
- Deploy image tag: immutable (`$(Build.BuildId)`), never deploy `latest`

If key details are missing, state assumptions explicitly in final output.

## 3) Load References (Progressive Disclosure)

Read local references first.

Always read:

- `docs/yaml-schema.md`
- `docs/best-practices.md`

Read conditionally:

- `docs/tasks-reference.md` when selecting tasks/inputs
- `docs/templates-guide.md` only for template-based mode

Then read only the closest example(s) from the mode mapping above.

Fallback behavior for missing references:

- Missing example: use nearest mode example and note substitution.
- Missing doc section: continue with known conventions and mark uncertainty.
- Snippet-only request: read only the minimum needed for safe output.

The final response MUST include:

- `References used`
- `References skipped or missing`
- `Impact`

## 4) External Docs Escalation (Only When Needed)

Escalate beyond local docs only when:

- required task info is not in local docs
- task version compatibility is unclear
- troubleshooting a task-specific failure

Use this order:

1. Context7 (`mcp__context7__resolve-library-id` -> `mcp__context7__query-docs`)
2. Official docs search (Microsoft Learn first)

If network/tools are unavailable, proceed with best-known local guidance and add a residual-risk note.

## 5) Pipeline Generation Checklist

Apply all items below unless user asks for a narrow snippet.

Security:

- Never hardcode secrets.
- Use service connections and variable groups/secrets.
- Use immutable deploy image tags.

Versioning:

- Pin `vmImage` to explicit version, not `*-latest`.
- Pin task major versions (`Task@N`).
- `@0` is allowed only when that task uses major `0`.

Reliability:

- Use explicit `dependsOn`.
- Add `timeoutInMinutes` for long-running jobs.
- Use branch-gated deployment `condition` rules.
- Use deployment jobs with `environment` for deploy stages.

Performance:

- Use `Cache@2` where it improves dependency install time.
- Use shallow checkout when full history is not required.
- Publish only required artifacts.

Testing/observability:

- Run lint/tests in CI.
- Publish test results with `condition: succeededOrFailed()`.
- Publish coverage when available.

Maintainability:

- Add `displayName` for stages/jobs/key steps.
- Use templates when logic repeats.
- Add short comments only for non-obvious logic.

## 6) Validation Workflow

Default path (MUST for full pipeline generation):

1. Generate or update YAML.
2. Validate with `azure-pipelines-validator`.
3. Fix findings.
4. Re-run validation until no blocking issues remain.

Script fallback if validator skill is unavailable but local validator scripts exist:

```bash
bash devops-skills-plugin/skills/azure-pipelines-validator/scripts/validate_azure_pipelines.sh <pipeline-file>
```

Manual fallback when neither skill nor script can run:

1. YAML structure/indentation sanity
2. Hierarchy sanity (`stages -> jobs -> steps`)
3. Task format sanity (`Task@Major`)
4. Secret exposure scan (no plaintext credentials/tokens)
5. Deployment safety scan (environment usage, immutable deploy tags)

When fallback is used, final response MUST include:

- `Validation status: Manual fallback`
- `Checks performed`
- `Residual risk`

Validation MAY be skipped only for:

- snippet-only YAML
- documentation-only examples
- explicit user request to skip validation

## 7) Output Contract

Final response MUST include:

1. Pipeline YAML (or template set)
2. Required setup:
   - service connections
   - variable groups/secrets
   - environments and approvals/checks
3. Validation result:
   - validator status, script status, or manual fallback status
4. Assumptions
5. References used/skipped and impact
6. Optional next improvements

## 8) Canonical Example Flows

### Example A: Full multi-stage generation

1. Select mode: Multi-stage CI/CD.
2. Capture stack/deploy/service-connection inputs.
3. Read `docs/yaml-schema.md`, `docs/best-practices.md`, and `examples/multi-stage-cicd.yml`.
4. Add requested customizations (stages, branch gates, environments, tasks).
5. Validate with `azure-pipelines-validator`; fix and re-run.
6. Return YAML + setup + validation + assumptions + references.

### Example B: Quick snippet generation

1. Select mode: Snippet-only.
2. Read only the minimum required reference section.
3. Generate focused YAML snippet with safe defaults.
4. Skip full validation and state `Validation status: Skipped (snippet-only)`.
5. Return snippet + assumptions + references.

## 9) Definition of Done

The execution is complete only when all applicable checks pass:

- Request mode is explicitly chosen.
- Assumptions are explicit for missing inputs.
- YAML follows checklist requirements (security, versioning, reliability, performance, maintainability).
- Validation path is documented (validator, script fallback, or manual fallback).
- Final response follows the output contract, including references and impact.
