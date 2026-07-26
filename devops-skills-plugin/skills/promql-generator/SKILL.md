---
name: promql-generator
description: "Use when creating or refining PromQL for dashboards, ad-hoc analysis, recording rules, alert rules, SLOs, RED, or USE monitoring."
---

# PromQL Generator

## Purpose

Translate a monitoring goal into semantically correct, efficient PromQL with explicit metric and time-window assumptions.

## Workflow

1. Determine the goal, usage context, available metric names/types/labels, scrape interval, desired grouping, time window, units, and Prometheus version.
2. Ask only about unknowns that materially change semantics. When metric metadata is unavailable, use clearly marked placeholders rather than inventing names.
3. Read the focused metric, function, pattern, or best-practice reference and the closest example. Open `references/extended-guide.md` for native histograms, SLO burn rates, or advanced vector matching.
4. Build the smallest query that preserves label semantics; add recording or alert rule structure only when requested.
5. Run `promql-validator`, fix findings, and verify against Prometheus when a safe query endpoint is available.

## Resources

- `references/metric_types.md`, `promql_functions.md`, `promql_patterns.md`, `best_practices.md`: focused guidance
- `examples/`: common, Kubernetes, RED/USE, SLO, alert, and recording patterns
- `references/extended-guide.md`: advanced features and detailed planning

## Safety and gotchas

- Use `rate`/`increase` on counters and preserve required labels in aggregations.
- Aggregate classic histogram buckets by `le` before `histogram_quantile`; do not average quantiles.
- Avoid broad regexes, unbounded high-cardinality grouping, and expensive long subqueries.
- Do not execute costly production queries without authorization.
- Verify version-specific native-histogram functions against official Prometheus docs.

## Validation

Run `promql-validator` plus the generator regression tests. Mark live metric existence, cardinality, and runtime evaluation as unverified when no Prometheus endpoint is available.

## Output

Provide query/rule, assumptions, behavior in plain language, expected units/legend, validation evidence, and performance notes.
