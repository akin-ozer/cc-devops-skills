---
name: promql-validator
description: "Use when syntax-checking, reviewing, optimizing, fixing, or explaining PromQL queries, recording rules, and alert expressions."
---

# PromQL Validator

## Purpose

Validate PromQL syntax and likely semantics, explain findings, and distinguish static inference from live Prometheus evidence.

## Workflow

1. Capture the query or rule, intended meaning, Prometheus version, metric types, scrape interval, and expected label shape when available.
2. Run `scripts/validate_syntax.py` and `scripts/check_best_practices.py` against the expression.
3. Read `docs/anti_patterns.md` or `best_practices.md` only for matching findings; use `references/extended-guide.md` for detailed examples and limitations.
4. Compare the expression with the stated intent and rank correctness issues ahead of optional optimization.
5. Apply fixes only when requested, rerun both scripts, and validate against Prometheus when safely available.

## Resources

- `scripts/validate_syntax.py`: deterministic syntax checks
- `scripts/check_best_practices.py`: semantic and performance heuristics
- `docs/`: anti-pattern and remediation guidance
- `references/extended-guide.md`: detailed workflow and known limitations

## Safety and gotchas

- Static checks cannot prove metric existence, type, label cardinality, or data shape.
- Do not infer that a name ending in `_total` is always a counter when metadata contradicts it.
- Preserve vector-matching and output-label semantics while optimizing.
- Avoid executing expensive production range queries without authorization.

## Validation

Run `python3 scripts/test_validators.py` when changing this skill. If live evaluation is unavailable, explicitly separate parser/heuristic results from runtime validity.

## Output

Report syntax, semantic, performance, and intent findings separately, followed by explanation, remediation, coverage limits, and rerun result.
