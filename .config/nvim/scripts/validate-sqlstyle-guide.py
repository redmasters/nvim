#!/usr/bin/env python3
"""Validate mechanically enforceable SQL Style Guide rules after formatting."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from sql_style_lexer import mask_non_code, new_lexical_state  # pyright: ignore[reportMissingImports]

GUIDE_URL = "https://www.sqlstyle.guide/"
CREATE_TABLE = re.compile(
    r"^\s*CREATE\s+(?:(?:GLOBAL|LOCAL)\s+)?(?:(?:TEMP|TEMPORARY|UNLOGGED)\s+)?TABLE\b.*\(\s*$",
    re.IGNORECASE,
)
CLOSING = re.compile(r"^\s*\);\s*$")
CONSTRAINT = re.compile(r"^CONSTRAINT\b", re.IGNORECASE)
INLINE_NAMED_UNIQUE = re.compile(r"^CONSTRAINT\b.*\bUNIQUE\b", re.IGNORECASE)
UNIQUE = re.compile(r"^UNIQUE\b", re.IGNORECASE)
STANDALONE_PRIMARY_KEY = re.compile(r"^PRIMARY\s+KEY\b", re.IGNORECASE)
STRUCTURAL_KEYWORDS = re.compile(
    r"\b(?:create|table|primary|key|not|null|constraint|unique|foreign|references|on|delete|cascade|restrict|set|default)\b",
    re.IGNORECASE,
)


def indentation(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def validate(source: str) -> list[str]:
    errors: list[str] = []
    lines = source.splitlines()
    create_indent: int | None = None
    body_indent: int | None = None
    in_constraint = False
    lexical_state = new_lexical_state()

    for number, line in enumerate(lines, 1):
        if "\t" in line:
            errors.append(f"line {number}: tabs are not allowed")
        if line.rstrip(" ") != line:
            errors.append(f"line {number}: trailing spaces are not allowed")

        masked_line = mask_non_code(line, lexical_state)
        stripped = masked_line.lstrip(" ")
        for keyword in STRUCTURAL_KEYWORDS.finditer(stripped):
            token = keyword.group(0)
            if token != token.upper():
                errors.append(f"line {number}: structural keyword must be uppercase: {token}")

        if CREATE_TABLE.match(masked_line):
            create_indent = indentation(line)
            body_indent = create_indent + 6
            in_constraint = False
            continue

        if create_indent is None or body_indent is None:
            continue

        if CLOSING.match(masked_line):
            expected = create_indent + 2
            if indentation(line) != expected:
                errors.append(f"line {number}: CREATE TABLE closing must use {expected} spaces")
            create_indent = None
            body_indent = None
            in_constraint = False
            continue

        if not stripped.strip():
            continue

        current = indentation(line)
        if CONSTRAINT.match(stripped):
            if current != body_indent:
                errors.append(f"line {number}: CONSTRAINT must use {body_indent} spaces")
            if INLINE_NAMED_UNIQUE.match(stripped):
                errors.append(f"line {number}: named UNIQUE must start on the line after CONSTRAINT")
            in_constraint = True
            continue

        if in_constraint and current <= body_indent:
            in_constraint = False

        if UNIQUE.match(stripped) and not in_constraint:
            errors.append(f"line {number}: table-level UNIQUE must follow a named CONSTRAINT")

        if STANDALONE_PRIMARY_KEY.match(stripped):
            errors.append(f"line {number}: PRIMARY KEY must remain on its column line")

        expected = body_indent + 4 if in_constraint else body_indent
        if current != expected:
            kind = "constraint continuation" if in_constraint else "column definition"
            errors.append(f"line {number}: {kind} must use {expected} spaces")

    if create_indent is not None:
        errors.append("unterminated CREATE TABLE block")
    if lexical_state["kind"] in {"block", "single", "double", "dollar"}:
        errors.append(f"unterminated SQL {lexical_state['kind']} literal or comment")
    return errors


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <file.sql>", file=sys.stderr)
        return 64

    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"SQL file does not exist: {path}", file=sys.stderr)
        return 66

    errors = validate(path.read_text(encoding="utf-8"))
    if errors:
        print(f"SQL style validation failed (guide: {GUIDE_URL}):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 65
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
