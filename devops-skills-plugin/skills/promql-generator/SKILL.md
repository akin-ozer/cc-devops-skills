---
name: promql-generator
description: Use when the user asks to write, generate, or build PromQL queries, alerting rules, recording rules, or SLO/burn-rate expressions for Prometheus or Grafana dashboards. Triggers — "write a Prometheus query", "alert on error rate", "P95 latency", "kube-state-metrics query", "burn rate alert". Not for general Prometheus operator/installation/scrape-config questions.
---

# PromQL Query Generator

Generate production-ready PromQL queries (ad-hoc, dashboard, alerting rule, recording rule, SLO/burn-rate). Most generation is direct; collaborative planning is reserved for genuinely ambiguous requests or alerting rules going to production.

## When to use

- Creating new PromQL queries for dashboards, alerts, recording rules, or analysis
- Implementing RED (Rate, Errors, Duration) or USE (Utilization, Saturation, Errors) signals
- SLO / error-budget / burn-rate expressions
- Converting monitoring requirements into PromQL

Trigger phrases (non-exhaustive): "write a Prometheus query", "PromQL for…", "alert when error rate > X", "P95 latency for service Y", "kube-state-metrics query for…", "burn rate alert", "recording rule for…".

Not for: installing/configuring Prometheus, scrape-config debugging, exporter authoring, Grafana dashboard JSON layout, or validating/reviewing existing queries (use `devops-skills:promql-validator` for that).

## Workflow

### Fast path (default)

If the request specifies metric + service/scope + threshold-or-time-window, generate the query directly. Open the response with a one-line assumption note that surfaces every default you picked, then deliver the query and a short usage block.

Example assumption note:
> Assuming counter `http_requests_total` with labels `job`, `status_code`; rate window `[5m]`; SLO threshold `> 5%`; output as ratio (0–1).

What "specified enough" means:
- A concrete metric name or unambiguous metric category (e.g. "5xx error rate on http_requests_total", "P95 latency from `http_request_duration_seconds`").
- A target service / job / scope (`job="api"`, namespace, deployment, etc.).
- A threshold and/or time window for alerts; just a window for graphs.

### Plan-confirm path (use only when warranted)

Switch to a plan-confirm-validate loop when any of these hold:
- The metric, metric type, or label set is unknown or ambiguous.
- The user is asking for an alerting rule that will go to production (page-grade or shared SLO).
- The request mixes signals (e.g. error rate AND latency) without specifying combination semantics.
- Cardinality, cost, or aggregation level materially changes the answer and the user has not picked one.

In that mode:
1. Confirm goal, metric(s) + type, labels, window, aggregation, and threshold. Use `AskUserQuestion` if available, otherwise a single inline questionnaire.
2. Present a plain-English plan: which metric, which function, what the result means, expected labels, expected value range. Ask for confirmation, with options to modify or to see alternatives (offer at least two with trade-offs).
3. Generate the query only after confirmation.

If `AskUserQuestion` is unavailable, batch all needed questions into one message; if the user only answers some, proceed with conservative defaults and mark assumptions explicitly.

### Reference reads

Read references when any of:
- Histogram or summary quantiles are involved (see `references/metric_types.md`, `references/promql_functions.md`).
- Joins / vector matching, subqueries, offsets, `@` modifier, or recording/alerting rules (`references/promql_patterns.md`, `references/promql_functions.md`).
- SLO / burn-rate / error-budget patterns (`examples/slo_patterns.promql`).
- Optimization or cardinality concerns (`references/best_practices.md`).
- Metric type or labels are unknown.

Skip reference reads only when the request is single-metric + single-function (`rate`, `increase`, `sum`, `avg`, `max`, `min`), no joins, no rules, and metric type is clearly given. State `Reference read skipped (trivial case)` when you skip.

Cite the pattern you used (file + section) so the user can audit.

### Validation flow

After generating a query, hand off to the validator:

```
Skill(devops-skills:promql-validator)
```

The validator covers: syntax, metric-type/function compatibility, anti-patterns, performance/cardinality, intent match.

If the validator passes, deliver. If it flags issues, fix and re-validate. Cap at two fix/re-validate cycles. If the validator skill is unavailable, fails, or stalls after two cycles:

- Report the failure mode briefly (unavailable / timeout / parse error).
- Run a manual fallback check: balanced brackets, function-vs-metric-type compatibility, label filters, aggregation correctness, time-range sanity.
- Mark anything you could not check as `UNVERIFIED` and ask the user whether to proceed or supply more context. IMPORTANT: never silently skip validation — surface the gap.

Display validation results in a short structured block:

```
## Validation Results
- Syntax:        VALID | WARNING | ERROR | UNVERIFIED   [notes]
- Best practice: OK | IMPROVABLE | ISSUES | UNVERIFIED  [notes / suggestions]
- Validator run: ok | failed | unavailable              [coverage gaps]
- What it measures: <plain-English summary>
- Output shape:     <instant vector / scalar / labels kept>
```

### Delivery

Final response includes:
1. The validated query.
2. Plain-English meaning + expected value range.
3. How to use it: dashboard panel, alerting rule (`for:` clause), recording rule, ad-hoc browser.
4. Customization knobs the user is most likely to tune (window, threshold, label filters).

## Decision tree (metric type → function)

| Metric type | Identifier | Use |
|---|---|---|
| Counter | `_total` suffix; monotonically increasing | `rate()`, `irate()`, `increase()` |
| Gauge | no suffix; can go up or down | direct, `avg_over_time()`, `max_over_time()`, `deriv()` |
| Classic histogram | `_bucket` + `le` label | `histogram_quantile(q, sum by (le, …) (rate(…_bucket[…])))` |
| Native histogram | no `_bucket`, no `le` | `histogram_quantile(q, sum by (…) (rate(metric[…])))` |
| Summary | `{quantile="…"}` | use quantile labels directly; never average them |

Anti-patterns to avoid (full list in `references/best_practices.md`): no label filters, regex when exact match suffices, `rate()` on gauges, missing `rate()` on histogram buckets, missing `le` in aggregation, averaging summary quantiles, joining on high-cardinality labels.

## Common issues

| Symptom | Likely cause | Fix |
|---|---|---|
| Empty result | metric not scraped, label typo, range too short | check `up{job="…"}`, verify label values, widen range |
| Too many series | high-cardinality label, no filters | add label filters, aggregate, or pre-record |
| Wrong values | wrong function for type (e.g. `rate` on gauge) | match function to metric type per decision tree |
| Slow query | long range, expensive subquery, regex | shrink range, use recording rule, prefer exact match |
| Quantile spikes implausibly high | missing `le` in aggregation, or histogram has too few buckets in that range | add `le` to `sum by (…)`, check bucket configuration |

## References and examples

References (read on demand):
- `references/promql_functions.md` — every function, grouped by category; includes native-histogram functions, subqueries, `@` modifier.
- `references/promql_patterns.md` — RED / USE / availability / saturation / vector-matching / Kubernetes joins / `offset` / `group_left` / `unless`.
- `references/metric_types.md` — Counter / Gauge / Histogram (classic + native + NHCB) / Summary; choosing a type.
- `references/best_practices.md` — cardinality, optimization, anti-pattern catalog, recording-rule naming.

Examples (copy-and-adapt):
- `examples/common_queries.promql` — request rate, error rate, latency.
- `examples/red_method.promql` — full RED implementation.
- `examples/use_method.promql` — full USE implementation.
- `examples/slo_patterns.promql` — error budget, burn rate, multi-window multi-burn-rate alerts, latency SLO compliance.
- `examples/alerting_rules.yaml` — production-shaped alerting rules with `for:` clauses.
- `examples/recording_rules.yaml` — recording rules with `level:metric:operations` naming.
- `examples/kubernetes_patterns.promql` — kube-state-metrics + cAdvisor patterns and joins.

## Documentation lookup

For features, operators, or behavior you are not sure about:

1. Prefer Context7:
   - `Context7:resolve-library-id` with `prometheus`
   - `Context7:query-docs` with the resolved id, topic = the function/operator name
2. Fallback: WebSearch with `Prometheus PromQL <feature> documentation examples`.

## Integration with sibling skills

- `devops-skills:promql-validator` — call after generation. This skill defers all syntax/anti-pattern checks to the validator.
- For "review my existing query" / "what's wrong with this" requests, hand off to the validator directly rather than regenerating.
