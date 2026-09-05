type: ruling-request
bundle: pre-workout-macros@v1

## Why this matters
The fluid gate (`workoutDurationMin < 60 AND tempC < 30` → no pre-workout fluid target) is firing on
**29% of production plans** — 10 of the 35 saved in August 2026, across 8 distinct users. The spec's
own notes §5.4 argue neither threshold is supported by its source, and offer a counter-example
("a 55-minute run at 18 °C is gated to no target while plausibly losing ~700 ml") that a real
2026-08-25 plan now matches almost exactly: a **59-minute run at 20 °C, no fluid target**. Until this
is ruled, we cannot tell a coach reporting "it recommended nothing before my workout" whether they
found a defect or the design.

## The question
Are `< 60 min` and `< 30 °C` the right thresholds for withholding a pre-workout fluid target
entirely — and should the gate exist in this form at all?

## What is already ruled
`spec/fueling/pre-workout-hydration.md` (RATIFIED v6, Xuan 2026-08-04), algorithm block: the gate is
evaluated first and returns `fluidMl/fluidLowMl/fluidHighMl: null`, `tiers: []`, `regime: "gated"`,
`targetBasis: "none"`. Invariant 11 pins it to `null`, never `0`. Notes §2.10 records the v6 decision
as "keep, unchanged" — the gate says *we are not setting a target at all* — while explicitly
conceding "the proxy is broader than its source". Registered as **PW-003** (severity B, medium) in
`pre-workout.OPEN-QUESTIONS.md`.

Load-bearing and NOT in question here: duration and temperature are used **only** by the gate. They
never re-enter the algorithm. Dose is a function of `timeBeforeWorkoutMin` and `bodyWeightKg` (plus
`hydrationCheck` at or above `T_REF`). This ruling decides *whether* a session gets a target, not
*how much*.

## Production evidence (prod Supabase, `activities.nutrition_plan_data`)
All 10 August gated plans are conformant with the gate as written — every one is `< 60 min` with
`tempC < 30`:

| Date | Activity | Duration | tempC used |
|---|---|---|---|
| 2026-08-25 | running | 59 min | 20 |
| 2026-08-25 | running | 34 min | 24 |
| 2026-08-22 | running | 53 min | 22 |
| 2026-08-22 | running | 23 min | 20 |
| 2026-08-14 | swimming | 53 min | (null → 22 default) |
| 2026-08-11 ×3, 2026-08-10 ×2 | swimming | 40 min | (null → 22 default) |

Reproduce: `ops/scratchpad/pre-workout-zero-fluid.sql`.

Coach-reported trigger: a coach reported a pre-workout recommendation of "0 fl oz and 0 sodium". Her
own three affected plans (2026-05-24, 2026-06-06, 2026-07-03) predate v6 and are a separate,
already-fixed literal-zero defect — but the complaint is equally consistent with the gate, and that
is what makes this worth ruling rather than closing.

## Options
1. **Keep unchanged.** Honest under NATA's carve-out; zero work. §5.4's objection stands unanswered,
   and ~29% of sessions keep getting no hydration guidance.
2. **Narrow the duration threshold to 30 min.** 30 is the only duration figure the source actually
   cites (though about intake *during* exercise). Roughly halves the gated population; a 40-min swim
   and a 53-min run would get a target.
3. **Drop the temperature condition.** J&G table 9.4 puts marathon sweat loss at 800–1,200 ml/h at
   15–20 °C — inside the gate's "cool" branch — so `< 30 °C` is doing little protective work.
   Combines naturally with option 2.
4. **Retire the gate; let the band carry it.** Below some duration, return the normal `t`-taper with
   `fluidLowMl = 0`, which already means *nothing is required*. Removes the null/zero split at the
   source, at the cost of making a recommendation where the literature is silent.
5. **Gate on sweat rate instead of duration+temp.** `users.sweat_rate`, `sweat_sodium`,
   `known_sweat_rate_ml_per_hour` are already collected. Best-targeted, largest spec change, and
   needs its own evidence base.

## Recommendation
Options 2+3 together (gate at `< 30 min`, no temperature term) as the smallest change that answers
§5.4 on its own terms — the retained threshold is then the one figure the source actually names.
Option 4 is defensible and would simplify the contract, but it makes a positive recommendation in a
region the spec currently and deliberately declines to cover; that is a product call, not a
conformance one.

## Adjacent — may warrant its own row
**Which temperature feeds the gate for swimming?** Six of the ten gated plans are swims with no
`tempC`, so the 22 °C default decided the gate. Five of those have `activities.swimming_water_temp_c
= 26` recorded and unused. Outcome is unchanged here (26 < 30), but pool temperatures do reach 30,
at which point air-vs-water selects opposite branches. The spec is sport-agnostic about what `tempC`
means.

## Suggested spec home
`spec/fueling/pre-workout-hydration.md` — the gate block in the algorithm, plus the scope banner;
resolve PW-003 in `pre-workout.OPEN-QUESTIONS.md` and fold the reasoning into notes §5.4. The v6
spec and its 21 vectors currently live on `qa/pre-workout-drawers` (unmerged); the two gate vectors
there regenerate from this ruling, the other 19 are unaffected.

## Gates
- Vector work: any threshold change regenerates `gate-fires-short-mild` / `gate-tempnull-default`.
- Blocked behind the sibling erratum `2026-08-25-hydration-slice-stale-v1.md` — the hydration
  conformance slice cannot currently run, so no ruling can be verified against the engine.
- App-side: the DTO defect that persists a gated `null` as `0.0`
  (`macro_repository.dart:209`, `fluidsMl: preHydration.fluidMl ?? 0`) violates invariant 11 today
  and is independent of this ruling — belongs ops-side, not here.
