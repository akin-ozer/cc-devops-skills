#!/usr/bin/env python3
"""
Regression tests for the terragrunt-generator skill.

Covers:
- All template files exist (including env.hcl)
- No invalid HCL attribute-name placeholders (brackets as keys)
- Required structural elements in each template
- No deprecated flags or attributes
- Catalog/stack value-key consistency
"""

import re
import unittest
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
TEMPLATES_DIR = SKILL_DIR / "assets" / "templates"
REFERENCES_DIR = SKILL_DIR / "references"


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _uncommented(content: str) -> str:
    """Strip HCL line comments so regex checks don't flag commented-out examples."""
    return "\n".join(
        line for line in content.splitlines()
        if not line.strip().startswith("#")
    )


def _all_templates() -> list[Path]:
    return list(TEMPLATES_DIR.rglob("*.hcl"))


def _all_references() -> list[Path]:
    return list(REFERENCES_DIR.rglob("*.md"))


# ──────────────────────────────────────────────────────────────────────────────
# 1. Existence
# ──────────────────────────────────────────────────────────────────────────────

class TemplateExistenceTests(unittest.TestCase):
    """All documented template files must be present."""

    def _assert_exists(self, *parts: str) -> None:
        p = TEMPLATES_DIR.joinpath(*parts)
        self.assertTrue(p.exists(), f"Missing template: {p.relative_to(SKILL_DIR)}")

    def test_root_template_exists(self):
        self._assert_exists("root", "terragrunt.hcl")

    def test_env_template_exists(self):
        """env.hcl is the foundation of Pattern A multi-environment setups."""
        self._assert_exists("env", "env.hcl")

    def test_child_template_exists(self):
        self._assert_exists("child", "terragrunt.hcl")

    def test_module_template_exists(self):
        self._assert_exists("module", "terragrunt.hcl")

    def test_stack_template_exists(self):
        self._assert_exists("stack", "terragrunt.stack.hcl")

    def test_catalog_template_exists(self):
        self._assert_exists("catalog", "terragrunt.hcl")


# ──────────────────────────────────────────────────────────────────────────────
# 2. HCL syntax safety
# ──────────────────────────────────────────────────────────────────────────────

# Matches bracket-wrapped identifiers used as bare HCL attribute names, e.g.:
#   [VARIABLE_NAME] = "something"
# Placeholders are valid inside quoted strings ("...") but NOT as attribute keys.
_INVALID_ATTRIBUTE_RE = re.compile(r"^\s*\[[A-Z0-9_ ]+\]\s*=", re.MULTILINE)


class HCLSyntaxTests(unittest.TestCase):
    """Templates must not contain invalid HCL attribute names."""

    def _check(self, path: Path) -> None:
        content = _read(path)
        active = _uncommented(content)
        bad = _INVALID_ATTRIBUTE_RE.findall(active)
        self.assertEqual(
            bad,
            [],
            f"{path.relative_to(SKILL_DIR)}: bracket-wrapped placeholder used as HCL "
            f"attribute name — this breaks HCL parsers: {bad}",
        )

    def test_root_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "root" / "terragrunt.hcl")

    def test_env_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "env" / "env.hcl")

    def test_child_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "child" / "terragrunt.hcl")

    def test_module_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "module" / "terragrunt.hcl")

    def test_stack_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "stack" / "terragrunt.stack.hcl")

    def test_catalog_no_invalid_hcl(self):
        self._check(TEMPLATES_DIR / "catalog" / "terragrunt.hcl")


# ──────────────────────────────────────────────────────────────────────────────
# 3. Root template required elements
# ──────────────────────────────────────────────────────────────────────────────

class RootTemplateTests(unittest.TestCase):
    ROOT = TEMPLATES_DIR / "root" / "terragrunt.hcl"

    @property
    def content(self) -> str:
        return _read(self.ROOT)

    def test_has_remote_state(self):
        self.assertIn("remote_state", self.content)

    def test_has_encrypt_true(self):
        self.assertIn("encrypt        = true", self.content)

    def test_has_errors_block_not_retryable_errors(self):
        """errors {} block must replace the deprecated retryable_errors attribute."""
        c = self.content
        self.assertIn("errors {", c, "Root template must use the errors {} block")
        # retryable_errors is only valid *inside* an errors.retry block in modern TG;
        # verify it doesn't appear as a top-level (outside errors block) attribute.
        before_errors = c.split("errors {")[0]
        self.assertNotIn(
            "retryable_errors",
            _uncommented(before_errors),
            "retryable_errors must not appear before the errors {} block",
        )

    def test_has_terragrunt_version_constraint(self):
        self.assertIn(
            "terragrunt_version_constraint",
            self.content,
            "Root template must declare terragrunt_version_constraint",
        )

    def test_has_terraform_version_constraint(self):
        self.assertIn(
            "terraform_version_constraint",
            self.content,
            "Root template must declare terraform_version_constraint",
        )

    def test_is_environment_agnostic(self):
        """root.hcl must not try to read env.hcl — Pattern A violation."""
        active = _uncommented(self.content)
        self.assertNotIn(
            'find_in_parent_folders("env.hcl")',
            active,
            "root.hcl must be environment-agnostic and must not read env.hcl",
        )

    def test_generate_uses_overwrite_terragrunt(self):
        self.assertIn("overwrite_terragrunt", self.content)


# ──────────────────────────────────────────────────────────────────────────────
# 4. env.hcl template required elements
# ──────────────────────────────────────────────────────────────────────────────

class EnvTemplateTests(unittest.TestCase):
    ENV = TEMPLATES_DIR / "env" / "env.hcl"

    @property
    def content(self) -> str:
        return _read(self.ENV)

    def test_has_locals_block(self):
        self.assertIn("locals {", self.content)

    def test_has_environment_key(self):
        self.assertIn("environment", self.content)

    def test_has_aws_region_key(self):
        self.assertIn("aws_region", self.content)

    def test_has_project_key(self):
        self.assertIn("project", self.content)

    def test_documents_pattern_a_usage(self):
        """env.hcl template must document that root.hcl must NOT read it."""
        self.assertIn(
            "DO NOT reference this file from root.hcl",
            self.content,
            "env.hcl template must warn against reading from root.hcl",
        )


# ──────────────────────────────────────────────────────────────────────────────
# 5. Child template required elements
# ──────────────────────────────────────────────────────────────────────────────

class ChildTemplateTests(unittest.TestCase):
    CHILD = TEMPLATES_DIR / "child" / "terragrunt.hcl"

    @property
    def content(self) -> str:
        return _read(self.CHILD)

    def test_uses_modern_root_include(self):
        self.assertIn('find_in_parent_folders("root.hcl")', self.content)

    def test_legacy_include_is_commented(self):
        """Legacy find_in_parent_folders() (no arg) must only appear in comments."""
        active = _uncommented(self.content)
        # find_in_parent_folders() with no argument is the legacy form
        self.assertNotIn(
            'find_in_parent_folders()',
            active,
            "Child template must not use bare find_in_parent_folders() in active code",
        )

    def test_has_mock_outputs_example(self):
        self.assertIn("mock_outputs", self.content)

    def test_has_exclude_block_example(self):
        """exclude block must replace deprecated skip attribute."""
        self.assertIn("exclude {", self.content)

    def test_no_active_skip_attribute(self):
        for line in self.content.splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            self.assertFalse(
                re.match(r"^skip\s*=", stripped),
                f"Child template contains deprecated 'skip' attribute: {line}",
            )


# ──────────────────────────────────────────────────────────────────────────────
# 6. Stack / catalog value-key consistency
# ──────────────────────────────────────────────────────────────────────────────

class StackCatalogConsistencyTests(unittest.TestCase):
    STACK = TEMPLATES_DIR / "stack" / "terragrunt.stack.hcl"
    CATALOG = TEMPLATES_DIR / "catalog" / "terragrunt.hcl"

    def test_catalog_uses_values_name(self):
        """Catalog template must read the generic 'name' key from values."""
        self.assertIn(
            "values.name",
            _read(self.CATALOG),
            "Catalog template must use values.name as the generic resource name",
        )

    def test_stack_passes_name_key_in_unit_values(self):
        """Stack template must pass 'name' (not unit-specific keys like vpc_name) in values."""
        content = _read(self.STACK)
        # All unit values blocks should use `name = ` not `vpc_name`, `db_name`, etc.
        active = _uncommented(content)
        for deprecated_key in ("vpc_name", "db_name", "app_name"):
            self.assertNotIn(
                deprecated_key,
                active,
                f"Stack template must not use unit-specific key '{deprecated_key}'. "
                f"Use the generic 'name' key instead to match catalog template.",
            )

    def test_stack_uses_shared_no_dot_variable(self):
        """All unit blocks must control no_dot_terragrunt_stack via a shared variable."""
        content = _read(self.STACK)
        self.assertIn(
            "use_direct_paths",
            content,
            "Stack template must declare use_direct_paths variable to ensure all "
            "units share the same no_dot_terragrunt_stack mode",
        )

    def test_stack_no_invalid_desired_count_placeholder(self):
        """desired_count must be a number literal, not a bracket placeholder."""
        active = _uncommented(_read(self.STACK))
        # The old template had `desired_count = [DESIRED_COUNT]` which is invalid HCL
        # (a tuple expression, not a number).
        self.assertNotIn(
            "[DESIRED_COUNT]",
            active,
            "desired_count must be a number literal, not a bracket placeholder",
        )


# ──────────────────────────────────────────────────────────────────────────────
# 7. Deprecated patterns in references
# ──────────────────────────────────────────────────────────────────────────────

class DeprecatedPatternTests(unittest.TestCase):
    """Verify deprecated Terragrunt patterns don't appear in reference files."""

    @property
    def _ref_content(self) -> str:
        return "\n".join(_read(f) for f in _all_references())

    @property
    def _template_content(self) -> str:
        return "\n".join(_read(f) for f in _all_templates())

    def test_no_terragrunt_quiet_flag_in_references(self):
        """--terragrunt-quiet is deprecated; use --quiet."""
        self.assertNotIn(
            "--terragrunt-quiet",
            self._ref_content,
            "References must not use deprecated '--terragrunt-quiet'. Use '--quiet'.",
        )

    def test_no_terragrunt_prefixed_flags_in_references(self):
        """--terragrunt-* flags are deprecated; use their unprefixed equivalents."""
        # Exclude URLs and comment lines from the check.
        bad = []
        for line in self._ref_content.splitlines():
            stripped = line.strip()
            if stripped.startswith("#") or "http" in stripped:
                continue
            flags = re.findall(r"--terragrunt-[a-z\-]+", stripped)
            bad.extend(flags)
        self.assertEqual(
            bad,
            [],
            f"References contain deprecated --terragrunt-* flags: {set(bad)}. "
            f"Use unprefixed equivalents (e.g., --quiet instead of --terragrunt-quiet).",
        )

    def test_no_run_all_subcommand_in_references(self):
        """'run-all' subcommand is deprecated; use 'run --all'."""
        # Look for `run-all` as a shell command token, not inside URLs/paths.
        for line in self._ref_content.splitlines():
            stripped = line.strip()
            if stripped.startswith("#") or "http" in stripped:
                continue
            self.assertNotIn(
                "run-all",
                stripped,
                f"References must not use deprecated 'run-all': {line}",
            )

    def test_no_active_skip_in_templates(self):
        """'skip' attribute is deprecated; use exclude block instead."""
        for line in self._template_content.splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            self.assertFalse(
                re.match(r"^skip\s*=", stripped),
                f"Template contains deprecated 'skip' attribute: {line}",
            )


if __name__ == "__main__":
    unittest.main()
