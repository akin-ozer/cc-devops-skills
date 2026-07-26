#!/usr/bin/env python3
"""Regression tests for logql-generator documentation contracts."""

from pathlib import Path
import re
import unittest


SKILL_DIR = Path(__file__).resolve().parent.parent
COMMON_QUERIES = SKILL_DIR / "examples" / "common_queries.logql"


def _resolve_extended_guide() -> Path:
    candidate = SKILL_DIR / "references" / "extended-guide.md"
    if candidate.exists():
        return candidate
    raise FileNotFoundError(f"Could not find extended guide: {candidate}")


SKILL_GUIDE = _resolve_extended_guide()


def _between(text: str, start_marker: str, end_marker: str) -> str:
    start = text.find(start_marker)
    end = text.find(end_marker, start + len(start_marker))
    if start == -1 or end == -1:
        raise AssertionError(
            f"Could not find section boundaries: {start_marker!r} -> {end_marker!r}"
        )
    return text[start:end]


class TestVectorMatchingGuidance(unittest.TestCase):
    """Ensure ratio examples and guidance reflect actual LogQL vector matching behavior."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.examples_text = COMMON_QUERIES.read_text(encoding="utf-8")

    def test_does_not_claim_vector_matching_is_unsupported(self) -> None:
        bad_claim = re.compile(
            r"does\s+not\s+support.*on\(\).*group_left",
            re.IGNORECASE | re.DOTALL,
        )
        self.assertIsNone(
            bad_claim.search(self.examples_text),
            "Examples must not claim that on()/group_left() are unsupported in LogQL.",
        )

    def test_has_ratio_example_with_on_group_left_against_total(self) -> None:
        self.assertRegex(
            self.examples_text,
            re.compile(
                r"sum by \(status_code\)\s*\(rate\(\{app=\"api\"\} \| json \[5m\]\)\)\s*"
                r"/ on\(\) group_left\s*sum\(rate\(\{app=\"api\"\}\[5m\]\)\)",
                re.DOTALL,
            ),
        )

    def test_has_many_to_one_ratio_example_with_group_left(self) -> None:
        self.assertRegex(
            self.examples_text,
            re.compile(
                r"sum by \(app, status_code\)\s*\(rate\(\{job=\"http-server\"\} \| json \[5m\]\)\)\s*"
                r"/ on\(app\) group_left\s*"
                r"sum by \(app\)\s*\(rate\(\{job=\"http-server\"\} \| json \[5m\]\)\)",
                re.DOTALL,
            ),
        )


class TestBytesOverTimePlacement(unittest.TestCase):
    """Ensure bytes_over_time remains classified as a log-range aggregation."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.skill_text = SKILL_GUIDE.read_text(encoding="utf-8")
        cls.log_range_section = _between(
            cls.skill_text,
            "### Log Range Aggregations",
            "### Unwrapped Range Aggregations",
        )
        cls.unwrapped_section = _between(
            cls.skill_text,
            "### Unwrapped Range Aggregations",
            "### Aggregation Operators",
        )

    def test_bytes_over_time_is_listed_in_log_range_section(self) -> None:
        self.assertIn("`bytes_over_time(log-range)`", self.log_range_section)

    def test_bytes_over_time_is_not_listed_in_unwrapped_section(self) -> None:
        self.assertNotIn("bytes_over_time", self.unwrapped_section)

    def test_skill_has_bytes_over_time_usage_rule(self) -> None:
        self.assertIn(
            "Use `bytes_over_time(<log-range>)` for raw log-byte volume.",
            self.skill_text,
        )
        self.assertIn(
            "Use `| unwrap bytes(field)` with unwrapped range aggregations",
            self.skill_text,
        )


if __name__ == "__main__":
    unittest.main()
