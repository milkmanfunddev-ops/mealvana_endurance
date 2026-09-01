#!/usr/bin/env python3
"""Lint the assembly shard files and merge them into assembly-library-1600.json + .md.

Usage:
  lint_merge.py lint  <shard.json> [...]      # report tag errors / dupes / counts, exit 1 on errors
  lint_merge.py merge <out_basename> <shard.json> [...]   # write <out>.json and <out>.md

Enum sets mirror lib/features/onboarding/domain/{dietary_preference,allergy}.dart — re-check them
if those files change.
"""
import json
import re
import sys
from collections import Counter, defaultdict

DIETS = {"omnivore", "vegetarian", "pescatarian", "vegan", "mediterranean", "paleo", "keto", "low_carb"}
ALLERGENS = {"dairy", "eggs", "fish", "gluten", "peanuts", "sesame", "shellfish", "soy", "tree_nuts"}
MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}
CONTEXTS = {"everyday", "pre-session", "recovery", "rest-day", "race-week", "carb-load", "travel"}
ROLES = {"protein", "starch", "veg", "fruit", "fat", "dairy", "sauce", "drink", "other"}
FREQ = {"staple", "common", "occasional"}
REQUIRED = ["id", "name", "meal_type", "components", "pattern", "context", "cuisine", "diets_ok",
            "allergens", "swaps", "approx_macros", "prep", "batch", "frequency", "source", "evidence"]

# Ingredient keywords that force a diet exclusion / allergen (cheap sanity net, not a full model).
MEAT = re.compile(r"\b(?<!tempeh )(?<!vegan )(?<!plant-based )(?<!coconut )(chicken|beef|steak|pork|bacon|ham|turkey|lamb|sausage|chorizo|jerky|mince|prosciutto|salami|venison|bison|duck)\b", re.I)
FISH = re.compile(r"\b(salmon|tuna|cod|sardine|mackerel|trout|anchov|halibut|tilapia|fish|prawn|shrimp|crab|lobster|mussel|clam|oyster|scallop|squid)\b", re.I)
SHELLFISH = re.compile(r"\b(prawn|shrimp|crab|lobster|mussel|clam|oyster|scallop|squid)\b", re.I)
DAIRY = re.compile(r"\b(milk|yogurt|yoghurt|skyr|cheese|butter|cream|whey|kefir|labneh|paneer|curd|ghee|quark|cottage|halloumi|feta|parmesan|mozzarella|ricotta|casein)\b", re.I)
NON_DAIRY = re.compile(r"\b(vegan yogh?urt|soya? yogh?urt|soya? milk|plant(-based)? milk|plant(-based)? butter|vegan butter|dairy-free[a-z ]*|lactose-free[a-z ]*|tofu ricotta|cashew cream|oat cream|coconut cream|vegan cheese|nutritional yeast|oat yogh?urt|coconut yogh?urt|almond yogh?urt|cream of wheat|cream of rice|coconut butter|apple butter|cocoa butter|cashew butter|sunflower butter|seed butter|oat milk|almond milk|soy milk|coconut milk|coconut yogurt|soy yogurt|oat yogurt|plant milk|rice milk|cashew|peanut butter|almond butter|nut butter|cocoa butter|coconut cream|vegan cheese|dairy-free)\b", re.I)
EGG = re.compile(r"(?<!just )\beggs?\b(?!-free)", re.I)
GLUTEN = re.compile(r"\b(bread|toast|bagel|wrap|tortilla|pasta|noodle|couscous|bulgur|barley|rye|wheat|pita|naan|roti|chapati|crackers|pretzel|granola|cereal|oats|oatmeal|porridge|muesli|soy sauce|seitan|croissant|waffle|pancake|muffin|bun|flatbread|semolina|farro|spelt|udon|ramen|mandazi|weetabix|english muffin|crumpet|panini|baguette|sourdough)\b", re.I)
GF_HINT = re.compile(r"\b(rice cereal|cream of rice|teff|okayu|congee|rice noodles?|rice vermicelli|glass noodles?|quinoa flake|ugali|corn pasta|gluten-free pasta|chickpea pasta|lentil pasta|brown rice pasta|injera|rice cakes?|rice crackers?|quinoa crackers?|corn tortillas?|soba \(100% buckwheat\)|millet porridge|sorghum|arepa|gorilla munch|chex|cheerios|corn flakes|cornflakes|rice krispies|rice chex|gf|gluten-free|gluten free|certified|corn tortilla|rice noodle|rice cake|buckwheat|tamari|rice cracker|100% rye)\b", re.I)
HIGH_CARB = re.compile(r"\b(rice|potato|pasta|bread|toast|oats|oatmeal|porridge|bagel|banana|honey|jam|maple|cereal|granola|noodle|couscous|quinoa|tortilla|dates?|juice|sports drink|ugali|injera|plantain|arepa|mango|pretzel|waffle|pancake)\b", re.I)


def comp_text(r):
    return " ".join(c.get("food", "") for c in r.get("components", []))


def check(r):
    errs = []
    for f in REQUIRED:
        if f not in r or r[f] in ("", None) or (r[f] == [] and f != "allergens"):
            errs.append(f"missing {f}")
    if r.get("meal_type") not in MEAL_TYPES:
        errs.append(f"bad meal_type {r.get('meal_type')!r}")
    for field, allowed in (("diets_ok", DIETS), ("allergens", ALLERGENS), ("context", CONTEXTS)):
        v = r.get(field) or []
        if not isinstance(v, list):
            errs.append(f"{field} not a list")
            continue
        bad = set(v) - allowed
        if bad:
            errs.append(f"bad {field} {sorted(bad)}")
    if r.get("frequency") not in FREQ:
        errs.append(f"bad frequency {r.get('frequency')!r}")
    comps = r.get("components") or []
    if not isinstance(comps, list) or not comps:
        errs.append("components empty")
    else:
        for c in comps:
            if c.get("role") not in ROLES:
                errs.append(f"bad role {c.get('role')!r}")
        n = len(comps)
        if n > 7:
            errs.append(f"{n} components (assembly should be 1-6)")
        if n == 1 and r.get("meal_type") != "snack":
            r.setdefault("_warn", []).append("single-component meal")
    # semantic sanity
    text = comp_text(r)
    diets = set(r.get("diets_ok") or [])
    allg = set(r.get("allergens") or [])
    meat_text = FISH.sub("", text)
    if MEAT.search(meat_text) and diets & {"vegan", "vegetarian", "pescatarian"}:
        errs.append("meat present but tagged veg/pesc/vegan")
    if FISH.search(text) and diets & {"vegan", "vegetarian"}:
        errs.append("fish present but tagged vegetarian/vegan")
    if FISH.search(text) and "fish" not in allg and not SHELLFISH.search(text):
        errs.append("fish present, allergen 'fish' missing")
    if SHELLFISH.search(text) and "shellfish" not in allg:
        errs.append("shellfish present, allergen missing")
    if EGG.search(text) and ("eggs" not in allg or "vegan" in diets):
        errs.append("egg present: needs allergen 'eggs' and not vegan")
    dairy_hit = DAIRY.search(NON_DAIRY.sub("", text))
    if dairy_hit and ("dairy" not in allg or "vegan" in diets):
        errs.append(f"dairy ({dairy_hit.group(0)}) present: needs allergen 'dairy' and not vegan")
    if GLUTEN.search(text) and not GF_HINT.search(text) and "gluten" not in allg:
        errs.append("gluten-bearing component but allergen 'gluten' missing")
    if GLUTEN.search(text) and not GF_HINT.search(text) and diets & {"paleo"}:
        errs.append("gluten grain tagged paleo")
    if len(HIGH_CARB.findall(text)) >= 2 and "keto" in diets:
        errs.append("2+ high-carb components tagged keto")
    if not r.get("source") or len(str(r.get("source"))) < 8:
        errs.append("source too thin")
    return errs


def dup_key(r):
    """Crude dedupe key: sorted set of main component words (first two tokens of each food)."""
    words = []
    for c in r.get("components", []):
        f = re.sub(r"[^a-z ]", " ", c.get("food", "").lower())
        f = re.sub(r"\b(cooked|steamed|grilled|roasted|baked|boiled|fresh|plain|sliced|raw|whole|large|small|medium|of|the|and|with|a|gluten|free|gf|organic|low|sodium|extra|firm|canned|tinned|dried|frozen|chopped|diced|mixed)\b", " ", f)
        toks = [t for t in f.split() if len(t) > 2]
        if toks:
            words.append(" ".join(toks[:3]))
    return (r.get("meal_type"), tuple(sorted(set(words))))


def load(paths):
    out = []
    for p in paths:
        with open(p, encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict):
            data = data.get("records") or data.get("assemblies") or list(data.values())[0]
        for r in data:
            r["_file"] = p
        out.extend(data)
    return out


def lint(paths, verbose=True):
    recs = load(paths)
    n_err = 0
    seen = defaultdict(list)
    for r in recs:
        errs = check(r)
        if errs:
            n_err += 1
            if verbose:
                print(f"  ! {r.get('_file')} {r.get('id')} '{str(r.get('name'))[:45]}': {'; '.join(errs)}")
        seen[dup_key(r)].append(r.get("id"))
    dupes = {k: v for k, v in seen.items() if len(v) > 1}
    per_type = Counter(r.get("meal_type") for r in recs)
    print(f"records={len(recs)} errors={n_err} dupe_groups={len(dupes)} per_type={dict(per_type)}")
    if verbose:
        for k, v in list(dupes.items())[:40]:
            print(f"  ~ dupe {v}: {k[1]}")
    return recs, n_err, dupes


def coverage(recs):
    rows = []
    types = ["breakfast", "lunch", "dinner", "snack"]

    def row(label, pred):
        cells = [sum(1 for r in recs if r["meal_type"] == t and pred(r)) for t in types]
        rows.append((label, cells, sum(cells)))

    for d in sorted(DIETS):
        row(f"diet:{d}", lambda r, d=d: d in r["diets_ok"])
    for a in sorted(ALLERGENS):
        row(f"free-of:{a}", lambda r, a=a: a not in r["allergens"])
    row("allergen-free as written", lambda r: not r["allergens"])
    for c in ["everyday", "pre-session", "recovery", "rest-day", "race-week", "carb-load", "travel"]:
        row(f"context:{c}", lambda r, c=c: c in r["context"])
    for f in ["staple", "common", "occasional"]:
        row(f"frequency:{f}", lambda r, f=f: r["frequency"] == f)
    row("batch-friendly", lambda r: bool(r.get("batch")))
    row("reconstructed_from_snippet", lambda r: bool(r.get("reconstructed_from_snippet")))
    return rows


def merge(out, paths):
    recs, n_err, dupes = lint(paths, verbose=False)
    # drop exact-key dupes, keep first
    kept, seenk = [], set()
    for r in recs:
        k = dup_key(r)
        if k in seenk:
            continue
        seenk.add(k)
        kept.append(r)
    order = {"breakfast": 0, "lunch": 1, "dinner": 2, "snack": 3}
    kept.sort(key=lambda r: (order[r["meal_type"]], r["id"]))
    # renumber into a flat id space per type
    counters = Counter()
    for r in kept:
        counters[r["meal_type"]] += 1
        r["shard_id"] = r["id"]
        r["id"] = f"A{r['meal_type'][0].upper()}-{counters[r['meal_type']]:03d}"
        r["excluded_diets"] = sorted(DIETS - set(r["diets_ok"]))
        r.pop("_file", None)
    with open(out + ".json", "w", encoding="utf-8") as fh:
        json.dump(kept, fh, indent=1, ensure_ascii=False)
    rows = coverage(kept)
    patterns = Counter((r["meal_type"], r["pattern"]) for r in kept)
    with open(out + ".md", "w", encoding="utf-8") as fh:
        w = fh.write
        w(f"# Assembly library — {len(kept)} no-recipe meals endurance athletes actually eat\n\n")
        w("_Assembled 2026-08-28 by 16 parallel `meal-scout` passes (4 per meal type: mainstream staples, "
          "plant-forward, restricted diets, international + context). An **assembly** is a meal put together "
          "from 1–6 plain components with no method — the everyday counterpart to the recipe-style "
          "`meal-library-400`. Brief and shard files in `assembly-library-research/`; machine-readable in "
          f"`{out.split('/')[-1]}.json`._\n\n")
        w("## Caveats\n\n1. Macros are rough estimates, not catalog lookups.\n2. Attribution is as-found; "
          "publisher sites that block fetching were reconstructed from search snippets (flagged per record).\n"
          "3. Diet/allergen tags were machine-linted (`tools/lint_merge.py`) but not dietitian-reviewed.\n"
          f"4. {len(dupes)} near-duplicate groups across shards were collapsed to one record each.\n\n")
        w("## Coverage\n\n| Coverage | Breakfast | Lunch | Dinner | Snack | All |\n|---|---|---|---|---|---|\n")
        for label, cells, tot in rows:
            w(f"| {label} | " + " | ".join(str(c) for c in cells) + f" | **{tot}** |\n")
        w("\n## Most common patterns\n\n")
        for t in ["breakfast", "lunch", "dinner", "snack"]:
            top = [(p, n) for (mt, p), n in patterns.most_common() if mt == t][:8]
            w(f"- **{t}**: " + ", ".join(f"{p} ({n})" for p, n in top) + "\n")
        for t in ["breakfast", "lunch", "dinner", "snack"]:
            group = [r for r in kept if r["meal_type"] == t]
            w(f"\n---\n\n## {t.capitalize()} ({len(group)})\n\n")
            for r in group:
                w(f"### {r['id']} · {r['name']}\n")
                w(f"- **Pattern:** {r['pattern']} · **Context:** {', '.join(r['context'])} · **Cuisine:** {r['cuisine']} · "
                  f"**Prep:** {r['prep']} · **Batch:** {'yes' if r.get('batch') else 'no'} · **Frequency:** {r['frequency']}\n")
                w("- **Components:** " + ", ".join(f"{c['food']} {c.get('qty','')}".strip() for c in r["components"]) + "\n")
                w(f"- **Diets OK:** {', '.join(sorted(r['diets_ok']))}\n")
                w(f"- **Allergens:** {', '.join(sorted(r['allergens'])) or 'none'}\n")
                w(f"- **Swaps:** {r['swaps']}\n- **Approx:** {r['approx_macros']}\n")
                w(f"- **Source:** {r['source']}\n- **Evidence:** {r['evidence']}\n\n")
    print(f"wrote {out}.json / {out}.md — kept {len(kept)} (dropped {len(recs)-len(kept)} dupes), lint errors remaining: {n_err}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    cmd = sys.argv[1]
    if cmd == "lint":
        _, n, _ = lint(sys.argv[2:])
        sys.exit(1 if n else 0)
    elif cmd == "merge":
        merge(sys.argv[2], sys.argv[3:])
    else:
        print(__doc__)
        sys.exit(2)
