"""Lexical masking helpers shared by SQL formatter safety checks."""

from __future__ import annotations

import re

DOLLAR_QUOTE = re.compile(r"\$(?:[A-Za-z_][A-Za-z0-9_]*)?\$")
LexicalState = dict[str, str | int]


def new_lexical_state() -> LexicalState:
    return {"kind": "normal", "depth": 0, "tag": ""}


def mask_non_code(line: str, state: LexicalState) -> str:
    """Replace comments and quoted content with spaces while preserving columns."""
    output: list[str] = []
    index = 0

    while index < len(line):
        kind = state["kind"]

        if kind == "block":
            if line.startswith("/*", index):
                state["depth"] = int(state["depth"]) + 1
                output.extend("  ")
                index += 2
            elif line.startswith("*/", index):
                state["depth"] = int(state["depth"]) - 1
                output.extend("  ")
                index += 2
                if state["depth"] == 0:
                    state["kind"] = "normal"
            else:
                output.append(" ")
                index += 1
            continue

        if kind == "single":
            if line.startswith("''", index):
                output.extend("  ")
                index += 2
            elif line[index] == "\\" and index + 1 < len(line):
                output.extend("  ")
                index += 2
            else:
                if line[index] == "'":
                    state["kind"] = "normal"
                output.append(" ")
                index += 1
            continue

        if kind == "double":
            if line.startswith('""', index):
                output.extend("  ")
                index += 2
            else:
                if line[index] == '"':
                    state["kind"] = "normal"
                output.append(" ")
                index += 1
            continue

        if kind == "dollar":
            tag = str(state["tag"])
            if line.startswith(tag, index):
                output.extend(" " * len(tag))
                index += len(tag)
                state["kind"] = "normal"
                state["tag"] = ""
            else:
                output.append(" ")
                index += 1
            continue

        if line.startswith("--", index):
            output.extend(" " * (len(line) - index))
            break
        if line.startswith("/*", index):
            state["kind"] = "block"
            state["depth"] = 1
            output.extend("  ")
            index += 2
            continue
        if line[index] == "'":
            state["kind"] = "single"
            output.append(" ")
            index += 1
            continue
        if line[index] == '"':
            state["kind"] = "double"
            output.append(" ")
            index += 1
            continue
        dollar = DOLLAR_QUOTE.match(line, index)
        previous = line[index - 1] if index > 0 else ""
        valid_boundary = not previous or not (previous.isalnum() or previous in "_$")
        if dollar and valid_boundary:
            tag = dollar.group(0)
            state["kind"] = "dollar"
            state["tag"] = tag
            output.extend(" " * len(tag))
            index += len(tag)
            continue

        output.append(line[index])
        index += 1

    return "".join(output)
