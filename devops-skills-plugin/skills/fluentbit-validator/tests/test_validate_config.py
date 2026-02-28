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


if __name__ == "__main__":
    unittest.main(verbosity=2)
