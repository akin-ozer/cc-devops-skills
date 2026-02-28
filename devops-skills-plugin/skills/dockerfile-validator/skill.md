---
name: dockerfile-validator
description: Comprehensive toolkit for validating, linting, and securing Dockerfiles. Use this skill when validating Dockerfile syntax, checking security best practices, optimizing image builds. Applies to all Dockerfile variants (Dockerfile, Dockerfile.prod, Dockerfile.dev, etc.).
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
- Syntax and lint validation
- Security and secrets checks
- Best-practice and performance review
- Dockerfile hardening before CI/CD or production

Do not use this skill for:
- Generating a new Dockerfile from scratch (use `dockerfile-generator`)
- Running containers, debugging runtime behavior, or image registry operations

## Local Files In This Skill

- Validator script: `scripts/dockerfile-validate.sh`
- References:
  - `references/security_checklist.md`
  - `references/optimization_guide.md`
  - `references/docker_best_practices.md`
- Example Dockerfiles: `examples/*.Dockerfile`

## Deterministic Execution Flow (Required)

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

### 2. Read the Target Dockerfile Explicitly

Use explicit file-read commands (not abstract "Read tool" wording):

```bash
sed -n '1,220p' "$TARGET_DOCKERFILE"
```

If needed for long files:

```bash
sed -n '220,440p' "$TARGET_DOCKERFILE"
```

### 3. Run Validation Script

Primary command:

```bash
bash "$SKILL_DIR/scripts/dockerfile-validate.sh" "$TARGET_DOCKERFILE"
```

Optional captured run for structured reporting:

```bash
bash "$SKILL_DIR/scripts/dockerfile-validate.sh" "$TARGET_DOCKERFILE" | tee /tmp/dockerfile-validator.out
```

### 4. Classify Findings by Severity (Standard)

Use this standard severity model:

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

### 5. No-Issue Fast Path (Required)

If validation has no actionable findings:
- Return a concise pass summary.
- Do **not** open reference files.
- Do **not** generate fix diffs.

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

Explicit read commands:

```bash
sed -n '1,220p' "$SKILL_DIR/references/security_checklist.md"
sed -n '1,220p' "$SKILL_DIR/references/optimization_guide.md"
sed -n '1,220p' "$SKILL_DIR/references/docker_best_practices.md"
```

For targeted extraction:

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

## Fallback Behavior (Explicit)

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

## Quick Command Set

### Validate one Dockerfile

```bash
cd /path/to/repo
bash devops-skills-plugin/skills/dockerfile-validator/scripts/dockerfile-validate.sh Dockerfile
```

### Validate alternate file

```bash
cd /path/to/repo
bash devops-skills-plugin/skills/dockerfile-validator/scripts/dockerfile-validate.sh Dockerfile.prod
```

### Validate skill examples

```bash
cd /path/to/repo/devops-skills-plugin/skills/dockerfile-validator
bash scripts/dockerfile-validate.sh examples/good-example.Dockerfile
bash scripts/dockerfile-validate.sh examples/security-issues.Dockerfile
```

## Progressive Disclosure Rules

- Always read the target Dockerfile first.
- Do not read any reference files unless findings require them.
- Read only the matching reference file(s) from the issue-to-reference mapping.
- Do not reread the same reference unless new issue categories appear.

## Done Criteria

Consider this skill execution complete only when all conditions below are satisfied:

- Trigger matched a Dockerfile validation/lint/security/optimization request.
- Target Dockerfile path was explicitly verified.
- Validation command (or explicit fallback) was executed.
- Findings were reported using severity buckets (`Critical`, `High`, `Medium`, `Low`).
- Reference usage matched issue categories and was explicitly listed.
- No-issue fast path skipped unnecessary reference reads.
- If fixes were applied, validation was rerun and final status reported.

## Resources

- Script: `scripts/dockerfile-validate.sh`
- Security reference: `references/security_checklist.md`
- Optimization reference: `references/optimization_guide.md`
- Best-practices reference: `references/docker_best_practices.md`
- Examples: `examples/good-example.Dockerfile`, `examples/bad-example.Dockerfile`, `examples/security-issues.Dockerfile`, `examples/python-optimized.Dockerfile`, `examples/golang-distroless.Dockerfile`

## Source Links

- [Docker Build Best Practices](https://docs.docker.com/build/building/best-practices/)
- [Dockerfile Reference](https://docs.docker.com/reference/dockerfile/)
- [Checkov Dockerfile Scanning](https://www.checkov.io/7.Scan%20Examples/Dockerfile.html)
- [hadolint](https://github.com/hadolint/hadolint)
