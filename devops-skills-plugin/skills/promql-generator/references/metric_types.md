# Prometheus Metric Types

Comprehensive guide to the four Prometheus metric types: Counter, Gauge, Histogram, and Summary.

## Table of Contents

1. [Overview](#overview)
2. [Counter](#counter)
3. [Gauge](#gauge)
4. [Histogram](#histogram)
5. [Summary](#summary)
6. [Choosing the Right Type](#choosing-the-right-type)
7. [Metric Naming Conventions](#metric-naming-conventions)

---

## Overview

Prometheus has four core metric types, each designed for specific use cases:

| Type | Description | Use Case | Example |
|------|-------------|----------|---------|
| **Counter** | Cumulative value that only increases | Counting events | Requests, errors, bytes sent |
| **Gauge** | Value that can go up or down | Current state | Memory usage, temperature, queue size |
| **Histogram** | Observations bucketed by value | Latency, sizes | Request duration, response size |
| **Summary** | Observations with quantiles | Latency, sizes | Request duration percentiles |

---

## Counter

### Definition

A **counter** is a cumulative metric that only increases over time (or resets to zero on restart). Counters are used for counting events.

### Characteristics

- **Only increases** (or resets to 0)
- **Cumulative** - represents total count since start
- **Not meaningful as raw value** - always use with `rate()` or `increase()`
- **Handles restarts** - rate functions automatically detect and handle counter resets

### Examples

```promql
# Total HTTP requests since process started
http_requests_total

# Total errors since process started
http_errors_total

# Total bytes sent since process started
bytes_sent_total

# Total database queries executed
db_queries_total{operation="select"}
```

### Naming Convention

Counters should end with `_total`:
- `http_requests_total`
- `errors_total`
- `bytes_processed_total`
- `cache_hits_total`

### Common PromQL Functions

#### rate() - Per-Second Average Rate

```promql
# Requests per second over last 5 minutes
rate(http_requests_total[5m])

# Errors per second
rate(errors_total[2m])

# Bytes sent per second
rate(bytes_sent_total[1m])
```

**When to use**: Graphing trends, calculating throughput, most monitoring use cases

#### irate() - Instant Rate

```promql
# Instant requests per second
irate(http_requests_total[5m])
```

**When to use**: Detecting spikes, alerting on sudden changes, real-time dashboards

#### increase() - Total Increase

```promql
# Total requests in the last hour
increase(http_requests_total[1h])

# Total errors in the last day
increase(errors_total[24h])
```

**When to use**: Calculating totals over periods, capacity planning, billing

### Best Practices

```promql
# ✅ Good: Use rate() for per-second values
rate(http_requests_total{job="api"}[5m])

# ✅ Good: Use increase() for totals
increase(http_requests_total{job="api"}[1h])

# ❌ Bad: Don't use raw counter values
http_requests_total

# ❌ Bad: Don't use rate() without time range
rate(http_requests_total)
```

### Use Cases

- **Request counting**: `http_requests_total`, `grpc_requests_total`
- **Error tracking**: `errors_total`, `failed_requests_total`
- **Throughput**: `bytes_sent_total`, `messages_processed_total`
- **Cache hits/misses**: `cache_hits_total`, `cache_misses_total`
- **Database operations**: `db_queries_total`, `db_transactions_total`

---

## Gauge

### Definition

A **gauge** is a metric that represents a single numerical value that can go up or down. Gauges represent current state or level.

### Characteristics

- **Can increase or decrease**
- **Represents current value** - meaningful as-is
- **Snapshot** - shows state at time of measurement
- **No cumulative behavior**

### Examples

```promql
# Current memory usage in bytes
memory_usage_bytes

# Current CPU temperature
cpu_temperature_celsius

# Current number of items in queue
queue_length

# Current number of active connections
active_connections

# Current disk space available
disk_available_bytes
```

### Naming Convention

Gauges should describe the measured value and include units:
- `memory_usage_bytes`
- `temperature_celsius`
- `queue_depth`
- `active_threads`
- `cpu_usage_ratio` (for percentages expressed as 0-1)

### Common PromQL Functions

#### Direct Usage

```promql
# Current memory usage
memory_usage_bytes

# Current queue length
queue_depth{service="worker"}
```

#### *_over_time Functions

```promql
# Average memory usage over 5 minutes
avg_over_time(memory_usage_bytes[5m])

# Maximum queue depth in last hour
max_over_time(queue_depth[1h])

# Minimum available disk space in last day
min_over_time(disk_available_bytes[24h])

# Count of samples (how many times scraped)
count_over_time(metric[5m])
```

#### Statistical Analysis

```promql
# Standard deviation of response time
stddev_over_time(response_time_seconds[5m])

# Quantile of gauge values over time
quantile_over_time(0.95, metric[5m])

# Rate of change (derivative)
deriv(queue_length[10m])
```

### Best Practices

```promql
# ✅ Good: Use gauge directly for current value
memory_usage_bytes

# ✅ Good: Use *_over_time for analysis
avg_over_time(memory_usage_bytes[5m])

# ❌ Bad: Don't use rate() on gauges
rate(memory_usage_bytes[5m])

# ❌ Bad: Don't use increase() on gauges
increase(memory_usage_bytes[1h])

# ✅ Good: Use deriv() for rate of change
deriv(disk_usage_bytes[1h])
```

### Use Cases

- **Resource usage**: `memory_usage_bytes`, `cpu_usage_percent`, `disk_usage_bytes`
- **Temperatures**: `cpu_temperature_celsius`, `disk_temperature_celsius`
- **Queue metrics**: `queue_length`, `pending_jobs`
- **Connection counts**: `active_connections`, `idle_connections`
- **Thread counts**: `active_threads`, `blocked_threads`
- **Current state**: `replica_count`, `node_count`, `pod_count`

---

## Histogram

### Definition

A **histogram** samples observations (like request durations or response sizes) and counts them in configurable buckets. It also provides a sum of all observed values.

### Characteristics

- **Buckets** - predefined upper bounds (le = "less than or equal")
- **Cumulative** - each bucket includes all observations ≤ its upper bound
- **Three metrics**:
  - `_bucket` - counter for each bucket
  - `_sum` - sum of all observed values
  - `_count` - total number of observations
- **Calculate quantiles** - use `histogram_quantile()`
- **Flexible** - can calculate any quantile from the same data

### Structure

For metric `http_request_duration_seconds`, you get:

```
http_request_duration_seconds_bucket{le="0.1"}   # ≤ 0.1s
http_request_duration_seconds_bucket{le="0.5"}   # ≤ 0.5s
http_request_duration_seconds_bucket{le="1"}     # ≤ 1s
http_request_duration_seconds_bucket{le="5"}     # ≤ 5s
http_request_duration_seconds_bucket{le="+Inf"}  # All observations
http_request_duration_seconds_sum                # Sum of all durations
http_request_duration_seconds_count              # Total count
```

### Examples

```promql
# Request duration histogram
http_request_duration_seconds_bucket

# Response size histogram
http_response_size_bytes_bucket

# Database query duration histogram
db_query_duration_seconds_bucket
```

### Naming Convention

Histograms should describe what is being measured and include units:
- `http_request_duration_seconds`
- `response_size_bytes`
- `db_query_duration_seconds`
- `batch_processing_time_seconds`

The instrumentation library automatically adds `_bucket`, `_sum`, and `_count` suffixes.

### Common PromQL Functions

#### histogram_quantile() - Calculate Percentiles

```promql
# 95th percentile request duration
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# Multiple percentiles
histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P50
histogram_quantile(0.90, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P90
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P99

# Percentile by service
histogram_quantile(0.95,
  sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

#### Average from Histogram

```promql
# Average request duration
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))

# Average by endpoint
sum by (endpoint) (rate(http_request_duration_seconds_sum[5m]))
/
sum by (endpoint) (rate(http_request_duration_seconds_count[5m]))
```

#### Request Rate from Histogram

```promql
# Requests per second (from histogram)
sum(rate(http_request_duration_seconds_count[5m]))

# Same as using counter
sum(rate(http_requests_total[5m]))
```

#### Fraction of Observations

```promql
# Percentage of requests under 100ms
(
  sum(rate(http_request_duration_seconds_bucket{le="0.1"}[5m]))
  /
  sum(rate(http_request_duration_seconds_count[5m]))
) * 100

# SLO: 95% of requests must be under 500ms
(
  sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
  /
  sum(rate(http_request_duration_seconds_count[5m]))
) >= 0.95
```

### Best Practices

```promql
# ✅ Good: Always use rate() on buckets
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# ✅ Good: Always include sum by (le)
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# ✅ Good: Can include other labels for grouping
histogram_quantile(0.95,
  sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
)

# ❌ Bad: Missing aggregation
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# ❌ Bad: Missing le in aggregation
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m]))
)

# ❌ Bad: Missing rate()
histogram_quantile(0.95,
  sum by (le) (http_request_duration_seconds_bucket)
)
```

### Use Cases

- **Request latency**: `http_request_duration_seconds`, `grpc_request_duration_seconds`
- **Response sizes**: `http_response_size_bytes`, `message_size_bytes`
- **Database query times**: `db_query_duration_seconds`
- **Batch processing times**: `batch_processing_duration_seconds`
- **Any measurement where you need percentiles**: response times, processing durations, sizes

### Advantages

- **Flexible**: Calculate any quantile from same data
- **Aggregatable**: Can aggregate across dimensions
- **Resource efficient**: Client-side bucketing, not all observations
- **Suitable for alerting**: Consistent with `rate()` calculations

### Bucket Configuration

Choose buckets that cover your expected range:

```go
// Example: HTTP request duration (Go client)
[]float64{.005, .01, .025, .05, .1, .25, .5, 1, 2.5, 5, 10}
// 5ms, 10ms, 25ms, 50ms, 100ms, 250ms, 500ms, 1s, 2.5s, 5s, 10s

// Example: Response size in bytes
[]float64{100, 1000, 10000, 100000, 1000000, 10000000}
// 100B, 1KB, 10KB, 100KB, 1MB, 10MB
```

---

## Summary

### Definition

A **summary** is similar to a histogram but calculates quantiles on the client side and streams pre-calculated percentiles to Prometheus.

### Characteristics

- **Pre-calculated quantiles** - computed by client
- **Three metrics**:
  - `{quantile="0.5"}` - 50th percentile
  - `{quantile="0.9"}` - 90th percentile
  - `{quantile="0.99"}` - 99th percentile
  - `_sum` - sum of all observed values
  - `_count` - total number of observations
- **Not aggregatable** - quantiles can't be averaged or summed
- **Less flexible** - can only view pre-configured quantiles

### Structure

For metric `http_request_duration_seconds`, you get:

```
http_request_duration_seconds{quantile="0.5"}   # 50th percentile (median)
http_request_duration_seconds{quantile="0.9"}   # 90th percentile
http_request_duration_seconds{quantile="0.99"}  # 99th percentile
http_request_duration_seconds_sum               # Sum of all durations
http_request_duration_seconds_count             # Total count
```

### Examples

```promql
# Pre-calculated 95th percentile
http_request_duration_seconds{quantile="0.95"}

# Pre-calculated 50th percentile (median)
rpc_duration_seconds{quantile="0.5"}
```

### Common PromQL Functions

#### Using Pre-Calculated Quantiles

```promql
# Use quantile directly (no calculation needed)
http_request_duration_seconds{quantile="0.95"}

# By service
http_request_duration_seconds{service="api", quantile="0.95"}
```

#### Calculate Average

```promql
# Average from summary
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))
```

### Best Practices

```promql
# ✅ Good: Use quantile directly
http_request_duration_seconds{quantile="0.95"}

# ✅ Good: Calculate average from _sum and _count
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))

# ❌ Bad: Don't average quantiles across instances
avg(http_request_duration_seconds{quantile="0.95"})

# ❌ Bad: Don't sum quantiles
sum(http_request_duration_seconds{quantile="0.95"})

# ❌ Bad: Don't use histogram_quantile() on summaries
histogram_quantile(0.95, http_request_duration_seconds)
```

### Use Cases

- **When client-side quantiles are acceptable**
- **Single instance metrics** (not aggregated across multiple instances)
- **Legacy systems** (histograms are generally preferred now)
- **Specific quantile requirements** that won't change

### Limitations

1. **Cannot aggregate across instances/labels** - quantiles can't be averaged
2. **Fixed quantiles** - can't calculate new percentiles from existing data
3. **More client resources** - quantile calculation happens on client
4. **Not suitable for alerting** - quantiles calculated differently than rates

### Histogram vs Summary

| Feature | Histogram | Summary |
|---------|-----------|---------|
| **Quantile calculation** | Server-side | Client-side |
| **Aggregatable** | ✅ Yes | ❌ No |
| **Flexible quantiles** | ✅ Calculate any | ❌ Only pre-configured |
| **Client resources** | Low | Higher |
| **Server resources** | Higher | Low |
| **Alerting friendly** | ✅ Yes | ⚠️ Limited |
| **Recommended** | ✅ Preferred | ⚠️ Legacy |

**Recommendation**: Use **histograms** for new instrumentation. Summaries are mainly for legacy compatibility.

---

## Choosing the Right Type

### Decision Tree

```
Are you counting events that only increase?
├─ Yes → Counter (e.g., requests_total, errors_total)
└─ No → Is it a current state that can go up or down?
    ├─ Yes → Gauge (e.g., memory_bytes, queue_length)
    └─ No → Do you need percentiles/distributions?
        ├─ Yes → Histogram (e.g., duration_seconds, size_bytes)
        └─ No → Consider if you really need metrics for this
```

### Use Case Matrix

| What You're Measuring | Metric Type | Example |
|----------------------|-------------|---------|
| Total requests | Counter | `http_requests_total` |
| Failed requests | Counter | `http_errors_total` |
| Bytes transferred | Counter | `bytes_sent_total` |
| Current memory usage | Gauge | `memory_usage_bytes` |
| Queue depth | Gauge | `queue_length` |
| Active connections | Gauge | `active_connections` |
| Request duration | Histogram | `http_request_duration_seconds` |
| Response size | Histogram | `http_response_size_bytes` |
| Latency percentiles | Histogram | `request_latency_seconds` |
| Pre-calculated quantiles | Summary | `rpc_duration_seconds` |

---

## Metric Naming Conventions

### General Rules

1. **Use base units**: seconds (not milliseconds), bytes (not kilobytes)
2. **Include units in name**: `_seconds`, `_bytes`, `_ratio`, `_percent`
3. **Use descriptive names**: `http_request_duration_seconds` not `http_req_dur_s`
4. **Counters end in `_total`**: `requests_total`, `errors_total`
5. **Ratios use `_ratio` suffix**: `cpu_usage_ratio` (0-1 range)
6. **Avoid stuttering**: `http_requests_total` not `http_http_requests_total`

### Unit Suffixes

| Unit | Suffix | Example |
|------|--------|---------|
| Seconds | `_seconds` | `http_request_duration_seconds` |
| Bytes | `_bytes` | `memory_usage_bytes` |
| Ratio (0-1) | `_ratio` | `cpu_usage_ratio` |
| Percentage (0-100) | `_percent` | `cpu_usage_percent` |
| Total count | `_total` | `http_requests_total` |
| Celsius | `_celsius` | `cpu_temperature_celsius` |
| Joules | `_joules` | `energy_consumption_joules` |
| Volts | `_volts` | `voltage_volts` |

### Namespace Structure

`<namespace>_<subsystem>_<metric_name>_<unit>`

```
# Good examples
http_request_duration_seconds
http_response_size_bytes
db_query_duration_seconds
process_resident_memory_bytes
node_cpu_seconds_total

# Component structure
prometheus_http_requests_total     # namespace: prometheus, subsystem: http
node_network_receive_bytes_total   # namespace: node, subsystem: network
```

---

## Summary Comparison

| Metric Type | Increases | Decreases | Aggregatable | Use Rate | Use Case |
|-------------|-----------|-----------|--------------|----------|----------|
| **Counter** | ✅ | ❌ | ✅ | ✅ | Event counting |
| **Gauge** | ✅ | ✅ | ✅ | ❌ | Current state |
| **Histogram** | ✅ (_bucket) | ❌ | ✅ | ✅ | Distributions |
| **Summary** | ✅ (_sum) | ❌ | ⚠️ (limited) | ⚠️ | Pre-calc quantiles |

**Most common**: Counter and Histogram cover 90% of use cases.

---

## References

- [Prometheus Metric Types](https://prometheus.io/docs/concepts/metric_types/)
- [Prometheus Best Practices - Naming](https://prometheus.io/docs/practices/naming/)
- [Histograms and Summaries](https://prometheus.io/docs/practices/histograms/)