---
name: ansible-generator
description: Comprehensive toolkit for generating best practice Ansible playbooks, roles, tasks, and inventory files.
---

# Ansible Generator

## Trigger Phrases

Use this skill when the request is to generate or scaffold Ansible content, for example:

- "Create a playbook to deploy nginx with TLS."
- "Generate an Ansible role for PostgreSQL backups."
- "Write inventory files for prod and staging."
- "Build reusable Ansible tasks for user provisioning."
- "Initialize an Ansible project with ansible.cfg and requirements.yml."
- "Give me a quick Ansible snippet to install Docker."

Do not use this skill as the primary workflow when the request is validation/debug-only (syntax errors, lint failures, Molecule/test failures). Use `ansible-validator` for those cases.

## Deterministic Execution Flow

Run these stages in order. Do not skip a stage unless the `Validation Exceptions Matrix` explicitly allows it.

### Stage 0: Classify Request Mode

Determine one mode first:

| Mode | Typical user intent | Deliverable |
| --- | --- | --- |
| `full-generation` | "create/build/generate" a full playbook/role/inventory/project file set | Complete file(s), production-ready |
| `snippet-only` | "quick snippet/example" without full file context | Focused task/play snippet |
| `docs-only` | explanation, pattern comparison, or conceptual guidance only | Explanatory content, optional examples |

### Stage 1: Collect Minimum Inputs

If details are missing, ask briefly. If the user does not provide them, proceed with safe defaults and state assumptions.

| Resource type | Required inputs | Safe defaults if missing |
| --- | --- | --- |
| Playbook | target hosts, privilege (`become`), OS family, objective | `hosts: all`, `become: false`, OS-agnostic modules |
| Role | role name, primary service/package, supported OS | role name from task domain, Debian + RedHat vars |
| Tasks file | operation scope, required vars, execution context | standalone reusable tasks with documented vars |
| Inventory | environments, host groups, hostnames/IPs | `production`/`staging` groups with placeholders |
| Project config | collections/roles dependencies, lint policy | minimal `ansible.cfg`, `requirements.yml`, `.ansible-lint` |

### Stage 2: Reference Extraction Checklist

Before drafting content, extract the following from local references/templates.

#### Required references

- `references/best-practices.md`
  - Extract: FQCN requirements, idempotency rules, naming, security expectations.
- `references/module-patterns.md`
  - Extract: correct module/parameter patterns for the exact task type.

#### Required templates by output type

- Playbook: `assets/templates/playbook/basic_playbook.yml`
- Role: `assets/templates/role/` (including `meta/argument_specs.yml` and `molecule/default/` for test scaffolding)
- Inventory (INI): `assets/templates/inventory/hosts`
- Inventory (YAML): `assets/templates/inventory/hosts.yml`
- Project config: `assets/templates/project/ansible.cfg`, `assets/templates/project/requirements.yml`, `assets/templates/project/.ansible-lint`

#### Extraction checks

- Identify every `[PLACEHOLDER]` that must be replaced.
- Decide module selection priority (`ansible.builtin.*` first).
- Capture at least one OS-appropriate package pattern when OS-specific behavior is needed.
- Capture required prerequisites (collections, binaries, target assumptions).

### Stage 3: Generate

Apply these generation standards:

1. Use FQCN module names (`ansible.builtin.*` first choice).
2. Keep tasks idempotent (`state`, `creates/removes`, `changed_when` when needed).
3. Use descriptive verb-first task names.
4. Use `true`/`false` booleans (not `yes`/`no`).
5. Add `no_log: true` for sensitive values.
6. Replace all placeholders before presenting output.
7. Prefer `ansible.builtin.dnf` for RHEL 8+/CentOS 8+ (legacy `yum` only for older systems).

### Stage 4: Validate (Default) or Apply Exception (Fallback)

Use the matrix below to keep validation deterministic and non-blocking.

## Validation Exceptions Matrix

| Scenario | Default behavior | Allowed fallback | What to report |
| --- | --- | --- | --- |
| `full-generation` | Run `ansible-validator` after generation and after each fix pass | If validator/tools are unavailable, run manual static checks (YAML shape, placeholder scan, FQCN/idempotency/security review) and provide exact deferred validation commands | Explicitly list which checks ran, which were skipped, and why |
| `snippet-only` | Skip full validator by default; do inline sanity checks | Run full validator only if user asks or snippet is promoted to full file | State that validation was limited because output is snippet-only |
| `docs-only` | No runtime validation | None needed | State that no executable artifact was generated |
| Offline environment (no web/docs access) | Continue with local references and templates | Skip external doc lookups; prefer builtin-module implementations; provide notes for later external verification | State offline constraint and impacted checks/lookups |

## Resource Generation Guidance

### Playbooks

- Use `assets/templates/playbook/basic_playbook.yml` as structure.
- Include: header comments, `pre_tasks`/`tasks`/`post_tasks` as needed, handlers, tags.
- Add health checks when service deployment/configuration is involved.

### Roles

- Build from `assets/templates/role/` structure.
- Keep defaults in `defaults/main.yml`; keep higher-priority role vars in `vars/main.yml`.
- Include OS-specific vars (`vars/Debian.yml`, `vars/RedHat.yml`) when relevant.
- Add `meta/argument_specs.yml` for variable validation.
- Include `molecule/default/` scaffold (from `assets/templates/role/molecule/`) for production-ready roles.

### Task Files

- Keep scope narrow and reusable.
- Document required input variables in comments.
- Use conditionals for environment/OS-sensitive operations.

### Inventory

- Build logical host groups and optional group hierarchies.
- Use variable layering intentionally: `group_vars/all.yml` -> group -> host.
- Default to INI format (`hosts`) for simple topologies; use YAML format (`hosts.yml`) when the user requests it or when the hierarchy is complex.

### Project Configuration

- Provide baseline `ansible.cfg`, `requirements.yml`, and `.ansible-lint`.
- Keep defaults practical and editable.

## Custom Modules and Collections

When the request depends on non-builtin modules/collections:

1. Identify collection + module and required version sensitivity.
2. Check local `references/module-patterns.md` first.
3. If still unresolved and network/tools are available, query Context7:
   - `mcp__context7__resolve-library-id`
   - `mcp__context7__query-docs`
4. If Context7 is unavailable, use official Ansible docs / Ansible Galaxy pages.
5. If external lookup is unavailable, provide a builtin fallback approach and state the limitation.

Always include collection installation guidance when collection modules are used.

## Canonical Example Flows

### Flow A: Full Generation (Playbook)

User prompt: "Create a playbook to deploy nginx with TLS on Ubuntu and RHEL."

1. Classify as `full-generation`.
2. Gather/confirm required inputs (hosts, cert paths, become, service name).
3. Extract required references (`best-practices.md`, `module-patterns.md`) and playbook template.
4. Generate complete playbook with OS conditionals (`apt`/`dnf`), handlers, validation for config templates.
5. Run `ansible-validator`.
6. Fix issues and rerun until checks pass (or apply matrix fallback if tooling unavailable).
7. Present output with validation summary, usage command, and prerequisites.

### Flow B: Quick Snippet (Task Block)

User prompt: "Give me a snippet to create a user and SSH key."

1. Classify as `snippet-only`.
2. Extract minimal module patterns for `ansible.builtin.user` and `ansible.builtin.authorized_key`.
3. Generate concise snippet with FQCN, idempotency, and variable placeholders.
4. Perform inline sanity checks (YAML shape, FQCN, obvious idempotency/security).
5. Present snippet and note that full validator run was skipped due to snippet-only mode.

## Output Requirements

For generated executable artifacts, use this response structure:

```markdown
## Generated [Resource Type]: [Name]

**Validation Status:** [Passed / Partially validated / Skipped with reason]
- YAML syntax: [status]
- Ansible syntax: [status]
- Lint: [status]

**Summary:**
- [What was generated]
- [Key implementation choices]

**Assumptions:**
- [Defaults or inferred values]

**Usage:**
```bash
[Exact command(s)]
```

**Prerequisites:**
- [Collections, binaries, environment needs]
```

## Done Criteria

This skill execution is complete only when all applicable items are true:

- Trigger decision is explicit (`full-generation`, `snippet-only`, or `docs-only`).
- Required references/templates were consulted for the selected artifact type.
- Generated output has no unresolved placeholders.
- Validation followed default behavior or a documented exception from the matrix.
- Any skipped checks include a concrete reason and deferred command(s).
- Final output includes summary, assumptions, usage, and prerequisites.
