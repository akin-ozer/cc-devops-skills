#!/usr/bin/env python3
"""Regression tests for gitlab-ci-generator extended-guide contracts."""

from pathlib import Path
import unittest


SKILL_GUIDE = (
    Path(__file__).resolve().parent.parent / "references" / "extended-guide.md"
)


def _between(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    end = text.find(end_marker, start + len(start_marker))
    if start == -1 or end == -1:
        raise AssertionError(
            f"Could not find section boundaries: {start_marker!r} -> {end_marker!r}"
        )
    return text[start:end]


class TestP1ValidationFallbackContract(unittest.TestCase):
    """Ensure fallback validation always targets the generated pipeline file."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.skill_text = SKILL_GUIDE.read_text(encoding="utf-8")
        cls.script_fallback = _between(
            cls.skill_text,
            "2. **Script fallback path (if validator skill cannot be invoked):**",
            "3. **Manual fallback path (only if both primary and script paths are unavailable):**",
        )

    def test_declares_pipeline_file_variable(self) -> None:
        self.assertIn('PIPELINE_FILE="<generated-output-path>"', self.script_fallback)

    def test_requires_file_existence_precheck(self) -> None:
        self.assertIn('if [[ ! -f "$PIPELINE_FILE" ]]; then', self.script_fallback)
        self.assertIn('echo "ERROR: CI file not found: $PIPELINE_FILE" >&2', self.script_fallback)

    def test_validator_commands_use_selected_pipeline_file(self) -> None:
        self.assertIn(
            'validate_gitlab_ci.sh "$PIPELINE_FILE"',
            self.script_fallback,
            "Fallback validator commands must use PIPELINE_FILE.",
        )
        self.assertNotIn(
            "validate_gitlab_ci.sh .gitlab-ci.yml",
            self.script_fallback,
            "Hardcoded .gitlab-ci.yml fallback commands can validate the wrong file.",
        )

    def test_api_lint_fallback_uses_generated_file_content(self) -> None:
        self.assertIn('$(<"$PIPELINE_FILE")', self.script_fallback)
        self.assertIn(
            "https://gitlab.com/api/v4/projects/:id/ci/lint?include_merged_yaml=true",
            self.script_fallback,
        )


class TestP2ModeContractConsistency(unittest.TestCase):
    """Ensure Targeted mode is first-class across routing, checklist, and summary."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.skill_text = SKILL_GUIDE.read_text(encoding="utf-8")
        cls.step1 = _between(
            cls.skill_text,
            "### Step 1: Classify Complexity (REQUIRED)",
            "### Step 2: Load References by Tier (REQUIRED)",
        )
        cls.step2 = _between(
            cls.skill_text,
            "### Step 2: Load References by Tier (REQUIRED)",
            "### Step 3: Confirm Understanding (EXPLICIT OUTPUT REQUIRED)",
        )
        cls.checklist_mode = _between(
            cls.skill_text,
            "### Mode and References",
            "### Generation Standards Applied",
        )
        cls.summary = _between(
            cls.skill_text,
            "## Summary",
            "Generate GitLab CI/CD pipelines that are:",
        )

    def test_step1_includes_targeted_mode(self) -> None:
        self.assertIn("| **Targeted** |", self.step1)

    def test_step2_has_targeted_specific_loading_rules(self) -> None:
        self.assertIn("**Targeted mode (review/Q&A/snippet/focused fix):**", self.step2)
        self.assertIn(
            "Do not enforce Full-generation Tier 1/Tier 2 checklist items.",
            self.step2,
        )
        self.assertIn(
            "Tier 1 (Required for complete pipeline generation in Lightweight and Full modes)",
            self.step2,
        )

    def test_checklist_mode_selection_supports_targeted(self) -> None:
        self.assertIn("Complexity mode selected (`Targeted`, `Lightweight`, or `Full`)", self.checklist_mode)
        self.assertIn(
            "For **Targeted** mode: only directly relevant files/references loaded",
            self.checklist_mode,
        )
        self.assertNotIn(
            "Complexity mode selected (`Lightweight` or `Full`)",
            self.checklist_mode,
        )

    def test_summary_includes_all_modes(self) -> None:
        self.assertIn(
            "Classify Complexity** - choose `Targeted`, `Lightweight`, or `Full` mode.",
            self.summary,
        )
        self.assertIn(
            "For `Targeted` mode, load only directly relevant files.",
            self.summary,
        )


if __name__ == "__main__":
    unittest.main()
