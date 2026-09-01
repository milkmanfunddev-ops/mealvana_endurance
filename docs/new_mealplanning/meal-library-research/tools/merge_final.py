#!/usr/bin/env python3
"""Merge final-<type>.md into docs/new_mealplanning/meal-library-400.md + .json with a computed coverage matrix."""
import json
import os
import re
import sys
from collections import Counter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from validate import DIETS, ALLERGENS, split_tags  # noqa: E402

OUT_DIR = "/Users/leemartin/development/mealvana_endurance/docs/new_mealplanning"
FIELDS = ["meal_type", "context", "cuisine", "ingredients", "diets_ok", "allergens", "swaps",
          "approx_macros", "prep", "batch", "source", "why"]
TYPES = ["breakfast", "lunch", "dinner", "snack"]
HEAD_RE = re.compile(r"^###\s+([BLDS]-\d{3})\s*[·\-–]\s*(.+?)\s*$", re.M)


def parse_final(text):
    out = []
    heads = list(HEAD_RE.finditer(text))
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        body = text[m.end():end]
        # stop at coverage check section
        body = body.split("\n## ")[0]
        b = {"id": m.group(1), "name": m.group(2).strip()}
        for line in body.splitlines():
            mm = re.match(r"^\s*-\s*([a-z_]+)\s*:\s*(.*)$", line)
            if mm and mm.group(1) in FIELDS:
                b[mm.group(1)] = mm.group(2).strip()
        out.append(b)
    return out


def norm(b):
    b["diets_ok_list"] = sorted(split_tags(b.get("diets_ok")) & DIETS)
    b["allergens_list"] = sorted(split_tags(b.get("allergens")) & ALLERGENS)
    b["excluded_diets"] = sorted(DIETS - set(b["diets_ok_list"]))
    b["context_list"] = sorted(split_tags(b.get("context")))
    b["batch"] = (b.get("batch") or "").strip().lower().startswith("y")
    b["named_source"] = not re.search(r"^\s*commonly", b.get("source") or "", re.I)
    return b


def coverage(blocks):
    n = len(blocks)
    c = {}
    for d in sorted(DIETS):
        c[f"diet:{d}"] = sum(1 for b in blocks if d in b["diets_ok_list"])
    for a in sorted(ALLERGENS):
        c[f"free-of:{a}"] = sum(1 for b in blocks if a not in b["allergens_list"])
    c["free of dairy+eggs+peanuts+tree_nuts"] = sum(
        1 for b in blocks if not ({"dairy", "eggs", "peanuts", "tree_nuts"} & set(b["allergens_list"])))
    c["free of ≥6 of 9 allergens"] = sum(1 for b in blocks if len(b["allergens_list"]) <= 3)
    c["allergen-free as written"] = sum(1 for b in blocks if not b["allergens_list"])
    for ctx in ["everyday", "pre-session", "recovery", "rest-day", "race-week", "carb-load", "travel"]:
        c[f"context:{ctx}"] = sum(1 for b in blocks if ctx in b["context_list"])
    c["batch-friendly"] = sum(1 for b in blocks if b["batch"])
    c["named attribution"] = sum(1 for b in blocks if b["named_source"])
    c["_n"] = n
    return c


def md_table(per_type, total):
    keys = [k for k in total if not k.startswith("_")]
    lines = ["| Coverage | " + " | ".join(t.title() for t in TYPES) + " | All 400 |",
             "|---|" + "---|" * (len(TYPES) + 1)]
    for k in keys:
        lines.append(f"| {k} | " + " | ".join(str(per_type[t][k]) for t in TYPES) + f" | **{total[k]}** |")
    return "\n".join(lines)


def block_md(b):
    return "\n".join([
        f"### {b['id']} · {b['name']}",
        f"- **Context:** {', '.join(b['context_list'])} · **Cuisine:** {b.get('cuisine', 'general')} · **Prep:** {b.get('prep', '')} · **Batch:** {'yes' if b['batch'] else 'no'}",
        f"- **Ingredients:** {b.get('ingredients', '')}",
        f"- **Diets OK:** {', '.join(b['diets_ok_list']) or '—'}",
        f"- **Allergens:** {', '.join(b['allergens_list']) or 'none'}",
        f"- **Swaps:** {b.get('swaps', '')}",
        f"- **Approx:** {b.get('approx_macros', '')}",
        f"- **Source:** {b.get('source', '')}",
        f"- **Why:** {b.get('why', '')}",
        "",
    ])


def main():
    per_type_blocks = {}
    for t in TYPES:
        path = os.path.join(HERE, f"final-{t}.md")
        blocks = [norm(b) for b in parse_final(open(path, encoding="utf-8").read())]
        per_type_blocks[t] = blocks
        print(t, len(blocks))
    all_blocks = [b for t in TYPES for b in per_type_blocks[t]]
    ids = [b["id"] for b in all_blocks]
    dupes = [i for i, n in Counter(ids).items() if n > 1]
    if dupes:
        print("DUPLICATE IDS", dupes)
    names = Counter(b["name"].lower() for b in all_blocks)
    dn = [n for n, k in names.items() if k > 1]
    if dn:
        print("DUPLICATE NAMES", dn)

    per_type_cov = {t: coverage(per_type_blocks[t]) for t in TYPES}
    total_cov = coverage(all_blocks)

    cuisines = Counter(b.get("cuisine", "general") for b in all_blocks)

    intro = open(os.path.join(HERE, "FINAL-INTRO.md"), encoding="utf-8").read()
    parts = [intro.strip(), "", "## Coverage matrix (computed from the entries below)", "",
             md_table(per_type_cov, total_cov), "",
             "Cuisine spread: " + ", ".join(f"{k} {v}" for k, v in cuisines.most_common()), ""]
    for t in TYPES:
        parts.append(f"\n---\n\n## {t.title()} ({len(per_type_blocks[t])})\n")
        for b in per_type_blocks[t]:
            parts.append(block_md(b))
    md = "\n".join(parts)
    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, "meal-library-400.md"), "w", encoding="utf-8") as w:
        w.write(md)

    json_rows = []
    for b in all_blocks:
        json_rows.append({
            "id": b["id"], "name": b["name"], "meal_type": b.get("meal_type"),
            "context": b["context_list"], "cuisine": b.get("cuisine", "general"),
            "ingredients": b.get("ingredients", ""), "diets_ok": b["diets_ok_list"],
            "excluded_diets": b["excluded_diets"], "allergens": b["allergens_list"],
            "swaps": b.get("swaps", ""), "approx_macros": b.get("approx_macros", ""),
            "prep": b.get("prep", ""), "batch": b["batch"], "source": b.get("source", ""), "why": b.get("why", ""),
        })
    with open(os.path.join(OUT_DIR, "meal-library-400.json"), "w", encoding="utf-8") as w:
        json.dump(json_rows, w, indent=1, ensure_ascii=False)
    print("TOTAL", len(all_blocks))
    for k, v in total_cov.items():
        print(f"  {k}: {v}")


if __name__ == "__main__":
    main()
