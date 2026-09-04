# SSOT — Shopping List

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** `../../synthesis-and-recommendations.md` finding 2 (the shopping list is the research's "moment of
value").
**Code:** `buildShoppingList(userId, plan)` → `buildItems(meals, have)` with `canonicalName`, `classifyAisle`,
`parseQty`, `aggregate` — prototype `server/vana/grocery.ts` ≡ edge `_shared/vana/grocery.ts`. The edge twin
additionally folds the `pantry_items` setting into `have` (Phase 7, 2026-09-03 — D-012). No Dart twin: the client
never builds the list (plan-tab-v2 sync table: "server-derived, don't compute on device").
**Scope:** ingredient resolution → canonical names → aisles → aggregated quantities → pantry `have`.
**Consumers:** `MealPlan.shopping`, the `shopping_list` part (`itemCount` = items not `have`; `skipped` = the
`have` names), the Shopping tab, the ConfirmedCard copy ("13 items. I skipped rice, you have it.").

The shopping list is the research's "moment of value" (`../../synthesis-and-recommendations.md` finding 2); it
is rebuilt deterministically on **every plan mutation** (`refreshShopping`), never by the model.

## Inputs

| Source | Ingredient rows | `baseServings` |
|---|---|---|
| `plan_meals.source = library` | `meal_library.ingredients_json[] {name, qty}`, with `swaps_applied` rewriting `from → to` by canonical name | 1 — library portions are per athlete serving |
| `plan_meals.source = saved` | `saved_meals.items[] {name \| food_name, portion \| quantity \| serving}` | 1 |
| pantry | `have` = staples logged ≥ 2× in 30 days whose canonical name contains one of `rice, oats, pasta, peanut butter, honey, olive oil, soy sauce` (+ edge: the `pantry_items` setting) | — |

## Constants

```
ALWAYS_HAVE  = { salt, pepper, olive oil, water, oil, pinch }    # exact canonical-name match → dropped
AISLE_ORDER  = Produce → Protein → Dairy → Bakery & Grains → Pantry → Spices → Frozen → Beverages → Other
PRIORITY     = Pantry:{crushed/chopped/tinned tomatoes, canned, tomato sauce/paste, passata, marinara, coconut milk,
                       peanut/almond/seed butter, stock, broth, dried, raisin, sun-dried}  Frozen:{frozen}
               Dairy:{cottage cheese, greek yogurt, cream cheese}            # substring, checked first
AISLE_RULES  = the keyword table in grocery.ts (Produce 60 keys … Beverages 8), matched as (?<![a-z])<key>
QUARTER      = totals round to ¼; ½ ¼ ¾ render as vulgar fractions
PROMOTE      = g ≥ 1000 → kg (1 dp) · ml ≥ 1000 → l (1 dp)
```

## The algorithm

```
for each plan meal m, each ingredient i:
  key = canonicalName(i.name)                 # lowercase · collapse onion colours / garlic cloves / baby spinach ·
                                              # strip cooking adjectives + (parentheticals) · drop ", …" tails ·
                                              # drop trailing dry/uncooked/cooked
  if key == "" or key ∈ ALWAYS_HAVE: skip
  bucket[key].entries += { qty: i.qty, mult: m.servings / max(1, m.baseServings) }
  bucket[key].from    += m.id
item = { aisle: classifyAisle(key), name: capitalise(key), qty: aggregate(entries), checked: false,
         have: ∃ h ∈ have : key.includes(h), fromMealIds }
sort by AISLE_ORDER index, then name (locale compare)

aggregate(entries): parse each qty → (n, unit); Σ n×mult per unit; render each unit (promote g/ml); non-numeric
                    quantities: keep the FIRST as a trailing part; join with " + "
refreshShopping(plan): rebuild; carry over `checked` and `have` from the previous list by lower-cased name
                       (have = new ∨ old); flag day_notes_stale
```

## Invariants

1. `checked == false` on every freshly built item; only `toggle_shopping` sets it, and it survives rebuilds.
2. `have` survives rebuilds and is monotone (a rebuild can add `have`, never remove it).
3. Every item traces to ≥ 1 `fromMealIds`; removing the last meal that needs it removes the item.
4. Units are never converted into each other (`agg-mixed-units-join`).
5. The list is a pure function of `(plan meals, ingredient rows, have)` — no model, no randomness.

## Worked examples

`vectors/planning/shopping-list.json` `two-meals-dedupe-aisles-pantry` is the canonical one (from the
prototype's own unit test): chicken ×5 and salmon ×4 sharing jasmine rice → 4 items, rice `900 g` and `have`.

## Tripwires (characterization vectors)

- `sea-salt-is-not-salt` — ALWAYS_HAVE is exact, so "sea salt" is bought. **Q-SL1.**
- `have-matches-by-substring` — pantry "rice" marks "rice cakes" as owned. **Q-SL1.**
- `aisle-kombucha-is-pantry` (Pantry's `kombu` wins) · `aisle-ice-cream-is-dairy` (Dairy's `cream` beats Frozen's
  `ice cream`). **Q-SL2.**

## Deviations

- **D-012** — the edge twin's `have` also includes the `pantry_items` setting; the prototype does not.

## Conformance

Vectors: `vectors/planning/shopping-list.json` (33: 4 `buildItems`, 7 `parseQty`, 6 `aggregate`, 10
`classifyAisle`, 6 `canonicalName`). Edge 33/33, prototype 33/33 (2026-09-03). The DB half (ingredient
resolution, swap rewriting, `pantryFromLogs`, carry-over on rebuild) is covered only by the smoke.
