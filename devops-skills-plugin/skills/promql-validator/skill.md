---
name: promql-validator
description: Comprehensive toolkit for validating, optimizing, and understanding Prometheus Query Language (PromQL) queries. Use this skill when working with PromQL queries to check syntax, detect anti-patterns, identify optimization opportunities, and interactively plan queries with users.
---

## How This Skill Works

This skill performs multi-level validation and provides interactive query planning:

1. **Syntax Validation**: Checks for syntactically correct PromQL expressions
2. **Semantic Validation**: Ensures queries make logical sense (e.g., rate() on counters, not gauges)
3. **Anti-Pattern Detection**: Identifies common mistakes and inefficient patterns
4. **Optimization Suggestions**: Recommends performance improvements
5. **Query Explanation**: Translates PromQL to plain English
6. **Interactive Planning**: Helps users clarify intent and refine queries

## Workflow

When a user provides a PromQL query, follow this workflow:

### Step 1: Validate Syntax

Run the syntax validation script to check for basic correctness:

```bash
python3 .claude/skills/promql-validator/scripts/validate_syntax.py "<query>"
```

The script will check for:
- Valid metric names and label matchers
- Correct operator usage
- Proper function syntax
- Valid time durations and ranges
- Balanced brackets and quotes
- Correct use of modifiers (offset, @)

### Step 2: Check Best Practices

Run the best practices checker to detect anti-patterns and optimization opportunities:

```bash
python3 .claude/skills/promql-validator/scripts/check_best_practices.py "<query>"
```

The script will identify:
- High cardinality queries without label filters
- Inefficient regex matchers that could be exact matches
- Missing rate()/increase() on counter metrics
- rate() used on gauge metrics
- Averaging pre-calculated quantiles
- Subqueries with excessive time ranges
- irate() over long time ranges
- Opportunities to add more specific label filters
- Complex queries that should use recording rules

### Step 3: Explain the Query

Parse and explain what the query does in plain English:
- What metrics are being queried
- What type of metrics they are (counter, gauge, histogram, summary)
- What functions are applied and why
- What the query calculates
- What labels will be in the output
- What the expected result structure looks like

**Required Output Details** (always include these explicitly):

```
**Output Labels**: [list labels that will be in the result, or "None (fully aggregated to scalar)"]
**Expected Result Structure**: [instant vector / range vector / scalar] with [N series / single value]
```

Example:
```
**Output Labels**: job, instance
**Expected Result Structure**: Instant vector with one series per job/instance combination
```

### Step 4: Interactive Query Planning (Phase 1 - STOP AND WAIT)

Ask the user clarifying questions to verify the query matches their intent:

1. **Understand the Goal**: "What are you trying to monitor or measure?"
   - Request rate, error rate, latency, resource usage, etc.

2. **Verify Metric Type**: "Is this a counter (always increasing), gauge (can go up/down), histogram, or summary?"
   - This affects which functions to use

3. **Clarify Time Range**: "What time window do you need?"
   - Instant value, rate over time, historical analysis

4. **Confirm Aggregation**: "Do you need to aggregate data across labels? If so, which labels?"
   - by (job), by (instance), without (pod), etc.

5. **Check Output Intent**: "Are you using this for alerting, dashboarding, or ad-hoc analysis?"
   - Affects optimization priorities

> **IMPORTANT: Two-Phase Dialogue**
>
> After presenting Steps 1-4 results (Syntax, Best Practices, Query Explanation, and Intent Questions):
>
> **⏸️ STOP HERE AND WAIT FOR USER RESPONSE**
>
> Do NOT proceed to Steps 5-7 until the user answers the clarifying questions.
> This ensures the subsequent recommendations are tailored to the user's actual intent.

### Step 5: Compare Intent vs Implementation (Phase 2 - After User Response)

**Only proceed to this step after the user has answered the clarifying questions from Step 4.**

After understanding the user's intent:
- Explain what the current query actually does
- Highlight any mismatches between intent and implementation
- Suggest corrections if the query doesn't match the goal
- Offer alternative approaches if applicable

When relevant, mention known limitations:
- Note when metric type detection is heuristic-based (e.g., "The script inferred this is a gauge based on the `_bytes` suffix. Please confirm if this is correct.")
- Acknowledge when high-cardinality warnings might be false positives (e.g., "This warning may not apply if you're using a recording rule or know your cardinality is low.")

### Step 6: Offer Optimizations

Based on validation results:
- Suggest more efficient query patterns
- Recommend recording rules for complex/repeated queries
- Propose better label matchers to reduce cardinality
- Advise on appropriate time ranges

**Reference Examples**: When suggesting corrections, cite relevant examples using this format:

```
As shown in `examples/bad_queries.promql` (lines 91-97):
❌ BAD: `avg(http_request_duration_seconds{quantile="0.95"})`
✅ GOOD: Use histogram_quantile() with histogram buckets
```

Citation sources:
- `examples/good_queries.promql` - for well-formed patterns
- `examples/optimization_examples.promql` - for before/after comparisons
- `examples/bad_queries.promql` - for showing what to avoid
- `docs/best_practices.md` - for detailed explanations
- `docs/anti_patterns.md` - for anti-pattern deep dives

**Citation Format**: `file_path (lines X-Y)` with the relevant code snippet quoted

### Step 7: Let User Plan/Refine

Give the user control:
- Ask if they want to modify the query
- Offer to help rewrite it for better performance
- Provide multiple alternatives if applicable
- Explain trade-offs between different approaches

## Key Validation Rules

### Syntax Rules

1. **Metric Names**: Must match `[a-zA-Z_:][a-zA-Z0-9_:]*` or use UTF-8 quoting syntax (Prometheus 3.0+):
   - Quoted form: `{"my.metric.with.dots"}`
   - Using __name__ label: `{__name__="my.metric.with.dots"}`
2. **Label Matchers**: `=` (equal), `!=` (not equal), `=~` (regex match), `!~` (regex not match)
3. **Time Durations**: `[0-9]+(ms|s|m|h|d|w|y)` - e.g., `5m`, `1h`, `7d`
4. **Range Vectors**: `metric_name[duration]` - e.g., `http_requests_total[5m]`
5. **Offset Modifier**: `offset <duration>` - e.g., `metric_name offset 5m`
6. **@ Modifier**: `@ <timestamp>` or `@ start()` / `@ end()`

### Semantic Rules

1. **rate() and irate()**: Should only be used with counter metrics (metrics ending in `_total`, `_count`, `_sum`, or `_bucket`)
2. **Counters**: Should typically use `rate()` or `increase()`, not raw values
3. **Gauges**: Should not use `rate()` or `increase()`
4. **Histograms**: Use `histogram_quantile()` with `le` label and `rate()` on `_bucket` metrics
5. **Summaries**: Don't average quantiles; calculate from `_sum` and `_count`
6. **Aggregations**: Use `by()` or `without()` to control output labels

### Performance Rules

1. **Cardinality**: Always use specific label matchers to reduce series count
2. **Regex**: Use `=` instead of `=~` when possible for exact matches
3. **Rate Range**: Should be at least 4x the scrape interval (typically `[2m]` minimum)
4. **irate()**: Best for short ranges (<5m); use `rate()` for longer periods
5. **Subqueries**: Avoid excessive time ranges that process millions of samples
6. **Recording Rules**: Use for complex queries accessed frequently

## Anti-Patterns to Detect

### High Cardinality Issues

❌ **Bad**: `http_requests_total{}`
- Matches all time series without filtering

✅ **Good**: `http_requests_total{job="api", instance="prod-1"}`
- Specific label filters reduce cardinality

### Regex Overuse

❌ **Bad**: `http_requests_total{status=~"2.."}`
- Regex is slower and less precise

✅ **Good**: `http_requests_total{status="200"}`
- Exact match is faster

### Missing rate() on Counters

❌ **Bad**: `http_requests_total`
- Counter raw values are not useful (always increasing)

✅ **Good**: `rate(http_requests_total[5m])`
- Rate shows requests per second

### rate() on Gauges

❌ **Bad**: `rate(memory_usage_bytes[5m])`
- Gauges measure current state, not cumulative values

✅ **Good**: `memory_usage_bytes`
- Use gauge value directly or with `avg_over_time()`

### Averaging Quantiles

❌ **Bad**: `avg(http_request_duration_seconds{quantile="0.95"})`
- Mathematically invalid to average pre-calculated quantiles

✅ **Good**: `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))`
- Calculate quantile from histogram buckets

### Excessive Subquery Ranges

❌ **Bad**: `rate(metric[5m])[90d:1m]`
- Processes millions of samples, very slow

✅ **Good**: Use recording rules or limit range to necessary duration

### irate() Over Long Ranges

❌ **Bad**: `irate(metric[1h])`
- irate() only looks at last two samples, range is wasted

✅ **Good**: `rate(metric[1h])` or `irate(metric[5m])`
- Use rate() for longer ranges or reduce irate() range

### Mixed Metric Types

❌ **Bad**: `avg(http_request_duration_seconds{quantile="0.95"}) / rate(node_memory_usage_bytes[1h]) + sum(http_requests_total)`
- Combines summary quantiles, gauge metrics, and counters in arithmetic
- Produces meaningless results

✅ **Good**: Keep each metric type in separate, purpose-specific queries:
- Latency: `histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))`
- Memory: `node_memory_usage_bytes{instance="prod-1"}`
- Request rate: `rate(http_requests_total{job="api"}[5m])`

## Output Format

Provide validation results in this structure:

```
## PromQL Validation Results

### Syntax Check
- Status: ✅ VALID / ⚠️ WARNING / ❌ ERROR
- Issues: [list any syntax errors with line/position]

### Semantic Check
- Status: ✅ VALID / ⚠️ WARNING / ❌ ERROR
- Issues: [list any logical problems]

### Performance Analysis
- Status: ✅ OPTIMIZED / ⚠️ CAN BE IMPROVED / ❌ INEFFICIENT
- Issues: [list optimization opportunities]
- Suggestions: [specific improvements]

### Query Explanation
Your query: `<query>`

This query does:
- [Plain English explanation]
- Metrics: [list metrics and their types]
- Functions: [explain each function]
- Output: [describe result structure]

### Intent Verification
Let me verify this matches your needs:

1. What are you trying to measure? [your goal here]
2. Is this a counter/gauge/histogram/summary? [metric type]
3. What time range interests you? [time window]
4. Do you need aggregation? If so, by which labels? [aggregation needs]
5. Is this for alerting, dashboarding, or analysis? [use case]

### Recommendations
[Based on the analysis, suggest improvements or alternatives]
```

## Interactive Dialogue

After validation, engage in dialogue:

**Claude**: "I've validated your query. It's syntactically correct, but I notice it queries `http_requests_total` without any label filters. This could match thousands of time series. What specific service or endpoint are you trying to monitor?"

**User**: [provides intent]

**Claude**: "Great! Based on that, here's an optimized version: `rate(http_requests_total{job="api-service", path="/users"}[5m])`. This calculates the per-second rate of requests to the /users endpoint over the last 5 minutes. Does this match what you need?"

**User**: [confirms or asks for changes]

**Claude**: [provides refined query or alternatives]

## Examples

See the `examples/` directory for:
- `good_queries.promql`: Well-written queries following best practices
- `bad_queries.promql`: Common mistakes and anti-patterns (with corrections)
- `optimization_examples.promql`: Before/after optimization examples

## Documentation

See the `docs/` directory for:
- `best_practices.md`: Comprehensive PromQL best practices guide
- `anti_patterns.md`: Detailed anti-pattern reference with explanations

## Important Notes

1. **Be Interactive**: Always ask clarifying questions to understand user intent
2. **Be Educational**: Explain WHY something is wrong, not just THAT it's wrong
3. **Be Helpful**: Offer to rewrite queries, don't just criticize
4. **Be Context-Aware**: Consider the user's use case (alerting vs dashboarding)
5. **Be Thorough**: Check all four levels (syntax, semantics, performance, intent)
6. **Be Practical**: Suggest realistic optimizations, not theoretical perfection

## Integration

This skill can be used:
- Standalone for query review
- During monitoring setup to validate alert rules
- When troubleshooting slow Prometheus queries
- As part of code review for recording rules
- For teaching PromQL to team members

## Validation Tools

The skill uses two main Python scripts:

1. **validate_syntax.py**: Pure syntax checking using regex patterns
2. **check_best_practices.py**: Semantic and performance analysis

Both scripts output JSON for programmatic parsing and human-readable messages for display.

## Success Criteria

A successful validation session should:
1. Identify all syntax errors
2. Detect semantic problems
3. Suggest at least one optimization (if applicable)
4. Clearly explain what the query does
5. Verify the query matches user intent
6. Provide actionable next steps

## Known Limitations

The validation scripts have some limitations to be aware of:

### Metric Type Detection
- **Heuristic-based**: Metric types (counter, gauge, histogram, summary) are inferred from naming conventions (e.g., `_total`, `_bytes`)
- **Custom metrics**: Metrics with non-standard names may not be correctly classified
- **Recommendation**: When the script can't determine metric type, ask the user to clarify

### High Cardinality Detection
- **Conservative approach**: The script flags metrics without label selectors, but some use cases legitimately query all series
- **Recording rules**: Queries using recording rule metrics (e.g., `job:http_requests:rate5m`) are valid without label filters
- **Recommendation**: Use judgment - if the user knows their cardinality is manageable, the warning can be safely ignored

### Semantic Validation
- **No runtime context**: The scripts cannot verify if metrics actually exist or if label values are valid
- **Schema-agnostic**: No knowledge of specific Prometheus deployments or metric schemas
- **Recommendation**: For production validation, test queries against actual Prometheus instances

### Script Detection Coverage
The scripts detect common anti-patterns but cannot catch:
- Business logic errors (e.g., calculating the wrong KPI)
- Context-specific optimizations (depends on scrape interval, retention, etc.)
- Custom function behavior from extensions

## Remember

The goal is not just to validate queries, but to help users write better PromQL and understand their monitoring data. Always be educational, interactive, and helpful!