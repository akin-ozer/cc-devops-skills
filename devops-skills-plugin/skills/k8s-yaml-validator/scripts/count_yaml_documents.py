#!/usr/bin/env python3
"""
Count non-empty YAML documents in a file using document separators.

This script is intentionally parser-independent so it still works when the YAML
contains syntax errors.
"""

import json
import re
import sys
from pathlib import Path

SEPARATOR_RE = re.compile(r"^\s*---\s*$")


def count_yaml_documents(content: str) -> tuple[int, int]:
    """Return (documents, separators)."""
    documents = 0
    separators = 0
    seen_yaml_content = False

    for line in content.splitlines():
        if SEPARATOR_RE.match(line):
            separators += 1
            if seen_yaml_content:
                documents += 1
            seen_yaml_content = False
            continue

        stripped = line.strip()
        if not stripped:
            continue

        # Ignore comment-only lines so header comments before the first '---'
        # are not counted as a document.
        if line.lstrip().startswith("#"):
            continue

        seen_yaml_content = True

    if seen_yaml_content:
        documents += 1

    return documents, separators


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: count_yaml_documents.py <yaml-file>", file=sys.stderr)
        return 1

    file_path = Path(sys.argv[1])
    if not file_path.exists():
        print(f"File not found: {file_path}", file=sys.stderr)
        return 1

    if not file_path.is_file():
        print(f"Not a regular file: {file_path}", file=sys.stderr)
        return 1

    try:
        content = file_path.read_text(encoding="utf-8")
    except OSError as exc:
        print(f"Failed to read file: {exc}", file=sys.stderr)
        return 1

    documents, separators = count_yaml_documents(content)
    output = {
        "file": str(file_path.resolve()),
        "documents": documents,
        "separators": separators,
    }
    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
