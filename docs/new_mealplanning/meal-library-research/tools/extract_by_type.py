#!/usr/bin/env python3
"""Split all research files into per-meal-type candidate files (cands-<type>.md)."""
import glob
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
from validate import parse, FIELDS  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
files = sorted(glob.glob(os.path.join(HERE, "[0-9][0-9]-*.md")))
by_type = {"breakfast": [], "lunch": [], "dinner": [], "snack": []}
for f in files:
    slug = os.path.basename(f)[:-3]
    for b in parse(open(f, encoding="utf-8").read()):
        mt = (b.get("meal_type") or "").strip().lower()
        mt = re.sub(r"[^a-z]", "", mt.split("|")[0].split("(")[0].strip())
        if mt not in by_type:
            continue
        by_type[mt].append((slug, b))

for mt, items in by_type.items():
    out = os.path.join(HERE, f"cands-{mt}.md")
    with open(out, "w", encoding="utf-8") as w:
        w.write(f"# Candidate {mt}s — {len(items)} blocks from {len(files)} research files\n\n")
        for i, (slug, b) in enumerate(items, 1):
            w.write(f"### [{slug} #{i}] {b['name']}\n")
            for fld in FIELDS:
                if fld in b:
                    w.write(f"- {fld}: {b[fld]}\n")
            w.write("\n")
    print(mt, len(items), out, os.path.getsize(out) // 1024, "KB")
