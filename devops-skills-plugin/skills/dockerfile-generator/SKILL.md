---
name: dockerfile-generator
description: "Use when containerizing an application or creating, modernizing, or optimizing a Dockerfile and .dockerignore."
---

# Dockerfile Generator

## Purpose

Create a production-oriented Docker build matched to the application's actual build and runtime behavior. Use `dockerfile-validator` for review-only tasks.

## Workflow

1. Inspect manifests, lockfiles, build scripts, runtime ports, health endpoints, native dependencies, and existing container conventions.
2. Resolve material choices such as runtime version, target platform, and build output; otherwise state conservative assumptions.
3. Use the matching script in `scripts/` or example in `examples/`. Read only the relevant language and security references; open `references/extended-guide.md` for advanced patterns.
4. Generate a minimal multi-stage build when it reduces the runtime surface, plus a repository-specific `.dockerignore`.
5. Validate with `dockerfile-validator`; build and smoke-test only when the environment and user scope allow it.

## Resources

- `scripts/generate_{nodejs,python,golang,java}.sh`: common scaffolds
- `references/language_specific_guides.md`: language-specific decisions
- `references/security_best_practices.md`, `optimization_patterns.md`, `multistage_builds.md`: focused guidance
- `references/extended-guide.md`: detailed examples and modern features

## Safety and gotchas

- Never bake credentials, tokens, private registries' passwords, or secret build arguments into layers.
- Use a non-root runtime user and the smallest practical runtime image, but preserve required certificates, libraries, and writable paths.
- Copy dependency manifests before source to retain cache value; keep dev-only tools out of the runtime stage.
- Pin image versions according to repository policy and verify unfamiliar image tags.

## Validation

Run `dockerfile-validator` and `scripts/test_generator.sh`. If Docker is available, build the image and probe its intended startup or health path; report any skipped runtime check.

## Output

List generated files, base-image/runtime decisions, build/run commands, assumptions, and validation evidence.
