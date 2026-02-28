---
name: gitlab-ci-validator
description: Comprehensive toolkit for validating, linting, testing, and securing GitLab CI/CD pipeline configurations. Use this skill when working with GitLab CI/CD pipelines, validating pipeline syntax, debugging configuration issues, or implementing best practices.
---

# GitLab CI/CD Validator

Comprehensive toolkit for validating, linting, testing, and securing `.gitlab-ci.yml` configurations.

## Trigger Phrases

Use this skill when requests include intent like:

- "Validate this `.gitlab-ci.yml`"
- "Why is this GitLab pipeline failing?"
- "Run a security review for our GitLab CI"
- "Check pipeline best practices"
- "Lint GitLab CI config before merge"

## Setup And Prerequisites (Run First)

All commands below assume repository root as current working directory.

```bash
# Ensure validator scripts are executable
chmod +x devops-skills-plugin/skills/gitlab-ci-validator/scripts/*.sh \
  devops-skills-plugin/skills/gitlab-ci-validator/scripts/*.py

# Required runtime
python3 --version
```

Use one canonical command path for orchestration:

```bash
VALIDATOR="bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/validate_gitlab_ci.sh"
```

Optional local execution tooling (for `--test-only`):

```bash
bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/install_tools.sh
```

## Quick Start Commands

```bash
# 1) Full validation (syntax + best practices + security)
$VALIDATOR .gitlab-ci.yml

# 2) Syntax and schema only (required first gate)
$VALIDATOR .gitlab-ci.yml --syntax-only

# 3) Best-practices only (recommended)
$VALIDATOR .gitlab-ci.yml --best-practices

# 4) Security only (required before merge)
$VALIDATOR .gitlab-ci.yml --security-only

# 5) Optional local pipeline structure test (needs gitlab-ci-local + Docker)
$VALIDATOR .gitlab-ci.yml --test-only

# 6) Strict mode (treat best-practice warnings as failure)
$VALIDATOR .gitlab-ci.yml --strict
```

## Deterministic Validation Workflow

Follow these gates in order:

1. Run Quick Start command `2` (`--syntax-only`).
2. If syntax fails, stop and fix errors before continuing.
3. Run Quick Start command `3` (`--best-practices`) and apply relevant improvements.
4. Run Quick Start command `4` (`--security-only`) and fix all `critical`/`high` findings before merge.
5. Optionally run Quick Start command `5` (`--test-only`) for local execution checks.
6. Run Quick Start command `6` (`--strict`) for final merge gate.

Required gates: syntax + security.
Recommended gate: best practices.
Optional gate: local execution test.

## Rule Severity Rationale And Documentation Links

### Severity Model

- `critical`: Direct credential/secret exposure or high-confidence compromise path. Block merge.
- `high`: Exploitable unsafe behavior or strong security regression. Fix before merge.
- `medium`: Security hardening gap with realistic risk. Track and fix soon.
- `low`/`suggestion`: Optimization or maintainability improvement.

### Rule Classes And Why They Matter

- Syntax rules (`yaml-syntax`, `job-stage-undefined`, `dependencies-undefined-job`): prevent pipeline parse and dependency failures.
- Best-practice rules (`cache-missing`, `artifact-no-expiration`, `dag-optimization`): reduce runtime cost and improve pipeline throughput.
- Security rules (`hardcoded-password`, `curl-pipe-bash`, `include-remote-unverified`): reduce credential leaks and supply-chain risk.

### References

- Local syntax reference: `devops-skills-plugin/skills/gitlab-ci-validator/docs/gitlab-ci-reference.md`
- Local best practices: `devops-skills-plugin/skills/gitlab-ci-validator/docs/best-practices.md`
- Local common issues: `devops-skills-plugin/skills/gitlab-ci-validator/docs/common-issues.md`
- GitLab CI YAML reference: https://docs.gitlab.com/ee/ci/yaml/
- GitLab CI/CD components: https://docs.gitlab.com/ee/ci/components/
- GitLab pipeline security guidance: https://docs.gitlab.com/ee/ci/pipelines/settings.html

## Fallbacks For Tool Or Environment Constraints

- Missing `python3`:
  - Behavior: validator cannot run.
  - Fallback: install Python 3 and rerun.
- Missing `PyYAML`:
  - Behavior: `python_wrapper.sh` auto-creates `.venv` and installs `pyyaml` when possible.
  - Fallback in restricted/offline environments: pre-install `pyyaml` from an internal mirror, then rerun.
- Missing `gitlab-ci-local`, `node`, or `docker`:
  - Behavior: `--test-only` reports warning/failure.
  - Fallback: skip local execution testing and continue with syntax/best-practice/security gates.
- No execute permission on scripts:
  - Behavior: shell permission errors.
  - Fallback: rerun the setup `chmod` command from the Setup section.

## Examples

### Example 1: New Pipeline Validation

```bash
$VALIDATOR examples/basic-pipeline.gitlab-ci.yml --syntax-only
$VALIDATOR examples/basic-pipeline.gitlab-ci.yml --security-only
```

### Example 2: Pre-Merge Hard Gate

```bash
$VALIDATOR .gitlab-ci.yml --strict
```

### Example 3: CI Integration

```yaml
stages:
  - validate

validate_gitlab_ci:
  stage: validate
  script:
    - chmod +x devops-skills-plugin/skills/gitlab-ci-validator/scripts/*.sh devops-skills-plugin/skills/gitlab-ci-validator/scripts/*.py
    - bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/validate_gitlab_ci.sh .gitlab-ci.yml --strict
```

## Individual Validators (Advanced)

```bash
# Syntax validator (via wrapper for PyYAML fallback)
bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/python_wrapper.sh \
  devops-skills-plugin/skills/gitlab-ci-validator/scripts/validate_syntax.py .gitlab-ci.yml

# Best-practices validator
bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/python_wrapper.sh \
  devops-skills-plugin/skills/gitlab-ci-validator/scripts/check_best_practices.py .gitlab-ci.yml

# Security validator
bash devops-skills-plugin/skills/gitlab-ci-validator/scripts/python_wrapper.sh \
  devops-skills-plugin/skills/gitlab-ci-validator/scripts/check_security.py .gitlab-ci.yml
```

## Done Criteria

- Frontmatter `name` and `description` unchanged.
- One canonical orchestrator path is used consistently.
- Setup and `chmod` prerequisites appear before workflow/use examples.
- Quick-start and workflow are non-duplicative (workflow references quick-start gates).
- Severity rationale and rule-to-doc references are explicit.
- Fallback behavior is documented for missing tools and constrained environments.
- Examples are executable from repository root.

## Notes

- This skill validates configuration and static patterns; it does not execute production pipelines.
- Use `gitlab-ci-local` or GitLab CI Lint for runtime behavior confirmation.
