# PromQL Functions Reference

Complete reference of Prometheus Query Language functions organized by category.

## Aggregation Operators

Aggregation operators combine multiple time series into fewer time series.

**Syntax**: `<operator> [without|by (<label_list>)] (<instant_vector>)`

### sum

Calculates sum of values across time series.

```promql
# Sum all HTTP requests
sum(http_requests_total)

# Sum by job and endpoint
sum by (job, endpoint) (http_requests_total)

# Sum without instance label
sum without (instance) (http_requests_total)
```

**Use for**: Totaling metrics across instances, calculating aggregate throughput.

### avg

Calculates average of values across time series.

```promql
# Average CPU usage across all instances
avg(cpu_usage_percent)

# Average by environment
avg by (environment) (cpu_usage_percent)
```

**Use for**: Average resource usage, typical response times.

### max / min

Returns maximum or minimum value across time series.

```promql
# Maximum memory usage across instances
max(memory_usage_bytes)

# Minimum available disk space by node
min by (node) (disk_available_bytes)
```

**Use for**: Peak resource usage, bottleneck identification.

### count

Counts the number of time series.

```promql
# Count of running instances
count(up == 1)

# Count of instances by version
count by (version) (app_version_info)
```

**Use for**: Counting instances, availability calculations.

### count_values

Counts time series with the same value.

```promql
# Count how many instances have each version
count_values("version", app_version)
```

**Use for**: Distribution analysis, version tracking.

### topk / bottomk

Returns k largest or smallest time series by value.

```promql
# Top 5 endpoints by request count
topk(5, rate(http_requests_total[5m]))

# Bottom 3 instances by available memory
bottomk(3, node_memory_available_bytes)
```

**Use for**: Identifying highest/lowest consumers, troubleshooting hotspots.

### quantile

Calculates φ-quantile (0 ≤ φ ≤ 1) across dimensions.

```promql
# 95th percentile of response times
quantile(0.95, response_time_seconds)

# 50th percentile (median) by service
quantile(0.5, response_time_seconds) by (service)
```

**Use for**: Percentile calculations across simple metrics (not histograms).

### stddev / stdvar

Calculates standard deviation or variance.

```promql
# Standard deviation of response times
stddev(response_time_seconds)
```

**Use for**: Measuring variability, detecting anomalies.

## Rate and Increase Functions

Functions for working with counter metrics (cumulative values that only increase).

### rate

Calculates per-second average rate of increase over a time range.

```promql
# Requests per second over last 5 minutes
rate(http_requests_total[5m])

# Bytes sent per second
rate(bytes_sent_total[1m])
```

**How it works**:
- Calculates increase between first and last samples in range
- Divides by time elapsed to get per-second rate
- Automatically handles counter resets
- Extrapolates to range boundaries

**Best practices**:
- Use with counter metrics only (metrics with `_total`, `_count`, `_sum`, or `_bucket` suffix)
- Range should be at least 4x the scrape interval
- Minimum range typically `[1m]` to `[5m]`
- Returns average rate, smoothing out spikes

**When to use**: For graphing trends, alerting on sustained rates, calculating throughput.

### irate

Calculates instant rate based on the last two data points.

```promql
# Instant rate of HTTP requests
irate(http_requests_total[5m])

# Real-time throughput (sensitive to spikes)
irate(bytes_processed_total[2m])
```

**How it works**:
- Uses only the last two samples in the range
- Range determines maximum lookback window
- More sensitive to short-term changes than `rate()`

**Best practices**:
- Use with counter metrics only
- Best for ranges of `[2m]` to `[5m]`
- More volatile than `rate()`, shows spikes
- Good for alerting on sudden changes

**When to use**: For alerting on spike detection, real-time dashboards showing immediate changes.

**Rate vs irate**:
- `rate()`: Average over time range, smooth
- `irate()`: Instant based on last 2 points, volatile
- For graphing: use `rate()`
- For spike alerts: use `irate()`

**Native Histogram Support (Prometheus 3.3+)**: `irate()` and `idelta()` now work with native histograms, enabling instant rate calculations on histogram data.

```promql
# Instant rate on native histogram (Prometheus 3.3+)
irate(http_request_duration_seconds[5m])
```

### increase

Calculates total increase over a time range.

```promql
# Total requests in the last hour
increase(http_requests_total[1h])

# Total bytes sent in the last day
increase(bytes_sent_total[24h])
```

**How it works**:
- Syntactic sugar for `rate(v) * range_in_seconds`
- Returns total increase (not per-second)
- Automatically handles counter resets
- Extrapolates to range boundaries

**Best practices**:
- Use with counter metrics only
- Useful for calculating totals over periods
- Result can be fractional due to extrapolation

**When to use**: Calculating totals for billing, capacity planning, SLO calculations.

### resets

Counts the number of counter resets within a time range.

```promql
# Number of times counter reset in last hour
resets(http_requests_total[1h])
```

**When to use**: Detecting application restarts, investigating metric inconsistencies.

## Time Functions

Functions for extracting time components and working with timestamps.

### time

Returns current evaluation timestamp as seconds since Unix epoch.

```promql
# Current timestamp
time()

# Time since metric was last seen (in seconds)
time() - max(metric_timestamp)
```

**Use for**: Calculating age of data, time-based math.

### timestamp

Returns timestamp of each sample in the instant vector.

```promql
# Get timestamp of last scrape
timestamp(up)

# Time since last successful backup
time() - timestamp(last_backup_success)
```

**Use for**: Checking staleness, calculating time since event.

### year / month / day_of_month / day_of_week

Extract time components from Unix timestamp.

```promql
# Current year
year()

# Current month (1-12)
month()

# Current day of month (1-31)
day_of_month()

# Current day of week (0=Sunday, 6=Saturday)
day_of_week()

# Extract from specific timestamp
year(timestamp(last_backup))
```

**Use for**: Time-based filtering, business hour alerting.

### hour / minute

Extract hour (0-23) or minute (0-59) from timestamp.

```promql
# Current hour
hour()

# Current minute
minute()

# Check if within business hours (9 AM - 5 PM)
hour() >= 9 and hour() < 17
```

**Use for**: Time-of-day alerting, business hour filtering.

### days_in_month

Returns number of days in the month of the timestamp.

```promql
# Days in current month
days_in_month()

# Days in month of specific timestamp
days_in_month(timestamp(metric))
```

**Use for**: Calendar calculations, month-end processing.

## Prometheus 3.x Time Functions (Experimental)

These functions are available in Prometheus 3.5+ behind the `--enable-feature=promql-experimental-functions` flag.

### ts_of_max_over_time

Returns the timestamp when the maximum value occurred in the range.

```promql
# When did CPU usage peak in the last hour?
ts_of_max_over_time(cpu_usage_percent[1h])

# Find when error spike happened
ts_of_max_over_time(rate(errors_total[5m])[1h:1m])
```

**Use for**: Incident investigation, finding when peaks occurred.

### ts_of_min_over_time

Returns the timestamp when the minimum value occurred in the range.

```promql
# When was memory usage lowest?
ts_of_min_over_time(memory_available_bytes[1h])

# Find when throughput dropped
ts_of_min_over_time(rate(requests_total[5m])[1h:1m])
```

**Use for**: Finding performance troughs, capacity planning.

### ts_of_last_over_time

Returns the timestamp of the last sample in the range.

```promql
# When was this metric last scraped?
ts_of_last_over_time(up[10m])

# Check data freshness
time() - ts_of_last_over_time(metric[1h])
```

**Use for**: Detecting stale data, monitoring scrape health.

### first_over_time (Prometheus 3.7+)

Returns the first (oldest) value in the time range.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# Get the first value in a range
first_over_time(metric[1h])

# Compare current vs initial value
metric - first_over_time(metric[1h])

# Calculate change over time window
last_over_time(metric[1h]) - first_over_time(metric[1h])
```

**Use for**: Baseline comparisons, detecting drift, calculating change over time.

### ts_of_first_over_time (Prometheus 3.7+)

Returns the timestamp of the first sample in the range.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# When did this time series start?
ts_of_first_over_time(metric[24h])

# How long has this metric existed?
time() - ts_of_first_over_time(metric[7d])
```

**Use for**: Tracking when metrics first appeared, calculating metric age.

### mad_over_time (Experimental)

Calculates the median absolute deviation of all float samples in the specified interval.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# Median absolute deviation of CPU usage over 1 hour
mad_over_time(cpu_usage_percent[1h])

# Detect anomalies: values far from median
metric > avg_over_time(metric[1h]) + 3 * mad_over_time(metric[1h])
```

**Use for**: Anomaly detection, measuring variability robustly (less sensitive to outliers than stddev).

### sort_by_label (Experimental)

Returns vector elements sorted by the values of the given labels in ascending order.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# Sort by service name
sort_by_label(up, "service")

# Sort by multiple labels
sort_by_label(http_requests_total, "job", "instance")
```

**How it works**:
- Sorts by the specified label values alphabetically
- If label values are equal, elements are sorted by their full label sets
- Acts on both float and histogram samples
- Only affects instant queries (range queries have fixed ordering)

**Use for**: Organizing query results for display, dashboard ordering.

### sort_by_label_desc (Experimental)

Same as `sort_by_label`, but sorts in descending order.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# Sort by service name (descending)
sort_by_label_desc(up, "service")
```

**Use for**: Reverse alphabetical ordering of results.

## Math Functions

Mathematical operations on metric values.

### abs

Returns absolute value.

```promql
# Absolute value of temperature difference
abs(current_temp - target_temp)
```

### ceil / floor

Rounds up or down to nearest integer.

```promql
# Round up CPU count
ceil(cpu_count_fractional)

# Round down memory in GB
floor(memory_bytes / 1024 / 1024 / 1024)
```

### round

Rounds to nearest integer or specified precision.

```promql
# Round to nearest integer
round(cpu_usage_percent)

# Round to nearest 0.1
round(response_time_seconds, 0.1)

# Round to nearest 10
round(request_count, 10)
```

### sqrt

Calculates square root.

```promql
# Standard deviation calculation
sqrt(avg(metric^2) - avg(metric)^2)
```

### exp / ln / log2 / log10

Exponential and logarithmic functions.

```promql
# Natural exponential
exp(log_scale_metric)

# Natural logarithm
ln(exponential_metric)

# Base-2 logarithm
log2(power_of_two_metric)

# Base-10 logarithm
log10(large_number_metric)
```

### clamp / clamp_max / clamp_min

Limits values to a range.

```promql
# Clamp between 0 and 100
clamp(metric, 0, 100)

# Cap at maximum
clamp_max(metric, 100)

# Ensure minimum
clamp_min(metric, 0)
```

**Use for**: Normalizing values, preventing display overflow.

### sgn

Returns sign of value: 1 for positive, 0 for zero, -1 for negative.

```promql
# Get sign of temperature delta
sgn(current_temp - target_temp)
```

## Native Histogram Functions (Prometheus 3.x+)

Native histograms are now **stable** in Prometheus 3.x. These functions work with native histogram data.

### histogram_quantile (Native Histograms)

For native histograms, the syntax is simpler - no `_bucket` suffix or `le` label needed:

```promql
# Native histogram quantile (simpler syntax)
histogram_quantile(0.95,
  sum by (job) (rate(http_request_duration_seconds[5m]))
)

# Compare with classic histogram (requires _bucket and le)
histogram_quantile(0.95,
  sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

### histogram_count

Extracts the count of observations from a native histogram.

```promql
# Rate of observations per second
histogram_count(rate(http_request_duration_seconds[5m]))

# Total observations in time window
histogram_count(increase(http_request_duration_seconds[1h]))
```

**Use for**: Getting request counts from native histogram metrics.

### histogram_sum

Extracts the sum of observations from a native histogram.

```promql
# Sum of all observation values
histogram_sum(rate(http_request_duration_seconds[5m]))

# Average value from native histogram
histogram_sum(rate(http_request_duration_seconds[5m]))
/
histogram_count(rate(http_request_duration_seconds[5m]))
```

**Use for**: Calculating averages, total latency.

### histogram_fraction

Calculates the fraction of observations between two values in a native histogram.

```promql
# Fraction of requests under 100ms
histogram_fraction(0, 0.1, rate(http_request_duration_seconds[5m]))

# Percentage of requests between 100ms and 500ms
histogram_fraction(0.1, 0.5, rate(http_request_duration_seconds[5m])) * 100

# SLO compliance: percentage under threshold
histogram_fraction(0, 0.2, rate(http_request_duration_seconds[5m])) >= 0.95
```

**Use for**: SLO compliance calculations, distribution analysis.

### histogram_stddev

Calculates the estimated standard deviation of observations in a native histogram.

```promql
# Standard deviation of request durations
histogram_stddev(rate(http_request_duration_seconds[5m]))
```

**How it works**:
- Assumes observations within a bucket are at the mean of bucket boundaries
- For zero buckets and custom-boundary buckets: uses arithmetic mean
- For exponential buckets: uses geometric mean
- Float samples are ignored and do not appear in the returned vector

**Use for**: Understanding variability in metrics, anomaly detection.

### histogram_stdvar

Calculates the estimated standard variance of observations in a native histogram.

```promql
# Standard variance of request durations
histogram_stdvar(rate(http_request_duration_seconds[5m]))

# Compare variance across services
histogram_stdvar(sum by (service) (rate(http_request_duration_seconds[5m])))
```

**How it works**:
- Same estimation method as `histogram_stddev` (variance = stddev²)
- Assumes observations within a bucket are at the mean of bucket boundaries
- For zero buckets and custom-boundary buckets: uses arithmetic mean
- For exponential buckets: uses geometric mean
- Float samples are ignored and do not appear in the returned vector

**Use for**: Statistical analysis, comparing variability across dimensions.

### histogram_avg

Calculates average from a native histogram (shorthand for sum/count).

```promql
# Average request duration
histogram_avg(rate(http_request_duration_seconds[5m]))
```

**Use for**: Quick average calculations.

---

## Prometheus 3.0 Breaking Changes and New Features

This section documents important changes in Prometheus 3.0 (released November 2024) that affect PromQL queries.

### Breaking Changes

1. **Range Selectors Now Left-Open**
   - In Prometheus 3.0, range selectors exclude samples at the lower time boundary
   - A sample coinciding with the lower time limit is now excluded (previously included)
   - This affects queries like `rate(metric[5m])` where the 5-minute-ago sample may behave differently

2. **`holt_winters` Renamed to `double_exponential_smoothing`**
   - The function is now behind `--enable-feature=promql-experimental-functions`
   - See the [double_exponential_smoothing](#double_exponential_smoothing-formerly-holt_winters) section

3. **Regex `.` Now Matches All Characters**
   - The `.` regex pattern now matches all characters including newlines
   - This is a performance improvement but may affect regex-based label matching

### New Features

1. **UTF-8 Metric and Label Names**
   - Prometheus 3.0 allows UTF-8 characters in metric and label names by default
   - Use the quoting syntax for UTF-8 metrics: `{"metric.name.with" = "value"}`

2. **Native Histograms Stable**
   - Native histograms are now stable (no longer experimental)
   - See the [Native Histogram Functions](#native-histogram-functions-prometheus-3x) section

3. **New Experimental Time Functions** (require `--enable-feature=promql-experimental-functions`)
   - `first_over_time()` - Returns the first value in a range (Prometheus 3.7+)
   - `ts_of_first_over_time()` - Timestamp of first sample (Prometheus 3.7+)
   - `ts_of_max_over_time()` - When maximum occurred (Prometheus 3.5+)
   - `ts_of_min_over_time()` - When minimum occurred (Prometheus 3.5+)
   - `ts_of_last_over_time()` - Timestamp of last sample (Prometheus 3.5+)

---

## Classic Histogram and Summary Functions

Functions for working with classic histogram and summary metrics.

### histogram_quantile

Calculates φ-quantile (0 ≤ φ ≤ 1) from histogram buckets.

```promql
# 95th percentile of request duration
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)

# 50th percentile (median) by service
histogram_quantile(0.5,
  sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
)

# 99th percentile with job label preserved
histogram_quantile(0.99,
  sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

**Critical requirements**:
- Must have `le` label (bucket upper bound)
- Must use `rate()` or `irate()` on bucket counters
- Result is interpolated, not exact
- Requires buckets on both sides of the quantile

**Best practices**:
- Always aggregate with `sum` before calling `histogram_quantile()`
- Keep `le` label in aggregation: `sum by (le)` or `sum by (job, le)`
- Apply `rate()` inside the aggregation
- Use appropriate time range for `rate()` (typically `[5m]`)

**Common mistakes**:
- ❌ `histogram_quantile(0.95, rate(metric_bucket[5m]))` - Missing aggregation
- ❌ `histogram_quantile(0.95, sum(metric_bucket))` - Missing rate() and le label
- ✅ `histogram_quantile(0.95, sum by (le) (rate(metric_bucket[5m])))` - Correct

**When to use**: Calculating latency percentiles, response time SLOs.

### histogram_count / histogram_sum

Extracts total count or sum of observations from histogram.

```promql
# Total number of requests (from histogram)
histogram_count(http_request_duration_seconds)

# Total duration of all requests
histogram_sum(http_request_duration_seconds)

# Average request duration
histogram_sum(http_request_duration_seconds)
/
histogram_count(http_request_duration_seconds)
```

**Note**: For classic histograms, use `_count` and `_sum` suffixes instead:
```promql
http_request_duration_seconds_count
http_request_duration_seconds_sum
```

### histogram_fraction

Calculates fraction of observations between two values.

```promql
# Fraction of requests faster than 100ms
histogram_fraction(0, 0.1, http_request_duration_seconds)

# Percentage of requests between 100ms and 500ms
histogram_fraction(0.1, 0.5, http_request_duration_seconds) * 100
```

**Use for**: Calculating SLO compliance, analyzing distribution.

## Range Vector Functions

Functions that operate on range vectors (time series over a duration).

### *_over_time Functions

Calculate statistics over a time range.

```promql
# Average value over last 5 minutes
avg_over_time(cpu_usage_percent[5m])

# Maximum value over last hour
max_over_time(memory_usage_bytes[1h])

# Minimum value over last 10 minutes
min_over_time(disk_available_bytes[10m])

# Sum of values over time range
sum_over_time(event_counter[1h])

# Count of samples in time range
count_over_time(metric[5m])

# Standard deviation over time
stddev_over_time(response_time[5m])

# Variance over time
stdvar_over_time(response_time[5m])

# Quantile over time
quantile_over_time(0.95, response_time[5m])

# First value in range (oldest)
present_over_time(metric[5m])

# Changes (count of value changes)
changes(metric[5m])
```

**Best practices**:
- Use with gauge metrics for analysis
- Don't use with counter metrics (use `rate()` instead)
- Common ranges: `[5m]`, `[1h]`, `[1d]`

**Use cases**:
- `avg_over_time()`: Smoothing noisy gauges
- `max_over_time()` / `min_over_time()`: Peak/trough detection
- `changes()`: Detecting flapping or instability

### deriv

Calculates per-second derivative using linear regression.

```promql
# Rate of change of queue length
deriv(queue_length[5m])
```

**Use for**: Predicting trends, detecting gradual changes.

### predict_linear

Predicts value at future time using linear regression.

```promql
# Predict disk usage in 4 hours
predict_linear(disk_usage_bytes[1h], 4*3600)

# Predict when disk will be full
(disk_capacity_bytes - disk_usage_bytes)
/
deriv(disk_usage_bytes[1h])
```

**Use for**: Capacity forecasting, preemptive alerting.

### double_exponential_smoothing (formerly holt_winters)

Calculates smoothed value using double exponential smoothing (Holt Linear method).

> **Prometheus 3.0 Breaking Change**: This function was renamed from `holt_winters` to `double_exponential_smoothing` in Prometheus 3.0. The old name `holt_winters` no longer works.
>
> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

```promql
# Smooth and forecast metric (Prometheus 3.0+)
double_exponential_smoothing(metric[1h], 0.5, 0.5)

# For Prometheus 2.x, use the old name:
# holt_winters(metric[1h], 0.5, 0.5)
```

**Parameters**:
- First number (sf): smoothing factor (0-1) - lower values give more weight to old data
- Second number (tf): trend factor (0-1) - higher values consider more trends

**Important Notes**:
- Should only be used with gauge metrics
- Only works with float samples (histogram samples are ignored)
- The rename was done because "Holt-Winters" usually refers to triple exponential smoothing, while this implementation is double exponential smoothing (also called "Holt Linear")

**Use for**: Seasonal pattern detection, anomaly detection, trend forecasting.

## Label Manipulation Functions

Functions for modifying labels on time series.

### label_replace

Replaces label value using regex. Syntax:
`label_replace(v, dst_label, replacement, src_label, regex)`

```promql
# Extract hostname from instance (remove port)
# Input: instance="server-1:9090" → Output: hostname="server-1"
label_replace(
  up,
  "hostname",        # destination label name
  "$1",              # replacement ($1 = first capture group)
  "instance",        # source label
  "(.+):\\d+"        # regex (capture everything before :port)
)

# Extract region from instance FQDN
# Input: instance="web-1.us-east-1.example.com:9090"
# Output: region="us-east-1"
label_replace(
  metric,
  "region",
  "$1",
  "instance",
  "[^.]+\\.([^.]+)\\..*"
)

# Create environment label from job name
# Input: job="api-production" → Output: env="production"
label_replace(
  metric,
  "env",
  "$1",
  "job",
  ".*-(.*)"
)

# Copy label to new name (rename)
label_replace(
  metric,
  "service",         # new label name
  "$1",
  "job",             # original label
  "(.*)"             # match everything
)

# Add static prefix/suffix to label
label_replace(
  metric,
  "full_name",
  "prefix-$1-suffix",
  "name",
  "(.*)"
)

# Handle missing labels (empty replacement if no match)
label_replace(
  metric,
  "extracted",
  "$1",
  "optional_label",
  "pattern-(.*)"     # Returns empty string if no match
)
```

**Syntax notes**:
- `$1`, `$2`, etc. refer to regex capture groups
- If regex doesn't match, the destination label gets an empty string
- If destination label already exists, it gets overwritten

**Use for**: Creating new labels, extracting parts of label values, renaming labels.

### label_join

Joins multiple label values with a separator. Syntax:
`label_join(v, dst_label, separator, src_label1, src_label2, ...)`

```promql
# Combine job and instance into single label
# Input: job="api", instance="server-1" → Output: job_instance="api:server-1"
label_join(
  metric,
  "job_instance",    # destination label name
  ":",               # separator
  "job",             # first source label
  "instance"         # second source label
)

# Create full path from multiple labels
# Input: namespace="prod", service="api", pod="api-xyz"
# Output: full_path="prod/api/api-xyz"
label_join(
  metric,
  "full_path",
  "/",
  "namespace",
  "service",
  "pod"
)

# Create unique identifier
label_join(
  metric,
  "uid",
  "-",
  "cluster",
  "namespace",
  "pod"
)

# Join with empty separator (concatenate)
label_join(
  metric,
  "combined",
  "",
  "prefix",
  "name"
)
```

**Use for**: Combining labels for grouping, creating unique identifiers, display purposes.

### info() Function (Experimental)

The `info()` function (experimental in Prometheus 3.x) enriches metrics with labels from info metrics like `target_info`.

> **Requires Feature Flag**: Must enable with `--enable-feature=promql-experimental-functions`

**Syntax**: `info(v instant-vector, [data-label-selector instant-vector])`

```promql
# Enrich metrics with target_info labels
info(
  rate(http_requests_total[5m]),
  {k8s_cluster_name=~".+"}
)

# Without data-label-selector (adds all data labels from matching info metrics)
info(rate(http_requests_total[5m]))

# Equivalent using raw join (works in all Prometheus versions)
rate(http_requests_total[5m])
* on (job, instance) group_left (k8s_cluster_name, k8s_namespace_name)
  target_info
```

**How it works**:
- Finds, for each time series in `v`, all info series with matching identifying labels
- Adds the union of their data (non-identifying) labels to the time series
- The optional second argument constrains which info series to consider and which data labels to add
- Identifying labels are the subset of labels that uniquely identify the info series

**Current Limitations**:
- This is an experimental function and behavior may change
- Designed to improve UX around including labels from info metrics
- Works best with OpenTelemetry's `target_info` metric

**Use for**: Adding resource attributes from OpenTelemetry, enriching metrics with metadata, simplifying group_left joins with info metrics.

## Utility Functions

Miscellaneous utility functions.

### absent

Returns 1-element vector if input is empty, otherwise returns empty.

```promql
# Alert if metric is missing
absent(up{job="critical-service"})

# Alert if no instances are up
absent(up{job="api"} == 1)
```

**Use for**: Alerting on missing metrics or time series.

### absent_over_time

Returns 1 if no samples exist in the time range.

```promql
# Alert if no data for 10 minutes
absent_over_time(metric[10m])
```

**Use for**: Detecting data gaps, scrape failures.

### scalar

Converts single-element instant vector to scalar.

```promql
# Convert vector to scalar for math
scalar(sum(up{job="api"}))

# Use in calculations
metric * scalar(sum(scaling_factor))
```

**Warning**: Returns NaN if input has 0 or >1 elements.

### vector

Converts scalar to single-element instant vector.

```promql
# Convert number to vector
vector(123)

# Current timestamp as vector
vector(time())
```

**Use for**: Combining scalars with vector operations.

### sort / sort_desc

Sorts instant vector by value.

```promql
# Sort ascending
sort(http_requests_total)

# Sort descending
sort_desc(http_requests_total)
```

**Use for**: Display ordering (topk/bottomk are usually better).

## Advanced Functions

### group

Returns constant 1 for each time series, removing all values.

```promql
# Get all time series without values
group(metric)
```

**Use for**: Existence checks, label discovery.

## Function Chaining

Functions can be chained to build complex queries:

```promql
# Multi-stage aggregation
topk(10,
  sum by (endpoint) (
    rate(http_requests_total{job="api"}[5m])
  )
)

# Nested time-based calculations
max_over_time(
  rate(metric[5m])[1h:1m]
)

# Complex ratio with aggregations
(
  sum by (job) (rate(http_errors_total[5m]))
  /
  sum by (job) (rate(http_requests_total[5m]))
) * 100
```

## Performance Considerations

1. **Range Vector Size**: Larger ranges process more data
   - `[5m]` is fast and usually sufficient
   - `[1h]` or larger can be expensive
   - Use recording rules for large ranges used frequently

2. **Cardinality**: Functions on high-cardinality metrics are expensive
   - Add label filters to reduce series count
   - Use aggregation to reduce dimensions
   - Avoid operations on bare metric names

3. **Subqueries**: Can be very expensive
   - Limit subquery ranges
   - Consider recording rules for complex subqueries
   - Test query performance before production use

4. **Regex**: Slower than exact matches
   - Use `=` instead of `=~` when possible
   - Keep regex patterns simple
   - Anchor patterns when possible

## Function Decision Tree

**For Counters** (metrics with `_total`, `_count`, `_sum`, `_bucket`):
- Graphing trends → `rate()`
- Detecting spikes → `irate()`
- Calculating totals → `increase()`
- Checking for resets → `resets()`

**For Gauges** (memory, temperature, queue depth):
- Current value → use directly
- Average over time → `avg_over_time()`
- Peak detection → `max_over_time()` / `min_over_time()`
- Smoothing noisy data → `avg_over_time()`

**For Histograms** (`_bucket` suffix with `le` label):
- Percentiles → `histogram_quantile()`
- Average → use `_sum` / `_count`
- Request count → use `_count`

**For Summaries** (pre-calculated quantiles):
- Use quantile labels directly
- Don't average quantiles
- Calculate average from `_sum` / `_count`