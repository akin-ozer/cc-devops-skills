---
name: fluentbit-generator
description: "Use when creating or updating Fluent Bit inputs, filters, parsers, outputs, routing, or complete logging pipelines."
---

# Fluent Bit Generator

## Purpose

Generate a coherent Fluent Bit classic-mode pipeline for the requested source, processing, and destination. Use `fluentbit-validator` for validation-only work.

## Workflow

1. Inspect existing Fluent Bit configuration and determine deployment environment, input, tag scheme, filters/parsers, output, buffering, and credential source.
2. Clarify only choices that affect routing or delivery guarantees.
3. Reuse the closest file in `examples/` or compose with `scripts/generate_config.py`; open `references/extended-guide.md` only for detailed plugin options and fallback flows.
4. Generate all required config fragments with consistent tags and includes.
5. Run `fluentbit-validator`, fix generator-owned findings, and rerun.

## Resources

- `scripts/generate_config.py`: supported pipeline scaffolding
- `examples/`: focused source/destination and processing patterns
- `references/extended-guide.md`: plugin lookup and advanced generation details

## Safety and gotchas

- Reference credentials through environment variables or the platform secret store.
- Ensure every output `Match` can receive the intended input tag; avoid accidental catch-all duplication.
- Configure filesystem buffering, retries, and limits deliberately for production delivery.
- Verify version-specific plugin keys against official Fluent Bit documentation.

## Validation

Run `fluentbit-validator` and `python3 scripts/test_generate_config.py` when Python is available. If `fluent-bit` is installed, perform a config dry-run; report skipped runtime checks.

## Output

List generated fragments, routing flow (`INPUT -> FILTER -> OUTPUT`), required secrets, assumptions, and validation results.
