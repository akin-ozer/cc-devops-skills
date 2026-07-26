---
name: logql-generator
description: "Use when creating or refining LogQL stream selectors, parsing/filter pipelines, metric queries, recording rules, or Loki alert expressions."
---

# LogQL Generator

## Purpose

Translate a logging or alerting goal into correct, efficient LogQL with explicit label and time-window assumptions.

## Workflow

1. Identify the use case, available stream labels, representative log shape, Loki version, time range, and whether the result is for exploration, dashboarding, recording, or alerting.
2. Ask only for missing inputs that change parsing or aggregation; otherwise provide an adaptable query with stated placeholders.
3. Read `references/best_practices.md` and `examples/common_queries.logql` only as needed for the selected query family. Open `references/extended-guide.md` for advanced parser, performance, alert, and modern-feature guidance.
4. Build incrementally: selector, line filters, parser, label filters, unwrap/aggregation, then alert comparison if needed.
5. Run `scripts/run_regression_checks.sh` for repository behavior and validate against Loki when a safe query endpoint is available.

## Resources

- `references/best_practices.md`: query design and performance guidance
- `examples/common_queries.logql`: representative query families
- `references/extended-guide.md`: detailed planning and modern features

## Safety and gotchas

- Keep stream selectors selective; line filters do not reduce index scanning.
- Do not create unbounded high-cardinality labels from log fields.
- Apply range selectors and `unwrap` in the correct pipeline position.
- Avoid executing expensive broad queries against production without user authorization.
- Verify version-specific functions against official Loki documentation.

## Validation

Run `scripts/run_regression_checks.sh`. When a Loki endpoint is unavailable, label syntax/runtime validation as not run and explain what was checked manually.

## Output

Provide the query or rule, assumptions, plain-language behavior, expected legend/units, validation evidence, and likely performance implications.
