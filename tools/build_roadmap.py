#!/usr/bin/env python3
"""Generate docs/roadmap.md (a tick-box study checklist) from docs/curriculum.md.

The curriculum is the single source of truth for learning order. This script
flattens its phase tables into a checklist and verifies that every note under
notes/ is scheduled somewhere in the curriculum.

Usage:
  python3 tools/build_roadmap.py           rewrite docs/roadmap.md
  python3 tools/build_roadmap.py --check   exit 1 if the roadmap is stale or a note is unscheduled (CI)
"""
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
CURR = DOCS / "curriculum.md"
OUT = DOCS / "roadmap.md"
NOTES = ROOT / "notes"
LINK = re.compile(r"\[([^\]]+)\]\(([^)#\s]+\.md)(#[^)]*)?\)")


def build():
    out, seen = [], []
    phase = None
    for line in CURR.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^## (Phase \d+: .+)$", line)
        if m:
            phase = m.group(1)
            out += ["", f"## {phase}", ""]
            continue
        if line.startswith("## "):
            phase = None
        if not phase or not line.startswith("| ") or line.startswith(("| #", "|---")):
            continue
        num = line.strip("|").split("|")[0].strip()
        for text, target, _ in LINK.findall(line):
            resolved = os.path.normpath(os.path.join("docs", target))
            if resolved in seen:
                continue
            seen.append(resolved)
            out.append(f"- [ ] **{num}** [{text}]({target})")
    notes = sorted(str(p.relative_to(ROOT)) for p in NOTES.rglob("*.md"))
    missing = [n for n in notes if n not in seen]
    header = [
        "# Study Roadmap (Checklist)",
        "",
        "> Generated from the [curriculum](curriculum.md) by `tools/build_roadmap.py`; edit the curriculum, then regenerate.",
        "> Tick items as you finish them **including their labs**. Start a phase only when the previous phase's exit criteria",
        "> (in the curriculum) are met without notes. Items marked *optional* in the curriculum can wait for Phase 8.",
        "",
        "Milestones: **after Phase 6 → sit the RHCSA (EX200)** · after Phase 8 → production-ready · Phase 9 → interview-ready.",
    ]
    footer = ["", "---", "", f"{len(notes)} notes in the library; {len(notes) - len(missing)} scheduled in this roadmap."]
    if missing:
        footer += ["", "Not yet scheduled (fix the curriculum):", ""] + [f"- {m}" for m in missing]
    return "\n".join(header + out + footer) + "\n", missing


def main():
    text, missing = build()
    if "--check" in sys.argv:
        stale = not OUT.exists() or OUT.read_text(encoding="utf-8") != text
        if stale:
            print("docs/roadmap.md is out of date: run python3 tools/build_roadmap.py")
        for m in missing:
            print("unscheduled note:", m)
        return 1 if stale or missing else 0
    OUT.write_text(text, encoding="utf-8")
    print(f"docs/roadmap.md written; unscheduled notes: {len(missing)}")
    for m in missing:
        print("  missing:", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
