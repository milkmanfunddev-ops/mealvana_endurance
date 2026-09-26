type: ruling-request
bundle: (cross-cutting — `spec/fueling/during-workout-carbs.md` + `vectors/fueling/during-workout-carbs.json`)

## Why this matters
`conformance/during_workout_carbs_conformance_test.dart` has been red at 3/11 since the
ratified vectors landed, so the whole during-carbs gate is a dead tripwire: a real
regression in the shipped rate math would not be distinguishable from this known red.
App-side fix scope waits on this ruling
(`ops/data/bug-reports/2026-09-03-during-carb-band-caps-diverge-from-ratified-vectors.md`).

## The question
When the duration band's midpoint exceeds the sport ceiling, is the published **band**
(`band_low` / `band_high`) clamped to that ceiling, or does the band stay as the duration
table states it with only the **rate** capped?

## What is already ratified
- `spec/fueling/during-workout-carbs.md` "Duration bands" + "Gut multiplier · sport ceiling":
  the ceiling is described as acting on the rate (Running 70 · Cycling 120 · Swimming 0).
- Vector `long-running-ceiling-cap` (ratified): 180 min running ⇒ `rate_gph 70`,
  **`band_low 60` / `band_high 90`**, `sport_ceiling 70` — why: "[60,90] midpoint 75 > 70
  running ceiling → capped 70". So the vector caps the rate and leaves the band unclamped.
- The app's `OfflineMacroCalculator.calculateDuringWorkoutCarbRate` clamps `band_low`/`band_high`
  to the sport ceiling (with a ×0.875 widen on the low edge) — introduced by app `a1b7b9ae`,
  still present on `release/1.27.0` and `mealplanning`.

## Options
1. **Vectors are right — the band is the duration band; only the rate caps.** The band keeps
   its evidential meaning (what the literature says this duration needs) and the ceiling is a
   delivery limit on the single number. Cost: the UI can show a band whose top the app will
   never prescribe (90 top, 70 prescribed), which reads oddly beside a capped target — and is
   the same "band wider than any plan" complaint that PW-021 ruled on for pre-workout carbs
   (`intake/2026-09-04-pre-workout-carb-band-ruling.md`, RESOLVED 2026-09-04).
2. **The app is right — clamp the band to the ceiling too.** The band then means "what we
   could actually prescribe here", consistent with the pre-workout plan-band amendment's
   direction (a usable per-plan tolerance, not the evidence range). Cost: vectors +
   `during-workout-carbs.md` need amending, and the ×0.875 low-edge widen currently in the code
   is undocumented policy that would need ratifying or dropping.
3. Clamp `band_high` only, leave `band_low` on the table value (no widen).

## Recommendation
Option 2's *direction* matches the already-ruled pre-workout band amendment (bands should be
usable, not evidential), but the ×0.875 widen should not be ratified by accident — if 2 is
taken, rule the widen explicitly or drop it. Either way the vectors and the code must end up
on one story; today they disagree and the gate stays red.

## Suggested spec home
`spec/fueling/during-workout-carbs.md` — a post-ratification addition under "Gut multiplier ·
sport ceiling" stating what the ceiling does to the band, plus regenerated
`vectors/fueling/during-workout-carbs.json` band fields if option 2/3 wins.
