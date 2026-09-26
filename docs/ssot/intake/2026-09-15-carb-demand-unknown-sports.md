# Carb demand for unknown/mobility sports — ratification needed

**Filed:** 2026-09-15 (Xuan's session). **Found during** the F4a validator hotfix
(macros-v6 rejected `other` sports before pricing; fixed + deployed same day).

## The question

F4a (session-demand.md, RULED 2026-09-10) rules session **ENERGY** for the open sport
domain: mobility 2.5 kcal·kg⁻¹·hr⁻¹, composites by legs, unknown → **0 kcal** +
ESTIMATE_ZERO. It says nothing about session **CARB DEMAND**.

`carbDemand()` (calculate-daily-macros-v6/formulas/session.ts) has no unknown-sport
guard: anything non-strength prices on the endurance carb-oxidation ladder. A 30-min
"Foam Rolling Routine" (sport `other`, IF ~0.77 zoneless default) adds **~10 g carbs**
to the day's target while adding **0 kcal** — internally inconsistent: the day demands
carbs for a session the engine says costs nothing.

## Options

1. **Unknown sports contribute 0 carb demand** (mirror F4a's 0-kcal: no energy → no
   oxidation to replace). Mobility class gets a proportionally low demand or also 0.
2. **Keep the oxidation-ladder pricing** for all non-strength sports (status quo) —
   accepts the kcal/carb inconsistency as conservative fueling.
3. **Tie carb demand to the priced kcal** (demand only where session_kcal > 0) — one
   rule, no per-class table.

Recommendation from the finding: option 1 or 3; the current state exists by omission,
not decision.

## Evidence
- Test pinning current behavior: `calculate-daily-macros-v6/index.test.ts`
  ("a day mixing running with an `other` session computes") — asserts kcal equality,
  deliberately does NOT assert carb equality, cites this intake.
- Sentry incident that surfaced the area: MEALVANA-ENDURANCE-C6.
- Related queued work: F4a spec-to-vectors regeneration (session-demand.md §F4a note) —
  still unrun; whichever option is ruled should land in that same vectors pass.
