---
name: fluentbit-generator
description: Comprehensive toolkit for generating best practice Fluent Bit configurations. Use this skill when creating new Fluent Bit configs, implementing log collection pipelines (INPUT, FILTER, OUTPUT sections), or building production-ready telemetry configurations.
---

# Fluent Bit Config Generator

## Trigger Guidance

Use this skill when the user asks for any of the following:
- Create or update a Fluent Bit config (`fluent-bit.conf`, `parsers.conf`)
- Build a log pipeline (INPUT -> FILTER -> OUTPUT)
- Configure Kubernetes logging with metadata enrichment
- Send logs/metrics to Elasticsearch, Loki, CloudWatch, S3, Kafka, OTLP, or Prometheus remote write
- Implement parser, multiline, lua, or stream processing behavior

Do not use this skill for pure validation-only requests; use `fluentbit-validator` in that case.

## Execution Flow

Follow this sequence exactly. Do not skip stages.

### Stage 1: Set Working Context and Preflight

Use one of these deterministic command patterns.

```bash
# Option A (recommended): run from this skill directory
cd /Users/akinozer/GolandProjects/cc-devops-skills/devops-skills-plugin/skills/fluentbit-generator
python3 scripts/generate_config.py --help
```

```bash
# Option B: run from any cwd with absolute paths
python3 /Users/akinozer/GolandProjects/cc-devops-skills/devops-skills-plugin/skills/fluentbit-generator/scripts/generate_config.py --help
```

Preflight checks:
- Confirm `python3` is available.
- Confirm script help loads without errors.
- If using relative output paths, run from the intended target cwd.

Fallback:
- If `python3` or script execution is unavailable, switch to manual generation flow (Stage 4) using `examples/` templates.

### Stage 2: Clarification Questionnaire (Explicit Template)

Collect these fields before generation.

Required questions:
1. Primary use case: `kubernetes`, `application logs`, `syslog`, `http ingest`, `metrics`, or `custom`?
2. Inputs: which sources and paths/ports (for example `tail /var/log/containers/*.log`)?
3. Outputs: destination plugin(s) and endpoint(s) (host, port, uri/topic/index/bucket)?
4. Reliability/security requirements: TLS on/off, retry expectations, buffering limits?
5. Environment context: cluster name, environment name, cloud region (if applicable)?

Optional but important:
1. Expected log format: json, regex, cri, docker, multiline stack traces?
2. Throughput profile: low/medium/high and acceptable latency?
3. Constraints: offline environment, missing binaries, read-only filesystem?

If any required answer is missing, ask focused follow-up questions before generating.

### Stage 3: Decide Script vs Manual Generation

Use this decision table.

| Condition | Path |
| --- | --- |
| Request matches a built-in use case and only needs supported flags | Script path (Stage 5) |
| Request needs uncommon plugin options not represented by script flags | Manual path (Stage 4) |
| Complex multi-filter chain, custom parser/lua logic, or specialized plugin tuning | Manual path (Stage 4) |
| Script cannot run in environment (missing Python/permissions) | Manual path (Stage 4) |
| User explicitly requests hand-crafted config | Manual path (Stage 4) |

Supported script use cases:
- `kubernetes-elasticsearch`
- `kubernetes-loki`
- `kubernetes-cloudwatch`
- `kubernetes-opentelemetry`
- `application-multiline`
- `syslog-forward`
- `file-tail-s3`
- `http-kafka`
- `multi-destination`
- `prometheus-metrics`
- `lua-filtering`
- `stream-processor`
- `custom`

Always state the decision explicitly, including why the other path was not used.

### Stage 4: Manual Generation (When Script Is Not the Best Fit)

1. Read the closest template in `examples/` first.
2. Read `examples/parsers.conf` before defining new parsers.
3. Assemble config in this order:
- `[SERVICE]`
- `[INPUT]`
- `[FILTER]`
- `[OUTPUT]`
- parser definitions (if needed)
4. Reuse known-good sections from examples and only customize required parameters.
5. Keep tags and parser references consistent across sections.

Required local template selection:
- Kubernetes + Elasticsearch: `examples/kubernetes-elasticsearch.conf`
- Kubernetes + Loki: `examples/kubernetes-loki.conf`
- Kubernetes + CloudWatch: `examples/cloudwatch.conf`
- Kubernetes + OpenTelemetry: `examples/kubernetes-opentelemetry.conf`
- App multiline: `examples/application-multiline.conf`
- Syslog forward: `examples/syslog-forward.conf`
- File to S3: `examples/file-tail-s3.conf`
- HTTP to Kafka: `examples/http-input-kafka.conf`
- Multi destination: `examples/multi-destination.conf`
- Metrics: `examples/prometheus-metrics.conf`
- Lua filtering: `examples/lua-filtering.conf`
- Stream processor: `examples/stream-processor.conf`
- Parsers: `examples/parsers.conf`

Fallback:
- If no matching example exists, start from `scripts/generate_config.py --use-case custom` output shape and extend manually.

### Stage 5: Script Generation Commands (Deterministic Examples)

Run from skill directory unless output path is absolute.

```bash
cd /Users/akinozer/GolandProjects/cc-devops-skills/devops-skills-plugin/skills/fluentbit-generator

# Kubernetes -> Elasticsearch
python3 scripts/generate_config.py \
  --use-case kubernetes-elasticsearch \
  --cluster-name prod-cluster \
  --environment production \
  --es-host elasticsearch.logging.svc \
  --es-port 9200 \
  --output output/fluent-bit.conf

# Kubernetes -> OpenTelemetry
python3 scripts/generate_config.py \
  --use-case kubernetes-opentelemetry \
  --cluster-name prod-cluster \
  --environment production \
  --otlp-endpoint otel-collector.observability.svc:4318 \
  --output output/fluent-bit-otlp.conf

# File tail -> S3
python3 scripts/generate_config.py \
  --use-case file-tail-s3 \
  --log-path /var/log/app/*.log \
  --s3-bucket my-logs-bucket \
  --s3-region us-east-1 \
  --output output/fluent-bit-s3.conf
```

Fallback:
- If a required option is unsupported by the script, document that gap and switch to Stage 4.

### Stage 6: Plugin Documentation Lookup Fallback Chain

Use this strict order when plugin behavior or parameters are uncertain.

1. Context7 (first choice)
- Resolve library id for Fluent Bit docs.
- Query plugin-specific configuration details.

2. Official Fluent Bit docs (second choice)
- Use `https://docs.fluentbit.io/manual` and plugin-specific pages.
- Prefer official plugin reference sections over blogs.

3. Web search (last choice)
- Use only when Context7 and official docs are unavailable/incomplete.
- Prioritize sources that quote or link official docs.

When to stop escalating:
- Stop as soon as required parameters and one validated example are found.
- If all sources are unavailable, proceed with local `examples/` and clearly mark assumptions.

### Stage 7: Validation and Fallback Behavior

Primary validation path:
- Invoke `fluentbit-validator` after generation.

If validator is unavailable, run local fallback checks:
```bash
# Syntax/format smoke check when fluent-bit is installed
fluent-bit -c <generated-config> --dry-run

# Optional execution test
fluent-bit -c <generated-config>
```

If `fluent-bit` binary is missing:
- Perform static checks manually:
  - section headers are valid (`[SERVICE]`, `[INPUT]`, `[FILTER]`, `[OUTPUT]`)
  - required plugin keys exist
  - tag/match patterns align
  - parser names/files referenced correctly
  - no hardcoded credentials
- Report that runtime validation was skipped and why.

### Stage 8: Response Contract

Always return:
1. Generation path used (`script` or `manual`) and reason.
2. Produced file(s) and key plugin choices.
3. Validation results (or explicit skip reason with fallback checks performed).
4. Assumptions, open risks, and what to customize next.

## Done Criteria

This skill execution is complete only when all are true:
- Trigger fit was explicitly confirmed.
- Clarification questionnaire captured required fields or documented assumptions.
- Script-vs-manual decision was explicit and justified.
- Plugin lookup used deterministic chain: Context7 -> official docs -> web (as needed).
- Commands were provided with cwd-safe examples.
- Fallback behavior was applied for any missing tools/docs/network constraints.
- Validation was executed (or skipped with explicit reason and fallback static checks).
- Final response included generated artifacts, validation outcome, and next customization points.

## Local Resources

- Script: `scripts/generate_config.py`
- Templates: `examples/*.conf`
- Parsers baseline: `examples/parsers.conf`
- Sample output directory: `output/`

Use these resources first before introducing new structure.
