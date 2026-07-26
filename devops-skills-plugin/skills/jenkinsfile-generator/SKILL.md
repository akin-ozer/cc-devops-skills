---
name: jenkinsfile-generator
description: "Use when creating or redesigning declarative or scripted Jenkinsfiles, pipeline stages, matrices, or shared-library scaffolding."
---

# Jenkinsfile Generator

## Purpose

Create a Jenkins pipeline matched to the repository, controller capabilities, and installed plugins. Use `jenkinsfile-validator` for review-only requests.

## Workflow

1. Inspect build commands, agents, container needs, credentials bindings, existing Jenkinsfiles, and shared-library conventions.
2. Choose declarative by default; use scripted syntax only when the requested control flow requires it.
3. Reuse the appropriate template or generator in `assets/` and `scripts/`. Read focused plugin/pattern references; open `references/extended-guide.md` for complex examples.
4. Generate the smallest pipeline with explicit stages, timeouts, cleanup, artifact flow, and safe credential bindings.
5. Run `jenkinsfile-validator`, fix generator-owned findings, and rerun.

## Resources

- `scripts/generate_declarative.py`, `generate_scripted.py`, `generate_shared_library.py`: scaffolds
- `assets/templates/`: minimal Jenkinsfiles
- `references/best_practices.md`, `common_plugins.md`: focused guidance
- `references/extended-guide.md`: advanced patterns and examples

## Safety and gotchas

- Never interpolate credentials into Groovy strings or shell command text.
- Verify non-core steps against the target plugin version.
- Keep controller-side work small and place build work on agents.
- Do not trigger jobs, deploy, or publish while generating files.

## Validation

Run `jenkinsfile-validator` plus the matching generator tests. Mark controller compilation and plugin-resolution behavior as unverified when no Jenkins instance is available.

## Output

List files, required plugins/credentials/agents, assumptions, execution notes, and validation evidence.
