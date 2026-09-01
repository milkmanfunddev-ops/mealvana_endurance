# Run — brick transition design capture (2026-09-01)

App: local branch `fix/activity-update-preserves-device-fields` (contains brick merge `d55c3c8b`),
dev flavor, iPhone 17 sim. Driver: idb/simctl fallback. Purpose: record the as-built transition
nutrition design on BOTH access paths (Xuan, 2026-09-01) ahead of ratification.
Screenshots: `runs/2026-09-01-brick-transition-design/`.

## Paths walked
- **A — event creation:** Create New Activity Plan → BRICK sport → leg tiles → Adjust Your
  Macros → Create Plan → plan page (`02…07`).
- **B — daily dashboard:** day timeline → BRICK card (2 legs · 127 min, "Pre · During ·
  Recovery fuel" footer) → tap → the SAME plan page, saved-activity chrome (`15…17`).
  Both paths land on one surface; there is no second transition rendering.

## The transition card as built (run 60 → bike 67, moderate, 73 kg-class account)
- Header: 🔁 `TRANSITION 1` + "Quick refuel between segments" + `?` (`09`).
- Stat trio: CARBS `90g` (bare, no band, no target) · PROTEIN `0g` · SODIUM `265/248mg`
  (delivered/target — the only stat rendered as a pair). **No FLUIDS stat on the card.**
- Foods: `3 Energy Gels` + `1 cup Sports Drink` + ADD FOOD.
- Drawer "How We Calculate Your Transition 1 Targets" (`11–14`): chip `T1 / T2`;
  per-stat sections with planned/target headline, formula line, Calculation + The Full Story
  expanders, per-section Helpful? 👍👎:
  - Carbs: **90g planned / 0g target**, `T1 target = 0g` (the <180-min tier, live).
  - Fluids: **10oz planned / 10oz target**, `T1 = fixed 10 oz` — "not a calculated segment…
    conservative bolus… 2–5 minute stop."
  - Sodium: **265mg planned / 248mg target**, `300 mL × conc 825 mg/L ÷ 1000 = 248mg`.

## Findings
| # | Finding | Class |
|---|---|---|
| F-A | **The 3-gel anecdote reproduced live**: 90 g delivered against a 0 g carb target — the selector chased sodium (248 mg) + water (300 ml) with gels. Mechanism 1 of the 2026-08-31 notes confirmed end-to-end. | known gap → food-recommendation bench (C4 + selection rewrite) |
| F-B | Card stat semantics are inconsistent: carbs shows *delivered only*, sodium shows *delivered/target*, fluids is *absent from the card* yet present in the drawer (10oz/10oz). | design ruling needed (transition-card spec) |
| F-C | Drawer contradiction: Full Story urges "quick-digesting carbs… helps maintain blood glucose" while the target reads 0 g. | resolved by ratifying transition-nutrition.md (target becomes ~24 g here) |
| F-D | Hardcoded triathlon copy on a run→bike brick: "between the swim and bike segments", "T1 bridges the swim gap and offsets wetsuit heat." | copy register defect; fix at implementation |
| F-E | Stale auto-name: header "RUNNING/RUNNING BRICK" while legs are RUN/BIKE (subtitle correct). | app bug (ops-side) |
| F-F | UI naming is already positional (`TRANSITION 1` on run→bike) and targets flowed — consistent with D-008's analysis that run→bike happens to produce a matching `T1`; bike→run remains the broken order. | supports R8; seam test still required |
| F-G | Adjust-Macros DURING aggregate (112 g) excludes the transition's delivered 90 g (52+59=111≈112). Transition is not represented anywhere on the aggregate table. | design ruling: where does transition fuel appear in aggregates? |
| F-H | Brick form facts: default 2×RUN legs (240/60 min defaults — the 240 cap visible, D-016), "BRICK IS FULL · 3 LEGS" cap copy (R4 rendered), brick-specific fasted warning: "Fasted training is not recommended for longer or harder bricks. Consider fueling before." | record; R4 conformance hook |
| F-I | BEFORE BRICK card: 80 g/12 oz/263 mg with band rails 73–292 g / 0–25 oz; PRE sodium on Adjust table renders "—" (F-1 honest-null ✓). | consistent with pre-workout family |

## Numbers vs the PROPOSED transition spec (`spec/fueling/transition-nutrition.md`)
This exact brick under the proposed model: total 127 min → band 45–60 → mid 52.5 g/h (bike
ceiling 120) · gap = 15 + ~2 + 10 = 27 min → dose ≈ **24 g** (band [0,30]) — vs as-built target
0 g and delivered 90 g. Fluid: proposed no-transition-demand (placement) vs as-built fixed 10 oz
target; sodium: as-built rides the fluid bolus — under the proposed model both move to the
continuous schedule (the multi-segment hydration slice owns the redistribution).
