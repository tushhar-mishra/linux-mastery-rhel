#!/usr/bin/env python3
"""Generate ROADMAP.md (a tick-box study checklist) from CURRICULUM.md.

The curriculum is the single source of truth for learning order; this script
flattens its phase tables into a checklist and verifies that every note in the
reference library is scheduled somewhere in the curriculum.

Usage: python3 tools/build_roadmap.py      (rewrites ROADMAP.md)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CURR = ROOT / "CURRICULUM.md"
OUT = ROOT / "ROADMAP.md"
LINK = re.compile(r"\[([^\]]+)\]\(([^)#\s]+\.md)(#[^)]*)?\)")
SKIP_DIRS = {"tools", "appendix"}
TOP_LEVEL = {"README.md", "CURRICULUM.md", "ROADMAP.md", "COVERAGE.md", "GAPS.md", "CHANGELOG.md"}


def main():
    lines = CURR.read_text(encoding="utf-8").splitlines()
    out, seen, phase = [], [], None
    for line in lines:
        m = re.match(r"^## (Phase \d+: .+)$", line)
        if m:
            phase = m.group(1)
            out += ["", f"## {phase}", ""]
            continue
        if line.startswith("## ") and not line.startswith("## Phase"):
            phase = None
        if not phase or not line.startswith("| ") or line.startswith("| #") or line.startswith("|---"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        num = cells[0]
        for text, target, _ in LINK.findall(line):
            if target in seen and target not in ("rhcsa-exam-labs/exam-objectives-map.md",):
                continue
            seen.append(target)
            out.append(f"- [ ] **{num}** [{text}]({target})")
        if "Exit criteria" in line:
            pass
    # completeness check
    notes = sorted(
        str(p.relative_to(ROOT)) for p in ROOT.rglob("*.md")
        if ".git" not in p.parts and p.parts[len(ROOT.parts)] not in SKIP_DIRS
        and str(p.relative_to(ROOT)) not in TOP_LEVEL
    )
    missing = [n for n in notes if n not in seen]
    header = [
        "# Study Roadmap (Checklist)",
        "",
        "> Generated from [CURRICULUM.md](CURRICULUM.md) by `tools/build_roadmap.py`; edit the curriculum, then regenerate.",
        "> Tick items as you finish them **including their labs**. Don't start a phase until the previous phase's exit criteria",
        "> (in the curriculum) are met without notes. Items marked *optional* in the curriculum can wait for Phase 8.",
        "",
        "Milestones: **after Phase 6 → sit the RHCSA (EX200)** · after Phase 8 → production-ready · Phase 9 → interview-ready.",
    ]
    footer = ["", "## Every note is scheduled", "",
              f"{len(notes)} notes in the library; {len(notes) - len(missing)} appear in this roadmap."]
    if missing:
        footer += ["", "Not yet scheduled (fix CURRICULUM.md):", ""] + [f"- {m}" for m in missing]
    OUT.write_text("\n".join(header + out + footer) + "\n", encoding="utf-8")
    print(f"ROADMAP.md written: {len(seen)} items; unscheduled notes: {len(missing)}")
    for m in missing:
        print("  missing:", m)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
