#!/usr/bin/env python3
"""
Fluent Bit Configuration Validator

Comprehensive validation tool for Fluent Bit configurations.
Checks syntax, semantics, security, performance, and best practices.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from typing import Dict, List, Set


class FluentBitValidator:
    """Validates Fluent Bit configuration files."""

    VALID_INPUT_PLUGINS = {
        "tail",
        "systemd",
        "tcp",
        "udp",
        "forward",
        "http",
        "syslog",
        "docker",
        "kubernetes",
        "exec",
        "dummy",
    }

    VALID_FILTER_PLUGINS = {
        "grep",
        "kubernetes",
        "parser",
        "modify",
        "nest",
        "rewrite_tag",
        "throttle",
        "multiline",
        "record_modifier",
        "lua",
        "geoip2",
        "expect",
        "type_converter",
        "stdout",
        "log_to_metrics",
        "wasm",
    }

    VALID_OUTPUT_PLUGINS = {
        "es",
        "elasticsearch",
        "kafka",
        "loki",
        "s3",
        "cloudwatch",
        "cloudwatch_logs",
        "http",
        "forward",
        "stdout",
        "file",
        "opentelemetry",
        "null",
        "influxdb",
        "datadog",
        "splunk",
        "stackdriver",
        "azure",
        "tcp",
        "udp",
        "nats",
        "counter",
        "flowcounter",
        "firehose",
        "kinesis_firehose",
        "kinesis_streams",
        "gelf",
        "pgsql",
    }

    def __init__(self, config_file: str, require_dry_run: bool = False):
        self.config_file = config_file
        self.require_dry_run = require_dry_run
        self.errors = []
        self.warnings = []
        self.recommendations = []
        self.sections = []

    def validate_all(self) -> bool:
        """Run all validation checks."""
        checks = [
            self.validate_structure,
            self.validate_syntax,
            self.validate_sections,
            self.validate_tags,
            self.validate_security,
            self.validate_performance,
            self.validate_best_practices,
            self.validate_dry_run,
        ]

        for check in checks:
            check()

        return len(self.errors) == 0

    def validate_structure(self) -> None:
        """Validate basic file structure."""
        if not os.path.exists(self.config_file):
            self.errors.append(f"Configuration file not found: {self.config_file}")
            return

        if not os.access(self.config_file, os.R_OK):
            self.errors.append(f"Configuration file not readable: {self.config_file}")
            return

        # Check if file is empty
        if os.path.getsize(self.config_file) == 0:
            self.errors.append("Configuration file is empty")
            return

        # Parse file and store line numbers
        self._parse_config()

    def _parse_config(self) -> None:
        """Parse configuration file and build section list."""
        try:
            self.sections = []

            with open(self.config_file, "r", encoding="utf-8") as f:
                lines = f.readlines()

            current_section = None

            for i, line in enumerate(lines, start=1):
                stripped = line.strip()

                # Skip empty lines and comments
                if not stripped or stripped.startswith("#"):
                    continue

                # Detect mixed indentation (tabs + spaces)
                indent_match = re.match(r"^[ \t]+", line)
                if indent_match:
                    indent = indent_match.group(0)
                    if " " in indent and "\t" in indent:
                        self.warnings.append(
                            f"Line {i}: Mixed tabs and spaces in indentation"
                        )

                # Section header
                if stripped.startswith("["):
                    if not stripped.endswith("]"):
                        self.errors.append(
                            f"Line {i}: Malformed section header '{stripped}'"
                        )
                        current_section = None
                        continue

                    section_name = stripped[1:-1].strip().upper()
                    if not section_name:
                        self.errors.append(f"Line {i}: Empty section header []")
                        current_section = None
                        continue

                    current_section = {
                        "type": section_name,
                        "line": i,
                        "params": {},
                    }
                    self.sections.append(current_section)
                    continue

                if current_section is None:
                    self.errors.append(
                        f"Line {i}: Parameter outside of a section '{stripped}'"
                    )
                    continue

                key, value = self._parse_key_value(stripped)
                if key is None:
                    self.errors.append(f"Line {i}: Malformed key-value pair '{stripped}'")
                    continue

                current_section["params"][key] = {
                    "value": value,
                    "line": i,
                }

        except Exception as e:
            self.errors.append(f"Failed to parse configuration: {str(e)}")

    def _parse_key_value(self, line: str):
        """Parse key-value pair supporting both whitespace and '=' delimiters."""
        equals_match = re.match(r"^([^\s=]+)\s*=\s*(.*)$", line)
        if equals_match:
            return equals_match.group(1), equals_match.group(2).strip()

        space_match = re.match(r"^([^\s=]+)\s+(.*)$", line)
        if space_match:
            return space_match.group(1), space_match.group(2).strip()

        return None, None

    def validate_syntax(self) -> None:
        """Validate INI syntax."""
        valid_sections = ["SERVICE", "INPUT", "FILTER", "OUTPUT", "PARSER", "MULTILINE_PARSER"]

        for section in self.sections:
            if section["type"] not in valid_sections:
                self.warnings.append(
                    f"Line {section['line']}: Unknown section type [{section['type']}]"
                )

    def validate_sections(self) -> None:
        """Validate individual sections."""
        has_service = False
        has_input = False
        has_output = False

        for section in self.sections:
            section_type = section["type"]
            params = section["params"]

            if section_type == "SERVICE":
                has_service = True
                self._validate_service_section(section)
            elif section_type == "INPUT":
                has_input = True
                self._validate_input_section(section)
            elif section_type == "FILTER":
                self._validate_filter_section(section)
            elif section_type == "OUTPUT":
                has_output = True
                self._validate_output_section(section)
            elif section_type in ["PARSER", "MULTILINE_PARSER"]:
                self._validate_parser_section(section)

        # Check required sections
        if not has_service:
            self.warnings.append("Missing [SERVICE] section (recommended)")
        if not has_input:
            self.errors.append("Missing [INPUT] section (required)")
        if not has_output:
            self.errors.append("Missing [OUTPUT] section (required)")

    def _validate_service_section(self, section: Dict) -> None:
        """Validate SERVICE section."""
        params = section["params"]

        # Check Flush parameter
        if "Flush" not in params:
            self.warnings.append(
                f"Line {section['line']}: [SERVICE] missing Flush parameter (recommended)"
            )
        else:
            flush_line = params["Flush"]["line"]
            try:
                flush_val = int(params["Flush"]["value"])
                if flush_val < 1:
                    self.warnings.append(
                        f"Line {flush_line}: Flush interval < 1 second (very low, high CPU usage)"
                    )
                elif flush_val > 10:
                    self.warnings.append(
                        f"Line {flush_line}: Flush interval > 10 seconds (high latency)"
                    )
            except ValueError:
                self.errors.append(
                    f"Line {flush_line}: Flush must be a number (got: {params['Flush']['value']})"
                )

        # Check Log_Level
        if "Log_Level" in params:
            valid_levels = ["off", "error", "warn", "info", "debug", "trace"]
            log_level = params["Log_Level"]["value"].lower()
            if log_level not in valid_levels:
                self.errors.append(
                    f"Line {params['Log_Level']['line']}: Invalid Log_Level '{log_level}' "
                    f"(valid: {', '.join(valid_levels)})"
                )

        # Check Parsers_File existence
        if "Parsers_File" in params:
            parser_file = params["Parsers_File"]["value"]
            # Try to resolve relative to config file
            config_dir = os.path.dirname(self.config_file)
            parser_path = os.path.join(config_dir, parser_file)
            if not os.path.exists(parser_path) and not os.path.exists(parser_file):
                self.warnings.append(
                    f"Line {params['Parsers_File']['line']}: Parsers_File '{parser_file}' not found"
                )

    def _validate_input_section(self, section: Dict) -> None:
        """Validate INPUT section."""
        params = section["params"]

        # Check required Name parameter
        if "Name" not in params:
            self.errors.append(f"Line {section['line']}: [INPUT] missing required parameter 'Name'")
            return

        plugin_name = params["Name"]["value"]
        plugin_name_normalized = plugin_name.lower()

        if plugin_name_normalized not in self.VALID_INPUT_PLUGINS:
            self.warnings.append(
                f"Line {params['Name']['line']}: Unknown INPUT plugin '{plugin_name}'"
            )

        # Check Tag parameter (recommended)
        if "Tag" not in params:
            if plugin_name_normalized != "forward":  # forward provides dynamic tags
                self.warnings.append(
                    f"Line {section['line']}: [INPUT] missing Tag parameter (recommended)"
                )

        # tail plugin specific checks
        if plugin_name_normalized == "tail":
            if "Path" not in params:
                self.errors.append(
                    f"Line {section['line']}: [INPUT tail] missing required parameter 'Path'"
                )

            if "Mem_Buf_Limit" not in params:
                self.warnings.append(
                    f"Line {section['line']}: [INPUT tail] missing Mem_Buf_Limit (OOM risk)"
                )

            if "DB" not in params:
                self.warnings.append(
                    f"Line {section['line']}: [INPUT tail] missing DB parameter (no crash recovery)"
                )

            if "Skip_Long_Lines" not in params:
                self.recommendations.append(
                    f"Line {section['line']}: [INPUT tail] consider adding Skip_Long_Lines On"
                )

    def _validate_filter_section(self, section: Dict) -> None:
        """Validate FILTER section."""
        params = section["params"]

        # Check required parameters
        if "Name" not in params:
            self.errors.append(f"Line {section['line']}: [FILTER] missing required parameter 'Name'")
            return

        filter_name = params["Name"]["value"]
        filter_name_normalized = filter_name.lower()

        if filter_name_normalized not in self.VALID_FILTER_PLUGINS:
            self.warnings.append(
                f"Line {params['Name']['line']}: Unknown FILTER plugin '{filter_name}' "
                f"(plugin-specific validation skipped)"
            )

        if "Match" not in params and "Match_Regex" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER] missing required parameter 'Match' or 'Match_Regex'"
            )

        # Filter-specific validation
        if filter_name_normalized == "kubernetes":
            self._validate_kubernetes_filter(section, params)
        elif filter_name_normalized == "parser":
            self._validate_parser_filter(section, params)
        elif filter_name_normalized == "grep":
            self._validate_grep_filter(section, params)
        elif filter_name_normalized == "modify":
            self._validate_modify_filter(section, params)
        elif filter_name_normalized == "nest":
            self._validate_nest_filter(section, params)
        elif filter_name_normalized == "rewrite_tag":
            self._validate_rewrite_tag_filter(section, params)
        elif filter_name_normalized == "throttle":
            self._validate_throttle_filter(section, params)
        elif filter_name_normalized == "multiline":
            self._validate_multiline_filter(section, params)

    def _validate_kubernetes_filter(self, section: Dict, params: Dict) -> None:
        """Validate kubernetes filter specific parameters."""
        # Check for common K8s filter parameters
        if "Kube_URL" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Kube_URL "
                f"(default: https://kubernetes.default.svc:443)"
            )

        # Recommend best practices
        if "Merge_Log" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Merge_Log On to parse JSON logs"
            )

        if "Keep_Log" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Keep_Log Off to reduce payload size"
            )

        if "Labels" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [FILTER kubernetes] consider enabling Labels On for pod labels"
            )

        # Buffer_Size recommendation
        if "Buffer_Size" in params:
            buffer_size = params["Buffer_Size"]["value"]
            if buffer_size != "0":
                self.recommendations.append(
                    f"Line {params['Buffer_Size']['line']}: [FILTER kubernetes] Buffer_Size 0 is recommended for performance"
                )

    def _validate_parser_filter(self, section: Dict, params: Dict) -> None:
        """Validate parser filter specific parameters."""
        if "Key_Name" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER parser] missing required parameter 'Key_Name'"
            )

        if "Parser" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER parser] missing required parameter 'Parser'"
            )

        # Recommend Reserve_Data
        if "Reserve_Data" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [FILTER parser] consider setting Reserve_Data On to keep unparsed data"
            )

    def _validate_grep_filter(self, section: Dict, params: Dict) -> None:
        """Validate grep filter specific parameters."""
        has_regex = "Regex" in params
        has_exclude = "Exclude" in params

        if not has_regex and not has_exclude:
            self.warnings.append(
                f"Line {section['line']}: [FILTER grep] has neither Regex nor Exclude parameter (no filtering will occur)"
            )

        # Validate regex patterns if present
        if has_regex:
            regex_value = params["Regex"]["value"]
            parts = regex_value.split(None, 1)
            if len(parts) != 2:
                self.warnings.append(
                    f"Line {params['Regex']['line']}: [FILTER grep] Regex format should be 'key pattern'"
                )

    def _validate_modify_filter(self, section: Dict, params: Dict) -> None:
        """Validate modify filter specific parameters."""
        has_operation = any(key in params for key in ["Add", "Remove", "Set", "Rename", "Copy", "Hard_Rename", "Hard_Copy"])

        if not has_operation:
            self.warnings.append(
                f"Line {section['line']}: [FILTER modify] no operation specified "
                f"(expected: Add, Remove, Set, Rename, Copy, etc.)"
            )

    def _validate_nest_filter(self, section: Dict, params: Dict) -> None:
        """Validate nest filter specific parameters."""
        if "Operation" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER nest] missing required parameter 'Operation'"
            )
        else:
            operation = params["Operation"]["value"].lower()
            valid_operations = ["nest", "lift"]
            if operation not in valid_operations:
                self.errors.append(
                    f"Line {params['Operation']['line']}: [FILTER nest] invalid Operation '{operation}' "
                    f"(valid: {', '.join(valid_operations)})"
                )

        if "Nested_under" not in params and "Nest_under" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER nest] missing required parameter 'Nested_under'"
            )

    def _validate_rewrite_tag_filter(self, section: Dict, params: Dict) -> None:
        """Validate rewrite_tag filter specific parameters."""
        if "Rule" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER rewrite_tag] missing required parameter 'Rule'"
            )

    def _validate_throttle_filter(self, section: Dict, params: Dict) -> None:
        """Validate throttle filter specific parameters."""
        if "Rate" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER throttle] missing required parameter 'Rate'"
            )

    def _validate_multiline_filter(self, section: Dict, params: Dict) -> None:
        """Validate multiline filter specific parameters."""
        if "multiline.parser" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER multiline] missing required parameter 'multiline.parser'"
            )

    def _validate_output_section(self, section: Dict) -> None:
        """Validate OUTPUT section."""
        params = section["params"]

        # Check required parameters
        if "Name" not in params:
            self.errors.append(f"Line {section['line']}: [OUTPUT] missing required parameter 'Name'")
            return

        plugin_name = params["Name"]["value"]
        plugin_name_normalized = plugin_name.lower()

        if plugin_name_normalized not in self.VALID_OUTPUT_PLUGINS:
            self.warnings.append(
                f"Line {params['Name']['line']}: Unknown OUTPUT plugin '{plugin_name}' "
                f"(plugin-specific validation skipped)"
            )

        if "Match" not in params and "Match_Regex" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT] missing required parameter 'Match' or 'Match_Regex'"
            )

        # Check Retry_Limit
        if "Retry_Limit" not in params:
            self.warnings.append(
                f"Line {section['line']}: [OUTPUT] missing Retry_Limit (infinite retries)"
            )

        # Plugin-specific checks
        if plugin_name_normalized in ["es", "elasticsearch"]:
            self._validate_elasticsearch_output(section, params)
        elif plugin_name_normalized == "kafka":
            self._validate_kafka_output(section, params)
        elif plugin_name_normalized == "loki":
            self._validate_loki_output(section, params)
        elif plugin_name_normalized == "s3":
            self._validate_s3_output(section, params)
        elif plugin_name_normalized in ["cloudwatch", "cloudwatch_logs"]:
            self._validate_cloudwatch_output(section, params)
        elif plugin_name_normalized == "http":
            self._validate_http_output(section, params)
        elif plugin_name_normalized == "forward":
            self._validate_forward_output(section, params)
        elif plugin_name_normalized == "stdout":
            self._validate_stdout_output(section, params)
        elif plugin_name_normalized == "file":
            self._validate_file_output(section, params)
        elif plugin_name_normalized == "opentelemetry":
            self._validate_opentelemetry_output(section, params)

    def _validate_elasticsearch_output(self, section: Dict, params: Dict) -> None:
        """Validate Elasticsearch output specific parameters."""
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT es] missing required parameter 'Host'"
            )

        # Recommend Logstash format for better indexing
        if "Logstash_Format" not in params and "Index" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT es] consider using Logstash_Format On or specify Index"
            )

        # Check for TLS in production
        if "tls" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT es] consider enabling TLS for production"
            )

    def _validate_kafka_output(self, section: Dict, params: Dict) -> None:
        """Validate Kafka output specific parameters."""
        if "Brokers" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT kafka] missing required parameter 'Brokers'"
            )

        if "Topics" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT kafka] missing required parameter 'Topics'"
            )

        # Recommend message format
        if "Format" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT kafka] consider setting Format (json, msgpack, gelf)"
            )

    def _validate_loki_output(self, section: Dict, params: Dict) -> None:
        """Validate Loki output specific parameters."""
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT loki] missing required parameter 'Host'"
            )

        # Recommend label configuration
        if "labels" not in params and "auto_kubernetes_labels" not in params:
            self.warnings.append(
                f"Line {section['line']}: [OUTPUT loki] missing labels configuration "
                f"(set 'labels' or 'auto_kubernetes_labels on')"
            )

        # Check line format
        if "line_format" in params:
            line_format = params["line_format"]["value"].lower()
            valid_formats = ["json", "key_value"]
            if line_format not in valid_formats:
                self.warnings.append(
                    f"Line {params['line_format']['line']}: [OUTPUT loki] invalid line_format '{line_format}' "
                    f"(valid: {', '.join(valid_formats)})"
                )

    def _validate_s3_output(self, section: Dict, params: Dict) -> None:
        """Validate S3 output specific parameters."""
        if "bucket" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT s3] missing required parameter 'bucket'"
            )

        if "region" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT s3] missing required parameter 'region'"
            )

        # Recommend compression
        if "compression" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT s3] consider enabling compression (gzip)"
            )

        # Recommend s3_key_format for organization
        if "s3_key_format" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT s3] consider setting s3_key_format for log organization"
            )

    def _validate_cloudwatch_output(self, section: Dict, params: Dict) -> None:
        """Validate CloudWatch Logs output specific parameters."""
        if "region" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT cloudwatch_logs] missing required parameter 'region'"
            )

        if "log_group_name" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT cloudwatch_logs] missing required parameter 'log_group_name'"
            )

        # Recommend auto_create_group
        if "auto_create_group" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT cloudwatch_logs] consider setting auto_create_group On"
            )

    def _validate_http_output(self, section: Dict, params: Dict) -> None:
        """Validate HTTP output specific parameters."""
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT http] missing required parameter 'Host'"
            )

        if "URI" not in params:
            self.warnings.append(
                f"Line {section['line']}: [OUTPUT http] missing URI parameter (will use /)"
            )

        # Recommend format
        if "Format" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT http] consider setting Format (json, msgpack)"
            )

        # Recommend compression
        if "Compress" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT http] consider enabling Compress (gzip)"
            )

    def _validate_forward_output(self, section: Dict, params: Dict) -> None:
        """Validate Forward output specific parameters."""
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT forward] missing required parameter 'Host'"
            )

        # Check for shared_key in secure mode
        if "Require_ack_response" in params:
            require_ack = params["Require_ack_response"]["value"].lower()
            if require_ack in ["on", "true", "yes"] and "Shared_Key" not in params:
                self.warnings.append(
                    f"Line {section['line']}: [OUTPUT forward] Require_ack_response On but missing Shared_Key"
                )

    def _validate_stdout_output(self, section: Dict, params: Dict) -> None:
        """Validate stdout output specific parameters."""
        # stdout is mainly for debugging, check format
        if "Format" in params:
            format_val = params["Format"]["value"].lower()
            valid_formats = ["json", "json_lines", "msgpack"]
            if format_val not in valid_formats:
                self.warnings.append(
                    f"Line {params['Format']['line']}: [OUTPUT stdout] invalid Format '{format_val}' "
                    f"(valid: {', '.join(valid_formats)})"
                )

    def _validate_file_output(self, section: Dict, params: Dict) -> None:
        """Validate file output specific parameters."""
        if "Path" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT file] missing required parameter 'Path'"
            )

        # Check if path is writable
        if "Path" in params:
            path = params["Path"]["value"]
            parent_dir = os.path.dirname(path) if os.path.dirname(path) else "."
            if os.path.exists(parent_dir) and not os.access(parent_dir, os.W_OK):
                self.warnings.append(
                    f"Line {params['Path']['line']}: [OUTPUT file] Path '{path}' may not be writable"
                )

    def _validate_opentelemetry_output(self, section: Dict, params: Dict) -> None:
        """Validate OpenTelemetry output specific parameters (Fluent Bit 2.x+)."""
        # Check for Host parameter (required)
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] missing required parameter 'Host'"
            )

        # Check Port (optional, defaults to 4317 for gRPC, 4318 for HTTP)
        if "Port" in params:
            try:
                port = int(params["Port"]["value"])
                if port < 1 or port > 65535:
                    self.errors.append(
                        f"Line {params['Port']['line']}: [OUTPUT opentelemetry] Port must be between 1-65535"
                    )
            except ValueError:
                self.errors.append(
                    f"Line {params['Port']['line']}: [OUTPUT opentelemetry] Port must be a number"
                )

        # Recommend specific URI endpoints
        has_uri = any(key in params for key in ["metrics_uri", "logs_uri", "traces_uri"])
        if not has_uri:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] consider specifying metrics_uri, logs_uri, or traces_uri"
            )

        # Check for authentication header
        if "Header" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] consider adding Header for authentication "
                f"(e.g., Header Authorization Bearer ${{OTEL_TOKEN}})"
            )
        else:
            # Check if header contains hardcoded credentials
            header_value = params["Header"]["value"]
            if "Bearer " in header_value and not "${" in header_value:
                self.warnings.append(
                    f"Line {params['Header']['line']}: [OUTPUT opentelemetry] Header may contain hardcoded credentials "
                    f"(use environment variable: Header Authorization Bearer ${{OTEL_TOKEN}})"
                )

        # Check TLS configuration
        if "tls" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] consider enabling TLS for production"
            )
        else:
            tls_value = params["tls"]["value"].lower()
            if tls_value in ["off", "false", "no"]:
                self.warnings.append(
                    f"Line {params['tls']['line']}: [OUTPUT opentelemetry] TLS disabled (security risk in production)"
                )

        # Check TLS verification
        if "tls.verify" in params:
            verify_value = params["tls.verify"]["value"].lower()
            if verify_value in ["off", "false", "no"]:
                self.warnings.append(
                    f"Line {params['tls.verify']['line']}: [OUTPUT opentelemetry] TLS verification disabled (MITM risk)"
                )

        # Recommend add_label for metadata
        if "add_label" not in params:
            self.recommendations.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] consider using add_label to add resource attributes"
            )

    def _validate_parser_section(self, section: Dict) -> None:
        """Validate PARSER and MULTILINE_PARSER sections."""
        params = section["params"]
        section_type = section["type"]

        if "Name" not in params:
            self.errors.append(f"Line {section['line']}: [{section_type}] missing required parameter 'Name'")

        # PARSER-specific validation
        if section_type == "PARSER":
            if "Format" not in params:
                self.errors.append(f"Line {section['line']}: [PARSER] missing required parameter 'Format'")
            else:
                parser_format = params["Format"]["value"].lower()
                valid_formats = ["json", "regex", "ltsv", "logfmt"]
                if parser_format not in valid_formats:
                    self.warnings.append(
                        f"Line {params['Format']['line']}: [PARSER] unknown Format '{parser_format}' "
                        f"(expected: {', '.join(valid_formats)})"
                    )

                # Regex-specific checks
                if parser_format == "regex":
                    if "Regex" not in params:
                        self.errors.append(
                            f"Line {section['line']}: [PARSER regex] missing required parameter 'Regex'"
                        )

                # Time parsing checks
                if "Time_Key" in params and "Time_Format" not in params:
                    self.warnings.append(
                        f"Line {section['line']}: [PARSER] has Time_Key but missing Time_Format"
                    )

        # MULTILINE_PARSER-specific validation
        elif section_type == "MULTILINE_PARSER":
            if "Type" not in params:
                self.errors.append(
                    f"Line {section['line']}: [MULTILINE_PARSER] missing required parameter 'Type'"
                )
            else:
                multiline_type = params["Type"]["value"].lower()
                valid_types = ["regex"]
                if multiline_type not in valid_types:
                    self.errors.append(
                        f"Line {params['Type']['line']}: [MULTILINE_PARSER] invalid Type '{multiline_type}' "
                        f"(valid: {', '.join(valid_types)})"
                    )

            # Check for rule definitions
            has_rule = any(key.lower().startswith("rule") for key in params.keys())
            if not has_rule:
                self.errors.append(
                    f"Line {section['line']}: [MULTILINE_PARSER] missing 'rule' definitions"
                )

            # Recommend flush_timeout
            if "flush_timeout" not in params and "Flush_timeout" not in params:
                self.recommendations.append(
                    f"Line {section['line']}: [MULTILINE_PARSER] consider setting flush_timeout (e.g., 1000ms)"
                )

    def validate_tags(self) -> None:
        """Validate tag consistency across INPUT, FILTER, OUTPUT."""
        input_tags = []
        for section in self.sections:
            if section["type"] == "INPUT":
                if "Tag" in section["params"]:
                    input_tags.append(section["params"]["Tag"]["value"])
        if not input_tags:
            return

        produced_tags = set(input_tags)

        # Process filters in order to simulate tag flow and rewrite_tag emissions.
        for section in self.sections:
            if section["type"] != "FILTER":
                continue

            params = section["params"]
            descriptor = self._match_descriptor(params)

            if not self._section_matches_any_tags(params, produced_tags, section, "FILTER"):
                if descriptor:
                    self.warnings.append(
                        f"Line {section['line']}: [FILTER] {descriptor} doesn't match any INPUT/FILTER tags"
                    )
                continue

            filter_name = params.get("Name", {}).get("value", "").lower()
            if filter_name == "rewrite_tag":
                generated_patterns = self._extract_rewrite_tag_patterns(section)
                produced_tags.update(generated_patterns)

        # Validate outputs against tags produced by inputs and filters.
        for section in self.sections:
            if section["type"] != "OUTPUT":
                continue

            params = section["params"]
            descriptor = self._match_descriptor(params)
            if not self._section_matches_any_tags(params, produced_tags, section, "OUTPUT"):
                if descriptor:
                    self.warnings.append(
                        f"Line {section['line']}: [OUTPUT] {descriptor} doesn't match any INPUT/FILTER tags"
                    )

    def _extract_rewrite_tag_patterns(self, section: Dict) -> Set[str]:
        """Extract tags emitted by rewrite_tag filters from Rule entries."""
        params = section["params"]
        generated = set()

        for key, meta in params.items():
            if not key.lower().startswith("rule"):
                continue

            rule = meta["value"].strip()
            parts = rule.split()
            if len(parts) < 3:
                self.warnings.append(
                    f"Line {meta['line']}: [FILTER rewrite_tag] Rule should be "
                    f"'$KEY REGEX NEW_TAG KEEP'"
                )
                continue

            new_tag = parts[2]
            generated.add("*" if "$" in new_tag else new_tag)

        return generated

    def _section_matches_any_tags(
        self, params: Dict, tags: Set[str], section: Dict, section_type: str
    ) -> bool:
        """Check if Match/Match_Regex for a section matches any known tags."""
        has_match = False
        has_regex = False

        if "Match" in params:
            has_match = True
            match_pattern = params["Match"]["value"]

            if match_pattern == "*":
                return True

            for tag in tags:
                if self._tag_patterns_overlap(tag, match_pattern):
                    return True

        if "Match_Regex" in params:
            has_regex = True
            regex_pattern = params["Match_Regex"]["value"]
            try:
                regex = re.compile(regex_pattern)
            except re.error as exc:
                self.errors.append(
                    f"Line {params['Match_Regex']['line']}: [{section_type}] "
                    f"invalid Match_Regex '{regex_pattern}': {exc}"
                )
                return False

            for tag in tags:
                for candidate in self._sample_tags_from_pattern(tag):
                    if regex.match(candidate):
                        return True

        return not has_match and not has_regex

    def _sample_tags_from_pattern(self, pattern: str) -> List[str]:
        """Generate representative sample tags from wildcard patterns."""
        if "*" not in pattern:
            return [pattern]

        return [
            pattern.replace("*", "sample"),
            pattern.replace("*", "x"),
        ]

    def _tag_patterns_overlap(self, left: str, right: str) -> bool:
        """Approximate overlap check for two wildcard-style tag patterns."""
        if left == "*" or right == "*":
            return True

        for sample in self._sample_tags_from_pattern(left):
            if self._tag_matches(sample, right):
                return True

        for sample in self._sample_tags_from_pattern(right):
            if self._tag_matches(sample, left):
                return True

        return False

    def _match_descriptor(self, params: Dict):
        """Return human-friendly descriptor for Match or Match_Regex."""
        if "Match" in params:
            return f"Match pattern '{params['Match']['value']}'"
        if "Match_Regex" in params:
            return f"Match_Regex pattern '{params['Match_Regex']['value']}'"
        return None

    def _tag_matches(self, tag: str, pattern: str) -> bool:
        """Check if tag matches pattern (with wildcard support)."""
        if pattern == "*":
            return True

        # Convert wildcard pattern to regex
        regex_pattern = pattern.replace(".", r"\.").replace("*", ".*")
        return re.match(f"^{regex_pattern}$", tag) is not None

    def validate_security(self) -> None:
        """Security audit of configuration."""
        for section in self.sections:
            params = section["params"]

            # Check for hardcoded credentials
            sensitive_keys = [
                "HTTP_User",
                "HTTP_Passwd",
                "Password",
                "AWS_Access_Key",
                "AWS_Secret_Key",
                "Secret",
                "API_Key",
                "Token",
            ]
            for key in sensitive_keys:
                if key in params:
                    value = params[key]["value"]
                    # Check if it's an environment variable reference
                    if not value.startswith("${"):
                        self.warnings.append(
                            f"Line {params[key]['line']}: Hardcoded credential '{key}' "
                            f"(use environment variable: ${{{key}}})"
                        )

            # Check TLS configuration
            if section["type"] == "OUTPUT":
                if "tls" in params:
                    tls_value = params["tls"]["value"].lower()
                    if tls_value in ["off", "false", "no"]:
                        self.warnings.append(
                            f"Line {params['tls']['line']}: TLS disabled (security risk in production)"
                        )

                if "tls.verify" in params:
                    verify_value = params["tls.verify"]["value"].lower()
                    if verify_value in ["off", "false", "no"]:
                        self.warnings.append(
                            f"Line {params['tls.verify']['line']}: TLS verification disabled (MITM risk)"
                        )

            # Check network exposure in SERVICE HTTP server
            if section["type"] == "SERVICE":
                http_server_on = params.get("HTTP_Server", {}).get("value", "").lower() in [
                    "on",
                    "true",
                    "yes",
                ]
                if http_server_on and params.get("HTTP_Listen", {}).get("value") == "0.0.0.0":
                    self.warnings.append(
                        f"Line {params['HTTP_Listen']['line']}: HTTP_Server exposed on 0.0.0.0 "
                        f"(limit to internal interface in production)"
                    )

            # Check network listener exposure for INPUT network plugins
            if section["type"] == "INPUT":
                plugin_name = params.get("Name", {}).get("value", "").lower()
                network_inputs = {"http", "tcp", "udp", "forward", "syslog"}
                if plugin_name in network_inputs:
                    listener = params.get("Listen", params.get("Host"))
                    if listener and listener["value"] == "0.0.0.0":
                        self.warnings.append(
                            f"Line {listener['line']}: [INPUT {plugin_name}] listening on 0.0.0.0 "
                            f"(ensure network controls and authentication are in place)"
                        )

    def validate_performance(self) -> None:
        """Analyze performance configuration."""
        for section in self.sections:
            params = section["params"]

            # Check tail input buffer limits
            if section["type"] == "INPUT" and params.get("Name", {}).get("value") == "tail":
                if "Mem_Buf_Limit" in params:
                    buf_limit = params["Mem_Buf_Limit"]["value"]
                    # Parse size (e.g., "50MB", "1GB", "512" where unit defaults to bytes)
                    size_match = re.match(r"^(\d+(?:\.\d+)?)\s*(MB|GB|KB|M|G|K|B)?$", buf_limit, re.IGNORECASE)
                    if size_match:
                        size = float(size_match.group(1))
                        unit = (size_match.group(2) or "B").upper()

                        # Normalize unit names (M -> MB, G -> GB, K -> KB)
                        if unit == "M":
                            unit = "MB"
                        elif unit == "G":
                            unit = "GB"
                        elif unit == "K":
                            unit = "KB"

                        # Convert to MB
                        if unit == "B":
                            size_mb = size / (1024 * 1024)
                        elif unit == "KB":
                            size_mb = size / 1024
                        elif unit == "GB":
                            size_mb = size * 1024
                        else:
                            size_mb = size

                        if size_mb < 10:
                            self.warnings.append(
                                f"Line {params['Mem_Buf_Limit']['line']}: Mem_Buf_Limit < 10MB (may cause backpressure)"
                            )
                        elif size_mb > 500:
                            self.warnings.append(
                                f"Line {params['Mem_Buf_Limit']['line']}: Mem_Buf_Limit > 500MB (high memory usage)"
                            )
                    else:
                        self.errors.append(
                            f"Line {params['Mem_Buf_Limit']['line']}: Invalid Mem_Buf_Limit format '{buf_limit}' "
                            f"(expected format: number with optional unit KB/MB/GB)"
                        )

            # Check OUTPUT storage limits
            if section["type"] == "OUTPUT":
                if "storage.total_limit_size" not in params:
                    self.recommendations.append(
                        f"Line {section['line']}: [OUTPUT] consider setting storage.total_limit_size"
                    )

    def validate_best_practices(self) -> None:
        """Check best practices."""
        has_http_server = False
        has_storage_metrics = False
        has_exclude_path_for_k8s = False
        is_kubernetes_setup = False
        tail_inputs = 0
        tail_inputs_with_db = 0
        tail_inputs_with_mem_buf_limit = 0
        total_outputs = 0
        outputs_with_retry_limit = 0

        for section in self.sections:
            section_type = section["type"]
            params = section["params"]

            # SERVICE section checks
            if section_type == "SERVICE":
                if "HTTP_Server" in params:
                    value = params["HTTP_Server"]["value"].lower()
                    if value in ["on", "true", "yes"]:
                        has_http_server = True

                if "storage.metrics" in params:
                    value = params["storage.metrics"]["value"].lower()
                    if value in ["on", "true", "yes"]:
                        has_storage_metrics = True

            # INPUT section checks
            elif section_type == "INPUT":
                if params.get("Name", {}).get("value", "").lower() == "tail":
                    tail_inputs += 1

                    # Check for DB parameter
                    if "DB" in params:
                        tail_inputs_with_db += 1

                    # Check Mem_Buf_Limit
                    if "Mem_Buf_Limit" in params:
                        tail_inputs_with_mem_buf_limit += 1

                    # Check for Kubernetes setup
                    if "Path" in params:
                        path = params["Path"]["value"]
                        if "/var/log/containers" in path or "kube" in path.lower():
                            is_kubernetes_setup = True

                            # Check Exclude_Path for Kubernetes
                            if "Exclude_Path" in params:
                                exclude = params["Exclude_Path"]["value"]
                                if "fluent-bit" in exclude or "fluentbit" in exclude:
                                    has_exclude_path_for_k8s = True

            # OUTPUT section checks
            elif section_type == "OUTPUT":
                total_outputs += 1
                if "Retry_Limit" in params:
                    outputs_with_retry_limit += 1

        # Generate best practice recommendations
        if not has_http_server:
            self.recommendations.append(
                "Consider enabling HTTP_Server for health checks and metrics (SERVICE: HTTP_Server On)"
            )

        if not has_storage_metrics:
            self.recommendations.append(
                "Consider enabling storage metrics for monitoring (SERVICE: storage.metrics on)"
            )

        if tail_inputs > 0 and tail_inputs_with_db < tail_inputs:
            self.recommendations.append(
                "Consider adding DB parameter to all tail INPUTs for crash recovery and offset tracking"
            )

        if tail_inputs > 0 and tail_inputs_with_mem_buf_limit < tail_inputs:
            self.recommendations.append(
                "Consider adding Mem_Buf_Limit to all tail INPUTs to avoid unbounded memory usage"
            )

        if total_outputs > 0 and outputs_with_retry_limit < total_outputs:
            self.recommendations.append(
                "Consider setting Retry_Limit on all OUTPUTs to avoid infinite retry loops"
            )

        if is_kubernetes_setup:
            if not has_exclude_path_for_k8s:
                self.recommendations.append(
                    "Consider excluding Fluent Bit's own logs to prevent loops (INPUT tail: Exclude_Path *fluent-bit*.log)"
                )

            # Check for kubernetes filter
            has_k8s_filter = any(
                section["type"] == "FILTER" and
                section["params"].get("Name", {}).get("value") == "kubernetes"
                for section in self.sections
            )

            if not has_k8s_filter:
                self.recommendations.append(
                    "Consider adding kubernetes FILTER for metadata enrichment in Kubernetes environments"
                )

    def validate_dry_run(self) -> None:
        """Test configuration with fluent-bit --dry-run if binary is available."""
        # Check if fluent-bit binary is available
        fluent_bit_path = shutil.which("fluent-bit")

        if not fluent_bit_path:
            message = (
                "Dry-run skipped because fluent-bit binary is not available in PATH; "
                "run dry-run in CI or a Fluent Bit runtime image."
            )
            if self.require_dry_run:
                self.errors.append(message)
            else:
                self.recommendations.append(message)
            return

        # Get absolute path to config file
        config_abs_path = os.path.abspath(self.config_file)

        try:
            # Run fluent-bit with --dry-run flag
            # --dry-run: Test configuration and exit
            result = subprocess.run(
                [fluent_bit_path, "-c", config_abs_path, "--dry-run"],
                capture_output=True,
                text=True,
                timeout=10,  # 10 second timeout
                check=False,  # Don't raise exception on non-zero exit
            )

            # Parse output for errors
            if result.returncode != 0:
                # Dry-run failed - parse error messages
                error_lines = []

                # Check both stdout and stderr
                for line in (result.stdout + result.stderr).splitlines():
                    line_lower = line.lower()

                    # Look for error indicators
                    if any(indicator in line_lower for indicator in ["error", "fail", "invalid", "cannot"]):
                        error_lines.append(line.strip())

                if error_lines:
                    self.errors.append(
                        f"Dry-run test failed:\n  " + "\n  ".join(error_lines[:5])  # Limit to first 5 errors
                    )
                else:
                    self.errors.append(
                        f"Dry-run test failed with exit code {result.returncode}"
                    )
            else:
                # Dry-run succeeded
                self.recommendations.append("Dry-run test passed - configuration is valid")

                # Check for warnings in output
                warning_lines = []
                for line in (result.stdout + result.stderr).splitlines():
                    line_lower = line.lower()
                    if "warn" in line_lower:
                        warning_lines.append(line.strip())

                if warning_lines:
                    for warning in warning_lines[:3]:  # Limit to first 3 warnings
                        self.recommendations.append(f"Dry-run warning: {warning}")

        except subprocess.TimeoutExpired:
            self.warnings.append(
                "Dry-run test timed out after 10 seconds (configuration may have issues)"
            )
        except Exception as e:
            self.warnings.append(
                f"Dry-run test failed with exception: {str(e)}"
            )

    def print_report(self) -> None:
        """Print validation report."""
        print(f"\nValidation Report: {self.config_file}")

        if self.errors:
            print("\nError:")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print("\nWarning:")
            for warning in self.warnings:
                print(f"  - {warning}")

        if self.recommendations:
            print("\nRecommendation:")
            for recommendation in self.recommendations:
                print(f"  - {recommendation}")

        if not self.errors and not self.warnings and not self.recommendations:
            print("\nRecommendation:")
            print("  - No findings.")

        print()

    def get_summary(self, fail_on_warning: bool = False) -> Dict:
        """Get validation summary as dict."""
        return {
            "file": self.config_file,
            "valid": len(self.errors) == 0 and (not fail_on_warning or len(self.warnings) == 0),
            "errors": self.errors,
            "warnings": self.warnings,
            "recommendations": self.recommendations,
        }


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Validate Fluent Bit configuration files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    parser.add_argument(
        "--file",
        required=True,
        help="Path to Fluent Bit configuration file",
    )

    parser.add_argument(
        "--check",
        default="all",
        choices=[
            "all",
            "structure",
            "syntax",
            "sections",
            "tags",
            "security",
            "performance",
            "best-practices",
            "dry-run",
        ],
        help="Validation check to perform (default: all)",
    )

    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )

    parser.add_argument(
        "--fail-on-warning",
        action="store_true",
        help="Return non-zero exit code when warnings are present",
    )
    parser.add_argument(
        "--require-dry-run",
        action="store_true",
        help="Treat missing fluent-bit binary as an error for dry-run checks",
    )

    args = parser.parse_args()

    # Validate configuration
    validator = FluentBitValidator(args.file, require_dry_run=args.require_dry_run)

    if args.check == "all":
        validator.validate_all()
    elif args.check == "structure":
        validator.validate_structure()
    elif args.check == "syntax":
        # Parse config first, then check syntax
        validator.validate_structure()
        validator.validate_syntax()
    elif args.check == "sections":
        # Parse config first, then validate sections
        validator.validate_structure()
        validator.validate_sections()
    elif args.check == "tags":
        # Parse config first, then check tag consistency
        validator.validate_structure()
        validator.validate_tags()
    elif args.check == "security":
        # Parse config first, then run security audit
        validator.validate_structure()
        validator.validate_security()
    elif args.check == "performance":
        # Parse config first, then analyze performance
        validator.validate_structure()
        validator.validate_performance()
    elif args.check == "best-practices":
        # Parse config first, then check best practices
        validator.validate_structure()
        validator.validate_best_practices()
    elif args.check == "dry-run":
        # Parse config first, then run dry-run test
        validator.validate_structure()
        validator.validate_dry_run()

    # Output results
    if args.json:
        print(json.dumps(validator.get_summary(args.fail_on_warning), indent=2))
    else:
        validator.print_report()

    # Exit with error code if validation failed
    has_failures = len(validator.errors) > 0 or (
        args.fail_on_warning and len(validator.warnings) > 0
    )
    sys.exit(0 if not has_failures else 1)


if __name__ == "__main__":
    main()
