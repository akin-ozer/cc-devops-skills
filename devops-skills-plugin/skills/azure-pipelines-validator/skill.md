---
name: azure-pipelines-validator
description: Comprehensive toolkit for validating, linting, and securing Azure DevOps Pipeline configurations.
---

# Azure Pipelines Validator

Use this skill to validate Azure DevOps pipeline YAML (`azure-pipelines.yml` / `azure-pipelines.yaml`) with local scripts first, then escalate to docs only when local output is not enough.

## Trigger Phrases

Use this skill when the user asks things like:

- "Validate my `azure-pipelines.yml`."
- "Why is this Azure pipeline YAML failing?"
- "Run a security scan on this Azure DevOps pipeline."
- "Check this pipeline for best-practice issues."
- "Review this pipeline in CI before merge."

Do not use this skill for pipeline generation from scratch. Use `azure-pipelines-generator` for that.

## Deterministic Path Setup (No Ambiguity)

Run from any directory using explicit absolute paths:

```bash
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
SKILL_DIR="$REPO_ROOT/devops-skills-plugin/skills/azure-pipelines-validator"
PIPELINE_FILE="$REPO_ROOT/azure-pipelines.yml"
```

If `REPO_ROOT` is empty, stop and ask for the repository root path. Do not guess paths.

Validate one file:

```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE"
```

Auto-detect from current directory (up to depth 3):

```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh"
```

If auto-detect returns multiple files, rerun with one explicit file path.

## Local-First Execution Model

1. Preflight
- Confirm `bash` and `python3` are available.
- Confirm target file exists.

2. Run local validator
- Default full pass:
```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE"
```
- Syntax only:
```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE" --syntax-only
```
- Best practices only:
```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE" --best-practices
```
- Security only:
```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE" --security-only
```
- Strict mode (warnings fail):
```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$PIPELINE_FILE" --strict
```

3. Interpret exit behavior
- `0`: pass (or non-blocking checks only)
- `1`: validation failed (blocking issues)
- `2`: invalid invocation (missing/ambiguous file or bad args)

4. Return findings in the report format below.

## Expected Report Format (Severity Buckets)

Always return results in this structure:

```text
Validation Report: <path>

Summary:
- Blocking: <count>        # Syntax errors + Security critical/high
- Warning: <count>         # Security medium/low + best-practice warnings
- Info: <count>            # Suggestions
- Skipped: <count>         # Explicitly name skipped checks

Findings:
- [Blocking][syntax][<rule-id>] line <n> - <message>
- [Blocking][security-high][<rule-id>] line <n> - <message>
- [Warning][security-medium][<rule-id>] line <n> - <message>
- [Warning][best-practice][<rule-id>] line <n> - <message>
- [Info][best-practice][<rule-id>] line <n> - <message>

Remediation:
- <short, concrete fix per finding>

Execution Notes:
- Commands run: <exact commands>
- Environment/fallback notes: <tool missing, skipped checks, offline constraints>
```

## Escalation Policy (Docs Only When Needed)

Run local checks first. Escalate only when at least one condition is true:

- Local finding depends on current upstream behavior (task versions, deprecations, new inputs).
- User asks for "latest/current/recent" Azure Pipelines task or schema details.
- Local scripts cannot determine validity for a specific task/resource syntax.

Escalation order:

1. Context7 docs tooling first.
```text
mcp__context7__resolve-library-id(...)
mcp__context7__query-docs(...)
```
2. Official docs second (`learn.microsoft.com` / Microsoft Azure DevOps docs).
3. General web search only if the first two are insufficient.

When escalating, cite the source URL and state what local check could not answer.

## Fallback Behavior

Use this matrix when tools are unavailable:

- Condition: `yamllint` unavailable.
- Action: Continue with syntax/best-practice/security checks.
- Report note: "YAML lint skipped because yamllint is unavailable."

- Condition: `python3` unavailable or venv/dependency setup fails.
- Action: Mark scripted validation blocked; perform manual YAML review only if requested.
- Report note: "Local scripted validation blocked by missing Python runtime/dependencies."

- Condition: No network while dependencies/docs are needed.
- Action: Run whatever local checks are still possible; defer doc/version verification.
- Report note: "External verification deferred due offline environment."

- Condition: Multiple auto-detected pipeline files.
- Action: Do not pick arbitrarily; require explicit target file path.
- Report note: "Validation paused until a single target file is specified."

## Rule Buckets (What the Scripts Check)

Syntax examples:

- `yaml-syntax`
- `yaml-invalid-root`
- `invalid-hierarchy`
- `task-invalid-format`
- `pool-invalid`
- `deployment-missing-strategy`

Best-practice examples:

- `missing-displayname`
- `task-version-zero`
- `task-missing-version`
- `pool-latest-image`
- `missing-cache`
- `missing-deployment-condition`

Security examples:

- `hardcoded-password`
- `hardcoded-secret`
- `curl-pipe-shell`
- `eval-command`
- `insecure-ssl`
- `container-latest-tag`
- `variable-not-secret`

Use script output rule IDs directly in the report.

## References and Examples

- Syntax reference: `docs/azure-pipelines-reference.md`
- Example pipelines: `examples/`

Quick local test:

```bash
bash "$SKILL_DIR/scripts/validate_azure_pipelines.sh" "$SKILL_DIR/examples/basic-pipeline.yml"
```

## Done Criteria

This skill execution is done when all conditions are true:

- Trigger match is explicit and plain-language examples are provided near the top.
- Validation command(s) were run with unambiguous paths.
- Report uses severity buckets (`Blocking`, `Warning`, `Info`, `Skipped`).
- Fallback behavior is explicitly reported for unavailable tools/environment constraints.
- External docs were consulted only when local checks were insufficient.
