# Loki Configuration Reference

This document provides a comprehensive reference for Grafana Loki configuration parameters.

> **Current Stable Release:** Loki 3.6.2 (November 2025)

## Table of Contents

- [Server Configuration](#server-configuration)
- [Common Configuration](#common-configuration)
- [Schema Configuration](#schema-configuration)
- [Storage Configuration](#storage-configuration)
- [Ingester Configuration](#ingester-configuration)
- [Distributor Configuration](#distributor-configuration)
- [Querier Configuration](#querier-configuration)
- [Query Frontend Configuration](#query-frontend-configuration)
- [Query Range Configuration](#query-range-configuration)
- [Compactor Configuration](#compactor-configuration)
- [Limits Configuration](#limits-configuration)
- [Ruler Configuration](#ruler-configuration)
- [Pattern Ingester Configuration](#pattern-ingester-configuration)
- [Bloom Configuration](#bloom-configuration)
- [Memberlist Configuration](#memberlist-configuration)
- [Caching Configuration](#caching-configuration)

---

## Server Configuration

The `server` block configures the HTTP and gRPC server settings.

```yaml
server:
  # HTTP server listen address
  # CLI flag: -server.http-listen-address
  [http_listen_address: <string> | default = ""]

  # HTTP server listen port
  # CLI flag: -server.http-listen-port
  [http_listen_port: <int> | default = 3100]

  # gRPC server listen address
  # CLI flag: -server.grpc-listen-address
  [grpc_listen_address: <string> | default = ""]

  # gRPC server listen port
  # CLI flag: -server.grpc-listen-port
  [grpc_listen_port: <int> | default = 9095]

  # Log level: debug, info, warn, error
  # CLI flag: -log.level
  [log_level: <string> | default = "info"]

  # Log format: logfmt, json
  # CLI flag: -log.format
  [log_format: <string> | default = "logfmt"]

  # Timeout for graceful shutdown
  # CLI flag: -server.graceful-shutdown-timeout
  [graceful_shutdown_timeout: <duration> | default = 30s]

  # HTTP server read timeout
  # CLI flag: -server.http-read-timeout
  [http_server_read_timeout: <duration> | default = 30s]

  # HTTP server write timeout
  # CLI flag: -server.http-write-timeout
  [http_server_write_timeout: <duration> | default = 30s]

  # HTTP server idle timeout
  # CLI flag: -server.http-idle-timeout
  [http_server_idle_timeout: <duration> | default = 120s]

  # Maximum number of simultaneous gRPC connections
  # CLI flag: -server.grpc-max-concurrent-streams
  [grpc_server_max_concurrent_streams: <int> | default = 100]

  # TLS configuration for HTTP server
  http_tls_config:
    [cert_file: <string>]
    [key_file: <string>]
    [client_ca_file: <string>]

  # TLS configuration for gRPC server
  grpc_tls_config:
    [cert_file: <string>]
    [key_file: <string>]
    [client_ca_file: <string>]
```

---

## Common Configuration

The `common` block configures shared settings across components.

```yaml
common:
  # Path prefix for data storage
  [path_prefix: <string> | default = ""]

  # Instance address for ring registration
  [instance_addr: <string>]

  # Replication factor for data durability
  # CLI flag: -common.replication-factor
  [replication_factor: <int> | default = 3]

  # Storage configuration
  storage:
    # S3 storage configuration
    s3:
      [s3: <string>]  # s3://region/bucket format
      [s3forcepathstyle: <boolean> | default = false]
      [access_key_id: <string>]
      [secret_access_key: <string>]
      [endpoint: <string>]
      [region: <string>]
      [insecure: <boolean> | default = false]

    # GCS storage configuration
    gcs:
      [bucket_name: <string>]
      [service_account: <string>]
      [chunk_buffer_size: <int>]

    # Azure storage configuration
    azure:
      [container_name: <string>]
      [account_name: <string>]
      [account_key: <string>]
      [use_managed_identity: <boolean> | default = false]
      [user_assigned_id: <string>]

    # Filesystem storage configuration
    filesystem:
      [chunks_directory: <string>]
      [rules_directory: <string>]

  # Ring configuration for service discovery
  ring:
    kvstore:
      # Store type: consul, etcd, memberlist, inmemory
      [store: <string> | default = "memberlist"]
      [prefix: <string> | default = "collectors/"]

      # Consul configuration
      consul:
        [host: <string> | default = "localhost:8500"]
        [acl_token: <string>]

      # Etcd configuration
      etcd:
        [endpoints: <list of strings>]
        [username: <string>]
        [password: <string>]
```

---

## Schema Configuration

The `schema_config` block defines how Loki stores and indexes data. **This is critical and cannot be changed after deployment without migration.**

```yaml
schema_config:
  configs:
    # Date when this schema takes effect (YYYY-MM-DD format)
    - from: <daytime>

      # Index store type: tsdb, boltdb-shipper (deprecated)
      # TSDB is recommended for all new deployments
      [store: <string> | default = "tsdb"]

      # Object store type: s3, gcs, azure, filesystem
      [object_store: <string>]

      # Schema version: v13 is latest and recommended
      [schema: <string> | default = "v13"]

      # Index configuration
      index:
        # Table name prefix
        [prefix: <string> | default = "index_"]
        # Table period (24h recommended)
        [period: <duration> | default = 24h]
```

**Best Practice:** Always use `store: tsdb` and `schema: v13` for new deployments.

---

## Storage Configuration

### Legacy Storage Configuration

```yaml
storage_config:
  # TSDB shipper configuration
  tsdb_shipper:
    [active_index_directory: <string>]
    [cache_location: <string>]
    [cache_ttl: <duration> | default = 24h]
    index_gateway_client:
      [server_address: <string>]

  # AWS/S3 configuration
  aws:
    [s3: <string>]
    [s3forcepathstyle: <boolean>]
    [access_key_id: <string>]
    [secret_access_key: <string>]

  # GCS configuration
  gcs:
    [bucket_name: <string>]

  # Azure configuration
  azure:
    [container_name: <string>]
    [account_name: <string>]
    [account_key: <string>]

  # Filesystem configuration
  filesystem:
    [directory: <string>]
```

### Thanos Object Storage Client (Loki 3.4+)

The Thanos-based storage client provides consistent configuration across Grafana's databases.

```yaml
storage_config:
  # Enable Thanos object storage client
  # MUTUALLY EXCLUSIVE with legacy storage config
  use_thanos_objstore: true

  object_store:
    # Storage prefix for all objects (cannot contain dashes)
    [storage_prefix: <string>]

    # S3 configuration
    s3:
      [bucket_name: <string>]
      [endpoint: <string>]
      [region: <string>]
      [access_key_id: <string>]
      [secret_access_key: <string>]
      [native_aws_auth_enabled: <boolean> | default = false]
      [dualstack_enabled: <boolean> | default = false]
      [storage_class: <string> | default = "STANDARD"]
      [max_retries: <int> | default = 10]

      # HTTP client settings
      http:
        [idle_conn_timeout: <duration> | default = 1m30s]
        [response_header_timeout: <duration> | default = 2m]
        [insecure_skip_verify: <boolean> | default = false]

      # Server-side encryption
      sse:
        [type: <string>]  # SSE-KMS or SSE-S3
        [kms_key_id: <string>]
        [kms_encryption_context: <string>]

    # GCS configuration
    gcs:
      [bucket_name: <string>]
      [service_account: <string>]
      [chunk_buffer_size: <int>]
      [max_retries: <int> | default = 5]

    # Azure configuration
    azure:
      [account_name: <string>]
      [account_key: <string>]
      [container_name: <string>]
      [use_managed_identity: <boolean> | default = false]

    # Filesystem configuration
    filesystem:
      [dir: <string>]  # Note: 'dir' not 'directory'
```

**Migration Notes:**
- `use_thanos_objstore: true` is mutually exclusive with legacy storage config
- `disable_dualstack` → `dualstack_enabled` (inverted logic)
- `signature_version` removed (always uses V4)
- `http_config` → `http` (nested block)
- Storage prefix cannot contain dashes (`-`) - use underscores

---

## Ingester Configuration

The `ingester` block configures log ingestion and chunk management.

```yaml
ingester:
  # Chunk compression algorithm: snappy, gzip, lz4, none
  # CLI flag: -ingester.chunk-encoding
  [chunk_encoding: <string> | default = "snappy"]

  # Flush inactive chunks after this period
  # CLI flag: -ingester.chunk-idle-period
  [chunk_idle_period: <duration> | default = 30m]

  # Keep flushed chunks in memory for this duration
  # CLI flag: -ingester.chunk-retain-period
  [chunk_retain_period: <duration> | default = 15m]

  # Maximum age of a chunk before flushing
  # CLI flag: -ingester.max-chunk-age
  [max_chunk_age: <duration> | default = 2h]

  # Target compressed chunk size (bytes)
  # CLI flag: -ingester.chunk-target-size
  [chunk_target_size: <int> | default = 1572864]  # 1.5MB

  # Number of concurrent chunk flushes
  # CLI flag: -ingester.concurrent-flushes
  [concurrent_flushes: <int> | default = 16]

  # Flush check interval
  # CLI flag: -ingester.flush-check-period
  [flush_check_period: <duration> | default = 30s]

  # WAL (Write-Ahead Log) configuration
  wal:
    [enabled: <boolean> | default = true]
    [dir: <string> | default = "wal"]
    [flush_on_shutdown: <boolean> | default = true]
    [replay_memory_ceiling: <int>]

  # Lifecycler configuration for ring registration
  lifecycler:
    ring:
      kvstore:
        [store: <string>]
      [replication_factor: <int> | default = 3]
    [num_tokens: <int> | default = 128]
    [heartbeat_period: <duration> | default = 5s]
    [join_after: <duration> | default = 0s]
    [observe_period: <duration> | default = 0s]
    [interface_names: <list of strings>]
    [final_sleep: <duration> | default = 30s]
```

**Best Practices:**
- Use `chunk_encoding: snappy` for best speed/compression balance
- Target 1.5MB chunks requires 5-10x raw log data
- Set `replication_factor: 3` for production

---

## Distributor Configuration

The `distributor` block configures log distribution to ingesters.

```yaml
distributor:
  ring:
    kvstore:
      [store: <string>]
    [heartbeat_timeout: <duration> | default = 1m]

  # OTLP configuration for default resource attributes
  otlp_config:
    # Override default list of resource attributes promoted to index labels
    # Excludes high-cardinality attributes like k8s.pod.name, service.instance.id
    default_resource_attributes_as_index_labels:
      - service.name
      - service.namespace
      - deployment.environment
      - cloud.region
      - cloud.availability_zone
      - k8s.cluster.name
      - k8s.namespace.name
      - k8s.container.name
      - container.name
      - k8s.deployment.name
      - k8s.statefulset.name
      - k8s.daemonset.name
      - k8s.cronjob.name
      - k8s.job.name

  # Ingest limits (Loki 3.5+)
  [ingest_limits_enabled: <boolean> | default = false]
  [ingest_limits_dry_run_enabled: <boolean> | default = false]
```

---

## Querier Configuration

The `querier` block configures log query processing.

```yaml
querier:
  # Maximum concurrent queries per querier
  # CLI flag: -querier.max-concurrent
  [max_concurrent: <int> | default = 4]

  # Query timeout
  # CLI flag: -querier.query-timeout
  [query_timeout: <duration> | default = 1m]

  # Maximum duration for live tailing
  # CLI flag: -querier.tail-max-duration
  [tail_max_duration: <duration> | default = 1h]

  # Extra delay before sending queries to storage
  # CLI flag: -querier.extra-query-delay
  [extra_query_delay: <duration> | default = 0s]

  # Multi-tenant queries (requires auth_enabled: false)
  [multi_tenant_queries_enabled: <boolean> | default = false]

  # Engine configuration
  engine:
    [timeout: <duration> | default = 5m]
    [max_look_back_period: <duration> | default = 30s]
```

---

## Query Frontend Configuration

The `frontend` block configures the query frontend.

```yaml
frontend:
  # Maximum outstanding requests per tenant
  # CLI flag: -querier.max-outstanding-requests-per-tenant
  [max_outstanding_per_tenant: <int> | default = 2048]

  # Compress HTTP responses
  # CLI flag: -querier.compress-http-responses
  [compress_responses: <boolean> | default = true]

  # Response encoding: protobuf (recommended) or json
  [encoding: <string> | default = "protobuf"]

  # Log queries longer than this duration
  # CLI flag: -frontend.log-queries-longer-than
  [log_queries_longer_than: <duration> | default = 0s]

  # Downstream URL for query processing
  [downstream_url: <string>]
```

---

## Query Range Configuration

The `query_range` block configures query splitting and caching.

```yaml
query_range:
  # Align queries with step intervals
  # CLI flag: -querier.align-queries-with-step
  [align_queries_with_step: <boolean> | default = false]

  # Maximum retries for failed queries
  # CLI flag: -querier.max-retries
  [max_retries: <int> | default = 5]

  # Enable parallel execution of shardable queries
  # CLI flag: -querier.parallelise-shardable-queries
  [parallelise_shardable_queries: <boolean> | default = true]

  # Cache query results
  [cache_results: <boolean> | default = false]

  # Results cache configuration
  results_cache:
    cache:
      # Embedded cache
      embedded_cache:
        [enabled: <boolean> | default = false]
        [max_size_mb: <int> | default = 100]
        [ttl: <duration> | default = 1h]

      # Memcached client
      memcached_client:
        [host: <string>]
        [service: <string>]
        [timeout: <duration> | default = 500ms]
        [max_idle_conns: <int> | default = 16]
        [update_interval: <duration> | default = 1m]
        [consistent_hash: <boolean> | default = true]

      # Redis client
      redis:
        [endpoint: <string>]
        [timeout: <duration>]
        [expiration: <duration>]
```

---

## Compactor Configuration

The `compactor` block configures index compaction and retention.

```yaml
compactor:
  # Directory for compaction work
  # CLI flag: -boltdb.shipper.compactor.working-directory
  [working_directory: <string>]

  # How often to run compaction
  # CLI flag: -boltdb.shipper.compactor.compaction-interval
  [compaction_interval: <duration> | default = 10m]

  # Enable retention enforcement
  # CLI flag: -compactor.retention-enabled
  [retention_enabled: <boolean> | default = false]

  # Delay before deleting expired data
  # CLI flag: -compactor.retention-delete-delay
  [retention_delete_delay: <duration> | default = 2h]

  # Number of parallel deletion workers
  # CLI flag: -compactor.retention-delete-worker-count
  [retention_delete_worker_count: <int> | default = 150]

  # Delete request store backend (Loki 3.5+)
  # Options: boltdb, sqlite, s3, gcs, azure
  # SQLite recommended over BoltDB for better query optimization
  [delete_request_store: <string>]

  # Horizontally Scalable Compactor (Loki 3.6+)
  # Modes: disabled (default), main, worker
  [horizontal_scaling_mode: <string> | default = "disabled"]

  # Jobs configuration (for horizontal scaling)
  jobs_config:
    deletion:
      [deletion_manifest_store_prefix: <string> | default = "__deletion_manifest__/"]
      [timeout: <duration> | default = 15m]
      [max_retries: <int> | default = 3]
      [chunk_processing_concurrency: <int> | default = 3]

  # Worker configuration (for horizontal scaling worker mode)
  worker_config:
    [num_sub_workers: <int> | default = 0]  # 0 = use CPU core count
```

**Horizontal Compactor Modes (Loki 3.6+):**
- `disabled`: Traditional single compactor behavior
- `main`: Distributes deletion work to workers; requires disk access
- `worker`: Processes deletion jobs from main compactor via gRPC

---

## Limits Configuration

The `limits_config` block sets rate limits and resource constraints.

```yaml
limits_config:
  # --- Ingestion Limits ---

  # Maximum ingestion rate (MB/s) per tenant
  # CLI flag: -distributor.ingestion-rate-limit-mb
  [ingestion_rate_mb: <float> | default = 4]

  # Maximum burst size (MB) per tenant
  # CLI flag: -distributor.ingestion-burst-size-mb
  [ingestion_burst_size_mb: <float> | default = 6]

  # Maximum log line size
  # CLI flag: -distributor.max-line-size
  [max_line_size: <int> | default = 256KB]

  # Truncate oversized lines instead of rejecting
  # CLI flag: -distributor.max-line-size-truncate
  [max_line_size_truncate: <boolean> | default = false]

  # --- Stream Limits ---

  # Maximum streams per tenant
  # CLI flag: -ingester.max-streams-per-user
  [max_streams_per_user: <int> | default = 10000]

  # Maximum global streams per tenant (across all ingesters)
  # CLI flag: -ingester.max-global-streams-per-user
  [max_global_streams_per_user: <int> | default = 5000]

  # Maximum label name length
  # CLI flag: -validation.max-length-label-name
  [max_label_name_length: <int> | default = 1024]

  # Maximum label value length
  # CLI flag: -validation.max-length-label-value
  [max_label_value_length: <int> | default = 2048]

  # Maximum labels per stream (reduced to 15 in Loki 3.0)
  # CLI flag: -validation.max-label-names-per-series
  [max_label_names_per_series: <int> | default = 15]

  # --- Query Limits ---

  # Maximum entries returned per query
  # CLI flag: -querier.max-entries-limit-per-query
  [max_entries_limit_per_query: <int> | default = 5000]

  # Maximum query time range
  # CLI flag: -querier.max-query-length
  [max_query_length: <duration> | default = 721h]

  # Maximum parallel sub-queries
  # CLI flag: -querier.max-query-parallelism
  [max_query_parallelism: <int> | default = 32]

  # Maximum series per query
  [max_query_series: <int> | default = 500]

  # Maximum chunks per query
  [max_chunks_per_query: <int> | default = 2000000]

  # Query splitting interval (moved from query_range in 2.5.0)
  # CLI flag: -querier.split-queries-by-interval
  [split_queries_by_interval: <duration> | default = 30m]

  # --- Retention ---

  # Global retention period (requires compactor.retention_enabled)
  # CLI flag: -limits.retention-period
  [retention_period: <duration> | default = 0]

  # Per-stream retention (optional)
  retention_stream:
    - selector: '{namespace="prod"}'
      priority: 1
      period: 720h  # 30 days

  # --- Structured Metadata (Loki 2.9+) ---

  # Enable structured metadata
  # CLI flag: -validation.allow-structured-metadata
  [allow_structured_metadata: <boolean> | default = true]

  # Maximum size per log line
  # CLI flag: -limits.max-structured-metadata-size
  [max_structured_metadata_size: <int> | default = 64KB]

  # Maximum entries per log line
  # CLI flag: -limits.max-structured-metadata-entries-count
  [max_structured_metadata_entries_count: <int> | default = 128]

  # --- Volume API ---

  # Enable volume endpoints for Explore Logs / Grafana Drilldown
  [volume_enabled: <boolean> | default = true]

  # --- OTLP Configuration (Loki 3.0+) ---

  otlp_config:
    resource_attributes:
      # Override default resource attributes list
      [ignore_defaults: <boolean> | default = false]

      # Attribute configuration
      attributes_config:
        - action: index_label  # or structured_metadata, drop
          attributes:
            - service.name
            - service.namespace
        - action: structured_metadata
          attributes:
            - k8s.pod.name
            - service.instance.id
        - action: structured_metadata
          regex: "cloud.*"

    # Scope attributes configuration
    scope_attributes:
      - action: drop
        attributes:
          - otel.library.name

    # Log attributes configuration
    log_attributes:
      - action: structured_metadata
        attributes:
          - trace_id
          - span_id
      - action: drop
        regex: "internal.*"

    # Store severity_text as index label (NOT recommended)
    # CLI flag: -limits.otlp-config.severity-text-as-label
    [severity_text_as_label: <boolean> | default = false]

  # --- Time Sharding for Out-of-Order Ingestion (Loki 3.4+) ---

  shard_streams:
    [enabled: <boolean> | default = false]
    [time_sharding_enabled: <boolean> | default = false]

  # --- Enforced Labels (Experimental) ---

  # Labels that must be present in every stream
  # CLI flag: -validation.enforced-labels
  [enforced_labels: <list of strings> | default = []]

  # Policy-based enforced labels
  # The '*' policy applies to all streams
  policy_enforced_labels:
    finance:
      - cost_center
    ops:
      - team
    '*':
      - service.name

  # Policy to stream selector mapping
  policy_stream_mapping:
    finance:
      - selector: '{namespace="prod", container="billing"}'
        priority: 2
    ops:
      - selector: '{namespace="prod", container="ops"}'
        priority: 1

  # --- Block Ingestion ---

  # Block ingestion until date (RFC3339 format)
  # CLI flag: -limits.block-ingestion-until
  [block_ingestion_until: <time> | default = 0]

  # Block ingestion per policy until date
  [block_ingestion_policy_until: <map of string to Time>]

  # HTTP status code when blocked (260 default, 200 for silent)
  # CLI flag: -limits.block-ingestion-status-code
  [block_ingestion_status_code: <int> | default = 260]

  # --- Bloom Filters (Experimental, Loki 3.0+) ---

  [bloom_creation_enabled: <boolean> | default = false]
  [bloom_split_series_keyspace_by: <int> | default = 1024]
  [bloom_gateway_enable_filtering: <boolean> | default = false]
  [tsdb_sharding_strategy: <string>]  # Use "bounded" for blooms

  # --- Metric Aggregation ---

  # Enable metric aggregation for faster histogram queries
  # CLI flag: -limits.metric-aggregation-enabled
  [metric_aggregation_enabled: <boolean> | default = false]

  # --- Ruler Limits ---

  [ruler_max_rules_per_rule_group: <int> | default = 100]
  [ruler_max_rule_groups_per_tenant: <int> | default = 50]
```

---

## Ruler Configuration

The `ruler` block configures alerting and recording rules.

```yaml
ruler:
  # Rule evaluation interval
  # CLI flag: -ruler.evaluation-interval
  [evaluation_interval: <duration> | default = 1m]

  # Rule polling interval
  # CLI flag: -ruler.poll-interval
  [poll_interval: <duration> | default = 1m]

  # Storage configuration
  storage:
    # Storage type: local, s3, gcs, azure
    [type: <string>]

    local:
      [directory: <string> | default = "/rules"]

    s3:
      [bucket_name: <string>]
      [region: <string>]

    gcs:
      [bucket_name: <string>]

    azure:
      [container_name: <string>]
      [account_name: <string>]

  # Temporary rule file path
  [rule_path: <string> | default = "/rules"]

  # Alertmanager URL
  # CLI flag: -ruler.alertmanager-url
  [alertmanager_url: <string>]

  # Use Alertmanager API v2 (default since Loki 3.2.0)
  # CLI flag: -ruler.enable-alertmanager-v2
  [enable_alertmanager_v2: <boolean> | default = true]

  # Enable ruler API for rule management
  # CLI flag: -ruler.enable-api
  [enable_api: <boolean> | default = false]

  # Enable rule sharding across instances
  # CLI flag: -ruler.enable-sharding
  [enable_sharding: <boolean> | default = false]

  # Ring configuration for sharding
  ring:
    kvstore:
      [store: <string>]

  # Alert timing
  [for_outage_tolerance: <duration> | default = 1h]
  [for_grace_period: <duration> | default = 10m]
  [resend_delay: <duration> | default = 1m]

  # Remote write for recording rules
  remote_write:
    [enabled: <boolean> | default = false]
    client:
      [url: <string>]
      [remote_timeout: <duration> | default = 30s]

  # Alertmanager client configuration
  alertmanager_client:
    tls_config:
      [ca_path: <string>]
      [cert_path: <string>]
      [key_path: <string>]
    [basic_auth_username: <string>]
    [basic_auth_password: <string>]
```

**Rule File Structure:**
```
/rules/<tenant-id>/rules1.yaml
                   /rules2.yaml
```

---

## Pattern Ingester Configuration

The `pattern_ingester` block configures automatic log pattern detection (Loki 3.0+).

```yaml
pattern_ingester:
  # Enable pattern detection
  [enabled: <boolean> | default = false]

  # Metric aggregation configuration
  metric_aggregation:
    [enabled: <boolean> | default = false]
    [loki_address: <string>]
```

---

## Bloom Configuration

Bloom filters accelerate "needle in haystack" queries on structured metadata (Loki 3.0+).

> **Warning:** Experimental feature for deployments ingesting >75TB/month.

> **Breaking Change (Loki 3.3+):** Bloom filters use structured metadata only (not free-text). Delete existing bloom blocks before upgrading.

```yaml
# Bloom build configuration
bloom_build:
  [enabled: <boolean> | default = false]
  planner:
    [planning_interval: <duration> | default = 6h]
    [bloom_split_series_keyspace_by: <int> | default = 1024]
  builder:
    [planner_address: <string>]

# Bloom gateway configuration
bloom_gateway:
  [enabled: <boolean> | default = false]
  client:
    [addresses: <string>]
  [worker_concurrency: <int> | default = 4]
  [block_query_concurrency: <int> | default = 8]
  [max_query_page_size: <int> | default = 64MiB]

# Bloom shipper configuration
bloom_shipper:
  [working_directory: <string>]
```

---

## Memberlist Configuration

The `memberlist` block configures gossip-based cluster coordination.

```yaml
memberlist:
  # Addresses of other nodes to join
  join_members:
    - loki-memberlist

  # Port for gossip messages
  # CLI flag: -memberlist.bind-port
  [bind_port: <int> | default = 7946]

  # Address to advertise to other nodes
  [advertise_addr: <string>]

  # Port to advertise
  [advertise_port: <int>]

  # Timeout for establishing a stream connection
  [stream_timeout: <duration> | default = 2s]

  # Interval between gossip messages
  [gossip_interval: <duration> | default = 200ms]

  # Number of random nodes to gossip to
  [gossip_nodes: <int> | default = 3]
```

---

## Caching Configuration

### Chunk Cache

```yaml
chunk_store_config:
  chunk_cache_config:
    memcached:
      [batch_size: <int> | default = 256]
      [parallelism: <int> | default = 10]
    memcached_client:
      [host: <string>]
      [service: <string>]
      [timeout: <duration> | default = 500ms]
      [max_idle_conns: <int> | default = 100]
```

### Results Cache

```yaml
query_range:
  cache_results: true
  results_cache:
    cache:
      memcached_client:
        [host: <string>]
        [service: <string>]
        [timeout: <duration> | default = 500ms]
        [max_idle_conns: <int> | default = 100]
        [consistent_hash: <boolean> | default = true]
        [update_interval: <duration> | default = 1m]
```

**Note:** TSDB does NOT need index cache - only chunks and results cache.

---

## Additional Resources

- [Grafana Loki Configuration](https://grafana.com/docs/loki/latest/configure/)
- [Grafana Loki Best Practices](https://grafana.com/docs/loki/latest/configure/bp-configure/)
- [Loki HTTP API Reference](https://grafana.com/docs/loki/latest/reference/loki-http-api/)
- [Loki Helm Chart Values](https://grafana.com/docs/loki/latest/setup/install/helm/reference/)