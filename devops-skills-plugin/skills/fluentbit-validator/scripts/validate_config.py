#!/usr/bin/env python3
"""
Fluent Bit Configuration Validator

Comprehensive validation tool for Fluent Bit configurations.
Checks syntax, semantics, security, performance, and best practices.
"""

import argparse
import configparser
import json
import os
import re
import shutil
import subprocess
import sys
from collections import defaultdict
from typing import Dict, List, Tuple, Optional


class FluentBitValidator:
    """Validates Fluent Bit configuration files."""

    def __init__(self, config_file: str):
        self.config_file = config_file
        self.errors = []
        self.warnings = []
        self.info = []
        self.sections = []
        self.line_map = {}  # Maps section/key to line number

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
            with open(self.config_file, "r") as f:
                lines = f.readlines()

            current_section = None
            line_num = 0

            for i, line in enumerate(lines, start=1):
                line_num = i
                stripped = line.strip()

                # Skip empty lines and comments
                if not stripped or stripped.startswith("#"):
                    continue

                # Section header
                if stripped.startswith("[") and stripped.endswith("]"):
                    section_name = stripped[1:-1].upper()
                    current_section = {
                        "type": section_name,
                        "line": line_num,
                        "params": {},
                    }
                    self.sections.append(current_section)
                    continue

                # Key-value pair
                if current_section and "  " in line and not stripped.startswith("["):
                    # Parse key-value (handle various spacing)
                    parts = stripped.split(None, 1)
                    if len(parts) == 2:
                        key, value = parts
                        current_section["params"][key] = {
                            "value": value,
                            "line": line_num,
                        }

        except Exception as e:
            self.errors.append(f"Failed to parse configuration: {str(e)}")

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
        valid_inputs = ["tail", "systemd", "tcp", "udp", "forward", "http", "syslog", "docker", "kubernetes", "exec", "dummy"]

        if plugin_name not in valid_inputs:
            self.warnings.append(
                f"Line {params['Name']['line']}: Unknown INPUT plugin '{plugin_name}'"
            )

        # Check Tag parameter (recommended)
        if "Tag" not in params:
            if plugin_name != "forward":  # forward provides dynamic tags
                self.warnings.append(
                    f"Line {section['line']}: [INPUT] missing Tag parameter (recommended)"
                )

        # tail plugin specific checks
        if plugin_name == "tail":
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
                self.info.append(
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

        if "Match" not in params and "Match_Regex" not in params:
            self.errors.append(
                f"Line {section['line']}: [FILTER] missing required parameter 'Match' or 'Match_Regex'"
            )

        # Filter-specific validation
        if filter_name == "kubernetes":
            self._validate_kubernetes_filter(section, params)
        elif filter_name == "parser":
            self._validate_parser_filter(section, params)
        elif filter_name == "grep":
            self._validate_grep_filter(section, params)
        elif filter_name == "modify":
            self._validate_modify_filter(section, params)
        elif filter_name == "nest":
            self._validate_nest_filter(section, params)
        elif filter_name == "rewrite_tag":
            self._validate_rewrite_tag_filter(section, params)
        elif filter_name == "throttle":
            self._validate_throttle_filter(section, params)
        elif filter_name == "multiline":
            self._validate_multiline_filter(section, params)

    def _validate_kubernetes_filter(self, section: Dict, params: Dict) -> None:
        """Validate kubernetes filter specific parameters."""
        # Check for common K8s filter parameters
        if "Kube_URL" not in params:
            self.info.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Kube_URL "
                f"(default: https://kubernetes.default.svc:443)"
            )

        # Recommend best practices
        if "Merge_Log" not in params:
            self.info.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Merge_Log On to parse JSON logs"
            )

        if "Keep_Log" not in params:
            self.info.append(
                f"Line {section['line']}: [FILTER kubernetes] consider setting Keep_Log Off to reduce payload size"
            )

        if "Labels" not in params:
            self.info.append(
                f"Line {section['line']}: [FILTER kubernetes] consider enabling Labels On for pod labels"
            )

        # Buffer_Size recommendation
        if "Buffer_Size" in params:
            buffer_size = params["Buffer_Size"]["value"]
            if buffer_size != "0":
                self.info.append(
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
            self.info.append(
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
        if plugin_name in ["es", "elasticsearch"]:
            self._validate_elasticsearch_output(section, params)
        elif plugin_name == "kafka":
            self._validate_kafka_output(section, params)
        elif plugin_name == "loki":
            self._validate_loki_output(section, params)
        elif plugin_name == "s3":
            self._validate_s3_output(section, params)
        elif plugin_name in ["cloudwatch", "cloudwatch_logs"]:
            self._validate_cloudwatch_output(section, params)
        elif plugin_name == "http":
            self._validate_http_output(section, params)
        elif plugin_name == "forward":
            self._validate_forward_output(section, params)
        elif plugin_name == "stdout":
            self._validate_stdout_output(section, params)
        elif plugin_name == "file":
            self._validate_file_output(section, params)
        elif plugin_name == "opentelemetry":
            self._validate_opentelemetry_output(section, params)

    def _validate_elasticsearch_output(self, section: Dict, params: Dict) -> None:
        """Validate Elasticsearch output specific parameters."""
        if "Host" not in params:
            self.errors.append(
                f"Line {section['line']}: [OUTPUT es] missing required parameter 'Host'"
            )

        # Recommend Logstash format for better indexing
        if "Logstash_Format" not in params and "Index" not in params:
            self.info.append(
                f"Line {section['line']}: [OUTPUT es] consider using Logstash_Format On or specify Index"
            )

        # Check for TLS in production
        if "tls" not in params:
            self.info.append(
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
            self.info.append(
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
            self.info.append(
                f"Line {section['line']}: [OUTPUT s3] consider enabling compression (gzip)"
            )

        # Recommend s3_key_format for organization
        if "s3_key_format" not in params:
            self.info.append(
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
            self.info.append(
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
            self.info.append(
                f"Line {section['line']}: [OUTPUT http] consider setting Format (json, msgpack)"
            )

        # Recommend compression
        if "Compress" not in params:
            self.info.append(
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
            self.info.append(
                f"Line {section['line']}: [OUTPUT opentelemetry] consider specifying metrics_uri, logs_uri, or traces_uri"
            )

        # Check for authentication header
        if "Header" not in params:
            self.info.append(
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
            self.info.append(
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
            self.info.append(
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
                self.info.append(
                    f"Line {section['line']}: [MULTILINE_PARSER] consider setting flush_timeout (e.g., 1000ms)"
                )

    def validate_tags(self) -> None:
        """Validate tag consistency across INPUT, FILTER, OUTPUT."""
        input_tags = []
        filter_matches = []
        output_matches = []

        # Collect tags and match patterns
        for section in self.sections:
            if section["type"] == "INPUT":
                if "Tag" in section["params"]:
                    input_tags.append(section["params"]["Tag"]["value"])
            elif section["type"] == "FILTER":
                if "Match" in section["params"]:
                    filter_matches.append(
                        (section["params"]["Match"]["value"], section["line"])
                    )
            elif section["type"] == "OUTPUT":
                if "Match" in section["params"]:
                    output_matches.append(
                        (section["params"]["Match"]["value"], section["line"])
                    )

        # Check if FILTER Match patterns match any INPUT tags
        for match, line in filter_matches:
            if match == "*":
                continue  # Matches everything

            # Check if match pattern matches any input tags
            matched = False
            for tag in input_tags:
                if self._tag_matches(tag, match):
                    matched = True
                    break

            if not matched and input_tags:
                self.warnings.append(
                    f"Line {line}: [FILTER] Match pattern '{match}' doesn't match any INPUT tags"
                )

        # Check if OUTPUT Match patterns match any INPUT tags
        for match, line in output_matches:
            if match == "*":
                continue  # Matches everything

            # Check if match pattern matches any input tags
            matched = False
            for tag in input_tags:
                if self._tag_matches(tag, match):
                    matched = True
                    break

            if not matched and input_tags:
                self.warnings.append(
                    f"Line {line}: [OUTPUT] Match pattern '{match}' doesn't match any INPUT tags"
                )

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
            sensitive_keys = ["HTTP_Passwd", "Password", "AWS_Secret_Key", "Secret", "API_Key"]
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
                    self.info.append(
                        f"Line {section['line']}: [OUTPUT] consider setting storage.total_limit_size"
                    )

    def validate_best_practices(self) -> None:
        """Check best practices."""
        has_http_server = False
        has_storage_metrics = False
        has_db_for_tail = False
        has_retry_limit_on_outputs = True
        has_mem_buf_limit_on_tail = True
        has_exclude_path_for_k8s = False
        is_kubernetes_setup = False

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
                if params.get("Name", {}).get("value") == "tail":
                    # Check for DB parameter
                    if "DB" in params:
                        has_db_for_tail = True

                    # Check Mem_Buf_Limit
                    if "Mem_Buf_Limit" not in params:
                        has_mem_buf_limit_on_tail = False

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
                if "Retry_Limit" not in params:
                    has_retry_limit_on_outputs = False

        # Generate best practice recommendations
        if not has_http_server:
            self.info.append(
                "Consider enabling HTTP_Server for health checks and metrics (SERVICE: HTTP_Server On)"
            )

        if not has_storage_metrics:
            self.info.append(
                "Consider enabling storage metrics for monitoring (SERVICE: storage.metrics on)"
            )

        if is_kubernetes_setup:
            if not has_exclude_path_for_k8s:
                self.info.append(
                    "Consider excluding Fluent Bit's own logs to prevent loops (INPUT tail: Exclude_Path *fluent-bit*.log)"
                )

            # Check for kubernetes filter
            has_k8s_filter = any(
                section["type"] == "FILTER" and
                section["params"].get("Name", {}).get("value") == "kubernetes"
                for section in self.sections
            )

            if not has_k8s_filter:
                self.info.append(
                    "Consider adding kubernetes FILTER for metadata enrichment in Kubernetes environments"
                )

    def validate_dry_run(self) -> None:
        """Test configuration with fluent-bit --dry-run if binary is available."""
        # Check if fluent-bit binary is available
        fluent_bit_path = shutil.which("fluent-bit")

        if not fluent_bit_path:
            self.info.append(
                "fluent-bit binary not found in PATH - skipping dry-run test "
                "(install Fluent Bit to enable actual configuration testing)"
            )
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
                self.info.append("Dry-run test passed - configuration is valid")

                # Check for warnings in output
                warning_lines = []
                for line in (result.stdout + result.stderr).splitlines():
                    line_lower = line.lower()
                    if "warn" in line_lower:
                        warning_lines.append(line.strip())

                if warning_lines:
                    for warning in warning_lines[:3]:  # Limit to first 3 warnings
                        self.info.append(f"Dry-run warning: {warning}")

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
        print(f"\nValidation Report for {self.config_file}")
        print("=" * 60)

        if self.errors:
            print(f"\n❌ Errors ({len(self.errors)}):")
            for error in self.errors:
                print(f"  - {error}")

        if self.warnings:
            print(f"\n⚠️  Warnings ({len(self.warnings)}):")
            for warning in self.warnings:
                print(f"  - {warning}")

        if self.info:
            print(f"\n💡 Info ({len(self.info)}):")
            for info_item in self.info:
                print(f"  - {info_item}")

        if not self.errors and not self.warnings:
            print("\n✅ All validation checks passed!")

        print()

    def get_summary(self) -> Dict:
        """Get validation summary as dict."""
        return {
            "file": self.config_file,
            "valid": len(self.errors) == 0,
            "errors": self.errors,
            "warnings": self.warnings,
            "info": self.info,
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

    args = parser.parse_args()

    # Validate configuration
    validator = FluentBitValidator(args.file)

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
        print(json.dumps(validator.get_summary(), indent=2))
    else:
        validator.print_report()

    # Exit with error code if validation failed
    sys.exit(0 if len(validator.errors) == 0 else 1)


if __name__ == "__main__":
    main()