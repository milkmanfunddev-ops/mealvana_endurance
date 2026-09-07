> **DEFERRED 2026-08-26 (Xuan) → next iteration.** No further ruling round this iteration; carried in `bundles/pre-workout-macros.deferred.md` with the interim default the coding agent uses. Not resolved, not declined.

type: spec-erratum
bundle: pre-workout-macros@v1 (superseding bundle pending — surfaced by stage 6 test plan)

## Why this matters
`pre-workout.notes.md` §6 is the drawer contract the coding agent will read next to the design
family, and four of its lines now contradict ratified, newer documents. Left as-is, a port
implements 5 g carb rounding and a clock-gated check that the design family forbids.

## Artifact + location
`spec/fueling/pre-workout.notes.md` §6 "Explanation layer — the drawer contract" (lines ~1137–1205):
1. "Carbohydrate rounds to 5 g." — contradicts `spec/design/components/fuel-stat.md` M-5
   (RATIFIED 2026-08-26): "carbs to the gram on this surface"; the ratified rendering shows 52 g / 43 g.
   The app's `pre_workout_display_rounding.dart` (`round5`) implements the §6 line.
2. "Stop offering it once the snack window closes. Past t−30 … the card drops the question" —
   superseded by PW-021 (2026-08-26): the check is athlete-timed, available for the life of a ≥ 2 h plan.
3. "The urine cue rides with the number, in every tier." — narrowed by PW-021 point 3: below `T_REF`
   the cue lives only in the fine print (and S-G4 defers even that this iteration).
4. "Honour `renderAs` (§3.8)" — carbs v2 *Outputs* says "No `renderAs`"; the naming threshold is now
   feeding-card FC-1.
Also: the ml→oz display rule ruled in R-01 (reconciliation §4, 2026-08-26) is not yet folded into §6
(F-13 debt) — the oz analogue of `round25` has no home in the notes.

## Why it is wrong
Each line predates a later ratified ruling (M-5, PW-021, carbs v2, R-01) and none carries a dated
supersession note, so a reader cannot tell which document wins.

## Smallest correction
Dated post-ratification strike-throughs in §6 citing M-5 / PW-021 / carbs v2, plus one new §6
paragraph carrying R-01 (target `round(ml/29.5735)` to the whole oz; band `[floor, ceil]`; carbs to
the gram). If Xuan prefers 5 g over M-5's gram, that is a ruling against M-5, not an erratum here.

## Adjacent question (not an erratum — flag for the ruling desk)
At `t = 0` the carbs band is `[0,0]` and suppressed (carbs †). If the athlete adds 1 g, is that
"delivered above ceiling" (fuel-stat M-2 alarm)? No document says.
