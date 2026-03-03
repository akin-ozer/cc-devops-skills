#!/usr/bin/env python3
"""Regression tests for detect_custom_resources.py."""

import json
import os
import subprocess
import tempfile
import textwrap
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
DETECTOR = SKILL_DIR / "scripts" / "detect_custom_resources.py"
FIXTURE_DIR = SKILL_DIR / "test" / "infrastructure"


def run_detector(target_dir: Path) -> dict:
    result = subprocess.run(
        ["python3", str(DETECTOR), str(target_dir), "--format", "json"],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


class DetectCustomResourcesTests(unittest.TestCase):
    def test_detects_expected_resources_and_ignores_cache_paths(self) -> None:
        report = run_detector(FIXTURE_DIR)

        providers = set(report["custom_providers"].keys())
        self.assertIn("datadog/datadog", providers)
        self.assertIn("newrelic/newrelic", providers)

        module_sources = set(report["custom_modules"].keys())
        self.assertIn("tfr:///terraform-aws-modules/vpc/aws", module_sources)
        self.assertIn(
            "git::https://github.com/cloudposse/terraform-aws-elasticache-redis.git",
            module_sources,
        )
        self.assertNotIn(
            "terraform-aws-modules/s3-bucket/aws",
            module_sources,
            "cache-derived modules should not be detected",
        )

        all_module_files = [
            item["file"]
            for modules in report["custom_modules"].values()
            for item in modules
        ]
        self.assertFalse(any(".terragrunt-cache" in path for path in all_module_files))

    def test_handles_required_provider_without_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            fixture = Path(tmp_dir) / "main.tf"
            fixture.write_text(
                textwrap.dedent(
                    """
                    terraform {
                      required_providers {
                        custom = {
                          source = "company/custom"
                        }
                      }
                    }
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            report = run_detector(Path(tmp_dir))
            self.assertIn("company/custom", report["custom_providers"])
            self.assertEqual(report["custom_providers"]["company/custom"], ["unspecified"])

    def test_parses_generate_blocks_with_custom_heredoc_delimiter(self) -> None:
        with tempfile.TemporaryDirectory() as tmp_dir:
            fixture = Path(tmp_dir) / "terragrunt.hcl"
            fixture.write_text(
                textwrap.dedent(
                    """
                    generate "provider" {
                      path      = "provider.tf"
                      if_exists = "overwrite_terragrunt"
                      contents  = <<EOT
                    terraform {
                      required_providers {
                        datadog = {
                          source  = "datadog/datadog"
                          version = "~> 3.30.0"
                        }
                      }
                    }
                    EOT
                    }
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            report = run_detector(Path(tmp_dir))
            self.assertIn("datadog/datadog", report["custom_providers"])
            self.assertIn("~> 3.30.0", report["custom_providers"]["datadog/datadog"])

    def test_cache_directories_are_excluded(self) -> None:
        """Cache exclusion must be verified with a real .terragrunt-cache directory.

        The broad fixture-level test only asserts the absence of a module that was
        never present in the first place.  This test creates an actual cache directory
        containing a conflicting module and confirms it is not surfaced in results.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            # Real unit file that should be detected.
            real_dir = Path(tmp_dir) / "dev" / "vpc"
            real_dir.mkdir(parents=True)
            (real_dir / "terragrunt.hcl").write_text(
                'terraform { source = "tfr:///terraform-aws-modules/vpc/aws?version=5.1.0" }\n',
                encoding="utf-8",
            )

            # Simulate a .terragrunt-cache entry that should be ignored.
            cache_dir = real_dir / ".terragrunt-cache" / "abc123" / "module"
            cache_dir.mkdir(parents=True)
            (cache_dir / "main.tf").write_text(
                textwrap.dedent(
                    """
                    module "s3_bucket" {
                      source  = "terraform-aws-modules/s3-bucket/aws"
                      version = "4.0.0"
                    }
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            report = run_detector(Path(tmp_dir))
            module_sources = set(report["custom_modules"].keys())

            self.assertIn(
                "tfr:///terraform-aws-modules/vpc/aws",
                module_sources,
                "real module should be detected",
            )
            self.assertNotIn(
                "terraform-aws-modules/s3-bucket/aws",
                module_sources,
                "module inside .terragrunt-cache must not be surfaced",
            )

    def test_module_block_with_nested_object_before_source(self) -> None:
        """Source attribute must be found even when nested blocks appear first.

        The old regex (non-greedy .*?) stopped at the first closing brace it saw,
        so a source attribute placed after any nested object was silently dropped.
        The fix uses _extract_balanced_braces, matching the approach used for
        required_providers.
        """
        with tempfile.TemporaryDirectory() as tmp_dir:
            fixture = Path(tmp_dir) / "main.tf"
            fixture.write_text(
                textwrap.dedent(
                    """
                    module "example" {
                      config = {
                        key = "value"
                      }
                      source  = "my-org/example-module/aws"
                      version = "1.2.0"
                    }
                    """
                ).strip()
                + "\n",
                encoding="utf-8",
            )

            report = run_detector(Path(tmp_dir))
            self.assertIn(
                "my-org/example-module/aws",
                report["custom_modules"],
                "source appearing after a nested object block must still be detected",
            )
            detected = report["custom_modules"]["my-org/example-module/aws"]
            self.assertEqual(detected[0]["version"], "1.2.0")


if __name__ == "__main__":
    unittest.main()
