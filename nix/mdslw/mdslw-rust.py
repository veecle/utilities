"""mdslw-rust — apply mdslw to the doc comments (`///` and `//!`) of Rust files.

Usage:
  mdslw-rust [--mode=format|check] PATH...
  mdslw-rust [--stdin-filepath=PATH] < input.rs > output.rs

Directories are searched recursively for `*.rs` files, skipping hidden directories and `target`.
In file mode the paths of changed files are printed; `--mode=check` doesn't write them and exits non-zero instead.

Doc comments are detected line by line without lexing Rust,
so lines starting with `///` or `//!` inside string literals or block comments are formatted too.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterator, Optional, Union

DOC_COMMENT = re.compile(r"^(?P<indent>[ \t]*)(?P<prefix>///|//!)(?!/)(?P<rest>.*)$")

# Joins all blocks of a file into a single mdslw invocation.
# mdslw passes HTML blocks through verbatim, and the blank lines around it stop it from merging with neighbouring paragraphs.
SEPARATOR = "<!-- mdslw-rust: block separator -->"


@dataclass
class Block:
    indent: str
    prefix: str
    lines: list[str]

    def render(self) -> list[str]:
        lead = self.indent + self.prefix
        return [f"{lead} {line}" if line else lead for line in self.lines]


def parse(text: str) -> list[Union[str, Block]]:
    """Split `text` into verbatim lines and doc comment blocks with their prefix stripped."""
    items: list[Union[str, Block]] = []
    current: Optional[Block] = None
    for line in text.split("\n"):
        match = DOC_COMMENT.match(line)
        if match is None:
            current = None
            items.append(line)
            continue
        indent, prefix, rest = match["indent"], match["prefix"], match["rest"]
        if current is None or (current.indent, current.prefix) != (indent, prefix):
            current = Block(indent, prefix, [])
            items.append(current)
        current.lines.append(rest)
    return [normalized for item in items for normalized in normalize(item)]


def normalize(item: Union[str, Block]) -> list[Union[str, Block]]:
    """Strip the space after the prefix, or keep the block verbatim if a line lacks it."""
    if isinstance(item, str):
        return [item]
    if any(line and not line.startswith(" ") for line in item.lines):
        return [item.indent + item.prefix + line for line in item.lines]
    return [Block(item.indent, item.prefix, [line.removeprefix(" ") for line in item.lines])]


def run_mdslw(markdown: str, filepath: str) -> str:
    if not os.path.isabs(filepath):
        # For directory-less paths mdslw fails to locate `.mdslw.toml` without a `./` prefix.
        filepath = os.path.join(".", filepath)
    result = subprocess.run(
        ["mdslw", f"--stdin-filepath={filepath}"],
        input=markdown,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"mdslw failed on {filepath}:\n{result.stderr}")
    return result.stdout


def format_text(text: str, filepath: str) -> str:
    items = parse(text)
    blocks = [item for item in items if isinstance(item, Block)]
    if not blocks:
        return text

    markdown = f"\n\n{SEPARATOR}\n\n".join("\n".join(block.lines) for block in blocks) + "\n"
    chunks = run_mdslw(markdown, filepath).split(f"\n{SEPARATOR}\n")
    if len(chunks) != len(blocks):
        raise RuntimeError(f"{filepath}: expected {len(blocks)} blocks back from mdslw, got {len(chunks)}")
    for block, chunk in zip(blocks, chunks):
        block.lines = chunk.strip("\n").split("\n")

    lines: list[str] = []
    for item in items:
        if isinstance(item, Block):
            lines.extend(item.render())
        else:
            lines.append(item)
    return "\n".join(lines)


def find_files(paths: list[str]) -> Iterator[str]:
    for path in paths:
        if not os.path.isdir(path):
            yield path
            continue
        for dirpath, dirnames, filenames in os.walk(path):
            dirnames[:] = sorted(d for d in dirnames if not d.startswith(".") and d != "target")
            yield from (os.path.join(dirpath, f) for f in sorted(filenames) if f.endswith(".rs"))


def main() -> int:
    parser = argparse.ArgumentParser(description="Apply mdslw to the doc comments of Rust files.")
    parser.add_argument("--mode", choices=["format", "check"], default="format")
    parser.add_argument("--stdin-filepath", default="stdin.rs", help="path used to locate `.mdslw.toml` in stdin mode")
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()

    if not args.paths:
        original = sys.stdin.read()
        formatted = format_text(original, args.stdin_filepath)
        if args.mode == "format":
            sys.stdout.write(formatted)
            return 0
        return 1 if formatted != original else 0

    changed = False
    for path in find_files(args.paths):
        with open(path, encoding="utf-8") as f:
            original = f.read()
        formatted = format_text(original, path)
        if formatted == original:
            continue
        changed = True
        print(path)
        if args.mode == "format":
            with open(path, "w", encoding="utf-8") as f:
                f.write(formatted)
    return 1 if changed and args.mode == "check" else 0


if __name__ == "__main__":
    sys.exit(main())
