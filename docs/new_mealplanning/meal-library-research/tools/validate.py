#!/usr/bin/env python3
"""Parse the strict meal-block format and report counts + tag errors.

Usage: validate.py <file.md> [more files...]   (add --json to dump parsed blocks)
"""
import json
import re
import sys
from collections import Counter

DIETS = {"omnivore", "vegetarian", "pescatarian", "vegan", "mediterranean", "paleo", "keto", "low_carb"}
ALLERGENS = {"dairy", "eggs", "fish", "gluten", "peanuts", "sesame", "shellfish", "soy", "tree_nuts"}
MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}
CONTEXTS = {"everyday", "pre-session", "recovery", "rest-day", "race-week", "carb-load", "travel"}
FIELDS = ["meal_type", "context", "ingredients", "diets_ok", "allergens", "swaps", "approx_macros", "prep", "source", "why"]

BLOCK_RE = re.compile(r"^###\s+(.+?)\s*$", re.M)


def parse(text):
    blocks = []
    heads = list(BLOCK_RE.finditer(text))
    for i, m in enumerate(heads):
        end = heads[i + 1].start() if i + 1 < len(heads) else len(text)
        body = text[m.end():end]
        b = {"name": m.group(1).strip()}
        for line in body.splitlines():
            mm = re.match(r"^\s*-\s*([a-z_]+)\s*:\s*(.*)$", line)
            if mm and mm.group(1) in FIELDS:
                b[mm.group(1)] = mm.group(2).strip()
        blocks.append(b)
    return blocks


def split_tags(s):
    s = re.sub(r"\([^)]*\)", "", (s or "")).strip().lower()
    s = re.sub(r"\s*[—–-]\s*.*$", "", s) if s.startswith("none") else s
    if s in ("", "none", "-", "n/a"):
        return set()
    return {t.strip().strip("`") for t in re.split(r"[,;/]+", s) if t.strip()}


def check(b):
    errs = []
    for f in FIELDS:
        if f not in b or not b[f]:
            errs.append(f"missing {f}")
    mt = (b.get("meal_type") or "").strip().lower()
    if mt not in MEAL_TYPES:
        errs.append(f"bad meal_type '{mt}'")
    bad = split_tags(b.get("diets_ok")) - DIETS
    if bad:
        errs.append(f"bad diets {sorted(bad)}")
    bad = split_tags(b.get("allergens")) - ALLERGENS
    if bad:
        errs.append(f"bad allergens {sorted(bad)}")
    bad = split_tags(b.get("context")) - CONTEXTS
    if bad:
        errs.append(f"bad context {sorted(bad)}")
    return errs


def main():
    dump = "--json" in sys.argv
    files = [a for a in sys.argv[1:] if not a.startswith("--")]
    all_blocks = []
    for path in files:
        text = open(path, encoding="utf-8").read()
        blocks = parse(text)
        n_err = 0
        for b in blocks:
            b["_file"] = path
            errs = check(b)
            if errs:
                n_err += 1
                if not dump:
                    print(f"  ! {path}: '{b['name'][:50]}': {'; '.join(errs)}")
        types = Counter((b.get("meal_type") or "?").lower() for b in blocks)
        vegan = sum(1 for b in blocks if "vegan" in split_tags(b.get("diets_ok")))
        gf = sum(1 for b in blocks if "gluten" not in split_tags(b.get("allergens")))
        if not dump:
            print(f"{path}: {len(blocks)} blocks, {n_err} with errors, types={dict(types)}, vegan={vegan}, gf={gf}")
        all_blocks.extend(blocks)
    if dump:
        json.dump(all_blocks, sys.stdout, indent=1)
    else:
        print(f"TOTAL {len(all_blocks)} blocks across {len(files)} files")


if __name__ == "__main__":
    main()
