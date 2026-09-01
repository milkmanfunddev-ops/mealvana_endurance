# Coding-agent handoff — brick-transition@v1

**Target:** tag `brick-transition@v1` (manifest `bundles/brick-transition.yaml`). Implement until
`qa/conformance/run_dart.sh transition-nutrition` and `… brick-eligibility` are green, the R8 seam
test is green, and `conformance/design/transition-card.yaml` passes. Specs are the contract; the
review trail lives on artifact e4542244 (v1–v8).

## Expected-red inventory (day one)
- `vectors/fueling/transition-nutrition.json` — 10/10 red: code computes weight×0.3/0.35 g/kg over
  a 180-min cliff (`brick-workout.ts:776-783`); spec T-1 replaces it with
  `clamp(round(next-leg rate × effective_gap/60), 0, 30)`.
- `vectors/domain/brick-eligibility.json` — r5-* red (skipped legs linkable, D-007); most others
  green-by-accident against `brick_eligibility.dart` — implement the published predicate anyway,
  the vectors must run against a published interface, not internals.
- Runner: `run_dart.sh` has no arms for either slice; `vectors/domain/` is a new family root.
  Extending the runner + writing the two Dart harnesses is part of THIS task.

## Deferred-ledger carry
This bundle has no prior `brick-transition.deferred.md`. Adjacent ledger:
`bundles/pre-workout-macros.deferred.md` P13/P17/P18 stay with the food-recommendation bench —
this bundle neither resolves nor carries them. Open Qs it deliberately ships around:
Q-TN1 (max gap) · Q-TN2 (per-sport pre-buffer) · Q-TN3 (transition_min as form input; default 3
ships silent) · Q-TN4 (gut-scaled clamp; flat 30 ships) · Q-TC1 (aggregate representation;
Adjust-Macros untouched) · Q-BR1/2 (characterization stands; one tripwire vector).

## Conflict watchlist (stage 6b — each row verified by grep/file-check 2026-09-01)
1. **Update, not greenfield (app); greenfield (harnesses).** `test/qa_conformance/` holds only the
   three pre-workout harnesses; brick code paths all exist and change in place.
2. **Twins.** `OfflineMacroCalculator.calculateBrickHydration` (dart:1557) mirrors
   `brick-workout.ts` "exactly" per its own doc comment — transition changes land in BOTH or the
   mirror claim breaks. `electrolyte-water-pairing` has a named Dart twin (catalog handback C2).
3. **Deploy-coupled API surface.** `transition_name` and the transition macro fields cross two
   process boundaries: generate-macros-v4 → generate-nutrition-plan-v3, and → the app parsers
   (`llm_response_parser.dart`, `brick_macro_service.dart`, `macro_explanation_service.*`).
   Edge functions ship via the deploy playbook, app ships separately — sequence: additive field
   (`sport_pair` label) first, consumers tolerant, then flip producer naming to positional.
4. **Tests pinning superseded behavior** (must be updated WITH the change, commit citing the spec):
   `brick-workout-new.test.ts`, `hydration-personas.test.ts`, `strict-macro-e2e.test.ts`,
   parity fixtures `29/30-brick-triathlon-*.json` (pin old T1/T2 names + 300 ml + weight carbs),
   app `brick_eligibility_test.dart` (pins skipped-legs-allowed = D-007),
   `nutrition_target_overrides_brick_payload_test.dart`, `macro_dashboard_brick_test.dart`,
   `fuel_timeline_brick_test.dart`.
5. **Adjacent call sites.** `activities_controller.dart`, `macro_dashboard_providers.dart`,
   `breakdown_pager.dart` (aggregate — Q-TC1 says DO NOT change it this bundle), and the
   explanation services that render the drawer (TC-4/TC-5 copy lives there).
6. **UI/goldens fate.** Transition card + drawer re-cut per TC-2/TC-4 (carbs delivered/target +
   band rail; fluids+sodium tallies; protein stat removed; sodium loses `/target`; drawer
   fluid/sodium sections lose their formula lines; swim/wetsuit copy replaced sport-aware, TC-5).
   Regenerate goldens citing the spec change. Stale auto-name ("RUNNING/RUNNING BRICK", run-log
   F-E) is an ops bug — fix welcome, not gated.
7. **Producer/consumer inventory** — every field the transition surface reads:

| Field | Producers | Shapes actually written | Existing consumers + resolution | New rule |
|---|---|---|---|---|
| `transition_name` | `brick-workout.ts` (×2 emit sites) | sport-pair: swim→bike=`T1`, bike→run=`T2`, else `T{i+1}` — COLLIDES on repeat legs; bike→run 2-leg emits `T2` | `brick-handler.ts:519` positional `T{i+1}`; app mapper positional; `normalizeTransitionName` digit-extracts | **Positional `T{i+1}` everywhere (R8)**; `sport_pair` as separate label field. SEAM TEST feeds producer-shaped payloads (3 shapes), asserts key equality — never engine-vs-itself |
| transition `carbs_g` | `brick-workout.ts` weight tiers | 0 below 180 min total; else `weight×0.3/0.35` | plan-v3 targets → LP; card shows delivered bare | **T-1 dose** (10 vectors); card per TC-2 |
| transition `water_ml` | `TRANSITION_FLUID_ML=300` (+ dart `_transitionFluidMl`) | fixed 300, subtracted from hydration total | plan solver `enforceWaterMin`; drawer "fixed 10 oz" | **No target (T-5)** — tally only; carve-out constant's fate = reserved hydration slice, DO NOT redesign here |
| transition `sodium_mg` | `brick-workout.ts:458` | `300/1000 × sodium_conc` | card `265/248` pair; drawer formula | **No target (T-5)** — tally only; drawer explains, no formula implying a target (TC-4) |
| `transitionMin` | **nobody** — creation form has no field | absent | none | new input; **default 3** when absent (Q-TN3 open on exposing it) |
| leg `status` | activity rows (platform sync can write `skipped`) | planned/skipped/done_confirmed/done_verified | `brick_eligibility.dart` ignores status | **R5: skipped ineligible**; done/verified unchanged (Q-BR1, tripwire vector) |

Seam-test discipline per app `docs/test/README.md` §"Seam tests: stored ≠ recomputed": stored side
built with the PRODUCER's constants and rounding; tolerance + log, never a hard assert; one test
through the real controller per write path.

## App-side companions (already in intake/)
`intake/2026-08-31-brick-handback.md` (R5/R8 fixes, citation repoints) and
`intake/2026-09-01-handback-catalog-conventions.md` (catalog migration, C2 pairing twin, C4
transition LP alignment) — execute with this bundle; they are part of done_when's spirit.
