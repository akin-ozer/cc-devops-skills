---
name: helm-generator
description: "Use when creating or extending Helm charts, Chart.yaml, values, templates, helpers, schemas, or CRD-aware packaging."
---

# Helm Generator

## Purpose

Create a Helm chart that renders predictable Kubernetes resources and follows the repository's chart conventions. Use `helm-validator` for validation-only requests.

## Workflow

1. Inspect application manifests, ports, probes, configuration, secret inputs, workload type, and any existing chart conventions.
2. Clarify only deployment choices that materially affect templates or values.
3. Use `scripts/generate_chart_structure.sh` and `generate_standard_helpers.sh` where appropriate. Read the closest file in `references/` or template in `assets/`; open `references/extended-guide.md` for advanced patterns.
4. Generate a minimal chart with a clear values surface, stable naming helpers, labels, NOTES, and schema where useful.
5. Run `helm-validator`, fix generator-owned findings, and rerun with representative values.

## Resources

- `scripts/`: chart and helper scaffolding
- `references/`: chart resource, template-function, and CRD guidance
- `assets/`: helpers, values-schema, and ignore-file starters
- `references/extended-guide.md`: full workflow and troubleshooting

## Safety and gotchas

- Do not place secret values in defaults; expose secret references or documented placeholders.
- Quote strings intentionally, preserve numeric/boolean types, and use whitespace controls carefully.
- Verify CRD schemas and supported API versions against the target platform.
- Do not install or upgrade a release while generating a chart.

## Validation

Run `helm-validator` plus `tests/test_generate_chart_structure.sh`. Render with representative value combinations and report unavailable cluster-side validation.

## Output

List chart files, required values/secrets, supported assumptions, render commands, and validation evidence.
