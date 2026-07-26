---
name: terragrunt-generator
description: "Use when creating or extending Terragrunt root/child HCL, multi-environment layouts, dependencies, stacks, units, or OpenTofu integration."
---

# Terragrunt Generator

## Purpose

Create a Terragrunt layout that keeps environment wiring clear and matches the repository's Terraform modules and supported Terragrunt version. Use `terragrunt-validator` for review-only work.

## Workflow

1. Inspect existing root includes, directory hierarchy, Terraform sources, dependency outputs, remote-state conventions, and version constraints.
2. Choose an environment-agnostic root, environment-aware root, or shared environment-vars pattern based on the repository rather than forcing a universal layout.
3. Read `references/common-patterns.md`. Open `references/extended-guide.md` only for its detailed layout examples, stacks, feature/exclude/errors blocks, and migration guidance.
4. Generate the smallest file set with explicit source versions, named includes, clear inputs, and non-secret placeholders.
5. Run `terragrunt-validator`, fix generator-owned findings, and rerun without apply.

## Resources

- `references/common-patterns.md`: reusable layout and configuration patterns
- `references/extended-guide.md`: architecture patterns, modern features, and migrations

## Safety and gotchas

- Prefer `root.hcl` for new roots when supported; preserve an existing convention unless migration is requested.
- Do not read or write credentials, populated state settings, or secrets into HCL.
- Pin remote module sources; avoid floating branch refs for production.
- Resolve dependency cycles and mock-output scope deliberately.
- Never run apply, destroy, stack mutation, or state operations while generating files.

## Validation

Run `terragrunt-validator` and `test/test_templates.py`. Report version, init/provider availability, dependency resolution, and plan coverage separately.

## Output

Show the generated tree, files and placeholders, architecture choice, required environment inputs, safe next commands, and validation evidence.
