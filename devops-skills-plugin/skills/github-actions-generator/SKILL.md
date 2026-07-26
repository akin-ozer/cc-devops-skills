---
name: github-actions-generator
description: "Use when creating or redesigning GitHub Actions workflows, reusable workflows, or custom action.yml actions."
---

# GitHub Actions Generator

## Purpose

Create secure, maintainable GitHub Actions automation matched to the repository. Use `github-actions-validator` for validation-only requests.

## Workflow

1. Inspect the repository's languages, package managers, lockfiles, existing workflows, release model, environments, and organization conventions.
2. Choose workflow, reusable workflow, composite action, JavaScript action, or Docker action based on the requested deliverable.
3. Read only the matching reference: `best-practices.md`, `custom-actions.md`, `advanced-triggers.md`, or a focused expressions/actions guide. Use `references/extended-guide.md` for patterns not covered there.
4. Generate the smallest complete file set with least-privilege permissions, explicit triggers, dependency caching, and bounded concurrency where relevant.
5. Run `github-actions-validator`, fix generator-owned findings, and rerun.

## Resources

- `assets/templates/`: workflow and custom-action starters
- `references/`: focused triggers, actions, expressions, security, and modern feature guidance
- `examples/`: representative workflows and actions
- `references/extended-guide.md`: end-to-end patterns

## Safety and gotchas

- Set `permissions` explicitly and keep untrusted pull-request code away from secrets and privileged tokens.
- Pin third-party actions according to repository policy; verify current releases and provenance before changing versions.
- Avoid expression injection into shell commands; pass values through `env`.
- Do not dispatch, release, deploy, or publish while generating files.

## Validation

Run `github-actions-validator` and `scripts/test_generator.sh`. Mark `act` or live GitHub behavior as unverified when unavailable.

## Output

List files, triggers, permissions, secrets/environments to configure, assumptions, and validation evidence.
