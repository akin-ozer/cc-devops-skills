---
name: jenkinsfile-validator
description: Comprehensive toolkit for validating, linting, testing, and automating Jenkinsfile pipelines (both Declarative and Scripted). Use this skill when working with Jenkins pipeline files, validating pipeline syntax, checking best practices, debugging pipeline issues, or working with custom plugins.
---

# Jenkinsfile Validator Skill

Use this skill to validate Jenkins pipelines and shared libraries with local scripts first, then optionally enrich findings with plugin documentation.

## Trigger Phrases

Use this skill when requests look like:
- "Validate this Jenkinsfile"
- "Check this pipeline for security issues"
- "Lint my Declarative/Scripted pipeline"
- "Why is this Jenkins pipeline failing syntax checks?"
- "Validate vars/*.groovy or src/**/*.groovy shared library files"

## Scope

This skill validates:
- Declarative pipelines (`pipeline { ... }`)
- Scripted pipelines (`node { ... }` and Groovy-style pipelines)
- Shared library files (`vars/*.groovy`, `src/**/*.groovy`)
- Hardcoded credential patterns
- Pipeline best practices and maintainability signals

## Prerequisites

Run commands from repository root unless noted.

### Required tools
- `bash`
- `grep`
- `sed`
- `awk`
- `head`
- `wc`
- `find` (needed for shared-library directory scans)

### Recommended tools
- `jq` (optional; improves JSON-heavy troubleshooting workflows)

### Script prerequisites
- Scripts live in `devops-skills-plugin/skills/jenkinsfile-validator/scripts/`
- Main orchestrator can run child scripts even if `+x` is missing (it uses `bash` fallback)
- If you want direct execution (`./script.sh`), make scripts executable:

```bash
chmod +x devops-skills-plugin/skills/jenkinsfile-validator/scripts/*.sh
```

### Preflight check (recommended)

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"

command -v bash grep sed awk head wc find >/dev/null && echo "required tools: ok" || echo "required tools: missing"
command -v jq >/dev/null && echo "jq: installed (optional)" || echo "jq: missing (optional)"

[ -d "$SKILL_DIR/scripts" ] && echo "scripts dir: ok" || echo "scripts dir: missing"
[ -f "$SKILL_DIR/scripts/validate_jenkinsfile.sh" ] && echo "main validator: ok" || echo "main validator: missing"
```

## Quick Start (Normalized Paths)

Use a single base path variable to avoid path ambiguity.

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"
TARGET_JENKINSFILE="Jenkinsfile"

# Full validation (recommended)
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" "$TARGET_JENKINSFILE"
```

### Common options

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"
TARGET_JENKINSFILE="Jenkinsfile"

bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --syntax-only "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --security-only "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --best-practices "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --no-security "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --no-best-practices "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" --strict "$TARGET_JENKINSFILE"
```

### Shared library validation

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"

bash "$SKILL_DIR/scripts/validate_shared_library.sh" vars/myStep.groovy
bash "$SKILL_DIR/scripts/validate_shared_library.sh" vars/
bash "$SKILL_DIR/scripts/validate_shared_library.sh" src/
bash "$SKILL_DIR/scripts/validate_shared_library.sh" /path/to/shared-library
```

## Deterministic Validation Flow

### 1) Detect pipeline type
- `pipeline {` => Declarative validator
- `node (...)` or `node {` => Scripted validator
- Unknown => tries both validators and keeps the better match

### 2) Run syntax validation
- Declarative: `validate_declarative.sh`
- Scripted: `validate_scripted.sh`

### 3) Run security scan
- `common_validation.sh check_credentials`

### 4) Run best practices check
- `best_practices.sh`

### 5) Aggregate and return final status
- Unified summary with pass/fail per phase and final exit code

## Individual Script Commands (Advanced)

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"
TARGET_JENKINSFILE="Jenkinsfile"

# Type detection
bash "$SKILL_DIR/scripts/common_validation.sh" detect_type "$TARGET_JENKINSFILE"

# Syntax-only by type
bash "$SKILL_DIR/scripts/validate_declarative.sh" "$TARGET_JENKINSFILE"
bash "$SKILL_DIR/scripts/validate_scripted.sh" "$TARGET_JENKINSFILE"

# Security-only
bash "$SKILL_DIR/scripts/common_validation.sh" check_credentials "$TARGET_JENKINSFILE"

# Best-practices-only
bash "$SKILL_DIR/scripts/best_practices.sh" "$TARGET_JENKINSFILE"
```

## Exit Code and Log Interpretation

### Main orchestrator: `validate_jenkinsfile.sh`
- `0`: Validation passed
- `1`: Validation failed (syntax/security errors, or warnings in `--strict` mode)
- `2`: Usage or environment error (bad args, missing file, missing required tools)

### Sub-scripts
- `validate_declarative.sh`: `0` pass (errors=0), `1` usage/file/validation failure
- `validate_scripted.sh`: `0` pass (errors=0), `1` usage/file/validation failure
- `common_validation.sh check_credentials`: `0` no credential errors, `1` credential issues found
- `validate_shared_library.sh`: `0` pass, `1` validation errors found, `2` invalid input target
- `best_practices.sh`: `1` only for usage/file errors; content findings are reported in logs and score output

### Log severity patterns
- `ERROR [Line N]: ...` => must fix
- `WARNING [Line N]: ...` => should review
- `INFO [Line N]: ...` => optional improvement
- Summary banners (`VALIDATION PASSED/FAILED`) determine final interpretation quickly

### Practical interpretation rules
- For CI gating, rely on main orchestrator exit code.
- Use `--strict` when warnings should fail pipelines.
- When `best_practices.sh` is run standalone, read report sections (`CRITICAL ISSUES`, `IMPROVEMENTS RECOMMENDED`, score); do not rely only on exit code.

## Fallback Behavior

### Missing optional tools
- If `jq` is missing, continue validation; treat as non-blocking.

### Non-executable child scripts
- Main orchestrator warns and falls back to `bash <script>` execution.

### Missing child scripts
- Main orchestrator reports runner error and returns failure for that phase.

### Unknown plugin steps
Use this order:
1. Check local reference: `devops-skills-plugin/skills/jenkinsfile-validator/references/common_plugins.md`
2. Context7 lookup:
   - `mcp__context7__resolve-library-id` with query like `jenkinsci <plugin-name>-plugin`
   - `mcp__context7__query-docs` for usage and parameters
3. Web fallback: [plugins.jenkins.io](https://plugins.jenkins.io/) and official Jenkins docs

### Offline/air-gapped mode
- Run all local validators.
- If plugin docs cannot be fetched, report: "Plugin docs lookup skipped due to environment constraints; local validation only."

## Plugin Documentation Lookup Workflow

When plugin-specific validation is requested:
1. Identify unknown steps from Jenkinsfile or validator logs.
2. Check `references/common_plugins.md` first.
3. If missing, use Context7 (`resolve-library-id` then `query-docs`).
4. If still missing, use web search against official plugin index/docs.
5. Return required parameters, optional parameters, version-sensitive notes, and security guidance.

## References

Local references:
- `devops-skills-plugin/skills/jenkinsfile-validator/references/declarative_syntax.md`
- `devops-skills-plugin/skills/jenkinsfile-validator/references/scripted_syntax.md`
- `devops-skills-plugin/skills/jenkinsfile-validator/references/best_practices.md`
- `devops-skills-plugin/skills/jenkinsfile-validator/references/common_plugins.md`

External references:
- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Pipeline Development Tools](https://www.jenkins.io/doc/book/pipeline/development/)
- [Pipeline Best Practices](https://www.jenkins.io/doc/book/pipeline/pipeline-best-practices/)
- [Jenkins Plugins](https://plugins.jenkins.io/)

## Reporting Template

Use this structure in validation responses:

```text
Validation Target: <path>
Pipeline Type: <Declarative|Scripted|Shared Library|Unknown>

Findings:
- ERROR [Line X]: <issue>
- WARNING [Line Y]: <issue>
- INFO [Line Z]: <suggestion>

Phase Results:
- Syntax: <PASSED|FAILED|SKIPPED>
- Security: <PASSED|FAILED|SKIPPED>
- Best Practices: <PASSED|REVIEW NEEDED|SKIPPED>

Exit Code: <0|1|2>
Next Actions:
1. <highest-priority fix>
2. <second fix>
```

## Example Flows

### Example 1: Full Jenkinsfile validation

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"
bash "$SKILL_DIR/scripts/validate_jenkinsfile.sh" Jenkinsfile
```

Expected behavior:
- Runs syntax + security + best practices
- Prints per-phase results and unified summary
- Returns `0/1/2` per orchestrator rules

### Example 2: Shared library directory validation

```bash
SKILL_DIR="devops-skills-plugin/skills/jenkinsfile-validator"
bash "$SKILL_DIR/scripts/validate_shared_library.sh" examples/shared-library
```

Expected behavior:
- Validates both `vars/` and `src/` files
- Aggregates issues with line references
- Returns `1` when errors are present

### Example 3: Unknown plugin step follow-up

Input step:
```groovy
nexusArtifactUploader artifacts: [[...]], nexusUrl: 'https://nexus.example.com'
```

Flow:
1. Validate locally first.
2. If step behavior is unclear, resolve docs via Context7.
3. If unavailable, use plugin site docs.
4. Report usage guidance and security-safe parameter patterns.

## Done Criteria

The skill usage is complete when all are true:
- Commands use normalized paths (`$SKILL_DIR/scripts/...`) with no cwd ambiguity.
- Prerequisites and optional dependencies are explicit.
- Exit-code semantics and log-severity interpretation are documented.
- Fallback behavior is defined for missing tools/docs and constrained environments.
- At least one runnable example exists for full validation and shared-library validation.
- Reporting format is deterministic and actionable.
