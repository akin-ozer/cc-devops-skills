# PromQL Anti-Patterns

Comprehensive guide to common mistakes, anti-patterns, and pitfalls in PromQL queries.

## Table of Contents

1. [High Cardinality Issues](#high-cardinality-issues)
2. [Incorrect Function Usage](#incorrect-function-usage)
3. [Performance Anti-Patterns](#performance-anti-patterns)
4. [Mathematical Errors](#mathematical-errors)
5. [Label Matching Problems](#label-matching-problems)
6. [Aggregation Mistakes](#aggregation-mistakes)
7. [Time Range Issues](#time-range-issues)
8. [Histogram and Summary Misuse](#histogram-and-summary-misuse)

---

## High Cardinality Issues

### Anti-Pattern 1: Unbounded Metric Selectors

**Problem**: Querying metrics without any label filters matches all time series, causing high cardinality.

```promql
# ❌ BAD: No filters - could match thousands of series
http_requests_total

# ❌ BAD: Empty label matcher
http_requests_total{}

# ✅ GOOD: Specific label filters
http_requests_total{job="api-service", environment="production"}
```

**Impact**:
- Query times: seconds to minutes instead of milliseconds
- High memory usage on Prometheus
- Risk of query timeouts
- Increased load on Prometheus server

**Detection**: Look for metric names without `{...}` selectors or with empty `{}`.

---

### Anti-Pattern 2: High-Cardinality Labels in Queries

**Problem**: Querying on labels with thousands of unique values.

```promql
# ❌ BAD: User ID has millions of unique values
http_requests_total{user_id="12345"}

# ✅ GOOD: Use low-cardinality labels
http_requests_total{job="api", endpoint="/users"}
```

**High-cardinality labels to avoid**:
- User IDs, customer IDs
- Request IDs, trace IDs
- Timestamps
- UUIDs
- Email addresses, IP addresses (unless aggregated)
- Full URLs (use path patterns instead)

**Low-cardinality labels (safe to use)**:
- Job name
- Instance name
- Service name
- Environment (prod, staging, dev)
- Status codes
- HTTP methods
- Endpoint paths (grouped)

---

### Anti-Pattern 3: Wildcard Regex Without Constraints

**Problem**: Overly broad regex patterns match too many series.

```promql
# ❌ BAD: Matches everything
http_requests_total{path=~".*"}

# ❌ BAD: Very broad pattern
http_requests_total{instance=~".*-prod-.*"}

# ✅ GOOD: Specific pattern with other filters
http_requests_total{
  job="api",
  instance=~"api-prod-[0-9]+",
  datacenter="us-east-1"
}
```

---

## Incorrect Function Usage

### Anti-Pattern 4: Missing rate() on Counters

**Problem**: Using counter metrics without rate() or increase() gives meaningless values.

```promql
# ❌ BAD: Raw counter value (always increasing, not useful)
http_requests_total{job="api"}

# ❌ BAD: Aggregating raw counters
sum(http_requests_total)

# ✅ GOOD: Use rate() for per-second rate
rate(http_requests_total{job="api"}[5m])

# ✅ GOOD: Use increase() for total increase
increase(http_requests_total{job="api"}[1h])
```

**Why it's wrong**: Counters only increase (or reset). The raw value shows total count since process start, not current rate.

---

### Anti-Pattern 5: Using rate() on Gauges

**Problem**: rate(), irate(), and increase() assume monotonically increasing values. Gauges go up and down.

```promql
# ❌ BAD: rate() on gauge (memory can go up or down)
rate(node_memory_usage_bytes[5m])

# ❌ BAD: irate() on gauge
irate(cpu_temperature_celsius[5m])

# ✅ GOOD: Use gauge directly
node_memory_usage_bytes

# ✅ GOOD: Or use avg_over_time for smoothing
avg_over_time(node_memory_usage_bytes[5m])

# ✅ GOOD: Use delta() if you need change over time
delta(cpu_temperature_celsius[5m])
```

**How to identify**:
- Counters typically end with: `_total`, `_count`, `_sum`, `_bucket`
- Gauges typically indicate current state: `_bytes`, `_usage`, `_percent`, `_celsius`

---

### Anti-Pattern 6: rate() Without Range Vector

**Problem**: rate(), irate(), increase() require a time range.

```promql
# ❌ BAD: Missing range vector
rate(http_requests_total)

# ❌ BAD: Missing range vector
increase(requests_total{job="api"})

# ✅ GOOD: Include time range
rate(http_requests_total[5m])

# ✅ GOOD: Include range for increase
increase(requests_total{job="api"}[1h])
```

**Error message**: `"parse error: expected type range vector in call to function, got instant vector"`

---

## Performance Anti-Patterns

### Anti-Pattern 7: Excessive Subquery Time Ranges

**Problem**: Subqueries over very long time ranges process millions of samples.

```promql
# ❌ BAD: 95-day subquery (extremely slow, may timeout)
max_over_time(rate(http_requests_total[5m])[95d:1m])

# ❌ BAD: Long range with high resolution
avg_over_time(metric[30d:10s])

# ✅ GOOD: Reasonable time range
max_over_time(rate(http_requests_total[5m])[7d:5m])

# ✅ BETTER: Use recording rules for long-term analysis
# Create recording rule:
# - record: :http_requests:rate5m
#   expr: rate(http_requests_total[5m])
# Then query:
max_over_time(:http_requests:rate5m[30d:1h])
```

**Impact**:
- Query timeouts
- Excessive memory usage (GBs)
- Prometheus server overload
- Minutes to execute instead of seconds

---

### Anti-Pattern 8: Regex Instead of Exact Match

**Problem**: Using regex (=~) when exact match (=) would work.

```promql
# ❌ BAD: Regex for exact match (slower)
http_requests_total{status=~"200"}

# ❌ BAD: Regex that's actually exact
http_requests_total{job=~"api-service"}

# ✅ GOOD: Exact match (faster index lookup)
http_requests_total{status="200"}

# ✅ GOOD: Exact match
http_requests_total{job="api-service"}
```

**Performance difference**: Exact matches can be 5-10x faster due to index lookups vs pattern matching.

**When regex IS appropriate**:
```promql
# ✅ GOOD: Multiple alternatives
http_requests_total{status=~"200|201|204"}

# ✅ GOOD: Pattern matching
http_requests_total{path=~"/api/v[0-9]+/.*"}

# ✅ GOOD: Exclusions
http_requests_total{path!~"/health|/metrics"}
```

---

### Anti-Pattern 9: Not Using Recording Rules for Complex Queries

**Problem**: Running expensive queries repeatedly in multiple dashboards/alerts.

```promql
# ❌ BAD: Complex query used in 10 dashboards, evaluated 100 times/minute
sum by (job, instance) (
  rate(http_request_duration_seconds_sum{job="api"}[5m])
) /
sum by (job, instance) (
  rate(http_request_duration_seconds_count{job="api"}[5m])
)

# ✅ GOOD: Create recording rule (evaluated once per cycle)
# prometheus.yml:
# - record: job_instance:http_request_duration_seconds:mean5m
#   expr: |
#     sum by (job, instance) (
#       rate(http_request_duration_seconds_sum{job="api"}[5m])
#     ) /
#     sum by (job, instance) (
#       rate(http_request_duration_seconds_count{job="api"}[5m])
#     )

# Then use pre-computed metric:
job_instance:http_request_duration_seconds:mean5m
```

**When to use recording rules**:
- Query is complex (multiple functions, aggregations)
- Query is used frequently (dashboards, multiple alerts)
- Query is slow (>1 second)
- Query uses subqueries

---

### Anti-Pattern 10: Filter After Aggregation

**Problem**: Filtering after expensive aggregation processes unnecessary data.

```promql
# ❌ BAD: Aggregates all jobs first, then filters
sum(rate(http_requests_total[5m])) and {job="api"}

# ❌ BAD: Processes all data before filtering
sum by (job) (rate(http_requests_total[5m])) == {job="api"}

# ✅ GOOD: Filter first, then aggregate
sum(rate(http_requests_total{job="api"}[5m]))

# ✅ GOOD: Specific filters reduce data early
sum by (path) (rate(http_requests_total{job="api", status="200"}[5m]))
```

**Performance impact**: 10-100x slower when filtering after aggregation.

---

## Mathematical Errors

### Anti-Pattern 11: Averaging Pre-Calculated Quantiles

**Problem**: Averaging quantiles across instances is mathematically invalid.

```promql
# ❌ BAD: Mathematically incorrect!
avg(http_request_duration_seconds{quantile="0.95"})

# ❌ BAD: Summing quantiles is also wrong
sum(response_time_seconds{quantile="0.99"})

# ✅ GOOD: Calculate quantile from histogram buckets
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# ✅ GOOD: Calculate average from _sum and _count
rate(http_request_duration_seconds_sum[5m])
/
rate(http_request_duration_seconds_count[5m])
```

**Why it's wrong**: Quantiles are non-additive. The average of two 95th percentiles is NOT the overall 95th percentile.

**Solution**: Use histograms instead of summaries when you need aggregation.

---

### Anti-Pattern 12: Division with Mismatched Labels

**Problem**: Dividing metrics with different label sets gives unexpected results.

```promql
# ❌ BAD: Labels don't match (no instance on right side)
rate(http_requests_total{job="api", instance="host1"}[5m])
/
rate(http_requests_total{job="api"}[5m])

# Result: No data (label mismatch)

# ✅ GOOD: Ensure both sides have same label filters
rate(http_requests_total{job="api", status="500"}[5m])
/
rate(http_requests_total{job="api"}[5m])

# ✅ GOOD: Use aggregation to match label dimensions
sum(rate(http_requests_total{status="500"}[5m]))
/
sum(rate(http_requests_total[5m]))
```

---

## Label Matching Problems

### Anti-Pattern 13: Incorrect offset Modifier Usage

**Problem**: Using offset incorrectly or misunderstanding its placement.

```promql
# ✅ CORRECT: offset after range vector selector
http_requests_total[5m] offset 1h

# ✅ CORRECT: offset with instant vector
http_requests_total offset 1h

# ✅ CORRECT: offset inside rate() function
rate(http_requests_total[5m] offset 1h)

# ❌ BAD: offset between metric name and range (invalid syntax)
http_requests_total offset 1h [5m]
```

**Note**: The `offset` modifier shifts the time range back by the specified duration. It comes AFTER the selector (including range vector bracket if present).

---

### Anti-Pattern 14: Multiple OR for Same Label

**Problem**: Using multiple OR operations instead of regex alternation.

```promql
# ❌ BAD: Multiple queries combined with OR
http_requests_total{job="api"}
or
http_requests_total{job="web"}
or
http_requests_total{job="worker"}

# ✅ GOOD: Single regex with alternatives
http_requests_total{job=~"api|web|worker"}

# ✅ GOOD: With aggregation
sum by (job) (rate(http_requests_total{job=~"api|web|worker"}[5m]))
```

**Performance**: Single regex is 3-5x faster than multiple ORs.

---

## Aggregation Mistakes

### Anti-Pattern 15: Aggregation Without by() or without()

**Problem**: Unclear what labels remain after aggregation.

```promql
# ❌ BAD: What labels are in the result?
sum(rate(http_requests_total[5m]))

# ❌ BAD: Unclear aggregation
avg(node_memory_usage_bytes)

# ✅ GOOD: Explicit grouping
sum by (job, instance) (rate(http_requests_total[5m]))

# ✅ GOOD: Explicit label dropping
sum without (pod, container) (rate(http_requests_total[5m]))
```

---

### Anti-Pattern 16: Aggregating Before Division

**Problem**: Order of operations affects results for ratios.

```promql
# ❌ BAD: Sum first, then divide (wrong denominator)
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))

# This gives overall average, not average per instance

# ✅ GOOD: Divide first, then aggregate (if you want per-instance avg)
sum(
  rate(http_request_duration_seconds_sum[5m])
  /
  rate(http_request_duration_seconds_count[5m])
)

# Note: Both may be valid depending on your goal!
# Be explicit about what you're calculating.
```

---

## Time Range Issues

### Anti-Pattern 17: irate() with Long Ranges

**Problem**: irate() only uses the last two samples, making longer ranges wasteful.

```promql
# ❌ BAD: irate over 1 hour (only uses last 2 samples!)
irate(http_requests_total[1h])

# ❌ BAD: irate over 10 minutes (still only 2 samples)
irate(http_requests_total[10m])

# ✅ GOOD: Use rate() for longer ranges
rate(http_requests_total[1h])

# ✅ GOOD: Use irate() with short range
irate(http_requests_total[2m])
```

**When to use irate()**:
- High-frequency monitoring (per-second spikes)
- Short time ranges (2-5 minutes)
- When you want instant rate, not average

**When to use rate()**:
- Most cases
- Alerting (more stable)
- Longer time ranges (>5 minutes)
- When you want average rate over period

---

### Anti-Pattern 18: rate() Range Too Short

**Problem**: rate() range shorter than 4x scrape interval gives inaccurate results.

```promql
# ❌ BAD: 30s range with 15s scrape interval (only 2 samples)
rate(http_requests_total[30s])

# ❌ BAD: 1m range might not have enough samples
rate(http_requests_total[1m])

# ✅ GOOD: At least 4x scrape interval (for 15s scrape: 1m minimum)
rate(http_requests_total[2m])

# ✅ GOOD: 5m is a common, safe choice
rate(http_requests_total[5m])
```

**Rule**: `rate_range >= 4 * scrape_interval`

---

## Histogram and Summary Misuse

### Anti-Pattern 19: histogram_quantile Without rate()

**Problem**: histogram_quantile needs rate() on bucket metrics.

```promql
# ❌ BAD: Missing rate() (uses raw bucket counts)
histogram_quantile(0.95,
  sum by (le) (http_request_duration_seconds_bucket)
)

# ✅ GOOD: Include rate()
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

---

### Anti-Pattern 20: histogram_quantile Without 'le' Label

**Problem**: histogram_quantile requires the 'le' (less than or equal) label.

```promql
# ❌ BAD: Missing 'le' in aggregation
histogram_quantile(0.95,
  sum by (job) (rate(http_request_duration_seconds_bucket[5m]))
)

# ✅ GOOD: Include 'le' in by() clause
histogram_quantile(0.95,
  sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
)

# ✅ GOOD: Remove other labels but keep 'le'
histogram_quantile(0.95,
  sum without (instance, pod) (rate(http_request_duration_seconds_bucket[5m]))
)
```

---

### Anti-Pattern 21: Using Summaries When You Need Aggregation

**Problem**: Summary quantiles cannot be aggregated across instances.

```promql
# ❌ BAD: Cannot meaningfully aggregate summary quantiles
avg(http_request_duration_seconds{quantile="0.95"})

# ✅ SOLUTION: Use histograms instead of summaries
# Histograms allow aggregation:
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

**When to use each**:
- **Histogram**: Need to aggregate across instances, calculate multiple quantiles
- **Summary**: Per-instance quantiles, lower memory overhead, don't need aggregation

---

## Additional Anti-Patterns

### Anti-Pattern 22: Nested Redundant Functions

**Problem**: Applying the same function twice or unnecessary nesting.

```promql
# ❌ BAD: Double rate (doesn't make sense)
rate(rate(http_requests_total[5m])[10m])

# ❌ BAD: Unnecessary nesting
avg(avg_over_time(metric[5m]))

# ✅ GOOD: Single function
rate(http_requests_total[5m])

# ✅ GOOD: Single aggregation
avg_over_time(metric[5m])
```

---

### Anti-Pattern 23: Forgetting group_left/group_right in Joins

**Problem**: One-to-many joins require group_left or group_right.

```promql
# ❌ BAD: Many-to-one join without group_left
rate(http_requests_total[5m])
* on (job, instance)
service_info

# Error: "multiple matches for labels"

# ✅ GOOD: Use group_left to include labels from right side
rate(http_requests_total[5m])
* on (job, instance) group_left (version, commit)
service_info
```

---

## Summary Checklist

Before running your query, check:

- [ ] All metrics have specific label filters
- [ ] Using rate() on counters, not on gauges
- [ ] Using exact match (=) instead of regex (=~) when possible
- [ ] rate() range is at least 2-4 minutes
- [ ] irate() range is 2-5 minutes maximum
- [ ] Aggregations have by() or without() clauses
- [ ] Not averaging pre-calculated quantiles
- [ ] histogram_quantile includes rate() and 'le' label
- [ ] Subquery ranges are reasonable (<7 days typically)
- [ ] Complex/frequent queries use recording rules
- [ ] Not using high-cardinality labels

---

## Resources

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [PromQL Official Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Common Query Patterns](https://www.robustperception.io/common-query-patterns-in-promql/)