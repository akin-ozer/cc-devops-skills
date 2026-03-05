#!/usr/bin/env python3
"""Automated tests for Fluent Bit validator regressions and core behavior."""

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parent.parent
VALIDATOR = SKILL_DIR / "scripts" / "validate_config.py"


class ValidatorTestCase(unittest.TestCase):
    """Behavioral tests for validate_config.py."""

    def run_validator(
        self,
        config_text,
        check="all",
        fail_on_warning=False,
        require_dry_run=False,
        env=None,
    ):
        """Run validator against temporary config and return (proc, summary)."""
        with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False) as config_file:
            config_file.write(textwrap.dedent(config_text).strip() + "\n")
            config_path = config_file.name

        cmd = [
            sys.executable,
            str(VALIDATOR),
            "--file",
            config_path,
            "--check",
            check,
            "--json",
        ]
        if fail_on_warning:
            cmd.append("--fail-on-warning")
        if require_dry_run:
            cmd.append("--require-dry-run")

        run_env = None
        if env is not None:
            run_env = os.environ.copy()
            run_env.update(env)

        proc = subprocess.run(cmd, capture_output=True, text=True, check=False, env=run_env)
        summary = json.loads(proc.stdout)

        Path(config_path).unlink(missing_ok=True)
        return proc, summary

    def run_validator_file(self, config_path, check="all", env=None):
        """Run validator against a checked-in config file and return (proc, summary)."""
        cmd = [
            sys.executable,
            str(VALIDATOR),
            "--file",
            str(config_path),
            "--check",
            check,
            "--json",
        ]

        run_env = None
        if env is not None:
            run_env = os.environ.copy()
            run_env.update(env)

        proc = subprocess.run(cmd, capture_output=True, text=True, check=False, env=run_env)
        summary = json.loads(proc.stdout)
        return proc, summary

    def test_single_space_and_equals_delimiters_are_supported(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
            Flush=5
            Log_Level info

            [INPUT]
            Name tail
            Path /var/log/*.log
            Tag app.logs
            Mem_Buf_Limit 50MB
            DB /tmp/flb.db
            Skip_Long_Lines On

            [OUTPUT]
            Name stdout
            Match *
            Retry_Limit 3
            """,
            check="sections",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(summary["valid"])
        self.assertEqual(summary["errors"], [])

    def test_structure_reports_malformed_key_value_pairs(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
            Flush 5
            InvalidLineWithoutDelimiter
            """,
            check="structure",
        )
        self.assertNotEqual(proc.returncode, 0)
        self.assertFalse(summary["valid"])
        self.assertTrue(
            any("Malformed key-value pair" in error for error in summary["errors"])
        )

    def test_tag_check_supports_match_regex(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs

            [FILTER]
                Name grep
                Match_Regex ^app\\..*$
                Regex level ERROR

            [OUTPUT]
                Name stdout
                Match_Regex ^app\\..*$
                Retry_Limit 3
            """,
            check="tags",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(
            any("doesn't match any INPUT" in warning for warning in summary["warnings"])
        )

    def test_parser_handles_equals_in_whitespace_delimited_values(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
                Mem_Buf_Limit 50MB
                DB /tmp/flb.db

            [FILTER]
                Name grep
                Match app.*
                Regex level ^foo=bar$

            [OUTPUT]
                Name stdout
                Match *
                Retry_Limit 3
            """,
            check="sections",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(
            any("has neither Regex nor Exclude" in warning for warning in summary["warnings"])
        )

    def test_tag_check_handles_rewrite_tag_generated_tags(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.raw

            [FILTER]
                Name rewrite_tag
                Match app.raw
                Rule $log ^.*$ app.processed false

            [OUTPUT]
                Name stdout
                Match app.processed
                Retry_Limit 3
            """,
            check="tags",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(
            any("app.processed" in warning for warning in summary["warnings"])
        )

    def test_tag_check_handles_non_final_rewrite_tag_rule(self):
        """OUTPUT should match tags generated by any rewrite_tag Rule, not only the last one."""
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.raw

            [FILTER]
                Name rewrite_tag
                Match app.raw
                Rule $log ^ERROR$ app.error false
                Rule $log ^INFO$ app.info false

            [OUTPUT]
                Name stdout
                Match app.error
                Retry_Limit 3
            """,
            check="tags",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(
            any("app.error" in warning and "doesn't match any INPUT/FILTER tags" in warning
                for warning in summary["warnings"])
        )

    def test_tag_check_wildcard_input_tag_can_overlap_with_match_regex(self):
        """Wildcard tag patterns should not produce false Match_Regex mismatch warnings."""
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.*

            [OUTPUT]
                Name stdout
                Match_Regex ^app\\.[0-9]+$
                Retry_Limit 3
            """,
            check="tags",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertFalse(
            any("^app\\.[0-9]+$" in warning and "doesn't match any INPUT/FILTER tags" in warning
                for warning in summary["warnings"])
        )

    def test_tag_check_true_match_regex_mismatch_still_warns(self):
        """Provable Match_Regex mismatches should still be reported."""
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs

            [OUTPUT]
                Name stdout
                Match_Regex ^infra\\..*$
                Retry_Limit 3
            """,
            check="tags",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(
            any("^infra\\..*$" in warning and "doesn't match any INPUT/FILTER tags" in warning
                for warning in summary["warnings"])
        )

    def test_unknown_output_plugin_is_reported(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
                Mem_Buf_Limit 50MB
                DB /tmp/flb.db

            [OUTPUT]
                Name madeup_output
                Match *
                Retry_Limit 3
            """,
            check="sections",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(
            any("Unknown OUTPUT plugin" in warning for warning in summary["warnings"])
        )

    def test_best_practices_reports_retry_db_and_mem_buf_gaps(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
                HTTP_Server On
                storage.metrics on

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs

            [OUTPUT]
                Name stdout
                Match *
            """,
            check="best-practices",
        )
        self.assertEqual(proc.returncode, 0)
        self.assertTrue(
            any(
                "DB parameter to all tail INPUTs" in recommendation
                for recommendation in summary["recommendations"]
            )
        )
        self.assertTrue(
            any(
                "Mem_Buf_Limit to all tail INPUTs" in recommendation
                for recommendation in summary["recommendations"]
            )
        )
        self.assertTrue(
            any(
                "Retry_Limit on all OUTPUTs" in recommendation
                for recommendation in summary["recommendations"]
            )
        )

    def test_fail_on_warning_changes_exit_code_and_valid_field(self):
        config = """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs

            [OUTPUT]
                Name es
                Match *
                Host elasticsearch.default.svc
                HTTP_Passwd hardcoded-password
                tls Off
                Retry_Limit 3
            """

        normal_proc, normal_summary = self.run_validator(config, check="security")
        strict_proc, strict_summary = self.run_validator(
            config, check="security", fail_on_warning=True
        )

        self.assertEqual(normal_proc.returncode, 0)
        self.assertTrue(normal_summary["valid"])
        self.assertNotEqual(strict_proc.returncode, 0)
        self.assertFalse(strict_summary["valid"])

    def test_missing_fluent_bit_is_recommendation_by_default(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
                Mem_Buf_Limit 50MB
                DB /tmp/flb.db

            [OUTPUT]
                Name stdout
                Match *
                Retry_Limit 3
            """,
            check="dry-run",
            env={"PATH": "/nonexistent"},
        )

        self.assertEqual(proc.returncode, 0)
        self.assertEqual(summary["errors"], [])
        self.assertTrue(
            any(
                "Dry-run skipped because fluent-bit binary is not available in PATH"
                in recommendation
                for recommendation in summary["recommendations"]
            )
        )

    def test_require_dry_run_escalates_missing_binary_to_error(self):
        proc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5

            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
                Mem_Buf_Limit 50MB
                DB /tmp/flb.db

            [OUTPUT]
                Name stdout
                Match *
                Retry_Limit 3
            """,
            check="dry-run",
            require_dry_run=True,
            env={"PATH": "/nonexistent"},
        )

        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(
            any(
                "Dry-run skipped because fluent-bit binary is not available in PATH"
                in error
                for error in summary["errors"]
            )
        )

    def test_text_report_uses_recommendation_label(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".conf", delete=False) as config_file:
            config_file.write(
                textwrap.dedent(
                    """
                    [SERVICE]
                        Flush 5

                    [INPUT]
                        Name tail
                        Path /var/log/*.log
                        Tag app.logs
                        Mem_Buf_Limit 50MB
                        DB /tmp/flb.db

                    [OUTPUT]
                        Name stdout
                        Match *
                        Retry_Limit 3
                    """
                ).strip()
                + "\n"
            )
            config_path = config_file.name

        cmd = [
            sys.executable,
            str(VALIDATOR),
            "--file",
            config_path,
            "--check",
            "dry-run",
        ]
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=False,
            env={**os.environ, "PATH": "/nonexistent"},
        )
        Path(config_path).unlink(missing_ok=True)

        self.assertEqual(proc.returncode, 0)
        self.assertIn("Recommendation:", proc.stdout)
        self.assertNotIn("Info", proc.stdout)

    def test_valid_basic_sample_is_clean_static_baseline(self):
        """The shipped valid sample should only emit the environment-driven dry-run recommendation."""
        proc, summary = self.run_validator_file(
            SKILL_DIR / "tests" / "valid-basic.conf",
            check="all",
            env={"PATH": "/nonexistent"},
        )

        self.assertEqual(proc.returncode, 0)
        self.assertEqual(summary["errors"], [])
        self.assertEqual(summary["warnings"], [])
        self.assertEqual(
            summary["recommendations"],
            [
                "Dry-run skipped because fluent-bit binary is not available in PATH; run dry-run in CI or a Fluent Bit runtime image."
            ],
        )


    # -------------------------------------------------------------------------
    # Regression tests for Bug 1: case-insensitive param key lookups
    # -------------------------------------------------------------------------

    def test_security_detects_tls_uppercase(self):
        """TLS Off written with uppercase key must still trigger a security warning."""
        _, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name es
                Match *
                Host es.example.com
                TLS Off
                Retry_Limit 3
            """,
            check="security",
        )
        self.assertTrue(
            any("TLS disabled" in w for w in summary["warnings"]),
            "Expected TLS warning for uppercase 'TLS Off'",
        )

    def test_security_detects_credential_lowercase_key(self):
        """Hardcoded credential written with lowercase key must still be detected."""
        _, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name es
                Match *
                Host es.example.com
                http_passwd mysecret
                Retry_Limit 3
            """,
            check="security",
        )
        self.assertTrue(
            any("HTTP_Passwd" in w for w in summary["warnings"]),
            "Expected credential warning for lowercase 'http_passwd'",
        )

    def test_s3_output_accepts_capitalized_params(self):
        """S3 output with Bucket/Region (capitalized) must not produce false errors."""
        rc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name s3
                Match *
                Bucket my-bucket
                Region us-east-1
                Retry_Limit 3
            """,
            check="sections",
        )
        self.assertFalse(
            any("missing required parameter 'bucket'" in e for e in summary["errors"]),
            "Capitalized 'Bucket' should be accepted for S3 output",
        )
        self.assertFalse(
            any("missing required parameter 'region'" in e for e in summary["errors"]),
            "Capitalized 'Region' should be accepted for S3 output",
        )

    def test_cloudwatch_accepts_capitalized_log_group_name(self):
        """CloudWatch with Log_Group_Name (capitalized) must not produce a false error."""
        _, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name cloudwatch_logs
                Match *
                region us-east-1
                Log_Group_Name /my/log/group
                Retry_Limit 3
            """,
            check="sections",
        )
        self.assertFalse(
            any("missing required parameter 'log_group_name'" in e for e in summary["errors"]),
            "Capitalized 'Log_Group_Name' should be accepted for CloudWatch output",
        )

    # -------------------------------------------------------------------------
    # Regression test for Bug 2: duplicate TLS warnings for OpenTelemetry
    # -------------------------------------------------------------------------

    def test_opentelemetry_no_duplicate_tls_warnings(self):
        """TLS Off on an OpenTelemetry output must produce exactly one TLS warning."""
        _, summary = self.run_validator(
            """
            [SERVICE]
                Flush 5
                HTTP_Server On
                storage.metrics on
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
                Mem_Buf_Limit 50MB
                DB /tmp/flb.db
            [OUTPUT]
                Name opentelemetry
                Match *
                Host otel-collector.example.com
                tls Off
                Retry_Limit 3
            """,
            check="all",
        )
        tls_warnings = [w for w in summary["warnings"] if "TLS disabled" in w]
        self.assertEqual(
            len(tls_warnings),
            1,
            f"Expected exactly one TLS warning, got {len(tls_warnings)}: {tls_warnings}",
        )

    # -------------------------------------------------------------------------
    # Regression test for Bug 3: Flush float false positive error
    # -------------------------------------------------------------------------

    def test_flush_float_is_not_an_error(self):
        """Flush 0.5 (valid sub-second float) must not produce an error."""
        rc, summary = self.run_validator(
            """
            [SERVICE]
                Flush 0.5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name stdout
                Match *
            """,
            check="sections",
        )
        self.assertFalse(
            any("Flush must be a number" in e for e in summary["errors"]),
            "Flush 0.5 should not raise a parse error",
        )
        self.assertTrue(
            any("Flush interval < 1 second" in w for w in summary["warnings"]),
            "Flush 0.5 should produce a sub-second performance warning",
        )

    # -------------------------------------------------------------------------
    # Regression tests for Gap 1: @INCLUDE and @SET directives
    # -------------------------------------------------------------------------

    def test_include_directive_does_not_error(self):
        """@INCLUDE directive must not produce a parse error."""
        _, summary = self.run_validator(
            """
            @INCLUDE /etc/fluent-bit/parsers.conf

            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name stdout
                Match *
            """,
            check="structure",
        )
        self.assertFalse(
            any("outside of a section" in e for e in summary["errors"]),
            "@INCLUDE should not be reported as 'Parameter outside of a section'",
        )

    def test_set_directive_does_not_error(self):
        """@SET directive must not produce a parse error."""
        _, summary = self.run_validator(
            """
            @SET my_path=/var/log/*.log

            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name stdout
                Match *
            """,
            check="structure",
        )
        self.assertFalse(
            any("outside of a section" in e for e in summary["errors"]),
            "@SET should not be reported as 'Parameter outside of a section'",
        )

    def test_include_directive_emits_recommendation(self):
        """@INCLUDE directive must produce a recommendation to validate the included file."""
        _, summary = self.run_validator(
            """
            @INCLUDE parsers.conf

            [SERVICE]
                Flush 5
            [INPUT]
                Name tail
                Path /var/log/*.log
                Tag app.logs
            [OUTPUT]
                Name stdout
                Match *
            """,
            check="structure",
        )
        self.assertTrue(
            any("@INCLUDE" in r and "parsers.conf" in r for r in summary["recommendations"]),
            "Expected a recommendation about the @INCLUDE directive",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
