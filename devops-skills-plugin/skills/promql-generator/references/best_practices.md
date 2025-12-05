# PromQL Best Practices

Comprehensive guide to writing efficient, maintainable, and correct PromQL queries.

## Table of Contents

1. [Label Selection and Filtering](#label-selection-and-filtering)
2. [Metric Type Usage](#metric-type-usage)
3. [Aggregation Best Practices](#aggregation-best-practices)
4. [Performance Optimization](#performance-optimization)
5. [Time Range Selection](#time-range-selection)
6. [Recording Rules](#recording-rules)
7. [Alerting Best Practices](#alerting-best-practices)
8. [Query Readability](#query-readability)
9. [Common Anti-Patterns](#common-anti-patterns)
10. [Testing and Validation](#testing-and-validation)

---

## Label Selection and Filtering

### Always Use Label Filters

**Problem**: Querying metrics without label filters can match thousands or millions of time series, causing performance issues and timeouts.

```promql
# ❌ Bad: No filtering, matches all time series
rate(http_requests_total[5m])

# ✅ Good: Specific filtering
rate(http_requests_total{job="api-server", environment="production"}[5m])
```

**Best practices**:
- Always include at least `job` label filter
- Add `environment` or `cluster` for multi-environment setups
- Use `instance` for single-instance queries
- Add functional labels like `endpoint`, `method`, `status_code` as needed

### Use Exact Matches Over Regex

**Problem**: Regex matching (`=~`) is significantly slower than exact matching (`=`).

```promql
# ❌ Bad: Unnecessary regex for exact match
http_requests_total{status_code=~"200"}

# ✅ Good: Exact match is faster
http_requests_total{status_code="200"}

# ✅ Good: Regex when truly needed
http_requests_total{status_code=~"2.."}  # All 2xx codes
http_requests_total{instance=~"prod-.*"}  # Pattern matching
```

**When regex is appropriate**:
- Matching patterns: `instance=~"prod-.*"`
- Multiple values: `status_code=~"200|201|202"`
- Character classes: `status_code=~"5.."`

**Optimization tips**:
- Anchor regex patterns when possible: `=~"^prod-.*"`
- Keep patterns simple and specific
- Use multiple exact matchers instead of single regex when possible

### Avoid High-Cardinality Labels

**Problem**: Labels with many unique values create massive number of time series.

```promql
# ❌ Bad: user_id creates one series per user (high cardinality)
sum by (user_id) (rate(requests_total[5m]))

# ✅ Good: Aggregate without high-cardinality labels
sum(rate(requests_total[5m]))

# ✅ Good: Use low-cardinality labels
sum by (service, environment) (rate(requests_total[5m]))
```

**High-cardinality labels to avoid in aggregations**:
- User IDs, session IDs, request IDs
- IP addresses (unless specifically needed)
- Timestamps
- Full URLs or paths (use path patterns instead)
- UUIDs

**Solutions**:
- Aggregate out high-cardinality labels with `without()`
- Use lower-cardinality alternatives (e.g., `path_pattern` instead of `full_url`)
- Implement recording rules to pre-aggregate

---

## Metric Type Usage

### Use rate() with Counters

**Problem**: Counter metrics always increase; raw values are not useful for analysis.

```promql
# ❌ Bad: Raw counter value is not meaningful
http_requests_total

# ✅ Good: Calculate rate (requests per second)
rate(http_requests_total[5m])

# ✅ Good: Calculate total increase over period
increase(http_requests_total[1h])
```

**Counter identification**:
- Metrics ending in `_total` (e.g., `requests_total`, `errors_total`)
- Metrics ending in `_count` (e.g., `http_requests_count`)
- Metrics ending in `_sum` (e.g., `request_duration_seconds_sum`)
- Metrics ending in `_bucket` (e.g., `request_duration_seconds_bucket`)

### Don't Use rate() with Gauges

**Problem**: Gauge metrics represent current state, not cumulative values.

```promql
# ❌ Bad: rate() on gauge doesn't make sense
rate(memory_usage_bytes[5m])

# ✅ Good: Use gauge value directly
memory_usage_bytes

# ✅ Good: Use *_over_time functions for analysis
avg_over_time(memory_usage_bytes[5m])
max_over_time(memory_usage_bytes[1h])
```

**Gauge examples**:
- `memory_usage_bytes`
- `cpu_temperature_celsius`
- `queue_length`
- `active_connections`

### Histogram Quantiles Require Aggregation

**Problem**: `histogram_quantile()` requires proper aggregation and the `le` label.

```promql
# ❌ Bad: Missing aggregation
histogram_quantile(0.95, rate(request_duration_seconds_bucket[5m]))

# ❌ Bad: Missing le label in aggregation
histogram_quantile(0.95, sum(rate(request_duration_seconds_bucket[5m])))

# ❌ Bad: Missing rate() on buckets
histogram_quantile(0.95, sum by (le) (request_duration_seconds_bucket))

# ✅ Good: Correct usage
histogram_quantile(0.95,
  sum by (le) (rate(request_duration_seconds_bucket[5m]))
)

# ✅ Good: Preserving additional labels
histogram_quantile(0.95,
  sum by (service, le) (rate(request_duration_seconds_bucket[5m]))
)
```

**Requirements for histogram_quantile()**:
1. Must apply `rate()` or `irate()` to bucket counters
2. Must aggregate with `sum`
3. Must include `le` label in aggregation
4. Can include other labels for grouping

### Never Average Pre-Calculated Quantiles

**Problem**: Averaging quantiles is mathematically invalid and produces incorrect results.

```promql
# ❌ Bad: Averaging quantiles is wrong
avg(request_duration_seconds{quantile="0.95"})

# ✅ Good: Use _sum and _count to calculate average
sum(rate(request_duration_seconds_sum[5m]))
/
sum(rate(request_duration_seconds_count[5m]))

# ✅ Good: If you need quantiles, use histogram
histogram_quantile(0.95,
  sum by (le) (rate(request_duration_seconds_bucket[5m]))
)
```

---

## Aggregation Best Practices

### Choose Between by() and without()

**by()**: Keeps only specified labels, removes all others
**without()**: Removes specified labels, keeps all others

```promql
# Use by() when you know exactly what labels you want to keep
sum by (service, environment) (rate(requests_total[5m]))

# Use without() when you want to remove specific labels
sum without (instance, pod) (rate(requests_total[5m]))
```

**When to use each**:
- **by()**: When aggregating to specific dimensions (service-level metrics)
- **without()**: When removing noise (instance-level details)

### Aggregate Before histogram_quantile()

**Always aggregate before calling histogram_quantile()**:

```promql
# ❌ Bad: Trying to aggregate after quantile calculation
sum(
  histogram_quantile(0.95, rate(request_duration_seconds_bucket[5m]))
)

# ✅ Good: Aggregate first, then calculate quantile
histogram_quantile(0.95,
  sum by (le) (rate(request_duration_seconds_bucket[5m]))
)

# ✅ Good: Aggregate with grouping
histogram_quantile(0.95,
  sum by (service, le) (rate(request_duration_seconds_bucket[5m]))
)
```

### Use Appropriate Aggregation Operators

Choose the right aggregation for your use case:

```promql
# sum: For counting, totaling
sum(up{job="api"})  # Total number of instances

# avg: For average values
avg(cpu_usage_percent)  # Average CPU across instances

# max/min: For identifying extremes
max(memory_usage_bytes)  # Instance with highest memory use

# count: For counting series
count(up{job="api"} == 1)  # Number of healthy instances

# topk/bottomk: For top/bottom N
topk(10, rate(requests_total[5m]))  # Top 10 by request rate

# quantile: For percentiles across simple metrics
quantile(0.95, response_time_seconds)  # 95th percentile
```

---

## Performance Optimization

### Limit Cardinality

**The number of time series matters most for query performance.**

```promql
# Check cardinality of a metric
count(metric_name)

# Check cardinality by label
count by (label_name) (metric_name)

# Identify high-cardinality metrics
topk(10, count by (__name__) ({__name__=~".+"}))
```

**Strategies to reduce cardinality**:
1. Add more specific label filters
2. Use aggregation to reduce dimensions
3. Remove high-cardinality labels from queries
4. Use recording rules for frequently-queried aggregations

### Optimize Time Ranges

**Larger time ranges process more data and run slower.**

```promql
# ❌ Slow: Very large range for rate
rate(requests_total[1h])

# ✅ Fast: Appropriate range for rate
rate(requests_total[5m])

# For recording rules: Pre-compute common ranges
# Then use the recorded metric instead
job:requests:rate5m  # Recorded metric
```

**Time range guidelines**:
- **Rate functions**: `[1m]` to `[5m]` for real-time monitoring
- **Trend analysis**: `[1h]` to `[1d]` when needed
- **Rule of thumb**: Range should be 4× scrape interval minimum
- **Recording rules**: Use for ranges longer than `[5m]` if queried frequently

### Avoid Expensive Subqueries

**Subqueries can exponentially increase query cost.**

```promql
# ❌ Expensive: Subquery over long range
max_over_time(rate(metric[5m])[7d:1h])

# ✅ Better: Use recording rule
max_over_time(job:metric:rate5m[7d])

# ✅ Better: Reduce range if possible
max_over_time(rate(metric[5m])[1d:1h])
```

**Subquery cost = range_duration / resolution × base_query_cost**

### Use Recording Rules for Complex Queries

**Recording rules pre-compute expensive queries.**

```yaml
# Recording rule configuration
groups:
  - name: request_rates
    interval: 30s
    rules:
      # Pre-compute expensive aggregation
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      # Pre-compute complex quantile
      - record: job:http_latency:p95
        expr: |
          histogram_quantile(0.95,
            sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
          )
```

**Use recording rules when**:
- Query is used in multiple dashboards
- Query is computationally expensive
- Query is accessed frequently (every dashboard refresh)
- You need faster dashboard/alert evaluation

---

## Time Range Selection

### Choose Appropriate Ranges for rate()

**Too short**: Noisy, sensitive to scraping jitter
**Too long**: Hides important spikes, slow to react

```promql
# Real-time monitoring: 1-5 minutes
rate(requests_total[2m])
rate(requests_total[5m])

# Trend analysis: 15 minutes to 1 hour
rate(requests_total[15m])
rate(requests_total[1h])

# Historical analysis: Hours to days
rate(requests_total[6h])
rate(requests_total[1d])
```

**Guidelines**:
- Minimum range: 4× scrape interval
- For 15s scrape interval: minimum `[1m]`
- For 30s scrape interval: minimum `[2m]`
- Default choice: `[5m]` works well for most cases

### Use irate() for Volatile Metrics

```promql
# rate(): Average over time range, smooth
rate(requests_total[5m])

# irate(): Instant based on last 2 points, volatile
irate(requests_total[5m])
```

**When to use irate()**:
- Detecting sudden spikes
- Alerting on rapid changes
- Short-term analysis
- Metrics that change dramatically

**When to use rate()**:
- Dashboard visualizations
- Trend analysis
- Smooth charts
- Most monitoring use cases

---

## Recording Rules

### Follow Naming Convention

**Format**: `level:metric:operations`

```yaml
# level: Aggregation level (job, service, cluster)
# metric: Base metric name
# operations: Functions applied (rate5m, p95, sum)

rules:
  # Good examples
  - record: job:http_requests:rate5m
    expr: sum by (job) (rate(http_requests_total[5m]))

  - record: job_endpoint:http_latency:p95
    expr: |
      histogram_quantile(0.95,
        sum by (job, endpoint, le) (rate(http_request_duration_seconds_bucket[5m]))
      )

  - record: cluster:cpu_usage:ratio
    expr: |
      sum(rate(node_cpu_seconds_total{mode!="idle"}[5m]))
      /
      sum(rate(node_cpu_seconds_total[5m]))
```

### Pre-Aggregate Expensive Queries

```yaml
# Instead of running this expensive query repeatedly:
# histogram_quantile(0.95, sum by (le) (rate(latency_bucket[5m])))

# Create a recording rule:
- record: :http_request_duration:p95
  expr: |
    histogram_quantile(0.95,
      sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
    )

# Then use the recorded metric:
# :http_request_duration:p95
```

### Layer Recording Rules

**Build complex metrics in stages:**

```yaml
# Layer 1: Basic rates
- record: instance:requests:rate5m
  expr: rate(http_requests_total[5m])

# Layer 2: Job-level aggregation
- record: job:requests:rate5m
  expr: sum by (job) (instance:requests:rate5m)

# Layer 3: Derived metrics
- record: job:error_ratio:rate5m
  expr: |
    sum by (job) (instance:requests:rate5m{status_code=~"5.."})
    /
    job:requests:rate5m
```

---

## Alerting Best Practices

### Make Alert Expressions Boolean

**Alert expressions should return 1 (firing) or 0 (not firing).**

```promql
# ✅ Good: Boolean expression
(
  sum(rate(errors_total[5m]))
  /
  sum(rate(requests_total[5m]))
) > 0.05

# ✅ Good: Explicit comparison
http_requests_rate < 10

# ✅ Good: Complex boolean
(cpu_usage > 80) and (memory_usage > 90)
```

### Use `for` Duration for Stability

**Avoid alerting on transient spikes.**

```yaml
# Alert only after condition persists for 10 minutes
- alert: HighErrorRate
  expr: |
    (
      sum(rate(errors_total[5m]))
      /
      sum(rate(requests_total[5m]))
    ) > 0.05
  for: 10m
  annotations:
    summary: "Error rate above 5% for 10+ minutes"
```

**`for` duration guidelines**:
- Short-lived issues: `5m`
- Sustained problems: `10m` to `15m`
- Avoid false positives: `30m`+
- Critical immediate alerts: `0m` (no `for`)

### Include Context in Alert Queries

```promql
# ✅ Good: Include labels that identify the problem
sum by (service, environment) (
  rate(errors_total[5m])
) > 100

# Alerts will show which service and environment
```

### Avoid Alerting on Absence Without Context

```promql
# ❌ Bad: Too generic
absent(up)

# ✅ Good: Specific service
absent(up{job="critical-service"})

# ✅ Good: With timeout
absent_over_time(up{job="critical-service"}[10m])
```

---

## Query Readability

### Format Complex Queries

**Use multi-line formatting for readability:**

```promql
# ✅ Good: Multi-line with indentation
histogram_quantile(0.95,
  sum by (service, le) (
    rate(http_request_duration_seconds_bucket{
      environment="production",
      job="api-server"
    }[5m])
  )
)

# ❌ Bad: Single line, hard to read
histogram_quantile(0.95, sum by (service, le) (rate(http_request_duration_seconds_bucket{environment="production", job="api-server"}[5m])))
```

### Use Comments in Recording Rules

```yaml
rules:
  # Calculate p95 latency for all API endpoints
  # Used by: API dashboard, SLO calculations, latency alerts
  - record: api:http_latency:p95
    expr: |
      histogram_quantile(0.95,
        sum by (endpoint, le) (
          rate(http_request_duration_seconds_bucket{job="api"}[5m])
        )
      )
```

### Name Recording Rules Descriptively

```yaml
# ✅ Good: Clear purpose from name
- record: api:error_rate:ratio5m
- record: db:query_duration:p99
- record: cluster:memory_usage:bytes

# ❌ Bad: Unclear names
- record: metric1
- record: temp_calc
- record: x
```

---

## Common Anti-Patterns

### Anti-Pattern 1: No Label Filters

```promql
# ❌ Anti-pattern
rate(http_requests_total[5m])

# ✅ Fix
rate(http_requests_total{job="api-server", environment="prod"}[5m])
```

### Anti-Pattern 2: Regex for Exact Match

```promql
# ❌ Anti-pattern
metric{label=~"value"}

# ✅ Fix
metric{label="value"}
```

### Anti-Pattern 3: rate() on Gauges

```promql
# ❌ Anti-pattern
rate(memory_usage_bytes[5m])

# ✅ Fix
avg_over_time(memory_usage_bytes[5m])
```

### Anti-Pattern 4: Missing rate() on Counters

```promql
# ❌ Anti-pattern
http_requests_total

# ✅ Fix
rate(http_requests_total[5m])
```

### Anti-Pattern 5: Averaging Quantiles

```promql
# ❌ Anti-pattern
avg(http_duration{quantile="0.95"})

# ✅ Fix
histogram_quantile(0.95,
  sum by (le) (rate(http_duration_bucket[5m]))
)
```

### Anti-Pattern 6: Missing Aggregation in histogram_quantile

```promql
# ❌ Anti-pattern
histogram_quantile(0.95, rate(latency_bucket[5m]))

# ✅ Fix
histogram_quantile(0.95,
  sum by (le) (rate(latency_bucket[5m]))
)
```

### Anti-Pattern 7: High-Cardinality Aggregation

```promql
# ❌ Anti-pattern
sum by (user_id) (requests)  # millions of series

# ✅ Fix
sum(requests)  # single series
# Or use low-cardinality labels
sum by (service) (requests)
```

---

## Testing and Validation

### Test Queries Before Production

1. **Check cardinality**:
   ```promql
   count(your_query)
   ```

2. **Verify result makes sense**:
   - Check value range
   - Verify labels in output
   - Compare with expected results

3. **Test edge cases**:
   - What if metric doesn't exist?
   - What if all instances are down?
   - What during counter resets?

### Validate Time Ranges

```promql
# Test with different ranges
rate(metric[1m])
rate(metric[5m])
rate(metric[1h])

# Verify results are reasonable
```

### Check for Missing Data

```promql
# Verify metric exists
count(metric_name) > 0

# Check for gaps
absent_over_time(metric_name[10m])
```

---

## Summary Checklist

Before deploying a PromQL query, verify:

- [ ] Uses specific label filters (at least `job`)
- [ ] Uses exact match (`=`) instead of regex when possible
- [ ] Uses appropriate function for metric type
  - [ ] `rate()` for counters
  - [ ] Direct value or `*_over_time()` for gauges
  - [ ] `histogram_quantile()` with `sum by (le)` for histograms
- [ ] Includes proper aggregation
- [ ] Uses reasonable time range (typically `[5m]`)
- [ ] Avoids high-cardinality labels
- [ ] Formatted for readability
- [ ] Tested and returns expected results
- [ ] Considers using recording rule if expensive and frequently accessed
- [ ] Includes descriptive naming (for recording rules/alerts)
- [ ] Documented with comments (for complex queries)

---

## Resources

- [Official Prometheus Querying Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [PromQL Functions Reference](promql_functions.md)
- [Common Query Patterns](promql_patterns.md)