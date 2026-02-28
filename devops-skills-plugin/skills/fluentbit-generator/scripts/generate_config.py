#!/usr/bin/env python3
"""
Fluent Bit Configuration Generator

Generates production-ready Fluent Bit configurations based on common use cases.
Supports multiple input sources, filters, and output destinations.
"""

import argparse
import sys
from typing import Dict, Optional, Callable, Any
from urllib.parse import urlparse


class FluentBitConfigGenerator:
    """Generates Fluent Bit configuration files with best practices built-in."""

    def __init__(self) -> None:
        """Initialize the generator with available use cases."""
        self.use_cases: Dict[str, Callable[..., str]] = {
            "kubernetes-elasticsearch": self._generate_k8s_elasticsearch,
            "kubernetes-loki": self._generate_k8s_loki,
            "kubernetes-cloudwatch": self._generate_k8s_cloudwatch,
            "kubernetes-opentelemetry": self._generate_k8s_opentelemetry,
            "application-multiline": self._generate_app_multiline,
            "syslog-forward": self._generate_syslog_forward,
            "file-tail-s3": self._generate_file_s3,
            "http-kafka": self._generate_http_kafka,
            "multi-destination": self._generate_multi_destination,
            "prometheus-metrics": self._generate_prometheus_metrics,
            "lua-filtering": self._generate_lua_filtering,
            "stream-processor": self._generate_stream_processor,
            "custom": self._generate_custom,
        }

    def generate(self, use_case: str, **kwargs) -> str:
        """
        Generate configuration for specified use case.

        Args:
            use_case: The name of the use case to generate
            **kwargs: Additional parameters specific to the use case

        Returns:
            Generated Fluent Bit configuration as a string

        Raises:
            ValueError: If use case is not recognized
        """
        if use_case not in self.use_cases:
            available = ", ".join(self.use_cases.keys())
            raise ValueError(
                f"Unknown use case: {use_case}\n"
                f"Available use cases: {available}"
            )
        return self.use_cases[use_case](**kwargs)

    @staticmethod
    def _parse_otlp_endpoint(endpoint: str) -> tuple[str, int, str]:
        """
        Parse OTLP endpoint into host/port/base path.

        Supports host:port, URL formats, and IPv6 bracket notation.
        """
        normalized = endpoint.strip()
        parsed = urlparse(normalized if "://" in normalized else f"//{normalized}")

        host = parsed.hostname
        if not host:
            raise ValueError(
                f"Invalid OTLP endpoint: {endpoint}. Expected host:port or URL."
            )

        port = parsed.port if parsed.port is not None else 4318
        base_path = parsed.path.rstrip("/")
        logs_uri = f"{base_path}/v1/logs" if base_path else "/v1/logs"
        return host, port, logs_uri

    def _generate_service_section(
        self,
        flush: int = 1,
        log_level: str = "info",
        http_server: bool = True,
        parsers_file: Optional[str] = None,
    ) -> str:
        """
        Generate SERVICE section with global Fluent Bit configuration.

        Args:
            flush: Flush interval in seconds (default: 1)
            log_level: Logging level (default: "info")
            http_server: Enable HTTP server for metrics (default: True)
            parsers_file: Path to parsers configuration file (optional)

        Returns:
            SERVICE section configuration string
        """
        config = f"""[SERVICE]
    # Flush interval in seconds
    Flush        {flush}

    # Log level: off, error, warn, info, debug, trace
    Log_Level    {log_level}

    # Daemon mode (Off for containers)
    Daemon       Off
"""

        if http_server:
            config += """
    # HTTP server for health checks and metrics
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_Port    2020

    # Enable storage metrics
    storage.metrics on
"""

        if parsers_file:
            config += f"""
    # Parser configuration file
    Parsers_File {parsers_file}
"""

        return config

    def _tls_block(
        self,
        tls_verify: bool = True,
        tls_ca_file: Optional[str] = None,
        indent: int = 4,
    ) -> str:
        """Generate TLS configuration lines for an OUTPUT block.

        Args:
            tls_verify: Verify server TLS certificates (default: True).
                        Set to False only for self-signed certs when a
                        custom CA file cannot be provided.
            tls_ca_file: Path to a custom CA certificate file.  When
                         provided, verification is always enabled using
                         this path as the trust anchor — the recommended
                         approach for self-signed certificates.
            indent: Leading spaces for each generated line.

        Returns:
            TLS configuration lines as a string (no trailing newline).
        """
        pad = " " * indent
        lines = [f"{pad}tls               On"]
        if tls_ca_file:
            lines.append(f"{pad}tls.verify        On")
            lines.append(f"{pad}tls.ca_file       {tls_ca_file}")
        elif tls_verify:
            lines.append(f"{pad}tls.verify        On")
        else:
            lines.append(f"{pad}tls.verify        Off")
        return "\n".join(lines)

    def _generate_k8s_elasticsearch(
        self,
        es_host: str = "elasticsearch.logging.svc",
        es_port: int = 9200,
        es_index_prefix: str = "k8s",
        cluster_name: str = "my-cluster",
        environment: str = "production",
        tls_verify: bool = True,
        tls_ca_file: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Generate Kubernetes to Elasticsearch configuration.

        Args:
            es_host: Elasticsearch hostname
            es_port: Elasticsearch port
            es_index_prefix: Index prefix for Logstash format
            cluster_name: Kubernetes cluster name
            environment: Environment identifier
            tls_verify: Verify TLS certificates (default: True).
                        Set to False only when self-signed certs are in use
                        and no CA file can be provided.
            tls_ca_file: Path to custom CA file for self-signed certificates.
                         When set, tls_verify is implicitly enabled.

        Returns:
            Complete Fluent Bit configuration string
        """
        es_host = es_host or "elasticsearch.logging.svc"
        es_port = es_port or 9200
        es_index_prefix = es_index_prefix or "k8s"
        cluster_name = cluster_name or "my-cluster"
        environment = environment or "production"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
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
    Read_from_Head    Off

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

[FILTER]
    Name          modify
    Match         *
    Add           cluster_name {cluster_name}
    Add           environment {environment}

[FILTER]
    Name          nest
    Match         *
    Operation     lift
    Nested_under  kubernetes
    Add_prefix    k8s_

[OUTPUT]
    Name              es
    Match             *
    Host              {es_host}
    Port              {es_port}
    Logstash_Format   On
    Logstash_Prefix   {es_index_prefix}
    Retry_Limit       3
    storage.total_limit_size 5M
    Buffer_Size       False
    Type              _doc
{self._tls_block(tls_verify, tls_ca_file)}
"""

        return config

    def _generate_k8s_loki(
        self,
        loki_host: str = "loki.logging.svc",
        loki_port: int = 3100,
        cluster_name: str = "my-cluster",
        **kwargs
    ) -> str:
        """
        Generate Kubernetes to Loki configuration.

        Args:
            loki_host: Loki hostname
            loki_port: Loki port
            cluster_name: Kubernetes cluster name

        Returns:
            Complete Fluent Bit configuration string
        """
        loki_host = loki_host or "loki.logging.svc"
        loki_port = loki_port or 3100
        cluster_name = cluster_name or "my-cluster"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
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

[FILTER]
    Name          modify
    Match         *
    Add           cluster {cluster_name}

[OUTPUT]
    Name              loki
    Match             *
    Host              {loki_host}
    Port              {loki_port}
    labels            job=fluent-bit, cluster={cluster_name}
    auto_kubernetes_labels on
    remove_keys       kubernetes,stream
    line_format       json
    Retry_Limit       3
"""

        return config

    def _generate_k8s_cloudwatch(
        self,
        aws_region: str = "us-east-1",
        log_group_name: str = "/aws/kubernetes/logs",
        cluster_name: str = "my-cluster",
        **kwargs
    ) -> str:
        """
        Generate Kubernetes to CloudWatch configuration.

        Args:
            aws_region: AWS region for CloudWatch
            log_group_name: CloudWatch log group name
            cluster_name: Kubernetes cluster name

        Returns:
            Complete Fluent Bit configuration string
        """
        aws_region = aws_region or "us-east-1"
        log_group_name = log_group_name or "/aws/kubernetes/logs"
        cluster_name = cluster_name or "my-cluster"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name              tail
    Tag               kube.*
    Path              /var/log/containers/*.log
    Exclude_Path      /var/log/containers/*fluent-bit*.log
    Parser            docker
    DB                /var/log/flb_kube.db
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On

[FILTER]
    Name                kubernetes
    Match               kube.*
    Kube_URL            https://kubernetes.default.svc:443
    Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
    Kube_Tag_Prefix     kube.var.log.containers.
    Merge_Log           On
    Keep_Log            Off
    Labels              On

[FILTER]
    Name          modify
    Match         *
    Add           cluster {cluster_name}

[OUTPUT]
    Name              cloudwatch_logs
    Match             *
    region            {aws_region}
    log_group_name    {log_group_name}
    log_stream_prefix from-fluent-bit-
    auto_create_group On
    Retry_Limit       3
"""

        return config

    def _generate_k8s_opentelemetry(
        self,
        otlp_endpoint: str = "opentelemetry-collector.observability.svc:4318",
        cluster_name: str = "my-cluster",
        environment: str = "production",
        tls_verify: bool = True,
        tls_ca_file: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Generate Kubernetes to OpenTelemetry configuration.

        Args:
            otlp_endpoint: OpenTelemetry Collector endpoint (HTTP)
            cluster_name: Kubernetes cluster name
            environment: Environment identifier
            tls_verify: Verify TLS certificates (default: True).
                        Set to False only when self-signed certs are in use
                        and no CA file can be provided.
            tls_ca_file: Path to custom CA file for self-signed certificates.
                         When set, tls_verify is implicitly enabled.

        Returns:
            Complete Fluent Bit configuration string
        """
        otlp_endpoint = otlp_endpoint or "opentelemetry-collector.observability.svc:4318"
        cluster_name = cluster_name or "my-cluster"
        environment = environment or "production"
        host, port, logs_uri = self._parse_otlp_endpoint(otlp_endpoint)
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
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
    Annotations         On

[FILTER]
    Name          modify
    Match         *
    Add           cluster_name {cluster_name}
    Add           environment {environment}

[OUTPUT]
    Name                 opentelemetry
    Match                *
    Host                 {host}
    Port                 {port}
    # Use HTTP protocol for OTLP
    logs_uri             {logs_uri}
    # Add resource attributes
    add_label            cluster {cluster_name}
    add_label            environment {environment}
    # TLS configuration
{self._tls_block(tls_verify, tls_ca_file, indent=4)}
    # Retry configuration
    Retry_Limit          3
"""

        return config

    def _generate_app_multiline(
        self,
        log_path: str = "/var/log/app/*.log",
        language: str = "java",
        app_name: str = "myapp",
        environment: str = "production",
        es_host: str = "elasticsearch",
        **kwargs
    ) -> str:
        """
        Generate application logs with multiline parsing configuration.

        Args:
            log_path: Path to application log files
            language: Programming language for multiline parser (java, python, go)
            app_name: Application name
            environment: Environment identifier
            es_host: Elasticsearch hostname

        Returns:
            Complete Fluent Bit configuration string
        """
        log_path = log_path or "/var/log/app/*.log"
        language = language or "java"
        app_name = app_name or "myapp"
        environment = environment or "production"
        es_host = es_host or "elasticsearch"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name              tail
    Tag               app.*
    Path              {log_path}
    Parser            json
    Multiline.Parser  multiline-{language}
    DB                /var/log/flb_app.db
    Mem_Buf_Limit     100MB
    Skip_Long_Lines   On

[FILTER]
    Name          modify
    Match         *
    Add           app_name {app_name}
    Add           environment {environment}

[FILTER]
    Name          parser
    Match         *
    Key_Name      log
    Parser        json
    Reserve_Data  On
    Preserve_Key  Off

[OUTPUT]
    Name              es
    Match             *
    Host              {es_host}
    Port              9200
    Index             app-logs
    Retry_Limit       3
    storage.total_limit_size 10M
"""

        return config

    def _generate_syslog_forward(
        self,
        listen_port: int = 5140,
        syslog_host: str = "syslog-server.example.com",
        syslog_port: int = 514,
        **kwargs
    ) -> str:
        """
        Generate syslog collection and forwarding configuration.

        Args:
            listen_port: Port to listen for syslog messages
            syslog_host: Destination syslog server hostname
            syslog_port: Destination syslog server port

        Returns:
            Complete Fluent Bit configuration string
        """
        listen_port = listen_port or 5140
        syslog_host = syslog_host or "syslog-server.example.com"
        syslog_port = syslog_port or 514
        config = self._generate_service_section(flush=5, parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name          syslog
    Tag           syslog.*
    Parser        syslog-rfc3164
    Listen        0.0.0.0
    Port          {listen_port}
    Mode          tcp
    Buffer_Size   32KB

[FILTER]
    Name          modify
    Match         *
    Add           source fluent-bit

[OUTPUT]
    Name          syslog
    Match         *
    Host          {syslog_host}
    Port          {syslog_port}
    Mode          tcp
    Syslog_Format rfc5424
    Retry_Limit   5

[OUTPUT]
    Name          stdout
    Match         *
    Format        json_lines
"""

        return config

    def _generate_file_s3(
        self,
        log_path: str = "/var/log/app/*.log",
        s3_bucket: str = "my-logs-bucket",
        s3_region: str = "us-east-1",
        **kwargs
    ) -> str:
        """
        Generate file tailing to S3 configuration.

        Args:
            log_path: Path to log files to tail
            s3_bucket: S3 bucket name
            s3_region: AWS region for S3

        Returns:
            Complete Fluent Bit configuration string
        """
        log_path = log_path or "/var/log/app/*.log"
        s3_bucket = s3_bucket or "my-logs-bucket"
        s3_region = s3_region or "us-east-1"
        config = self._generate_service_section(flush=5)

        config += f"""
[INPUT]
    Name              tail
    Tag               files.*
    Path              {log_path}
    DB                /var/log/flb_files.db
    Mem_Buf_Limit     100MB
    Skip_Long_Lines   On

[FILTER]
    Name          modify
    Match         *
    Add           source file-collector

[OUTPUT]
    Name              s3
    Match             *
    bucket            {s3_bucket}
    region            {s3_region}
    total_file_size   100M
    upload_timeout    10m
    use_put_object    Off
    compression       gzip
    s3_key_format     /fluent-bit-logs/%Y/%m/%d/$TAG[0]/%H-%M-%S-$UUID.gz
    Retry_Limit       3
"""

        return config

    def _generate_http_kafka(
        self,
        http_port: int = 9880,
        kafka_brokers: str = "kafka:9092",
        kafka_topic: str = "logs",
        **kwargs
    ) -> str:
        """
        Generate HTTP webhook to Kafka configuration.

        Args:
            http_port: Port to listen for HTTP requests
            kafka_brokers: Comma-separated Kafka broker addresses
            kafka_topic: Kafka topic name

        Returns:
            Complete Fluent Bit configuration string
        """
        http_port = http_port or 9880
        kafka_brokers = kafka_brokers or "kafka:9092"
        kafka_topic = kafka_topic or "logs"
        config = self._generate_service_section()

        config += f"""
[INPUT]
    Name          http
    Tag           webhook.*
    Listen        0.0.0.0
    Port          {http_port}
    Buffer_Size   32KB

[FILTER]
    Name          modify
    Match         *
    Add           source webhook

[OUTPUT]
    Name              kafka
    Match             *
    Brokers           {kafka_brokers}
    Topics            {kafka_topic}
    Format            json
    Timestamp_Key     @timestamp
    Retry_Limit       3
    rdkafka.queue.buffering.max.messages 100000
    rdkafka.request.required.acks        1
"""

        return config

    def _generate_multi_destination(
        self,
        es_host: str = "elasticsearch",
        s3_bucket: str = "logs-archive",
        **kwargs
    ) -> str:
        """
        Generate multi-destination configuration.

        Args:
            es_host: Elasticsearch hostname
            s3_bucket: S3 bucket name for archival

        Returns:
            Complete Fluent Bit configuration string
        """
        es_host = es_host or "elasticsearch"
        s3_bucket = s3_bucket or "logs-archive"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name              tail
    Tag               app.*
    Path              /var/log/app/*.log
    Parser            json
    DB                /var/log/flb_app.db
    Mem_Buf_Limit     100MB

[FILTER]
    Name          modify
    Match         *
    Add           environment production

[OUTPUT]
    Name              es
    Match             *
    Host              {es_host}
    Port              9200
    Index             app-logs
    Retry_Limit       3

[OUTPUT]
    Name              s3
    Match             *
    bucket            {s3_bucket}
    region            us-east-1
    total_file_size   100M
    compression       gzip
    s3_key_format     /logs/%Y/%m/%d/%H-%M-%S-$UUID.gz
    Retry_Limit       3

[OUTPUT]
    Name          stdout
    Match         *
    Format        json_lines
"""

        return config

    def _generate_prometheus_metrics(
        self,
        prometheus_host: str = "prometheus.monitoring.svc",
        prometheus_port: int = 9090,
        scrape_interval: int = 15,
        cluster_name: str = "my-cluster",
        tls_verify: bool = True,
        tls_ca_file: Optional[str] = None,
        **kwargs
    ) -> str:
        """
        Generate Prometheus metrics collection and forwarding configuration.

        Args:
            prometheus_host: Prometheus remote write endpoint hostname
            prometheus_port: Prometheus remote write endpoint port
            scrape_interval: Metrics scrape interval in seconds
            cluster_name: Kubernetes cluster name
            tls_verify: Verify TLS certificates (default: True).
                        Set to False only when self-signed certs are in use
                        and no CA file can be provided.
            tls_ca_file: Path to custom CA file for self-signed certificates.
                         When set, tls_verify is implicitly enabled.

        Returns:
            Complete Fluent Bit configuration string
        """
        prometheus_host = prometheus_host or "prometheus.monitoring.svc"
        prometheus_port = prometheus_port or 9090
        scrape_interval = scrape_interval or 15
        cluster_name = cluster_name or "my-cluster"
        config = self._generate_service_section(flush=scrape_interval)

        config += f"""
[INPUT]
    Name              node_exporter_metrics
    Tag               node_metrics
    Scrape_interval   {scrape_interval}

[INPUT]
    Name              prometheus_scrape
    Tag               k8s_metrics
    Host              127.0.0.1
    Port              2020
    Scrape_interval   {scrape_interval}

[FILTER]
    Name          modify
    Match         *
    Add           cluster {cluster_name}

[OUTPUT]
    Name              prometheus_remote_write
    Match             *
    Host              {prometheus_host}
    Port              {prometheus_port}
    Uri               /api/v1/write
    # Add labels to all metrics
    add_label         cluster {cluster_name}
    # TLS configuration
{self._tls_block(tls_verify, tls_ca_file)}
    # Retry configuration
    Retry_Limit       3
    # Compression
    compression       snappy
"""

        return config

    def _generate_lua_filtering(
        self,
        log_path: str = "/var/log/app/*.log",
        lua_script_path: str = "/fluent-bit/scripts/filter.lua",
        es_host: str = "elasticsearch",
        **kwargs
    ) -> str:
        """
        Generate configuration with Lua scripting filter.

        Args:
            log_path: Path to log files
            lua_script_path: Path to Lua filter script
            es_host: Elasticsearch hostname

        Returns:
            Complete Fluent Bit configuration string
        """
        log_path = log_path or "/var/log/app/*.log"
        lua_script_path = lua_script_path or "/fluent-bit/scripts/filter.lua"
        es_host = es_host or "elasticsearch"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name              tail
    Tag               app.*
    Path              {log_path}
    Parser            json
    DB                /var/log/flb_app.db
    Mem_Buf_Limit     100MB
    Skip_Long_Lines   On

[FILTER]
    Name          parser
    Match         *
    Key_Name      log
    Parser        json
    Reserve_Data  On

[FILTER]
    Name    lua
    Match   *
    script  {lua_script_path}
    call    process_record

[FILTER]
    Name          modify
    Match         *
    Add           processed_by lua_filter

[OUTPUT]
    Name              es
    Match             *
    Host              {es_host}
    Port              9200
    Index             app-logs
    Retry_Limit       3
    storage.total_limit_size 10M

# Example Lua script content (save to {lua_script_path}):
# function process_record(tag, timestamp, record)
#     -- Add custom field
#     record["custom_field"] = "custom_value"
#
#     -- Transform existing field
#     if record["level"] then
#         record["severity"] = string.upper(record["level"])
#     end
#
#     -- Filter out specific records (return -1 to drop)
#     if record["message"] and string.match(record["message"], "DEBUG") then
#         return -1, timestamp, record
#     end
#
#     -- Return modified record
#     return 1, timestamp, record
# end
"""

        return config

    def _generate_stream_processor(
        self,
        log_path: str = "/var/log/app/*.log",
        es_host: str = "elasticsearch",
        **kwargs
    ) -> str:
        """
        Generate configuration with Stream Processor for advanced log processing.

        Args:
            log_path: Path to log files
            es_host: Elasticsearch hostname

        Returns:
            Complete Fluent Bit configuration string
        """
        log_path = log_path or "/var/log/app/*.log"
        es_host = es_host or "elasticsearch"
        config = self._generate_service_section(parsers_file="parsers.conf")

        config += f"""
[INPUT]
    Name              tail
    Tag               app.*
    Path              {log_path}
    Parser            json
    DB                /var/log/flb_app.db
    Mem_Buf_Limit     100MB
    Skip_Long_Lines   On

# Stream Processor for advanced SQL-like transformations
[STREAM_TASK]
    Name    error_aggregation
    Exec    CREATE STREAM errors AS \\
            SELECT \\
                level, \\
                COUNT(*) as error_count, \\
                TUMBLE_START() as window_start \\
            FROM TAG:'app.*' \\
            WHERE level = 'error' \\
            GROUP BY level, TUMBLE(time, INTERVAL '1' MINUTE);

[STREAM_TASK]
    Name    high_latency_detection
    Exec    CREATE STREAM high_latency AS \\
            SELECT \\
                service, \\
                endpoint, \\
                response_time_ms \\
            FROM TAG:'app.*' \\
            WHERE response_time_ms > 1000;

[FILTER]
    Name          modify
    Match         *
    Add           processed_by stream_processor

[OUTPUT]
    Name              es
    Match             app.*
    Host              {es_host}
    Port              9200
    Index             app-logs
    Retry_Limit       3

[OUTPUT]
    Name              es
    Match             errors
    Host              {es_host}
    Port              9200
    Index             error-metrics
    Retry_Limit       3

[OUTPUT]
    Name              es
    Match             high_latency
    Host              {es_host}
    Port              9200
    Index             performance-alerts
    Retry_Limit       3
"""

        return config

    def _generate_custom(self, **kwargs) -> str:
        """
        Generate minimal custom configuration template.

        Returns:
            Basic Fluent Bit configuration string
        """
        config = self._generate_service_section()

        config += """
[INPUT]
    Name              tail
    Tag               custom.*
    Path              /var/log/*.log
    DB                /var/log/flb_custom.db
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On

[FILTER]
    Name          modify
    Match         *
    Add           custom_field custom_value

[OUTPUT]
    Name          stdout
    Match         *
    Format        json_lines
"""

        return config


def main() -> None:
    """Main entry point for the configuration generator."""
    use_case_arg_map: Dict[str, list[str]] = {
        "kubernetes-elasticsearch": [
            "cluster_name",
            "environment",
            "es_host",
            "es_port",
            "es_index_prefix",
            "tls_verify",
            "tls_ca_file",
        ],
        "kubernetes-loki": ["cluster_name", "loki_host", "loki_port"],
        "kubernetes-cloudwatch": ["cluster_name", "aws_region", "log_group_name"],
        "kubernetes-opentelemetry": [
            "cluster_name",
            "environment",
            "otlp_endpoint",
            "tls_verify",
            "tls_ca_file",
        ],
        "application-multiline": [
            "environment",
            "es_host",
            "log_path",
            "app_name",
            "language",
        ],
        "syslog-forward": ["listen_port", "syslog_host", "syslog_port"],
        "file-tail-s3": ["log_path", "s3_bucket", "s3_region"],
        "http-kafka": ["http_port", "kafka_brokers", "kafka_topic"],
        "multi-destination": ["es_host", "s3_bucket"],
        "prometheus-metrics": [
            "cluster_name",
            "prometheus_host",
            "prometheus_port",
            "scrape_interval",
            "tls_verify",
            "tls_ca_file",
        ],
        "lua-filtering": ["es_host", "log_path", "lua_script_path"],
        "stream-processor": ["es_host", "log_path"],
        "custom": [],
    }

    parser = argparse.ArgumentParser(
        description="Generate Fluent Bit configurations",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--use-case",
        required=True,
        choices=[
            "kubernetes-elasticsearch",
            "kubernetes-loki",
            "kubernetes-cloudwatch",
            "kubernetes-opentelemetry",
            "application-multiline",
            "syslog-forward",
            "file-tail-s3",
            "http-kafka",
            "multi-destination",
            "prometheus-metrics",
            "lua-filtering",
            "stream-processor",
            "custom",
        ],
        help="Configuration use case to generate",
    )

    parser.add_argument(
        "--output",
        default="fluent-bit.conf",
        help="Output file path (default: fluent-bit.conf)",
    )

    # Common options
    parser.add_argument("--cluster-name", default=None, help="Kubernetes cluster name")
    parser.add_argument("--environment", default=None, help="Environment name")

    # Elasticsearch options
    parser.add_argument("--es-host", default=None, help="Elasticsearch host")
    parser.add_argument("--es-port", type=int, default=None, help="Elasticsearch port")
    parser.add_argument("--es-index-prefix", default=None, help="Elasticsearch index prefix")

    # Loki options
    parser.add_argument("--loki-host", default=None, help="Loki host")
    parser.add_argument("--loki-port", type=int, default=None, help="Loki port")

    # CloudWatch options
    parser.add_argument("--aws-region", default=None, help="AWS region")
    parser.add_argument("--log-group-name", default=None, help="CloudWatch log group")

    # OpenTelemetry options
    parser.add_argument(
        "--otlp-endpoint",
        default=None,
        help="OpenTelemetry Collector OTLP endpoint (HTTP)",
    )

    # Application options
    parser.add_argument("--log-path", default=None, help="Log file path")
    parser.add_argument("--app-name", default=None, help="Application name")
    parser.add_argument(
        "--language",
        default=None,
        choices=["java", "python", "go"],
        help="Language for multiline parsing",
    )

    # S3 options
    parser.add_argument("--s3-bucket", default=None, help="S3 bucket name")
    parser.add_argument("--s3-region", default=None, help="S3 region")

    # Syslog options
    parser.add_argument("--listen-port", type=int, default=None, help="Syslog listen port")
    parser.add_argument("--syslog-host", default=None, help="Destination syslog host")
    parser.add_argument("--syslog-port", type=int, default=None, help="Destination syslog port")
    parser.add_argument("--forward-host", default=None, help=argparse.SUPPRESS)
    parser.add_argument("--forward-port", type=int, default=None, help=argparse.SUPPRESS)

    # Kafka options
    parser.add_argument("--http-port", type=int, default=None, help="HTTP listen port")
    parser.add_argument("--kafka-brokers", default=None, help="Kafka brokers")
    parser.add_argument("--kafka-topic", default=None, help="Kafka topic")

    # Prometheus options
    parser.add_argument("--prometheus-host", default=None, help="Prometheus host")
    parser.add_argument("--prometheus-port", type=int, default=None, help="Prometheus port")
    parser.add_argument(
        "--scrape-interval",
        type=int,
        default=None,
        help="Metrics scrape interval in seconds",
    )

    # Lua options
    parser.add_argument("--lua-script-path", default=None, help="Path to Lua script")

    # TLS options (applies to elasticsearch, opentelemetry, prometheus-metrics)
    tls_group = parser.add_mutually_exclusive_group()
    tls_group.add_argument(
        "--tls-verify",
        dest="tls_verify",
        action="store_true",
        default=True,
        help="Verify TLS certificates (default: enabled)",
    )
    tls_group.add_argument(
        "--no-tls-verify",
        dest="tls_verify",
        action="store_false",
        help=(
            "Disable TLS certificate verification. "
            "Prefer --tls-ca-file for self-signed certificates instead."
        ),
    )
    parser.add_argument(
        "--tls-ca-file",
        default=None,
        help=(
            "Path to custom CA certificate file for self-signed certificates. "
            "When provided, TLS verification is always enabled."
        ),
    )

    args = parser.parse_args()

    # Generate configuration
    generator = FluentBitConfigGenerator()
    try:
        effective_args: Dict[str, Any] = vars(args).copy()
        if effective_args.get("syslog_host") is None and effective_args.get("forward_host"):
            effective_args["syslog_host"] = effective_args["forward_host"]
        if effective_args.get("syslog_port") is None and effective_args.get("forward_port") is not None:
            effective_args["syslog_port"] = effective_args["forward_port"]

        selected_kwargs = {
            key: effective_args[key]
            for key in use_case_arg_map[args.use_case]
            if effective_args.get(key) is not None
        }
        config = generator.generate(args.use_case, **selected_kwargs)

        # Write to file with error handling
        try:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(config)
        except PermissionError as e:
            print(f"Error: Permission denied writing to {args.output}: {e}", file=sys.stderr)
            sys.exit(1)
        except IOError as e:
            print(f"Error: Failed to write configuration file: {e}", file=sys.stderr)
            sys.exit(1)

        print(f"✓ Configuration generated successfully: {args.output}")
        print(f"\nUse case: {args.use_case}")
        print(f"\nNext steps:")
        print(f"1. Review the configuration: cat {args.output}")
        print(f"2. Customize parameters as needed")
        print(f"3. Validate the configuration: fluent-bit -c {args.output} --dry-run")
        print(f"4. Test the configuration: fluent-bit -c {args.output}")

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: Unexpected error generating configuration: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
