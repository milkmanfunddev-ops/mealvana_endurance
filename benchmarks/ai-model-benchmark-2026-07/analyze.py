#!/usr/bin/env python3
"""Score the 2x2 benchmark results.

There is no ground truth for these meals, so this deliberately does NOT claim
an accuracy number. It measures what can be measured honestly:

  1. Cost / latency / tokens per arm — hard numbers.
  2. Instruction adherence — the prompt gives an explicit, checkable rule
     ("one item per DISH, not one item per raw ingredient"), so item-count
     inflation is a measurable failure to follow it.
  3. Model agreement — where Haiku and Sonnet diverge sharply on the same
     input, one of them is wrong; those are the cases worth eyeballing.
  4. Compression sensitivity — same model, same image, 1000px vs full-res.
     This is the S4 question: does the downscale change the answer?
"""

import json
import pathlib
import statistics as st

ROOT = pathlib.Path(__file__).resolve().parent
R = json.loads((ROOT / "_derived" / "results.json").read_text())

# $ per 1M tokens
PRICE = {
    "anthropic/claude-haiku-4.5": (1.00, 5.00),
    "anthropic/claude-sonnet-4.6": (3.00, 15.00),
}


def cost(r):
    pin, pout = PRICE[r["model"]]
    return (r["input_tokens"] * pin + r["output_tokens"] * pout) / 1e6


by = {}
for r in R:
    parts = r["tag"].split("|")
    kind, model = parts[0], parts[1]
    arm = parts[2] if kind == "image" else "text"
    key = parts[-1]
    by[(kind, model, arm, key)] = r

def rows(kind, model, arm):
    return [v for (k, m, a, _), v in by.items()
            if k == kind and m == model and a == arm]


def section(title):
    print(f"\n{'=' * 74}\n{title}\n{'=' * 74}")


section("1. COST · LATENCY · TOKENS")
print(f"{'arm':<28}{'n':>4}{'$/call':>10}{'$ total':>10}"
      f"{'p50 s':>8}{'p95 s':>8}{'out tok':>9}")
totals = {}
for kind, arm in [("text", "text"), ("image", "compressed"),
                  ("image", "uncompressed")]:
    for model in ("haiku", "sonnet"):
        rs = rows(kind, model, arm)
        if not rs:
            continue
        cs = [cost(r) for r in rs]
        lat = sorted(r["latency_s"] for r in rs)
        p95 = lat[int(len(lat) * 0.95) - 1]
        totals[(kind, model, arm)] = sum(cs)
        print(f"{kind + '/' + arm + ' · ' + model:<28}{len(rs):>4}"
              f"{st.mean(cs):>10.4f}{sum(cs):>10.4f}"
              f"{st.median(lat):>8.1f}{p95:>8.1f}"
              f"{st.mean([r['output_tokens'] for r in rs]):>9.0f}")
print(f"\n  grand total spend: ${sum(totals.values()):.4f}")

h = sum(v for (k, m, a), v in totals.items() if m == "haiku")
s = sum(v for (k, m, a), v in totals.items() if m == "sonnet")
print(f"  haiku ${h:.4f}  vs  sonnet ${s:.4f}   → sonnet is {s / h:.1f}x haiku")


section("2. INSTRUCTION ADHERENCE — 'one item per DISH, not per ingredient'")
print("Mean items returned for the SAME inputs. Higher = more ingredient")
print("splitting = worse adherence to an explicit prompt rule.\n")
print(f"{'arm':<28}{'haiku':>10}{'sonnet':>10}{'delta':>10}")
for kind, arm in [("text", "text"), ("image", "compressed"),
                  ("image", "uncompressed")]:
    hh = [len(r["analysis"]["items"]) for r in rows(kind, "haiku", arm)]
    ss = [len(r["analysis"]["items"]) for r in rows(kind, "sonnet", arm)]
    if not hh:
        continue
    print(f"{kind + '/' + arm:<28}{st.mean(hh):>10.2f}{st.mean(ss):>10.2f}"
          f"{st.mean(hh) - st.mean(ss):>+10.2f}")

print("\nWorst per-input splits (text arm), haiku vs sonnet item counts:")
splits = []
for (k, m, a, key), v in by.items():
    if k == "text" and m == "haiku":
        so = by.get(("text", "sonnet", "text", key))
        if so:
            splits.append((len(v["analysis"]["items"])
                           - len(so["analysis"]["items"]), key,
                           len(v["analysis"]["items"]),
                           len(so["analysis"]["items"])))
for d, key, hn, sn in sorted(splits, reverse=True)[:6]:
    print(f"   {key:<12} haiku {hn:>2} items   sonnet {sn:>2} items   ({d:+d})")


section("3. MODEL DISAGREEMENT ON CALORIES (same input, both models)")
print("Large gaps mean one model is materially wrong — worth a human look.\n")
gaps = []
for (k, m, a, key), v in by.items():
    if m != "haiku":
        continue
    so = by.get((k, "sonnet", a, key))
    if not so:
        continue
    hc = v["analysis"]["totals"]["calories"]
    sc = so["analysis"]["totals"]["calories"]
    if max(hc, sc) > 0:
        gaps.append((abs(hc - sc) / max(hc, sc), f"{k}/{a}/{key}", hc, sc))
gaps.sort(reverse=True)
print(f"  median relative gap: {st.median([g[0] for g in gaps]):.1%}")
print(f"  gaps over 40%: {sum(1 for g in gaps if g[0] > 0.4)} of {len(gaps)}\n")
for rel, tag, hc, sc in gaps[:8]:
    print(f"   {tag:<34} haiku {hc:>5} kcal   sonnet {sc:>5} kcal   ({rel:.0%})")


section("4. COMPRESSION SENSITIVITY (the S4 question)")
print("Same model, same image, 1000px vs full-res. If the downscale is safe,")
print("these deltas should be small and non-systematic.\n")
for model in ("haiku", "sonnet"):
    deltas, item_changes, conf_changes = [], 0, 0
    for (k, m, a, key), v in by.items():
        if k != "image" or m != model or a != "compressed":
            continue
        u = by.get(("image", model, "uncompressed", key))
        if not u:
            continue
        c1 = v["analysis"]["totals"]["calories"]
        c2 = u["analysis"]["totals"]["calories"]
        if max(c1, c2) > 0:
            deltas.append(abs(c1 - c2) / max(c1, c2))
        if len(v["analysis"]["items"]) != len(u["analysis"]["items"]):
            item_changes += 1
        if v["analysis"]["confidence"] != u["analysis"]["confidence"]:
            conf_changes += 1
    print(f"  {model}:  median kcal delta {st.median(deltas):.1%}   "
          f"mean {st.mean(deltas):.1%}   "
          f"item-count changed on {item_changes}/11   "
          f"confidence changed on {conf_changes}/11")

print("\n  Largest compression-induced swings:")
sw = []
for model in ("haiku", "sonnet"):
    for (k, m, a, key), v in by.items():
        if k != "image" or m != model or a != "compressed":
            continue
        u = by.get(("image", model, "uncompressed", key))
        if not u:
            continue
        c1 = v["analysis"]["totals"]["calories"]
        c2 = u["analysis"]["totals"]["calories"]
        if max(c1, c2) > 0:
            sw.append((abs(c1 - c2) / max(c1, c2), model, key, c1, c2,
                       v["analysis"]["name"], u["analysis"]["name"]))
for rel, model, key, c1, c2, n1, n2 in sorted(sw, reverse=True)[:6]:
    print(f"   {model:<7}{key:<8} {c1:>5} → {c2:<5} kcal ({rel:.0%})")
    if n1 != n2:
        print(f"           named: {n1!r} → {n2!r}")


section("5. CONFIDENCE DISTRIBUTION")
for kind, arm in [("text", "text"), ("image", "compressed"),
                  ("image", "uncompressed")]:
    for model in ("haiku", "sonnet"):
        rs = rows(kind, model, arm)
        if not rs:
            continue
        c = {}
        for r in rs:
            c[r["analysis"]["confidence"]] = c.get(
                r["analysis"]["confidence"], 0) + 1
        print(f"  {kind + '/' + arm + ' · ' + model:<28}"
              + "  ".join(f"{k}={v}" for k, v in sorted(c.items())))


section("6. TOTALS ARITHMETIC — do reported totals match summed items?")
print("The schema asks the model to compute totals. A model that can't add")
print("its own items is producing macros the app will show verbatim.\n")
for kind, arm in [("text", "text"), ("image", "compressed"),
                  ("image", "uncompressed")]:
    for model in ("haiku", "sonnet"):
        rs = rows(kind, model, arm)
        if not rs:
            continue
        bad = 0
        worst = 0.0
        for r in rs:
            a = r["analysis"]
            summed = sum(i["calories"] for i in a["items"])
            rep = a["totals"]["calories"]
            if max(summed, rep) > 0:
                d = abs(summed - rep) / max(summed, rep)
                worst = max(worst, d)
                if d > 0.02:
                    bad += 1
        print(f"  {kind + '/' + arm + ' · ' + model:<28}"
              f"mismatched: {bad}/{len(rs)}   worst {worst:.0%}")
