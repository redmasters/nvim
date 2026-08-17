#!/usr/bin/env python3
"""Normalize JetBrains-formatted CREATE TABLE indentation without changing SQL tokens."""

from __future__ import annotations

import os
import re
import stat
import sys
from pathlib import Path

from sql_style_lexer import mask_non_code, new_lexical_state  # pyright: ignore[reportMissingImports]

CREATE_TABLE = re.compile(
    r"^\s*CREATE\s+(?:(?:GLOBAL|LOCAL)\s+)?(?:(?:TEMP|TEMPORARY|UNLOGGED)\s+)?TABLE\b.*\(\s*$",
    re.IGNORECASE,
)
CLOSING = re.compile(r"^\s*\);\s*$")
PRIMARY_KEY = re.compile(r"^PRIMARY\s+KEY\b", re.IGNORECASE)
CONSTRAINT = re.compile(r"^CONSTRAINT\b", re.IGNORECASE)
INLINE_NAMED_UNIQUE = re.compile(
    r'^(CONSTRAINT\s+(?:"(?:[^"]|"")*"|\S+))\s+(UNIQUE\b.*)$',
    re.IGNORECASE,
)


def indentation(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def normalize(source: str) -> str:
    had_final_newline = source.endswith("\n")
    lines = source.splitlines()
    output: list[str] = []
    create_indent: int | None = None
    body_indent: int | None = None
    in_constraint = False
    lexical_state = new_lexical_state()

    for line in lines:
        masked_line = mask_non_code(line, lexical_state)
        code = masked_line.lstrip(" ")
        stripped = line.lstrip(" ")

        if CREATE_TABLE.match(masked_line):
            create_indent = indentation(line)
            body_indent = create_indent + 6
            in_constraint = False
            output.append(line)
            continue

        if create_indent is None or body_indent is None:
            output.append(line)
            continue

        if CLOSING.match(masked_line):
            output.append(" " * (create_indent + 2) + stripped)
            create_indent = None
            body_indent = None
            in_constraint = False
            continue

        if not code.strip():
            output.append(line)
            continue

        current_indent = indentation(line)

        if CONSTRAINT.match(code):
            unique = INLINE_NAMED_UNIQUE.match(stripped)
            if unique:
                output.append(" " * body_indent + unique.group(1))
                output.append(" " * (body_indent + 4) + unique.group(2))
            else:
                output.append(" " * body_indent + stripped)
            in_constraint = True
            continue

        if in_constraint and current_indent > body_indent:
            output.append(" " * (body_indent + 4) + stripped)
            continue

        in_constraint = False

        previous = output[-1].lstrip(" ") if output else ""
        if (
            PRIMARY_KEY.match(code)
            and output
            and indentation(output[-1]) == body_indent
            and not previous.startswith(("--", "/*", "CONSTRAINT"))
            and "--" not in previous
            and not previous.rstrip().endswith(",")
        ):
            output[-1] = output[-1].rstrip() + " " + stripped
            continue

        output.append(line)

    normalized = "\n".join(output)
    if had_final_newline:
        normalized += "\n"
    return normalized


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Usage: {Path(sys.argv[0]).name} <file.sql>", file=sys.stderr)
        return 64

    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"SQL file does not exist: {path}", file=sys.stderr)
        return 66

    source = path.read_text(encoding="utf-8")
    normalized = normalize(source)
    if normalized != source:
        original_mode = stat.S_IMODE(path.stat().st_mode)
        temporary = path.with_name(f".{path.name}.postprocess.{os.getpid()}")
        try:
            temporary.write_text(normalized, encoding="utf-8")
            temporary.chmod(original_mode)
            os.replace(temporary, path)
        finally:
            temporary.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
