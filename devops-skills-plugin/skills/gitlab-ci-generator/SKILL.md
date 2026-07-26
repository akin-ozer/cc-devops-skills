---
name: gitlab-ci-generator
description: "Use when creating or redesigning .gitlab-ci.yml pipelines, stages, jobs, rules, includes, templates, or deployment flows."
---

# GitLab CI Generator

## Purpose

Generate a GitLab CI/CD pipeline suited to the repository's build, test, release, and deployment model. Use `gitlab-ci-validator` for review-only work.

## Workflow

1. Inspect the repository for build commands, images, artifacts, environments, existing includes, runner tags, and protected branch conventions.
2. Clarify material unknowns such as pipeline sources, deployment targets, and runner capabilities; avoid a long questionnaire for simple CI.
3. Read only the focused file in `references/` and the closest template in `assets/templates/`. Open `references/extended-guide.md` for advanced parent-child, multi-project, or security patterns.
4. Generate a minimal pipeline with explicit `workflow:rules`/job `rules`, dependable artifact or cache flow, and reusable components only where they reduce duplication.
5. Run `gitlab-ci-validator`, fix generator-owned findings, and rerun.

## Resources

- `references/`: focused pipeline, pattern, security, and optimization guidance
- `assets/templates/`: basic, container, Kubernetes, and multi-project starters
- `references/extended-guide.md`: comprehensive advanced examples

## Safety and gotchas

- Use masked/protected CI variables; never commit token or kubeconfig values.
- Distinguish cache from artifacts and set retention deliberately.
- Avoid duplicate pipelines caused by overlapping branch and merge-request rules.
- Never trigger, deploy, publish, or mutate runners while generating configuration.

## Validation

Run `gitlab-ci-validator` and `tests/test_skill_contract.py`. Treat server-side include expansion and project-variable checks as unverified unless actually available.

## Output

List files, pipeline sources, stages, required variables/runners, assumptions, and validation results.
