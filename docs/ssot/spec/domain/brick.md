# SSOT — Brick: eligibility & composition

**Status: RATIFIED v1 (Xuan, 2026-08-31)** — via the ruling on intake
`intake/2026-08-26-brick-eligibility-logic-ssot.md` (the desk of 2026-08-31). R1–R4 and R6–R7
ratify Lee's 2026-08-26 field rulings as implemented; R5 and R8 rule *against* current code
(see `DEVIATIONS.md` D-007 / D-008). Q-BR1/Q-BR2 remain open.

**What this file owns:** what a brick *is*, which workouts may be its legs, and when the
link-into-a-brick action is *offered*. It owns no quantity (transition fuel amounts →
`spec/fueling/` transition-nutrition slice, in progress on this branch) and no pixel
(brick surfaces → `spec/design/`). Every surface that offers bricks (macro dashboard, fueling
page, any future host) cites these rules rather than restating them.

## Definitions

- **Leg** — a single workout participating in a brick.
- **Brick** — an ordered list of 2–3 legs on one calendar day, fueled as one event
  (`generate-plan.md` H10: one shared Before, per-segment During, per-gap transition fuel,
  one recovery After).
- **Transition** — the gap between consecutive legs, identified positionally (R8).

## Ratified rules

- **R1 — Any-on-day, no adjacency. RULED (Lee 2026-08-26, field; ratified Xuan 2026-08-31).**
  The brick action is offered iff the day holds **2+ eligible workouts** (R3), whatever lies
  between them on the timeline. Adjacency is not a condition (the earlier adjacency gate is
  WITHDRAWN). Corollary: the earlier "2+ distinct sports" offer condition is also gone — the
  sport-set test is per-leg (R3), and R2 makes duplicates legal.
- **R2 — Same-sport legs are allowed. RULED (Lee 2026-08-26, field; ratified Xuan 2026-08-31).**
  Two runs may form a brick (double-run day). The sport *set* is the only per-leg filter.
- **R3 — Eligible leg = swim | bike | run, not already a brick.** Strength/"other" are never
  legs. (Direct brick-extension is Q-BR2.)
- **R4 — Leg count: min 2, max 3. RULED (Xuan, 2026-08-31): the max-3 cap STANDS** for this
  iteration. It is a product cap, revisitable: once transition fuel is per-gap (the
  transition-nutrition slice), a 4th leg is no longer blocked by the nutrition model — lifting
  the cap becomes a pure product ruling.
- **R5 — A SKIPPED leg may NOT be linked. RULED (Xuan, 2026-08-31, against current code).**
  Current code silently accepts skipped legs (D-007). DONE/verified legs and past/future days
  are Q-BR1 — until ruled, code behaviour there is characterization, not truth.
- **R6 — Leg order = pick order. RULED (Lee 2026-08-26, field; ratified Xuan 2026-08-31).**
  The athlete's tap order is the brick's leg order; it need not match timeline order. `Swap`
  reverses it.
- **R7 — Delete brick = ungroup. RULED (Lee 2026-08-26, field; ratified Xuan 2026-08-31).**
  Deleting a brick restores its legs to the ungrouped state (visible, individually owned) and
  removes the brick row and its plan. Legs are never tombstoned by a brick delete.
- **R8 — Transition identity is POSITIONAL. RULED (Xuan, 2026-08-31, against current code).**
  A brick's transitions are `T1 … T(n-1)` **by position** (the gap after leg i is `T{i}`); the
  sport pair (e.g. "bike→run") is a display label only, carrying no identity and no nutritional
  meaning (the literature scales fuel by cumulative time and next-leg tolerance, not by pair).
  Producers and consumers key transitions positionally; a sport-pair key is a defect (D-008 —
  today a plain bike→run brick's transition fuel silently falls to zero-defaults, and repeat
  legs collide).
- **Time gap between legs — DEFERRED (Xuan, 2026-08-31)** into the transition-nutrition slice's
  **max-gap rule** (`spec/fueling/transition-nutrition.notes.md`, proposed model v0 §4): past a
  ratified maximum gap the "brick" is two sessions with their own pre/post phases. Eligibility
  carries no gap condition until that slice ratifies one.

## Open questions

| Q | Question | Blocks |
|---|---|---|
| Q-BR1 | May a DONE_CONFIRMED / DONE_VERIFIED leg be linked? May a brick be formed on a past day? A future day? (Current code: yes to all, silently — characterization.) | nothing ships-blocking; vectors for those states stay `status: characterization` |
| Q-BR2 | May an existing brick be extended with a third workout directly, or only ungroup-then-relink? (Current: ungroup-then-relink only.) | the dashboard affordance set |

## Conformance

`vectors/domain/brick-eligibility.json` (to be generated via `spec-to-vectors` from THIS file —
not from `brick_eligibility.dart`): input = ordered day of `(sport, status, isBrick)` →
expected `{offered, candidateIds}` + create-time verdicts (leg count, R5). R8 additionally
requires a **producer-shaped seam test** (ship-bundle rule, qa `8b12b9d`): the
`generate-macros-v4` transition payload keys must match what `generate-nutrition-plan-v3`
looks up — a single-engine vector cannot see that seam.

## Cross-references

- `spec/recommendation/generate-plan.md` H10 — brick plan composition ("T1/T2" there reads as
  "per-gap transition fuel" under R8; wording updates at that spec's next revision).
- `spec/fueling/during-workout-carbs.md` / `during-workout-hydration.md` — the reserved
  multi-segment slice this bundle fills; cumulative-event-time banding.
- Characterization source: `app/lib/features/activities/domain/brick_eligibility.dart`,
  `brick_selection_controller.dart`, `supabase/functions/generate-macros-v4/brick-workout.ts`,
  `generate-nutrition-plan-v3/brick-handler.ts` (as of app develop `38a2e920`).

## Post-ratification additions (RULED, Xuan, 2026-09-03 — create-flow desk)
- **R1a — Two creation paths COEXIST.** Link-based creation (R1, as ratified: the brick action on
  a day holding 2+ eligible workouts) is joined by **inline creation** in the Create Activity Plan
  flow (sport tab BRICK → leg chips → drag-order rows with per-leg durations). Neither replaces
  the other; eligibility rules (R2–R7) bind both paths identically.
- **R9 — A brick holds at most 3 legs** ("BRICK IS FULL · 3 LEGS"). Applies to both creation
  paths; extending past 3 is declined in-UI, not silently truncated.
