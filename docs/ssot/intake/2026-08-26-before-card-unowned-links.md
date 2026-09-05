> **DEFERRED 2026-08-26 (Xuan) → next iteration.** No further ruling round this iteration; carried in `bundles/pre-workout-macros.deferred.md` with the interim default the coding agent uses. Not resolved, not declined.

type: ruling-request
bundle: pre-workout-macros@v1 (superseding bundle pending — surfaced by stage 6 test plan
`docs/feature-test-plans/pre-workout-before-card.md` §1 I5, I10 and the symmetry finding; §6.1 FC-1)

## Why this matters
Four behaviours of the BEFORE card are owned by no document. A coding agent will decide each one
silently; each is a future bug of the "faithfully ported the hole" class.

## The questions

### Q1 — Hydration check on a GATED plan (plan I5)
`hydration-check.md` makes the control exist iff `timeBeforeWorkoutMin >= T_REF`; hydration v6's gate
returns `fluidMl: null`. A ≥ 2 h plan that is gated (short, cool session) therefore shows a check
whose DARK answer would add `4·BW` to a target that is "not stated". Options: (a) suppress the check
when `regime == "gated"` (recommended — a target that is not stated cannot be raised; F-1 keeps
"no target" and "0" distinct); (b) show it, answer recorded, no write; (c) a DARK answer un-gates.
Spec home: hydration-check *When it exists at all* (+ a suppression golden note on `fuelstat_gated`).

### Q2 — Persistence of the three writes (plan I10)
The answer (`hydrationCheck`), stepper edits and added rows have no column, no JSON key and no
document claiming they survive relaunch/sync (`hydration-check.md` says so explicitly). Also: is the
recompute client-only (offline engine, the authority per the app file header) or does
`generate-macros-v4` gain a request field? Options: (a) persist all three in
`activities.nutrition_plan_data` alongside the plan, recompute client-side, one atomic write;
(b) answer only, edits ephemeral; (c) defer persistence (answer lost on relaunch — accepted).
Spec home: a "Persistence" contract on `surfaces/pre-workout-before-card.md`.

### Q3 — Row removal and the edited water row (symmetry)
FC-7 adds a food row; no gesture removes one. And H-4 removes "the added water row" on Change answer
— including one the athlete has since stepped up (DARK copy invites that)? Options: (a) stepper to 0
removes any row; the tag governs — an edited tagged row is still removed on revert (recommended);
(b) swipe-to-delete rows; edited tagged rows lose the tag and survive. Spec home: feeding-card FC-G2/FC-7.

### Q4 — MEAL title: "Pre-Run Meal" always (FC-1) vs the app's sport-varying titles
`pre_workout_feeding_labels.dart` renders Pre-Run / Pre-Ride / Pre-Workout by sport; FC-1 says
"Pre-Run Meal — always, never renamed". Was the ratified title meant to be run-specific, or should
the design spec read "Pre-{Sport} Meal"? Options: (a) design spec amended to sport-varying (erratum
on FC-1 + the golden notes); (b) code retires the sport variant. Spec home: feeding-card FC-1.

## What it gates
The hydration-check write path (Q1, Q2), the stepper/row gestures (Q3), the feeding-card goldens (Q4).
