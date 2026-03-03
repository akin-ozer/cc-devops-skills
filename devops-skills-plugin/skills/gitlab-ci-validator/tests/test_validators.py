#!/usr/bin/env python3
"""Regression tests for gitlab-ci-validator bug fixes and gap coverage.

Each test class focuses on one bug or gap fix:
  - TestBug1StartIn       : 'start_in' accepted as a valid rule keyword
  - TestBug2FallbackKeys  : 'fallback_keys' accepted as a valid cache keyword
  - TestGap1ImageNoTag    : images without a version tag are detected
  - TestGap2EchoSecrets   : prefixed / brace-wrapped secret variables are detected
  - TestGap3ArtifactPaths : security-report filenames not false-flagged as sensitive
"""

import json
import os
import subprocess
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


SKILL_DIR = Path(__file__).resolve().parent.parent
SYNTAX_VALIDATOR = SKILL_DIR / "scripts" / "validate_syntax.py"
SECURITY_CHECKER = SKILL_DIR / "scripts" / "check_security.py"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _run_syntax(yaml_text: str) -> tuple[subprocess.CompletedProcess, dict]:
    """Write yaml_text to a temp file and run validate_syntax.py --json."""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yml", delete=False
    ) as f:
        f.write(textwrap.dedent(yaml_text).strip() + "\n")
        path = f.name
    try:
        proc = subprocess.run(
            [sys.executable, str(SYNTAX_VALIDATOR), path, "--json"],
            capture_output=True,
            text=True,
            check=False,
        )
        result = json.loads(proc.stdout)
    finally:
        Path(path).unlink(missing_ok=True)
    return proc, result


def _run_security(yaml_text: str) -> tuple[subprocess.CompletedProcess, dict]:
    """Write yaml_text to a temp file and run check_security.py --json."""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".yml", delete=False
    ) as f:
        f.write(textwrap.dedent(yaml_text).strip() + "\n")
        path = f.name
    try:
        proc = subprocess.run(
            [sys.executable, str(SECURITY_CHECKER), path, "--json"],
            capture_output=True,
            text=True,
            check=False,
        )
        result = json.loads(proc.stdout)
    finally:
        Path(path).unlink(missing_ok=True)
    return proc, result


def _issue_rules(result: dict) -> list[str]:
    """Return list of rule IDs from a JSON result."""
    return [issue["rule"] for issue in result.get("issues", [])]


def _issue_messages(result: dict) -> list[str]:
    """Return list of messages from a JSON result."""
    return [issue["message"] for issue in result.get("issues", [])]


# ---------------------------------------------------------------------------
# Bug 1 — 'start_in' is a valid rule keyword (required for when: delayed)
# ---------------------------------------------------------------------------

class TestBug1StartIn(unittest.TestCase):
    """'start_in' must not be flagged as an unknown rule keyword."""

    _PIPELINE = """
        stages:
          - deploy

        delayed-deploy:
          stage: deploy
          image: alpine:3.18
          script:
            - echo "deploying after delay"
          rules:
            - when: delayed
              start_in: 5 minutes
    """

    def test_start_in_not_flagged_as_unknown_rule_keyword(self):
        """'start_in' alongside 'when: delayed' must produce no unknown-rule-keyword error."""
        _, result = _run_syntax(self._PIPELINE)
        unknown_kw_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "unknown-rule-keyword"
            and "start_in" in issue["message"]
        ]
        self.assertEqual(
            unknown_kw_errors,
            [],
            f"Unexpected 'start_in' keyword errors: {unknown_kw_errors}",
        )

    def test_pipeline_with_only_start_in_rule_passes(self):
        """A pipeline whose only rule keyword is start_in (with when: delayed) must be valid."""
        _, result = _run_syntax(self._PIPELINE)
        errors = [i for i in result.get("issues", []) if i["severity"] == "error"]
        self.assertEqual(
            errors,
            [],
            f"Unexpected errors in delayed-job pipeline: {errors}",
        )


# ---------------------------------------------------------------------------
# Bug 2 — 'fallback_keys' is a valid cache keyword (GitLab ≥ 15.3)
# ---------------------------------------------------------------------------

class TestBug2FallbackKeys(unittest.TestCase):
    """'fallback_keys' must not be flagged as an unknown cache keyword."""

    _PIPELINE = """
        stages:
          - build

        build-job:
          stage: build
          image: alpine:3.18
          script:
            - make build
          cache:
            key: $CI_COMMIT_REF_SLUG
            fallback_keys:
              - $CI_DEFAULT_BRANCH
            paths:
              - .cache/
    """

    def test_fallback_keys_not_flagged_as_unknown_cache_keyword(self):
        """'fallback_keys' in cache must produce no unknown-cache-keyword error."""
        _, result = _run_syntax(self._PIPELINE)
        unknown_kw_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "unknown-cache-keyword"
            and "fallback_keys" in issue["message"]
        ]
        self.assertEqual(
            unknown_kw_errors,
            [],
            f"Unexpected 'fallback_keys' keyword errors: {unknown_kw_errors}",
        )

    def test_pipeline_with_fallback_keys_passes(self):
        """A pipeline using fallback_keys in cache must not have any errors."""
        _, result = _run_syntax(self._PIPELINE)
        errors = [i for i in result.get("issues", []) if i["severity"] == "error"]
        self.assertEqual(
            errors,
            [],
            f"Unexpected errors in fallback_keys pipeline: {errors}",
        )


# ---------------------------------------------------------------------------
# Gap 1 — Images without a version tag are flagged (implicit :latest)
# ---------------------------------------------------------------------------

class TestGap1ImageNoTag(unittest.TestCase):
    """Security checker must detect images that carry no version tag."""

    def test_image_with_no_tag_is_flagged(self):
        """'ubuntu' (no tag) must produce an image-no-tag security warning."""
        _, result = _run_security("""
            build:
              image: ubuntu
              script:
                - echo hello
        """)
        self.assertIn(
            "image-no-tag",
            _issue_rules(result),
            "Expected 'image-no-tag' issue for untagged image 'ubuntu'",
        )

    def test_image_with_registry_and_no_tag_is_flagged(self):
        """'registry.example.com/myapp' (no tag) must produce an image-no-tag warning."""
        _, result = _run_security("""
            build:
              image: registry.example.com/myapp
              script:
                - echo hello
        """)
        self.assertIn(
            "image-no-tag",
            _issue_rules(result),
            "Expected 'image-no-tag' for registry image without tag",
        )

    def test_image_pinned_by_digest_is_not_flagged(self):
        """An image pinned via SHA256 digest must not produce any tag-related issue."""
        _, result = _run_security("""
            build:
              image: ubuntu@sha256:abc123def456abc123def456abc123def456abc123def456abc123def456abc1
              script:
                - echo hello
        """)
        tag_issues = [
            rule for rule in _issue_rules(result)
            if rule in ("image-no-tag", "image-latest-tag")
        ]
        self.assertEqual(
            tag_issues,
            [],
            f"Digest-pinned image must not produce tag issues, got: {tag_issues}",
        )

    def test_image_with_explicit_tag_is_not_flagged(self):
        """'ubuntu:22.04' (explicit tag) must not produce any image-no-tag issue."""
        _, result = _run_security("""
            build:
              image: ubuntu:22.04
              script:
                - echo hello
        """)
        self.assertNotIn(
            "image-no-tag",
            _issue_rules(result),
            "Explicitly tagged image must not produce 'image-no-tag'",
        )

    def test_image_variable_reference_is_not_flagged(self):
        """An image set via a CI variable ($IMAGE) must not produce a false 'image-no-tag'."""
        _, result = _run_security("""
            build:
              image: $MY_CUSTOM_IMAGE
              script:
                - echo hello
        """)
        self.assertNotIn(
            "image-no-tag",
            _issue_rules(result),
            "Variable-reference image must not produce 'image-no-tag'",
        )


# ---------------------------------------------------------------------------
# Gap 2 — Prefixed/brace-wrapped secret variables are detected in echo
# ---------------------------------------------------------------------------

class TestGap2EchoSecrets(unittest.TestCase):
    """Security checker must detect secret-variable echoes regardless of name prefix."""

    def _secret_warning_rules(self, result: dict) -> list[str]:
        return [
            i["rule"] for i in result.get("issues", [])
            if "echo" in i["message"].lower() or "print" in i["message"].lower()
            or "secret" in i["message"].lower() or "password" in i["message"].lower()
        ]

    def test_echo_db_password_is_detected(self):
        """'echo $DB_PASSWORD' must be flagged as echoing a secret."""
        _, result = _run_security("""
            build:
              image: alpine:3.18
              script:
                - echo $DB_PASSWORD
        """)
        rules = _issue_rules(result)
        self.assertTrue(
            any("secret" in r or "echo" in r for r in rules),
            f"Expected secret-echo issue for 'echo $DB_PASSWORD', got rules: {rules}",
        )

    def test_echo_my_secret_is_detected(self):
        """'echo $MY_SECRET' (prefixed variable) must be flagged."""
        _, result = _run_security("""
            build:
              image: alpine:3.18
              script:
                - echo $MY_SECRET
        """)
        rules = _issue_rules(result)
        self.assertTrue(
            any("secret" in r or "echo" in r for r in rules),
            f"Expected secret-echo issue for 'echo $MY_SECRET', got rules: {rules}",
        )

    def test_echo_brace_wrapped_token_is_detected(self):
        """'echo ${API_TOKEN}' (brace-wrapped) must be flagged."""
        _, result = _run_security("""
            build:
              image: alpine:3.18
              script:
                - echo ${API_TOKEN}
        """)
        rules = _issue_rules(result)
        self.assertTrue(
            any("secret" in r or "echo" in r for r in rules),
            f"Expected secret-echo issue for 'echo ${{API_TOKEN}}', got rules: {rules}",
        )

    def test_echo_app_password_is_detected(self):
        """'echo $APP_PASSWORD' must be flagged."""
        _, result = _run_security("""
            build:
              image: alpine:3.18
              script:
                - echo $APP_PASSWORD
        """)
        rules = _issue_rules(result)
        self.assertTrue(
            any("secret" in r or "echo" in r for r in rules),
            f"Expected secret-echo issue for 'echo $APP_PASSWORD', got rules: {rules}",
        )

    def test_echo_plain_var_is_not_flagged(self):
        """'echo $BUILD_VERSION' (non-secret variable) must not produce a false positive."""
        _, result = _run_security("""
            build:
              image: alpine:3.18
              script:
                - echo $BUILD_VERSION
        """)
        echo_secret_issues = [
            i for i in result.get("issues", [])
            if "BUILD_VERSION" in i.get("message", "")
        ]
        self.assertEqual(
            echo_secret_issues,
            [],
            f"Non-secret variable must not be flagged: {echo_secret_issues}",
        )


# ---------------------------------------------------------------------------
# Gap 3 — Security-scan report artifact paths are not false-flagged
# ---------------------------------------------------------------------------

class TestGap3ArtifactPaths(unittest.TestCase):
    """artifact-sensitive-path must use component-aware matching."""

    def test_secrets_report_json_is_not_flagged(self):
        """'secrets-report.json' is a standard scan output and must not be flagged."""
        _, result = _run_security("""
            security-scan:
              image: alpine:3.18
              script:
                - run-scan
              artifacts:
                paths:
                  - secrets-report.json
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertEqual(
            artifact_issues,
            [],
            f"'secrets-report.json' must not be flagged as sensitive: {artifact_issues}",
        )

    def test_gl_secret_detection_report_is_not_flagged(self):
        """'gl-secret-detection-report.json' (GitLab built-in output) must not be flagged."""
        _, result = _run_security("""
            secret-detection:
              image: alpine:3.18
              script:
                - run-secret-detection
              artifacts:
                paths:
                  - gl-secret-detection-report.json
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertEqual(
            artifact_issues,
            [],
            f"'gl-secret-detection-report.json' must not be flagged: {artifact_issues}",
        )

    def test_secrets_directory_is_flagged(self):
        """A bare 'secrets/' directory in artifacts must still be flagged."""
        _, result = _run_security("""
            bad-job:
              image: alpine:3.18
              script:
                - make certs
              artifacts:
                paths:
                  - secrets/
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertNotEqual(
            artifact_issues,
            [],
            "A 'secrets/' directory must be flagged as sensitive",
        )

    def test_credentials_directory_is_flagged(self):
        """A bare 'credentials/' directory in artifacts must be flagged."""
        _, result = _run_security("""
            bad-job:
              image: alpine:3.18
              script:
                - generate-credentials
              artifacts:
                paths:
                  - credentials/
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertNotEqual(
            artifact_issues,
            [],
            "A 'credentials/' directory must be flagged as sensitive",
        )

    def test_nested_secrets_file_is_flagged(self):
        """A file directly inside a secrets/ directory must be flagged."""
        _, result = _run_security("""
            bad-job:
              image: alpine:3.18
              script:
                - make certs
              artifacts:
                paths:
                  - config/secrets/private.key
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertNotEqual(
            artifact_issues,
            [],
            "'config/secrets/private.key' must be flagged as sensitive",
        )

    def test_dot_env_file_is_flagged(self):
        """'.env' artifact must still be caught by the component-aware check."""
        _, result = _run_security("""
            bad-job:
              image: alpine:3.18
              script:
                - env > .env
              artifacts:
                paths:
                  - .env
        """)
        artifact_issues = [
            i for i in result.get("issues", [])
            if i["rule"] == "artifact-sensitive-path"
        ]
        self.assertNotEqual(
            artifact_issues,
            [],
            "'.env' artifact must be flagged as sensitive",
        )


# ---------------------------------------------------------------------------
# Bug 3 — .pre and .post are always valid stages even when stages: is defined
# ---------------------------------------------------------------------------

class TestBug3PrePostStages(unittest.TestCase):
    """.pre and .post must be valid stages regardless of the stages: list."""

    _PIPELINE_WITH_POST = """
        stages:
          - build
          - deploy

        build-job:
          stage: build
          image: alpine:3.18
          script:
            - make build

        cleanup:
          stage: .post
          image: alpine:3.18
          script:
            - echo "cleanup"
          when: always
    """

    _PIPELINE_WITH_PRE = """
        stages:
          - build

        setup:
          stage: .pre
          image: alpine:3.18
          script:
            - echo "setup"

        build-job:
          stage: build
          image: alpine:3.18
          script:
            - make build
    """

    def test_post_stage_not_flagged_when_stages_defined(self):
        """'.post' must not be flagged as undefined when a stages: list is present."""
        _, result = _run_syntax(self._PIPELINE_WITH_POST)
        post_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "job-stage-undefined" and ".post" in issue["message"]
        ]
        self.assertEqual(
            post_errors,
            [],
            f"'.post' stage must never raise job-stage-undefined: {post_errors}",
        )

    def test_post_stage_pipeline_passes(self):
        """A pipeline using .post with a custom stages: list must have no errors."""
        _, result = _run_syntax(self._PIPELINE_WITH_POST)
        errors = [i for i in result.get("issues", []) if i["severity"] == "error"]
        self.assertEqual(
            errors,
            [],
            f"Unexpected errors for pipeline with .post stage: {errors}",
        )

    def test_pre_stage_not_flagged_when_stages_defined(self):
        """'.pre' must not be flagged as undefined when a stages: list is present."""
        _, result = _run_syntax(self._PIPELINE_WITH_PRE)
        pre_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "job-stage-undefined" and ".pre" in issue["message"]
        ]
        self.assertEqual(
            pre_errors,
            [],
            f"'.pre' stage must never raise job-stage-undefined: {pre_errors}",
        )


# ---------------------------------------------------------------------------
# Bug 4 — docker-build template: echo with colon-space must parse as string
# ---------------------------------------------------------------------------

class TestBug4DockerBuildTemplate(unittest.TestCase):
    """The docker-build template's echo command must be parsed as a string, not a dict."""

    # Reproduces the exact pattern from docker-build.yml:
    # an echo command containing ': ' that YAML previously parsed as a mapping.
    _PIPELINE = """
        stages:
          - build

        build-docker-dind:
          stage: build
          image: docker:24-dind
          services:
            - docker:24-dind
          script:
            - 'echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"'
            - docker build --tag myapp:latest .
    """

    def test_quoted_echo_with_colon_not_flagged(self):
        """A YAML-quoted echo command containing ': ' must produce no script-item errors."""
        _, result = _run_syntax(self._PIPELINE)
        script_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "job-script-item-invalid"
        ]
        self.assertEqual(
            script_errors,
            [],
            f"Quoted echo command must not raise job-script-item-invalid: {script_errors}",
        )

    def test_unquoted_echo_with_colon_is_flagged(self):
        """An unquoted echo with ': ' inside must raise a script-item error (YAML dict)."""
        bad_pipeline = """
            stages:
              - build

            build-docker-dind:
              stage: build
              image: docker:24-dind
              script:
                - echo "Building Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
                - docker build --tag myapp:latest .
        """
        _, result = _run_syntax(bad_pipeline)
        script_errors = [
            issue for issue in result.get("issues", [])
            if issue["rule"] == "job-script-item-invalid"
        ]
        self.assertNotEqual(
            script_errors,
            [],
            "An unquoted echo with colon-space must be caught as job-script-item-invalid",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
