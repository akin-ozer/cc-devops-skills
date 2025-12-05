#!/usr/bin/env python3
"""
Loki Configuration Generator

Generates production-ready Loki configurations based on deployment mode and requirements.
Supports monolithic, simple scalable, and microservices modes with various storage backends.
"""

import argparse
import sys
from typing import Dict, Optional


class LokiConfigGenerator:
    """Generates Loki configuration files."""

    def __init__(self):
        self.deployment_modes = {
            "monolithic": self._generate_monolithic,
            "simple-scalable": self._generate_simple_scalable,
            "microservices": self._generate_microservices,
        }

        self.storage_backends = {
            "filesystem": self._generate_filesystem_storage,
            "s3": self._generate_s3_storage,
            "gcs": self._generate_gcs_storage,
            "azure": self._generate_azure_storage,
        }

    def generate(self, mode: str, storage: str, **kwargs) -> str:
        """Generate configuration for specified deployment mode and storage."""
        if mode not in self.deployment_modes:
            raise ValueError(f"Unknown deployment mode: {mode}")
        if storage not in self.storage_backends:
            raise ValueError(f"Unknown storage backend: {storage}")

        return self.deployment_modes[mode](storage, **kwargs)

    def _generate_common_config(
        self,
        auth_enabled: bool = True,
        log_level: str = "info",
        **kwargs
    ) -> str:
        """Generate common configuration sections."""
        return f"""auth_enabled: {str(auth_enabled).lower()}

server:
  http_listen_port: 3100
  grpc_listen_port: 9096
  log_level: {log_level}
  log_format: logfmt
  graceful_shutdown_timeout: 30s
"""

    def _generate_schema_config(
        self,
        storage_type: str,
        from_date: str = "2025-01-01",
    ) -> str:
        """Generate schema configuration."""
        return f"""
schema_config:
  configs:
    - from: {from_date}
      store: tsdb
      object_store: {storage_type}
      schema: v13
      index:
        prefix: loki_index_
        period: 24h
"""

    def _generate_limits_config(
        self,
        ingestion_rate_mb: int = 10,
        max_streams: int = 10000,
        retention_days: int = 30,
    ) -> str:
        """Generate limits configuration."""
        return f"""
limits_config:
  # Ingestion limits
  ingestion_rate_mb: {ingestion_rate_mb}
  ingestion_burst_size_mb: {ingestion_rate_mb * 2}
  max_line_size: 256KB
  max_line_size_truncate: true

  # Stream limits
  max_streams_per_user: {max_streams}
  max_global_streams_per_user: {max_streams * 10}

  # Query limits
  max_entries_limit_per_query: 5000
  max_query_length: 721h
  max_query_parallelism: 32
  max_query_series: 500

  # Retention
  retention_period: {retention_days}d

  # Chunks
  max_chunks_per_query: 2000000

  # Structured metadata (Loki 2.9+)
  allow_structured_metadata: true
  max_structured_metadata_size: 64KB
  max_structured_metadata_entries_count: 128

  # Volume API
  volume_enabled: true
"""

    def _generate_pattern_ingester_config(self) -> str:
        """Generate pattern ingester configuration (Loki 3.0+)."""
        return """
# Pattern Ingester (Loki 3.0+)
pattern_ingester:
  enabled: true
"""

    def _generate_otlp_config(self) -> str:
        """Generate OTLP configuration for limits_config (Loki 3.0+).

        Note: k8s.pod.name and service.instance.id are NOT included as index labels
        due to high cardinality. They should be stored as structured_metadata instead.
        """
        return """
  # OTLP Configuration (Loki 3.0+)
  # IMPORTANT: k8s.pod.name and service.instance.id are NOT index labels (high cardinality)
  # See: https://grafana.com/docs/loki/latest/get-started/labels/remove-default-labels/
  otlp_config:
    resource_attributes:
      ignore_defaults: false
      attributes_config:
        - action: index_label
          attributes:
            - service.name
            - service.namespace
            - deployment.environment
        - action: structured_metadata
          attributes:
            - k8s.pod.name         # High cardinality - stored as structured metadata
            - service.instance.id  # High cardinality - stored as structured metadata
    log_attributes:
      - action: structured_metadata
        attributes:
          - trace_id
          - span_id
"""

    def _generate_time_sharding_config(self) -> str:
        """Generate time sharding configuration for out-of-order ingestion (Loki 3.4+)."""
        return """
  # Time Sharding for out-of-order ingestion (Loki 3.4+)
  shard_streams:
    time_sharding_enabled: true
"""

    def _generate_thanos_s3_storage(
        self,
        bucket: str = "loki-bucket",
        region: str = "us-east-1",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate Thanos-based S3 storage configuration (Loki 3.4+)."""
        return f"""
# Thanos Object Storage Client (Loki 3.4+)
storage_config:
  use_thanos_objstore: true
  object_store:
    s3:
      bucket_name: {bucket}
      endpoint: s3.{region}.amazonaws.com
      region: {region}
      # Authentication via IAM role (recommended)
      # Or use: access_key_id and secret_access_key
      native_aws_auth_enabled: true
      dualstack_enabled: true
      max_retries: 10

common:
  path_prefix: /loki
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_thanos_gcs_storage(
        self,
        bucket: str = "loki-bucket",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate Thanos-based GCS storage configuration (Loki 3.4+)."""
        return f"""
# Thanos Object Storage Client (Loki 3.4+)
storage_config:
  use_thanos_objstore: true
  object_store:
    gcs:
      bucket_name: {bucket}
      # Authentication via GOOGLE_APPLICATION_CREDENTIALS or service account

common:
  path_prefix: /loki
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_thanos_azure_storage(
        self,
        container: str = "loki-container",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate Thanos-based Azure storage configuration (Loki 3.4+)."""
        return f"""
# Thanos Object Storage Client (Loki 3.4+)
storage_config:
  use_thanos_objstore: true
  object_store:
    azure:
      account_name: ${{AZURE_ACCOUNT_NAME}}
      account_key: ${{AZURE_ACCOUNT_KEY}}
      container_name: {container}
      # Or use managed identity:
      # use_managed_identity: true

common:
  path_prefix: /loki
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_frontend_config(self, encoding: str = "protobuf") -> str:
        """Generate query frontend configuration."""
        return f"""
query_frontend:
  max_outstanding_per_tenant: 4096
  compress_responses: true
  encoding: {encoding}  # Recommended for performance
"""

    def _generate_ingester_config(self, zone_awareness: bool = False) -> str:
        """Generate ingester configuration.

        Args:
            zone_awareness: Enable zone-aware replication for multi-AZ deployments
        """
        config = """
ingester:
  chunk_encoding: snappy
  chunk_idle_period: 30m
  chunk_retain_period: 15m
  max_chunk_age: 2h
  chunk_target_size: 1572864  # 1.5MB"""

        if zone_awareness:
            config += """

  # Zone-aware replication (CRITICAL for multi-AZ production deployments)
  lifecycler:
    ring:
      replication_factor: 3
      zone_awareness_enabled: true  # Ensures replicas spread across AZs

# Set zone via environment variable in Kubernetes:
# env:
#   - name: AVAILABILITY_ZONE
#     valueFrom:
#       fieldRef:
#         fieldPath: metadata.labels['topology.kubernetes.io/zone']
common:
  instance_availability_zone: ${AVAILABILITY_ZONE}
"""
        else:
            config += "\n"

        return config

    def _generate_compactor_config(
        self,
        delete_request_store: str = None,
        horizontal_scaling: str = "disabled"
    ) -> str:
        """Generate compactor configuration.

        Args:
            delete_request_store: Storage for delete requests (boltdb, sqlite, or same as object storage)
            horizontal_scaling: Horizontal scaling mode (disabled, main, worker) - Loki 3.6+
        """
        config = """
compactor:
  working_directory: /loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  retention_delete_worker_count: 150"""

        # Add delete_request_store if specified (Loki 3.5+)
        if delete_request_store:
            config += f"\n  delete_request_store: {delete_request_store}  # Loki 3.5+"

        # Add horizontal scaling configuration (Loki 3.6+)
        if horizontal_scaling == "main":
            config += """
  # Horizontally Scalable Compactor - Main Mode (Loki 3.6+)
  horizontal_scaling_mode: main
  jobs_config:
    deletion:
      deletion_manifest_store_prefix: "__deletion_manifest__/"
      timeout: 15m
      max_retries: 3"""
        elif horizontal_scaling == "worker":
            config += """
  # Horizontally Scalable Compactor - Worker Mode (Loki 3.6+)
  horizontal_scaling_mode: worker
  jobs_config:
    deletion:
      chunk_processing_concurrency: 3
  worker_config:
    num_sub_workers: 0  # 0 = use CPU core count"""

        config += "\n"
        return config

    def _generate_ruler_config(
        self,
        storage_type: str = "s3",
        bucket: str = "loki-ruler-bucket",
        alertmanager_url: str = "http://alertmanager:9093",
        enable_remote_write: bool = False,
        remote_write_url: str = "http://prometheus:9090/api/v1/write",
        **kwargs
    ) -> str:
        """Generate ruler configuration for alerting and recording rules."""
        config = f"""
# Ruler Configuration (Alerting & Recording Rules)
ruler:
  storage:
    type: {storage_type}
    {storage_type}:
      bucket_name: {bucket}"""

        if storage_type == "s3":
            config += f"""
      region: {kwargs.get('region', 'us-east-1')}"""

        config += f"""

  rule_path: /loki/rules-temp
  alertmanager_url: {alertmanager_url}
  enable_alertmanager_v2: true  # Default since Loki 3.2.0
  enable_api: true
  enable_sharding: true
  ring:
    kvstore:
      store: memberlist

  # Rule evaluation settings
  evaluation_interval: 1m
  poll_interval: 1m"""

        if enable_remote_write:
            config += f"""

  # Remote write recording rule metrics to Prometheus
  remote_write:
    enabled: true
    client:
      url: {remote_write_url}"""

        config += "\n"
        return config

    def _generate_distributor_dry_run_config(self) -> str:
        """Generate distributor dry-run mode configuration (Loki 3.5+)."""
        return """
distributor:
  # Dry-run mode for limits (Loki 3.5+)
  # Logs would-be rejections without rejecting - useful for testing limits
  ingest_limits_enabled: true
  ingest_limits_dry_run_enabled: true
"""

    def _generate_querier_config(self, max_concurrent: int = 4) -> str:
        """Generate querier configuration."""
        return f"""
querier:
  max_concurrent: {max_concurrent}
  query_timeout: 5m
"""

    def _generate_filesystem_storage(self, **kwargs) -> str:
        """Generate filesystem storage configuration."""
        return """
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory
"""

    def _generate_s3_storage(
        self,
        bucket: str = "loki-bucket",
        region: str = "us-east-1",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate S3 storage configuration."""
        return f"""
common:
  path_prefix: /loki
  storage:
    s3:
      s3: s3://{region}/{bucket}
      s3forcepathstyle: false
      # Authentication via IAM role (recommended)
      # Or use environment variables: S3_ACCESS_KEY_ID, S3_SECRET_ACCESS_KEY
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_gcs_storage(
        self,
        bucket: str = "loki-bucket",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate GCS storage configuration."""
        return f"""
common:
  path_prefix: /loki
  storage:
    gcs:
      bucket_name: {bucket}
      # Authentication via service account (mounted as file)
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_azure_storage(
        self,
        container: str = "loki-container",
        replication: int = 3,
        **kwargs
    ) -> str:
        """Generate Azure storage configuration."""
        return f"""
common:
  path_prefix: /loki
  storage:
    azure:
      container_name: {container}
      account_name: ${{AZURE_ACCOUNT_NAME}}
      account_key: ${{AZURE_ACCOUNT_KEY}}
  replication_factor: {replication}
  ring:
    kvstore:
      store: memberlist

memberlist:
  join_members:
    - loki-memberlist
"""

    def _generate_monolithic(self, storage: str, **kwargs) -> str:
        """Generate monolithic (single binary) configuration."""
        auth_enabled = kwargs.get("auth_enabled", False)
        log_level = kwargs.get("log_level", "info")
        ingestion_rate = kwargs.get("ingestion_rate_mb") or 10
        max_streams = kwargs.get("max_streams") or 10000
        retention_days = kwargs.get("retention_days") or 30
        pattern_ingester = kwargs.get("pattern_ingester", True)

        storage_type = "filesystem" if storage == "filesystem" else "s3" if storage == "s3" else "gcs" if storage == "gcs" else "azure"

        config = self._generate_common_config(auth_enabled, log_level)
        config += self.storage_backends[storage](**kwargs)
        config += self._generate_schema_config(storage_type)
        config += self._generate_limits_config(ingestion_rate, max_streams, retention_days)
        if pattern_ingester:
            config += self._generate_pattern_ingester_config()
        config += self._generate_compactor_config()
        config += self._generate_ingester_config()

        return config

    def _generate_simple_scalable(self, storage: str, **kwargs) -> str:
        """Generate simple scalable configuration."""
        auth_enabled = kwargs.get("auth_enabled", True)
        log_level = kwargs.get("log_level", "info")
        ingestion_rate = kwargs.get("ingestion_rate_mb") or 50
        max_streams = kwargs.get("max_streams") or 100000
        retention_days = kwargs.get("retention_days") or 90
        max_concurrent = kwargs.get("max_concurrent") or 4
        pattern_ingester = kwargs.get("pattern_ingester", True)
        otlp_enabled = kwargs.get("otlp_enabled", False)
        frontend_encoding = kwargs.get("frontend_encoding", "protobuf")
        thanos_storage = kwargs.get("thanos_storage", False)
        time_sharding = kwargs.get("time_sharding", False)
        zone_awareness = kwargs.get("zone_awareness", False)

        storage_type = "filesystem" if storage == "filesystem" else "s3" if storage == "s3" else "gcs" if storage == "gcs" else "azure"

        config = self._generate_common_config(auth_enabled, log_level)

        # Use Thanos storage if requested (Loki 3.4+)
        if thanos_storage and storage != "filesystem":
            if storage == "s3":
                config += self._generate_thanos_s3_storage(**kwargs)
            elif storage == "gcs":
                config += self._generate_thanos_gcs_storage(**kwargs)
            elif storage == "azure":
                config += self._generate_thanos_azure_storage(**kwargs)
        else:
            config += self.storage_backends[storage](**kwargs)

        config += self._generate_schema_config(storage_type)
        limits_config = self._generate_limits_config(ingestion_rate, max_streams, retention_days)
        if otlp_enabled:
            limits_config = limits_config.rstrip() + self._generate_otlp_config()
        if time_sharding:
            limits_config = limits_config.rstrip() + self._generate_time_sharding_config()
        config += limits_config
        if pattern_ingester:
            config += self._generate_pattern_ingester_config()

        # Compactor with optional 3.5+ and 3.6+ features
        delete_request_store = kwargs.get("delete_request_store")
        horizontal_compactor = kwargs.get("horizontal_compactor", "disabled")
        config += self._generate_compactor_config(
            delete_request_store=delete_request_store,
            horizontal_scaling=horizontal_compactor
        )
        config += self._generate_ingester_config(zone_awareness=zone_awareness)
        config += self._generate_querier_config(max_concurrent)

        # Add query frontend config
        config += f"""
query_frontend:
  max_outstanding_per_tenant: 4096
  compress_responses: true
  encoding: {frontend_encoding}

query_range:
  parallelise_shardable_queries: true
  cache_results: true
"""

        return config

    def _generate_microservices(self, storage: str, **kwargs) -> str:
        """Generate microservices (distributed) configuration."""
        auth_enabled = kwargs.get("auth_enabled", True)
        log_level = kwargs.get("log_level", "info")
        ingestion_rate = kwargs.get("ingestion_rate_mb") or 100
        max_streams = kwargs.get("max_streams") or 500000
        retention_days = kwargs.get("retention_days") or 180
        max_concurrent = kwargs.get("max_concurrent") or 16

        storage_type = "filesystem" if storage == "filesystem" else "s3" if storage == "s3" else "gcs" if storage == "gcs" else "azure"

        config = self._generate_common_config(auth_enabled, log_level)

        # For microservices, use consul for coordination
        if storage == "s3":
            config += f"""
common:
  path_prefix: /loki
  storage:
    s3:
      s3: s3://{kwargs.get('region', 'us-east-1')}/{kwargs.get('bucket', 'loki-bucket')}
      s3forcepathstyle: false
  replication_factor: 3
  ring:
    kvstore:
      store: consul
      consul:
        host: consul:8500
"""
        else:
            config += self.storage_backends[storage](**kwargs)
            config = config.replace("memberlist", "consul\n      consul:\n        host: consul:8500")

        config += self._generate_schema_config(storage_type)

        # Enhanced limits for microservices
        config += f"""
limits_config:
  ingestion_rate_mb: {ingestion_rate}
  ingestion_burst_size_mb: {ingestion_rate * 2}
  max_line_size: 256KB
  max_line_size_truncate: true
  max_streams_per_user: {max_streams}
  max_global_streams_per_user: {max_streams * 2}
  max_entries_limit_per_query: 5000
  max_query_length: 721h
  max_query_parallelism: 64
  retention_period: {retention_days}d
  allow_structured_metadata: true
  volume_enabled: true
  split_queries_by_interval: 15m
"""

        config += self._generate_compactor_config()
        config += self._generate_ingester_config()

        # Add distributor config
        config += """
distributor:
  ring:
    kvstore:
      store: consul
"""

        config += self._generate_querier_config(max_concurrent)

        # Add query frontend and scheduler
        config += """
query_frontend:
  max_outstanding_per_tenant: 8192
  compress_responses: true

query_scheduler:
  max_outstanding_requests_per_tenant: 800

index_gateway:
  mode: ring
"""

        return config


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Loki configurations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--mode",
        required=True,
        choices=["monolithic", "simple-scalable", "microservices"],
        help="Deployment mode",
    )

    parser.add_argument(
        "--storage",
        required=True,
        choices=["filesystem", "s3", "gcs", "azure"],
        help="Storage backend",
    )

    parser.add_argument(
        "--output",
        default="loki-config.yaml",
        help="Output file path (default: loki-config.yaml)",
    )

    # Common options
    parser.add_argument(
        "--auth-enabled",
        action="store_true",
        default=None,
        help="Enable multi-tenancy (default: false for monolithic, true for others)",
    )
    parser.add_argument("--log-level", default="info", choices=["error", "warn", "info", "debug"], help="Log level")
    parser.add_argument("--ingestion-rate-mb", type=int, help="Ingestion rate limit (MB/s)")
    parser.add_argument("--max-streams", type=int, help="Max streams per tenant")
    parser.add_argument("--retention-days", type=int, help="Log retention period (days)")
    parser.add_argument("--max-concurrent", type=int, help="Max concurrent queries per querier")

    # Storage-specific options
    parser.add_argument("--bucket", help="S3/GCS bucket name")
    parser.add_argument("--container", help="Azure container name")
    parser.add_argument("--region", default="us-east-1", help="AWS region (for S3)")
    parser.add_argument("--replication", type=int, default=3, help="Replication factor")

    # Loki 3.0+ features
    parser.add_argument(
        "--pattern-ingester",
        action="store_true",
        default=True,
        help="Enable Pattern Ingester (Loki 3.0+, default: true)",
    )
    parser.add_argument(
        "--no-pattern-ingester",
        action="store_false",
        dest="pattern_ingester",
        help="Disable Pattern Ingester",
    )
    parser.add_argument(
        "--otlp-enabled",
        action="store_true",
        default=False,
        help="Enable OTLP configuration (Loki 3.0+)",
    )
    parser.add_argument(
        "--frontend-encoding",
        default="protobuf",
        choices=["protobuf", "json"],
        help="Query frontend encoding (default: protobuf)",
    )

    # Loki 3.4+ features
    parser.add_argument(
        "--thanos-storage",
        action="store_true",
        default=False,
        help="Use Thanos-based storage clients (Loki 3.4+, opt-in, will become default in future)",
    )
    parser.add_argument(
        "--time-sharding",
        action="store_true",
        default=False,
        help="Enable time sharding for out-of-order log ingestion (Loki 3.4+)",
    )

    # Loki 3.5+ features
    parser.add_argument(
        "--delete-request-store",
        default=None,
        choices=["boltdb", "sqlite", "s3", "gcs", "azure"],
        help="Delete request store backend (Loki 3.5+: sqlite recommended over boltdb)",
    )
    parser.add_argument(
        "--limits-dry-run",
        action="store_true",
        default=False,
        help="Enable dry-run mode for limits (Loki 3.5+, logs rejections without rejecting)",
    )

    # Loki 3.6+ features
    parser.add_argument(
        "--horizontal-compactor",
        default="disabled",
        choices=["disabled", "main", "worker"],
        help="Horizontal compactor scaling mode (Loki 3.6+): disabled (default), main, or worker",
    )

    # High Availability options
    parser.add_argument(
        "--zone-awareness",
        action="store_true",
        default=False,
        help="Enable zone-aware replication for multi-AZ production deployments (CRITICAL for HA)",
    )

    # Ruler configuration
    parser.add_argument(
        "--ruler",
        action="store_true",
        default=False,
        help="Enable ruler configuration for alerting and recording rules",
    )
    parser.add_argument(
        "--ruler-bucket",
        default=None,
        help="Ruler storage bucket name (default: loki-ruler-bucket)",
    )
    parser.add_argument(
        "--alertmanager-url",
        default="http://alertmanager:9093",
        help="Alertmanager URL for ruler (default: http://alertmanager:9093)",
    )
    parser.add_argument(
        "--ruler-remote-write",
        action="store_true",
        default=False,
        help="Enable remote write for ruler to push recording rule metrics to Prometheus",
    )
    parser.add_argument(
        "--ruler-remote-write-url",
        default="http://prometheus:9090/api/v1/write",
        help="Prometheus remote write URL for ruler metrics",
    )

    args = parser.parse_args()

    # Set defaults based on mode
    if args.auth_enabled is None:
        args.auth_enabled = args.mode != "monolithic"

    # Generate configuration
    generator = LokiConfigGenerator()
    try:
        config = generator.generate(
            args.mode,
            args.storage,
            auth_enabled=args.auth_enabled,
            log_level=args.log_level,
            ingestion_rate_mb=args.ingestion_rate_mb,
            max_streams=args.max_streams,
            retention_days=args.retention_days,
            max_concurrent=args.max_concurrent,
            bucket=args.bucket or "loki-bucket",
            container=args.container or "loki-container",
            region=args.region,
            replication=args.replication,
            pattern_ingester=args.pattern_ingester,
            otlp_enabled=args.otlp_enabled,
            frontend_encoding=args.frontend_encoding,
            thanos_storage=args.thanos_storage,
            time_sharding=args.time_sharding,
            delete_request_store=args.delete_request_store,
            horizontal_compactor=args.horizontal_compactor,
            limits_dry_run=args.limits_dry_run,
            zone_awareness=args.zone_awareness,
            ruler_enabled=args.ruler,
            ruler_bucket=args.ruler_bucket or "loki-ruler-bucket",
            alertmanager_url=args.alertmanager_url,
            ruler_remote_write=args.ruler_remote_write,
            ruler_remote_write_url=args.ruler_remote_write_url,
        )

        # Add ruler configuration if enabled
        if args.ruler and args.mode != "monolithic":
            storage_type = args.storage if args.storage in ["s3", "gcs", "azure"] else "s3"
            config += generator._generate_ruler_config(
                storage_type=storage_type,
                bucket=args.ruler_bucket or "loki-ruler-bucket",
                alertmanager_url=args.alertmanager_url,
                enable_remote_write=args.ruler_remote_write,
                remote_write_url=args.ruler_remote_write_url,
                region=args.region,
            )

        # Add dry-run mode for limits if enabled (Loki 3.5+)
        if args.limits_dry_run:
            config += generator._generate_distributor_dry_run_config()

        # Write to file
        with open(args.output, "w") as f:
            f.write(config)

        print(f"Configuration generated successfully: {args.output}")
        print(f"\nDeployment mode: {args.mode}")
        print(f"Storage backend: {args.storage}")
        print(f"Authentication: {'enabled' if args.auth_enabled else 'disabled'}")
        if args.zone_awareness:
            print(f"Zone Awareness: enabled (CRITICAL for multi-AZ HA)")
        if args.ruler:
            print(f"Ruler: enabled (Alertmanager: {args.alertmanager_url})")
        if args.horizontal_compactor != "disabled":
            print(f"Horizontal Compactor: {args.horizontal_compactor} mode (Loki 3.6+)")
        if args.delete_request_store:
            print(f"Delete Request Store: {args.delete_request_store} (Loki 3.5+)")
        if args.limits_dry_run:
            print("Limits Dry-Run Mode: enabled (Loki 3.5+)")
        print(f"\nNext steps:")
        print(f"1. Review the configuration: cat {args.output}")
        print(f"2. Customize parameters as needed")
        print(f"3. Validate the configuration: loki -config.file={args.output} -verify-config")
        print(f"4. Start Loki: loki -config.file={args.output}")
        if args.zone_awareness:
            print(f"\nZone Awareness Note:")
            print(f"   Set AVAILABILITY_ZONE env var for each pod based on node topology.")
            print(f"   See generated config for Kubernetes env var configuration.")

        # Mention Grafana Alloy for log collection in production/Kubernetes deployments
        if args.mode in ["simple-scalable", "microservices"]:
            print(f"\nLog Collection:")
            print(f"   Promtail is deprecated (support ends Feb 2026).")
            print(f"   Use Grafana Alloy for log collection: https://grafana.com/docs/alloy/latest/")
            print(f"   See examples/grafana-alloy.yaml for Kubernetes DaemonSet configuration.")

    except Exception as e:
        print(f"Error generating configuration: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
