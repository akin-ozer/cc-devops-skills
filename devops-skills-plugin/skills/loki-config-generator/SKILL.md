
---
name: loki-config-generator
description: Comprehensive toolkit for generating best practice Grafana Loki server configurations following current standards and conventions. Use this skill when creating new Loki deployments, configuring Loki servers, implementing log aggregation systems, or building production-ready Loki configurations.
---

# Loki Configuration Generator

## Overview

Generate production-ready Grafana Loki server configurations with best practices. Supports monolithic, simple scalable, and microservices deployment modes with S3, GCS, Azure, or filesystem storage.

> **Current Stable:** Loki 3.6.2 (November 2025)
> **Important:** Promtail deprecated in 3.4 - use [Grafana Alloy](https://grafana.com/docs/alloy/latest/) instead. See `examples/grafana-alloy.yaml` for log collection configuration.

## When to Use

Invoke when: deploying Loki, creating configs from scratch, migrating to Loki, implementing multi-tenant logging, configuring storage backends, or optimizing existing deployments.

---

## Generation Methods

### Method 1: Script Generation (Recommended)

**Use `scripts/generate_config.py` for consistent, validated configurations:**

```bash
# Simple Scalable with S3 (production)
python scripts/generate_config.py \
  --mode simple-scalable \
  --storage s3 \
  --bucket my-loki-bucket \
  --region us-east-1 \
  --retention-days 30 \
  --otlp-enabled \
  --output loki-config.yaml

# Monolithic with filesystem (development)
python scripts/generate_config.py \
  --mode monolithic \
  --storage filesystem \
  --auth-enabled=false \
  --output loki-dev.yaml

# Production with Thanos storage (Loki 3.4+)
python scripts/generate_config.py \
  --mode simple-scalable \
  --storage s3 \
  --thanos-storage \
  --otlp-enabled \
  --time-sharding \
  --output loki-thanos.yaml
```

**Script Options:**
| Option | Description |
|--------|-------------|
| `--mode` | monolithic, simple-scalable, microservices |
| `--storage` | filesystem, s3, gcs, azure |
| `--otlp-enabled` | Enable OTLP ingestion configuration |
| `--thanos-storage` | Use Thanos object storage client (3.4+) |
| `--time-sharding` | Enable out-of-order ingestion (3.4+) |
| `--ruler` | Enable alerting/recording rules |
| `--horizontal-compactor` | main/worker mode (3.6+) |

### Method 2: Manual Configuration

Follow the staged workflow below when script generation doesn't meet specific requirements or when learning the configuration structure.

### Output Formats

For Kubernetes deployments, generate BOTH formats:
1. **Native Loki config** (`loki-config.yaml`) - For ConfigMap or direct use
2. **Helm values** (`values.yaml`) - For Helm chart deployments

See `examples/kubernetes-helm-values.yaml` for Helm format.

---

## Documentation Lookup

### When to Use Context7/Web Search

**REQUIRED - Use Context7 MCP for:**
- Configuring features from Loki 3.4+ (Thanos storage, time sharding)
- Configuring features from Loki 3.6+ (horizontal compactor, enforced labels)
- Bloom filter configuration (complex, experimental)
- Custom OTLP attribute mappings beyond standard patterns
- Troubleshooting configuration errors

**OPTIONAL - Skip documentation lookup for:**
- Standard deployment modes (monolithic, simple-scalable)
- Basic storage configuration (S3, GCS, Azure, filesystem)
- Default limits and component settings
- Configurations covered in `references/` directory

### Context7 MCP (preferred)

```
resolve-library-id: "grafana loki"
get-library-docs: /websites/grafana_loki, topic: [component]
```

**Example topics:** `storage_config`, `limits_config`, `otlp`, `compactor`, `ruler`, `bloom`

### Web Search Fallback

Use when Context7 unavailable: `"Grafana Loki 3.6 [component] configuration documentation site:grafana.com"`

---

## Configuration Workflow

### Stage 1: Gather Requirements

**Deployment Mode:**
| Mode | Scale | Use Case |
|------|-------|----------|
| Monolithic | <100GB/day | Testing, development |
| Simple Scalable | 100GB-1TB/day | Production |
| Microservices | >1TB/day | Large-scale, multi-tenant |

**Storage Backend:** S3, GCS, Azure Blob, Filesystem, MinIO

**Key Questions:** Expected log volume? Retention period? Multi-tenancy needed? High availability requirements? Kubernetes deployment?

Use AskUserQuestion if information is missing.

### Stage 2: Schema Configuration (CRITICAL)

For all new deployments (Loki 2.9+), use TSDB with v13 schema:

```yaml
schema_config:
  configs:
    - from: "2025-01-01"  # Use deployment date
      store: tsdb
      object_store: s3     # s3, gcs, azure, filesystem
      schema: v13
      index:
        prefix: loki_index_
        period: 24h
```

**Key:** Schema cannot change after deployment without migration.

### Stage 3: Storage Configuration

**S3:**
```yaml
common:
  storage:
    s3:
      s3: s3://us-east-1/loki-bucket
      s3forcepathstyle: false
```

**GCS:** `gcs: { bucket_name: loki-bucket }`
**Azure:** `azure: { container_name: loki-container, account_name: ${AZURE_ACCOUNT_NAME} }`
**Filesystem:** `filesystem: { chunks_directory: /loki/chunks, rules_directory: /loki/rules }`

### Stage 4: Component Configuration

**Ingester:**
```yaml
ingester:
  chunk_encoding: snappy
  chunk_idle_period: 30m
  max_chunk_age: 2h
  chunk_target_size: 1572864  # 1.5MB
  lifecycler:
    ring:
      replication_factor: 3  # 3 for production
```

**Querier:**
```yaml
querier:
  max_concurrent: 4
  query_timeout: 1m
```

**Compactor:**
```yaml
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
```

### Stage 5: Limits Configuration

```yaml
limits_config:
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
  max_streams_per_user: 10000
  max_entries_limit_per_query: 5000
  max_query_length: 721h
  retention_period: 30d
  allow_structured_metadata: true
  volume_enabled: true
```

### Stage 6: Server & Auth

```yaml
server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: info

auth_enabled: true  # false for single-tenant
```

### Stage 7: OTLP Ingestion (Loki 3.0+)

Native OpenTelemetry ingestion - use `otlphttp` exporter (NOT deprecated `lokiexporter`):

```yaml
limits_config:
  allow_structured_metadata: true
  otlp_config:
    resource_attributes:
      attributes_config:
        - action: index_label  # Low-cardinality only!
          attributes: [service.name, service.namespace, deployment.environment]
        - action: structured_metadata  # High-cardinality
          attributes: [k8s.pod.name, service.instance.id]
```

**Actions:** `index_label` (searchable, low-cardinality), `structured_metadata` (queryable), `drop`

> **⚠️ NEVER use `k8s.pod.name` as index_label** - use structured_metadata instead.

**OTel Collector:**
```yaml
exporters:
  otlphttp:
    endpoint: http://loki:3100/otlp
```

### Stage 8: Caching

```yaml
chunk_store_config:
  chunk_cache_config:
    memcached_client:
      host: memcached-chunks
      timeout: 500ms

query_range:
  cache_results: true
  results_cache:
    cache:
      memcached_client:
        host: memcached-results
```

### Stage 9: Advanced Features

**Pattern Ingester (3.0+):**
```yaml
pattern_ingester:
  enabled: true
```

**Bloom Filters (Experimental, 3.3+):** Only for >75TB/month deployments. Works on structured metadata only. See examples/ for config.

**Time Sharding (3.4+):** For out-of-order ingestion:
```yaml
limits_config:
  shard_streams:
    time_sharding_enabled: true
```

**Thanos Storage (3.4+):** New storage client, opt-in now, default later:
```yaml
storage_config:
  use_thanos_objstore: true
  object_store:
    s3:
      bucket_name: my-bucket
      endpoint: s3.us-west-2.amazonaws.com
```

### Stage 10: Ruler (Alerting)

```yaml
ruler:
  storage:
    type: s3
    s3: { bucket_name: loki-ruler }
  alertmanager_url: http://alertmanager:9093
  enable_api: true
  enable_sharding: true
```

### Stage 11: Loki 3.6 Features

- **Horizontally Scalable Compactor:** `horizontal_scaling_mode: main|worker`
- **Policy-Based Enforced Labels:** `enforced_labels: [service.name]`
- **FluentBit v4:** `structured_metadata` parameter support

### Stage 12: Validate Configuration (REQUIRED)

**Always validate before deployment:**

```bash
# Syntax and parameter validation
loki -config.file=loki-config.yaml -verify-config

# Print resolved configuration (shows defaults)
loki -config.file=loki-config.yaml -print-config-stderr 2>&1 | head -100

# Dry-run with Docker (if Loki not installed locally)
docker run --rm -v $(pwd)/loki-config.yaml:/etc/loki/config.yaml \
  grafana/loki:3.6.2 -config.file=/etc/loki/config.yaml -verify-config
```

**Validation Checklist:**
- [ ] No syntax errors from `-verify-config`
- [ ] Schema uses `tsdb` and `v13`
- [ ] `replication_factor: 3` for production
- [ ] `auth_enabled: true` if multi-tenant
- [ ] Storage credentials/IAM configured
- [ ] Retention period matches requirements

---

## Production Checklist

### High Availability Requirements

**Zone-Aware Replication (CRITICAL for production multi-AZ deployments):**

When using `replication_factor: 3`, ALWAYS enable zone-awareness for multi-AZ deployments:

```yaml
ingester:
  lifecycler:
    ring:
      replication_factor: 3
      zone_awareness_enabled: true  # CRITICAL for multi-AZ

# Set zone via environment variable or config
# Each pod should set its zone based on node topology
common:
  instance_availability_zone: ${AVAILABILITY_ZONE}
```

**Why:** Without zone-awareness, all 3 replicas may land in the same AZ. If that AZ fails, you lose data.

**Kubernetes Implementation:**
```yaml
# In Helm values or pod spec
env:
  - name: AVAILABILITY_ZONE
    valueFrom:
      fieldRef:
        fieldPath: metadata.labels['topology.kubernetes.io/zone']
```

### TLS Configuration (Production Required)

Enable TLS for all inter-component and client communication:

```yaml
server:
  http_tls_config:
    cert_file: /etc/loki/tls/tls.crt
    key_file: /etc/loki/tls/tls.key
    client_ca_file: /etc/loki/tls/ca.crt  # For mTLS
  grpc_tls_config:
    cert_file: /etc/loki/tls/tls.crt
    key_file: /etc/loki/tls/tls.key
    client_ca_file: /etc/loki/tls/ca.crt
```

See `examples/production-tls.yaml` for complete TLS configuration.

### Production Checklist Summary

| Requirement | Setting | Required For |
|-------------|---------|--------------|
| `replication_factor: 3` | common block | All production |
| `zone_awareness_enabled: true` | ingester.lifecycler.ring | Multi-AZ |
| `auth_enabled: true` | root level | Multi-tenant |
| TLS enabled | server block | All production |
| IAM roles (not keys) | storage config | Cloud storage |
| Caching enabled | chunk_store_config, query_range | Performance |
| Pattern ingester | pattern_ingester.enabled | Observability |
| Retention configured | compactor + limits_config | Cost control |

---

## Monitoring Recommendations

### Key Metrics to Monitor

Configure Prometheus to scrape Loki metrics and alert on these critical indicators:

```yaml
# Prometheus scrape config
- job_name: 'loki'
  static_configs:
    - targets: ['loki:3100']
```

### Critical Alerts

```yaml
groups:
  - name: loki-critical
    rules:
      # Ingestion failures
      - alert: LokiIngestionFailures
        expr: sum(rate(loki_distributor_ingester_append_failures_total[5m])) > 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Loki ingestion failures detected"

      # High stream cardinality (performance killer)
      - alert: LokiHighStreamCardinality
        expr: loki_ingester_memory_streams > 100000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High stream cardinality - review labels"

      # Compaction not running (retention broken)
      - alert: LokiCompactionStalled
        expr: time() - loki_compactor_last_successful_run_timestamp_seconds > 7200
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Loki compaction stalled - retention not enforced"

      # Query latency
      - alert: LokiSlowQueries
        expr: histogram_quantile(0.99, sum(rate(loki_request_duration_seconds_bucket{route=~"loki_api_v1_query.*"}[5m])) by (le)) > 30
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Loki query P99 latency > 30s"

      # Ingester memory pressure
      - alert: LokiIngesterMemoryHigh
        expr: container_memory_usage_bytes{container="ingester"} / container_spec_memory_limit_bytes{container="ingester"} > 0.8
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Loki ingester memory usage > 80%"
```

### Key Metrics Reference

| Metric | Description | Action Threshold |
|--------|-------------|------------------|
| `loki_ingester_memory_streams` | Active streams in memory | >100k: review cardinality |
| `loki_distributor_ingester_append_failures_total` | Ingestion failures | >0: investigate immediately |
| `loki_request_duration_seconds` | Query latency | P99 >30s: add caching/queriers |
| `loki_ingester_chunks_flushed_total` | Chunk flush rate | Low rate: check ingester health |
| `loki_compactor_last_successful_run_timestamp_seconds` | Last compaction | >2h ago: compaction broken |

### Grafana Dashboard

Import official Loki dashboards:
- Dashboard ID: `13407` - Loki Logs
- Dashboard ID: `14055` - Loki Operational

---

## Log Collection with Grafana Alloy

> **Promtail is deprecated** (support ends Feb 2026). Use Grafana Alloy for new deployments.

### Basic Alloy Configuration

See `examples/grafana-alloy.yaml` for complete configuration.

```alloy
// Kubernetes log discovery
discovery.kubernetes "pods" {
  role = "pod"
}

// Relabeling for Kubernetes metadata
discovery.relabel "pods" {
  targets = discovery.kubernetes.pods.targets

  rule {
    source_labels = ["__meta_kubernetes_namespace"]
    target_label  = "namespace"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_name"]
    target_label  = "pod"
  }
  rule {
    source_labels = ["__meta_kubernetes_pod_container_name"]
    target_label  = "container"
  }
}

// Log collection
loki.source.kubernetes "pods" {
  targets    = discovery.relabel.pods.output
  forward_to = [loki.write.default.receiver]
}

// Send to Loki
loki.write "default" {
  endpoint {
    url = "http://loki-gateway.loki.svc.cluster.local/loki/api/v1/push"

    // For multi-tenant
    tenant_id = "default"
  }
}
```

### Migration from Promtail

```bash
# Convert Promtail config to Alloy
alloy convert --source-format=promtail --output=alloy-config.alloy promtail.yaml
```

---

## Complete Examples

See `examples/` directory for full configurations:
- `monolithic-filesystem.yaml` - Development/testing
- `simple-scalable-s3.yaml` - Production with S3
- `microservices-s3.yaml` - Large-scale distributed
- `multi-tenant.yaml` - Multi-tenant with per-tenant limits
- `production-tls.yaml` - TLS-enabled production config
- `grafana-alloy.yaml` - Log collection with Alloy
- `kubernetes-helm-values.yaml` - Helm chart values

**Minimal Monolithic:**
```yaml
auth_enabled: false
server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2025-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: loki_index_
        period: 24h

limits_config:
  retention_period: 30d
  allow_structured_metadata: true

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
```

---

## Helm Deployment

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki -f values.yaml
```

**Generate both native config and Helm values for Kubernetes deployments.**

```yaml
# values.yaml
deploymentMode: SimpleScalable

loki:
  schemaConfig:
    configs:
      - from: "2025-01-01"
        store: tsdb
        object_store: s3
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
  limits_config:
    retention_period: 30d
    allow_structured_metadata: true
  # Zone awareness for HA
  ingester:
    lifecycler:
      ring:
        zone_awareness_enabled: true

backend:
  replicas: 3
  # Spread across zones
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: topology.kubernetes.io/zone
      whenUnsatisfiable: DoNotSchedule
read:
  replicas: 3
write:
  replicas: 3
```

---

## Best Practices

**Performance:**
- `chunk_encoding: snappy`, `chunk_target_size: 1572864`
- Enable caching (chunks, results)
- `parallelise_shardable_queries: true`

**Security:**
- `auth_enabled: true` with reverse proxy auth
- IAM roles for cloud storage (never hardcode keys)
- TLS for all communications (see Production Checklist)

**Reliability:**
- `replication_factor: 3` for production
- `zone_awareness_enabled: true` for multi-AZ (see Production Checklist)
- Persistent volumes for ingesters
- Monitor ingestion rate and query latency (see Monitoring section)

**Limits:** Set `ingestion_rate_mb`, `max_streams_per_user` to prevent overload

---

## Common Issues

| Issue | Solution |
|-------|----------|
| High ingester memory | Reduce `max_streams_per_user`, lower `chunk_idle_period` |
| Slow queries | Increase `max_concurrent`, enable parallelization, add caching |
| Ingestion failures | Check `ingestion_rate_mb`, verify storage connectivity |
| Storage growing fast | Enable retention, check compression, review cardinality |
| Data loss in AZ failure | Enable `zone_awareness_enabled: true` |
| Config validation fails | Run `loki -verify-config`, check YAML syntax |

---

## Deprecated (Migrate Away)

- `boltdb-shipper` → `tsdb`
- `lokiexporter` → `otlphttp`
- Promtail → Grafana Alloy (support ends Feb 2026)

---

## Resources

**scripts/generate_config.py** - Generate configs programmatically (RECOMMENDED)
**examples/** - Complete configuration examples for all modes
**references/** - Full parameter reference and best practices

## Related Skills

- **logql-generator** - LogQL query generation
- **fluentbit-generator** - Log collection to Loki