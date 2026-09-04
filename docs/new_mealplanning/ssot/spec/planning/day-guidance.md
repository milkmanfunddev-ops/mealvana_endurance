# SSOT — Day Guidance

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** N/A — recorded from the shipped code (see Code).
**Code:** `dayGuidance(userId, ctx, date)` — prototype `server/vana/tools.ts`, edge `_shared/vana/tools.ts`
(identical logic).
**Scope:** the day-label decision table, the note copy, and the dinner + snack pick. **Consumers:** the
`day_guidance` part (general Vana "what should I eat today", the home payload's `day`), `planDayPart` (which
context tags fill a day's slots), the day-notes fallback text.

## Inputs

`ctx.week.workouts` for the date · `ctx.race` · `daily_macro_targets.carb_g` for the date (fallback: today's
context target, then 0).

## Decision table — evaluated top to bottom, first match wins

| # | Condition | `label` | `contexts` searched | `note` |
|---|---|---|---|---|
| 1 | race is on this date (`raceIn == 0`) | Race day | race-week · pre-session | "Race-morning breakfast from your pre-race formula; eat familiar food only." |
| 2 | `raceIn == 1` | Race eve | race-week · carb-load | "Low-fiber, low-fat, high-carb: at least {N}g carbs. Nothing new tonight." |
| 3 | `raceIn ≤ 3` (2 or 3) | Carb-load day | carb-load · race-week | "At least {N}g carbs today; keep fat and fiber modest." |
| 4 | no workouts, or Σ minutes < 45 | Rest day (no workouts) / Low-load day (some) | rest-day | "At least {N}g carbs, protein at every meal. No need to top up around training." |
| 5 | Σ minutes ≥ 120 | Big session day | recovery · pre-session | "At least {N}g carbs; a real recovery meal within two hours of finishing." |
| 6 | otherwise (45 ≤ Σ < 120) | Training day | everyday · recovery | "At least {N}g carbs, protein at every meal." |

`raceIn` is `race.date − date` in whole days; negative (race already happened) never matches rows 1–3.
**Row 1's note carries no carb number** — deliberate: race-morning fuel is the deterministic pre-workout engine's,
not Vana's (`../intent/` §1.2). `{N}` = `minCarbsG` (rounded).

## Suggestions

One **dinner** and one **snack**, each the top `search_meals` hit for the row's contexts with `embed: false`
(rank by frequency nudge + saved-first only — no query text). The snack search excludes the dinner's id so a
saved meal with `meal_types = {}` can never fill both (`../selection/meal-search.md` MS-6). Exactly two
suggestions when the library has any match; the contract fixture asserts `suggestions.length == 2` and distinct
ids.

## Invariants

1. Exactly one label per date; the set is the seven strings above.
2. The race rows beat the workout rows: a 3-hour ride the day before a race is "Race eve".
3. `minCarbsG` is the date's own target row when it exists, never today's, so a future day reads its own number.
4. The note quotes `minCarbsG` as a minimum ("at least") or not at all.

## Worked examples

| Date | Race | Workouts | → |
|---|---|---|---|
| Sat, race Sat | 0 d | 5k 20 min | Race day |
| Fri, race Sat | 1 d | rest | Race eve |
| Wed, race Sat | 3 d | 60 min easy | Carb-load day (race row wins over Training day) |
| Tue, race Sat | 4 d | — | Rest day |
| Mon, no race | — | 30 min swim | Low-load day |
| Sun, no race | — | 180 min ride | Big session day |
| Thu, no race | — | 75 min run | Training day |

## Conformance

Pending extraction (**Q-DG1**): the label/contexts/note decision is inside an async DB-bound function.
Extracting `dayGuidanceLabel(workoutsMinutes, workoutCount, raceIn, minCarbsG)` into `plan-math.ts` lets the
seven worked examples become `vectors/planning/day-guidance.json`. Today the guard is the contract fixture
`day_guidance.json` (one live day) and the smoke.
