#!/usr/bin/env python3
"""Copies the numbered lines of design/TRIP_TEXT_DRAFT.md into src/game/data.odin.

Sections read: "## Plain lines" -> TRIP_LINES, "## Named fragments" -> NAMED_FRAGMENTS,
"## Scarred fragments" -> SCARRED_FRAGMENTS. Only lines of the form "1. text" count, so notes
and headings in the draft are ignored. Then run ./test.sh: trip_text_fits_and_keeps_the_voice
checks every line fits two rows, is plain ASCII and never says "your" or "you're".
The beating messages (src/web/web.odin) are not touched; edit those by hand.
Usage: tools/apply_trip_text.py [draft.md]
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
draft_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "design", "TRIP_TEXT_DRAFT.md")
data_path = os.path.join(ROOT, "src", "game", "data.odin")
draft = open(draft_path, encoding="utf-8").read()


def section(heading):
    if heading not in draft:
        sys.exit(f"no section {heading!r} in {draft_path}")
    part = draft.split(heading, 1)[1].split("\n## ", 1)[0]
    lines = [l.strip() for l in re.findall(r"^\d+\.\s+(.+)$", part, re.M)]
    if not lines:
        sys.exit(f"section {heading!r} has no numbered lines")
    return lines


src = open(data_path, encoding="utf-8").read()
for heading, name in (("## Plain lines", "TRIP_LINES"), ("## Named fragments", "NAMED_FRAGMENTS"),
                      ("## Scarred fragments", "SCARRED_FRAGMENTS")):
    lines = section(heading)
    body = "\n".join('\t"%s",' % l.replace("\\", "\\\\").replace('"', '\\"') for l in lines)
    src, n = re.subn(r"(%s := \[\?\]string \{\n).*?(\n\})" % name, lambda m: m.group(1) + body + m.group(2), src,
                     flags=re.S)
    if n != 1:
        sys.exit(f"could not find {name} in {data_path}")
    print(f"{name}: {len(lines)} lines")
open(data_path, "w", encoding="utf-8").write(src)
print("written src/game/data.odin; now run ./test.sh")
