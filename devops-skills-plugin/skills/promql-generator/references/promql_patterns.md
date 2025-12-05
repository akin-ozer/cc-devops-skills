# PromQL Query Patterns

Common query patterns for typical monitoring scenarios, organized by use case.

## Table of Contents

1. [RED Method (Request-Driven Services)](#red-method)
2. [USE Method (Resources)](#use-method)
3. [Request Patterns](#request-patterns)
4. [Error Patterns](#error-patterns)
5. [Latency Patterns](#latency-patterns)
6. [Resource Usage Patterns](#resource-usage-patterns)
7. [Availability Patterns](#availability-patterns)
8. [Saturation Patterns](#saturation-patterns)
9. [Ratio Calculations](#ratio-calculations)
10. [Time-Based Patterns](#time-based-patterns)
11. [Alerting Patterns](#alerting-patterns)

---

## RED Method

The RED method focuses on three key metrics for request-driven services:
- **Rate**: Throughput (requests per second)
- **Errors**: Error rate (failed requests)
- **Duration**: Latency (response time)

### Rate: Request Throughput

```promql
# Total requests per second across all instances
sum(rate(http_requests_total{job="api-server"}[5m]))

# Requests per second by endpoint
sum by (endpoint) (rate(http_requests_total{job="api-server"}[5m]))

# Requests per second by status code
sum by (status_code) (rate(http_requests_total{job="api-server"}[5m]))

# Requests per second by method and endpoint
sum by (method, endpoint) (rate(http_requests_total{job="api-server"}[5m]))

# Total requests per minute (instead of per second)
sum(rate(http_requests_total{job="api-server"}[5m])) * 60
```

### Errors: Error Rate

```promql
# Error ratio (0 to 1)
sum(rate(http_requests_total{job="api-server", status_code=~"5.."}[5m]))
/
sum(rate(http_requests_total{job="api-server"}[5m]))

# Error percentage (0 to 100)
(
  sum(rate(http_requests_total{job="api-server", status_code=~"5.."}[5m]))
  /
  sum(rate(http_requests_total{job="api-server"}[5m]))
) * 100

# Error rate by endpoint
sum by (endpoint) (rate(http_requests_total{status_code=~"5.."}[5m]))
/
sum by (endpoint) (rate(http_requests_total[5m]))

# 4xx client errors separately
sum(rate(http_requests_total{status_code=~"4.."}[5m]))
/
sum(rate(http_requests_total[5m]))
```

### Duration: Latency

```promql
# 95th percentile latency
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket{job="api-server"}[5m]))
)

# Multiple percentiles
histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P50 (median)
histogram_quantile(0.90, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P90
histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P95
histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))  # P99

# Average latency
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))

# Latency by endpoint
histogram_quantile(0.95,
  sum by (endpoint, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

---

## USE Method

The USE method focuses on resources:
- **Utilization**: Percentage of resource in use
- **Saturation**: Queue depth or resource contention
- **Errors**: Error counters

### Utilization: Resource Usage

```promql
# CPU utilization percentage
(
  1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))
) * 100

# Memory utilization percentage
(
  (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
  /
  node_memory_MemTotal_bytes
) * 100

# Disk utilization percentage
(
  (node_filesystem_size_bytes - node_filesystem_avail_bytes)
  /
  node_filesystem_size_bytes
) * 100

# Network utilization (as percentage of capacity)
(
  rate(node_network_transmit_bytes_total[5m])
  /
  node_network_speed_bytes
) * 100
```

### Saturation: Queue Depth

```promql
# Load average (normalized by CPU count)
node_load1
/
count without (cpu, mode) (node_cpu_seconds_total{mode="idle"})

# Average queue length
avg_over_time(queue_depth{job="worker"}[5m])

# Maximum queue depth in last hour
max_over_time(queue_depth{job="worker"}[1h])

# Thread pool saturation
active_threads / max_threads
```

### Errors: Resource Errors

```promql
# Network receive errors per second
rate(node_network_receive_errs_total[5m])

# Disk I/O errors
rate(node_disk_io_errors_total[5m])

# Out of memory kills
rate(node_vmstat_oom_kill[5m])
```

---

## Request Patterns

### Total Requests

```promql
# Total requests (instant count)
sum(http_requests_total)

# Total requests in last hour
sum(increase(http_requests_total[1h]))

# Total requests by service
sum by (service) (http_requests_total)
```

### Request Rate Over Time

```promql
# Current request rate
rate(http_requests_total[5m])

# Request rate comparison: current vs 1 hour ago
rate(http_requests_total[5m])
-
rate(http_requests_total[5m] offset 1h)

# Request rate comparison: current vs 1 week ago
rate(http_requests_total[5m])
/
rate(http_requests_total[5m] offset 1w)
```

### Top Endpoints

```promql
# Top 10 endpoints by request count
topk(10, sum by (endpoint) (rate(http_requests_total[5m])))

# Bottom 5 endpoints (least used)
bottomk(5, sum by (endpoint) (rate(http_requests_total[5m])))
```

---

## Error Patterns

### Error Count and Rate

```promql
# Total errors per second
sum(rate(http_errors_total[5m]))

# Errors by type
sum by (error_type) (rate(errors_total[5m]))

# Specific error rate
rate(http_requests_total{status_code="503"}[5m])
```

### Error Ratios

```promql
# Overall error rate
sum(rate(errors_total[5m]))
/
sum(rate(requests_total[5m]))

# Error rate by service
sum by (service) (rate(errors_total[5m]))
/
sum by (service) (rate(requests_total[5m]))

# Success rate (inverse of error rate)
1 - (
  sum(rate(errors_total[5m]))
  /
  sum(rate(requests_total[5m]))
)
```

### Error Trending

```promql
# Rate of change in errors
deriv(sum(errors_total)[10m])

# Predicted error count in 1 hour
predict_linear(errors_total[30m], 3600)
```

---

## Latency Patterns

### Percentile Calculations

```promql
# Standard percentiles from histogram
histogram_quantile(0.50, sum by (le) (rate(latency_bucket[5m])))  # Median
histogram_quantile(0.90, sum by (le) (rate(latency_bucket[5m])))  # P90
histogram_quantile(0.95, sum by (le) (rate(latency_bucket[5m])))  # P95
histogram_quantile(0.99, sum by (le) (rate(latency_bucket[5m])))  # P99
histogram_quantile(0.999, sum by (le) (rate(latency_bucket[5m]))) # P99.9

# Percentiles by service
histogram_quantile(0.95,
  sum by (service, le) (rate(request_duration_seconds_bucket[5m]))
)
```

### Average and Aggregate Latency

```promql
# Average latency
sum(rate(request_duration_seconds_sum[5m]))
/
sum(rate(request_duration_seconds_count[5m]))

# Maximum latency across all instances
max(max_over_time(request_duration_seconds[5m]))

# Minimum latency
min(min_over_time(request_duration_seconds[5m]))
```

### Latency SLO Compliance

```promql
# Percentage of requests under 200ms
(
  sum(rate(request_duration_seconds_bucket{le="0.2"}[5m]))
  /
  sum(rate(request_duration_seconds_count[5m]))
) * 100

# Percentage of requests violating SLO (over 1s)
(
  sum(rate(request_duration_seconds_count[5m]))
  -
  sum(rate(request_duration_seconds_bucket{le="1"}[5m]))
) / sum(rate(request_duration_seconds_count[5m])) * 100
```

---

## Resource Usage Patterns

### CPU

```promql
# CPU usage percentage by mode
sum by (mode) (rate(node_cpu_seconds_total[5m])) * 100

# Total CPU usage (excluding idle)
(
  sum(rate(node_cpu_seconds_total{mode!="idle"}[5m]))
  /
  sum(rate(node_cpu_seconds_total[5m]))
) * 100

# CPU usage by instance
100 - (
  avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100
)

# Container CPU usage (percentage of limit)
(
  rate(container_cpu_usage_seconds_total[5m])
  /
  container_spec_cpu_quota * container_spec_cpu_period
) * 100
```

### Memory

```promql
# Available memory in GB
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024

# Memory usage percentage
(
  (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
  /
  node_memory_MemTotal_bytes
) * 100

# Container memory usage (percentage of limit)
(
  container_memory_usage_bytes
  /
  container_spec_memory_limit_bytes
) * 100

# Memory usage by namespace (Kubernetes)
sum by (namespace) (container_memory_usage_bytes)
```

### Disk

```promql
# Disk space available in GB
node_filesystem_avail_bytes / 1024 / 1024 / 1024

# Disk usage percentage
(
  (node_filesystem_size_bytes - node_filesystem_avail_bytes)
  /
  node_filesystem_size_bytes
) * 100

# Disk I/O rate (reads + writes per second)
rate(node_disk_reads_completed_total[5m]) + rate(node_disk_writes_completed_total[5m])

# Time until disk full (prediction in hours)
(
  node_filesystem_avail_bytes
  /
  deriv(node_filesystem_avail_bytes[1h])
) / 3600
```

### Network

```promql
# Network receive rate in MB/s
rate(node_network_receive_bytes_total[5m]) / 1024 / 1024

# Network transmit rate in MB/s
rate(node_network_transmit_bytes_total[5m]) / 1024 / 1024

# Total network throughput
(
  rate(node_network_receive_bytes_total[5m])
  +
  rate(node_network_transmit_bytes_total[5m])
) / 1024 / 1024

# Network error rate
rate(node_network_receive_errs_total[5m]) + rate(node_network_transmit_errs_total[5m])
```

---

## Availability Patterns

### Service Uptime

```promql
# Percentage of instances that are up
(count(up{job="api-server"} == 1) / count(up{job="api-server"})) * 100

# Number of instances up
count(up{job="api-server"} == 1)

# Number of instances down
count(up{job="api-server"} == 0)

# Uptime by service
sum by (job) (up == 1) / count by (job) (up) * 100
```

### Uptime Duration

```promql
# Time since last restart (in hours)
(time() - process_start_time_seconds) / 3600

# Minimum uptime across instances (in days)
min((time() - process_start_time_seconds) / 86400)
```

### Success Rate

```promql
# HTTP success rate (2xx + 3xx)
sum(rate(http_requests_total{status_code=~"[23].."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Health check success rate
sum(rate(health_check_total{result="success"}[5m]))
/
sum(rate(health_check_total[5m]))
```

---

## Saturation Patterns

### Queue Metrics

```promql
# Current queue size
queue_size

# Average queue size over time
avg_over_time(queue_size[10m])

# Queue processing rate
rate(queue_processed_total[5m])

# Queue fill rate
rate(queue_added_total[5m]) - rate(queue_processed_total[5m])

# Time to drain queue (in seconds)
queue_size / rate(queue_processed_total[5m])
```

### Thread Pool Saturation

```promql
# Active threads ratio
active_threads / max_threads

# Thread pool utilization percentage
(active_threads / max_threads) * 100

# Rejected tasks rate
rate(thread_pool_rejected_total[5m])
```

### Connection Pool

```promql
# Active connections ratio
active_connections / max_connections

# Connection pool utilization
(active_connections / max_connections) * 100

# Connection wait time
connection_wait_duration_seconds
```

---

## Ratio Calculations

### Basic Ratios

```promql
# Success/failure ratio
rate(success_total[5m]) / rate(failure_total[5m])

# Cache hit ratio
rate(cache_hits_total[5m])
/
(rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))

# Write/read ratio
rate(writes_total[5m]) / rate(reads_total[5m])
```

### Efficiency Metrics

```promql
# Requests per CPU core
sum(rate(http_requests_total[5m]))
/
count(node_cpu_seconds_total{mode="idle"})

# Throughput per GB of memory
sum(rate(bytes_processed_total[5m]))
/
sum(node_memory_MemTotal_bytes / 1024 / 1024 / 1024)

# Cost per request (if cost metric exists)
sum(cost_dollars_total) / sum(http_requests_total)
```

---

## Time-Based Patterns

### Comparing with Historical Data

```promql
# Current vs 1 hour ago
metric - metric offset 1h

# Current vs yesterday
metric - metric offset 1d

# Current vs last week
metric - metric offset 1w

# Percentage change from yesterday
((metric - metric offset 1d) / metric offset 1d) * 100
```

### Time-of-Day Analysis

```promql
# Only show data during business hours (9 AM - 5 PM)
metric and hour() >= 9 and hour() < 17

# Only show data on weekdays (Monday-Friday)
metric and day_of_week() > 0 and day_of_week() < 6

# Weekend metrics
metric and (day_of_week() == 0 or day_of_week() == 6)
```

### Trend Analysis

```promql
# Rate of change over time
deriv(metric[10m])

# Predict value in 1 hour
predict_linear(metric[30m], 3600)

# Smoothed trend (Double Exponential Smoothing)
# Note: holt_winters was renamed to double_exponential_smoothing in Prometheus 3.0
# Requires --enable-feature=promql-experimental-functions
double_exponential_smoothing(metric[1h], 0.5, 0.5)
```

---

## Alerting Patterns

### Threshold Alerts

```promql
# CPU usage above 80%
(1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m]))) * 100 > 80

# Error rate above 5%
(
  sum(rate(errors_total[5m]))
  /
  sum(rate(requests_total[5m]))
) > 0.05

# Disk space below 10%
(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10

# Latency above 1 second
histogram_quantile(0.95, sum by (le) (rate(latency_bucket[5m]))) > 1
```

### Rate of Change Alerts

```promql
# Error rate increasing rapidly
deriv(sum(errors_total)[10m]) > 10

# Sudden traffic spike (>50% increase in 5 minutes)
(
  (rate(requests_total[5m]) - rate(requests_total[5m] offset 5m))
  /
  rate(requests_total[5m] offset 5m)
) > 0.5
```

### Absence Alerts

```promql
# Alert if metric is missing
absent(up{job="critical-service"})

# Alert if no data for 10 minutes
absent_over_time(metric[10m])

# Alert if no successful health checks
absent(health_check{result="success"})
```

### Multi-Condition Alerts

```promql
# High error rate AND high latency
(
  (sum(rate(errors_total[5m])) / sum(rate(requests_total[5m]))) > 0.05
)
and
(
  histogram_quantile(0.95, sum by (le) (rate(latency_bucket[5m]))) > 1
)

# Low availability AND high error rate
(
  (count(up{job="api"} == 1) / count(up{job="api"})) < 0.9
)
and
(
  sum(rate(errors_total[5m])) > 10
)
```

---

## Vector Matching and Joins

Vector matching enables combining data from different metrics. Essential for enriching metrics with metadata and correlating related time series.

### Basic One-to-One Matching

```promql
# Default: match on all common labels
metric_a + metric_b

# Result includes only series where both metrics have matching labels
# Output has labels present in both sides
```

### Using `on()` for Explicit Label Matching

```promql
# Match only on specific labels
metric_a + on (job, instance) metric_b

# Match ignoring specific labels
metric_a + ignoring (version, pod) metric_b
```

### Many-to-One Joins with `group_left`

Use `group_left` when the left side has more time series than the right side. The result includes labels from both sides.

```promql
# Enrich metrics with version info from info metric
rate(http_requests_total[5m])
* on (job, instance) group_left (version, environment)
  app_version_info

# Join container metrics with kube_pod_info
sum by (namespace, pod) (
  rate(container_cpu_usage_seconds_total{container!=""}[5m])
)
* on (namespace, pod) group_left (node, created_by_name)
  kube_pod_info

# Add target_info labels to metrics (OpenTelemetry pattern)
rate(http_requests_total[5m])
* on (job, instance) group_left (k8s_cluster_name, k8s_namespace_name)
  target_info
```

### One-to-Many Joins with `group_right`

Use `group_right` when the right side has more time series.

```promql
# Service info on the right, metrics on the left
service_info
* on (service) group_right (version, owner)
  sum by (service) (rate(requests_total[5m]))
```

### Joining Metrics with Different Label Names

Use `label_replace` to create matching labels when metrics use different label names.

```promql
# Metric A uses "server", Metric B uses "host"
# First, rename "server" to "host" in metric_a
label_replace(metric_a, "host", "$1", "server", "(.*)")
* on (host) group_left ()
  metric_b

# Alternative: rename in both metrics to a common name
label_replace(metric_a, "machine", "$1", "server", "(.*)")
* on (machine)
  label_replace(metric_b, "machine", "$1", "host", "(.*)")
```

### Enriching with Info Metrics

Info metrics are gauges with constant value 1 that carry metadata labels.

```promql
# Common info metric pattern
# info_metric{label1="value1", label2="value2", ...} = 1

# Join to add metadata labels to metrics
up
* on (job, instance) group_left (version, commit)
  build_info

# Kubernetes: Add node info to pod metrics
sum by (namespace, pod, node) (
  kube_pod_info
  * on (pod, namespace) group_right (node)
    sum by (namespace, pod) (
      rate(container_cpu_usage_seconds_total[5m])
    )
)
```

### Extracting Deployment Name from ReplicaSet

```promql
# ReplicaSet names are deployment_name + "-" + random_suffix
# Extract deployment name from owner reference
sum by (namespace, deployment) (
  label_replace(
    kube_pod_container_resource_requests{resource="cpu"},
    "deployment",
    "$1",
    "pod",
    "(.+)-[^-]+-[^-]+"  # Match deployment-replicaset-pod pattern
  )
)
```

### Conditional Joins

```promql
# Only include series where both conditions are met
metric_a > 100
and on (job, instance)
metric_b > 50

# Include all from left, filter by right
metric_a
and on (job)
(metric_b > 100)

# Exclude series present in right side
metric_a
unless on (job)
metric_b
```

### Aggregating Before Joining

```promql
# Wrong: joining before aggregating can cause mismatches
rate(http_requests_total[5m])
* on (instance) group_left (version)
  app_info

# Better: aggregate first, then join
sum by (job, instance) (rate(http_requests_total[5m]))
* on (job, instance) group_left (version)
  app_info
```

### Kubernetes Join Patterns

```promql
# CPU usage with pod owner (deployment, statefulset, etc.)
sum by (namespace, pod) (
  rate(container_cpu_usage_seconds_total{container!="", container!="POD"}[5m])
)
* on (namespace, pod) group_left (owner_name, owner_kind)
  kube_pod_owner

# Memory usage with node zone label
sum by (namespace, pod, node) (
  container_memory_working_set_bytes{container!="", container!="POD"}
)
* on (node) group_left (label_topology_kubernetes_io_zone)
  kube_node_labels

# Requests with service selector labels
sum by (namespace, service) (
  rate(http_requests_total[5m])
)
* on (namespace, service) group_left (label_app, label_version)
  kube_service_labels
```

### Vector Matching Operators Summary

| Operator | Purpose | Example |
|----------|---------|---------|
| `on (labels)` | Match only on specified labels | `a + on (job) b` |
| `ignoring (labels)` | Match ignoring specified labels | `a + ignoring (pod) b` |
| `group_left (labels)` | Many-to-one, copy labels from right | `a * on (job) group_left (version) b` |
| `group_right (labels)` | One-to-many, copy labels from left | `a * on (job) group_right (version) b` |
| `and on ()` | Intersection (both sides match) | `a and on (job) b` |
| `or on ()` | Union (either side) | `a or on (job) b` |
| `unless on ()` | Exclusion (left minus right) | `a unless on (job) b` |

### Common Pitfalls

```promql
# ❌ Wrong: Missing group_left for many-to-one join
rate(http_requests_total[5m]) * on (instance) app_info

# ✅ Correct: Use group_left
rate(http_requests_total[5m]) * on (instance) group_left () app_info

# ❌ Wrong: group_left without on()
rate(http_requests_total[5m]) * group_left (version) app_info

# ✅ Correct: Always pair group_left with on()
rate(http_requests_total[5m]) * on (job, instance) group_left (version) app_info

# ❌ Wrong: Joining on high-cardinality labels causes explosion
metric_a * on (request_id) metric_b

# ✅ Correct: Aggregate first or use lower-cardinality labels
sum by (job) (metric_a) * on (job) sum by (job) (metric_b)
```

---

## Best Practices Summary

1. **Always use label filters** to reduce cardinality
2. **Use appropriate time ranges** - typically `[5m]` for real-time, `[1h]` for trends
3. **Aggregate before histogram_quantile()** - always include `sum by (le)`
4. **Use rate() for counters** - don't query counter values directly
5. **Format for readability** - use multi-line for complex queries
6. **Test queries** - verify they return expected results before productionizing
7. **Use recording rules** - pre-compute expensive queries used frequently
8. **Consider cardinality** - avoid high-cardinality labels in aggregations
9. **Apply exact matches** - use `=` instead of `=~` when possible
10. **Document queries** - add comments explaining complex logic

---

## Pattern Selection Guide

**For monitoring request-driven services**:
- Use RED method (Rate, Errors, Duration)
- Focus on request rate, error rate, and latency percentiles

**For monitoring resources** (CPU, memory, disk):
- Use USE method (Utilization, Saturation, Errors)
- Track usage percentage, queue depth, and error counters

**For alerting**:
- Use threshold-based alerts for known limits
- Use rate-of-change alerts for anomaly detection
- Combine conditions for more accurate alerts

**For dashboards**:
- Use smooth metrics (rate, avg_over_time)
- Show multiple percentiles for latency
- Include comparison with historical data

**For capacity planning**:
- Use predict_linear() for forecasting
- Track trends over longer periods
- Monitor saturation metrics