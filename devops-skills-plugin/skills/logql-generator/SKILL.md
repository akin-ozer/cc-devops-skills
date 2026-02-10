---
name: logql-generator
description: Comprehensive toolkit for generating best practice LogQL (Loki Query Language) queries following current standards and conventions. Use this skill when creating new LogQL queries, implementing log analysis dashboards, alerting rules, or troubleshooting with Loki.
---

# LogQL Query Generator

## Overview

Interactive workflow for generating production-ready LogQL queries. LogQL is Grafana Loki's query language—distributed grep with labels for filtering, plus aggregation and metrics capabilities.

## When to Use This Skill

- Creating LogQL queries for log analysis, dashboards, or alerting
- Converting log analysis requirements into LogQL expressions
- Troubleshooting applications through log analysis
- Working with structured logs (JSON, logfmt)

## Interactive Query Planning Workflow

**CRITICAL**: Always engage the user in collaborative planning before generating queries.

### Stage 1: Understand the Goal

Gather requirements using **AskUserQuestion**:

1. **Primary Goal**: Error analysis, performance tracking, security monitoring, debugging, pattern detection?
2. **Use Case**: Dashboard, alerting rule, ad-hoc troubleshooting, metrics generation?
3. **Context**: Application/service, environment, time range, log format?

### Stage 2: Identify Log Sources

1. **Labels**: What labels identify your logs? (`job`, `namespace`, `app`, `level`, `service_name`)
2. **Log Format**: JSON, logfmt, plain text, or custom?
3. **Strategy**: Use labels for stream selection (indexed), line filters for content (not indexed)

### Stage 3: Determine Query Parameters

1. **Query Type**: Log query (return lines) or metric query (calculate values)?
2. **Filtering**: Stream selector `{job="app"}`, line filters `|= "error"`, label filters `| status >= 500`
3. **Parsing**: `| json`, `| logfmt`, `| pattern "<ip> - <user>"`, `| regexp "(?P<field>...)"`
4. **Aggregation**: `count_over_time()`, `rate()`, `sum by (label)`, `quantile_over_time()`
5. **Time Range**: `[5m]`, `[1h]`, `[24h]`

### Stage 4: Present Plan & Confirm

**Before generating code**, present a plain-English plan:

```
## LogQL Query Plan

**Goal**: [Description]
**Query Structure**:
1. Select streams: `{label="value"}`
2. Filter lines: [operations]
3. Parse logs: [parser]
4. Aggregate: [function]

**Does this match your intentions?**
```

Use **AskUserQuestion** to confirm before proceeding.

### Stage 4a: Consult Reference Files (REQUIRED for Complex Queries)

**MANDATORY**: Use the **Read tool** to explicitly read reference files during skill execution. Do NOT rely on prior knowledge or cached information.

**BEFORE generating queries**, when the query involves ANY of the following, you MUST use the Read tool:

| Query Complexity | Action Required |
|------------------|-----------------|
| **Complex aggregations** (nested topk, multiple sum by, percentiles) | `Read examples/common_queries.logql` for verified patterns |
| **Performance-critical queries** (large time ranges, high-volume streams) | `Read references/best_practices.md` sections #1-5, #15-18 |
| **Alerting rules** | `Read references/best_practices.md` sections #19-21, #39 |
| **Structured metadata / Loki 3.x features** | `Read references/best_practices.md` sections #35-37 |
| **Template functions** (line_format, label_format) | `Read examples/common_queries.logql` Template Functions section |
| **IP filtering, pattern extraction, regex** | `Read examples/common_queries.logql` for exact syntax |

**How to consult (MUST use Read tool)**:
```
# Use the Read tool with these paths during skill execution:
Read(".claude/skills/logql-generator/examples/common_queries.logql")   # For query patterns
Read(".claude/skills/logql-generator/references/best_practices.md")    # For optimization and anti-patterns
```

**Example workflow**:
1. User requests alerting rule with topk aggregation
2. **MUST** call: `Read examples/common_queries.logql` to get topk patterns
3. **MUST** call: `Read references/best_practices.md` to get alerting best practices (#19-21, #39)
4. Then generate query using patterns from the files you just read

**Why this matters**: Reference files contain battle-tested patterns and edge cases not covered in the skill overview. Explicit consultation during each skill execution ensures you use the latest patterns and prevents syntax errors.

### Stage 5: Generate Query

#### Best Practices

1. **Specific Stream Selectors**: `{namespace="prod", app="api", level="error"}` not just `{namespace="prod"}`
2. **Filter Order**: Line filter → parse → label filter (fastest to slowest)
3. **Parser Performance**: pattern > logfmt > json > regexp

#### Core Query Patterns

**Log Filtering**:
```logql
{job="app"} |= "error" |= "timeout"        # Contains both
{job="app"} |~ "error|fatal|critical"       # Regex match
{job="app"} != "debug"                      # Exclude
```

**JSON/logfmt Parsing**:
```logql
{app="api"} | json | level="error" | status_code >= 500
{app="app"} | logfmt | caller="database.go"
```

**Pattern Extraction**:
```logql
{job="nginx"} | pattern "<ip> - - [<_>] \"<method> <path>\" <status> <size>"
```

**Metrics**:
```logql
# Rate
rate({job="app"} | json | level="error" [5m])

# Count by label
sum by (app) (count_over_time({namespace="prod"} | json [5m]))

# Error percentage
sum(rate({app="api"} | json | level="error" [5m])) / sum(rate({app="api"}[5m])) * 100

# Latency percentiles
quantile_over_time(0.95, {app="api"} | json | unwrap duration [5m])

# Top N
topk(10, sum by (error_type) (count_over_time({job="app"} | json | level="error" [1h])))
```

**Formatting**:
```logql
{job="app"} | json | line_format "{{.level}}: {{.message}}"
{job="app"} | json | label_format env="{{.environment}}"
```

**IP Filtering** (prefer label filter after parsing for precision):
```logql
{job="nginx"} | logfmt | remote_addr = ip("192.168.4.0/24")
```

### Stage 5a: Incremental Query Building (Educational/Debugging)

**When to use this stage:**
- User is learning LogQL
- Complex multi-stage queries
- Debugging query issues
- User explicitly requests step-by-step explanation

**Present the query construction incrementally:**

```
## Building Your Query Step-by-Step

### Step 1: Stream Selector (verify logs exist)
```logql
{app="api"}
```
*Test this first to confirm logs are flowing*

### Step 2: Add Line Filter (fast pre-filtering)
```logql
{app="api"} |= "error"
```
*Reduces data before parsing*

### Step 3: Add Parser (extract fields)
```logql
{app="api"} |= "error" | json
```
*Now you can filter on extracted labels*

### Step 4: Add Label Filter (precise filtering)
```logql
{app="api"} |= "error" | json | level="error"
```
*Final filter on parsed data*

### Step 5: Add Aggregation (if metric query)
```logql
sum(count_over_time({app="api"} |= "error" | json | level="error" [5m]))
```
*Complete metric query*
```

**Benefits of incremental building:**
1. Identify which step breaks (no results, parse errors)
2. Understand performance impact of each operation
3. Debug unexpected results by testing each stage
4. Learn LogQL query structure naturally

**Use AskUserQuestion** to offer incremental mode:
- Option: "Show step-by-step construction" vs "Show final query only"

### Stage 6: Provide Usage

1. **Final Query** with explanation
2. **How to Use**: Grafana panel, Loki alerting rules, `logcli query`, HTTP API
3. **Customization**: Labels to modify, thresholds to tune

## Advanced Techniques

### Multiple Parsers
```logql
{app="api"} | json | regexp "user_(?P<user_id>\\d+)"
```

### Unwrap for Numeric Metrics
```logql
sum(sum_over_time({app="api"} | json | unwrap duration [5m]))
```

### Pattern Match Operators (Loki 3.0+, 10x faster than regex)
```logql
{service_name=`app`} |> "<_> level=debug <_>"
```

### Logical Operators
```logql
{app="api"} | json | (status_code >= 400 and status_code < 500) or level="error"
```

### Offset Modifier
```logql
sum(rate({app="api"} | json | level="error" [5m])) - sum(rate({app="api"} | json | level="error" [5m] offset 1d))
```

### Label Operations
```logql
{app="api"} | json | keep namespace, pod, level
{app="api"} | json | drop pod, instance
```

> **Note**: LogQL has no `dedup` or `distinct` operators. Use metric aggregations like `sum by (field)` for programmatic deduplication.

## Loki 3.x Key Features

### Structured Metadata
High-cardinality data without indexing (trace_id, user_id, request_id):
```logql
# Filter AFTER stream selector, NOT in it
{app="api"} | trace_id="abc123" | json | level="error"
```

### Query Acceleration (Bloom Filters)
Place structured metadata filters BEFORE parsers:
```logql
# ACCELERATED
{cluster="prod"} | detected_level="error" | logfmt | json
# NOT ACCELERATED
{cluster="prod"} | logfmt | json | detected_level="error"
```

### approx_topk (Probabilistic)
```logql
approx_topk(10, sum by (endpoint) (rate({app="api"}[5m])))
```

### vector() for Alerting
```logql
sum(count_over_time({app="api"} | json | level="error" [5m])) or vector(0)
```

### Automatic Labels
- **service_name**: Auto-populated from container name
- **detected_level**: Auto-detected when `discover_log_levels: true` (stored as structured metadata)

## Function Reference

### Log Range Aggregations
| Function | Description |
|----------|-------------|
| `rate(log-range)` | Entries per second |
| `count_over_time(log-range)` | Count entries |
| `bytes_rate(log-range)` | Bytes per second |
| `absent_over_time(log-range)` | Returns 1 if no logs |

### Unwrapped Range Aggregations
| Function | Description |
|----------|-------------|
| `sum_over_time`, `avg_over_time`, `max_over_time`, `min_over_time` | Aggregate numeric values |
| `quantile_over_time(φ, range)` | φ-quantile (0 ≤ φ ≤ 1) |
| `first_over_time`, `last_over_time` | First/last value |

### Aggregation Operators
`sum`, `avg`, `min`, `max`, `count`, `stddev`, `topk`, `bottomk`, `approx_topk`, `sort`, `sort_desc`

With grouping: `sum by (label1, label2)` or `sum without (label1)`

### Conversion Functions
| Function | Description |
|----------|-------------|
| `duration_seconds(label)` | Convert duration string |
| `bytes(label)` | Convert byte string (KB, MB) |

### label_replace()
```logql
label_replace(rate({job="api"} |= "err" [1m]), "foo", "$1", "service", "(.*):.*")
```

## Parser Reference

### logfmt
```logql
| logfmt [--strict] [--keep-empty]
```
- `--strict`: Error on malformed entries
- `--keep-empty`: Keep standalone keys

### JSON
```logql
| json                                           # All fields
| json method="request.method", status="response.status"  # Specific fields
| json servers[0], headers="request.headers[\"User-Agent\"]"  # Nested/array
```

## Template Functions

Common functions for `line_format` and `label_format`:

**String**: `trim`, `upper`, `lower`, `replace`, `trunc`, `substr`, `printf`, `contains`, `hasPrefix`
**Math**: `add`, `sub`, `mul`, `div`, `addf`, `subf`, `floor`, `ceil`, `round`
**Date**: `date`, `now`, `unixEpoch`, `toDate`, `duration_seconds`
**Regex**: `regexReplaceAll`, `count`
**Other**: `fromJson`, `default`, `int`, `float64`, `__line__`, `__timestamp__`

See `examples/common_queries.logql` for detailed usage.

## Alerting Rules

```logql
# Alert when error rate exceeds 5%
(sum(rate({app="api"} | json | level="error" [5m])) / sum(rate({app="api"}[5m]))) > 0.05

# With vector() to avoid "no data"
sum(rate({app="api"} | json | level="error" [5m])) or vector(0) > 10
```

## Error Handling

| Issue | Solution |
|-------|----------|
| No results | Check labels exist, verify time range, test stream selector alone |
| Query slow | Use specific selectors, filter before parsing, reduce time range |
| Parse errors | Verify log format matches parser, test JSON validity |
| High cardinality | Use line filters not label filters for unique values, aggregate |

## Documentation Lookup

### When to Fetch External Documentation (MANDATORY)

**Trigger context7 MCP or WebSearch when the query involves ANY of these:**

| Trigger | Topic to Search | Tool to Use |
|---------|-----------------|-------------|
| User mentions "Loki 3.x" features | `structured metadata`, `bloom filters`, `detected_level` | context7 MCP |
| `approx_topk` function needed | `approx_topk probabilistic` | context7 MCP |
| Pattern match operators (`\|>`, `!>`) | `pattern match operator` | context7 MCP |
| `vector()` function for alerting | `vector function alerting` | context7 MCP |
| Recording rules configuration | `recording rules loki` | context7 MCP |
| Unclear syntax or edge cases | Specific function or operator | context7 MCP |
| Version-specific behavior questions | Version + feature | WebSearch |
| Grafana Alloy integration | `grafana alloy loki` | WebSearch |

### How to Use

**context7 MCP** (preferred - authoritative docs):
```
1. mcp__context7__resolve-library-id with libraryName="grafana loki"
2. mcp__context7__get-library-docs with context7CompatibleLibraryID and topic="[specific topic]"
```

**WebSearch** (fallback for latest features):
```
WebSearch query: "Grafana Loki LogQL [topic] documentation [year]"
```

### Example Workflow

When user asks for "error tracking with trace correlation in Loki 3.x":
1. Recognize trigger: "Loki 3.x" + "trace" → structured metadata
2. Fetch docs: `mcp__context7__get-library-docs` with topic="structured metadata trace_id"
3. Apply patterns from docs to generate accurate query

## Resources

- **examples/common_queries.logql**: Comprehensive query examples
- **references/best_practices.md**: 39+ LogQL best practices, performance optimization, anti-patterns

## Guidelines

1. **Always plan interactively** - Present plain-English plan before generating
2. **Use AskUserQuestion** - Gather requirements and confirm plans
3. **MUST use Read tool for complex queries** - Explicitly call `Read` on `examples/common_queries.logql` and `references/best_practices.md` during skill execution for alerting rules, topk, percentiles, or performance-critical queries. Do NOT skip this step or rely on prior knowledge.
4. **Fetch docs for advanced features** - Use context7 MCP when Loki 3.x features, approx_topk, or unclear syntax is involved (see Documentation Lookup triggers)
5. **Offer incremental building** - For learning or debugging, present step-by-step query construction (see Stage 5a)
6. **Explain queries** - What it does, how to interpret results
7. **Prioritize performance** - Specific selectors, filter early, simpler parsers

## Version Notes

- **Loki 3.0+**: Bloom filters, structured metadata, pattern match operators (`|>`, `!>`)
- **Loki 3.3+**: `approx_topk` function
- **Loki 3.5+**: Promtail deprecated (use Grafana Alloy)
- **Loki 3.6+**: Horizontally scalable compactor, Loki UI as Grafana plugin

> **Deprecations**: Promtail (use Alloy), BoltDB store (use TSDB with v13 schema)