---
name: ansible-validator
description: "Use when validating, linting, security-reviewing, testing, or debugging existing Ansible playbooks, roles, tasks, inventories, or collections."
---

# Ansible Validator

## Purpose

Produce an evidence-based Ansible validation report and, when requested, apply minimal fixes. Use `ansible-generator` for new scaffolding.

## Workflow

1. Resolve the target path and classify it as a playbook, role, inventory, or collection. Inspect its config and dependency files.
2. Run the relevant local wrapper from `scripts/`; prefer wrappers over reconstructing their commands.
3. Load only the reference associated with a finding: `common_errors.md`, `security_checklist.md`, `best_practices.md`, or `module_alternatives.md`.
4. For custom modules or collections, extract names and versions first, then consult authoritative version-matched documentation only where local references are insufficient.
5. Classify findings by severity, distinguish failures from unavailable checks, and rerun affected checks after any fix.

## Resources

- `scripts/validate_playbook.sh`, `validate_role.sh`, `validate_inventory.sh`: primary validators
- `scripts/test_role.sh`: Molecule-aware role test path
- `scripts/scan_secrets.sh`, `check_fqcn.sh`: focused checks
- `references/extended-guide.md`: command variants and detailed troubleshooting

## Safety and gotchas

- Default to syntax, lint, security, and check-mode operations; do not execute a live playbook without explicit authorization.
- Treat a missing inventory, credentials, container runtime, or Molecule driver as a blocked check, not a passing result.
- Redact secrets and avoid printing decrypted vault content.
- Do not install tools or mutate the target merely to complete validation unless asked.

## Validation

Run the applicable script suite and `bash test/test_regressions.sh` when changing this skill. Record commands, exit status, coverage, and skips.

## Output

Report target, checks run, findings by severity with locations, blocked/skipped checks, and the final post-fix result.
