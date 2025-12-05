# Loki Configuration Best Practices

This document outlines best practices for configuring and deploying Grafana Loki in production environments.

> **Important Notice (Loki 3.4+):** Promtail has been deprecated and its code merged into Grafana Alloy. For new log collection deployments, use [Grafana Alloy](https://grafana.com/docs/alloy/latest/) instead of Promtail.

## Schema Configuration

### Use TSDB with v13 Schema (CRITICAL)

**Always use the latest schema** for new deployments:

```yaml
schema_config:
  configs:
    - from: "2025-01-01"  # Use deployment date
      store: tsdb
      object_store: s3
      schema: v13
      index:
        prefix: loki_index_
        period: 24h
```

**Why:**
- TSDB is the modern, performant index store
- v13 schema provides best performance and features
- Cannot be changed after deployment without migration
- Daily period (`24h`) is recommended for most use cases

**Important:** Set `from` date to your deployment date, not a past date.

## Deployment Modes

### Choose the Right Deployment Mode

| Mode | Use Case | Ingestion | Complexity |
|------|----------|-----------|------------|
| **Monolithic** | Development, testing, small deployments | <100GB/day | Low |
| **Simple Scalable** | Production, moderate scale | 100GB-1TB/day | Medium |
| **Microservices** | Large scale, multi-tenancy | >1TB/day | High |

**Monolithic:**
- Single binary with all components
- Easy to operate
- Limited scalability
- Good for getting started

**Simple Scalable:**
- Separates read, write, and backend
- Horizontal scaling
- Production-ready
- Recommended for most use cases

**Microservices:**
- Full component separation
- Maximum scalability
- Independent scaling per component
- Requires more operational overhead

## Storage Configuration

### Storage Backend Selection

**Filesystem:**
- Development and testing only
- Requires persistent volumes
- Not recommended for production at scale

**Object Storage (S3, GCS, Azure):**
- Recommended for production
- Cost-effective at scale
- Durable and highly available
- Use IAM roles/service accounts for authentication

**Best practices:**
```yaml
common:
  storage:
    s3:
      s3: s3://region/bucket-name
      s3forcepathstyle: false
      # Use IAM roles instead of access keys
  replication_factor: 3  # Always use 3 for production
```

## Replication and High Availability

### Always Use Replication Factor 3

```yaml
common:
  replication_factor: 3
```

**Why:**
- Data durability: tolerates 2 node failures
- Query reliability: ensures data availability
- Industry standard for distributed systems

### Enable Zone-Aware Replication

For multi-AZ deployments:

```yaml
ingester:
  lifecycler:
    ring:
      zone_awareness_enabled: true
```

**Why:**
- Distributes replicas across availability zones
- Survives entire AZ failures
- Better fault tolerance

## Native OTLP Ingestion (Loki 3.0+)

### Configure OTLP Attributes

If using OpenTelemetry, configure how OTLP attributes are mapped:

```yaml
limits_config:
  allow_structured_metadata: true

  otlp_config:
    resource_attributes:
      ignore_defaults: false  # Set true to completely override defaults
      attributes_config:
        - action: index_label
          attributes:
            - service.name
            - service.namespace
            - deployment.environment
            # NOTE: Do NOT include high-cardinality attributes as index labels!
        - action: structured_metadata
          attributes:
            - k8s.pod.name           # High cardinality - use structured_metadata
            - service.instance.id    # High cardinality - use structured_metadata
    log_attributes:
      - action: structured_metadata
        attributes:
          - trace_id
          - span_id
```

> **⚠️ CRITICAL: Label Cardinality Best Practices (Updated 2025)**
>
> **DO NOT** use these high-cardinality attributes as index labels:
> - `k8s.pod.name` - Changes frequently, creates too many streams
> - `service.instance.id` - High cardinality
>
> Instead, store them as `structured_metadata`. This is now the recommended approach.
> See: https://grafana.com/docs/loki/latest/get-started/labels/remove-default-labels/

**Recommended index labels** (low-cardinality):
- `service.name`, `service.namespace`, `deployment.environment`
- `cloud.region`, `cloud.availability_zone`
- `k8s.cluster.name`, `k8s.namespace.name`, `k8s.container.name`
- `k8s.deployment.name`, `k8s.statefulset.name`, `k8s.daemonset.name`

**Configuring Default Resource Attributes:**

For more control over which OTLP resource attributes become labels:

```yaml
distributor:
  otlp_config:
    default_resource_attributes_as_index_labels:
      - service.name
      - service.namespace
      - deployment.environment
      - k8s.cluster.name
      - k8s.namespace.name
      # EXCLUDES: k8s.pod.name, service.instance.id
```

**Why:**
- Native OTLP support eliminates the need for Loki Exporter (deprecated)
- Control which attributes become labels vs structured metadata
- **Low-cardinality** attributes should be `index_label`
- **High-cardinality** attributes should be `structured_metadata`
- Use `ignore_defaults: true` for complete control over attribute mapping

**OTLP Endpoint:** `POST /otlp/v1/logs`

**OpenTelemetry Collector Configuration:**
```yaml
exporters:
  otlphttp:
    endpoint: http://loki:3100/otlp
    # Note: lokiexporter is DEPRECATED - use otlphttp instead

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlphttp]
```

## Pattern Ingester (Loki 3.0+)

### Enable Pattern Detection

```yaml
pattern_ingester:
  enabled: true
```

**Why:**
- Automatic log pattern detection
- Powers Explore Logs / Grafana Drilldown features
- Identifies recurring patterns for anomaly detection
- Minimal resource overhead

## Caching Configuration

### Configure Memcached for Production

```yaml
# Chunk cache
chunk_store_config:
  chunk_cache_config:
    memcached:
      batch_size: 256
      parallelism: 10
    memcached_client:
      host: memcached-chunks.loki.svc.cluster.local
      service: memcached-client
      timeout: 500ms

# Results cache
query_range:
  cache_results: true
  results_cache:
    cache:
      memcached_client:
        host: memcached-results.loki.svc.cluster.local
        timeout: 500ms
```

**Important Notes:**
- **TSDB does NOT need index cache** - only chunks and results cache
- Use separate Memcached instances for chunks and results
- Size chunk cache based on query hot data volume
- Size results cache based on repeated query patterns

**Helm Chart Caching:**
```yaml
memcached:
  chunk_cache:
    enabled: true
  results_cache:
    enabled: true

memcachedChunks:
  enabled: true
  replicas: 2
  resources:
    requests:
      memory: 1Gi
    limits:
      memory: 2Gi
```

## Limits Configuration

### Set Appropriate Ingestion Limits

```yaml
limits_config:
  ingestion_rate_mb: 50  # Adjust based on expected load
  ingestion_burst_size_mb: 100  # 2x rate for bursts
  max_line_size: 256KB
  max_line_size_truncate: true
```

**Why:**
- Prevents resource exhaustion
- Protects against misconfigured clients
- Allows burst traffic while limiting sustained overload

### Control Stream Cardinality

```yaml
limits_config:
  max_streams_per_user: 10000
  max_global_streams_per_user: 100000
```

**Why:**
- High cardinality kills performance
- Each label combination creates a stream
- Limit prevents accidental label explosion

**Best practice:** Use line filters for high-cardinality data (user IDs, trace IDs) instead of labels.

### Configure Retention

```yaml
compactor:
  retention_enabled: true
  retention_delete_delay: 2h

limits_config:
  retention_period: 30d  # Adjust based on requirements
```

**Why:**
- Controls storage costs
- Meets compliance requirements
- Automatic cleanup of old data

## Chunk Management

### Optimize Chunk Settings

```yaml
ingester:
  chunk_encoding: snappy
  chunk_target_size: 1572864  # 1.5MB
  chunk_idle_period: 30m
  max_chunk_age: 2h
```

**Why:**
- `snappy`: Best balance of speed vs compression
- `1.5MB` target: Optimal chunk size (requires 5-10x raw data)
- `30m` idle: Flushes inactive chunks to storage
- `2h` max age: Prevents memory buildup

**Important:** More streams = more chunks in memory. Keep stream cardinality low.

## Query Performance

### Configure Query Concurrency

```yaml
querier:
  max_concurrent: 4  # Per querier instance
  query_timeout: 5m
```

**Recommendations:**
- Start with 4 concurrent queries
- Increase based on CPU/memory resources
- Monitor query latency and adjust

### Enable Query Parallelization

```yaml
query_range:
  parallelise_shardable_queries: true
  split_queries_by_interval: 15m  # For large time ranges
```

**Why:**
- Distributes query load across queriers
- Faster results for large time ranges
- Better resource utilization

## Security

### Enable Multi-Tenancy

```yaml
auth_enabled: true
```

**Production recommendation:**
- Always use `auth_enabled: true`
- Deploy authenticating reverse proxy (nginx, Envoy)
- Enforce `X-Scope-OrgID` header
- Isolate tenant data

### Use TLS for Inter-Component Communication

```yaml
server:
  http_tls_config:
    cert_file: /path/to/cert.pem
    key_file: /path/to/key.pem
  grpc_tls_config:
    cert_file: /path/to/cert.pem
    key_file: /path/to/key.pem
```

**Why:**
- Encrypts data in transit
- Prevents eavesdropping
- Required for compliance (PCI, HIPAA, etc.)

### Secure Credentials

**Never hardcode credentials:**
```yaml
# BAD
common:
  storage:
    s3:
      access_key_id: AKIAIOSFODNN7EXAMPLE
      secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

# GOOD
common:
  storage:
    s3:
      # Uses IAM role automatically
```

**Best practices:**
- Use IAM roles for AWS
- Use service accounts for GCP
- Use managed identities for Azure
- Store secrets in Kubernetes Secrets or Vault
- Reference secrets via environment variables

## Monitoring and Observability

### Enable Metrics

Loki exports Prometheus metrics automatically. Scrape them:

```yaml
# In Prometheus config
- job_name: 'loki'
  static_configs:
    - targets: ['loki:3100']
```

**Key metrics to monitor:**
- `loki_ingester_chunks_flushed_total`: Chunk flush rate
- `loki_ingester_memory_streams`: Active streams (watch for growth)
- `loki_request_duration_seconds`: Query latency
- `loki_distributor_ingester_append_failures_total`: Ingestion failures
- `loki_boltdb_shipper_request_duration_seconds`: Index query time

### Set Up Alerts

**Critical alerts:**
```yaml
# High ingestion failure rate
- alert: LokiIngestionFailureRate
  expr: sum(rate(loki_distributor_ingester_append_failures_total[5m])) > 10

# Too many streams (cardinality explosion)
- alert: LokiHighStreamCardinality
  expr: loki_ingester_memory_streams > 100000

# Compaction not running
- alert: LokiCompactionNotRunning
  expr: time() - loki_boltdb_shipper_compact_tables_operation_last_successful_run_timestamp_seconds > 3600
```

## Resource Planning

### Ingester Resources

**Memory requirements:**
- Base: ~1GB per ingester
- Add: 1-2KB per active stream
- Add: Chunk buffer (depends on throughput)

**Example:** 10,000 streams = ~1GB + 20MB = ~1.2GB minimum

**Kubernetes recommendations:**
```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "1"
  limits:
    memory: "8Gi"
    cpu: "2"
```

### Querier Resources

**Memory requirements:**
- Base: ~500MB per querier
- Add: Depends on query complexity and concurrency

**CPU requirements:**
- Varies with query load
- More CPU = faster queries

**Kubernetes recommendations:**
```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1"
  limits:
    memory: "4Gi"
    cpu: "2"
```

### Storage Requirements

**Estimate storage:**
```
Daily storage = (ingestion rate MB/s) × 86400 seconds × compression ratio
```

**Compression ratios:**
- Text logs: 5-10x (snappy)
- JSON logs: 3-7x (snappy)
- Structured logs: 2-5x (snappy)

**Example:** 10 MB/s ingestion with 5x compression:
```
10 MB/s × 86400 × 0.2 = ~170 GB/day
```

## Operational Best Practices

### Use Health Checks

Configure Kubernetes probes:

```yaml
livenessProbe:
  httpGet:
    path: /ready
    port: 3100
  initialDelaySeconds: 45

readinessProbe:
  httpGet:
    path: /ready
    port: 3100
  initialDelaySeconds: 45
```

### Enable Graceful Shutdown

```yaml
server:
  graceful_shutdown_timeout: 30s
```

**Why:**
- Allows in-flight requests to complete
- Prevents data loss during restarts
- Smooth rolling updates

### Use Configuration Management

**Best practices:**
- Store configs in Git
- Use configuration as code (Terraform, Helm)
- Validate configs before applying
- Test in staging before production
- Document all customizations

### Regular Maintenance

**Weekly:**
- Review metrics and alerts
- Check for errors in logs
- Verify compaction is running

**Monthly:**
- Review and adjust limits based on actual usage
- Analyze storage growth trends
- Update Loki to latest stable version

**Quarterly:**
- Review architecture for scale
- Optimize queries and cardinality
- Conduct disaster recovery tests

## Common Anti-Patterns

### Don't Use High-Cardinality Labels

**BAD:**
```yaml
# Don't use user_id, trace_id, request_id as labels
{app="api", user_id="12345"}  # Creates too many streams
```

**GOOD:**
```yaml
# Use structured metadata or line filters instead
{app="api"} | json | user_id="12345"
```

### Don't Ignore Limits

**BAD:**
```yaml
limits_config:
  max_streams_per_user: 0  # Unlimited - dangerous!
```

**GOOD:**
```yaml
limits_config:
  max_streams_per_user: 10000  # Reasonable limit
```

### Don't Skip Replication

**BAD:**
```yaml
common:
  replication_factor: 1  # Single copy - data loss risk
```

**GOOD:**
```yaml
common:
  replication_factor: 3  # Durability and availability
```

### Don't Use Filesystem Storage in Production

**BAD:**
```yaml
common:
  storage:
    filesystem:
      chunks_directory: /loki/chunks  # Not scalable
```

**GOOD:**
```yaml
common:
  storage:
    s3:
      s3: s3://region/bucket  # Scalable and durable
```

### Don't Disable Authentication in Multi-Tenant Environments

**BAD:**
```yaml
auth_enabled: false  # No tenant isolation
```

**GOOD:**
```yaml
auth_enabled: true  # Proper tenant isolation
```

## Configuration Validation

### Before Deployment

1. **Validate syntax:**
   ```bash
   loki -config.file=loki.yaml -verify-config
   ```

2. **Review configuration:**
   ```bash
   loki -config.file=loki.yaml -print-config-stderr
   ```

3. **Test ingestion:**
   Send test logs and verify they appear

4. **Test queries:**
   Run sample LogQL queries

### After Deployment

1. **Check health:**
   ```bash
   curl http://loki:3100/ready
   ```

2. **Monitor metrics:**
   Review Prometheus metrics

3. **Verify data ingestion:**
   Check ingester and distributor logs

4. **Test query performance:**
   Run representative queries

## Troubleshooting Guide

### High Memory Usage

**Symptoms:**
- OOMKilled pods
- Slow queries
- High `loki_ingester_memory_streams`

**Solutions:**
- Reduce `max_streams_per_user`
- Lower `chunk_idle_period`
- Check for cardinality explosion
- Add more ingester replicas

### Slow Queries

**Symptoms:**
- Query timeouts
- High `loki_request_duration_seconds`

**Solutions:**
- Increase `max_concurrent` in querier
- Enable query parallelization
- Add caching
- Optimize LogQL queries (use specific stream selectors)
- Add more querier replicas

### Ingestion Failures

**Symptoms:**
- High `loki_distributor_ingester_append_failures_total`
- Missing logs

**Solutions:**
- Check ingestion rate limits
- Verify storage backend connectivity
- Check authentication headers
- Review distributor logs
- Increase ingester capacity

### Storage Growing Rapidly

**Symptoms:**
- Storage costs increasing
- Running out of disk space

**Solutions:**
- Enable retention
- Review log volume and cardinality
- Implement sampling or filtering at source
- Check chunk compression settings

## Thanos Object Storage Client (Loki 3.4+)

Loki 3.4 introduces new object storage clients based on the **Thanos Object Storage Client**. This is opt-in now but will become the default in future releases.

### Enable Thanos Storage

```yaml
storage_config:
  use_thanos_objstore: true
  object_store:
    s3:
      bucket_name: my-loki-bucket
      endpoint: s3.us-west-2.amazonaws.com
      region: us-west-2
```

**Key Migration Notes:**
- `use_thanos_objstore: true` is **mutually exclusive** with legacy storage config
- `disable_dualstack` → `dualstack_enabled` (inverted)
- `signature_version` removed (always uses V4)
- `http_config` → `http` (nested block)
- Multiple bucket support removed (use single `bucket_name`)
- Storage prefix cannot contain dashes (`-`) - use underscores

**When using Thanos storage, ruler storage must be configured separately:**
```yaml
ruler_storage:
  backend: s3
  s3:
    bucket_name: my-ruler-bucket
```

## Time Sharding for Out-of-Order Ingestion (Loki 3.4+)

For scenarios with delayed log delivery or historical imports:

```yaml
limits_config:
  shard_streams:
    time_sharding_enabled: true
```

**Use cases:**
- Log backfilling
- Delayed log delivery (network issues, batch processing)
- Multi-region log aggregation with varying latencies

## Bloom Filters (Experimental - Loki 3.0+)

> **Warning:** Bloom filters are experimental and intended for deployments ingesting >75TB/month.

> **⚠️ BREAKING CHANGE (Loki 3.3+):** Bloom filters now use **structured metadata** instead of free-text search. The block format (V3) is incompatible with previous versions. **Delete existing bloom blocks before upgrading to 3.3+**.

### When to Use

Bloom filters accelerate "needle in haystack" queries on **structured metadata**:

```yaml
bloom_build:
  enabled: true
  planner:
    planning_interval: 6h

bloom_gateway:
  enabled: true
  worker_concurrency: 4
  block_query_concurrency: 8

limits_config:
  bloom_creation_enabled: true
  bloom_gateway_enable_filtering: true
  tsdb_sharding_strategy: bounded
```

**Use when:**
- Large-scale deployments (>75TB/month)
- Frequent searches for specific values in structured metadata (trace IDs, UUIDs)
- Queries like: `{cluster="prod"} | traceID="3c0e3dcd33e7"`

**Don't use when:**
- Small deployments (overhead > benefit)
- Queries mostly use label selectors
- Budget is a concern (requires additional storage)
- Need free-text search (blooms work on structured metadata only)

**Best Practice for Bloom Queries:**
```logql
# Good - filter structured metadata BEFORE parser
{cluster="prod"} | trace_id="abc123" | json | level="error"

# Bad - parser runs first, blooms can't help
{cluster="prod"} | json | trace_id="abc123" | level="error"
```

## Deprecated Storage and Configuration

> **⚠️ Deprecation Warnings**

### Deprecated Index Stores
- `boltdb` / `boltdb-shipper` - Use `tsdb` instead
- `bigtable` - Migrate to TSDB
- `dynamodb` - Migrate to TSDB
- `cassandra` (for chunks) - Migrate to object storage

### Deprecated Tools
- **Promtail** - Deprecated in Loki 3.4, commercial support ends **February 28, 2026**
  - Use [Grafana Alloy](https://grafana.com/docs/alloy/latest/) instead
  - Migration: `alloy convert --source-format=promtail`
- **Grafana Agent** - Long-term support ended **October 31, 2025**
  - Migrate to [Grafana Alloy](https://grafana.com/docs/alloy/latest/)
- **lokiexporter** (OTel Collector) - Use `otlphttp` instead

### Migration from BoltDB to TSDB
```yaml
schema_config:
  configs:
    - from: 2020-01-01
      store: boltdb-shipper  # Keep for existing data
      schema: v11
    - from: 2025-01-01       # Add new period
      store: tsdb            # Use TSDB for new data
      schema: v13
```

## Additional Resources

- [Grafana Loki Best Practices](https://grafana.com/docs/loki/latest/configure/bp-configure/)
- [Loki Configuration Reference](https://grafana.com/docs/loki/latest/configure/)
- [Loki Operations Guide](https://grafana.com/docs/loki/latest/operations/)
- [Loki Helm Charts](https://grafana.com/docs/loki/latest/setup/install/helm/)
- [OTLP Ingestion](https://grafana.com/docs/loki/latest/send-data/otel/)
- [Grafana Alloy (Promtail replacement)](https://grafana.com/docs/alloy/latest/)

## Related Skills

- **logql-generator**: For generating LogQL queries
- **fluentbit-generator**: For log collection pipelines to Loki
- **promql-generator**: For Prometheus (monitoring Loki)