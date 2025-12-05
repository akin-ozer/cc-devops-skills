# PromQL Best Practices

Comprehensive guide to writing efficient, correct, and maintainable PromQL queries.

## Table of Contents

1. [Metric Types and Functions](#metric-types-and-functions)
2. [Label Filtering](#label-filtering)
3. [Aggregations](#aggregations)
4. [Time Ranges](#time-ranges)
5. [Performance Optimization](#performance-optimization)
6. [Recording Rules](#recording-rules)
7. [Histograms and Summaries](#histograms-and-summaries)
8. [Alerting Queries](#alerting-queries)
9. [Common Patterns](#common-patterns)

---

## Metric Types and Functions

### Counters

**What they are**: Metrics that only increase (or reset to zero). Examples: `http_requests_total`, `errors_count`.

**Best practices**:
- ✅ Always use `rate()` or `increase()` with counters
- ✅ Use `rate()` for per-second rates: `rate(http_requests_total[5m])`
- ✅ Use `increase()` for total increase: `increase(http_requests_total[1h])`
- ❌ Never use raw counter values (they always increase, not useful)
- ❌ Never use `rate()` or `increase()` without a range vector

**Naming convention**: Counters typically end with `_total`, `_count`, `_sum`, or `_bucket`.

**Examples**:
```promql
# Good: Calculate requests per second
rate(http_requests_total{job="api"}[5m])

# Good: Total requests in last hour
increase(http_requests_total{job="api"}[1h])

# Bad: Raw counter value
http_requests_total{job="api"}
```

### Gauges

**What they are**: Metrics that can go up and down. Examples: `memory_usage_bytes`, `temperature_celsius`.

**Best practices**:
- ✅ Use gauge values directly
- ✅ Use `avg_over_time()`, `max_over_time()`, `min_over_time()` for time windows
- ✅ Can use `delta()` for change over time (but not common)
- ❌ Never use `rate()`, `irate()`, or `increase()` on gauges
- ❌ These functions assume monotonically increasing values

**Examples**:
```promql
# Good: Current memory usage
node_memory_usage_bytes{instance="prod-1"}

# Good: Average over time
avg_over_time(node_memory_usage_bytes{instance="prod-1"}[5m])

# Good: Maximum in last hour
max_over_time(node_cpu_percent{instance="prod-1"}[1h])

# Bad: Rate on gauge
rate(memory_usage_bytes[5m])
```

### Histograms

**What they are**: Multiple time series representing bucketed observations. Metrics end with `_bucket`, `_sum`, `_count`.

**Best practices**:
- ✅ Use `histogram_quantile()` to calculate quantiles
- ✅ Always include `le` label in `by()` clause
- ✅ Use `rate()` on bucket metrics
- ✅ Aggregate before calculating quantiles
- ❌ Never average pre-calculated quantiles

**Examples**:
```promql
# Good: Calculate 95th percentile latency
histogram_quantile(0.95,
  sum by (job, le) (
    rate(http_request_duration_seconds_bucket{job="api"}[5m])
  )
)

# Good: Calculate average from histogram
rate(http_request_duration_seconds_sum{job="api"}[5m])
/
rate(http_request_duration_seconds_count{job="api"}[5m])

# Bad: Missing rate()
histogram_quantile(0.95, sum by (le) (http_request_duration_seconds_bucket))

# Bad: Missing 'le' in aggregation
histogram_quantile(0.95, sum by (job) (rate(http_request_duration_seconds_bucket[5m])))
```

### Summaries

**What they are**: Pre-calculated quantiles with `_sum` and `_count`. Includes labels like `quantile="0.95"`.

**Best practices**:
- ✅ Use `_sum` and `_count` to calculate averages
- ❌ Never average or aggregate pre-calculated quantiles
- ❌ Quantiles from summaries cannot be aggregated across instances

**Examples**:
```promql
# Good: Calculate average from summary
rate(http_request_duration_seconds_sum[5m])
/
rate(http_request_duration_seconds_count[5m])

# Bad: Averaging quantiles (mathematically invalid!)
avg(http_request_duration_seconds{quantile="0.95"})
```

---

## Label Filtering

### Always Use Specific Label Filters

**Why**: Reduces cardinality, improves query performance, and makes intent clear.

```promql
# Bad: No filters
http_requests_total

# Good: Specific filters
http_requests_total{job="api-service", environment="production"}

# Good: Multiple filters for precision
http_requests_total{
  job="api-service",
  environment="production",
  datacenter="us-east-1",
  instance="prod-api-1"
}
```

### Use Exact Matches Over Regex When Possible

**Why**: Exact matches are faster (index lookups) vs regex (pattern matching).

```promql
# Bad: Regex for exact match
http_requests_total{status=~"200"}

# Good: Exact match
http_requests_total{status="200"}

# Regex is fine when you need it:
http_requests_total{status=~"2[0-9]{2}"}  # All 2xx status codes
```

### Efficient Regex Patterns

```promql
# Bad: Multiple OR queries
sum(http_requests_total{path="/api/users"})
or
sum(http_requests_total{path="/api/products"})
or
sum(http_requests_total{path="/api/orders"})

# Good: Single regex with alternation
sum by (path) (
  http_requests_total{path=~"/api/(users|products|orders)"}
)

# Good: Negative regex for exclusions
http_requests_total{path!~"/health|/metrics"}
```

### Label Matcher Operators

- `=` : Equal to
- `!=` : Not equal to
- `=~` : Regex match (fully anchored)
- `!~` : Regex does not match

---

## Aggregations

### Always Use `by()` or `without()` Clauses

**Why**: Makes output labels explicit and prevents confusion.

```promql
# Unclear: What labels will remain?
sum(rate(http_requests_total[5m]))

# Clear: Group by these labels
sum by (job, instance) (rate(http_requests_total[5m]))

# Clear: Remove only these labels
sum without (pod, container) (rate(http_requests_total[5m]))
```

### Use `without()` for High-Cardinality Labels

**Why**: More maintainable when you want to keep many labels.

```promql
# Verbose: List all labels to keep
sum by (job, instance, environment, datacenter, region, cluster, zone) (metric)

# Better: Drop only the high-cardinality labels
sum without (pod, container, node) (metric)
```

### Common Aggregation Operators

- `sum`: Total across series
- `avg`: Average value
- `min`: Minimum value
- `max`: Maximum value
- `count`: Count of series
- `stddev`: Standard deviation
- `stdvar`: Standard variance
- `topk(N, ...)`: Top N series
- `bottomk(N, ...)`: Bottom N series
- `quantile(φ, ...)`: φ-quantile (0 ≤ φ ≤ 1)

### Aggregation Examples

```promql
# Sum request rate per service
sum by (service) (rate(http_requests_total[5m]))

# Average CPU across all cores per node
avg by (instance) (rate(node_cpu_seconds_total[5m]))

# Top 10 pods by memory usage
topk(10, container_memory_usage_bytes)

# Count running instances per job
count by (job) (up == 1)
```

---

## Time Ranges

### rate() Range Selection

**Rule of thumb**: Use at least 4x your scrape interval.

- Typical scrape interval: 15s
- Minimum `rate()` range: `[1m]` (preferably `[2m]`)

```promql
# Bad: Too short (less than 4x scrape interval)
rate(http_requests_total[30s])

# Good: At least 2 minutes
rate(http_requests_total[2m])

# Common: 5 minutes (good balance of responsiveness and stability)
rate(http_requests_total[5m])

# Longer ranges: More stable, less sensitive to spikes
rate(http_requests_total[15m])
```

### irate() vs rate()

**irate()**: Instant rate, only uses last two samples.
- ✅ Use for high-frequency, short-range monitoring
- ✅ Good for rapidly changing metrics
- ✅ Range: `[2m]` to `[5m]` typically
- ❌ Don't use for long ranges (wasted range)

**rate()**: Average rate over entire range.
- ✅ Use for most cases
- ✅ More stable and accurate for longer ranges
- ✅ Better for alerting (less noisy)

```promql
# Good: irate with short range
irate(http_requests_total[2m])

# Good: rate for longer range
rate(http_requests_total[5m])

# Bad: irate with long range (only uses last 2 samples anyway!)
irate(http_requests_total[1h])
```

### Subqueries

**Syntax**: `query[range:resolution]`

**Use sparingly**: Subqueries can be very expensive.

```promql
# Calculate max rate over 30 minutes with 1-minute resolution
max_over_time(
  rate(http_requests_total[5m])[30m:1m]
)

# Bad: Excessive range
max_over_time(
  rate(http_requests_total[5m])[95d:1m]
)  # Processes millions of samples!

# Better: Use recording rules for long ranges
```

---

## Performance Optimization

### 1. Filter Early, Aggregate Late

```promql
# Good: Filter before expensive operations
sum(rate(http_requests_total{job="api", status="200"}[5m]))

# Bad: Filter after aggregation (processes more data)
sum(rate(http_requests_total[5m])) and {job="api", status="200"}
```

### 2. Use topk/bottomk to Limit Results

```promql
# Instead of processing all series:
sum by (pod) (rate(container_cpu_usage[5m]))

# Limit to top 10 in query:
topk(10, sum by (pod) (rate(container_cpu_usage[5m])))
```

### 3. Avoid High-Cardinality Labels

- User IDs, request IDs, timestamps as labels = BAD
- Job, instance, path, status code = OK
- Keep label cardinality under 10-100 unique values when possible

### 4. Use Recording Rules for Complex Queries

See [Recording Rules](#recording-rules) section below.

### 5. Minimize Regex Usage

```promql
# Slower: Regex match
{label=~"value"}

# Faster: Exact match
{label="value"}
```

### 6. Share Common Subexpressions

```promql
# Bad: Same rate calculated twice
rate(metric[5m]) / rate(metric[5m] offset 1h)

# Can't be optimized in PromQL directly, but use recording rules:
# - record: metric:rate5m
#   expr: rate(metric[5m])

# Then:
metric:rate5m / (metric:rate5m offset 1h)
```

---

## Recording Rules

**Purpose**: Pre-compute frequently-used or expensive queries.

**Benefits**:
- Faster dashboard loads
- Lower query latency
- Reduced Prometheus CPU usage
- Easier to maintain complex expressions

**When to use**:
- Query runs frequently (multiple dashboards, alerts)
- Query is computationally expensive
- Query spans long time ranges (subqueries)
- Query is complex (multiple aggregations, joins)

**Naming convention**:
```
level:metric:operations
```

Examples:
- `job:http_requests:rate5m`
- `instance:node_cpu:rate1m`
- `job_instance:request_latency_seconds:mean5m`

**Configuration example**:

```yaml
groups:
  - name: example_recording_rules
    interval: 30s
    rules:
      # Basic rate recording
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      # Error rate recording
      - record: job:http_requests:error_rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))

      # Average latency recording
      - record: job:http_request_latency_seconds:mean5m
        expr: |
          sum by (job) (rate(http_request_duration_seconds_sum[5m]))
          /
          sum by (job) (rate(http_request_duration_seconds_count[5m]))
```

---

## Histograms and Summaries

### Histogram Best Practices

```promql
# Calculate quantile
histogram_quantile(0.95,
  sum by (le, job) (
    rate(http_request_duration_seconds_bucket{job="api"}[5m])
  )
)

# Always include 'le' in aggregation
sum by (job, le) (...)  # ✅ Correct
sum by (job) (...)      # ❌ Wrong - missing 'le'

# Use rate() on bucket metrics
rate(http_request_duration_seconds_bucket[5m])  # ✅ Correct
http_request_duration_seconds_bucket            # ❌ Wrong - missing rate()
```

### Calculate Average from Histogram

```promql
rate(http_request_duration_seconds_sum[5m])
/
rate(http_request_duration_seconds_count[5m])
```

### Count Observations

```promql
rate(http_request_duration_seconds_count[5m])
```

---

## Native Histograms (Prometheus 2.40+/3.0)

Native histograms are a newer histogram format introduced in Prometheus 2.40 and made stable in 3.0. They offer significant storage and query efficiency improvements over classic histograms.

### Key Differences from Classic Histograms

| Classic Histograms | Native Histograms |
|-------------------|-------------------|
| Separate `_bucket`, `_sum`, `_count` time series | Single time series containing all data |
| Fixed bucket boundaries defined at instrumentation | Dynamic bucket resolution |
| Requires `_bucket` suffix in queries | No `_bucket` suffix needed |
| Always need `le` label in aggregation | No `le` label manipulation |

### Native Histogram Query Syntax

```promql
# Classic histogram (old way)
histogram_quantile(0.9, sum by (job, le) (rate(http_request_duration_seconds_bucket[10m])))

# Native histogram (simpler - no _bucket suffix, no 'le' label needed)
histogram_quantile(0.9, sum by (job) (rate(http_request_duration_seconds[10m])))
```

### Native Histogram Functions

Prometheus provides special functions for native histograms:

```promql
# Calculate average from native histogram
histogram_avg(rate(http_request_duration_seconds[5m]))

# Calculate standard deviation
histogram_stddev(rate(http_request_duration_seconds[5m]))

# Calculate standard variance
histogram_stdvar(rate(http_request_duration_seconds[5m]))

# Get observation count
histogram_count(rate(http_request_duration_seconds[5m]))

# Get sum of observations
histogram_sum(rate(http_request_duration_seconds[5m]))

# Get fraction of observations in a range
histogram_fraction(0.1, 0.5, rate(http_request_duration_seconds[5m]))
```

### Best Practices for Native Histograms

1. **Still use `rate()` with native histograms** - The histogram functions work with rate-aggregated data
   ```promql
   # ✅ Correct
   histogram_avg(rate(http_request_duration_seconds[5m]))

   # ❌ Wrong - missing rate()
   histogram_avg(http_request_duration_seconds)
   ```

2. **Simpler aggregation** - No need for `le` label in `by()` clause
   ```promql
   # Classic histogram - need 'le'
   histogram_quantile(0.95, sum by (job, le) (rate(metric_bucket[5m])))

   # Native histogram - no 'le' needed
   histogram_quantile(0.95, sum by (job) (rate(metric[5m])))
   ```

3. **Enable native histograms in Prometheus** - Requires configuration:
   ```yaml
   # prometheus.yml
   global:
     scrape_native_histograms: true
   ```

4. **Check if metrics are native or classic** - Query the metric directly to see its format in the response

### When to Use Native Histograms

- ✅ New projects starting with Prometheus 2.40+
- ✅ High-cardinality histogram data (storage efficiency)
- ✅ When you need many quantile calculations (query efficiency)
- ❌ Legacy systems that don't support native histograms
- ❌ When you need exact bucket boundaries for compliance

---

## Alerting Queries

### Keep Alert Expressions Simple

```promql
# Bad: Complex alert expression
alert: HighErrorRate
expr: |
  (
    sum by (job) (rate(http_requests_total{status=~"5.."}[5m]))
    /
    sum by (job) (rate(http_requests_total[5m]))
  ) > 0.05

# Better: Use recording rule, simple alert
# Recording rule:
- record: job:http_requests:error_rate5m
  expr: ...

# Alert:
alert: HighErrorRate
expr: job:http_requests:error_rate5m > 0.05
```

### Use `for` Clause to Avoid Flapping

```yaml
- alert: HighMemoryUsage
  expr: node_memory_usage_percent > 90
  for: 5m  # Must be true for 5 minutes
  annotations:
    summary: "High memory usage on {{ $labels.instance }}"
```

### Alert on Rate of Change

```promql
# Alert if request rate drops suddenly
(
  rate(http_requests_total[5m])
  /
  rate(http_requests_total[5m] offset 1h)
) < 0.5  # Less than 50% of rate 1 hour ago
```

---

## Common Patterns

### Error Rate Calculation

```promql
# Error rate as percentage
(
  sum(rate(http_requests_total{status=~"5.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) * 100
```

### Success Rate

```promql
# Success rate as percentage
(
  sum(rate(http_requests_total{status=~"2.."}[5m]))
  /
  sum(rate(http_requests_total[5m]))
) * 100
```

### Percentage Calculation

```promql
# Memory usage percentage
(
  node_memory_usage_bytes
  /
  node_memory_total_bytes
) * 100
```

### Comparing to Historical Baseline

```promql
# Compare current to 1 day ago
rate(http_requests_total[5m])
/
rate(http_requests_total[5m] offset 1d)
```

### Detect Sudden Spikes

```promql
# Alert if current rate > 2x the max rate in last hour
rate(metric[5m])
>
max_over_time(rate(metric[5m])[1h:]) * 2
```

### Absent Metrics (Alerting)

```promql
# Alert if metric disappears
absent(up{job="critical-service"})

# Alert if metric was present but now gone
absent_over_time(up{job="critical-service"}[5m])
```

### Joining Metrics

```promql
# Add labels from info metric to other metrics
rate(http_requests_total[5m])
* on (job, instance) group_left (version, commit)
service_info
```

---

## Quick Reference

| Pattern | Use Case | Example |
|---------|----------|---------|
| `rate(counter[5m])` | Per-second rate of counter | `rate(http_requests_total[5m])` |
| `increase(counter[1h])` | Total increase in counter | `increase(requests_total[1h])` |
| `gauge` | Current value | `node_memory_usage_bytes` |
| `avg_over_time(gauge[5m])` | Average gauge over time | `avg_over_time(cpu_percent[5m])` |
| `histogram_quantile(0.95, ...)` | Calculate percentile | See histogram section |
| `sum by (label) (...)` | Aggregate by labels | `sum by (job) (rate(metric[5m]))` |
| `topk(N, ...)` | Top N series | `topk(10, metric)` |
| `absent(metric)` | Check if metric missing | `absent(up{job="api"})` |
| `metric offset 1h` | Historical comparison | `rate(metric[5m] offset 1h)` |

---

## Additional Resources

- [Official Prometheus Querying Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Best Practices for Naming Metrics](https://prometheus.io/docs/practices/naming/)