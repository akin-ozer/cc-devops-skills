---
name: ansible-generator
description: "Use when creating or scaffolding Ansible playbooks, roles, tasks, handlers, inventories, variables, or project configuration."
---

# Ansible Generator

## Purpose

Create maintainable Ansible content from a stated automation goal. Use `ansible-validator` instead when the request is only to inspect or debug existing content.

## Workflow

1. Inspect the repository and identify the requested artifact, supported operating systems, inventory shape, privilege needs, and existing Ansible conventions.
2. Ask only about missing details that materially change the result; otherwise choose conservative defaults and state them.
3. Read `references/module-patterns.md` for non-trivial module usage and `references/best-practices.md` for project or role design. Open `references/extended-guide.md` only for detailed examples or unusual resource types.
4. Generate the smallest complete file set. Prefer FQCNs, idempotent modules, handlers for restarts, explicit file modes, and variables for environment-specific values.
5. Run the matching validator and fix findings caused by the generated content.

## Resources

- `references/module-patterns.md`: module and collection patterns
- `references/best-practices.md`: reusable design and security guidance
- `references/extended-guide.md`: detailed artifact checklists and examples

Read only the resources needed for the request.

## Safety and gotchas

- Do not embed credentials, vault passwords, private keys, or production host data.
- Do not replace idempotent modules with `shell` or `command` without a documented reason and suitable `changed_when`.
- Verify collection names and version-sensitive parameters against local metadata or official documentation.
- Never run a generated playbook against an inventory unless the user explicitly asks.

## Validation

Use `ansible-validator` on the generated path. If its tooling is unavailable, at minimum parse YAML and run `ansible-playbook --syntax-check` when installed; report every skipped check.

## Output

Summarize files created, assumptions, variables the user must set, and validation results.
