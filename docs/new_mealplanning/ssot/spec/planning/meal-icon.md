# SSOT — Meal Icon

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `mealIconFor({name, ingredients?, pattern?})` · `resolveMealIcon(stored, …)` — prototype
`lib/vana/meal-icon.ts` ≡ edge `_shared/vana/meal-icon.ts` (byte-identical) ≡ Dart `MealIconClassifier`
(keyword lists ported byte-for-byte; **verified by the Dart arm**).
**Persisted:** `meal_library.icon`, `saved_meals.icon`, `plan_meals.icon` (copied from the source at add/swap);
`search_meals()` returns it. Every surface renders `stored ?? classify(name)`.

## The 23 keys

`bowl oats chicken meat fish egg salad bread wrap pasta soup pizza drink fruit nuts yogurt potato beans tofu baked
snack sweet utensils` — the wire enum (`MealIconKeyZ`); Flutter maps each to a Font Awesome glyph
(`plan-tab-v2.md` §Meal icons). Adding a key is a contract change in three places.

## The algorithm

```
tiers = [HEADLINE, DISH, PROTEIN, STARCH, OTHER]        # keyword regexes, \b(?:…) prefix-bounded, case-insensitive
classify(text): for tier in tiers: k = earliest match position among the tier's rules; if k: return k
icon = classify(name) ?? classify(ingredients) ?? patternHint(pattern) ?? "utensils"
patternHint: /protein/ → chicken · /starch|grain/ → bowl · /fruit/ → fruit · /veg|green/ → salad
resolve(stored, …) = stored if stored ∈ KEYS else icon
```

| Tier | Meaning | Examples of keys |
|---|---|---|
| 0 HEADLINE | dishes that name the whole plate | jacket/baked/loaded potato, hash · pizza · smoothie/shake/latte/juice/coffee/tea/chocolate milk/electrolyte · soup/stew/chili/curry/dal/ramen/pho/broth |
| 1 DISH | the dish form | pasta/noodle… · wrap/burrito/taco… · sandwich/toast/bagel/bread/rice cake/naan… · salad/slaw/poke · oats/porridge/granola/cereal/overnight · yogurt/skyr/cottage cheese · pretzel/energy bar/gel/chews · pancake/waffle/muffin/frittata/quiche… |
| 2 PROTEIN | the protein | chicken/turkey · beef/steak/pork/bacon/burger… · salmon/tuna/fish/shrimp… · egg/omelette/shakshuka · tofu/tempeh/seitan/paneer · bean/lentil/chickpea/hummus/falafel/dal |
| 3 STARCH | the base | potato/fries/yam · rice/quinoa/couscous/grain/bowl/farro/… |
| 4 OTHER | the rest | bar/popcorn/chips… (snack) · banana/apple/berr…/avocado (fruit) · nut/almond/seed/trail mix (nuts) · cheese/milk/whey/butter (yogurt) · cookie/chocolate/honey/maple/sugar (sweet) · broccoli/spinach/veg… (salad) |

**Within a tier, position wins, not list order** (`earliest-in-tier-*`). Across tiers, the lower tier wins
however late it appears (`headline-soup-beats-protein`).

## Invariants

1. Total: every input yields one of the 23 keys; `utensils` is the only fallback.
2. Deterministic and model-free.
3. A valid stored key is authoritative (`stored-key-wins`); an invalid one is ignored (`invalid-stored-key-reclassifies`).
4. Over the 1,922 live rows (backfill 2026-08-31): 0 `utensils` from classification.

## Tripwire

`dal-is-soup` — "Dal with rice" renders the soup glyph, not beans, because `dal` sits in the headline soup list.
**Q-MI1** (product call).

## Conformance

Vectors: `vectors/planning/meal-icon.json` (29). Edge 29/29 · prototype 29/29 · Dart 29/29 (2026-09-03).
Required coverage: one vector per tier, both "earliest in tier" orderings, the three fallbacks, both stored-key
branches. **The keyword lists themselves are pinned by the byte-identity rule (R5), not by vectors** — a
`diff` between the three twins' tables is the cheaper guard (see `conformance/README.md`).
