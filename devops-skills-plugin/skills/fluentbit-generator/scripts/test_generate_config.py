#!/usr/bin/env python3
"""
Tests for generate_config.py

Run with:
    python3 -m unittest scripts/test_generate_config.py -v
or:
    python3 -m pytest scripts/test_generate_config.py -v
"""

import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# Make sure the script directory is importable
SCRIPT_DIR = Path(__file__).parent
sys.path.insert(0, str(SCRIPT_DIR))

from generate_config import FluentBitConfigGenerator  # noqa: E402


ALL_USE_CASES = [
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
]

GENERATOR = SCRIPT_DIR / "generate_config.py"


class TestAllUseCasesGenerate(unittest.TestCase):
    """Every use case must generate without raising and return a non-empty string."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    def _check(self, use_case, **kwargs):
        result = self.gen.generate(use_case, **kwargs)
        self.assertIsInstance(result, str)
        self.assertGreater(len(result.strip()), 0, f"{use_case} returned empty config")

    def test_kubernetes_elasticsearch(self):
        self._check("kubernetes-elasticsearch")

    def test_kubernetes_loki(self):
        self._check("kubernetes-loki")

    def test_kubernetes_cloudwatch(self):
        self._check("kubernetes-cloudwatch")

    def test_kubernetes_opentelemetry(self):
        self._check("kubernetes-opentelemetry")

    def test_application_multiline(self):
        self._check("application-multiline")

    def test_syslog_forward(self):
        self._check("syslog-forward")

    def test_file_tail_s3(self):
        self._check("file-tail-s3")

    def test_http_kafka(self):
        self._check("http-kafka")

    def test_multi_destination(self):
        self._check("multi-destination")

    def test_prometheus_metrics(self):
        self._check("prometheus-metrics")

    def test_lua_filtering(self):
        self._check("lua-filtering")

    def test_stream_processor(self):
        self._check("stream-processor")

    def test_custom(self):
        self._check("custom")

    def test_unknown_use_case_raises(self):
        with self.assertRaises(ValueError):
            self.gen.generate("nonexistent-use-case")


class TestOtlpEndpointParsing(unittest.TestCase):
    """_parse_otlp_endpoint should handle valid inputs and reject invalid ones."""

    def _parse(self, endpoint):
        return FluentBitConfigGenerator._parse_otlp_endpoint(endpoint)

    def test_host_port(self):
        host, port, uri = self._parse("collector.svc:4318")
        self.assertEqual(host, "collector.svc")
        self.assertEqual(port, 4318)
        self.assertEqual(uri, "/v1/logs")

    def test_http_url(self):
        host, port, uri = self._parse("http://otel.example.com:4318")
        self.assertEqual(host, "otel.example.com")
        self.assertEqual(port, 4318)
        self.assertEqual(uri, "/v1/logs")

    def test_url_with_base_path(self):
        host, port, uri = self._parse("http://otel.example.com:4318/prefix")
        self.assertEqual(uri, "/prefix/v1/logs")

    def test_default_port_when_omitted(self):
        host, port, uri = self._parse("collector.example.com")
        self.assertEqual(port, 4318)

    def test_invalid_endpoint_raises(self):
        with self.assertRaises(ValueError):
            self._parse("://no-host")

    def test_whitespace_stripped(self):
        host, port, uri = self._parse("  collector.svc:4318  ")
        self.assertEqual(host, "collector.svc")


class TestTlsBlock(unittest.TestCase):
    """_tls_block should produce correct lines for all four TLS combinations."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    def test_verify_on_no_ca(self):
        block = self.gen._tls_block(tls_verify=True, tls_ca_file=None)
        self.assertIn("tls               On", block)
        self.assertIn("tls.verify        On", block)
        self.assertNotIn("tls.ca_file", block)

    def test_verify_off_no_ca(self):
        block = self.gen._tls_block(tls_verify=False, tls_ca_file=None)
        self.assertIn("tls               On", block)
        self.assertIn("tls.verify        Off", block)
        self.assertNotIn("tls.ca_file", block)

    def test_ca_file_forces_verify_on(self):
        block = self.gen._tls_block(tls_verify=False, tls_ca_file="/etc/certs/ca.crt")
        self.assertIn("tls.verify        On", block)
        self.assertIn("tls.ca_file       /etc/certs/ca.crt", block)
        self.assertNotIn("tls.verify        Off", block)

    def test_verify_on_with_ca_file(self):
        block = self.gen._tls_block(tls_verify=True, tls_ca_file="/etc/certs/ca.crt")
        self.assertIn("tls.verify        On", block)
        self.assertIn("tls.ca_file       /etc/certs/ca.crt", block)

    def test_custom_indent(self):
        block = self.gen._tls_block(indent=8)
        self.assertTrue(block.startswith(" " * 8))


class TestContainerRuntime(unittest.TestCase):
    """K8s generators must use the correct Parser based on container_runtime."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    K8S_USE_CASES = [
        "kubernetes-elasticsearch",
        "kubernetes-loki",
        "kubernetes-cloudwatch",
        "kubernetes-opentelemetry",
    ]

    def _parser_lines(self, config: str) -> list[str]:
        """Return lines that contain 'Parser' outside of comments."""
        return [
            line
            for line in config.splitlines()
            if re.search(r"^\s+Parser\s", line) and not line.strip().startswith("#")
        ]

    def test_default_is_cri(self):
        for uc in self.K8S_USE_CASES:
            with self.subTest(use_case=uc):
                config = self.gen.generate(uc)
                parser_lines = self._parser_lines(config)
                self.assertTrue(
                    any("cri" in l for l in parser_lines),
                    f"{uc}: expected 'cri' parser line, got: {parser_lines}",
                )
                self.assertFalse(
                    any("docker" in l for l in parser_lines),
                    f"{uc}: unexpected 'docker' parser line, got: {parser_lines}",
                )

    def test_docker_override(self):
        for uc in self.K8S_USE_CASES:
            with self.subTest(use_case=uc):
                config = self.gen.generate(uc, container_runtime="docker")
                parser_lines = self._parser_lines(config)
                self.assertTrue(
                    any("docker" in l for l in parser_lines),
                    f"{uc}: expected 'docker' parser line, got: {parser_lines}",
                )
                self.assertFalse(
                    any(re.search(r"\bcri\b", l) for l in parser_lines),
                    f"{uc}: unexpected 'cri' in parser line, got: {parser_lines}",
                )

    def test_explicit_none_falls_back_to_cri(self):
        config = self.gen.generate("kubernetes-loki", container_runtime=None)
        parser_lines = self._parser_lines(config)
        self.assertTrue(any("cri" in l for l in parser_lines))


class TestApplicationMultiline(unittest.TestCase):
    """application-multiline INPUT must not mix Parser and Multiline.Parser."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    def _input_block(self, config: str) -> str:
        """Extract the first [INPUT] block from config."""
        match = re.search(r"\[INPUT\](.*?)(?=\[|\Z)", config, re.DOTALL)
        return match.group(0) if match else ""

    def test_no_plain_parser_in_input(self):
        config = self.gen.generate("application-multiline")
        input_block = self._input_block(config)
        # Must NOT have a bare `Parser` line (only Multiline.Parser is allowed)
        plain_parser = re.findall(r"^\s+Parser\s", input_block, re.MULTILINE)
        self.assertEqual(
            plain_parser,
            [],
            f"INPUT block must not contain plain 'Parser' alongside Multiline.Parser: {input_block}",
        )

    def test_multiline_parser_present(self):
        config = self.gen.generate("application-multiline", language="java")
        self.assertIn("Multiline.Parser  multiline-java", config)

    def test_ruby_language(self):
        config = self.gen.generate("application-multiline", language="ruby")
        self.assertIn("Multiline.Parser  multiline-ruby", config)
        input_block = self._input_block(config)
        plain_parser = re.findall(r"^\s+Parser\s", input_block, re.MULTILINE)
        self.assertEqual(plain_parser, [])

    def test_python_language(self):
        config = self.gen.generate("application-multiline", language="python")
        self.assertIn("Multiline.Parser  multiline-python", config)

    def test_go_language(self):
        config = self.gen.generate("application-multiline", language="go")
        self.assertIn("Multiline.Parser  multiline-go", config)


class TestPrometheusMetrics(unittest.TestCase):
    """prometheus-metrics must not contain a [FILTER] block."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    def test_no_filter_block(self):
        config = self.gen.generate("prometheus-metrics")
        # [FILTER] blocks silently no-op on metrics records — must be absent
        self.assertNotIn("[FILTER]", config, "prometheus-metrics must not contain a [FILTER] block")

    def test_output_contains_add_label(self):
        config = self.gen.generate("prometheus-metrics", cluster_name="test-cluster")
        self.assertIn("add_label", config)
        self.assertIn("test-cluster", config)


class TestFalsyDefaults(unittest.TestCase):
    """Fix 5: falsy values like port=0 or host='' must not be replaced by defaults."""

    def setUp(self):
        self.gen = FluentBitConfigGenerator()

    def test_zero_port_not_replaced(self):
        # Port 0 is falsy; the old `or` pattern would replace it with the default.
        config = self.gen.generate("kubernetes-loki", loki_port=0)
        self.assertIn("Port              0", config)

    def test_empty_string_host_not_replaced(self):
        # Empty string is falsy; old `or` pattern would silently revert to default.
        config = self.gen.generate("file-tail-s3", s3_bucket="")
        self.assertIn("bucket            ", config)
        # Default "my-logs-bucket" must NOT appear when caller explicitly passes ""
        self.assertNotIn("my-logs-bucket", config)

    def test_zero_scrape_interval_not_replaced(self):
        config = self.gen.generate("prometheus-metrics", scrape_interval=0)
        self.assertIn("Scrape_interval   0", config)

    def test_none_falls_back_to_default(self):
        # None should still fall back to the declared default
        config = self.gen.generate("kubernetes-loki", loki_port=None)
        self.assertIn("Port              3100", config)


class TestCLI(unittest.TestCase):
    """Smoke tests for the CLI entry point via subprocess."""

    def _run(self, *args, expect_success=True):
        result = subprocess.run(
            [sys.executable, str(GENERATOR), *args],
            capture_output=True,
            text=True,
        )
        if expect_success:
            self.assertEqual(
                result.returncode,
                0,
                f"CLI failed.\nstdout: {result.stdout}\nstderr: {result.stderr}",
            )
        return result

    def test_help(self):
        result = self._run("--help", expect_success=True)
        self.assertIn("--use-case", result.stdout)

    def test_kubernetes_loki_default(self):
        with tempfile.NamedTemporaryFile(suffix=".conf", delete=False) as tmp:
            self._run("--use-case", "kubernetes-loki", "--output", tmp.name)
            content = Path(tmp.name).read_text()
        self.assertIn("[INPUT]", content)
        self.assertIn("[OUTPUT]", content)
        self.assertIn("cri", content)

    def test_container_runtime_docker_cli(self):
        with tempfile.NamedTemporaryFile(suffix=".conf", delete=False) as tmp:
            self._run(
                "--use-case", "kubernetes-loki",
                "--container-runtime", "docker",
                "--output", tmp.name,
            )
            content = Path(tmp.name).read_text()
        self.assertIn("docker", content)
        self.assertNotIn("Parser            cri", content)

    def test_language_ruby_cli(self):
        with tempfile.NamedTemporaryFile(suffix=".conf", delete=False) as tmp:
            self._run(
                "--use-case", "application-multiline",
                "--language", "ruby",
                "--output", tmp.name,
            )
            content = Path(tmp.name).read_text()
        self.assertIn("multiline-ruby", content)

    def test_prometheus_metrics_cli(self):
        with tempfile.NamedTemporaryFile(suffix=".conf", delete=False) as tmp:
            self._run("--use-case", "prometheus-metrics", "--output", tmp.name)
            content = Path(tmp.name).read_text()
        self.assertNotIn("[FILTER]", content)

    def test_unknown_use_case_exits_nonzero(self):
        result = self._run("--use-case", "nonexistent", expect_success=False)
        self.assertNotEqual(result.returncode, 0)

    def test_invalid_language_exits_nonzero(self):
        result = self._run(
            "--use-case", "application-multiline",
            "--language", "cobol",
            expect_success=False,
        )
        self.assertNotEqual(result.returncode, 0)

    def test_invalid_container_runtime_exits_nonzero(self):
        result = self._run(
            "--use-case", "kubernetes-loki",
            "--container-runtime", "podman",
            expect_success=False,
        )
        self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
