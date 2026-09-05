> **RESOLVED 2026-09-01 → ruling folded to spec/domain/catalog-conventions.md v1 (qa/brick-transition-nutrition); handback intake/2026-09-01-handback-catalog-conventions.md**

type: ruling-request
bundle: (food-recommendation ratification; touches pre-workout-hydration@v6 delivered-fluid accounting)

## Why this matters
Every plan's "delivered fluid" is partly imaginary and dry powders ship with no water — until the catalog's fluid convention is ruled, P13 cannot be fixed and the water-pairing invariant is structurally defeated.

## The question
What does `template_foods.fluid_ml` MEAN for items consumed with water — dry (0, fluid added separately) or as-prepared (the mixed volume)? And should the electrolyte↔water pairing invariant extend to non-electrolyte powders?

## Evidence (probe register F-13, F-15, F-16, F-36, F-41 — runs/2026-08-31-food-recommendation-probe.md)
- Live dev rows are INCONSISTENT: `electrolyte_tablet` fluid_ml=475 (a tablet!), `electrolyte_packet` 480, `carb_drink_mix` 500 — but `sports_drink_mix` 0, `electrolyte_capsule` 0. `oatmeal` carries 200ml/serving (P18's 44oz).
- Code assumes dry: `generate-macros-v4/pre-workout.ts:1080` "Electrolytes have 0 fluid_ml — they dissolve in the drink".
- Consequence A (fl>15ml rows): the pairing pass treats them as self-satisfying → tablet ships with NO water row; delivered-fluid overcounts (sim: 4h run showed 109oz "delivered", 16oz of it the mix's phantom water — `runs/2026-08-31-food-recommendation-probe/27.png`).
- Consequence B (fl=0 non-electrolyte powders): invisible to the pairing pass → "0.5 packets Carb Drink Mix" / "0.5 servings Sports Drink Mix" ship standalone (`34.png`, `43.png`).

## Options
1. **Dry convention** (recommended): fluid_ml = intrinsic fluid only; powders/tablets = 0; pairing invariant extends to ANY item flagged requires-water (new column `requires_fluid_ml` or reuse `is_drink_pool` semantics); delivered fluid counts only drinkable rows + pairing water. Cost: catalog corrections + pairing scope extension + fluid accounting change.
2. **As-prepared convention**: fluid_ml = mixed volume, and the selector must then EMIT the water ("mix with 16oz water" instruction row) so the plan carries the water it counts. Cost: selector emits instructions; catalog must be made consistent the other way (sports_drink_mix 0 → 500).
3. Status quo — inconsistent per row (not tenable; both failure modes live).

## Gates
P13 close-out; water-pairing extension (S3); catalog corrections; the "delivered fluid" definition in pre-workout-hydration conformance (H6 deferred question).

## Suggested spec home
`spec/fueling/pre-workout-food-composition.md` (catalog column contract) + a delivered-fluid definition note in `pre-workout-hydration.md`.

> **Addendum 2026-09-01:** prod catalog audited — byte-identical to dev (93/93 rows, zero diffs), so every offender row above ships on prod today; one correction pass fixes both projects. Register F-52.

## RULING (Xuan, 2026-09-01)
- **A1 — dry zeros, RULED as drafted:** `fluid_ml` = fluid the item delivers as consumed; powders/tablets/single-serve mixes are dry → 0. Corrections: electrolyte_tablet 475→0 · electrolyte_packet 480→0 · electrolyte_drink_mix 500→0 · high_sodium_electrolyte_mix 480→0 · carb_drink_mix 500→0 · high_carb_drink_mix 600→0. (sports_drink_mix already 0; pickle_juice_shot keeps 70 — genuinely liquid.)
- **A2 — pairing extension, RULED as drafted:** the water-pairing invariant covers every dry requires-water item (the A1 set), not only electrolytes.
- **A3 — RULED, AMENDED from the draft:** food-embedded water **counts toward the hydration/delivered-fluid plan** when the row's consumed state carries it — cooked oatmeal keeps 200 ml because the athlete absorbs that water. A row whose consumed state is literally dry must carry 0. Mixes stay 0 **because their water arrives as the pairing water row — counting it on the mix would double-count.** Consequence for P18: the 200 ml/serving was legitimate; the 44 oz absurdity was the ×6.5 pin scaling alone. This also closes the deferred H6/P13 "does food-embedded water count" question: **it counts.**
