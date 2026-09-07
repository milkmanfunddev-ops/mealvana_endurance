# SSOT — Catalog conventions: fluid semantics & consumable units

**Status:** v1 — created by RULING (Xuan, 2026-09-01), the brick.md precedent (impact class b).
**Source:** `intake/2026-08-31-catalog-fluid-convention-and-powder-pairing.md` and the transition
slice of `intake/2026-08-31-recommendation-practicality-constraints.md` (both stamped RESOLVED on
`qa/food-recommendation`; probe evidence register `runs/2026-08-31-food-recommendation-probe.md`
F-13/15/16/36/41/42 there). Domain policy: applies to every engine that reads `template_foods`.

## C1 — `fluid_ml` means "fluid the item delivers as consumed" — RULED (Xuan, 2026-09-01)
- Powders, tablets, and single-serve mixes are **dry: `fluid_ml` = 0.** Their water arrives as the
  separate pairing water row (C2); carrying it on the item row double-counts.
- **Food-embedded water COUNTS toward the hydration / delivered-fluid plan** when the row's
  consumed state carries it: cooked oatmeal keeps its 200 ml — the athlete absorbs that water.
  A row whose consumed state is literally dry must carry 0. (This also settles the deferred
  H6/P13 question from `bundles/pre-workout-macros.deferred.md`: embedded water **counts**.)
- Catalog corrections this ruling orders (dev and prod are row-identical — one migration, both
  projects): `electrolyte_tablet` 475→0 · `electrolyte_packet` 480→0 · `electrolyte_drink_mix`
  500→0 · `high_sodium_electrolyte_mix` 480→0 · `carb_drink_mix` 500→0 · `high_carb_drink_mix`
  600→0. Unchanged by design: `sports_drink_mix` (already 0) · `pickle_juice_shot` 70 (genuinely
  liquid) · `oatmeal` 200 (consumed cooked) · fruit/rice intrinsic water.

## C2 — Water pairing covers every dry requires-water item — RULED (Xuan, 2026-09-01)
The electrolyte↔water pairing invariant (`_shared/nutrition/electrolyte-water-pairing.ts` and its
Dart mirror) extends beyond electrolyte-flagged items to **any dry item that requires water to
consume** — the C1 zero-fluid set (carb mixes included: nobody chews drink mix). Mechanism:
a `requires_water` flag, or derivation from `product_type` + `fluid_ml = 0`, decided app-side.

## C3 — `is_indivisible` = "cannot be consumed in fractional units" — RULED (Xuan, 2026-09-01)
Corrections: `energy_gel` → true; single-serve sticks/packets → true. Divisible-in-practice items
(banana halves, powder scoops) unchanged.

## C4 — Transition (T1/T2) recommendations — RULED (Xuan, 2026-09-01)
- **Whole consumable units only** (no 0.5 gels, no fractional sticks — probe evidence F-42).
- **Maximum 2 items per transition**, plus a water row when C2 demands it.
These constrain the transition selection this branch's spec will ratify; the selection mechanism
being replaced is mapped in the probe register (F-25: during-template-0 on a synthetic 60-min
duration → LP (maxFoodItems 3, cap 2) → greedy).

## Explicitly NOT ruled here
Meal-tier practicality — per-item portion caps, during-phase volume/carryability budgets, meal
variety minimums — remains OPEN with the food-recommendation ratification
(`qa/food-recommendation`, intake practicality file items (a)(b)(d)).

## C3a — Clarification: powder mixes remain DIVISIBLE — RULED (Xuan, 2026-09-03)
`is_indivisible = true` means *physically unportionable as consumed*: gels (cannot re-cork),
capsules, tablets. **Powder mixes (`carb_drink_mix`, `high_carb_drink_mix`,
`electrolyte_drink_mix`, `sports_drink_mix`) stay divisible** — dissolving 1.5 packets into a
bottle is normal practice, especially cycling. The gels-only shipped migration was therefore the
correct implementation of C3; the original "single-serve sticks/packets → true" wording was
overbroad and is superseded by this clarification. Unchanged: C4's whole-consumable-units rule at
transitions (a T-window is not a mixing moment) — fractional mixes remain fine in the during
phase, not at T1/T2.
