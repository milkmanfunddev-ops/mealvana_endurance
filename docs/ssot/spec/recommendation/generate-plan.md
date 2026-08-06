# SSOT — Generate Nutrition Plan (food selection)

**Status: RATIFIED (Xuan, 2026-07-28).** One open *code*-reconciliation remains (H5 bands vs the
`calculatePreWorkoutTargets` meal_type bands — see D4).

## What this is (read first)
This is an **invariant / contract** spec, NOT a procedure. It states **WHAT any correct
implementation must guarantee**, and deliberately says nothing about **HOW** (which solver runs
first, LP vs greedy, etc.). The point: Lee can refactor the "spaghetti" freely — as long as every
**hard invariant** below stays green, behaviour is preserved.

- **This algorithm consumes the macro targets** (produced by the fueling calc — the ratified
  `spec/fueling/*` slices) **and selects the actual foods** for each phase.
- **The flowchart is the current implementation, NOT the SSOT.** `app/docs/business_logic/
  nutrition-plan-v3-flowchart.png` = the current HOW. It may change; this spec must not.
- **Code today (impure orchestrator):** `ClientPlanService.generatePlan` + the server edge functions
  `generate-macros-v4` / `personal-formula-pins`. The pure scaling core (`FormulaMacros`) is
  golden-vectored separately.

## Vocabulary
- **Phase** — before · during · after.
- **Formula / "kit"** — a `PersonalFormula`: a user-authored set of food components tied to a phase.
- **Pin** — a personal formula the user has pinned to a phase.
- **Suitable pin** *(ratified D2)* — the pin's **phase** scope matches, its **sport** matches, AND the
  workout's **window** (window/duration) fits it. All three.
- **Range** *(ratified D3)* — every macro at every phase has a calculated **[low, high] range**; the
  target sits at (about) the **midpoint**. "In tolerance" means **inside the range** — closer to the
  midpoint is better, but any point in `[low, high]` is acceptable.
- **Gap-fill** *(ratified D3)* — when scaling a formula alone can't bring a macro into its range, the
  algorithm adds **hydration / sodium / electrolyte** to fill the gap and reach the range.
- **Diet/allergy violation** — a component food carrying an allergen on the user's list, or
  incompatible with their `dietaryPreference`.

## Hard invariants — MUST always hold (any violation = a bug)
- **H1 — Graceful degradation (safety net).** generate-plan ALWAYS returns a plan; a *genuinely*
  unmeetable target → a **reported shortfall/warning**, never a hard failure or blocked delivery.
  (Normal in-range is guaranteed by H6; H1 covers only the rare truly-impossible case.)
- **H2 — Safety, with informed override.** The **algorithm never *selects*** a diet/allergy-violating
  food in the fallback/library path. A user's **explicit pin may override** safety (user autonomy) —
  BUT any safety-violating pinned formula **MUST always carry a visible warning**. So: no
  *algorithm-chosen* violator ever; a *user-chosen* violator only ever appears **with a warning**.
  **⚠️ VERIFIED GAP (sim + code, 2026-07-28 — see `DEVIATIONS.md` D-003):** the *override* half
  holds, but the *warning* half is **NOT implemented**. A pinned gluten formula (Oatmeal) was
  served to a gluten-allergic athlete (Ravi) with **no warning of any kind** — the pin path
  bypasses the allergen filter (`pre-workout.ts:1006-1008`) and emits no safety flag on
  `pin_decision`. This is the intended H2 truth; the code does not yet meet it. Awaiting Xuan's ruling.
- **H3 — Pin priority.** If a *suitable* pin exists for a phase, the plan's foods for that phase
  derive from it (scaled toward the range), **before** any library/template fallback — honored even
  when the pin violates safety (per H2's mandatory warning).
- **H4 — Fallback filtering.** When no suitable pin exists, the library fallback considers all
  formulas **except** diet/allergy violators.
- **H5 — Pre-workout stacking.** Pre-workout eating occasions by the pre-workout window, and they
  **stack** (larger ⊇ smaller): **t < 30 min → {top-up}** · **30 ≤ t < 120 min → {snack, top-up}** ·
  **t ≥ 120 min → {meal, snack, top-up}**. Boundaries are **inclusive at the bottom**, matching the
  pre-workout bundle's convention — `t == 30` and `t == 120` take the upper band.
  **Amended 2026-08-05 (ruling: Lee).** These bands were `≤30 / 30–90 / ≥90` until
  `pre-workout-macros@v1` landed, which set the meal boundary at `TIER_MEAL_MIN = 120`. The two
  ratified documents disagreed for one day; the bundle wins, because its conformance vectors pin
  `meal iff t >= 120` (carbs inv 6) and the engine now derives `sub_phase_type` from that tier
  result. **This changed athlete-visible behaviour**: a 90–119 minute window no longer yields a
  Full Meal. Registered and resolved as **D-017**; it also settles D-015, which asked only whether
  90 sat in the upper band — there is no longer a band edge at 90.
  ✅ *Code MATCHES* — `calculatePreWorkoutCarbs` / `calculatePreWorkoutHydration`
  (`generate-macros-v4/pre-workout.ts`). Note `BeforeSubPhase.fromTimeWindow`
  (`formula_kit/domain/before_sub_phase.dart`) is a **different** thing: it buckets
  `pre_workout_templates.time_window` strings for the Before-tab **filter chips**, and still reads
  `<30 / 30–90 / 1.5–3h`. It does not drive plan occasions.
  (Also not to be confused with `calculatePreWorkoutTargets.meal_type` at 60/150, a *separate*
  label for protein/fat magnitude — see D4.)
- **H6 — In-range adherence (scaling + gap-fill).** **Every macro at every phase lands within its
  [low, high] range.** When formula-scaling alone can't reach it, the algorithm **gap-fills**
  (hydration / sodium / electrolyte) to bring it in. **A plan is never returned that misses a range**
  (the only exception is the H1 genuinely-impossible edge, which is *reported*).
- **H7 — Gut cap.** During-carb selection never exceeds the sport gut ceiling (run 70 / bike 120 /
  swim 0 g/hr) — consistent with `spec/fueling/during-workout-carbs`.
- **H8 — Input validation.** Missing/invalid required input → rejected (HTTP 400), never a silent
  degraded plan.
- **H9 — Targets deterministic, foods need not be.** The macro *targets/ranges* consumed are
  deterministic (fueling calc). Food *selection* MAY vary (repo order, tie-breaks) — we pin the
  **properties** (H1–H8), not the exact foods.
- **H10 — Brick composition.** A brick plan = one shared Before + per-segment During + T1/T2
  transition fuel + a recovery After; each segment's During obeys the single-sport During invariants.

## Soft invariants — SHOULD hold (ranked preferences; a miss is a quality issue, not a bug)
- **S1** prefer honoring liked foods / avoiding disliked.
- **S2** prefer fewer distinct items (simplicity).
- **S3** recovery (after) prefers lower travel + prep.
- **S4** on the H1 edge, minimize the shortfall magnitude.
- **S5** prefer each macro **near the midpoint** of its range (H6 guarantees *in* range; S5 prefers *centered*).
- The algorithm may weigh S1–S5 however it likes — **never at the expense of a hard invariant.**

## Ratified decisions (2026-07-28)
- **D1 ✅ (ratified) / ⚠️ code gap** Pin **overrides** safety, but a safety-violating pin **always
  carries a warning** (H2/H3). **Override half verified working; warning half NOT implemented**
  (sim + code, 2026-07-28 — `DEVIATIONS.md` D-003). Ruling pending: build the warning vs re-open D1.
- **D2 ✅** "Suitable" pin = **phase + sport + window** all fit (Vocabulary).
- **D3 ✅** Tolerance = **inside the [low, high] range**; never miss it; midpoint preferred (S5);
  **gap-fill** (hydration/sodium/electrolyte) fills shortfalls to reach the range (H6).
- **D4 ✅ (spec + code, verified 2026-07-28)** Stacking bands are **≤30 / 30–90 / ≥90 min**, and the
  code **MATCHES**: the occasion concept is `BeforeSubPhase.fromTimeWindow` (`<30 / 30–90 / 1.5–3h`),
  driven by `pre_workout_templates.time_window`. The earlier "60/150 deviation" was a **conflation** —
  `calculatePreWorkoutTargets.meal_type` (60/150) is a *separate* label that sets pre-workout
  protein/fat magnitude + the explanation copy, NOT the occasion count. **No deviation on H5.**
  *Minor note (optional cleanup, not a bug):* the app has two "hours-before" band systems — 30/90 for
  occasions, 60/150 for protein/fat — which could confuse. Not verified end-to-end on the sim yet
  (only the band definitions were traced; the actual stacking behavior is a separate check).

## Conformance (Phase-4 invariant harness)
For many `(athlete × workout)` inputs, run the **real** generate-plan (server path) and assert
**H1–H10** as *properties*:
- **H2** — scan every plan food vs the athlete's allergies/diet: any violator MUST trace to a pin
  AND carry a warning; the fallback path has none.
- **H3** — when a suitable pin exists, the phase foods trace to it.
- **H5** — the occasion set equals the banded/stacked expectation for the window.
- **H6** — every macro's total lands within `[low, high]`; check gap-fill kicked in when scaling fell short.
Soft invariants (S1–S5) are **scored + reported**, not pass/fail. The pure scaling core
(`FormulaMacros`) keeps **exact golden vectors** (a separate `spec/recommendation/formula-scaling` slice).
Seeded athletes span the constraints (vegan, allergies, keto — `qa/profiles/athletes.json`).

## Appendix — current implementation (NOT the SSOT, may change)
The flowchart's solver mechanics (Algorithm-C fallback · explode composite templates · template
solver → rule-solver → gut-capped gap-fill · recovery template → LP → greedy · brick T1/T2) are
**HOW**. Free to refactor as long as H1–H10 hold.
