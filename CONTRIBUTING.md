# Contributing Skill Packs

This repo packages DevOps skills under `devops-skills-plugin/skills/`.
Use the existing packs as the contract: keep names predictable, put reusable
helpers in the skill folder, and wire generated output back through the matching
validator when one exists.

## Skill Folder Layout

Create one directory per skill:

```text
devops-skills-plugin/skills/<kebab-case-skill-name>/
  SKILL.md
  scripts/
  references/ or docs/
  examples/
  assets/
  tests/ or test/
```

Only `SKILL.md` is required for every skill, but most production skills include
some of the optional folders above:

- `scripts/`: executable shell or Python helpers used by the skill instructions.
- `references/` or `docs/`: local guidance that the skill reads before external lookup.
- `examples/`: known-good and known-bad fixtures or generated examples.
- `assets/`: templates or static files copied by generators.
- `tests/` or `test/`: regression tests for scripts, fixtures, or skill contracts.

Use lowercase kebab-case directory names. The folder name, frontmatter `name`,
and any cross-skill references should match exactly, for example
`dockerfile-generator`, `gitlab-ci-validator`, or `k8s-yaml-generator`.

## `SKILL.md` Frontmatter

Every `SKILL.md` starts with YAML frontmatter bounded by `---`. At minimum it
must declare:

```yaml
---
name: <folder-name>
description: <short trigger-oriented description>
---
```

Rules:

- `name` is required and must equal the skill directory name.
- `description` is required and should describe when an agent should use the skill.
- Keep the description concise and action-oriented, as in existing skills:
  `Create, generate, or scaffold ...` for generators and
  `Validate, lint, audit, or ...` for validators.
- Put the operational workflow, trigger phrases, local file map, and fallback
  behavior below the frontmatter in Markdown.

## Generator and Validator Pairing

Most domains are represented as a generator plus a validator:

```text
<domain>-generator
<domain>-validator
```

Examples in this repo include `dockerfile-generator` paired with
`dockerfile-validator`, `helm-generator` with `helm-validator`, and
`gitlab-ci-generator` with `gitlab-ci-validator`.

Follow these conventions when adding or changing a pair:

- Name paired skills with the same domain prefix and `-generator` or
  `-validator` suffix.
- In the generator `SKILL.md`, explicitly require validation with the matching
  validator skill after artifacts are generated.
- Include a script fallback path when the validator skill cannot be invoked, for
  example `devops-skills-plugin/skills/<domain>-validator/scripts/validate_*.sh`.
- Generator helper scripts usually start with `generate_` and may have
  `test_generator.sh` or targeted regression tests.
- Validator entry scripts usually start with `validate_`, `check_`, `run_`, or
  use a domain-specific validation name such as `dockerfile-validate.sh`.
- Re-run the validator after generator fixes when the generated artifact changes.

When a domain has no validator yet, state the local fallback checks in the
generator and prefer adding a validator before expanding generation behavior.

## Before Opening a PR

- Confirm the new directory is under `devops-skills-plugin/skills/`.
- Confirm `SKILL.md` has `name` and `description` frontmatter.
- Run shell/Python syntax checks for new scripts.
- Run the skill's tests or add focused regression coverage for new behavior.
- Update `README.md` if the skill catalog or installation guidance changes.
