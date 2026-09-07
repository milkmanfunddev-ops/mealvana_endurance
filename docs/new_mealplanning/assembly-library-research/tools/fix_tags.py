#!/usr/bin/env python3
"""Apply deterministic tag fixes to shard files in place, printing a change log."""
import json, sys, re
sys.path.insert(0, 'tools')
import lint_merge as L

changes = 0
for p in sys.argv[1:]:
    recs = json.load(open(p))
    for r in recs:
        before = json.dumps({k: r.get(k) for k in ("diets_ok","allergens","context","swaps")}, sort_keys=True)
        # normalisation
        r["allergens"] = [{"treeNuts":"tree_nuts","lowCarb":"low_carb"}.get(a,a) for a in r.get("allergens",[])]
        r["diets_ok"] = [{"lowCarb":"low_carb"}.get(d,d) for d in r.get("diets_ok",[])]
        r["context"] = [{"post-run":"recovery","post-session":"recovery","pre-run":"pre-session","race-day":"race-week"}.get(c,c) for c in r.get("context",[])]
        if not r.get("swaps"):
            r["swaps"] = "none noted"
        text = L.comp_text(r)
        diets, allg = set(r["diets_ok"]), set(r["allergens"])
        meat_text = L.FISH.sub("", text)
        if L.MEAT.search(meat_text):
            diets -= {"vegan","vegetarian","pescatarian"}
        if L.FISH.search(text):
            diets -= {"vegan","vegetarian"}
            allg.add("shellfish" if L.SHELLFISH.search(text) else "fish")
            if L.SHELLFISH.search(text): allg.add("shellfish")
        if L.EGG.search(text):
            allg.add("eggs"); diets.discard("vegan")
        if L.DAIRY.search(L.NON_DAIRY.sub("", text)):
            allg.add("dairy"); diets.discard("vegan")
        if L.GLUTEN.search(text) and not L.GF_HINT.search(text):
            allg.add("gluten"); diets.discard("paleo")
        if len(L.HIGH_CARB.findall(text)) >= 2:
            diets.discard("keto")
        r["diets_ok"], r["allergens"] = sorted(diets), sorted(allg)
        after = json.dumps({k: r.get(k) for k in ("diets_ok","allergens","context","swaps")}, sort_keys=True)
        if before != after:
            changes += 1
            print(f"  ~ {r['id']} {r['name'][:40]!r}: {before} -> {after}")
    json.dump(recs, open(p,"w"), indent=1, ensure_ascii=False)
print(f"changed {changes} records")
