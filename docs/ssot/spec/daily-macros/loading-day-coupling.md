# SSOT — Loading-Day Coupling (daily macros × carb-loading plan)

**Status: PROPOSED (drafted 2026-09-25 under Q-019's ruled direction — Xuan, morning interview:
OPTION 1, plan-authoritative override. The formulas below are the rebalance proposal for the
mini-interview; nothing here is ratified).** **Engine:** B (the daily-macros pipeline) — TWIN
implementations (edge `generate-macros` + app Dart) under the D-005 parity discipline; the
coupling must land in BOTH or the dashboard/meal-page split this spec exists to kill returns as
a twin split. **Bundle:** `loading-day-macros-coupling` (own track; RELEASE-coupled to the
carb-loading LOAD face). **Authorities:** `assembly.md` (the pipeline), `multi-day-context.md`
Formula 8, `spec/fueling/carb-loading.md` CL-3/CL-4a (the plan-side numbers).

## LC-1 — The trigger (scope guard)
The override applies iff the computed date falls inside a carb-loading plan that the ATHLETE'S
OWN account created and has not deleted (the same data condition that selects the LOAD face —
one predicate, two consumers; a divergence is a bug). Race day itself is OUTSIDE every plan
window (plans end day −1) — race-day daily macros are untouched by this spec.

## LC-2 — Carb: replace, not floor
`carb := the plan day's STORED carbTargetGrams` (athlete edits included, per CL-4a). This
REPLACES the pipeline's carb value after step 8 (baseline, debt, pre-load, weekly, phase all
compute-then-yield); Formula 8's 9.0 floor is redundant inside a plan and REMAINS as the
no-plan race-tomorrow fallback — the two never stack.
- The step-9 carb clamp (12 g/kg) does NOT bind the override *(proposal — interview Q-LC2)*:
  plan-authoritative means one number everywhere, including an athlete's 900 g edit.

## LC-3 — Protein: unchanged
Protein holds the pipeline's ratified value (its own clamps stand). Loading days change fuel,
not protein policy.

## LC-4 — Fat: residual with a floor; intake may exceed TDEE by design
F15 computes fat as the energy residual as today, around the overridden carb. Then:
`fat := max(residual_fat, FAT_FLOOR_G)` with **`FAT_FLOOR_G = 0.5 × weight_kg`** *(proposal —
interview Q-LC1; clinical essential-fat guidance; ≈15 %E at these intakes; the RACE_WEEK
`fat_mod 0.85` note recorded this squeeze-fat intent in 2026-08)*. When the floor binds,
**intake deliberately exceeds TDEE** — a glycogen-storage surplus is the point of a load day —
and the pipeline does NOT re-inflate TDEE to match: `tdee` stays descriptive (energy out),
`energy_basis = "loading_surplus"` *(new enum value)* says the delivered intake is
plan-authoritative. The 10b fat cap stands (unreachable when the floor binds). The EA gate runs
unchanged (a surplus can only raise EA; BLOCK still stops a plan for its own reasons).

## LC-5 — Provenance
`sources` gains the tag `carb_loading_plan` on the carb figure (Q-012's enum widens by one —
enum change is part of this bundle); consumers may render the provenance ("from your
carb-loading plan") but the NUMBER needs no qualifier — it is the same number the LOAD face
shows, which is the whole point.

## Worked example (the oracle target; 68.0 kg, protein 1.8 g/kg, RMR-normal day, TDEE ≈ 2,600)
Day −1 of the 3-Day Classic (stored 680 g): carb 680 (2,720 kcal) · protein 122 g (490) ·
residual fat < 0 → floor binds: fat = 34 g (306) → intake 3,516 kcal vs TDEE 2,600 →
`energy_basis = loading_surplus`, sources carb = `carb_loading_plan`. The meal page and the
LOAD face now agree at 680 to the gram, edits included.

## Open questions (the mini-interview)
| Q | Question |
|---|---|
| Q-LC1 | FAT_FLOOR_G value: 0.5 g/kg (proposed) vs 20 %E vs a flat gram floor |
| Q-LC2 | Does the 12 g/kg clamp bind an EDITED plan target, or is the override exempt (proposed: exempt)? |
| Q-LC3 | `energy_basis = "loading_surplus"` naming + whether tdee/tef render with a caveat on loading days |
| Q-LC4 | Do the additive steps (recovery debt, tomorrow top-up) ever ADD to the plan target (proposed: never — replace is total)? |
| Q-LC5 | Meal-page provenance rendering (display slice — desk, not this spec) |
