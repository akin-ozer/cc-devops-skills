#!/usr/bin/env python3
"""
Regression tests for count_yaml_documents.py and related skill guidance.

Run from repository root:
    python3 devops-skills-plugin/skills/k8s-yaml-validator/scripts/test_count_yaml_documents.py
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SKILL_DIR = SCRIPT_DIR.parent
sys.path.insert(0, str(SCRIPT_DIR))

from count_yaml_documents import count_yaml_documents  # noqa: E402


class TestCountYamlDocuments(unittest.TestCase):
    def test_single_document_without_separators(self):
        content = """\
apiVersion: v1
kind: ConfigMap
metadata:
  name: single
"""
        self.assertEqual(count_yaml_documents(content), (1, 0))

    def test_multi_document_with_top_level_separator(self):
        content = """\
apiVersion: v1
kind: ConfigMap
metadata:
  name: one
---
apiVersion: v1
kind: Service
metadata:
  name: two
"""
        self.assertEqual(count_yaml_documents(content), (2, 1))

    def test_indented_separator_in_literal_block_is_not_a_document_separator(self):
        content = """\
apiVersion: v1
kind: ConfigMap
metadata:
  name: script
data:
  script: |
    echo start
    ---
    echo end
---
apiVersion: v1
kind: Service
metadata:
  name: service
"""
        self.assertEqual(count_yaml_documents(content), (2, 1))

    def test_comment_only_document_and_explicit_end_marker(self):
        content = """\
---
# Comment-only document should not count
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: with-end-marker
...
"""
        self.assertEqual(count_yaml_documents(content), (1, 2))

    def test_mixed_valid_and_invalid_documents_count_deterministically(self):
        content = """\
apiVersion: v1
kind: ConfigMap
metadata:
  name: valid-a
---
apiVersion: v1
kind Deployment
metadata:
  name: invalid-b
---
apiVersion: v1
kind: Service
metadata:
  name: valid-c
"""
        self.assertEqual(count_yaml_documents(content), (3, 2))

    def test_edge_case_fixture_counts_match_expected(self):
        fixture = SKILL_DIR / "test" / "document-counter-edge-cases.yaml"
        self.assertTrue(fixture.exists(), "Expected edge-case fixture to exist")

        command = [sys.executable, str(SCRIPT_DIR / "count_yaml_documents.py"), str(fixture)]
        result = subprocess.run(command, capture_output=True, text=True, check=True)

        payload = json.loads(result.stdout)
        self.assertEqual(payload["documents"], 2)
        self.assertEqual(payload["separators"], 3)


class TestDryRunGuidanceRegression(unittest.TestCase):
    def test_validate_false_guidance_is_explicitly_parse_only(self):
        skill_doc_path = SKILL_DIR / "references" / "extended-guide.md"
        skill_doc = skill_doc_path.read_text(encoding="utf-8")
        self.assertIn(
            "`--validate=false` disables schema/type/required-field validation",
            skill_doc,
        )
        self.assertIn(
            "Limited parse-only validation (no cluster access) - schema and admission policies not checked",
            skill_doc,
        )
        self.assertNotIn("- Basic schema validation", skill_doc)


if __name__ == "__main__":
    unittest.main()
