---
name: fluentbit-generator
description: Comprehensive toolkit for generating best practice Fluent Bit configurations. Use this skill when creating new Fluent Bit configs, implementing log collection pipelines (INPUT, FILTER, OUTPUT sections), or building production-ready telemetry configurations.
---

# Fluent Bit Config Generator

## Overview

This skill provides a comprehensive workflow for generating production-ready Fluent Bit configurations with best practices built-in. Generate complete pipelines or individual sections (SERVICE, INPUT, FILTER, OUTPUT, PARSER) with proper syntax, optimal performance settings, and automatic validation.

Fluent Bit is a fast and lightweight telemetry agent for logs, metrics, and traces. It's part of the CNCF (Cloud Native Computing Foundation) and is commonly used in Kubernetes environments for log aggregation, forwarding, and processing.

## When to Use This Skill

Invoke this skill when:
- Creating new Fluent Bit configurations from scratch
- Implementing log collection pipelines (INPUT → FILTER → OUTPUT)
- Configuring Kubernetes log collection with metadata enrichment
- Setting up log forwarding to destinations (Elasticsearch, Loki, S3, Kafka, CloudWatch, etc.)
- Building multi-line log parsing for stack traces
- Converting existing logging configurations to Fluent Bit
- Implementing custom parsers for structured logging
- Working with Fluent Bit plugins that require documentation lookup
- The user asks to "create", "generate", "build", or "configure" Fluent Bit configs
- Setting up telemetry pipelines with filters and transformations

## Configuration Generation Workflow

Follow this workflow when generating Fluent Bit configurations. Adapt based on user needs:

### Stage 1: Understand Requirements

Gather information about the logging infrastructure needs:

1. **Use case identification:**
   - Kubernetes log collection (DaemonSet deployment)
   - Application log forwarding
   - System log collection (syslog, systemd)
   - Multi-line log parsing (stack traces, JSON logs)
   - Log aggregation from multiple sources
   - Metrics collection and forwarding

2. **Input sources:**
   - tail (file tailing)
   - systemd (systemd journal)
   - tcp/udp (network input)
   - forward (Fluent protocol)
   - http (HTTP endpoint)
   - kubernetes (K8s pod logs)
   - docker (Docker container logs)
   - syslog
   - exec (command execution)

3. **Processing requirements:**
   - Parsing (JSON, regex, logfmt)
   - Multi-line handling (stack traces)
   - Filtering (grep, modify, lua)
   - Enrichment (Kubernetes metadata)
   - Transformation (nest, rewrite_tag)
   - Throttling (rate limiting)

4. **Output destinations:**
   - Elasticsearch
   - Grafana Loki
   - AWS S3/CloudWatch
   - Kafka
   - HTTP endpoint
   - File
   - stdout (debugging)
   - forward (Fluent protocol)
   - Prometheus remote write

5. **Performance and reliability:**
   - Buffer limits (memory constraints)
   - Flush intervals
   - Retry logic
   - TLS/SSL requirements
   - Worker threads (parallelism)

Use AskUserQuestion if information is missing or unclear.

### Script vs Manual Generation

**Step 1: Always verify script capabilities first:**

```bash
# REQUIRED: Run --help to check if your use case is supported
python3 scripts/generate_config.py --help
```

**Step 2: For supported use cases, prefer using `generate_config.py`** for consistency and tested templates:

```bash
# Generate configuration for a supported use case
python3 scripts/generate_config.py --use-case kubernetes-elasticsearch --output fluent-bit.conf
python3 scripts/generate_config.py --use-case kubernetes-opentelemetry --cluster-name my-cluster --output fluent-bit.conf
```

**Supported use cases:** kubernetes-elasticsearch, kubernetes-loki, kubernetes-cloudwatch, kubernetes-opentelemetry, application-multiline, syslog-forward, file-tail-s3, http-kafka, multi-destination, prometheus-metrics, lua-filtering, stream-processor, custom.

**Step 3: Use manual generation (Stages 3-8)** when:
- The use case is not supported by the script (verified via `--help`)
- Custom plugins or complex filter chains are required (e.g., grep filtering for log levels)
- Non-standard configurations are needed
- The user explicitly requests manual configuration

**Document your decision:** When choosing manual generation, explicitly state why the script was not suitable (e.g., "Manual generation chosen because grep filter for log levels is not supported by the script").

### Consulting Examples Before Manual Generation

**REQUIRED before writing any manual configuration:**

1. **Identify the closest matching example** from the `examples/` directory:
   - For Kubernetes + Elasticsearch: Read `examples/kubernetes-elasticsearch.conf`
   - For Kubernetes + Loki: Read `examples/kubernetes-loki.conf`
   - For Kubernetes + OpenTelemetry: Read `examples/kubernetes-opentelemetry.conf`
   - For application logs with multiline: Read `examples/application-multiline.conf`
   - For syslog forwarding: Read `examples/syslog-forward.conf`
   - For S3 output: Read `examples/file-tail-s3.conf`
   - For Kafka output: Read `examples/http-input-kafka.conf`
   - For multi-destination: Read `examples/multi-destination.conf`
   - For Prometheus metrics: Read `examples/prometheus-metrics.conf`
   - For Lua filtering: Read `examples/lua-filtering.conf`
   - For stream processing: Read `examples/stream-processor.conf`
   - For production setup: Read `examples/full-production.conf`

2. **Read the example file** using the Read tool to understand:
   - Section structure and ordering
   - Parameter values and best practices
   - Comments and documentation style

3. **Read `examples/parsers.conf`** for parser definitions - reuse existing parsers rather than recreating them.

4. **Use examples as templates** - copy relevant sections and customize for the user's requirements.

### Stage 2: Plugin Documentation Lookup (if applicable)

If the configuration requires specific plugins or custom output destinations:

1. **Identify plugins needing documentation:**
   - Custom output plugins (proprietary systems)
   - Less common input plugins
   - Complex filter configurations
   - Parser patterns for specific log formats
   - Cloud provider integrations (AWS, GCP, Azure)

2. **Try context7 MCP first (preferred):**
   ```
   Use mcp__context7__resolve-library-id with "fluent-bit" or "fluent/fluent-bit"
   Then use mcp__context7__get-library-docs with:
   - context7CompatibleLibraryID: /fluent/fluent-bit-docs (or /fluent/fluent-bit)
   - topic: The plugin name and configuration (e.g., "elasticsearch output configuration")
   - page: 1 (fetch additional pages if needed)
   ```

3. **Fallback to WebSearch if context7 fails:**
   ```
   Search query patterns:
   "fluent-bit" "<plugin-type>" "<plugin-name>" "configuration" "parameters" site:docs.fluentbit.io

   Examples:
   "fluent-bit" "output" "elasticsearch" "configuration" site:docs.fluentbit.io
   "fluent-bit" "filter" "kubernetes" "configuration" site:docs.fluentbit.io
   "fluent-bit" "parser" "multiline" "configuration" site:docs.fluentbit.io
   ```

4. **Extract key information:**
   - Required parameters
   - Optional parameters and defaults
   - Configuration examples
   - Performance tuning options
   - Common pitfalls and best practices

### Stage 3: SERVICE Section Configuration

**ALWAYS start with the SERVICE section** - this defines global behavior:

```ini
[SERVICE]
    # Flush interval in seconds - how often to flush data to outputs
    # Lower values = lower latency, higher CPU usage
    # Recommended: 1-5 seconds for most use cases
    Flush        1

    # Daemon mode - run as background process (Off in containers)
    Daemon       Off

    # Log level: off, error, warn, info, debug, trace
    # Recommended: info for production, debug for troubleshooting
    Log_Level    info

    # Optional: Write Fluent Bit's own logs to file
    # Log_File     /var/log/fluent-bit.log

    # Parser configuration file (if using custom parsers)
    Parsers_File parsers.conf

    # Enable built-in HTTP server for metrics and health checks
    # Recommended for Kubernetes liveness/readiness probes
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_Port    2020

    # Enable storage metrics endpoint
    storage.metrics on

    # Number of worker threads (0 = auto-detect CPU cores)
    # Increase for high-volume environments
    # workers      0
```

**Key SERVICE parameters:**

- **Flush** (1-5 sec): Lower for real-time, higher for batching efficiency
- **Log_Level**: Use `info` in production, `debug` for troubleshooting
- **HTTP_Server**: Enable for health checks and metrics
- **Parsers_File**: Reference external parser definitions
- **storage.metrics**: Enable for monitoring buffer/storage metrics

### Stage 4: INPUT Section Configuration

Create INPUT sections for data sources. Common patterns:

#### Kubernetes Pod Logs (DaemonSet)

```ini
[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    # Exclude Fluent Bit's own logs to prevent loops
    Exclude_Path      /var/log/containers/*fluent-bit*.log
    Parser            docker
    DB                /var/log/flb_kube.db
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On
    Refresh_Interval  10
    Read_from_Head    Off
```

**Key INPUT patterns:**

1. **tail plugin** (most common):
   - `Path`: File path or wildcard pattern
   - `Tag`: Routing tag for filters/outputs
   - `Parser`: Pre-parser for log format (docker, cri, json)
   - `DB`: Position database for crash recovery
   - `Mem_Buf_Limit`: Per-input memory limit (prevents OOM)
   - `Skip_Long_Lines`: Skip lines > 32KB (prevents hang)
   - `Read_from_Head`: Start from beginning (false for new logs only)

2. **systemd plugin**:
```ini
[INPUT]
    Name              systemd
    Tag               host.*
    Systemd_Filter    _SYSTEMD_UNIT=kubelet.service
    Read_From_Tail    On
```

3. **http plugin** (webhook receiver):
```ini
[INPUT]
    Name          http
    Tag           app.logs
    Listen        0.0.0.0
    Port          9880
    Buffer_Size   32KB
```

4. **forward plugin** (Fluent protocol):
```ini
[INPUT]
    Name          forward
    Tag           forward.*
    Listen        0.0.0.0
    Port          24224
```

**Best practices for INPUT:**
- Always set `Mem_Buf_Limit` to prevent memory issues
- Use `DB` for tail inputs to track file positions
- Set appropriate `Tag` patterns for routing
- Use `Exclude_Path` to prevent log loops
- Enable `Skip_Long_Lines` for robustness

### Stage 5: FILTER Section Configuration

Create FILTER sections for log processing and enrichment:

#### Kubernetes Metadata Enrichment

```ini
[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Keep_Log            Off
    K8S-Logging.Parser  On
    K8S-Logging.Exclude On
    Labels              On
    Annotations         Off
    Buffer_Size         0
```

**Key FILTER patterns:**

1. **kubernetes filter** (metadata enrichment):
   - `Merge_Log`: Parse JSON logs into structured fields
   - `Keep_Log`: Keep original log field (Off saves space)
   - `K8S-Logging.Parser`: Honor pod parser annotations
   - `K8S-Logging.Exclude`: Honor pod exclude annotations
   - `Labels`: Include pod labels in output
   - `Annotations`: Include pod annotations (optional, increases size)

2. **parser filter** (structured parsing):
```ini
[FILTER]
    Name          parser
    Match         *
    Key_Name      log
    Parser        json
    Reserve_Data  On
    Preserve_Key  Off
```

3. **grep filter** (include/exclude):
```ini
[FILTER]
    Name          grep
    Match         *
    # Include only error logs
    Regex         level (error|fatal|critical)
    # Exclude health check logs
    Exclude       path /health
```

4. **modify filter** (add/remove fields):
```ini
[FILTER]
    Name          modify
    Match         *
    Add           cluster_name production
    Add           environment prod
    Remove        _p
```

5. **nest filter** (restructure):
```ini
[FILTER]
    Name          nest
    Match         *
    Operation     lift
    Nested_under  kubernetes
    Add_prefix    k8s_
```

6. **multiline filter** (stack traces):
```ini
[FILTER]
    Name          multiline
    Match         *
    multiline.key_content log
    multiline.parser      java, python, go
```

7. **throttle filter** (rate limiting):
```ini
[FILTER]
    Name          throttle
    Match         *
    Rate          1000
    Window        5
    Interval      1m
```

8. **lua filter** (custom scripting):
```ini
[FILTER]
    Name    lua
    Match   *
    script  /fluent-bit/scripts/filter.lua
    call    process_record
```

Example Lua script (`/fluent-bit/scripts/filter.lua`):
```lua
function process_record(tag, timestamp, record)
    -- Add custom field
    record["custom_field"] = "custom_value"

    -- Transform existing field
    if record["level"] then
        record["severity"] = string.upper(record["level"])
    end

    -- Filter out specific records (return -1 to drop)
    if record["message"] and string.match(record["message"], "DEBUG") then
        return -1, timestamp, record
    end

    -- Return modified record
    return 1, timestamp, record
end
```

**Best practices for FILTER:**
- Order matters: parsers before modifiers
- Use `Kubernetes` filter in K8s environments for enrichment
- Parse JSON logs early to enable field-based filtering
- Add cluster/environment identifiers for multi-cluster setups
- Use `grep` to reduce data volume early in pipeline
- Implement throttling to prevent downstream overload

### Stage 6: OUTPUT Section Configuration

Create OUTPUT sections for destination systems:

#### Elasticsearch

```ini
[OUTPUT]
    Name              es
    Match             *
    Host              elasticsearch.default.svc
    Port              9200
    # Index pattern with date
    Logstash_Format   On
    Logstash_Prefix   fluent-bit
    Retry_Limit       3
    # Buffer configuration
    storage.total_limit_size 5M
    # TLS configuration
    tls               On
    tls.verify        Off
    # Authentication
    HTTP_User         ${ES_USER}
    HTTP_Passwd       ${ES_PASSWORD}
    # Performance tuning
    Buffer_Size       False
    Type              _doc
```

#### Grafana Loki

```ini
[OUTPUT]
    Name              loki
    Match             *
    Host              loki.default.svc
    Port              3100
    # Label extraction from metadata
    labels            job=fluent-bit, namespace=$kubernetes['namespace_name'], pod=$kubernetes['pod_name'], container=$kubernetes['container_name']
    label_keys        $stream
    # Remove Kubernetes metadata to reduce payload size
    remove_keys       kubernetes,stream
    # Auto Kubernetes labels
    auto_kubernetes_labels on
    # Line format
    line_format       json
    # Retry configuration
    Retry_Limit       3
```

#### AWS S3

```ini
[OUTPUT]
    Name              s3
    Match             *
    bucket            my-logs-bucket
    region            us-east-1
    total_file_size   100M
    upload_timeout    10m
    use_put_object    Off
    # Compression
    compression       gzip
    # Path structure with time formatting
    s3_key_format     /fluent-bit-logs/%Y/%m/%d/$TAG[0]/%H-%M-%S-$UUID.gz
    # IAM role authentication (recommended)
    # Or use AWS credentials
    # AWS credentials loaded from environment or IAM role
    Retry_Limit       3
```

#### Kafka

```ini
[OUTPUT]
    Name              kafka
    Match             *
    Brokers           kafka-broker-1:9092,kafka-broker-2:9092
    Topics            logs
    # Message format
    Format            json
    # Timestamp key
    Timestamp_Key     @timestamp
    # Retry configuration
    Retry_Limit       3
    # Queue configuration
    rdkafka.queue.buffering.max.messages     100000
    rdkafka.request.required.acks            1
```

#### AWS CloudWatch Logs

```ini
[OUTPUT]
    Name              cloudwatch_logs
    Match             *
    region            us-east-1
    log_group_name    /aws/fluent-bit/logs
    log_stream_prefix from-fluent-bit-
    auto_create_group On
    Retry_Limit       3
```

#### OpenTelemetry (OTLP)

```ini
[OUTPUT]
    Name                 opentelemetry
    Match                *
    Host                 opentelemetry-collector.observability.svc
    Port                 4318
    # Use HTTP protocol for OTLP
    logs_uri             /v1/logs
    # Add resource attributes
    add_label            cluster my-cluster
    add_label            environment production
    # TLS configuration
    tls                  On
    tls.verify           Off
    # Retry configuration
    Retry_Limit          3
```

#### Prometheus Remote Write

```ini
[OUTPUT]
    Name              prometheus_remote_write
    Match             *
    Host              prometheus.monitoring.svc
    Port              9090
    Uri               /api/v1/write
    # Add labels to all metrics
    add_label         cluster my-cluster
    add_label         environment production
    # TLS configuration
    tls               On
    tls.verify        Off
    # Retry configuration
    Retry_Limit       3
    # Compression
    compression       snappy
```

#### HTTP Endpoint

```ini
[OUTPUT]
    Name              http
    Match             *
    Host              logs.example.com
    Port              443
    URI               /api/logs
    Format            json
    # TLS
    tls               On
    tls.verify        On
    # Authentication
    Header            Authorization Bearer ${API_TOKEN}
    # Compression
    Compress          gzip
    # Retry configuration
    Retry_Limit       3
```

#### stdout (debugging)

```ini
[OUTPUT]
    Name              stdout
    Match             *
    Format            json_lines
```

**Key OUTPUT patterns:**

1. **Common parameters:**
   - `Name`: Output plugin name
   - `Match`: Tag pattern to match (supports wildcards)
   - `Retry_Limit`: Number of retries (0 = infinite)
   - `storage.total_limit_size`: Disk buffer limit

2. **Buffer and retry configuration:**
   ```ini
   # Memory buffering (default)
   storage.type      memory

   # Filesystem buffering (for high reliability)
   storage.type      filesystem
   storage.path      /var/log/fluent-bit-buffer/
   storage.total_limit_size 10G

   # Retry configuration
   Retry_Limit       5
   ```

3. **TLS configuration:**
   ```ini
   tls               On
   tls.verify        On
   tls.ca_file       /path/to/ca.crt
   tls.crt_file      /path/to/client.crt
   tls.key_file      /path/to/client.key
   ```

**Best practices for OUTPUT:**
- Always set `Retry_Limit` (3-5 for most cases)
- Use environment variables for credentials: `${ENV_VAR}`
- Enable TLS for production
- Set `storage.total_limit_size` to prevent disk exhaustion
- Use compression when available (gzip)
- For Kubernetes: use service DNS names
- Add multiple outputs for redundancy if needed

### Stage 7: PARSER Section Configuration

**IMPORTANT: Always check `examples/parsers.conf` first** before creating custom parsers. The examples directory contains production-ready parser definitions for common use cases.

**Step 1: Read the existing parsers file:**
```bash
# Read the examples/parsers.conf file to see available parsers
Read examples/parsers.conf
```

**Step 2: Reuse existing parsers when possible.** The `examples/parsers.conf` includes:
- `docker` - Docker JSON log format
- `json` - Generic JSON logs
- `cri` - CRI container runtime format
- `syslog-rfc3164` - Syslog RFC 3164
- `syslog-rfc5424` - Syslog RFC 5424
- `nginx` - Nginx access logs
- `apache` - Apache access logs
- `apache_error` - Apache error logs
- `mongodb` - MongoDB logs
- `multiline-java` - Java stack traces
- `multiline-python` - Python tracebacks
- `multiline-go` - Go panic traces
- `multiline-ruby` - Ruby exceptions

**Step 3: Only create custom parsers** when the existing ones don't match your log format.

**Example custom parser definition (only if needed):**

```ini
# parsers.conf - Add custom parsers alongside existing ones

[PARSER]
    Name        custom-app
    Format      regex
    Regex       ^(?<timestamp>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) \[(?<level>\w+)\] (?<message>.*)$
    Time_Key    timestamp
    Time_Format %Y-%m-%d %H:%M:%S
```

**Parser types:**

1. **JSON**: For JSON-formatted logs
2. **Regex**: For custom log formats
3. **LTSV**: For LTSV (Labeled Tab-Separated Values)
4. **Logfmt**: For logfmt format
5. **MULTILINE_PARSER**: For multi-line logs (stack traces)

**Best practices for PARSER:**
- **Reuse `examples/parsers.conf`** - copy and extend rather than recreating from scratch
- Use built-in parsers when possible (docker, cri, json)
- Test regex patterns thoroughly
- Set `Time_Key` and `Time_Format` for proper timestamps
- Use `MULTILINE_PARSER` for stack traces
- Reference parsers file in SERVICE section

### Stage 8: Complete Configuration Structure

A production-ready Fluent Bit configuration follows this structure:

```
fluent-bit.conf          # Main configuration file
parsers.conf             # Custom parser definitions (optional)
```

**Before writing a new configuration, consult the `examples/` directory** for production-ready templates:
- Review `examples/` files that match your use case
- Use them as starting points and customize as needed
- Reference `examples/parsers.conf` for parser definitions

**Example complete configuration (Kubernetes to Elasticsearch):**

```ini
# fluent-bit.conf

[SERVICE]
    Flush         1
    Daemon        Off
    Log_Level     info
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020
    storage.metrics on

[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    Exclude_Path      /var/log/containers/*fluent-bit*.log
    Parser            docker
    DB                /var/log/flb_kube.db
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On
    Refresh_Interval  10

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Keep_Log            Off
    K8S-Logging.Parser  On
    K8S-Logging.Exclude On
    Labels              On
    Annotations         Off

[FILTER]
    Name          modify
    Match         *
    Add           cluster_name my-cluster
    Add           environment production

[FILTER]
    Name          nest
    Match         *
    Operation     lift
    Nested_under  kubernetes

[OUTPUT]
    Name              es
    Match             *
    Host              elasticsearch.logging.svc
    Port              9200
    Logstash_Format   On
    Logstash_Prefix   k8s
    Retry_Limit       3
    storage.total_limit_size 5M
    tls               On
    tls.verify        Off
```

### Stage 9: Best Practices and Optimization

Apply these best practices to all generated configurations:

#### Performance Optimization

1. **Buffer management:**
   - Set `Mem_Buf_Limit` on inputs (default 32MB can cause OOM)
   - Use `storage.type filesystem` for high-reliability scenarios
   - Set `storage.total_limit_size` to prevent disk exhaustion
   - Recommended: 50-100MB per input, 5-10GB total disk buffer

2. **Flush and batching:**
   - `Flush 1-5`: Balance between latency and efficiency
   - Lower flush = lower latency, higher CPU/network
   - Higher flush = better batching, higher memory usage

3. **Worker threads:**
   - Default (0) auto-detects CPU cores
   - Increase for high-volume environments
   - Monitor CPU usage before adjusting

4. **Compression:**
   - Enable compression for network outputs (gzip)
   - Reduces bandwidth by 70-90%
   - Slight CPU overhead

#### Reliability

1. **Retry logic:**
   - Set `Retry_Limit 3-5` on all outputs
   - Use filesystem buffering for critical logs
   - Consider multiple outputs for redundancy

2. **Health checks:**
   - Enable `HTTP_Server` for liveness/readiness probes
   - Expose port 2020 (standard)
   - Kubernetes probes: GET http://localhost:2020/api/v1/health

3. **Database files:**
   - Use `DB` parameter for tail inputs
   - Enables position tracking across restarts
   - Store in persistent volume in Kubernetes

#### Security

1. **TLS/SSL:**
   - Always enable TLS in production (`tls On`)
   - **Default to `tls.verify On`** for production deployments
   - Use `tls.verify Off` ONLY in these scenarios:
     - Internal Kubernetes cluster traffic with self-signed certificates
     - Development/testing environments
     - When proper CA certificates are not available (add comment explaining why)
   - When using `tls.verify Off`, always add a comment explaining the reason:
     ```ini
     tls               On
     tls.verify        Off  # Internal cluster with self-signed certs
     ```
   - Use environment variables for credentials

2. **Credentials:**
   - Never hardcode passwords
   - Use environment variables: `${VAR_NAME}`
   - Or Kubernetes secrets mounted as env vars

3. **RBAC (Kubernetes):**
   - Grant minimal permissions to ServiceAccount
   - Only needs read access to pods/namespaces
   - No write permissions required

#### Resource Limits

1. **Memory:**
   - Set per-input limits: `Mem_Buf_Limit 50MB`
   - Kubernetes limits: 200-500MB for typical DaemonSet
   - Monitor actual usage and adjust

2. **CPU:**
   - Typically low CPU usage (5-50m per node)
   - Spikes during log bursts
   - Set requests/limits based on workload

3. **Disk:**
   - For filesystem buffering only
   - Recommended: 5-10GB per node
   - Monitor with `storage.metrics on`

#### Logging Best Practices

1. **Structured logging:**
   - Prefer JSON logs in applications
   - Easier parsing and querying
   - Better performance than regex

2. **Log levels:**
   - Use appropriate log levels in apps
   - Filter noisy logs with grep filter
   - Reduce volume = lower costs

3. **Avoid log loops:**
   - Exclude Fluent Bit's own logs
   - Use `Exclude_Path` pattern
   - Tag filtering if needed

### Stage 10: Validate Generated Configuration

**ALWAYS validate the generated configuration** using the devops-skills:fluentbit-validator skill:

```
Invoke the devops-skills:fluentbit-validator skill to validate the config:
1. Syntax validation (section format, key-value pairs)
2. Required field checks
3. Plugin parameter validation
4. Tag consistency checks
5. Parser reference validation
6. Security checks (plaintext passwords)
7. Best practice recommendations
8. Dry-run testing (if fluent-bit binary available)

Follow the devops-skills:fluentbit-validator workflow to identify and fix any issues.
```

**Validation checklist:**
- Configuration syntax is correct (INI format)
- All required parameters are present
- Plugin names are valid
- Tags are consistent across sections
- Parser files and references exist
- Buffer limits are set
- Retry limits are configured
- TLS is enabled for production
- No hardcoded credentials
- Memory limits are reasonable

If validation fails, fix issues and re-validate until all checks pass.

## Error Handling

### Common Issues and Solutions

1. **Configuration syntax errors:**
   - Check section headers: `[SECTION]` format
   - Verify key-value indentation (spaces, not tabs)
   - Check for typos in plugin names
   - Use validator for syntax checking

2. **Memory issues (OOM):**
   - Set `Mem_Buf_Limit` on all tail inputs
   - Reduce buffer limits if memory constrained
   - Enable filesystem buffering for overflow
   - Check Kubernetes memory limits

3. **Missing logs:**
   - Verify file paths exist
   - Check file permissions (read access)
   - Verify tag matching in filters/outputs
   - Check `DB` file for position tracking
   - Review `Exclude_Path` patterns

4. **Parser failures:**
   - Test regex patterns with sample logs
   - Verify parser file is referenced in SERVICE
   - Check Time_Format matches log timestamps
   - Enable debug logging to see parser errors

5. **Kubernetes metadata missing:**
   - Verify RBAC permissions (ServiceAccount, ClusterRole)
   - Check Kube_URL is correct (usually https://kubernetes.default.svc:443)
   - Verify Kube_CA_File and Kube_Token_File paths
   - Check Kube_Tag_Prefix matches input tags

6. **Output connection failures:**
   - Verify host and port are correct
   - Check network connectivity (DNS resolution)
   - Verify TLS configuration if enabled
   - Check authentication credentials
   - Review retry_limit settings

7. **High CPU usage:**
   - Reduce flush frequency
   - Simplify regex parsers
   - Reduce filter complexity
   - Consider worker threads

8. **Disk full (buffering):**
   - Set `storage.total_limit_size`
   - Monitor disk usage
   - Clean old buffer files
   - Adjust flush intervals

## Communication Guidelines

When generating configurations:

1. **Explain structure** - Describe the configuration sections and their purpose
2. **Document decisions** - Explain why certain plugins or settings were chosen
3. **Highlight customization** - Point out parameters that should be customized
4. **Provide examples** - Show how to use the config with different scenarios
5. **Reference documentation** - Link to relevant Fluent Bit docs when helpful
6. **Validate proactively** - Always validate generated configs and fix issues
7. **Security reminders** - Highlight credential and TLS requirements
8. **Performance notes** - Explain buffer limits and flush intervals

## Integration with devops-skills:fluentbit-validator

After generating any Fluent Bit configuration, **automatically invoke the devops-skills:fluentbit-validator skill** to ensure quality:

```
Steps:
1. Generate the Fluent Bit configuration
2. Invoke devops-skills:fluentbit-validator skill with the config file
3. Review validation results
4. Fix any issues identified
5. Re-validate until all checks pass
6. Provide summary of generated config and validation status
```

This ensures all generated configurations follow best practices and are production-ready.

## Resources

### scripts/

**generate_config.py**
- Python script for generating Fluent Bit configurations
- Template-based approach with common use cases
- Supports 13 use cases:
  - `kubernetes-elasticsearch` - K8s logs to Elasticsearch
  - `kubernetes-loki` - K8s logs to Loki
  - `kubernetes-cloudwatch` - K8s logs to CloudWatch
  - `kubernetes-opentelemetry` - K8s logs to OpenTelemetry (NEW)
  - `application-multiline` - App logs with multiline parsing
  - `syslog-forward` - Syslog forwarding
  - `file-tail-s3` - File tailing to S3
  - `http-kafka` - HTTP webhook to Kafka
  - `multi-destination` - Multiple output destinations
  - `prometheus-metrics` - Prometheus metrics collection (NEW)
  - `lua-filtering` - Lua script filtering (NEW)
  - `stream-processor` - Stream processor for analytics (NEW)
  - `custom` - Minimal custom template
- Usage: `python3 scripts/generate_config.py --use-case kubernetes-elasticsearch --output fluent-bit.conf`

### examples/

Contains production-ready example configurations:

- `kubernetes-elasticsearch.conf` - K8s logs to Elasticsearch with metadata enrichment
- `kubernetes-loki.conf` - K8s logs to Loki with labels
- `kubernetes-opentelemetry.conf` - K8s logs to OpenTelemetry Collector (OTLP/HTTP)
- `application-multiline.conf` - App logs with stack trace parsing
- `syslog-forward.conf` - Syslog collection and forwarding
- `file-tail-s3.conf` - File tailing to S3 with compression
- `http-input-kafka.conf` - HTTP webhook to Kafka
- `multi-destination.conf` - Logs to multiple outputs (Elasticsearch + S3)
- `prometheus-metrics.conf` - Metrics collection and Prometheus remote_write
- `lua-filtering.conf` - Custom Lua script filtering and transformation
- `stream-processor.conf` - SQL-like stream processing for analytics
- `parsers.conf` - Custom parser examples (JSON, regex, multiline)
- `full-production.conf` - Complete production setup
- `cloudwatch.conf` - AWS CloudWatch integration

## Documentation Sources

Based on comprehensive research from:

- [Fluent Bit Official Documentation](https://docs.fluentbit.io/manual)
- [Fluent Bit Operations and Best Practices](https://fluentbit.net/fluent-bit-operations-and-best-practices/)
- [Kubernetes Metadata Enrichment Guide](https://fluentbit.io/blog/2023/11/30/kubernetes-metadata-enrichment-with-fluent-bit-with-troubleshooting-tips/)
- [Fluent Bit Tutorial - Coralogix](https://coralogix.com/blog/fluent-bit-guide/)
- [CNCF Parsing Guide](https://www.cncf.io/blog/2025/01/06/parsing-101-with-fluent-bit/)
- Context7 Fluent Bit documentation (/fluent/fluent-bit-docs)
