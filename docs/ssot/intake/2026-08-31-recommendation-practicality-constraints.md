> **RESOLVED 2026-09-01 (PARTIAL — B1/B2/B3 transition slice → spec/domain/catalog-conventions.md v1 on qa/brick-transition-nutrition); meal-tier items (a)(b)(d) remain OPEN with this branch**

type: ruling-request
bundle: (food-recommendation ratification — the P13/P17/P18 umbrella)

## Why this matters
Plans are numerically in-band yet physically silly: three bananas as a meal, ten cups of sports drink to carry on a run, half an energy gel at a brick transition — athletes lose trust in every number on the card.

## The question
What practicality constraints must food selection satisfy beyond macro bands? Candidates observed missing: (a) per-item practical portion caps at recommendation time (a "meal" is not one food ×3.5 — P18/F-33, "Banana ×3" F-29); (b) a carryability/volume budget for during-phase rows ("10 cups Sports Drink", 2.4L — F-37); (c) indivisibility honored for physically-indivisible items (catalog marks gels & bananas divisible → "0.5 Energy Gels" at T1, "0.5 Bananas" post — F-42); (d) minimum variety in a meal slot (single-component meals allowed today).

## Evidence
Probe register F-29, F-33, F-37, F-42 with screenshots in `runs/2026-08-31-food-recommendation-probe/` (`14.png`, `25.png`, `27.png`, `43.png`, `44.png`). All arise from selection/catalog, not target math — engine targets verified in-band in every case.

## Options
Rule each constraint into the food-composition SSOT as selector contract lines (the H-series pattern): portion cap per product_type; per-phase volume budget; is_indivisible corrections (gel, banana true) as catalog data fixes once the flag's semantics are ruled; meal-tier composition minimum (≥2 components unless template is explicitly single-food-sufficient). Or explicitly ratify "macro bands only, practicality out of scope" (not recommended).

## Gates
P18 close-out; catalog `is_indivisible` corrections; during-selector volume budget; the meal-tier suitability rule the 2026-08-05 drop-migration articulated ("standalone-sufficient feeding") but no spec holds.

## Suggested spec home
`spec/fueling/pre-workout-food-composition.md` (+ a during-workout counterpart section in during-workout-carbs.md for volume/carryability).

## RULING (Xuan, 2026-09-01) — TRANSITION SLICE ONLY
- **B1 — `is_indivisible` semantics RULED:** true = cannot be consumed in fractional units. Corrections: `energy_gel` → true; single-serve sticks/packets → true. Divisible-in-practice items (banana, scoops) unchanged.
- **B2 — RULED:** transition (T1/T2) recommendations use **whole consumable units only**.
- **B3 — RULED:** **max 2 items per transition**, plus a water row when the pairing invariant demands it.
- Items (a) portion caps, (b) volume/carryability budget, (d) meal variety: **remain OPEN** — decided with the food-recommendation ratification, not the brick bundle.
