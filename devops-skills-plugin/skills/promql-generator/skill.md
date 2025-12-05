---
name: promql-generator
description: Comprehensive toolkit for generating best practice PromQL (Prometheus Query Language) queries following current standards and conventions. Use this skill when creating new PromQL queries, implementing monitoring and alerting rules, or building observability dashboards.
---

# PromQL Query Generator

## Overview

This skill provides a comprehensive, interactive workflow for generating production-ready PromQL queries with best practices built-in. Generate queries for monitoring dashboards, alerting rules, and ad-hoc analysis with an emphasis on user collaboration and planning before code generation.

## When to Use This Skill

Invoke this skill when:
- Creating new PromQL queries from scratch
- Building monitoring dashboards (Grafana, Prometheus UI, etc.)
- Implementing alerting rules for Prometheus Alertmanager
- Analyzing metrics for troubleshooting or capacity planning
- Converting monitoring requirements into PromQL expressions
- Learning PromQL or teaching others
- The user asks to "create", "generate", "build", or "write" PromQL queries
- Working with Prometheus metrics (counters, gauges, histograms, summaries)
- Implementing RED (Rate, Errors, Duration) or USE (Utilization, Saturation, Errors) metrics

## Interactive Query Planning Workflow

**CRITICAL**: This skill emphasizes **interactive planning** before query generation. Always engage the user in a collaborative planning process to ensure the generated query matches their exact intentions.

Follow this workflow when generating PromQL queries:

### Stage 1: Understand the Monitoring Goal

Start by understanding what the user wants to monitor or measure. Ask clarifying questions to gather requirements:

1. **Primary Goal**: What are you trying to monitor or measure?
   - Request rate (requests per second)
   - Error rate (percentage of failed requests)
   - Latency/duration (response times, percentiles)
   - Resource usage (CPU, memory, disk, network)
   - Availability/uptime
   - Queue depth, saturation, throughput
   - Custom business metrics

2. **Use Case**: What will this query be used for?
   - Dashboard visualization (Grafana, Prometheus UI)
   - Alerting rule (firing when threshold exceeded)
   - Ad-hoc troubleshooting/analysis
   - Recording rule (pre-computed aggregation)
   - Capacity planning or SLO tracking

3. **Context**: Any additional context?
   - Service/application name
   - Team or project
   - Priority level
   - Existing metrics or naming conventions

Use the **AskUserQuestion** tool to gather this information if not provided.

> **When to Ask vs. Infer**: If the user's initial request already clearly specifies the goal, use case, and context (e.g., "Create an alert for P95 latency > 500ms for payment-service"), you may acknowledge these details in your response instead of re-asking. Only ask clarifying questions for information that is missing or ambiguous.

### Stage 2: Identify Available Metrics

Determine which metrics are available and relevant:

1. **Metric Discovery**: What metrics are available?
   - Ask the user for metric names
   - If uncertain, suggest common naming patterns
   - Check for metric type indicators in the name:
     - `_total` suffix → Counter
     - `_bucket`, `_sum`, `_count` suffix → Histogram
     - No suffix → Likely Gauge
     - `_created` suffix → Counter creation timestamp

2. **Metric Type Identification**: Confirm the metric type(s)
   - **Counter**: Cumulative metric that only increases (or resets to zero)
     - Examples: `http_requests_total`, `errors_total`, `bytes_sent_total`
     - Use with: `rate()`, `irate()`, `increase()`
   - **Gauge**: Point-in-time value that can go up or down
     - Examples: `memory_usage_bytes`, `cpu_temperature_celsius`, `queue_length`
     - Use with: `avg_over_time()`, `min_over_time()`, `max_over_time()`, or directly
   - **Histogram**: Buckets of observations with cumulative counts
     - Examples: `http_request_duration_seconds_bucket`, `response_size_bytes_bucket`
     - Use with: `histogram_quantile()`, `rate()`
   - **Summary**: Pre-calculated quantiles with count and sum
     - Examples: `rpc_duration_seconds{quantile="0.95"}`
     - Use `_sum` and `_count` for averages; don't average quantiles

3. **Label Discovery**: What labels are available on these metrics?
   - Common labels: `job`, `instance`, `environment`, `service`, `endpoint`, `status_code`, `method`
   - Ask which labels are important for filtering or grouping

Use the **AskUserQuestion** tool to confirm metric names, types, and available labels.

### Stage 3: Determine Query Parameters

Gather specific requirements for the query.

#### Pre-confirmation for User-Provided Parameters

**IMPORTANT**: When the user has already specified parameters in their initial request (e.g., "5-minute window", "500ms threshold", "> 5% error rate"), you MUST:

1. **Acknowledge the provided values** explicitly in your response
2. **Present them as pre-filled defaults** in AskUserQuestion with the first option being "Use specified values"
3. **Allow quick confirmation** rather than re-asking for information already given

**Example**: If user says "alert when P95 latency exceeds 500ms", use:
```
AskUserQuestion:
- Question: "Confirm the alert threshold?"
- Options:
  1. "500ms (as specified)" - Use the threshold from your request
  2. "Different threshold" - Let me specify a different value
```

This respects the user's input and speeds up the workflow while still allowing modifications.

1. **Time Range**: What time window should the query cover?
   - Instant value (current)
   - Rate over time (`[5m]`, `[1h]`, `[1d]`)
   - For rate calculations: typically `[1m]` to `[5m]` for real-time, `[1h]` to `[1d]` for trends
   - Rule of thumb: Rate range should be at least 4x the scrape interval

2. **Label Filtering**: Which labels should filter the data?
   - Exact matches: `job="api-server"`, `status_code="200"`
   - Negative matches: `status_code!="200"`
   - Regex matches: `instance=~"prod-.*"`
   - Multiple conditions: `{job="api", environment="production"}`

3. **Aggregation**: Should the data be aggregated?
   - **No aggregation**: Return all time series as-is
   - **Aggregate by labels**: `sum by (job, endpoint)`, `avg by (instance)`
   - **Aggregate without labels**: `sum without (instance, pod)`, `avg without (job)`
   - Common aggregations: `sum`, `avg`, `max`, `min`, `count`, `topk`, `bottomk`

4. **Thresholds or Conditions**: Are there specific conditions?
   - For alerting: threshold values (e.g., error rate > 5%)
   - For filtering: only show series above/below a value
   - For comparison: compare against historical data (offset)

Use the **AskUserQuestion** tool to gather or confirm these parameters. When the user has already provided values (e.g., "5-minute window", "> 5%"), present them as the default option for confirmation.

### Stage 4: Present the Query Plan

**BEFORE GENERATING ANY CODE**, present a plain-English query plan and ask for user confirmation:

```
## PromQL Query Plan

Based on your requirements, here's what the query will do:

**Goal**: [Describe the monitoring goal in plain English]

**Query Structure**:
1. Start with metric: `[metric_name]`
2. Filter by labels: `{label1="value1", label2="value2"}`
3. Apply function: `[function_name]([metric][time_range])`
4. Aggregate: `[aggregation] by ([label_list])`
5. Additional operations: [any calculations, ratios, or transformations]

**Expected Output**:
- Data type: [instant vector/scalar]
- Labels in result: [list of labels]
- Value represents: [what the number means]
- Typical range: [expected value range]

**Example Interpretation**:
If the query returns `0.05`, it means: [plain English explanation]

**Does this match your intentions?**
- If yes, I'll generate the query and validate it
- If no, let me know what needs to change
```

Use the **AskUserQuestion** tool to confirm the plan with options:
- "Yes, generate this query"
- "Modify [specific aspect]"
- "Show me alternative approaches"

### Stage 5: Generate the PromQL Query

Once the user confirms the plan, generate the actual PromQL query following best practices.

#### IMPORTANT: Consult Reference Files Before Generating

**Before writing any query code**, you MUST:

1. **Read the relevant reference file(s)** using the Read tool:
   - For histogram queries → Read `references/metric_types.md` (Histogram section)
   - For error/latency patterns → Read `references/promql_patterns.md` (RED method section)
   - For resource monitoring → Read `references/promql_patterns.md` (USE method section)
   - For optimization questions → Read `references/best_practices.md`
   - For specific functions → Read `references/promql_functions.md`

2. **Cite the applicable pattern or best practice** in your response:
   ```
   As documented in references/promql_patterns.md (Pattern 3: Latency Percentile):
   # 95th percentile latency
   histogram_quantile(0.95, sum by (le) (rate(...)))
   ```

3. **Reference example files** when generating similar queries:
   ```
   Based on examples/red_method.promql (lines 64-82):
   # P95 latency with proper histogram_quantile usage
   ```

This ensures generated queries follow documented patterns and helps users understand why certain approaches are recommended.

#### Best Practices for Query Generation

1. **Always Use Label Filters**
   ```promql
   # Good: Specific filtering reduces cardinality
   rate(http_requests_total{job="api-server", environment="prod"}[5m])

   # Bad: Matches all time series, high cardinality
   rate(http_requests_total[5m])
   ```

2. **Use Appropriate Functions for Metric Types**
   ```promql
   # Counter: Use rate() or increase()
   rate(http_requests_total[5m])

   # Gauge: Use directly or with *_over_time()
   memory_usage_bytes
   avg_over_time(memory_usage_bytes[5m])

   # Histogram: Use histogram_quantile()
   histogram_quantile(0.95,
     sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
   )
   ```

3. **Apply Aggregations with by() or without()**
   ```promql
   # Aggregate by specific labels (keeps only these labels)
   sum by (job, endpoint) (rate(http_requests_total[5m]))

   # Aggregate without specific labels (removes these labels)
   sum without (instance, pod) (rate(http_requests_total[5m]))
   ```

4. **Use Exact Matches Over Regex When Possible**
   ```promql
   # Good: Faster exact match
   http_requests_total{status_code="200"}

   # Bad: Slower regex match when not needed
   http_requests_total{status_code=~"200"}
   ```

5. **Calculate Ratios Properly**
   ```promql
   # Error rate: errors / total requests
   sum(rate(http_requests_total{status_code=~"5.."}[5m]))
   /
   sum(rate(http_requests_total[5m]))
   ```

6. **Use Recording Rules for Complex Queries**
   - If a query is used frequently or is computationally expensive
   - Pre-aggregate data to reduce query load
   - Follow naming convention: `level:metric:operations`

7. **Format for Readability**
   ```promql
   # Good: Multi-line for complex queries
   histogram_quantile(0.95,
     sum by (le, job) (
       rate(http_request_duration_seconds_bucket{job="api-server"}[5m])
     )
   )
   ```

#### Common Query Patterns

**Pattern 1: Request Rate**
```promql
# Requests per second
rate(http_requests_total{job="api-server"}[5m])

# Total requests per second across all instances
sum(rate(http_requests_total{job="api-server"}[5m]))
```

**Pattern 2: Error Rate**
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
```

**Pattern 3: Latency Percentile (Histogram)**
```promql
# 95th percentile latency
histogram_quantile(0.95,
  sum by (le) (
    rate(http_request_duration_seconds_bucket{job="api-server"}[5m])
  )
)
```

**Pattern 4: Resource Usage**
```promql
# Current memory usage
process_resident_memory_bytes{job="api-server"}

# Average CPU usage over 5 minutes
avg_over_time(process_cpu_seconds_total{job="api-server"}[5m])
```

**Pattern 5: Availability**
```promql
# Percentage of up instances
(
  count(up{job="api-server"} == 1)
  /
  count(up{job="api-server"})
) * 100
```

**Pattern 6: Saturation/Queue Depth**
```promql
# Average queue length
avg_over_time(queue_depth{job="worker"}[5m])

# Maximum queue depth in the last hour
max_over_time(queue_depth{job="worker"}[1h])
```

### Stage 6: Validate the Generated Query

**ALWAYS validate the generated query** using the devops-skills:promql-validator skill:

```
After generating the query, automatically invoke:
Skill(devops-skills:promql-validator)

The devops-skills:promql-validator skill will:
1. Check syntax correctness
2. Validate semantic logic (correct functions for metric types)
3. Identify anti-patterns and inefficiencies
4. Suggest optimizations
5. Explain what the query does
6. Verify it matches user intent
```

**Validation checklist**:
- Syntax is correct (balanced brackets, valid operators)
- Metric type matches function usage
- Label filters are specific enough
- Aggregation is appropriate
- Time ranges are reasonable
- No known anti-patterns
- Query is optimized for performance

If validation fails, fix issues and re-validate until all checks pass.

**IMPORTANT: Display Validation Results to User**

After running validation, you MUST display the structured results to the user in this format:

```
## PromQL Validation Results

### Syntax Check
- Status: ✅ VALID / ⚠️ WARNING / ❌ ERROR
- Issues: [list any syntax errors]

### Best Practices Check
- Status: ✅ OPTIMIZED / ⚠️ CAN BE IMPROVED / ❌ HAS ISSUES
- Issues: [list any problems found]
- Suggestions: [list optimization opportunities]

### Query Explanation
- **What it measures**: [plain English description]
- **Output labels**: [list labels in result, or "None (scalar)"]
- **Expected result structure**: [instant vector / scalar / etc.]
```

This transparency helps users understand the validation process and any recommendations.

### Stage 7: Provide Usage Instructions

After successful generation and validation, provide the user with:

1. **The Final Query**:
   ```promql
   [Generated and validated PromQL query]
   ```

2. **Query Explanation**:
   - What the query measures
   - How to interpret the results
   - Expected value range
   - Labels in the output

3. **How to Use It**:
   - **For Dashboards**: Copy into Grafana/Prometheus UI panel query
   - **For Alerts**: Integrate into Alertmanager rule with threshold
   - **For Recording Rules**: Add to Prometheus recording rule config
   - **For Ad-hoc**: Run directly in Prometheus expression browser

4. **Customization Notes**:
   - Time ranges that might need adjustment
   - Labels to modify for different environments
   - Threshold values to tune
   - Alternative functions if requirements change

5. **Related Queries**:
   - Suggest complementary queries
   - Mention recording rule opportunities
   - Recommend dashboard panels

## Native Histograms (Prometheus 3.x+)

Native histograms are now **stable** in Prometheus 3.0+ (released November 2024). They offer significant advantages over classic histograms:
- Sparse bucket representation with near-zero cost for empty buckets
- No configuration of bucket boundaries during instrumentation
- Coverage of the full float64 range
- Efficient mergeability across histograms
- Simpler query syntax

> **Important**: Starting with Prometheus v3.8.0, native histograms are fully stable. However, scraping native histograms still requires explicit activation via the `scrape_native_histograms` configuration setting. Starting with v3.9, no feature flag is needed but `scrape_native_histograms` must be set explicitly.

### Native vs Classic Histogram Syntax

```promql
# Classic histogram (requires _bucket suffix and le label)
histogram_quantile(0.95,
  sum by (job, le) (rate(http_request_duration_seconds_bucket[5m]))
)

# Native histogram (simpler - no _bucket suffix, no le label needed)
histogram_quantile(0.95,
  sum by (job) (rate(http_request_duration_seconds[5m]))
)
```

### Native Histogram Functions

```promql
# Get observation count rate from native histogram
histogram_count(rate(http_request_duration_seconds[5m]))

# Get sum of observations from native histogram
histogram_sum(rate(http_request_duration_seconds[5m]))

# Calculate fraction of observations between two values
histogram_fraction(0, 0.1, rate(http_request_duration_seconds[5m]))

# Average request duration from native histogram
histogram_sum(rate(http_request_duration_seconds[5m]))
/
histogram_count(rate(http_request_duration_seconds[5m]))
```

### Detecting Native vs Classic Histograms

Native histograms are identified by:
- **No `_bucket` suffix** on the metric name
- **No `le` label** in the time series
- The metric stores histogram data directly (not separate bucket counters)

When querying, check if your Prometheus instance has native histograms enabled:
```yaml
# prometheus.yml - Enable native histogram scraping
scrape_configs:
  - job_name: 'my-app'
    scrape_native_histogram: true  # Prometheus 3.x+
```

### Custom Bucket Native Histograms (NHCB)

Prometheus 3.4+ supports custom bucket native histograms (schema -53), allowing classic histogram to native histogram conversion. This is a key migration path for users with existing classic histograms.

**Benefits of NHCB**:
- Keep existing instrumentation (no code changes needed)
- Store classic histograms as native histograms for lower costs
- Query with native histogram syntax
- Improved reliability and compression

**Configuration** (Prometheus 3.4+):
```yaml
# prometheus.yml - Convert classic histograms to NHCB on scrape
global:
  scrape_configs:
    - job_name: 'my-app'
      convert_classic_histograms_to_nhcb: true  # Prometheus 3.4+
```

**Querying NHCB**:
```promql
# Query NHCB metrics the same way as native histograms
histogram_quantile(0.95, sum by (job) (rate(http_request_duration_seconds[5m])))

# histogram_fraction also works with NHCB (Prometheus 3.4+)
histogram_fraction(0, 0.2, rate(http_request_duration_seconds[5m]))
```

**Note**: Schema -53 indicates custom bucket boundaries. These histograms with different custom bucket boundaries are generally not mergeable with each other.

---

## SLO, Error Budget, and Burn Rate Patterns

Service Level Objectives (SLOs) are critical for modern SRE practices. These patterns help implement SLO-based monitoring and alerting.

### Error Budget Calculation

```promql
# Error budget remaining (for 99.9% SLO over 30 days)
# Returns value between 0 and 1 (1 = full budget, 0 = exhausted)
1 - (
  sum(rate(http_requests_total{job="api", status_code=~"5.."}[30d]))
  /
  sum(rate(http_requests_total{job="api"}[30d]))
) / 0.001  # 0.001 = 1 - 0.999 (allowed error rate)

# Simplified: Availability over 30 days
sum(rate(http_requests_total{job="api", status_code!~"5.."}[30d]))
/
sum(rate(http_requests_total{job="api"}[30d]))
```

### Burn Rate Calculation

Burn rate measures how fast you're consuming error budget. A burn rate of 1 means you'll exhaust the budget exactly at the end of the SLO window.

```promql
# Current burn rate (1 hour window, 99.9% SLO)
# Burn rate = (current error rate) / (allowed error rate)
(
  sum(rate(http_requests_total{job="api", status_code=~"5.."}[1h]))
  /
  sum(rate(http_requests_total{job="api"}[1h]))
) / 0.001  # 0.001 = allowed error rate for 99.9% SLO

# Burn rate > 1 means consuming budget faster than allowed
# Burn rate of 14.4 consumes 2% of monthly budget in 1 hour
```

### Multi-Window, Multi-Burn-Rate Alerts (Google SRE Standard)

The recommended approach for SLO alerting uses multiple windows to balance detection speed and precision:

```promql
# Page-level alert: 2% budget in 1 hour (burn rate 14.4)
# Long window (1h) AND short window (5m) must both exceed threshold
(
  (
    sum(rate(http_requests_total{job="api", status_code=~"5.."}[1h]))
    /
    sum(rate(http_requests_total{job="api"}[1h]))
  ) > 14.4 * 0.001
)
and
(
  (
    sum(rate(http_requests_total{job="api", status_code=~"5.."}[5m]))
    /
    sum(rate(http_requests_total{job="api"}[5m]))
  ) > 14.4 * 0.001
)

# Ticket-level alert: 5% budget in 6 hours (burn rate 6)
(
  (
    sum(rate(http_requests_total{job="api", status_code=~"5.."}[6h]))
    /
    sum(rate(http_requests_total{job="api"}[6h]))
  ) > 6 * 0.001
)
and
(
  (
    sum(rate(http_requests_total{job="api", status_code=~"5.."}[30m]))
    /
    sum(rate(http_requests_total{job="api"}[30m]))
  ) > 6 * 0.001
)
```

### SLO Recording Rules

Pre-compute SLO metrics for efficient alerting:

```yaml
# Recording rules for SLO calculations
groups:
  - name: slo_recording_rules
    interval: 30s
    rules:
      # Error ratio over different windows
      - record: job:slo_errors_per_request:ratio_rate1h
        expr: |
          sum by (job) (rate(http_requests_total{status_code=~"5.."}[1h]))
          /
          sum by (job) (rate(http_requests_total[1h]))

      - record: job:slo_errors_per_request:ratio_rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status_code=~"5.."}[5m]))
          /
          sum by (job) (rate(http_requests_total[5m]))

      # Availability (success ratio)
      - record: job:slo_availability:ratio_rate1h
        expr: |
          1 - job:slo_errors_per_request:ratio_rate1h
```

### Latency SLO Queries

```promql
# Percentage of requests faster than SLO target (200ms)
(
  sum(rate(http_request_duration_seconds_bucket{le="0.2", job="api"}[5m]))
  /
  sum(rate(http_request_duration_seconds_count{job="api"}[5m]))
) * 100

# Requests violating latency SLO (slower than 500ms)
(
  sum(rate(http_request_duration_seconds_count{job="api"}[5m]))
  -
  sum(rate(http_request_duration_seconds_bucket{le="0.5", job="api"}[5m]))
)
/
sum(rate(http_request_duration_seconds_count{job="api"}[5m]))
```

### Burn Rate Reference Table

| Burn Rate | Budget Consumed | Time to Exhaust 30-day Budget | Alert Severity |
|-----------|-----------------|-------------------------------|----------------|
| 1         | 100% over 30d   | 30 days                       | None           |
| 2         | 100% over 15d   | 15 days                       | Low            |
| 6         | 5% in 6h        | 5 days                        | Ticket         |
| 14.4      | 2% in 1h        | ~2 days                       | Page           |
| 36        | 5% in 1h        | ~20 hours                     | Page (urgent)  |

---

## Advanced Query Techniques

### Using Subqueries

Subqueries enable complex time-based calculations:

```promql
# Maximum 5-minute rate over the past 30 minutes
max_over_time(
  rate(http_requests_total[5m])[30m:1m]
)
```

**Syntax**: `<query>[<range>:<resolution>]`
- `<range>`: Time window to evaluate over
- `<resolution>`: Step size between evaluations

### Using Offset Modifier

Compare current data with historical data:

```promql
# Compare current rate with rate from 1 week ago
rate(http_requests_total[5m])
-
rate(http_requests_total[5m] offset 1w)
```

### Using @ Modifier

Query metrics at specific timestamps:

```promql
# Rate at the end of the range query
rate(http_requests_total[5m] @ end())

# Rate at specific Unix timestamp
rate(http_requests_total[5m] @ 1609459200)
```

### Binary Operators and Vector Matching

Combine metrics with operators and control label matching:

```promql
# One-to-one matching (default)
metric_a + metric_b

# Many-to-one with group_left
rate(http_requests_total[5m])
* on (job, instance) group_left (version)
  app_version_info

# Ignoring specific labels
metric_a + ignoring(instance) metric_b
```

### Logical Operators

Filter time series based on conditions:

```promql
# Return series only where value > 100
http_requests_total > 100

# Return series present in both
metric_a and metric_b

# Return series in A but not in B
metric_a unless metric_b
```

## Documentation Lookup

If the user asks about specific Prometheus features, operators, or custom metrics:

1. **Try context7 MCP first (preferred)**:
   ```
   Use mcp__context7__resolve-library-id with "prometheus"
   Then use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID: /prometheus/docs
   - topic: [specific feature, function, or operator]
   - page: 1 (fetch additional pages if needed)
   ```

2. **Fallback to WebSearch**:
   ```
   Search query pattern:
   "Prometheus PromQL [function/operator/feature] documentation [version] examples"

   Examples:
   "Prometheus PromQL rate function documentation examples"
   "Prometheus PromQL histogram_quantile documentation best practices"
   "Prometheus PromQL aggregation operators documentation"
   ```

## Common Monitoring Scenarios

### RED Method (for Request-Driven Services)

1. **Rate**: Request throughput
   ```promql
   sum(rate(http_requests_total{job="api"}[5m])) by (endpoint)
   ```

2. **Errors**: Error rate
   ```promql
   sum(rate(http_requests_total{job="api", status_code=~"5.."}[5m]))
   /
   sum(rate(http_requests_total{job="api"}[5m]))
   ```

3. **Duration**: Latency percentiles
   ```promql
   histogram_quantile(0.95,
     sum by (le) (rate(http_request_duration_seconds_bucket{job="api"}[5m]))
   )
   ```

### USE Method (for Resources)

1. **Utilization**: Resource usage percentage
   ```promql
   (
     avg(rate(node_cpu_seconds_total{mode!="idle"}[5m]))
     /
     count(node_cpu_seconds_total{mode="idle"})
   ) * 100
   ```

2. **Saturation**: Queue depth or resource contention
   ```promql
   avg_over_time(node_load1[5m])
   ```

3. **Errors**: Error counters
   ```promql
   rate(node_network_receive_errs_total[5m])
   ```

## Alerting Rules

When generating queries for alerting:

1. **Include the Threshold**: Make the condition explicit
   ```promql
   # Alert when error rate exceeds 5%
   (
     sum(rate(http_requests_total{status_code=~"5.."}[5m]))
     /
     sum(rate(http_requests_total[5m]))
   ) > 0.05
   ```

2. **Use Boolean Operators**: Return 1 (fire) or 0 (no alert)
   ```promql
   # Returns 1 when memory usage > 90%
   (process_resident_memory_bytes / node_memory_MemTotal_bytes) > 0.9
   ```

3. **Consider for Duration**: Alerts typically use `for` clause
   ```yaml
   alert: HighErrorRate
   expr: |
     (
       sum(rate(http_requests_total{status_code=~"5.."}[5m]))
       /
       sum(rate(http_requests_total[5m]))
     ) > 0.05
   for: 10m  # Only fire after 10 minutes of continuous violation
   ```

## Recording Rules

When generating queries for recording rules:

1. **Follow Naming Convention**: `level:metric:operations`
   ```yaml
   # level: aggregation level (job, instance, etc.)
   # metric: base metric name
   # operations: functions applied

   - record: job:http_requests:rate5m
     expr: sum by (job) (rate(http_requests_total[5m]))
   ```

2. **Pre-aggregate Expensive Queries**:
   ```yaml
   # Recording rule for frequently-used latency query
   - record: job_endpoint:http_request_duration_seconds:p95
     expr: |
       histogram_quantile(0.95,
         sum by (job, endpoint, le) (
           rate(http_request_duration_seconds_bucket[5m])
         )
       )
   ```

3. **Use Recorded Metrics in Dashboards**:
   ```promql
   # Instead of expensive query, use pre-recorded metric
   job_endpoint:http_request_duration_seconds:p95{job="api-server"}
   ```

## Error Handling

### Common Issues and Solutions

1. **Empty Results**:
   - Check if metrics exist: `up{job="your-job"}`
   - Verify label filters are correct
   - Check time range is appropriate
   - Confirm metric is being scraped

2. **Too Many Series (High Cardinality)**:
   - Add more specific label filters
   - Use aggregation to reduce series count
   - Consider using recording rules
   - Check for label explosion (dynamic labels)

3. **Incorrect Values**:
   - Verify metric type (counter vs gauge)
   - Check function usage (rate on counters, not gauges)
   - Verify time range is appropriate
   - Check for counter resets

4. **Performance Issues**:
   - Reduce time range for range vectors
   - Add label filters to reduce cardinality
   - Use recording rules for complex queries
   - Avoid expensive regex patterns
   - Consider query timeout settings

## Communication Guidelines

When generating queries:

1. **Explain the Plan**: Always present a plain-English plan before generating
2. **Ask Questions**: Use AskUserQuestion tool to gather requirements
3. **Confirm Intent**: Verify the query matches user goals before finalizing
4. **Educate**: Explain why certain functions or patterns are used
5. **Provide Context**: Show how to interpret results
6. **Suggest Improvements**: Offer optimizations or alternative approaches
7. **Validate Proactively**: Always validate and fix issues
8. **Follow Up**: Ask if adjustments are needed

## Integration with devops-skills:promql-validator

After generating any PromQL query, **automatically invoke the devops-skills:promql-validator skill** to ensure quality:

```
Steps:
1. Generate the PromQL query based on user requirements
2. Invoke devops-skills:promql-validator skill with the generated query
3. Review validation results (syntax, semantics, performance)
4. Fix any issues identified by the validator
5. Re-validate until all checks pass
6. Provide the final validated query with usage instructions
7. Ask user if further refinements are needed
```

This ensures all generated queries follow best practices and are production-ready.

## Resources

> **IMPORTANT: Explicit Reference Consultation**
>
> When generating queries, you SHOULD explicitly read the relevant reference files using the Read tool and cite applicable best practices. This ensures generated queries follow documented patterns and helps users understand why certain approaches are recommended.

### references/

**promql_functions.md**
- Comprehensive reference of all PromQL functions
- Grouped by category (aggregation, math, time, histogram, etc.)
- Usage examples for each function
- **Read this file when**: implementing specific function requirements or when user asks about function behavior

**promql_patterns.md**
- Common query patterns for typical monitoring scenarios
- RED method patterns (Rate, Errors, Duration)
- USE method patterns (Utilization, Saturation, Errors)
- Alerting and recording rule patterns
- **Read this file when**: implementing standard monitoring patterns like error rates, latency, or resource usage

**best_practices.md**
- PromQL best practices and anti-patterns
- Performance optimization guidelines
- Cardinality management
- Query structure recommendations
- **Read this file when**: optimizing queries, reviewing for anti-patterns, or when cardinality concerns arise

**metric_types.md**
- Detailed guide to Prometheus metric types
- Counter, Gauge, Histogram, Summary
- When to use each type
- Appropriate functions for each type
- **Read this file when**: clarifying metric type questions or determining appropriate functions for a metric

### examples/

**common_queries.promql**
- Collection of commonly-used PromQL queries
- Request rate, error rate, latency queries
- Resource usage queries
- Availability and uptime queries
- Can be copied and customized

**red_method.promql**
- Complete RED method implementation
- Request rate queries
- Error rate queries
- Duration/latency queries

**use_method.promql**
- Complete USE method implementation
- Utilization queries
- Saturation queries
- Error queries

**alerting_rules.yaml**
- Example Prometheus alerting rules
- Various threshold-based alerts
- Best practices for alert expressions

**recording_rules.yaml**
- Example Prometheus recording rules
- Pre-aggregated metrics
- Naming conventions

**slo_patterns.promql**
- SLO, error budget, and burn rate queries
- Multi-window, multi-burn-rate alerting patterns
- Latency SLO compliance queries

**kubernetes_patterns.promql**
- Kubernetes monitoring patterns
- kube-state-metrics queries (pods, deployments, nodes)
- cAdvisor container metrics (CPU, memory)
- Vector matching and joins for Kubernetes

## Important Notes

1. **Always Plan Interactively**: Never generate a query without confirming the plan with the user
2. **Use AskUserQuestion**: Leverage the tool to gather requirements and confirm plans
3. **Validate Everything**: Always invoke devops-skills:promql-validator after generation
4. **Educate Users**: Explain what the query does and why it's structured that way
5. **Consider Use Case**: Tailor the query based on whether it's for dashboards, alerts, or analysis
6. **Think About Performance**: Always include label filters and consider cardinality
7. **Follow Metric Types**: Use appropriate functions for counters, gauges, and histograms
8. **Format for Readability**: Use multi-line formatting for complex queries

## Success Criteria

A successful query generation session should:
1. Fully understand the user's monitoring goal
2. Identify correct metrics and their types
3. Present a clear plan in plain English
4. Get user confirmation before generating code
5. Generate a syntactically correct query
6. Use appropriate functions for metric types
7. Include specific label filters
8. Pass devops-skills:promql-validator validation
9. Provide clear usage instructions
10. Offer customization guidance

## Remember

The goal is to **collaboratively plan** and generate PromQL queries that exactly match user intentions. Always prioritize clarity, correctness, and performance. The interactive planning phase is the most important part of this skill—never skip it!