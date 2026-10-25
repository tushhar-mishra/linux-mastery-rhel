#!/usr/bin/env python3
"""Lint the knowledge base.

Checks every tracked Markdown file for:
  - relative links to files that don't exist
  - links to #anchors that don't exist in the target file (GitHub slug rules)
  - unbalanced code fences (a file that ends inside a code block)
  - stale "planned" markers for topics that now have notes

Usage:  python3 tools/check_notes.py [--quiet]
Exit status is non-zero when any problem is found.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINK_RE = re.compile(r"(?<!!)\[([^\]]*)\]\(([^)\s]+)\)")
FENCE_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def md_files():
    out = subprocess.run(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "*.md"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout.split()
    return sorted(ROOT / p for p in out if (ROOT / p).exists())


def strip_code(lines):
    """Yield (lineno, line, in_code) with fenced-code state tracked."""
    fence = None
    for n, line in enumerate(lines, 1):
        m = FENCE_RE.match(line)
        if m:
            tok = m.group(1)
            if fence is None:
                fence = tok
                yield n, line, True
                continue
            if tok[0] == fence[0] and len(tok) >= len(fence) and line.strip() == tok:
                fence = None
                yield n, line, True
                continue
        yield n, line, fence is not None
    yield -1, "", fence is not None  # sentinel: final state


def slug(text):
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)   # links -> text
    text = text.replace("`", "")
    text = re.sub(r"[*_]{1,3}([^*_]+)[*_]{1,3}", r"\1", text)  # emphasis
    text = text.strip().lower()
    text = re.sub(r"[^\w\- ]", "", text)
    return text.replace(" ", "-")


def anchors(path, cache={}):
    if path in cache:
        return cache[path]
    seen, result = {}, set()
    for n, line, code in strip_code(path.read_text(encoding="utf-8").splitlines()):
        if n == -1 or code:
            continue
        m = HEADING_RE.match(line)
        if not m:
            continue
        s = slug(m.group(2))
        if s in seen:
            seen[s] += 1
            s = f"{s}-{seen[s]}"
        else:
            seen[s] = 0
        result.add(s)
    cache[path] = result
    return result


def main():
    quiet = "--quiet" in sys.argv
    problems = []
    files = md_files()
    for f in files:
        rel = f.relative_to(ROOT)
        lines = f.read_text(encoding="utf-8").splitlines()
        final_in_code = False
        for n, line, code in strip_code(lines):
            if n == -1:
                final_in_code = code
                continue
            if code:
                continue
            for _text, target in LINK_RE.findall(line):
                if re.match(r"^[a-z]+://|^mailto:", target):
                    continue
                path_part, _, frag = target.partition("#")
                dest = (f.parent / path_part).resolve() if path_part else f
                if not dest.exists():
                    problems.append(f"{rel}:{n}: missing file -> {target}")
                    continue
                if frag and dest.suffix == ".md" and frag not in anchors(dest):
                    problems.append(f"{rel}:{n}: missing anchor -> {target}")
            if re.search(r"\(planned\)|: planned\b|, planned\b|\bplanned$", line):
                problems.append(f"{rel}:{n}: stale 'planned' marker")
        if final_in_code:
            problems.append(f"{rel}: file ends inside an unclosed code fence")
    for p in problems:
        print(p)
    if not quiet:
        print(f"\n{len(files)} files checked, {len(problems)} problem(s).")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
