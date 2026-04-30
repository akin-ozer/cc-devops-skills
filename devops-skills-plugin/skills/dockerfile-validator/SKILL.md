---
name: dockerfile-validator
description: Use when validating, linting, scanning, or hardening an existing Dockerfile for security, best practices, or image-size/build-time issues. Triggers "lint Dockerfile", "scan Dockerfile for vulnerabilities", "review Dockerfile.prod", "Dockerfile security check", "optimize image size/build". Not for authoring a new Dockerfile from scratch — see dockerfile-generator.
---

# Dockerfile Validator

Validate Dockerfiles with deterministic stages, clear severity reporting, and explicit fallbacks when tools or network access are constrained.

## Trigger Phrases

Use this skill when the user asks for tasks like:
- "validate this Dockerfile"
- "lint/check my Dockerfile"
- "security scan Dockerfile"
- "optimize Docker image size/build time"
- "review Dockerfile before merge"
- "find issues in Dockerfile.prod/Dockerfile.dev"

## Use / Do Not Use

Use this skill for:
- Syntax and validation
- Security and secrets checks
- Best-practice and performance review
- Dockerfile hardening before CI/CD or production

Do not use this skill for:
- Generating a new Dockerfile from scratch (use `dockerfile-generator`)
- Running containers, debugging runtime behavior, or image registry operations

## Skill Contents

- Validator script: `scripts/dockerfile-validate.sh`
- CI/regression entrypoint: `scripts/test_validate.sh`
- References:
  - `references/security_checklist.md` — secrets, root user, hardening, registry/runtime
  - `references/optimization_guide.md` — image size, layer count, multi-stage, cache, `.dockerignore`
  - `references/docker_best_practices.md` — instruction usage, tag pinning, COPY vs ADD, conventions
- Examples: `examples/good-example.Dockerfile`, `examples/bad-example.Dockerfile`, `examples/security-issues.Dockerfile`, `examples/python-optimized.Dockerfile`, `examples/golang-distroless.Dockerfile`

## Deterministic Execution Flow

Run these steps in order. Do not skip steps unless a documented fallback branch applies.

### 1. Preflight and Path Setup

Assume repo root as working directory:

```bash
cd /path/to/repo
SKILL_DIR="devops-skills-plugin/skills/dockerfile-validator"
TARGET_DOCKERFILE="Dockerfile"   # replace when user provides a path
```

Validate inputs before running tools:

```bash
test -f "$SKILL_DIR/scripts/dockerfile-validate.sh"
test -f "$TARGET_DOCKERFILE"
```

If either check fails, stop and report the exact missing path.

### 2. Read the Target Dockerfile

Use the Read tool on `$TARGET_DOCKERFILE` to load its contents into context before running the validator. For very long files, page through with the Read tool's `offset`/`limit` parameters.

### 3. Run Validation Script

Primary command:

```bash
bash "$SKILL_DIR/scripts/dockerfile-validate.sh" "$TARGET_DOCKERFILE"
```

The script's stdout is captured directly in the conversation context — no `tee` redirect is required.

### 4. Classify Findings by Severity

Use this severity model:

- `Critical`
  - Hardcoded secrets/credentials
  - Explicit root runtime with high-risk context
  - High-impact security policy failures
- `High`
  - Checkov failures for container hardening
  - hadolint errors likely to cause insecure/unreliable builds
  - Missing or unsafe runtime-user posture (`USER`)
- `Medium`
  - `:latest` image tags, missing pinning, cache-cleanup misses
  - Build cache inefficiency and layered install anti-patterns
- `Low`
  - Style/info guidance and non-blocking optimization suggestions

### 5. No-Issue Fast Path

If validation has no actionable findings:
- Return a concise pass summary.
- Do not open reference files.
- Do not generate fix diffs.

Use fast path when all are true:
- Script reports overall pass.
- No security failures.
- No error/warning findings requiring user action.

### 6. Reference Loading Rules (Only When Findings Exist)

Only read references that match actual findings. Read each required file once.

Issue-to-reference mapping:

| Issue category | Trigger examples | Read this file |
|---|---|---|
| Secrets, root user, exposed sensitive ports, hardening gaps | `CKV_DOCKER_*`, hardcoded token/password, root runtime | `references/security_checklist.md` |
| Image size, layer count, multi-stage opportunities, cache efficiency, `.dockerignore` gaps | too many `RUN`, single-stage with build deps, cache misses | `references/optimization_guide.md` |
| Tag pinning, instruction usage, COPY vs ADD, WORKDIR/CMD/ENTRYPOINT conventions | `:latest`, unpinned packages, instruction-level best practices | `references/docker_best_practices.md` |

Use the Read tool on the matching reference file(s). Each reference has a section index at the top — jump to the relevant section rather than reading end-to-end.

For targeted extraction within a reference:

```bash
rg -n "USER|secrets|EXPOSE|HEALTHCHECK" "$SKILL_DIR/references/security_checklist.md"
rg -n "multi-stage|cache|layer|dockerignore" "$SKILL_DIR/references/optimization_guide.md"
rg -n "FROM|COPY|ADD|WORKDIR|CMD|ENTRYPOINT|latest" "$SKILL_DIR/references/docker_best_practices.md"
```

### 7. Produce Standard Report Output

Use this template for every non-fast-path run:

```markdown
## Dockerfile Validation Report
- Target: <path>
- Command: `bash <skill-script> <target>`
- Overall result: PASS | FAIL | PARTIAL (fallback)

### Critical
- <issue or `None`>

### High
- <issue or `None`>

### Medium
- <issue or `None`>

### Low
- <issue or `None`>

### Recommended Fixes
- <specific code-level fix per actionable issue>

### References Used
- <list only files actually read>

### Fallbacks Used
- `None` or exact fallback branch + reason
```

### 8. Offer Fix Application

After reporting:
- Ask whether to apply fixes.
- If user approves, patch the Dockerfile and rerun validation.

## Recovery

When applied fixes break the build (`docker build` fails after the patch, or a rerun introduces new errors), undo the changes before iterating:

```bash
# If the Dockerfile is tracked and unstaged
git checkout -- Dockerfile

# If you want to keep the attempt for inspection
git stash push -m "dockerfile-validator failed fix" -- Dockerfile
```

Then rerun the validator on the restored file and propose a smaller patch.

## Fallback Behavior

When the primary script cannot complete, use deterministic fallback branches and report them.

### Fallback A: Python/Tool Install Constraint

Condition:
- Script exits with tool-install failure (for example Python missing, package install blocked, or restricted environment).

Action:
1. Report primary failure and why.
2. Run manual minimum checks:

```bash
# Basic syntax signal (if Docker is available)
DOCKERFILE_DIR="$(dirname "$TARGET_DOCKERFILE")"
docker build --no-cache -f "$TARGET_DOCKERFILE" "$DOCKERFILE_DIR"

# High-value static checks
grep -nEi "^[[:space:]]*FROM[[:space:]]+.*:latest" "$TARGET_DOCKERFILE" || true
grep -nEi "^[[:space:]]*(ENV|ARG)[[:space:]].*(password|secret|token|api[_-]?key)[[:space:]]*=" "$TARGET_DOCKERFILE" || true
grep -nEi "^[[:space:]]*USER[[:space:]]+(root|0(:0)?)$" "$TARGET_DOCKERFILE" || true
grep -nEi "^[[:space:]]*HEALTHCHECK[[:space:]]+" "$TARGET_DOCKERFILE" || true
```

3. Classify output with `PARTIAL` result and clearly label skipped checks.

### Fallback B: hadolint Not Available but Docker Available

Use hadolint container image:

```bash
docker run --rm -i hadolint/hadolint < "$TARGET_DOCKERFILE"
```

### Fallback C: No Docker, No hadolint/checkov

Run only manual regex-based checks (Fallback A step 2), clearly mark as `PARTIAL`, and state which scanners were skipped.

## Progressive Disclosure Rules

- Always read the target Dockerfile first.
- Do not read any reference files unless findings require them.
- Read only the matching reference file(s) from the issue-to-reference mapping.
- Do not reread the same reference unless new issue categories appear.

## Done Criteria

Consider this skill execution complete only when all conditions below are satisfied:

- Trigger matched a Dockerfile validation request.
- Target Dockerfile path was explicitly verified.
- Validation command (or explicit fallback) was executed.
- Findings were reported using severity buckets (`Critical`, `High`, `Medium`, `Low`).
- Reference usage matched issue categories and was explicitly listed.
- No-issue fast path skipped unnecessary reference reads.
- If fixes were applied, validation was rerun and final status reported.

## Source Links

- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Checkov Dockerfile Scanning](https://www.checkov.io/7.Scan%20Examples/Dockerfile.html)
- [hadolint](https://github.com/hadolint/hadolint)
