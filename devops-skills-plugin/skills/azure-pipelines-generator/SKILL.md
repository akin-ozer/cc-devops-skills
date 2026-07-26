---
name: azure-pipelines-generator
description: "Use when creating or redesigning Azure Pipelines YAML, stages, jobs, steps, deployment jobs, or reusable templates."
---

# Azure Pipelines Generator

## Purpose

Generate Azure DevOps pipeline YAML that matches the repository's build and deployment model. Use `azure-pipelines-validator` for validation-only requests.

## Workflow

1. Inspect the repository for its language, build commands, service connections, variable conventions, deployment environments, and existing templates.
2. Clarify only material unknowns such as trigger branches, agent pool, artifact flow, and deployment targets.
3. Read the focused document for the requested feature: `docs/yaml-schema.md`, `tasks-reference.md`, `templates-guide.md`, or `best-practices.md`. Use `references/extended-guide.md` for end-to-end examples.
4. Generate the smallest pipeline or template set, preserving repository naming and indentation.
5. Run `azure-pipelines-validator`, fix generator-owned findings, and rerun it.

## Resources

- `docs/`: focused schema, task, template, and design guidance
- `examples/`: representative pipeline shapes
- `references/extended-guide.md`: detailed modes and report contract

## Safety and gotchas

- Reference secret variables or Key Vault; never write secret values into YAML.
- Keep compile-time (`${{ }}`), runtime (`$[]`), and macro (`$()`) expressions distinct.
- Add approvals through protected environments rather than interactive scripts.
- Verify unfamiliar tasks and inputs against current Microsoft documentation.

## Validation

Invoke `azure-pipelines-validator`. If unavailable, parse the YAML, review expressions and templates manually, and clearly mark server-side Azure validation as not run.

## Output

List files, triggers, variables/service connections that must be configured, assumptions, and validation results.
