#!/usr/bin/env python3
"""
Fluent Bit Configuration Generator

Generates production-ready Fluent Bit configurations based on common use cases.
Supports multiple input sources, filters, and output destinations.
"""

import argparse
import sys
from typing import Dict, List, Optional, Callable


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

    def _generate_k8s_elasticsearch(
        self,
        es_host: str = "elasticsearch.logging.svc",
        es_port: int = 9200,
        es_index_prefix: str = "k8s",
        cluster_name: str = "my-cluster",
        environment: str = "production",
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

        Returns:
            Complete Fluent Bit configuration string
        """
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
    tls               On
    tls.verify        Off
    Buffer_Size       False
    Type              _doc
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
        config = self._generate_service_section()

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
        config = self._generate_service_section()

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
        **kwargs
    ) -> str:
        """
        Generate Kubernetes to OpenTelemetry configuration.

        Args:
            otlp_endpoint: OpenTelemetry Collector endpoint (HTTP)
            cluster_name: Kubernetes cluster name
            environment: Environment identifier

        Returns:
            Complete Fluent Bit configuration string
        """
        config = self._generate_service_section()

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
    Host                 {otlp_endpoint.split(':')[0]}
    Port                 {otlp_endpoint.split(':')[1] if ':' in otlp_endpoint else '4318'}
    # Use HTTP protocol for OTLP
    logs_uri             /v1/logs
    # Add resource attributes
    add_label            cluster {cluster_name}
    add_label            environment {environment}
    # TLS configuration
    tls                  On
    tls.verify           Off
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
        forward_host: str = "syslog-server.example.com",
        forward_port: int = 514,
        **kwargs
    ) -> str:
        """
        Generate syslog collection and forwarding configuration.

        Args:
            listen_port: Port to listen for syslog messages
            forward_host: Destination syslog server hostname
            forward_port: Destination syslog server port

        Returns:
            Complete Fluent Bit configuration string
        """
        config = self._generate_service_section(flush=5)

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
    Name          forward
    Match         *
    Host          {forward_host}
    Port          {forward_port}
    Retry_Limit   5

[OUTPUT]
    Name          stdout
    Match         *
    Format        json_lines
"""

        return config

    def _generate_file_s3(
        self,
        file_path: str = "/var/log/app/*.log",
        s3_bucket: str = "my-logs-bucket",
        s3_region: str = "us-east-1",
        **kwargs
    ) -> str:
        """
        Generate file tailing to S3 configuration.

        Args:
            file_path: Path to log files to tail
            s3_bucket: S3 bucket name
            s3_region: AWS region for S3

        Returns:
            Complete Fluent Bit configuration string
        """
        config = self._generate_service_section(flush=5)

        config += f"""
[INPUT]
    Name              tail
    Tag               files.*
    Path              {file_path}
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
        **kwargs
    ) -> str:
        """
        Generate Prometheus metrics collection and forwarding configuration.

        Args:
            prometheus_host: Prometheus remote write endpoint hostname
            prometheus_port: Prometheus remote write endpoint port
            scrape_interval: Metrics scrape interval in seconds
            cluster_name: Kubernetes cluster name

        Returns:
            Complete Fluent Bit configuration string
        """
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
    tls               On
    tls.verify        Off
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
    parser.add_argument("--cluster-name", default="my-cluster", help="Kubernetes cluster name")
    parser.add_argument("--environment", default="production", help="Environment name")

    # Elasticsearch options
    parser.add_argument("--es-host", default="elasticsearch", help="Elasticsearch host")
    parser.add_argument("--es-port", type=int, default=9200, help="Elasticsearch port")
    parser.add_argument("--es-index-prefix", default="k8s", help="Elasticsearch index prefix")

    # Loki options
    parser.add_argument("--loki-host", default="loki", help="Loki host")
    parser.add_argument("--loki-port", type=int, default=3100, help="Loki port")

    # CloudWatch options
    parser.add_argument("--aws-region", default="us-east-1", help="AWS region")
    parser.add_argument("--log-group-name", default="/aws/kubernetes/logs", help="CloudWatch log group")

    # OpenTelemetry options
    parser.add_argument(
        "--otlp-endpoint",
        default="opentelemetry-collector.observability.svc:4318",
        help="OpenTelemetry Collector OTLP endpoint (HTTP)",
    )

    # Application options
    parser.add_argument("--log-path", default="/var/log/app/*.log", help="Log file path")
    parser.add_argument("--app-name", default="myapp", help="Application name")
    parser.add_argument("--language", default="java", choices=["java", "python", "go"], help="Language for multiline parsing")

    # S3 options
    parser.add_argument("--s3-bucket", default="my-logs-bucket", help="S3 bucket name")
    parser.add_argument("--s3-region", default="us-east-1", help="S3 region")

    # Syslog options
    parser.add_argument("--listen-port", type=int, default=5140, help="Syslog listen port")
    parser.add_argument("--forward-host", default="syslog-server", help="Syslog forward host")
    parser.add_argument("--forward-port", type=int, default=514, help="Syslog forward port")

    # Kafka options
    parser.add_argument("--http-port", type=int, default=9880, help="HTTP listen port")
    parser.add_argument("--kafka-brokers", default="kafka:9092", help="Kafka brokers")
    parser.add_argument("--kafka-topic", default="logs", help="Kafka topic")

    # Prometheus options
    parser.add_argument("--prometheus-host", default="prometheus.monitoring.svc", help="Prometheus host")
    parser.add_argument("--prometheus-port", type=int, default=9090, help="Prometheus port")
    parser.add_argument("--scrape-interval", type=int, default=15, help="Metrics scrape interval in seconds")

    # Lua options
    parser.add_argument("--lua-script-path", default="/fluent-bit/scripts/filter.lua", help="Path to Lua script")

    args = parser.parse_args()

    # Generate configuration
    generator = FluentBitConfigGenerator()
    try:
        config = generator.generate(
            args.use_case,
            cluster_name=args.cluster_name,
            environment=args.environment,
            es_host=args.es_host,
            es_port=args.es_port,
            es_index_prefix=args.es_index_prefix,
            loki_host=args.loki_host,
            loki_port=args.loki_port,
            aws_region=args.aws_region,
            log_group_name=args.log_group_name,
            otlp_endpoint=args.otlp_endpoint,
            log_path=args.log_path,
            app_name=args.app_name,
            language=args.language,
            s3_bucket=args.s3_bucket,
            s3_region=args.s3_region,
            listen_port=args.listen_port,
            forward_host=args.forward_host,
            forward_port=args.forward_port,
            http_port=args.http_port,
            kafka_brokers=args.kafka_brokers,
            kafka_topic=args.kafka_topic,
            prometheus_host=args.prometheus_host,
            prometheus_port=args.prometheus_port,
            scrape_interval=args.scrape_interval,
            lua_script_path=args.lua_script_path,
        )

        # Write to file with error handling
        try:
            with open(args.output, "w", encoding="utf-8") as f:
                f.write(config)
        except IOError as e:
            print(f"Error: Failed to write configuration file: {e}", file=sys.stderr)
            sys.exit(1)
        except PermissionError as e:
            print(f"Error: Permission denied writing to {args.output}: {e}", file=sys.stderr)
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